-- MoneyMap Social community board
-- Run this once in Supabase SQL Editor for project dmapwfwltcfsmqgrvrxq.
create table if not exists public.moneymap_blog_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default 'MoneyMap member',
  author_tier text not null default 'basic' check (author_tier in ('basic','plus','premium')),
  is_admin boolean not null default false,
  body text not null check (char_length(body) between 1 and 1200),
  created_at timestamptz not null default now()
);

alter table public.moneymap_blog_posts enable row level security;

create or replace function public.moneymap_blog_set_author()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_email text;
begin
  select lower(email) into account_email from auth.users where id = new.user_id;
  if account_email is null or auth.uid() is distinct from new.user_id then
    raise exception 'Invalid community author.';
  end if;
  new.author_name := split_part(account_email, '@', 1) || '@gmail.com';
  new.is_admin := account_email = 'serifxvi@gmail.com';
  if new.author_tier not in ('basic','plus','premium') then
    new.author_tier := 'basic';
  end if;
  new.body := btrim(new.body);
  if char_length(new.body) < 1 or char_length(new.body) > 1200 then
    raise exception 'Post must be between 1 and 1200 characters.';
  end if;
  return new;
end;
$$;

drop trigger if exists moneymap_blog_author_guard on public.moneymap_blog_posts;
create trigger moneymap_blog_author_guard
before insert on public.moneymap_blog_posts
for each row execute function public.moneymap_blog_set_author();

drop policy if exists "Anyone can read MoneyMap community posts" on public.moneymap_blog_posts;
create policy "Anyone can read MoneyMap community posts"
on public.moneymap_blog_posts for select
to anon, authenticated
using (true);

drop policy if exists "Signed-in users can publish their own community posts" on public.moneymap_blog_posts;
create policy "Signed-in users can publish their own community posts"
on public.moneymap_blog_posts for insert
to authenticated
with check (auth.uid() = user_id);

revoke all on public.moneymap_blog_posts from public;
revoke all on public.moneymap_blog_posts from anon;
grant select on public.moneymap_blog_posts to anon, authenticated;
grant insert on public.moneymap_blog_posts to authenticated;
