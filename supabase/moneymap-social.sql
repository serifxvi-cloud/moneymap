-- MoneyMap Social: complete, repeatable database + media setup
-- Run the ENTIRE script in Supabase Dashboard > SQL Editor > New query.
create extension if not exists pgcrypto;

create table if not exists public.moneymap_blog_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default 'MoneyMap member',
  author_tier text not null default 'basic' check (author_tier in ('basic','plus','premium')),
  is_admin boolean not null default false,
  body text not null default '',
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  constraint moneymap_blog_body_length check (char_length(body) <= 1200),
  constraint moneymap_blog_attachments_array check (jsonb_typeof(attachments) = 'array')
);

alter table public.moneymap_blog_posts add column if not exists author_name text not null default 'MoneyMap member';
alter table public.moneymap_blog_posts add column if not exists author_tier text not null default 'basic';
alter table public.moneymap_blog_posts add column if not exists is_admin boolean not null default false;
alter table public.moneymap_blog_posts add column if not exists body text not null default '';
alter table public.moneymap_blog_posts add column if not exists attachments jsonb not null default '[]'::jsonb;
alter table public.moneymap_blog_posts add column if not exists created_at timestamptz not null default now();

alter table public.moneymap_blog_posts drop constraint if exists moneymap_blog_posts_body_check;
alter table public.moneymap_blog_posts drop constraint if exists moneymap_blog_body_length;
alter table public.moneymap_blog_posts add constraint moneymap_blog_body_length check (char_length(body) <= 1200);
alter table public.moneymap_blog_posts enable row level security;

create or replace function public.moneymap_blog_set_author()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare account_email text;
begin
  select lower(email) into account_email from auth.users where id = new.user_id;
  if account_email is null or auth.uid() is distinct from new.user_id then
    raise exception 'Invalid community author.';
  end if;
  new.author_name := split_part(account_email, '@', 1) || '@gmail.com';
  new.is_admin := account_email = 'serifxvi@gmail.com';
  new.body := btrim(coalesce(new.body, ''));
  if char_length(new.body) > 1200 then raise exception 'Post text is too long.'; end if;
  if new.attachments is null or jsonb_typeof(new.attachments) <> 'array' then
    raise exception 'Invalid post attachments.';
  end if;
  if char_length(new.body) = 0 and jsonb_array_length(new.attachments) = 0 then
    raise exception 'Add text or an attachment before publishing.';
  end if;
  return new;
end;
$$;

drop trigger if exists moneymap_blog_author_guard on public.moneymap_blog_posts;
create trigger moneymap_blog_author_guard before insert on public.moneymap_blog_posts
for each row execute function public.moneymap_blog_set_author();

drop policy if exists "Anyone can read MoneyMap community posts" on public.moneymap_blog_posts;
create policy "Anyone can read MoneyMap community posts"
on public.moneymap_blog_posts for select to anon, authenticated using (true);

drop policy if exists "Signed-in users can publish their own community posts" on public.moneymap_blog_posts;
create policy "Signed-in users can publish their own community posts"
on public.moneymap_blog_posts for insert to authenticated
with check (auth.uid() = user_id);

grant usage on schema public to anon, authenticated;
grant select on public.moneymap_blog_posts to anon, authenticated;
grant insert on public.moneymap_blog_posts to authenticated;

-- Enable Postgres Changes so new posts arrive without manual refresh.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'moneymap_blog_posts'
  ) then
    alter publication supabase_realtime add table public.moneymap_blog_posts;
  end if;
exception when undefined_object then
  raise notice 'supabase_realtime publication is not available in this project. Enable Realtime for moneymap_blog_posts in Database > Publications.';
end $$;

-- Public-read media bucket. Uploads remain restricted to each signed-in user's folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-media', 'community-media', true, 104857600,
  array['image/jpeg','image/png','image/webp','image/gif','image/avif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Community media is publicly readable" on storage.objects;
create policy "Community media is publicly readable" on storage.objects
for select to anon, authenticated using (bucket_id = 'community-media');

drop policy if exists "Users upload community media to own folder" on storage.objects;
create policy "Users upload community media to own folder" on storage.objects
for insert to authenticated
with check (bucket_id = 'community-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users update own community media" on storage.objects;
create policy "Users update own community media" on storage.objects
for update to authenticated
using (bucket_id = 'community-media' and owner = auth.uid())
with check (bucket_id = 'community-media' and owner = auth.uid());

drop policy if exists "Users delete own community media" on storage.objects;
create policy "Users delete own community media" on storage.objects
for delete to authenticated
using (bucket_id = 'community-media' and owner = auth.uid());

notify pgrst, 'reload schema';
