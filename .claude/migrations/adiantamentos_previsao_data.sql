-- Adiantamentos de fatura: ahora se crean con tarjeta + valor + fecha de pago (el mes de origen y la fatura
-- que abaten se derivan de la fecha) y pueden marcarse como previsão.
alter table public.adiantamentos add column if not exists previsao boolean not null default false;
alter table public.adiantamentos add column if not exists data date;
comment on column public.adiantamentos.previsao is 'true = hipotetico: solo se ve y afecta en la pagina Previsoes';
comment on column public.adiantamentos.data is 'fecha del pago adelantado; de ella se derivan mes_origem y mes_destino (fatura abierta de la tarjeta en esa fecha)';
