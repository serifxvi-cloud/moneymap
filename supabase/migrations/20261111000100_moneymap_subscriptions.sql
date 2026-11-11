create table if not exists public.mm_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  tier text not null check (tier in ('premium','elite')),
  status text not null default 'pending' check (status in ('pending','active','past_due','canceled','inactive')),
  reference_id text not null unique,
  amount_idr integer not null check (amount_idr in (5000,10000)),
  currency text not null default 'IDR' check (currency = 'IDR'),
  xendit_session_id text,
  xendit_plan_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.mm_payment_events (
  event_key text primary key,
  event_type text not null,
  reference_id text not null,
  processed_at timestamptz not null default now()
);
alter table public.mm_subscriptions enable row level security;
alter table public.mm_payment_events enable row level security;
drop policy if exists "Users can read their own subscription" on public.mm_subscriptions;
create policy "Users can read their own subscription" on public.mm_subscriptions for select to authenticated using (auth.uid() = user_id);
revoke insert, update, delete on public.mm_subscriptions from anon, authenticated;
revoke all on public.mm_payment_events from anon, authenticated;

create or replace function public.mm_apply_xendit_subscription_event(
  p_event_key text, p_event_type text, p_reference_id text,
  p_plan_id text default null, p_cycle_id text default null,
  p_event_created timestamptz default now()
) returns void language plpgsql security definer set search_path = public as $$
declare inserted_count integer;
begin
  insert into public.mm_payment_events(event_key,event_type,reference_id)
  values(p_event_key,p_event_type,p_reference_id) on conflict(event_key) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count = 0 then return; end if;

  if p_event_type = 'recurring.plan.activated' then
    update public.mm_subscriptions set xendit_plan_id=coalesce(p_plan_id,xendit_plan_id),updated_at=now() where reference_id=p_reference_id;
  elsif p_event_type = 'recurring.cycle.succeeded' then
    update public.mm_subscriptions set status='active',xendit_plan_id=coalesce(p_plan_id,xendit_plan_id),
      current_period_start=coalesce(current_period_start,p_event_created,now()),
      current_period_end=greatest(coalesce(current_period_end,now()),now())+interval '1 month',updated_at=now()
      where reference_id=p_reference_id;
  elsif p_event_type in ('recurring.cycle.failed','recurring.cycle.retrying') then
    update public.mm_subscriptions set status=case when status='active' and current_period_end>now() then 'active' else 'past_due' end,updated_at=now() where reference_id=p_reference_id;
  elsif p_event_type = 'recurring.plan.inactivated' then
    update public.mm_subscriptions set status='canceled',updated_at=now() where reference_id=p_reference_id;
  end if;
end; $$;
revoke all on function public.mm_apply_xendit_subscription_event(text,text,text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.mm_apply_xendit_subscription_event(text,text,text,text,text,timestamptz) to service_role;
