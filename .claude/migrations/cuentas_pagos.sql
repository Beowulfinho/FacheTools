-- Cuentas como lista de pagos del mes: cada factura de tarjeta y cada gasto fijo puede marcarse pagado, y se
-- guarda el saldo de hoy en las cuentas para ver cuánto queda tras pagar lo pendiente.
--   item null                 -> tarjeta (cartao_id) o el débito del mes (cartao_id null)
--   item 'fijo:<desc>|<pers>' -> gasto fijo a pagar
--   item 'saldo'              -> saldo informado (valor_real); la fecha va en pago_em
alter table public.cuentas_mes add column if not exists item text;
alter table public.cuentas_mes add column if not exists pago boolean not null default false;
alter table public.cuentas_mes add column if not exists valor_pago numeric;
alter table public.cuentas_mes add column if not exists pago_em date;
drop index if exists public.cuentas_mes_unique;
create unique index cuentas_mes_unique on public.cuentas_mes (mes, coalesce(cartao_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(item, ''));
