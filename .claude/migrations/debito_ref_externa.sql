-- Gastos de débito itemizados desde extractos bancarios: cada fila guarda el ID del movimiento
-- (columna "Identificador" del CSV de Nubank) para poder reimportar sin duplicar.
alter table public.debito add column if not exists ref_externa text;
create unique index if not exists debito_ref_externa_unique on public.debito (ref_externa) where ref_externa is not null;
comment on column public.debito.ref_externa is 'ID del movimiento en el extracto bancario (Nubank etc.). Presente = gasto de debito itemizado desde extracto; consume el diario del mes.';
