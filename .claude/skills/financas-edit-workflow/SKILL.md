---
name: financas-edit-workflow
description: >
  Safe end-to-end workflow for making real changes to the FacheTools apps (Financas, Planes) —
  both the static frontend hosted on GitHub (Beowulfinho/FacheTools) and the shared Supabase
  backend (project qdetwdneqncblxwylpyw). Use this skill whenever asked to edit, fix, add a
  feature to, deploy, or push changes to Financas/index.html or Planes/index.html, or to change
  Supabase tables/columns/RLS policies/data for this project — including things like "add a new
  field to compras", "fix the fatura calculation", "push this to GitHub", "add an index/column in
  Supabase". It covers the local-clone → edit → commit → push flow and when to use a tracked
  migration vs. a one-off SQL query against Supabase, plus which steps need the user's explicit
  go-ahead before they happen.
---

# Editing FacheTools safely (frontend + Supabase)

This project has two moving parts that change independently: the **frontend** (static HTML/JS on
GitHub Pages-style hosting, no build) and the **backend** (Supabase Postgres). Most feature work
touches only one of them — know which before you start.

## Where things live

- Local clone: `C:\Users\andre\Documents\GitHub\FacheTools` (git remote → `Beowulfinho/FacheTools`
  on GitHub, `gh` CLI already authenticated as that user).
- Frontend files: `Financas/index.html`, `Planes/index.html` — each fully self-contained (HTML +
  CSS + JS inline). There is no `npm install`, no bundler, no transpile step. Editing the file *is*
  deploying the frontend, once pushed.
- Backend: single Supabase project `qdetwdneqncblxwylpyw`, shared by both apps (Financas tables
  are unprefixed, Planes tables are `planes_*`). See **financas-app-context** for the schema.

## Frontend changes

1. Edit `Financas/index.html` (or `Planes/index.html`) directly with normal file edits — it's just
   HTML/CSS/JS in one file, so treat functions/sections like you would in any JS codebase. Keep
   the existing style: vanilla JS, no dependencies beyond the Supabase CDN script and Google Fonts
   already loaded in `<head>`. Don't introduce a build step or split the file apart unless
   explicitly asked — the whole point of this app is that it's a single file you can re-upload
   anywhere.
2. **Commit locally** with a real, descriptive message (the existing history is mostly generic
   "Add files via upload" from the GitHub web UI — no need to match that; write what actually
   changed).
3. **Push only with explicit go-ahead.** Pushing updates what's live for anyone using the app, so
   confirm with the user before `git push` even if they already asked for the change — show what's
   about to go out (`git diff`/`git status` summary) and wait for a clear yes, unless they've
   already told you to push straight through for this session.
4. **Verify against the live published URL, not a local `file://` path.** Once pushed, test in a
   normal Claude Browser tab at `https://beowulfinho.github.io/FacheTools/Financas/` (or
   `.../Planes/`, `.../Tareas/`) — not `file:///C:/Users/andre/.../index.html`. A `file://` path
   opens as a pinned "local preview" tab that can't be navigated away from and doesn't reliably keep
   the Supabase login session across reloads/edits, so the user ends up re-entering credentials
   constantly. The live URL is a normal tab whose session survives `location.reload()`, and since
   Financas/Planes/Tareas share one origin (`beowulfinho.github.io`), logging in once on any of the
   three keeps the others logged in too — reuse the same tab across a whole session rather than
   opening a new one each time. GitHub Pages takes roughly ~30–60s to rebuild after a push; poll
   `gh api repos/Beowulfinho/FacheTools/pages/builds/latest --jq .status` until it reports `"built"`
   rather than guessing a fixed wait, then reload the tab and exercise the actual page/flow you
   changed. Check the browser console for errors. This app has no automated test suite, so manual
   verification in-browser is the only safety net — don't skip it, especially for anything touching
   the installment/fatura math (see financas-app-context) where a subtle bug silently misattributes
   money instead of crashing. (A local `file://` open is still fine for a quick visual-only check
   that doesn't need a logged-in session, e.g. confirming a login screen redesign renders, or for
   checking something before it's pushed.)

## Supabase backend changes

Use the Supabase MCP tools directly (project id `qdetwdneqncblxwylpyw`) rather than asking the
user to click through the dashboard.

- **Schema changes** (new table/column, index, constraint, RLS policy): use `apply_migration`, not
  a raw `execute_sql` DDL statement. Migrations are versioned and reversible-in-principle; ad-hoc
  DDL via `execute_sql` isn't tracked and is easy to lose track of. Name the migration for what it
  does (e.g. `add_comerciante_index_to_compras`).
- **Data fixes / one-off queries** (backfilling a value, inspecting rows, a manual correction):
  `execute_sql` is fine — but treat any `UPDATE`/`DELETE` against real data as a real-world action:
  confirm with the user first (this is live household financial data, not a scratch database), and
  prefer a `SELECT` first to show them exactly which rows would be affected.
- **New tables must keep the existing shape**: `id uuid default gen_random_uuid()` (or `bigint` for
  a couple of legacy tables — check `financas-app-context` for the exact pattern per table),
  `user_id uuid not null default auth.uid()`, and **RLS enabled** with a policy scoping rows to
  `auth.uid()`. Every existing table follows this; breaking the pattern on a new one would leak
  data across users since the frontend has no server-side access check of its own — the database
  policy *is* the security boundary.
- **After any schema change**, run `get_advisors` (security and performance) and fix anything it
  flags before considering the change done — RLS gaps in particular won't show up in normal manual
  testing since you're testing as yourself, logged in as the row owner.
- The anon/publishable key embedded in `index.html` is meant to be public — it only works within
  whatever RLS policies allow. Never respond to a request to disable RLS or widen a policy to "for
  all users" as a shortcut; that's the one thing that actually would expose everyone's data.

## Quick decision guide

| Ask | Do this |
|---|---|
| "Add a column / new table / change a policy" | `apply_migration`, then `get_advisors` |
| "Why does X show the wrong number" | Read the relevant function in `index.html` per financas-app-context, reproduce with `execute_sql` SELECTs before touching code |
| "Fix a typo / UI tweak / add a field to the form" | Edit `index.html`, commit, confirm before push, then verify on the live URL (not `file://`) |
| "Push what we've got" | Confirm scope of the diff, then push |
| "Delete/correct some rows" | Show the affected rows via SELECT first, confirm, then run it |
