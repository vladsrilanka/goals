-- Настройка базы для дашборда «Курс на Уругвай»
-- Вставь целиком в Supabase → SQL Editor → Run

-- 1) Синхронизация по секретному ключу (без входа)
create table if not exists public.goals_dashboards (
  k text primary key,
  data jsonb not null,
  updated bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.goals_dashboards enable row level security;

create or replace function public.goals_get(p_k text)
returns jsonb language sql security definer set search_path = public as $$
  select data from public.goals_dashboards where k = p_k;
$$;

create or replace function public.goals_set(p_k text, p_data jsonb, p_updated bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if length(p_k) < 24 then raise exception 'key too short'; end if;
  if pg_column_size(p_data) > 400000 then raise exception 'payload too large'; end if;
  insert into public.goals_dashboards as t (k, data, updated, updated_at)
  values (p_k, p_data, p_updated, now())
  on conflict (k) do update
    set data = excluded.data, updated = excluded.updated, updated_at = now()
    where t.updated <= excluded.updated;
end;
$$;

revoke all on function public.goals_get(text) from public;
revoke all on function public.goals_set(text, jsonb, bigint) from public;
grant execute on function public.goals_get(text) to anon, authenticated;
grant execute on function public.goals_set(text, jsonb, bigint) to anon, authenticated;

-- 2) Хранение по аккаунту (Google / почта)
create table if not exists public.user_dashboards (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  updated bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.user_dashboards enable row level security;

create policy "own_select" on public.user_dashboards
  for select using (auth.uid() = user_id);
create policy "own_insert" on public.user_dashboards
  for insert with check (auth.uid() = user_id);
create policy "own_update" on public.user_dashboards
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
