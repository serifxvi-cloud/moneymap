import { createClient } from "npm:@supabase/supabase-js@2";
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  try {
    const expected = Deno.env.get("XENDIT_WEBHOOK_TOKEN"), received = req.headers.get("x-callback-token");
    if (!expected || !received || received !== expected) return new Response("Unauthorized", { status: 401 });
    const event = await req.json(), type = String(event?.event ?? ""), data = event?.data ?? {}, ref = String(data?.reference_id ?? "");
    if (!ref || !type) return new Response("Invalid event", { status: 400 });
    const allowed = ["recurring.plan.activated","recurring.plan.inactivated","recurring.cycle.succeeded","recurring.cycle.failed","recurring.cycle.retrying"];
    if (!allowed.includes(type)) return new Response("Ignored", { status: 200 });
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const key = type + ":" + String(data?.id ?? data?.plan_id ?? (ref + ":" + (event?.created ?? "")));
    const { error } = await db.rpc("mm_apply_xendit_subscription_event", { p_event_key: key, p_event_type: type, p_reference_id: ref, p_plan_id: data?.plan_id ?? data?.id ?? null, p_cycle_id: data?.id ?? null, p_event_created: event?.created ?? new Date().toISOString() });
    if (error) throw error;
    return new Response("OK", { status: 200 });
  } catch (e) { console.error(e); return new Response("Webhook processing failed", { status: 500 }); }
});