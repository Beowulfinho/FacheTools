-- Tracker: modo admin. Una cuenta listada en tratamientos_admins puede ver y editar las filas de las demás
-- cuentas (la app le deja elegir a cuál mirar). El resto de cuentas sigue viendo solo lo suyo.
create table if not exists public.tratamientos_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.tratamientos_admins enable row level security; -- sin políticas: solo lo leen las funciones de abajo

insert into public.tratamientos_admins (user_id)
select id from auth.users where email = 'andresjuanfr@gmail.com'
on conflict do nothing;

create or replace function public.tratamientos_es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.tratamientos_admins where user_id = auth.uid());
$$;

-- Cuentas con sus totales, solo para admins (para el selector "Ver como").
create or replace function public.tratamientos_listar_usuarios()
returns table (id uuid, email text, total bigint)
language sql stable security definer set search_path = public, auth as $$
  select u.id, u.email::text, (select count(*) from public.tratamientos_pacientes p where p.user_id = u.id)
  from auth.users u
  where public.tratamientos_es_admin()
  order by u.email;
$$;

revoke all on function public.tratamientos_es_admin() from public, anon;
revoke all on function public.tratamientos_listar_usuarios() from public, anon;
grant execute on function public.tratamientos_es_admin() to authenticated;
grant execute on function public.tratamientos_listar_usuarios() to authenticated;

drop policy if exists tratamientos_pacientes_owner_all on public.tratamientos_pacientes;
create policy tratamientos_pacientes_owner_all on public.tratamientos_pacientes
  for all
  using (auth.uid() = user_id or public.tratamientos_es_admin())
  with check (auth.uid() = user_id or public.tratamientos_es_admin());
