# Feedback a otro proyecto - Clase 19

- **Nombre completo del evaluador:** Lorgio Choque Severiche
- **Mi grupo y caso de estudio:** UniSport — organización de partidos y completado de equipos
- **Grupo y caso de estudio evaluado:** Presupuesto Estudiantil
- **Integrantes del proyecto evaluado:** Guzmán Montalvan Marcos Lehonti
- **URL de la app y repositorio evaluado:** _(completar)_
- **Fecha y versión/commit probado:** 03/11/2026 — commit no disponible

## Primera impresión

Al entrar entendí que la aplicación sirve para que un estudiante lleve el control de sus gastos y que la acción principal es registrar un gasto.

Lo que me confundió fue el botón **"Registrar movimiento"**: la palabra "movimiento" es genérica y no deja claro si voy a registrar un gasto, un ingreso u otra cosa. También me desconcertó que, después de registrar un gasto, este apareciera con un estado **"Pendiente"** o **"Pagado"**.

## Funcionalidad asignada y resultado

Tarea indicada por el docente: registrar un gasto en la aplicación.

- [x] La completé sin ayuda.
- [ ] La completé con ayuda. ¿Cuál?
- [ ] No pude completarla. ¿Dónde me detuve?

## Qué no funcionó

No encontré errores que me impidieran completar la tarea, pero sí puntos de fricción en el formulario y en el flujo posterior al registro:

1. **La fecha no viene cargada por defecto**
   - **Pasos:** abrir el formulario de registro y llegar al campo de fecha.
   - **Resultado esperado:** que la fecha de hoy aparezca seleccionada, ya que la mayoría de los gastos se anotan el mismo día en que ocurren.
   - **Resultado observado:** el campo no trae la fecha actual y hay que buscarla manualmente en el calendario.

2. **Faltan opciones de repetición**
   - **Pasos:** en el formulario, abrir el campo **"¿Se repite?"**.
   - **Resultado esperado:** poder elegir una frecuencia diaria.
   - **Resultado observado:** solo existen las opciones "No se repite", "Cada 7 días" y "Cada mes".

3. **El estado del gasto genera confusión**
   - **Pasos:** completar el formulario y pulsar **"Registrar gasto"**.
   - **Resultado esperado:** que el gasto quede anotado como realizado, porque se registra después de haberlo pagado.
   - **Resultado observado:** el gasto aparece con el estado "Pendiente" o "Pagado", y no queda claro qué significa cada uno ni qué debo hacer a continuación.

## Qué mejoraría y por qué

**Propuesta principal:** cambiar la etiqueta **"Registrar movimiento"** por una que describa exactamente la acción, como **"Registrar gasto"**. Si el botón también sirve para registrar ingresos, convendría separarlo en dos acciones claras: "Registrar gasto" y "Registrar ingreso". Usar el mismo lenguaje que usa el estudiante elimina la duda al entrar y le permite saber qué va a pasar antes de pulsar el botón.

Además recomendaría:

- **Agregar la opción "Diario" en "¿Se repite?"**, porque muchos gastos de un estudiante, como el pasaje o el almuerzo, se repiten todos los días.
- **Mostrar la fecha de hoy por defecto** y permitir cambiarla desde el calendario. Así se ahorra un paso en el caso más común sin quitar flexibilidad.

## Qué quitaría y por qué

Quitaría el campo **"Estado" (Pendiente / Pagado)**. Un estudiante normalmente anota un gasto cuando ya lo realizó, por lo que pedirle un estado agrega una decisión innecesaria y vuelve confuso el flujo. Si el equipo quiere conservar la idea de pagos futuros, podría manejarla por separado, por ejemplo como "gastos programados" o recordatorios, sin mezclarla con el registro normal de gastos.
