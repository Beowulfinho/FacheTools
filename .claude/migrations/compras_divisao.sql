-- Compras divididas entre dos personas. null = compra de una sola persona.
-- Formato: [{"pessoa_id": uuid, "parcelas": [1,2,3] | null (todas), "pct": 50}, ...]
alter table public.compras add column if not exists divisao jsonb;
comment on column public.compras.divisao is 'division entre personas: [{pessoa_id, parcelas|null, pct}]; null = sin division';
