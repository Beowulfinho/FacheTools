-- 1. Household model: a household groups auth users who share financial data.
create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

alter table public.households enable row level security;
alter table public.household_members enable row level security;

create policy "select own household" on public.households
  for select using (
    id in (select household_id from public.household_members where user_id = auth.uid())
  );

create policy "select own membership" on public.household_members
  for select using (auth.uid() = user_id);

-- 2. Seed one household containing both existing accounts.
with new_household as (
  insert into public.households (name) values ('Casa') returning id
)
insert into public.household_members (household_id, user_id)
select new_household.id, u.id
from new_household, auth.users u
where u.email in ('andresjuanfr@gmail.com', 'gabb.cavalheiro@gmail.com');

-- 3. Membership check used by RLS policies below. SECURITY DEFINER so it can see
-- household_members rows belonging to the *other* user, which the caller's own
-- RLS-restricted view would not otherwise expose.
create or replace function public.is_household_member(target_user uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.household_members hm1
    join public.household_members hm2 on hm1.household_id = hm2.household_id
    where hm1.user_id = auth.uid() and hm2.user_id = target_user
  );
$$;

grant execute on function public.is_household_member(uuid) to authenticated;

-- 4. Re-scope the previously per-user-only tables to "any member of the same household".
drop policy "own rows" on public.pessoas;
create policy "household rows" on public.pessoas
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

drop policy "own rows" on public.cartoes;
create policy "household rows" on public.cartoes
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

drop policy "own rows" on public.tipos;
create policy "household rows" on public.tipos
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

drop policy "own rows" on public.compras;
create policy "household rows" on public.compras
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

drop policy "own rows" on public.debito;
create policy "household rows" on public.debito
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

drop policy "own rows" on public.diario;
create policy "household rows" on public.diario
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

drop policy "Users manage their own antecipacoes" on public.antecipacoes;
create policy "household rows" on public.antecipacoes
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

-- 5. reservas/adiantamentos had no ownership column at all (policy was literally "true",
-- i.e. open to every authenticated user in the project, not just this household). Give them
-- a user_id like every other table, backfill existing rows to the account that created them,
-- then scope by household like everything else.
alter table public.reservas add column if not exists user_id uuid;
update public.reservas set user_id = (select id from auth.users where email = 'andresjuanfr@gmail.com')
  where user_id is null;
alter table public.reservas alter column user_id set default auth.uid();
alter table public.reservas alter column user_id set not null;
drop policy "reservas_owner" on public.reservas;
create policy "household rows" on public.reservas
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));

alter table public.adiantamentos add column if not exists user_id uuid;
update public.adiantamentos set user_id = (select id from auth.users where email = 'andresjuanfr@gmail.com')
  where user_id is null;
alter table public.adiantamentos alter column user_id set default auth.uid();
alter table public.adiantamentos alter column user_id set not null;
drop policy "adiantamentos_owner" on public.adiantamentos;
create policy "household rows" on public.adiantamentos
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));
