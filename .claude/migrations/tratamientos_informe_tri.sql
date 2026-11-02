-- Tracker: "necesita informe terapéutico" pasa a tres estados: true (con informe), false (sin informe), null (sin registrar).
-- Hasta ahora false era el valor por defecto (casilla sin marcar), o sea "no se eligió": esas filas pasan a null.
alter table public.tratamientos_pacientes alter column informe drop not null;
alter table public.tratamientos_pacientes alter column informe drop default;
update public.tratamientos_pacientes set informe = null where informe = false;
