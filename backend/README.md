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

# para hacer las pruebas unitarias
python -m pytest -v



SELECT id, nombre, cantidad_jugadores
FROM partidos
WHERE cantidad_jugadores < 1;

UPDATE partidos
SET cantidad_jugadores = 10
WHERE id = 1;