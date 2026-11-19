-- Tracker: 3 variaciones por protocolo (patología). Cada ejercicio de una patología pertenece a una variación (1..3);
-- los paquetes del mismo paciente con la misma patología rotan 1, 2, 3, 1, 2, 3… (se calcula en la app).
-- No destructiva: todo lo que existe queda en la variación 1.
alter table public.tratamientos_ejercicios add column if not exists variacion smallint not null default 1;
alter table public.tratamientos_ejercicios drop constraint if exists tratamientos_ejercicios_variacion_check;
alter table public.tratamientos_ejercicios add constraint tratamientos_ejercicios_variacion_check check (variacion between 1 and 3);
