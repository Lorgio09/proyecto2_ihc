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

Pregunta: *de quienes empiezan a unirse a un partido, ¿cuántos lo terminan?*

| Evento | Cuándo se dispara | Propiedades |
|---|---|---|
| `union_iniciada` | La app, al tocar "Unirse" en Explorar | `deporte` |
| `partido_unido` | El backend, solo cuando unirse se guardó | `deporte`, `como_suplente` |

No se guarda quién hizo la acción (ni id de usuario, ni email, ni nombre).

- Panel: `http://127.0.0.1:8000/analitica` (conteos, % que termina y últimos eventos).
- Datos en JSON: `GET /api/analitica/resumen`.
- Google Analytics 4: con `GA_MEASUREMENT_ID` y `GA_API_SECRET` en `.env`, cada evento también se envía a GA (Informes → Tiempo real). Vacíos, solo se guarda en la tabla `eventos`. Las pruebas nunca envían a GA.
