---
name: hacer-cuentas
description: >
  Modo rápido de "Hacer cuentas" de los facheros (Andrés y Gabriela): el usuario entrega las
  facturas de las tarjetas (CSV/PDF/total) y cuánto dinero hay hoy en las cuentas de débito, y
  Claude deja la app Financas (Supabase) actualizada: carga las compras que faltan, verifica que
  cada factura cuadre con el app y concilia el saldo de hoy contra lo que el app espera, teniendo en
  cuenta que el salario cae a mitad y a fin de mes y financia el mes siguiente. Usar cuando digan
  "hacer cuentas", "hagamos cuentas", "tenemos las facturas", "cierra el mes", "actualiza el app",
  "carga estas facturas", o cuando pasen archivos de factura de cualquier tarjeta (Nubank AJ, Nubank
  Gab, Bradesco, Santander, XP, Renner). Cargar antes financas-app-context (esquema y lógica de
  fatura).
---

# Hacer cuentas — modo rápido (desde Claude)

Equivale a hacer a mano el flujo de la pestaña **Cuentas** de `Financas/index.html`, pero con las
facturas entregadas en el chat. Objetivo actual: **que el app quede actualizada** (compras cargadas,
`cuentas_mes` conferido, saldo conciliado). El reparto Fachero/Fachera del Dashboard es un extra que
se informa si lo piden.

Idioma con el usuario: español. Proyecto Supabase: `qdetwdneqncblxwylpyw`.
**Cargar también `facheros-contexto`**: da el significado de personas, cuentas, tarjetas y gastos para
interpretar cada número y cada transferencia (y se amplía cuando el usuario aclara algo nuevo).
Fecha de hoy: **obtenerla del sistema (`date`) y decirla en voz alta**; toda la lógica del saldo
depende de ella.

## Qué recibir (pedir solo lo que falte)

1. **Facturas**: una por tarjeta (CSV Nubank, PDF u otro) o al menos su total real. Tarjetas:
   Bradesco, Nubank AJ, Nubank Gab, Renner, Santander, XP. Una tarjeta sin factura se confirma con el
   usuario, no se asume, **excepto Renner**: no es una tarjeta activa. Si no entregan su factura, **su
   valor en el app se considera intacto hasta nuevo aviso**: no preguntar por ella ni tomarlo como un
   cambio. Solo para poder cerrar el mes en Cuentas, dejarla conferida con `valor_real` = total del
   app. Si algún día entregan una factura de Renner, procesarla como cualquier otra. La tarjeta se identifica por el **día de vencimiento** (`cartoes.vencimiento`)
   y por los comerciantes ya vistos en esa tarjeta (ej. vence el 10 + Raia168/Pão de Açúcar = Nubank AJ;
   vence el 12 = Nubank Gab o Bradesco). Si queda duda, preguntar.
2. **Saldo de débito de hoy**: la suma de lo que hay hoy en las cuentas de ambos. No piden desglose.
   Si cada uno da el suyo por separado ("mi débito es X"), pedir el del otro y sumar.

**Cómo interpretar lo que llega**: los **archivos o totales de factura son crédito** (tarjetas); un
**valor suelto ("tengo 1.619,54") es el saldo de débito de hoy**, no una factura. Si un número es
ambiguo, **preguntar antes de usarlo** (error real: un saldo de débito se tomó por el total de una
factura y generó una "diferencia" inexistente de R$ 1.134,46).

El mes de la fatura sale de la propia factura (vencimiento / fechas de las compras vs. el
`fechamento` de la tarjeta).

## Calendario del salario y "mes del app" (regla clave)

- Cada uno recibe el **40% a mitad de mes (día 15)** y el **60% el último día ÚTIL del mes** (último
  día de lunes a viernes, descontando feriados nacionales de Brasil; calcularlo, no asumir el día 30/31).
- **El salario financia el mes siguiente.** Toda la plata que cae en el mes *m* (el 40% del día 15 y
  el 60% del último día útil) es el **ingreso del mes *m+1*** en el app (las filas "Salario Fachero/Fachera 60%/40%"
  con fecha día 1 de *m+1*). Con él se paga la fatura de *m+1* (vence el 10–12 de *m+1*) y los gastos
  fijos de *m+1* (aluguel, PUC, Claro, servicios).
- Por eso el saldo de hoy **mezcla dos meses**. Con *m* = mes calendario de hoy:
  - hoy **< día 15**: el salario completo de *m* ya cayó (40% del día 15 de *m−1* + 60% del último día
    de *m−1*) y el de *m+1* aún no → el saldo es plata del mes *m* (menos lo ya pagado).
  - hoy **entre el día 15 y antes del último día útil**: además cayó el 40% del salario de *m+1*.
  - hoy **>= último día útil del mes**: ya cayó el 100% del salario de *m+1*.
- Confirmado por el usuario: el salario recibido en *m* es el ingreso de *m+1*, "mitad de mes" = día 15
  y el 60% cae el último día útil. La plata de los padres ("Plata Padres") la envían cada mes por
  Western Union, sin fecha fija, con un **mínimo de R$ 1.300**: **usar el valor que está en el app** (debe
  ser 1.300) y darla por recibida, salvo que el usuario diga cuánto cayó exactamente (entonces usar ese
  valor). No preguntar por ella.

## Flujo

### 1. Leer el estado actual
- `execute_sql` sobre `cartoes`, `pessoas`, `tipos`, `compras` (activas, `out=false`), `debito`,
  `diario`, `adiantamentos` y `cuentas_mes`. Ignorar las filas con `previsao = true` (hipotéticas) al comparar.
- Mes de fatura de una compra = mes de `data`, +1 si `día >= cartoes.fechamento` (`getFaturaStartYM`).
  La cuota k cae en `inicio + (k-1)` meses. Las asignaturas (`tipo` con "Assinatura") se repiten cada
  mes hasta `cancelamento`. Para totales exactos (anticipaciones, reembolsos, trocas de cartão,
  adiantamentos) **leer `getCompraScheduleForMonth` y `getFaturaAppTotals` en `Financas/index.html`**
  antes de calcular; no improvisar.
- Aprovechar para **detectar anomalías** (ej. filas idénticas repetidas) y reportarlas sin tocarlas.

### 2. Leer cada factura
- **CSV Nubank**: columnas `date,title,amount`. Reglas de `buildImportCandidates`: amount < 0 = pago o
  estorno (ignorar); `"X - Parcela k/n"` = cuota k de n (si k>1 buscar la compra original por
  `comerciante` y mes; si no existe, estimar inicio y `valor_total = amount × n` y avisar); quitar el
  sufijo `- NuPay`. **Filas idénticas dentro del mismo CSV son compras reales** (ej. dos cobros iguales
  el mismo día): deduplicar solo contra lo que **ya existe en el app**, nunca entre filas del CSV.
- **PDF**: leer con Read por páginas, extraer fecha, descripción y valor por línea y el **total de la
  factura**. Si es ambiguo, mostrar lo extraído y confirmar antes de seguir.
- Anotar el **total real** de cada factura: es el `valor_real`.

### 3. Conciliar facturas
Por tarjeta: total app vs. total real; compras que faltan (nuevas); las que ya existen (mismo
`comerciante` + `data` + valor → no insertar); y lo que sobra en el app sin contraparte (posible
duplicado o tarjeta equivocada: **avisar, no borrar**).

### 4. Estado de pagos y saldo de hoy (página Cuentas)
Los meses cerrados **no se comparan**: un mes cerrado ya se pagó entero y el saldo de hoy es **posterior** a esos
pagos. Lo que importa es qué del mes que se está pagando ya se pagó y qué falta. La página **Cuentas** del app lo
guarda en `cuentas_mes`:
- **Facturas de tarjeta**: fila `(mes, cartao_id)` con `valor_real` (total del banco), `conferido`, `pago`, `valor_pago`
  y `pago_em`. Un `pago = true` significa que ya salió la plata de las cuentas.
- **Gastos fijos** (Aluguel, Servicios, Claro, PUC…): fila con `item = 'fijo:<descripción>|<persona>'` y `pago`.
  Recordar: aluguel + servicios se pagan el **día 1** y la PUC el **día 10**.
- **Saldo de hoy**: fila con `item = 'saldo'`, `valor_real` = suma de las cuentas y `pago_em` = fecha del saldo
  (mes = mes calendario de hoy). Es el total de todas las cuentas (Nubank AJ, Nubank Gab, Bradesco de Gab…); un
  número suelto que den es esto.
- **Débito del mes completo**: fila `item` null y `cartao_id` null con `conferido`.

Procedimiento:
1. Preguntar (o deducir de los extractos/mensajes) **qué ya se pagó del mes en curso** y marcarlo (`pago = true`,
   `valor_pago`, `pago_em`). Lo pagado hasta la fecha del saldo ya está descontado del saldo.
2. Guardar el **saldo de hoy** con su fecha.
3. Calcular `A pagar` = suma de facturas (valor real si lo hay, si no el del app) y fijos **no pagados**; la
   **sobra tras pagar lo pendiente** = saldo − A pagar. Esa sobra debe cubrir el diario del mes; si es negativa,
   avisar cuánto falta y de qué mes sale (el salario que cae el día 15 financia el mes siguiente).
4. No usar `restante(m)` del Dashboard como referencia del saldo: el saldo real manda. Si hay una inconsistencia
   fuerte entre el app y los extractos, mostrar el detalle (facturas pagadas vs. valor del app, transferencias
   internas) y preguntar, sin plugs.
- El salario ya recibido del mes siguiente sigue en el saldo; no se resta, porque lo que se compara ahora es contra
  lo pendiente del mes en curso (el salario de un mes financia el siguiente).

### 4b. Extractos de débito: cada gasto visible en el app
Desde ahora los gastos de débito **no se resumen en un "gasto variable"**: cada movimiento del extracto
(CSV de Nubank: `Data,Valor,Identificador,Descrição`) se carga como una fila de `debito`.
- **Fila**: `tipo='Gasto Variable'`, `descricao` = comercio + cuenta entre paréntesis (`"99 NuPay (AJ)"`,
  `"Pix: NOMBRE (Gab)"`), `valor` positivo, `data` = fecha real, `pessoa` = **Facheros** salvo que el
  usuario indique otra (la asignación Fachero/Fachera es solo para casos específicos),
  `ref_externa` = **columna Identificador** del extracto, `user_id` explícito.
- **Idempotente**: `insert ... on conflict (ref_externa) where ref_externa is not null do nothing`;
  reimportar un extracto solapado no duplica.
- **Sí se cargan**: compras en débito, Pix a terceros (comercios y personas).
- **No se cargan** (no son gasto o ya están en el app): pago de fatura (ya cuenta en las compras de la
  tarjeta), transferencias entre ellos dos o entre cuentas propias, aplicaciones/RDB (inversión),
  aluguel y servicios (Gasto Fijo), Claro (Gasto Fijo), pago de Renner (Realize), estornos y sus
  intentos. Lo ambiguo (resgate de empréstimo, entradas de terceros) se **pregunta**: las entradas de
  personas con "gera ingresso" (Mãe, Padres, Tchuka) ya suman como "Espelho de compras" y registrarlas
  duplicaría el ingreso.
- **Diario = presupuesto de R$ 700/mes del que salen estos gastos.** El Dashboard descuenta de él las
  filas con `ref_externa` (no las suma al balance, para no contar dos veces). Mes abierto: reserva
  `max(diario, gasto real)`. Mes con el débito marcado completo en Cuentas: vale el gasto real (lo que
  sobró del diario vuelve como positivo, lo que se pasó cuenta como negativo). El mes siguiente
  empieza con otros R$ 700. No cambiar el diario de cada mes a 0.
- Los extractos de AJ y de Gab se cargan **por separado**; falta tu Santander y las otras cuentas de
  Gab (Bradesco, Santander, XP, Caixa) si hay gastos allí.
- Un extracto termina el día anterior a su exportación: los movimientos del último día los trae el
  siguiente.

### 5. Plan único y escritura en Supabase
Presentar una sola tabla (facturas + saldo) y pedir un solo "ok" antes de escribir; si el usuario ya
dijo que cargues sin preguntar, proceder y reportar.
- **Siempre fijar `user_id` explícito** (el MCP corre sin sesión, `auth.uid()` es null):
  `(select id from auth.users where email='andresjuanfr@gmail.com')`.
- `compras`: `descricao`, `comerciante` = descripción en minúsculas con espacios colapsados,
  `pessoa_id` "Facheros" por defecto (otra persona solo si el usuario lo dice), `cartao_id`,
  `valor_total`, `parcelas`, `data`, `tipo_id` ("À Vista" —con À— si 1 parcela, "Parcelado" si más;
  consultar `tipos` para el nombre exacto), `out=false`.
- **Suscripciones o compras que pasaron a otra tarjeta**: no se editan ni se duplican; se inserta una
  fila en `compra_cartao_trocas` (`compra_id`, `cartao_id` nuevo, `mes` = primer mes de fatura en la
  tarjeta nueva, formato `YYYY-MM`, `user_id` explícito). Una suscripción con `cancelamento` ya no se
  cobra y no afecta los totales.
- **Duplicados en el app** (filas idénticas que la factura muestra una sola vez): se dejan en el app con
  `out=true` (excluidas), conservando la más antigua; nunca `delete`.
- `debito`: `tipo` ∈ {Ingreso Fijo, Ingreso Variable, Gasto Fijo, Gasto Variable}, `pessoa_id` "Facheros".
- `cuentas_mes` (una fila por tarjeta y una con `cartao_id` null para débito; índice único
  `(mes, coalesce(cartao_id, ...))`, así que `update` si existe e `insert` si no): poner `valor_real`
  y `conferido=true`/`conferido_at=now()` solo si la diferencia app vs. real es < R$ 0,01. Una tarjeta
  con diferencia queda **sin** conferir y se reporta.
- Un `execute_sql` por bloque lógico y un `select` de verificación después. Nada de `delete` ni
  `update` de compras existentes sin que lo pidan.

### 5b. Previsões (desde Planes)
Al terminar de cargar, revisar los eventos de Planes de los próximos 3 a 6 meses y **sincronizar las previsões**
según `facheros-contexto/references/planes.md` (presupuesto y pasajes pendientes → fila de `debito` con `previsao = true`
en el mes del gasto). Informar qué previsões se crearon o cambiaron. Las filas con `previsao = true` **no cuentan**
para facturas, balance ni conciliación: solo existen en la página Previsões.

### 6. Verificar y entregar
- Releer los totales por tarjeta del mes y confirmar que coinciden con `valor_real`. Lo más fiable es la
  pestaña **Cuentas** de la app en el navegador del panel (botón `#btnReload` refresca los datos desde
  Supabase; un `location.reload()` no siempre lo hace). Si el usuario da el total que ve en su app de
  Nubank y no coincide con la suma del CSV, **no inventar**: reportar ambos y preguntar de qué factura
  o fecha de corte es; dejar esa tarjeta sin `valor_real` ni `conferido`.
- Reportar: qué se cargó (nº de compras y total por tarjeta), qué quedó sin cuadrar, el resultado de
  la conciliación del saldo y las anomalías detectadas.
- Solo si lo piden: balance Fachero/Fachera del Dashboard (leerlo en la app en vivo, no `file://`, o
  calcular con `renderDashboard`: `fachero = restante/2 − (indivAj − indivGab)/2`,
  `fachera = restante/2 + (indivAj − indivGab)/2`, indicando que es un cálculo manual).

## Reglas
- No se borra nada ni se tocan compras existentes: solo se insertan faltantes y se reporta lo raro.
- Sin cambios de esquema ni push a GitHub en este flujo (son solo datos).
- Si una factura no cuadra tras cargar, no forzar `conferido`: explicar la diferencia con las líneas
  sospechosas (duplicados, cuota con otra fecha, compra en tarjeta equivocada).
- Bradesco, Santander, XP y Renner todavía no tienen parser documentado: la primera vez que llegue una
  factura de esos bancos, mostrar cómo se interpretó y, si el usuario aprueba, agregar aquí sus
  particularidades.
