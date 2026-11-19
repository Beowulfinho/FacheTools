-- Tracker: catálogo de ejercicios + protocolos en modo "Libre".
--  * tratamientos_catalogo = ejercicio con toda su información (nombre, descripción, accesorio, series/repeticiones).
--  * tratamientos_ejercicios sigue siendo "ejercicio dentro de una patología" y apunta al catálogo con catalogo_id
--    (conserva copias de los textos para la app vieja en caché; la app nueva las mantiene sincronizadas).
--  * tratamientos_patologias.modo: 'esquema' (base + extras por hito, lo de siempre) o 'libre' (ejercicios repartidos
--    a mano en las sesiones 1..15; se guardan como tipo 'libre' con sesion_hito = número de sesión).
-- No destructiva: las filas actuales no cambian, solo se agrupan en el catálogo.
create table if not exists public.tratamientos_catalogo (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre text not null,
  descripcion text,
  accesorio text,
  dosis text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists tratamientos_catalogo_user_idx on public.tratamientos_catalogo (user_id);

alter table public.tratamientos_catalogo enable row level security;
drop policy if exists tratamientos_catalogo_owner_all on public.tratamientos_catalogo;
create policy tratamientos_catalogo_owner_all on public.tratamientos_catalogo
  for all
  using (auth.uid() = user_id or public.tratamientos_es_admin())
  with check (auth.uid() = user_id or public.tratamientos_es_admin());

alter table public.tratamientos_patologias
  add column if not exists modo text not null default 'esquema';
alter table public.tratamientos_patologias drop constraint if exists tratamientos_patologias_modo_check;
alter table public.tratamientos_patologias add constraint tratamientos_patologias_modo_check check (modo in ('esquema', 'libre'));

alter table public.tratamientos_ejercicios
  add column if not exists catalogo_id uuid references public.tratamientos_catalogo(id) on delete set null;
create index if not exists tratamientos_ejercicios_catalogo_idx on public.tratamientos_ejercicios (catalogo_id);
alter table public.tratamientos_ejercicios drop constraint if exists tratamientos_ejercicios_tipo_check;
alter table public.tratamientos_ejercicios add constraint tratamientos_ejercicios_tipo_check check (tipo in ('base', 'extra', 'libre'));

-- Backfill (solo si el catálogo está vacío): un ejercicio de catálogo por cada combinación idéntica de textos.
insert into public.tratamientos_catalogo (user_id, nombre, descripcion, accesorio, dosis)
select distinct on (user_id, nombre, coalesce(descripcion, ''), coalesce(accesorio, ''), coalesce(dosis, ''))
       user_id, nombre, descripcion, accesorio, dosis
from public.tratamientos_ejercicios
where deleted_at is null
  and not exists (select 1 from public.tratamientos_catalogo)
order by user_id, nombre, coalesce(descripcion, ''), coalesce(accesorio, ''), coalesce(dosis, '');

update public.tratamientos_ejercicios e
set catalogo_id = c.id
from public.tratamientos_catalogo c
where e.catalogo_id is null and c.deleted_at is null and c.user_id = e.user_id and c.nombre = e.nombre
  and coalesce(c.descripcion, '') = coalesce(e.descripcion, '')
  and coalesce(c.accesorio, '') = coalesce(e.accesorio, '')
  and coalesce(c.dosis, '') = coalesce(e.dosis, '');
