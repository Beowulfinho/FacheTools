-- Tracker: marca si el usuario necesita informe terapéutico y se retira el campo notas
-- (a la fecha ningún registro tenía notas).
alter table public.tratamientos_pacientes add column if not exists informe boolean not null default false;
alter table public.tratamientos_pacientes drop column if exists notas;
