-- App Tratamientos (fisioterapeuta): lista de usuarios con la fecha en que termina su tratamiento.
-- Mismo patrón de RLS que tareas_tasks: cada cuenta solo ve y edita sus propias filas.
create table if not exists public.tratamientos_pacientes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre text not null,
  fecha_fin date not null,
  notas text,
  terminado boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tratamientos_pacientes_user_fecha_idx
  on public.tratamientos_pacientes (user_id, fecha_fin);

alter table public.tratamientos_pacientes enable row level security;

drop policy if exists tratamientos_pacientes_owner_all on public.tratamientos_pacientes;
create policy tratamientos_pacientes_owner_all on public.tratamientos_pacientes
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
