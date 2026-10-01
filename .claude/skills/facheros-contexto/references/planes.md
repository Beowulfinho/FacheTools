# Planes: la interconexión con las finanzas

El app **Planes** (viajes y salidas) comparte la base de datos con Financas. Los eventos de Planes son la
fuente de muchos gastos futuros, que en Financas aparecen como **compras** (pasajes, hospedaje) y como
**reservas** (previsiones de balance). *(confirmado: "aquí inicia la interconexión")*

## Estado actual (01/10/2026)
| Planes | Fechas | Notas |
|---|---|---|
| **Carlinhos** (salida) | 24–25/10/2026, Bertioga | Buser R$ 60 pendiente. Reserva en Financas: "Carlinhos" R$ 270 para octubre. |
| **Viaje a Colombia** | 19/12/2026 – 04/01/2027 | 5 pasajes, R$ 8.434,08; presupuesto R$ 2.000. Vuelo de regreso LATAM BAQ→GRU 03/01 (R$ 4.217,04 × 2, comprado). Pasajes de ida pendientes en Planes. |
| **Skydiving** (salida) | sin fecha, Boituva SP | Presupuesto R$ 1.900. |
| **Viaje 2027** | Perú, sin fecha | Sin datos. |

## Hallazgos
- Los pasajes de Planes **no están vinculados** a las compras de Financas (`compra_id` vacío en todos): la
  conexión existe en el esquema pero no se usa.
- En Financas hay pasajes en cuotas en Bradesco (R$ 5.479, R$ 5.500 "recompra" y R$ 5.724) y en Santander
  (R$ 2.901,84 y R$ 4.217,04) cuyo cruce con los de Planes no está claro (posibles duplicados por la "recompra").

## Viaje a Colombia: estructura de pasajes *(confirmado por el usuario)*
1. **Ida GRU → BOG**: 2 pasajes (Andrés y Gabriela).
2. **BOG → CUC** (Bogotá a Cúcuta): 2 pasajes, se comprarán después. En Planes la fila "Interno" tenía una sola persona
   ("Facheros") con fecha 23/09/2026 (parece un placeholder, antes del viaje): se dividió en Andrés y Gabriela;
   **la fecha sigue pendiente de corregir**.
3. **Regreso BAQ → GRU** (Barranquilla a São Paulo): 2 pasajes, ya comprados (R$ 4.217,04 cada uno).

## Regla: Planes alimenta las reservas (previsiones de balance)
Un evento de Planes con gasto cierto en un mes futuro debe tener una **reserva** en Financas, para ver cómo queda el
balance de ese mes. Sincronizar al hacer cuentas, mirando los próximos 3 a 6 meses:
- **Qué cuenta**: el presupuesto planeado (`planes_orcamento.planejado`) y los pasajes/hospedajes **pendientes** con
  valor. Lo ya comprado en cuotas **no** se reserva (ya está en las compras).
- **Fila**: `reservas` con `descricao = 'Planes · <nombre del viaje> (<concepto>)'`, `valor`, `mes_destino` = mes del
  gasto (el de inicio del viaje, o el de cada fecha si son varias), `mes_origem` = **el mes anterior al destino**
  (como las reservas existentes: sep → oct) y `soma_balance = false` (plata comprometida, no disponible).
- **Idempotente**: si ya existe una reserva con esa misma descripción, actualizarla en vez de crear otra.
- **Sin fecha** (Skydiving, Perú 2027): no se crea reserva hasta que tengan mes.
- Ya creada: "Planes · Viaje a Colombia (presupuesto)", R$ 2.000, nov → dic 2026. Cuando se compren los pasajes
  BOG → CUC, sumar su valor.
- Avisar al usuario de lo que se creó; borrar una reserva solo si el evento se cancela.

## Vincular pasajes con compras
Un pasaje o hospedaje comprado debe **vincularse a su compra** de Financas (`planes_passagens.compra_id`) para no
contarlo dos veces. Hoy ninguno está vinculado; pendiente de saber cuál compra de Bradesco/Santander es cuál.
