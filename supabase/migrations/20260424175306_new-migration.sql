create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references auth.users(id) on delete cascade,
  email text,
  username text unique,
  first_name text,
  last_name text,
  gender text,
  birth_date text,
  ethnicity text,
  relationship_status text,
  occupation text,
  bio text,
  location text,
  height text,
  weight text,
  profile_picture text,
  cover_picture text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create table if not exists public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_username text,
  sender_name text,
  post_format text not null,
  text_content text,
  background_color text,
  image_content text,
  audio_content text,
  video_content text,
  is_reply boolean not null default false,
  previous_post_id uuid references public.posts(id) on delete cascade,
  is_published boolean not null default true,
  scheduled_at timestamptz,
  share_count int not null default 0,
  like_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

create index if not exists posts_sender_id_idx on public.posts(sender_id);
create index if not exists posts_previous_post_id_idx on public.posts(previous_post_id);
create index if not exists posts_created_at_idx on public.posts(created_at desc);

create table if not exists public.media_files (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  media_type text not null,
  image_file text,
  audio_file text,
  video_file text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists media_files_set_updated_at on public.media_files;
create trigger media_files_set_updated_at
before update on public.media_files
for each row execute function public.set_updated_at();

create index if not exists media_files_post_id_idx on public.media_files(post_id);

create table if not exists public.post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create index if not exists post_reactions_post_id_idx on public.post_reactions(post_id);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx on public.notifications(user_id);
create index if not exists notifications_created_at_idx on public.notifications(created_at desc);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists conversations_created_by_idx on public.conversations(created_by);

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index if not exists conversation_participants_user_id_idx on public.conversation_participants(user_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message_type text not null default 'text',
  text_content text,
  media_url text,
  is_reply boolean not null default false,
  previous_message_id uuid references public.messages(id) on delete set null,
  previous_message_content text,
  previous_message_sender_id uuid references auth.users(id) on delete set null,
  status text not null default 'sent',
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_id_created_at_idx on public.messages(conversation_id, created_at desc);
create index if not exists messages_sender_id_idx on public.messages(sender_id);

alter table public.profiles enable row level security;
alter table public.user_follows enable row level security;
alter table public.posts enable row level security;
alter table public.media_files enable row level security;
alter table public.post_reactions enable row level security;
alter table public.notifications enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert
on public.profiles
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update
on public.profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists user_follows_select on public.user_follows;
create policy user_follows_select
on public.user_follows
for select
to authenticated
using (true);

drop policy if exists user_follows_insert on public.user_follows;
create policy user_follows_insert
on public.user_follows
for insert
to authenticated
with check (follower_id = auth.uid());

drop policy if exists user_follows_update on public.user_follows;
create policy user_follows_update
on public.user_follows
for update
to authenticated
using (follower_id = auth.uid())
with check (follower_id = auth.uid());

drop policy if exists posts_select on public.posts;
create policy posts_select
on public.posts
for select
to authenticated
using (true);

drop policy if exists posts_insert on public.posts;
create policy posts_insert
on public.posts
for insert
to authenticated
with check (sender_id = auth.uid());

drop policy if exists posts_update_own on public.posts;
create policy posts_update_own
on public.posts
for update
to authenticated
using (sender_id = auth.uid())
with check (sender_id = auth.uid());

drop policy if exists media_files_select on public.media_files;
create policy media_files_select
on public.media_files
for select
to authenticated
using (true);

drop policy if exists media_files_insert on public.media_files;
create policy media_files_insert
on public.media_files
for insert
to authenticated
with check (
  exists (
    select 1
    from public.posts p
    where p.id = media_files.post_id
      and p.sender_id = auth.uid()
  )
);

drop policy if exists post_reactions_select on public.post_reactions;
create policy post_reactions_select
on public.post_reactions
for select
to authenticated
using (true);

drop policy if exists post_reactions_insert on public.post_reactions;
create policy post_reactions_insert
on public.post_reactions
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists post_reactions_update on public.post_reactions;
create policy post_reactions_update
on public.post_reactions
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists notifications_select on public.notifications;
create policy notifications_select
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists notifications_insert on public.notifications;
create policy notifications_insert
on public.notifications
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists conversations_select on public.conversations;
create policy conversations_select
on public.conversations
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = conversations.id
      and cp.user_id = auth.uid()
  )
);

drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert
on public.conversations
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists conversation_participants_select on public.conversation_participants;
create policy conversation_participants_select
on public.conversation_participants
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_participants me
    where me.conversation_id = conversation_participants.conversation_id
      and me.user_id = auth.uid()
  )
);

drop policy if exists conversation_participants_insert on public.conversation_participants;
create policy conversation_participants_insert
on public.conversation_participants
for insert
to authenticated
with check (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_participants.conversation_id
      and c.created_by = auth.uid()
  )
);

drop policy if exists messages_select on public.messages;
create policy messages_select
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
      and cp.user_id = auth.uid()
  )
);

drop policy if exists messages_insert on public.messages;
create policy messages_insert
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
      and cp.user_id = auth.uid()
  )
);

drop policy if exists messages_update on public.messages;
create policy messages_update
on public.messages
for update
to authenticated
using (
  exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
      and cp.user_id = auth.uid()
  )
);

revoke all on public.posts from anon, authenticated;
revoke all on public.messages from anon, authenticated;
revoke all on public.conversation_participants from anon, authenticated;
revoke all on public.conversations from anon, authenticated;

grant select, insert on public.posts to authenticated;
grant update (share_count, like_count) on public.posts to authenticated;

grant select, insert on public.conversations to authenticated;
grant select, insert on public.conversation_participants to authenticated;

grant select, insert on public.messages to authenticated;
grant update (status) on public.messages to authenticated;

insert into storage.buckets (id, name, public)
values
  ('profile_pictures', 'profile_pictures', true),
  ('post_media', 'post_media', true),
  ('chat_media', 'chat_media', true)
on conflict (id) do update set public = excluded.public;

alter publication supabase_realtime add table public.messages;
