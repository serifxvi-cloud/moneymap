import { createClient } from "npm:@supabase/supabase-js@2";
const headers = { "Access-Control-Allow-Origin": Deno.env.get("APP_BASE_URL") ?? "https://serifxvi-cloud.github.io", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };
const plans = { premium: { amount: 5000, name: "MoneyMap Premium" }, elite: { amount: 10000, name: "MoneyMap Elite" } } as const;
function reply(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers }); }
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")!, anon = Deno.env.get("SUPABASE_ANON_KEY")!, serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, xenditKey = Deno.env.get("XENDIT_SECRET_KEY");
    if (!xenditKey) throw new Error("Xendit is not configured yet.");
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return reply({ error: "Sign in first." }, 401);
    const auth = createClient(url, anon, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false } });
    const { data: { user }, error: authError } = await auth.auth.getUser();
    if (authError || !user) return reply({ error: "Your session is invalid. Please sign in again." }, 401);
    const body = await req.json(), tier = String(body?.tier ?? "").toLowerCase();
    if (!(tier in plans)) return reply({ error: "Choose Premium or Elite." }, 400);
    const plan = plans[tier as keyof typeof plans];
    const db = createClient(url, serviceKey, { auth: { persistSession: false } });
    const referenceId = "MM" + crypto.randomUUID().replaceAll("-", "");
    const anchor = new Date(); anchor.setDate(Math.min(anchor.getDate(), 28)); anchor.setMinutes(anchor.getMinutes() + 2);
    const { error: saveError } = await db.from("mm_subscriptions").upsert({ user_id: user.id, tier, status: "pending", reference_id: referenceId, amount_idr: plan.amount, currency: "IDR", updated_at: new Date().toISOString() }, { onConflict: "user_id" });
    if (saveError) throw saveError;
    const email = user.email ?? "";
    const name = (email.split("@")[0] || "MoneyMap User").replace(/[^a-zA-Z0-9 ]/g, " ").slice(0, 50) || "MoneyMap User";
    const appUrl = Deno.env.get("APP_BASE_URL") ?? "https://serifxvi-cloud.github.io/moneymap/";
    const payload = {
      reference_id: referenceId, session_type: "SUBSCRIPTION", mode: "PAYMENT_LINK", amount: plan.amount, currency: "IDR", country: "ID", locale: "id",
      customer: { reference_id: "MMUSER" + user.id.replaceAll("-", ""), type: "INDIVIDUAL", email, individual_detail: { given_names: name } },
      description: plan.name + " — monthly subscription",
      subscription: { schedule: { interval: "MONTH", interval_count: 1, anchor_date: anchor.toISOString(), retry_interval: "DAY", retry_interval_count: 1, total_retry: 3, failed_attempt_notifications: [1,2,3] }, immediate_payment: true, failed_cycle_action: "RESUME", payment_link_for_failed_attempt: true },
      success_return_url: appUrl + "?payment=return&plan=" + tier, cancel_return_url: appUrl + "?payment=cancelled"
    };
    const response = await fetch("https://api.xendit.co/sessions", { method: "POST", headers: { Authorization: "Basic " + btoa(xenditKey + ":"), "api-version": "2022-07-31", "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    const result = await response.json();
    if (!response.ok) { await db.from("mm_subscriptions").update({ status: "inactive", updated_at: new Date().toISOString() }).eq("reference_id", referenceId); return reply({ error: result?.message ?? "Unable to start checkout." }, response.status); }
    await db.from("mm_subscriptions").update({ xendit_session_id: result.payment_session_id ?? null, xendit_plan_id: result.recurring_plan_id ?? null, updated_at: new Date().toISOString() }).eq("reference_id", referenceId);
    if (!result.payment_link_url) throw new Error("Xendit did not return a checkout URL.");
    return reply({ checkout_url: result.payment_link_url });
  } catch (e) { console.error(e); return reply({ error: e instanceof Error ? e.message : "Checkout error." }, 500); }
});