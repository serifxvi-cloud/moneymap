-- MoneyMap cloud account storage. Run this ONCE in Supabase Dashboard > SQL Editor.
-- Each account can read/write only the row whose user_id matches its auth.uid().
create table if not exists public.moneymap_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.moneymap_profiles enable row level security;

revoke all on table public.moneymap_profiles from public, anon, authenticated;
grant select, insert, update on table public.moneymap_profiles to authenticated;

drop policy if exists "MoneyMap users can read their own row" on public.moneymap_profiles;
drop policy if exists "MoneyMap users can create their own row" on public.moneymap_profiles;
drop policy if exists "MoneyMap users can update their own row" on public.moneymap_profiles;

create policy "MoneyMap users can read their own row"
on public.moneymap_profiles for select to authenticated
using ((select auth.uid()) = user_id);

create policy "MoneyMap users can create their own row"
on public.moneymap_profiles for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "MoneyMap users can update their own row"
on public.moneymap_profiles for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
