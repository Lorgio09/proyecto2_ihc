# UniSport

Aplicación para crear partidos y completar equipos.


## Iniciar el backend

Primero crea el entorno virtual:

```bash
python -m venv .venv
```

Actívalo según tu sistema operativo:

```powershell
.\.venv\Scripts\Activate.ps1
```

```bash
source .venv/bin/activate
```

Después, inicia el backend:

```bash
uvicorn app.main:app --reload
```

La documentación estará disponible en `http://127.0.0.1:8000/docs`.

## Configuración

1. Copia `.env.example` como `.env` si aún no existe.
2. Configura `DATABASE_URL` con tu PostgreSQL local.
3. Cuando se publique la aplicación, reemplaza ese valor por la URL de Neon.

# Instalar todas las dependencias
python -m pip install -r requirements.txt

# Guardar los requirements
pip freeze > requirements.txt

## Inicia el servidor:
uvicorn app.main:app --reload

# instalador para postgres
pip install "psycopg[binary]"

# PARA GENERAR CLAVE SECRETA
python -c "import secrets; print(secrets.token_urlsafe(32))"

# JWT Encriptacion
pip install pyjwt python-multipart

# PARA CAMBIOS EN LA BASE DE DATOS
alembic revision --autogenerate -m "describe el cambio"
alembic upgrade head

# Para instalar pytest
python -m pip install pytest

# para hacer las pruebas unitarias
python -m pytest -v



SELECT id, nombre, cantidad_jugadores
FROM partidos
WHERE cantidad_jugadores < 1;

UPDATE partidos
SET cantidad_jugadores = 10
WHERE id = 1;
## Analítica de interacción

Pregunta general: *en cada flujo principal, ¿cuántos de los que empiezan terminan y en qué paso se traban?*

| Flujo | Inicio (app) | Éxito (backend, solo si se guardó) |
|---|---|---|
| Crear partido | `partido_creacion_iniciada` | `partido_creado` |
| Unirse a un partido | `union_iniciada` | `partido_unido` |
| Reprogramar | `reprogramacion_iniciada` | `partido_reprogramado` |
| Validar el resultado | `resultado_registrado` | `resultado_confirmado` (y `resultado_disputado`) |
| Darse de baja | `baja_iniciada` | `baja_registrada` (`tardia`) |

Además: `tarea_fallida` (`flujo` y `motivo` de una lista fija de códigos) y `busqueda_sin_resultados` (solo qué filtros se usaron). El plan completo, con `archivo:línea` y la pregunta de cada evento, está en `evidencias/tarea-9.md`.

No se guarda quién hizo la acción (ni id de usuario, ni email, ni nombre) ni ningún texto escrito por el usuario (búsquedas, motivos).

- Panel: `http://127.0.0.1:8000/analitica` (un embudo por flujo, la caída entre pasos, la mayor caída, errores y búsquedas vacías).
- Datos en JSON: `GET /api/analitica/resumen`.
- Google Analytics 4: con `GA_MEASUREMENT_ID` y `GA_API_SECRET` en `.env`, cada evento también se envía a GA (Informes → Tiempo real). Vacíos, solo se guarda en la tabla `eventos`. Las pruebas nunca envían a GA.
