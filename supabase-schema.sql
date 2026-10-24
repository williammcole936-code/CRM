-- ID Vault CRM — Supabase setup
-- Run this whole file in Supabase Dashboard > SQL Editor.
-- This schema keeps each team lead's rows private from other team leads.
-- IMPORTANT: The "password" field stores the external account password entered into the portal.
-- Access is restricted by RLS, but authorized admins and the owning team lead can read it.
-- For highly sensitive credentials, consider storing only a reference or using a dedicated secrets vault.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'team_lead' check (role in ('admin','team_lead')),
  created_at timestamptz not null default now()
);

create table if not exists public.id_entries (
  id uuid primary key default gen_random_uuid(),
  rar_file_number text not null,
  user_name text not null default '',
  uid text not null default '',
  password text not null default '',
  reason text not null default '',
  response text not null default '',
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists id_entries_created_by_idx on public.id_entries(created_by);
create index if not exists id_entries_rar_idx on public.id_entries(rar_file_number);
create index if not exists id_entries_uid_idx on public.id_entries(uid);
create index if not exists id_entries_created_at_idx on public.id_entries(created_at desc);

alter table public.profiles enable row level security;
alter table public.id_entries enable row level security;

-- Helper checks profile role from the current authenticated user's profile.
create or replace function public.current_user_role()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.current_user_role() = 'admin', false)
$$;

revoke all on function public.current_user_role() from public;
revoke all on function public.is_admin() from public;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Profiles readable by self or admin" on public.profiles;
create policy "Profiles readable by self or admin"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Users can read own entries and admins all" on public.id_entries;
create policy "Users can read own entries and admins all"
on public.id_entries for select to authenticated
using (created_by = auth.uid() or public.is_admin());

drop policy if exists "Team leads can insert own entries" on public.id_entries;
create policy "Team leads can insert own entries"
on public.id_entries for insert to authenticated
with check (created_by = auth.uid() or public.is_admin());

drop policy if exists "Users can update own entries and admins all" on public.id_entries;
create policy "Users can update own entries and admins all"
on public.id_entries for update to authenticated
using (created_by = auth.uid() or public.is_admin())
with check (created_by = auth.uid() or public.is_admin());

drop policy if exists "Admins can delete entries" on public.id_entries;
create policy "Admins can delete entries"
on public.id_entries for delete to authenticated
using (public.is_admin());

-- Keep updated_at current on edits.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists id_entries_set_updated_at on public.id_entries;
create trigger id_entries_set_updated_at
before update on public.id_entries
for each row execute function public.set_updated_at();

-- Keep team_lead_name in sync for the admin table without exposing profile details
-- to other team leads. This function runs with its owner's permissions.
create or replace function public.get_entry_team_lead_name(profile_id uuid)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select full_name from public.profiles where id = profile_id
$$;
revoke all on function public.get_entry_team_lead_name(uuid) from public;
grant execute on function public.get_entry_team_lead_name(uuid) to authenticated;

-- Expose a computed team_lead_name via a view. The front end currently queries the table
-- directly; for displaying team lead names, add a team_lead_name column or use the optional
-- view below. Simpler approach: add a cached column populated by trigger.
alter table public.id_entries add column if not exists team_lead_name text not null default '';

create or replace function public.fill_team_lead_name()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select full_name into new.team_lead_name from public.profiles where id = new.created_by;
  return new;
end;
$$;
drop trigger if exists id_entries_fill_team_lead_name on public.id_entries;
create trigger id_entries_fill_team_lead_name
before insert or update of created_by on public.id_entries
for each row execute function public.fill_team_lead_name();


-- Automatically create a Team Lead profile for every public sign-up.
-- Public clients cannot choose or update their role; role always defaults to team_lead.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'team_lead'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Set up users:
-- 1) Supabase Dashboard > Authentication > Users > Add user.
-- 2) Copy the user's UUID.
-- 3) Run ONE insert below per account, replacing UUID and details.
-- First admin:
-- insert into public.profiles (id, full_name, role)
-- values ('PASTE_AUTH_USER_UUID', 'Admin Name', 'admin');
-- Team lead:
-- insert into public.profiles (id, full_name, role)
-- values ('PASTE_AUTH_USER_UUID', 'Team Lead Name', 'team_lead');
--
-- Do not let the public client change its own role. Admin role assignment should be done
-- only through the Supabase dashboard SQL editor by a trusted project owner.
