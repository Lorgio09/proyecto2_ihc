# Tarea 02 - Cambio de estado

## Proyecto

UniSport

## Módulo

Partidos

## Funcionalidad implementada

Se agregó una acción que permite cambiar el estado de un partido.

Estado inicial:

Cupos abiertos

Acción:

Completar equipo

Estado final:

equipo completo

## Regla de negocio

Un partido solamente puede cambiar de:

Cupos abiertos -> equipo completo

Si el partido ya se encuentra en estado "equipo completo",
la acción es rechazada.

## Persistencia

El estado se almacena en la base de datos mediante el campo:

`estado`

del modelo `Partido`.

Por este motivo, el cambio se conserva después de recargar
la aplicación.

## Pruebas unitarias

Se implementaron cuatro pruebas:

1. El estado inicial es "Cupos abiertos".
2. La acción "Completar equipo" cambia correctamente el estado.
3. No se permite completar dos veces el mismo equipo.
4. Los demás datos del partido se conservan.

## Ejecutar pruebas

Desde la carpeta backend:

```bash
pytest -m pytest -v
```