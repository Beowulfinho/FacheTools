-- Antecipações: pessoa propia (la antecipación puede ser responsabilidad de otra persona que la compra).
-- null = hereda la persona de la compra.
alter table public.antecipacoes add column if not exists pessoa_id uuid references public.pessoas(id) on delete set null;
comment on column public.antecipacoes.pessoa_id is 'persona responsable de la antecipacion; null = la de la compra';
