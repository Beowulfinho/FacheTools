-- Tracker: informe terapéutico. Plantilla por patología (se precarga en la última sesión del paquete)
-- y texto guardado por sesión.
alter table public.tratamientos_patologias add column if not exists plantilla_informe text;
alter table public.tratamientos_sesiones add column if not exists informe text;
