---
name: financas-app-context
description: >
  Provides deep context on the "Financas" app (Control de Cuentas) inside the FacheTools repo —
  a single-file vanilla-JS PWA backed by Supabase for tracking credit-card purchases (with
  installments), income/expenses, subscriptions, and shared-card reimbursements in a Brazilian
  household. Use this skill whenever the user asks about Financas/Finanças, "Control de Cuentas",
  FacheTools, or anything touching Financas/index.html, its Supabase tables (pessoas, cartoes,
  tipos, compras, debito, diario, antecipacoes, reservas, adiantamentos), the mãe/mae-mode
  read-only view, parcela/cuota logic, fatura/closing-date calculations, or Nubank CSV import —
  even if they don't name the app directly. Load this BEFORE editing Financas/index.html so
  changes fit the existing patterns instead of guessing at the architecture.
---

# Financas app context

## What this is

"Control de Cuentas" (short name "Finanças") is a personal/household finance tracker built as an
installable PWA. It lives at [`Financas/index.html`](../../../Financas/index.html) in this repo —
one ~270KB HTML file with all CSS and JS inline, no build step, no framework, no bundler. What you
see in the file is exactly what ships. `manifest.json` + the icon PNGs make it installable on a
phone home screen.

The repo also contains a sibling app, `Planes/` (trip planning), which is unrelated in UI but
**shares the same Supabase project** — see "Shared backend" below.

## Architecture at a glance

- **No backend code of its own.** All persistence goes straight from the browser to Supabase via
  `@supabase/supabase-js` (loaded from a CDN `<script>` tag). Look for `SUPABASE_URL` and
  `SUPABASE_ANON_KEY` near the top of the `<script>` block (search `Supabase client`).
- **Auth**: Supabase email/password (or magic link) auth. `currentUserEmail` tracks the signed-in
  user. All tables have `user_id` defaulting to `auth.uid()` and RLS enabled, so each signed-in
  user only ever sees their own rows — there's no server-side multi-tenant logic to reason about.
- **"mãe" read-only mode**: `window.READONLY_MAE` (set by a separate small HTML file that loads
  this same script) switches on `mae-mode`, which CSS-hides the Dashboard, Débito, Investimentos,
  and Limite tabs — a stripped view meant for a family member who should only see certain tabs.
  That loader file doesn't exist yet in the repo (only referenced in a code comment around line
  1637) — if asked to build it, keep it a thin wrapper that sets the flag and includes this same
  `index.html` logic rather than forking the file.
- **State**: a single in-memory `state` object per table (`state.compras`, `state.cartoes`, ...),
  populated by `loadEverything()` and re-rendered by page-specific `render*()` functions
  (`renderDashboard`, `renderList`, `renderCalendarioPage`, `renderLimitePage`,
  `renderAssinaturasPage`, ...). There's no virtual DOM — rendering rebuilds `innerHTML` chunks
  directly.
- **Money/date conventions**: dates are stored as "serial" day numbers internally
  (`serialToDate`/`dateInputToSerial`) for cheap arithmetic, then formatted for display/inputs.
  Amounts use `fmtBRL`/`parseAmountInput` for BRL formatting.

## Pages (bottom nav / top tabs, `data-page` attribute)

| data-page | Purpose |
|---|---|
| `dashboard` | Overview / balances |
| `tabela` (label "Credito") | Credit-card purchase ledger — the core table, with installments |
| `calendario` | Calendar view of what's due/charged per day |
| `limite` | Credit limit usage per card per month |
| `debito` (label "Ingresos/Salidas") | Direct income/expense entries (not on a card) |
| `investimentos` | Investments |

`Assinaturas` (subscriptions/recurring charges) is a related concept surfaced via
`renderAssinaturasPage`/`getActiveSubscriptions`, layered on top of `compras` rows tagged with a
recurring "tipo".

## Supabase schema (project `qdetwdneqncblxwylpyw`)

All tables below live in `public`, have RLS enabled, and (except `reservas`/`adiantamentos`) carry
`user_id uuid default auth.uid()`.

- **pessoas** — people sharing expenses: `nome`, `gera_ingresso` (bool — does this person's share
  count as incoming money to reconcile).
- **cartoes** — credit cards: `nome`, `vencimento` (due day), `fechamento` (statement closing
  day), `limite`.
- **tipos** — purchase categories/tags: `nome` (drives recurring/"assinatura" detection via
  `isAssinaturaTipo`).
- **compras** — the main ledger: `descricao`, `comerciante`, `pessoa_id`, `cartao_id`,
  `valor_total`, `parcelas` (number of installments), `data`, `tipo_id`, `cancelamento` (date, for
  a cancelled subscription), `out` (soft-delete/excluded flag).
- **debito** — non-card income/expense: `tipo`, `descricao`, `pessoa_id`, `valor`, `data`, `out`,
  `variacao` (bool).
- **diario** — a single running "daily allowance" value used by `getDiarioAmount`.
- **antecipacoes** — installment anticipations: `compra_id`, `mes`, `indices` (array — which
  installment indices were paid early), `valor`.
- **reservas** — money reserved/moved between months: `descricao`, `valor`, `mes_origem`,
  `mes_destino`, `out`.
- **adiantamentos** — advances against a card, similar shape to `reservas` plus `cartao_id`.

`buildPayload(tableKey, rec)` (around line 2002) is the single source of truth for how a UI record
maps to a table's insert/update payload — check it before assuming a column name.

## Domain logic worth knowing before touching it

- **Installments (parcelas) & fatura math**: `getCartaoFechamento`, `getFaturaStartYM`,
  `monthsElapsedByDay`, `getCompraScheduleForMonth` work out which statement month a given
  installment of a purchase lands in, based on the card's `fechamento` day. This is the trickiest
  part of the app — read these functions fully before changing installment logic, since off-by-one
  month errors here silently misattribute real money.
- **Anticipations**: `getAntecipacoesForCompra`/`getAntecipatedIndexMap` let a user "pay ahead" on
  specific installment indices of a `compras` row without changing the original schedule.
- **Nubank CSV import**: `parseNubankCsv` → `buildImportCandidates` matches imported rows against
  existing `compras` (by merchant name + amount + date proximity, see
  `findLatestByComerciante`/`findContinuationMatch`) to avoid duplicate entries when re-importing a
  statement.

## Shared backend with Planes

The `Planes/` app (trip planning) uses the **same Supabase project and anon key**, with its own
tables prefixed `planes_` (`planes_trip`, `planes_orcamento`, `planes_passagens`,
`planes_hospedagem`, `planes_atividades`, `planes_comentarios`, `planes_categorias`,
`planes_atividade_itens`, `planes_pendencias`). When working on Financas, don't assume the project
is exclusively its backend — a migration or advisor check on this project will also surface Planes
tables; that's expected, not a bug.

## Where to go next

For the actual edit/deploy workflow (local clone → commit → push, and safe Supabase schema
changes), see the sibling skill **financas-edit-workflow**.
