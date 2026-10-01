-- "Hacer cuentas" paso 1 (cargar todo): una fila por mes y por ítem a conferir.
--   cartao_id NOT NULL  -> factura de una tarjeta (valor_real = total de la factura del banco)
--   cartao_id NULL      -> bloque de débito del mes (sin valor_real; solo marca "completo")
create table if not exists public.cuentas_mes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  mes text not null check (mes ~ '^\d{4}-\d{2}$'),
  cartao_id uuid references public.cartoes(id) on delete cascade,
  valor_real numeric,
  conferido boolean not null default false,
  conferido_at timestamptz,
  created_at timestamptz not null default now()
);

-- Un solo registro por (mes, tarjeta) y uno por mes para débito.
create unique index if not exists cuentas_mes_unique
  on public.cuentas_mes (mes, coalesce(cartao_id, '00000000-0000-0000-0000-000000000000'::uuid));

alter table public.cuentas_mes enable row level security;

create policy "household rows" on public.cuentas_mes
  for all using (is_household_member(user_id)) with check (is_household_member(user_id));
