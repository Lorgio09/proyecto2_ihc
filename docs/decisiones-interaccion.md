# Decisiones de interacción — Historial de UniSport

## Funcionalidad

El historial responde a la pregunta:

> ¿En qué partidos participó el usuario?

Cuando el usuario se une a un partido, UniSport registra el evento en la base
de datos. El usuario autenticado puede consultar sus eventos desde la pantalla
“Mi historial”.

## 1. Ley de Fitts

### Decisión

Se agregó el botón “Mi historial” en la pantalla principal, junto con las
funciones principales de UniSport. El botón utiliza el mismo tamaño que
“Mis partidos” y “Explorar partidos”, por lo que ofrece un área amplia y fácil
de seleccionar.

Cuando el historial está vacío, se muestra un botón visible llamado
“Explorar partidos” cerca de la explicación de lo que el usuario debe hacer.

### Resultado

La entrada al historial y la acción recomendada del estado vacío son fáciles
de alcanzar y no dependen de iconos pequeños.

### Evidencia

![Estado vacío del historial](evidencias/clase-16/historial-vacio.png)

### Referencias al código

- `frontend_flutter/lib/views/home_view/home_view.dart`
- `frontend_flutter/lib/views/partido_view/historial_partidos_view.dart`
- Métodos: `construirEstadoVacio()` y `abrirExplorarPartidos()`.

## 2. Ley de Hick

### Decisión

El historial presenta una sola lista cronológica. No muestra simultáneamente
filtros o acciones que no son necesarias para comprender las participaciones.

Cada tarjeta representa un evento y mantiene juntas la acción, el partido y
su estado.

### Resultado

El usuario puede revisar sus participaciones sin escoger entre demasiadas
opciones. Los eventos aparecen ordenados del más reciente al más antiguo.

### Evidencia

![Historial con registros](evidencias/clase-16/historial-con-registros.png)

### Referencias al código

- `backend/app/modules/partidos/service.py`
- Función: `listar_historial()`.
- `frontend_flutter/lib/views/partido_view/historial_partidos_view.dart`
- Método: `construirLista()`.

## 3. Carga cognitiva

### Decisión

Cada registro muestra primero el nombre del partido y la acción realizada.
Después presenta deporte, ubicación, fecha y estado. La fecha de registro
aparece como información secundaria.

El estado vacío explica qué ocurrió y ofrece directamente la siguiente acción.

### Resultado

El usuario puede comprender cada evento sin recordar información de otras
pantallas. Los textos acompañan a los estados y no dependen solamente de
colores o iconos.

### Evidencia

![Historial con información necesaria](evidencias/clase-16/historial-con-registros.png)

### Referencias al código

- `frontend_flutter/lib/models/historial_partido.dart`
- Propiedades: `accionTexto`, `deporteTexto` y `estadoTexto`.
- `frontend_flutter/lib/views/partido_view/historial_partidos_view.dart`
- Métodos: `construirLista()`, `construirEstadoVacio()` y
  `fechaYHoraTexto()`.

## Verificación

- El usuario autenticado solamente consulta su historial.
- Unirse a un partido genera un evento persistente.
- Los eventos se ordenan del más reciente al más antiguo.
- Existe un estado vacío.
- La interfaz maneja carga y errores.
- Las pruebas del backend y Flutter se ejecutan correctamente.