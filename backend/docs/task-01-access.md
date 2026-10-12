# Tarea 1: Acceso y sesión

## Alcance actual

- Registro de una cuenta nueva.
- Inicio y cierre de sesión.
- Recuperación y cambio de contraseña sin correo real.
- Sesión conservada al recargar.
- Ruta pública y ruta privada `Mis partidos`.
- Nombre de la persona autenticada dentro de la ruta privada.

## Decisiones técnicas

- Backend: FastAPI.
- Base de datos local: PostgreSQL.
- Producción: Neon PostgreSQL.
- La URL de base de datos se configura con `DATABASE_URL`.
