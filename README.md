# Work_net

Bolsa de empleo con backend Django REST y frontend Flutter en reconstrucción.
Las historias y sus criterios se mantienen en [GitHub Issues](https://github.com/Danilo2334/Work_net/issues).

## Ramas

- `develop`: backend consolidado; base de las tareas de backend.
- `frontend`: nueva interfaz Flutter, dentro de `frontend/`, usando los criterios de las historias y los mockups revisados.
- `feature/backend-sprint-2`: rama compartida para continuar el backend del Sprint 2; conserva el trabajo de HU005.
- `main`: base estable; recibe las integraciones revisadas.

La consolidación conserva los commits anteriores y retira los archivos del frontend antiguo de las versiones actuales. Los commits de Danilo y Francisco mantienen su autoría. Cambiar de cuenta de GitHub CLI no cambia el autor de los commits de Git.

## Backend disponible

- HU001: registro, roles públicos candidato/empresa y verificación de correo.
- HU002: login con token; rol efectivo de administrador para las cuentas administrativas.
- HU003: recuperación de contraseña con token de un solo uso y revocación del acceso anterior.
- HU004: consulta y edición de cuenta, cambio de contraseña, eliminación con confirmación y preferencias push.
- HU005, tarea #48: resumen del candidato con métricas, completitud del perfil y ofertas recientes.

Esto no declara terminado todo el Sprint 2. Los demás dashboards y las funciones restantes deben implementarse y revisarse según sus historias.

## Ejecutar en Windows / PowerShell

Desde `backend`, con Python 3.12 o superior y el entorno virtual activo:

```powershell
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py check
python manage.py test accounts candidate_dashboard --noinput
python manage.py runserver
```

Se utiliza la base SQLite local configurada en el proyecto. El runner crea y elimina su propia base de pruebas. Las pruebas de correo usan memoria; no envían correos reales.

### Correo y enlaces

La configuración SMTP de la integración se conserva. Para los envíos reales, completar `GMAIL_USER` y `GMAIL_APP_PASSWORD` en `backend/.env`, usando una contraseña de aplicación autorizada. Puede tomarse `backend/.env.example` como referencia. El archivo `.env` se mantiene fuera de Git.

Configurar `PASSWORD_RESET_FRONTEND_URL` con la URL de la nueva pantalla de recuperación cuando exista. Mientras se reconstruye Flutter, el correo de recuperación no tendrá una pantalla funcional de destino. El endpoint para confirmar la nueva contraseña ya está disponible.

## API

| Método | Ruta | Autenticación |
|---|---|---|
| POST | `/api/register/` | Pública |
| GET | `/api/verify-email/?token=...` | Enlace firmado |
| POST | `/api/login/` | Pública |
| POST | `/api/password-recovery/request/` | Pública |
| POST | `/api/password-recovery/confirm/` | UID y token de recuperación |
| GET, PATCH | `/api/account/` | Token |
| POST | `/api/account/password/` | Token |
| DELETE | `/api/account/delete/` | Token y confirmación |
| GET, PATCH | `/api/account/notifications/` | Token |
| GET | `/api/dashboard/candidate/` | Token de candidato |

Encabezado: `Authorization: Token <token>`. Después de cambiar la contraseña desde configuración, guardar el token nuevo. La recuperación de contraseña requiere un nuevo login.

## HU005 y futuras historias

El resumen consulta datos persistentes en `candidate_dashboard`: perfil, ofertas, postulaciones, guardados y notificaciones. Las siguientes historias deberán extender o reutilizar esas entidades, evitando tablas paralelas para la misma información. La publicación y edición de ofertas, la edición del perfil y las otras operaciones de escritura aún deben desarrollarse en sus historias correspondientes.

Las empresas pendientes o rechazadas y los dashboards de empresa/administrador requieren completar sus historias. El login devuelve el rol; esto no equivale a tener esos flujos terminados.

## Integración y evidencias

Trabajar por bloques funcionales. Ejecutar las pruebas de las áreas modificadas y el conjunto completo antes de integrar. Documentar resultados reales. Las capturas de UI y el resumen de una colección de API complementan la revisión; las operaciones de frontend deben verificarse contra la API real.
