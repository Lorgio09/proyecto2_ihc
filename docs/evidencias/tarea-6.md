# Tarea 6 - Pruebas de punta a punta y suplentes (UniSport)

## Que se hizo

1. Se escribieron pruebas E2E con `integration_test` para todos los flujos de la app (acceso, cuenta, crear partido, Mis partidos, explorar, unirse y salir, historial).
2. Se agregaron pruebas de accesibilidad y capturas de referencia (golden) para las pantallas principales, y se corrigieron en la interfaz los problemas que encontraron.
3. Se corrio toda la suite **antes** de tocar la feature.
4. Se agrego la feature de **suplentes**: los titulares llegan hasta el cupo del partido, quien se une despues queda como suplente (en orden de llegada) y, si un titular sale, sube el primer suplente.
5. Se volvio a correr toda la suite **despues** de la feature.

## Como se corren las pruebas

Las pruebas usan la app real contra el backend real y la base PostgreSQL en Docker. `run_e2e.sh` levanta la base, aplica las migraciones, **reinicia los datos de ejemplo** (`seed.py --reset`), arranca el backend y corre cada archivo E2E.

```bash
# Solo los E2E (en Linux de escritorio o en el emulador Android Galaxy_S25)
./run_e2e.sh                  # linux
./run_e2e.sh emulator-5554    # emulador

# Backend
cd backend && source .venv/bin/activate && python -m pytest

# Pruebas de widgets, accesibilidad y capturas de referencia
cd frontend_flutter && flutter test

# Todo junto, guardando la salida en docs/evidencias/tarea-6/
./run_suite.sh antes
./run_suite.sh despues [dispositivo]
```

Se probo en Linux de escritorio y en el emulador Android (los 17 E2E pasan en ambos). La suite "antes" se corrio solo en Linux.

`run_e2e.sh` se niega a correr si el puerto 8000 esta ocupado por otro servicio que no es UniSport (reutilizarlo hace fallar todos los E2E con "Not Found"). En ese caso se usa otro puerto: `E2E_PORT=8010 ./run_e2e.sh`. La suite "despues" de esta carpeta se corrio asi, con el codigo de este commit.

## Resumen

| Suite | Antes | Despues |
|---|---|---|
| Backend (pytest) | 3 archivos, 25 de 25 pasan | 4 archivos, 34 de 34 pasan |
| Widgets Flutter (incluye accesibilidad y capturas) | 8 archivos, 28 de 28 pasan | 9 archivos, 37 de 37 pasan |
| E2E Flutter | 5 archivos, 16 de 16 pasan | 6 archivos, 17 de 17 pasan |

Las salidas completas estan en la carpeta `tarea-6/`.

## Matriz de pruebas E2E

| # | Archivo | Flujo | Prueba | Antes | Despues |
|---|---|---|---|---|---|
| 1 | login_test.dart | Iniciar sesion | Un jugador inicia sesion y ve su bienvenida | Pasa | Pasa |
| 2 | login_test.dart | Iniciar sesion | Un jugador ingresa una contraseña incorrecta y ve el error | Pasa | Pasa |
| 3 | cuenta_test.dart | Crear cuenta | Un visitante se registra y llega a su bienvenida | Pasa | Pasa |
| 4 | cuenta_test.dart | Crear cuenta | Un visitante envia el registro vacio y ve el aviso | Pasa | Pasa |
| 5 | cuenta_test.dart | Crear cuenta | Un visitante se registra con un email ya usado y ve el error | Pasa | Pasa |
| 6 | cuenta_test.dart | Recuperar contraseña | Un usuario recupera su contraseña y entra con la nueva | Pasa | Pasa |
| 7 | cuenta_test.dart | Recuperar contraseña | Un usuario escribe un codigo de recuperacion incorrecto | Pasa | Pasa |
| 8 | cuenta_test.dart | Cambiar contraseña | Un usuario cambia su contraseña con sesion iniciada | Pasa | Pasa |
| 9 | crear_partido_test.dart | Crear partido | El organizador crea un partido y lo ve en Mis partidos | Pasa | Pasa |
| 10 | crear_partido_test.dart | Crear partido | El organizador intenta guardar sin fecha y ve el error | Pasa | Pasa |
| 11 | mis_partidos_test.dart | Mis partidos | El organizador edita la ubicacion de su partido | Pasa | Pasa |
| 12 | mis_partidos_test.dart | Mis partidos | El organizador completa su equipo y luego lo reabre | Pasa | Pasa |
| 13 | mis_partidos_test.dart | Mis partidos | El organizador cancela eliminar y el partido se queda | Pasa | Pasa |
| 14 | mis_partidos_test.dart | Mis partidos | El organizador elimina un partido y desaparece de la lista | Pasa | Pasa |
| 15 | explorar_unirse_salir_test.dart | Explorar, unirse y salir | Un jugador se une, lo ve en su historial y luego sale | Pasa | Pasa |
| 16 | explorar_unirse_salir_test.dart | Explorar, unirse y salir | El organizador no ve sus propios partidos en Explorar | Pasa | Pasa |
| 17 | suplentes_test.dart | Suplentes | Con el cupo lleno el tercero queda de suplente y sube cuando un titular sale | No existia | Pasa |

La prueba 17 recorre el caso completo con cinco sesiones: dos jugadores ocupan los dos cupos de "Duelo de dos", un tercero queda de suplente, el organizador ve titulares y suplentes por separado, sale un titular, el suplente pasa a titular y su historial lo registra.

## Pruebas del backend

| Archivo | Que prueba | Antes | Despues |
|---|---|---|---|
| test_historial_partidos.py | Consultar y registrar el historial | Pasa (4) | Pasa (4) |
| test_partidos_estados.py | Completar y reabrir el equipo | Pasa (6) | Pasa (6) |
| test_partidos_uniones.py | Unirse y salir de un partido | Pasa (15) | Pasa (15) |
| test_partidos_suplentes.py | Suplentes: cupo lleno, orden de llegada, subir al salir, capacidad | No existia | Pasa (9) |

## Pruebas de widgets, accesibilidad y capturas

Estas pruebas no estan en la tarea del otro grupo, pero la rubrica pide "visual" y "accesibilidad".

| Archivo | Que prueba | Antes | Despues |
|---|---|---|---|
| accesibilidad_test.dart | Login, registro, recuperar, Mis partidos, explorar e inicio cumplen las guias de Flutter: zona tactil (Android e iOS), etiqueta en cada control y contraste de texto | Pasa (6) | Pasa (6) |
| visual_test.dart | Login, registro, inicio y Mis partidos se ven igual que la captura base (`test/goldens/`) | Pasa (4) | Pasa (4) |
| suplentes_test.dart | Explorar, Mis partidos e historial muestran titulares y suplentes | No existia | Pasa (9) |
| Otros 6 archivos de `test/` | Formulario, reintentar, acciones de la tarjeta, completar, filtros y fecha | Pasa (18) | Pasa (18) |

## Cambios de la feature

- Base de datos: la migracion `a7d3f1c8b2e5` agrega `es_suplente` y `unido_en` a `partido_participantes`. Se verifico subir, bajar y volver a subir sobre PostgreSQL.
- Backend: no hay endpoints nuevos. `POST /api/partidos/{id}/unirse` ahora deja al usuario como suplente si el cupo esta lleno, y `DELETE /api/partidos/{id}/salir` sube al primer suplente cuando sale un titular. Subir la capacidad promueve suplentes. Las respuestas agregan `suplentes` y `cantidad_suplentes`, y el historial registra `se_unio_suplente` y `paso_a_titular`.
- App: en Explorar el boton dice "Unirse como suplente" con el cupo lleno, la tarjeta muestra "Suplentes: n" y "Eres suplente (posicion n)". En Mis partidos el organizador ve los suplentes aparte de los titulares. El historial traduce los dos eventos nuevos.
- Datos de ejemplo: `seed.py` agrega el partido "Duelo de dos" (2 cupos) y dos jugadores mas. `seed.py --reset` limpia partidos, cuentas `e2e-*` y tokens de recuperacion para que cada corrida parta del mismo estado.

## Correcciones de accesibilidad

| Hallazgo | Correccion |
|---|---|
| Boton principal de 46 px de alto (minimo 48) | `BotonGuardar` a 48 px |
| Contraste 2.61:1 del texto blanco sobre coral (minimo 4.5) | `CoralAccesible` (4.96:1) en `BotonGuardar` |
| "Inicia Sesion" con zona tactil de 20 px | relleno vertical de 14 px |
| Botones Editar, Eliminar, Nuevo partido y Buscar sin etiqueta | `tooltip` |
| "Completar equipo" naranja y botones verdes con bajo contraste | tonos mas oscuros (5:1 o mas) |

## Decisiones y supuestos

- El orden de los suplentes es por `unido_en`. Los participantes ya existentes quedan como titulares con la hora de la migracion.
- No se registra la salida en el historial: un test existente (`test_historial_permanece_despues_de_salir_del_partido`) fija que no cuenta.
- Si el organizador cierra el equipo con lugares libres, unirse sigue rechazandose ("El equipo ya esta completo"). Solo un equipo lleno por cupo acepta suplentes.
- El orden de errores de `unirse` cambio en un caso: quien ya esta inscrito en un equipo lleno recibe `YA_INSCRITO` (antes `EQUIPO_COMPLETO`).

## Huecos y hallazgos pendientes

- **Backend, token de recuperacion fijo** (`123456`): el reseteo busca al usuario solo por token. Con dos recuperaciones pendientes puede cambiar la contraseña de otra persona. No se corrigio porque cambia el contrato de la API; `seed.py --reset` limpia los tokens para que las pruebas sean repetibles.
- Sin captura visual ni prueba de accesibilidad: formulario de partido, cambiar contraseña e historial.
- Las capturas de referencia cargan Roboto y los iconos desde el SDK de Flutter (`FLUTTER_ROOT`). Si cambia la version del SDK, puede haber diferencias de unos pixeles y hay que regenerarlas con `flutter test --update-goldens test/visual_test.dart`.
