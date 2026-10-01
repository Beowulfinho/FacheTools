-- Previsões: una fila marcada previsao=true es hipotética. El app la carga aparte y solo afecta la
-- proyección de la página Previsões; el resto de las pantallas no la ve.
alter table public.compras add column if not exists previsao boolean not null default false;
alter table public.debito add column if not exists previsao boolean not null default false;
alter table public.antecipacoes add column if not exists previsao boolean not null default false;
comment on column public.compras.previsao is 'true = hipotetico: solo se ve y afecta en la pagina Previsoes; el resto del app no lo carga';
comment on column public.debito.previsao is 'true = hipotetico: solo se ve y afecta en la pagina Previsoes; el resto del app no lo carga';
comment on column public.antecipacoes.previsao is 'true = hipotetico: solo se ve y afecta en la pagina Previsoes; el resto del app no lo carga';
