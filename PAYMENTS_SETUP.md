# MoneyMap monthly payment setup

Prepared subscription prices:
- Premium: IDR 5,000 per month
- Elite: IDR 10,000 per month

This repository now contains a secure server-side integration scaffold. It is **not live yet**: merchant credentials, database migration, function deployment, webhook configuration, and frontend wiring are still required.

## 1. Xendit account

Create/sign in to a Xendit merchant account, complete verification, and request/enable Subscriptions plus a payment channel that supports merchant-initiated recurring transactions. Begin in Test Mode.

Never place the Xendit secret API key in index.html, browser JavaScript, GitHub Pages, or a public repository.

Xendit uses a hosted Payment Session with session_type SUBSCRIPTION. The customer links a supported payment method on the hosted checkout. Xendit schedules monthly collections and sends plan/cycle webhooks.

## 2. Apply the Supabase migration

In Supabase Dashboard → SQL Editor, run:
supabase/migrations/20261111000100_moneymap_subscriptions.sql

This creates a subscription row per account, webhook idempotency storage, and a server-only RPC for applying verified Xendit events. Users can read only their own subscription; client writes are denied.

## 3. Deploy Edge Functions

Deploy:
- supabase/functions/payment-create-checkout/index.ts
- supabase/functions/xendit-subscription-webhook/index.ts

Use Supabase CLI or the Supabase Dashboard Edge Functions editor. Configure these secrets:
- XENDIT_SECRET_KEY — Xendit secret API key (test key first)
- XENDIT_WEBHOOK_TOKEN — exact callback verification token configured in Xendit
- APP_BASE_URL — https://serifxvi-cloud.github.io/moneymap/

Hosted Supabase Edge Functions provide SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY automatically. Never expose the service-role key.

The checkout function requires a valid signed-in Supabase user. It accepts only tier=premium or tier=elite; amounts are fixed server-side (5000 / 10000 IDR), not supplied by the browser.

## 4. Configure Xendit webhook

Set the Xendit Subscriptions webhook URL to:
https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-subscription-webhook

Configure the same callback verification token as XENDIT_WEBHOOK_TOKEN in Supabase. Subscribe to:
- recurring.plan.activated
- recurring.plan.inactivated
- recurring.cycle.succeeded
- recurring.cycle.retrying
- recurring.cycle.failed

The webhook validates x-callback-token and processes events idempotently. The browser return URL is not proof of payment and must never unlock a tier.

## 5. Frontend integration still required

The membership buttons in the public GitHub Pages app still need to call the deployed payment-create-checkout Edge Function after the migration and functions are deployed.

The browser flow must:
1. Require a signed-in Supabase session.
2. POST {"tier":"premium"} or {"tier":"elite"} to /functions/v1/payment-create-checkout with Authorization: Bearer <access_token>.
3. Redirect to the returned checkout_url.
4. Read subscription status from mm_subscriptions after the webhook arrives.
5. Unlock paid features only when the server-backed subscription status is active and current_period_end is in the future.

Do not use query parameters, localStorage, or a client-side tier switch to grant paid access.

## 6. Test before going live

Use Xendit Test Mode and a supported test payment method. Verify first-cycle success, renewals, duplicate webhook delivery, failed/retrying cycles, cancellation, paid-through expiration, and row-level security. Only switch to Live Mode after successful end-to-end testing and merchant approval.

Important: this is a backend scaffold committed to the repository, not a completed live checkout. Confirm recurring payment channel support and current event settings in your own Xendit merchant dashboard before launch.
