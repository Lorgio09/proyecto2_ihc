# Tarea 6 — UniSport: toda la app con E2E y la feature Suplentes

## 1. Resumen

| Suite | Antes (`de031a4`) | Después (`66a6d00`) |
|---|---|---|
| Backend (pytest) | 25 pasan | **34** pasan (+9 de suplentes) |
| Widgets Flutter | 28 pasan | **37** pasan (+9 de suplentes) |
| E2E (Linux) | 16 pasan | **17** pasan (+1 flujo de suplentes) |
| E2E (emulador Android `emulator-5554`) | — | **17** pasan (6 archivos) |

Resultados crudos: [`suite-antes.txt`](suite-antes.txt) y [`suite-despues.txt`](suite-despues.txt).

Cómo reproducir (desde la raíz del repo, con Docker y el entorno del backend listos):

```bash
./run_suite.sh antes            # backend + widgets + E2E en Linux
./run_suite.sh despues emulator-5554   # igual, E2E en el emulador
./run_e2e.sh [dispositivo]      # solo los E2E (BD, migraciones, semilla y backend incluidos)
```

## 2. Parte A — matriz de flujos

Leyenda: ✅ cubierto y pasa · ➖ no aplica · ⚠️ hueco conocido (ver §5).

| # | Flujo | Camino principal | Alternativo | Visual | Accesibilidad |
|---|---|---|---|---|---|
| 1 | Iniciar sesión | ✅ `login_test` | ✅ contraseña incorrecta | ✅ `visual_test` login | ✅ `accesibilidad_test` login |
| 2 | Registrarse | ✅ `cuenta_test` | ✅ campos vacíos · email ya usado | ✅ registro | ✅ registro |
| 3 | Recuperar contraseña | ✅ `cuenta_test` (entra con la nueva) | ✅ código incorrecto | ⚠️ | ✅ recuperar |
| 4 | Cambiar contraseña (con sesión) | ✅ `cuenta_test` | ✅ la clave vieja deja de servir | ⚠️ | ⚠️ |
| 5 | Inicio | ✅ bienvenida tras login | ➖ | ✅ inicio | ✅ inicio |
| 6 | Crear partido | ✅ `crear_partido_test` | ✅ sin fecha | ⚠️ | ⚠️ |
| 7 | Editar partido | ✅ `mis_partidos_test` | ⚠️ | ✅ Mis partidos | ✅ Mis partidos |
| 8 | Completar y reabrir equipo | ✅ `mis_partidos_test` | ✅ widget tests (cancelar) | — | — |
| 9 | Eliminar partido | ✅ `mis_partidos_test` | ✅ cancelar el borrado | — | — |
| 10 | Explorar partidos | ✅ `explorar_unirse_salir_test` | ✅ el organizador no ve los suyos | ⚠️ | ✅ explorar |
| 11 | Unirse y salir | ✅ `explorar_unirse_salir_test` | ✅ widget tests (motivos de bloqueo) | — | — |
| 12 | Historial | ✅ aparece la unión | ⚠️ | ⚠️ | ⚠️ |
| 13 | **Suplentes (nuevo)** | ✅ `suplentes_test` | ✅ equipo cerrado por el organizador sigue rechazando | — | ✅ botón con contraste |

Semilla: `backend/seed.py` (`--reset` borra los partidos de los usuarios semilla, las
cuentas `e2e-*@unisport.test` y los tokens de recuperación pendientes). Cada corrida de
`run_e2e.sh` parte del mismo estado.

## 3. Parte B — Suplentes (UniSport)

**Regla:** titulares hasta el cupo; luego suplentes; si un titular sale, sube el primer suplente.
**La prueba comprueba:** la lista cambia de suplente a titular.

| Regla | Dónde se comprueba |
|---|---|
| Con el cupo lleno, quien se une queda de suplente | backend `test_con_el_cupo_lleno…`; widget; E2E |
| Los suplentes se ordenan por llegada | backend `test_los_suplentes_se_ordenan_por_llegada` |
| Si sale un titular, sube el primer suplente | backend `test_si_sale_un_titular_sube…`; **E2E** (la lista cambia de suplente a titular) |
| Si sale un suplente, nadie sube | backend `test_si_sale_un_suplente_nadie_sube` |
| Sin suplentes, salir abre un cupo | backend `test_si_sale_un_titular_sin_suplentes…` |
| Equipo cerrado por el organizador con lugares libres sigue rechazando | backend + widget |
| Subir la capacidad promueve suplentes; bajarla solo cuenta titulares | backend (2 tests) |
| El historial registra `se_unio_suplente` y `paso_a_titular` | backend; widget; E2E |

Decisiones propias (la diapositiva no las fija): ver §4.

## 4. Decisiones y supuestos

- El orden de los suplentes es por `unido_en` (columna nueva). Los participantes ya
  existentes quedan como titulares con la hora de la migración.
- **No** se registra la salida en el historial: un test existente
  (`test_historial_permanece_despues_de_salir_del_partido`) fija que no cuenta.
- La migración `a7d3f1c8b2e5` agrega `es_suplente` y `unido_en`; se verificó
  subir → bajar → subir sobre PostgreSQL.
- El orden de errores de `unirse` cambió en un caso: quien ya está inscrito en un equipo
  lleno ahora recibe `YA_INSCRITO` (antes `EQUIPO_COMPLETO`).

## 5. Huecos y hallazgos pendientes (sin corregir)

- **Backend, token de recuperación fijo** (`123456`): `reset_user_password` busca al
  usuario solo por token. Con dos recuperaciones pendientes puede cambiar la contraseña
  de la persona equivocada. No se corrigió porque cambia el contrato; `seed.py --reset`
  limpia los tokens para que los tests sean repetibles.
- Las capturas de referencia (golden) cargan Roboto y los iconos desde el SDK de Flutter
  (`FLUTTER_ROOT`); si ese SDK cambia de versión, las fuentes pueden variar unos píxeles y
  habrá que regenerarlas con `flutter test --update-goldens test/visual_test.dart`.
- Sin captura visual ni test de accesibilidad: formulario de partido, cambiar contraseña
  e historial (marcados ⚠️ arriba).
- Los E2E de la matriz oficial del docente podrían pedir otras columnas; esta tabla es
  una propuesta propia (no se vio la diapositiva 14).

## 6. Correcciones de accesibilidad hechas por los tests

| Hallazgo | Corrección |
|---|---|
| Botón principal de 46 px de alto (mínimo 48) | `BotonGuardar` a 48 px |
| Contraste 2.61:1 del texto blanco sobre coral (mínimo 4.5) | `CoralAccesible` (4.96:1) en `BotonGuardar` |
| "Inicia Sesion" con zona táctil de 20 px | relleno vertical de 14 px |
| Botones Editar, Eliminar, Nuevo partido y Buscar sin etiqueta | `tooltip` |
| "Completar equipo" naranja y botones verdes con bajo contraste | tonos más oscuros (≥ 5:1) |
