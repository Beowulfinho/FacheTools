---
name: facheros-contexto
description: >
  Conocimiento de la vida real y las finanzas de los facheros (Andrés y Gabriela): quiénes son las
  personas del app, qué cuenta o tarjeta sirve para qué, qué significa cada gasto fijo, cómo fluye el
  dinero en el mes y cómo se reparten gastos e ingresos. Cargar siempre que haya que darle significado a
  un número, un gasto, un nombre ("PUC", "Mãe", "Padres", "Tuna", "Realize", "Acomulado") o una transferencia,
  y antes de hacer-cuentas, de importar extractos/facturas o de proponer cualquier cambio en las finanzas.
  Se amplía con rondas de preguntas al usuario; cada dato indica si está **confirmado** o es **inferido**.
---

# Facheros — contexto de la vida real

Complemento de `financas-app-context` (cómo está construido el app) y `hacer-cuentas` (el proceso).
Aquí vive el **significado**: qué representa cada número en la vida de los facheros.

## Cómo usar este conocimiento
- Ante un gasto o transferencia desconocida, buscar primero aquí; si no está, **preguntar** y luego
  agregarlo (con la fecha y marcado como confirmado por el usuario).
- Los datos marcados *(inferido)* se verifican con el usuario antes de apoyarse en ellos.
- Un valor puede ser correcto en el app pero tener otro sentido en la vida real (ej. el "40% / 60%" del
  salario es el momento del pago, no una proporción).

## Índice
- [`references/personas.md`](references/personas.md): Facheros, Gab, Aj, Mãe, Tchuka, Padres.
- [`references/cuentas.md`](references/cuentas.md): cuentas de débito, quién las usa y el flujo del dinero.
- [`references/tarjetas.md`](references/tarjetas.md): qué se usa cada tarjeta de crédito.
- [`references/gastos-fijos.md`](references/gastos-fijos.md): significado de cada gasto fijo y otros rubros.
- [`references/reglas.md`](references/reglas.md): cómo se organizan, reparten y deciden las finanzas.
- [`references/planes.md`](references/planes.md): viajes y salidas de Planes y cómo se conectan con compras y previsões.

## Principios de la casa (confirmados)
1. **Todo es una sola economía**: los ingresos se consideran como uno y no llevan finanzas por separado.
2. **Andrés se encarga de pagar todo** (por ahora).
3. La asignación a "Fachero" o "Fachera" ocurre **solo en casos específicos**; si no se informa, el gasto es
   de **Facheros**.
4. El salario de un mes financia el **mes siguiente** (ver `hacer-cuentas`).
