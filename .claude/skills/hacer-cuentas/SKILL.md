---
name: hacer-cuentas
description: >
  Modo rápido de "Hacer cuentas" de los facheros (Andrés y Gabriela): el usuario entrega las
  facturas de las tarjetas (CSV/PDF/total) y el total de débito del mes, y Claude carga todo en la
  app Financas (Supabase), verifica que cada factura cuadre con el app y entrega el balance
  Fachero/Fachera. Usar cuando digan "hacer cuentas", "hagamos cuentas", "tenemos las facturas",
  "cierra el mes", "carga estas facturas", o cuando pasen archivos de factura de cualquier tarjeta
  (Nubank AJ, Nubank Gab, Bradesco, Santander, XP, Renner) con la intención de cerrar el mes.
  Cargar antes financas-app-context (esquema y lógica de fatura).
---

# Hacer cuentas — modo rápido (desde Claude)

Equivale a hacer a mano el flujo de la pestaña **Cuentas** de `Financas/index.html`, pero con las
facturas entregadas en el chat. El resultado debe quedar **igual que si lo hubieran hecho en la
app**: compras cargadas, `cuentas_mes` conferido y el balance calculado.

Idioma con el usuario: español. Proyecto Supabase: `qdetwdneqncblxwylpyw`.

## Qué recibir (pedir solo lo que falte)

1. **Mes de la fatura** (ej. "2026-10"). Es el mes de la *fatura*, no el de las compras.
2. **Una factura por tarjeta** (CSV Nubank, PDF u otro) o, mínimo, el **total real** de cada una.
   Tarjetas: Bradesco, Nubank AJ, Nubank Gab, Renner, Santander, XP. Una tarjeta sin factura ese mes
   se confirma con el usuario (0 o "sin movimiento"), no se asume.
3. **Débito del mes**: total de gastos y de ingresos. Si solo dan un número, preguntar una vez si es
   gasto o ingreso y si hay detalle; sin detalle se registra como **una sola fila** "Débito del mes
   (total)" de tipo `Gasto Variable` (o `Ingreso Variable`).

## Flujo

### 1. Leer el estado actual
- `execute_sql` sobre `cartoes`, `pessoas`, `tipos`, `compras` (activas, `out=false`) y `cuentas_mes`.
- Mes de fatura de una compra = mes de `data`, +1 si `día >= cartoes.fechamento` (`getFaturaStartYM`).
  Cuota k de una compra cae en `inicio + (k-1)` meses. Asignaturas (`tipo` con "Assinatura") se
  repiten cada mes hasta `cancelamento`. Para totales exactos del app (anticipaciones, reembolsos,
  trocas de cartão, adiantamentos) **leer `getCompraScheduleForMonth` y `getFaturaAppTotals` en
  `Financas/index.html`** antes de calcular; no improvisar.

### 2. Leer cada factura
- **CSV Nubank**: columnas `date,title,amount`. Reglas ya implementadas en `buildImportCandidates`
  (`Financas/index.html`): amount < 0 = pago/estorno (se ignora); `"X - Parcela k/n"` = cuota k de n
  (si k>1 buscar la compra original por `comerciante` y mes; si no existe, estimar inicio y valor
  total = amount × n y avisar); quitar sufijo `- NuPay`.
- **PDF**: leerlo con Read (por páginas) y extraer línea por línea (fecha, descripción, valor) y el
  **total de la factura**. Si el PDF es ambiguo, mostrar lo extraído y confirmar antes de seguir.
- Anotar siempre el **total real** de cada factura: es el valor de `valor_real`.

### 3. Conciliar y mostrar el plan (una sola confirmación)
Por tarjeta: total app actual vs. total real, qué compras faltan (nuevas), cuáles ya existen
(mismo `comerciante` + `data` + valor → duplicada, no insertar), y qué sobra en el app sin
contraparte en la factura (posible duplicado o tarjeta equivocada: **avisar, no borrar**).
Presentar una tabla corta y pedir un solo "ok" antes de escribir. Si el usuario ya dijo
explícitamente que cargues sin preguntar, proceder y reportar.

### 4. Escribir en Supabase
- **Siempre fijar `user_id` explícito** (el MCP corre sin sesión, `auth.uid()` es null):
  `(select id from auth.users where email='andresjuanfr@gmail.com')`.
- `compras`: `descricao`, `comerciante` = descripción en minúsculas con espacios colapsados,
  `pessoa_id` = "Facheros" por defecto (compra compartida; usar otra persona solo si el usuario lo
  dice), `cartao_id`, `valor_total`, `parcelas`, `data`, `tipo_id` ("Á vista" si 1 parcela,
  "Parcelado" si más), `out=false`.
- `debito`: `tipo` ∈ {Ingreso Fijo, Ingreso Variable, Gasto Fijo, Gasto Variable}, `data` en el mes,
  `pessoa_id` "Facheros".
- `cuentas_mes` (una fila por tarjeta y una con `cartao_id` null para débito), con índice único
  `(mes, cartao_id)`: `insert ... on conflict` no aplica al índice con `coalesce`; hacer
  `update` si existe, `insert` si no. Poner `valor_real`, y `conferido=true`/`conferido_at=now()`
  solo si la diferencia app vs. real es < R$ 0,01 (el débito se marca completo cuando el usuario
  confirmó el total). Una tarjeta con diferencia queda **sin** conferir y se reporta.
- Usar un solo `execute_sql` por bloque lógico y un `select` de verificación después. No `delete`
  ni `update` de compras existentes sin pedirlo.

### 5. Verificar y entregar el balance
- Releer los totales por tarjeta del mes y confirmar que coinciden con `valor_real`.
- Dar el balance del Dashboard para ese mes. Idealmente abrir la app en vivo (no `file://`) con el
  navegador y leer Dashboard → "Balance final / Fachero / Fachera". Si no hay sesión disponible,
  calcular con la fórmula del código (`renderDashboard`): `restante = balance − totalCompras −
  diario − investimento + reservasNet`, `fachero = restante/2 − (indivAj − indivGab)/2`,
  `fachera = restante/2 + (indivAj − indivGab)/2`, y decir que es un cálculo manual.
- Cerrar con: qué se cargó (nº de compras por tarjeta), qué quedó sin cuadrar, y el resultado
  Fachero/Fachera.

## Reglas
- Nada se borra y no se tocan compras existentes: solo se insertan faltantes y se reporta lo raro.
- Sin cambios de esquema ni push a GitHub en este flujo (son solo datos).
- Si una factura no cuadra tras cargar, no forzar `conferido`: explicar la diferencia con las líneas
  sospechosas (duplicados, cuota con otra fecha, compra en tarjeta equivocada).
- Formato PDF/CSV de Bradesco, Santander, XP y Renner todavía no tiene parser documentado: la
  primera vez que llegue uno, mostrar cómo se interpretó y, si el usuario lo aprueba, agregar aquí
  una sección con sus particularidades.
