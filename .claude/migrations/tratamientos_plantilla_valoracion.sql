-- Tracker: plantilla de valoración por patología. Aparece (editable) en el campo Valoración de la sesión 1
-- de los pacientes cuyo paquete tiene esa patología y todavía no tienen valoración escrita.
alter table public.tratamientos_patologias
  add column if not exists plantilla_valoracion text;
