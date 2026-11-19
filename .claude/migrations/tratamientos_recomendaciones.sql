-- Tracker: "Observaciones y recomendaciones" de la última sesión, con plantilla por patología.
-- Reemplaza al campo de observaciones genérico en la última sesión: las observaciones que ya existían ahí se copian.
alter table public.tratamientos_patologias add column if not exists plantilla_recomendaciones text;
alter table public.tratamientos_sesiones add column if not exists recomendaciones text;
update public.tratamientos_sesiones s
set recomendaciones = s.observaciones
from public.tratamientos_pacientes p
where s.paciente_id = p.id and s.numero = p.total_sesiones and s.numero > 1
  and s.observaciones is not null and s.recomendaciones is null;
