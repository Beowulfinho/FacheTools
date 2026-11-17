-- Tracker: pacientes y paquetes como objetos distintos.
--  * tratamientos_personas = el paciente (nombre, patología, informe).
--  * tratamientos_pacientes sigue siendo el paquete (grupo de sesiones) y apunta a su paciente con persona_id.
-- No destructiva: las filas actuales se agrupan por nombre (sin tildes/mayúsculas) y las columnas viejas se conservan.
create table if not exists public.tratamientos_personas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre text not null,
  patologia_id uuid references public.tratamientos_patologias(id) on delete set null,
  informe boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists tratamientos_personas_user_idx on public.tratamientos_personas (user_id);

alter table public.tratamientos_personas enable row level security;
drop policy if exists tratamientos_personas_owner_all on public.tratamientos_personas;
create policy tratamientos_personas_owner_all on public.tratamientos_personas
  for all
  using (auth.uid() = user_id or public.tratamientos_es_admin())
  with check (auth.uid() = user_id or public.tratamientos_es_admin());

alter table public.tratamientos_pacientes
  add column if not exists persona_id uuid references public.tratamientos_personas(id) on delete cascade;
create index if not exists tratamientos_pacientes_persona_idx on public.tratamientos_pacientes (persona_id);

-- Clave de nombre equivalente a nameKey() de la app.
create or replace function public.tratamientos_name_key(n text) returns text
language sql immutable as $$
  select trim(regexp_replace(translate(lower(n), 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'), '\s+', ' ', 'g'));
$$;

-- Backfill (solo si todavía no se hizo): una persona por nombre y cuenta, con la patología/informe del paquete más reciente.
insert into public.tratamientos_personas (user_id, nombre, patologia_id, informe, deleted_at)
select user_id, nombre, patologia_id, informe,
       case when any_active then null else last_del end
from (
  select distinct on (user_id, public.tratamientos_name_key(nombre))
         user_id, nombre, patologia_id, informe,
         bool_or(deleted_at is null) over (partition by user_id, public.tratamientos_name_key(nombre)) as any_active,
         max(deleted_at) over (partition by user_id, public.tratamientos_name_key(nombre)) as last_del
  from public.tratamientos_pacientes
  where persona_id is null
  order by user_id, public.tratamientos_name_key(nombre), (deleted_at is null) desc, fecha_fin desc
) x
where not exists (select 1 from public.tratamientos_personas);

update public.tratamientos_pacientes p
set persona_id = q.id
from public.tratamientos_personas q
where p.persona_id is null and q.user_id = p.user_id
  and public.tratamientos_name_key(q.nombre) = public.tratamientos_name_key(p.nombre);
