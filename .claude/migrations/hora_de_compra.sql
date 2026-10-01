-- Hora opcional en los gastos registrados: compras de crédito, movimientos de débito y adiantamentos de fatura.
alter table public.compras add column if not exists hora time;
alter table public.debito add column if not exists hora time;
alter table public.adiantamentos add column if not exists hora time;
comment on column public.compras.hora is 'hora de la compra (opcional)';
comment on column public.debito.hora is 'hora del movimiento (opcional)';
comment on column public.adiantamentos.hora is 'hora del pago adelantado (opcional)';
