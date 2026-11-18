# UniSport

[![pruebas](https://github.com/Lorgio09/proyecto2_ihc/actions/workflows/pruebas.yml/badge.svg?branch=main)](https://github.com/Lorgio09/proyecto2_ihc/actions/workflows/pruebas.yml?query=branch%3Amain)

**Arma tu partido, completa tu equipo.** UniSport ayuda a estudiantes a organizar partidos de fútbol, básquet o vóley: crear el partido, sumar jugadores (y suplentes que suben solos cuando alguien se baja), reprogramar con aviso a los titulares, validar el resultado entre los dos equipos y llevarse o borrar sus datos cuando quieran.

Proyecto 2 de Interacción Hombre-Computador (UAGRM, 2026-2), sobre el fork de [alvaroSG34/proyecto2_ihc](https://github.com/alvaroSG34/proyecto2_ihc).

**Equipo:** Diego Andrés Astete Paz · Lorgio Choque Severiche

## Enlaces

| Qué | Dónde |
|---|---|
| **App en la nube** | https://lorgio09.github.io/proyecto2_ihc/ |
| API (documentación) | https://unisport-api.onrender.com/docs |
| Panel de analítica | https://unisport-api.onrender.com/analitica |
| Pruebas en GitHub Actions (última ejecución) | https://github.com/Lorgio09/proyecto2_ihc/actions/workflows/pruebas.yml?query=branch%3Amain |
| Sistema de diseño en Figma | _pendiente_ |
| Video de la app | _pendiente_ |
| Informe | _pendiente_ |
| Diapositivas | _pendiente_ |
| Evidencias por tarea | [`docs/evidencias/`](docs/evidencias) (Tareas 6 y 7) y [`evidencias/`](evidencias) (Tareas 8, 9, 10 y Clases 20, 22, 23) |
| Accesibilidad (Lighthouse interpretado, correcciones y contraste AA) | [`evidencias/accesibilidad.md`](evidencias/accesibilidad.md) |
| Tokens del sistema de diseño en el código | [`frontend_flutter/lib/theme/tokens.dart`](frontend_flutter/lib/theme/tokens.dart) · tabla componente ↔ archivo en [`evidencias/tokens-en-el-codigo.md`](evidencias/tokens-en-el-codigo.md) |

### Cuentas de prueba

Todas con la contraseña `Seed1234` y con datos ya cargados. En UniSport no hay roles fijos: cualquier cuenta crea partidos y se une a los de otros. Cada cuenta de prueba trae datos para recorrer un lado distinto:

| Cuenta | Para probar |
|---|---|
| `organizador@unisport.test` | Crear y administrar partidos: completar o reabrir el equipo, reprogramar, proponer equipos y registrar el resultado. |
| `jugador@unisport.test` | Explorar, unirse, ver «Me uní», salir con plazo y descargar o eliminar sus datos. |
| `jugador2@unisport.test` | Capitán rival: acepta los equipos y confirma o disputa el marcador. |
| `jugador3@unisport.test` | Baja de último momento (baja tardía). |

> El servidor gratuito se duerme cuando nadie lo usa: la primera carga puede tardar alrededor de un minuto. Un ping cada 10 minutos lo mantiene despierto.

## Pruebas

Corren solas en **GitHub Actions** en cada push ([`.github/workflows/pruebas.yml`](.github/workflows/pruebas.yml)), con un PostgreSQL de servicio cargado con la semilla:

1. **Pruebas unitarias** (backend con pytest y app con `flutter test`), con coverage.
2. **Cobertura del código del fork** con `diff-cover`: falla si alguna línea agregada en el fork queda sin probar.
3. **Pruebas E2E** (`integration_test`): la app real en Linux con `xvfb`, contra la API real.

### Coverage

| | Backend | App (Flutter) |
|---|---|---|
| **Líneas agregadas en el fork** (`diff-cover`) | **100 %** (684 de 684) | **100 %** (1.351 de 1.351) |
| Todo el código (incluye el del proyecto original) | 92 % (1.048 de 1.144) | 80 % (1.880 de 2.345) |
| Pruebas | 100 | 128 unitarias y de pantalla + 24 E2E |

**Qué queda sin probar** (todo es código del proyecto original, que no tocamos en el fork): la pantalla de cambiar contraseña (`cambiar_contraseña.dart`, 0 %), el servicio de autenticación (`auth_service.dart`, 8 %) y el modelo `usuario.dart` (5 %), la pantalla de historial (37 %), recuperar contraseña (53 %) y parte del login y el registro. En el backend, las rutas de autenticación del proyecto original. Las E2E sí recorren el login, el registro, la recuperación y el cambio de contraseña con la API real, pero esas pruebas no suman coverage. `lib/services/descarga_web.dart` solo existe en la versión web y no entra en la medición de `flutter test`.

### Comandos

Desde la raíz del repositorio:

```bash
# Backend: pruebas y coverage
cd backend
python -m pytest --cov=app --cov-report=term --cov-report=xml:../coverage/backend.xml
cd ..

# App: pruebas y coverage
cd frontend_flutter
flutter test --coverage --coverage-path=../coverage/app.lcov
cd ..

# Cobertura de las líneas agregadas en el fork (diff-cover)
git remote add upstream https://github.com/alvaroSG34/proyecto2_ihc.git   # una sola vez
git fetch upstream main
sed 's#^SF:#SF:frontend_flutter/#' coverage/app.lcov > coverage/app-repo.lcov
diff-cover coverage/backend.xml --compare-branch=upstream/main --include "backend/app/**" --fail-under=100
diff-cover coverage/app-repo.lcov --compare-branch=upstream/main --include "frontend_flutter/lib/**" --fail-under=100
```

`pytest-cov` y `diff-cover` se instalan con `pip install pytest-cov diff-cover`. Los reportes HTML de cada ejecución quedan como artefacto «reportes» en GitHub Actions.

Las E2E necesitan la API corriendo con la semilla (`python seed.py --reset`) y un dispositivo:

```bash
cd frontend_flutter
flutter test integration_test/crear_partido_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Correr el proyecto en tu máquina

Requisitos: Python 3.12, PostgreSQL 16 y Flutter 3.47.

**Backend** (`backend/`):

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows · en Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env           # Linux/macOS: cp .env.example .env · completa DATABASE_URL y SECRET_KEY
alembic upgrade head
python seed.py                   # cuentas y partidos de prueba
uvicorn app.main:app --reload    # http://127.0.0.1:8000/docs
```

**App** (`frontend_flutter/`):

```bash
flutter pub get
flutter run -d chrome                                                       # web, contra http://127.0.0.1:8000
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000  # emulador Android
```

## Despliegue

- **API**: Render, definida en [`render.yaml`](render.yaml). Cada arranque aplica las migraciones y carga la semilla que falte.
- **Base de datos**: PostgreSQL en Neon.
- **App web**: GitHub Pages, publicada por [`.github/workflows/web.yml`](.github/workflows/web.yml) en cada push a `main`.

Las claves (`DATABASE_URL`, `SECRET_KEY` y las de Google Analytics) viven solo en Render y en `backend/.env`, nunca en el repositorio.
