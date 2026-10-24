# Work_net

Bolsa de empleo con backend Django REST y frontend Flutter.
Las historias y sus criterios se mantienen en [GitHub Issues](https://github.com/Danilo2334/Work_net/issues).

## Ramas

- `develop`: backend consolidado; base de las tareas de backend.
- `frontend`: nueva interfaz Flutter, dentro de `frontend/`, usando los criterios de las historias y los mockups revisados.
- `feature/backend-sprint-2`: rama compartida para continuar el backend del Sprint 2; conserva el trabajo de HU005.
- `feature/hu008-selection-profile`: consulta empresarial del perfil limitada a postulaciones propias.
- `feature/backend-sprint-3`: API de currículums subidos, edición de datos y generación de PDF.
- `main`: base estable; recibe las integraciones revisadas.

La consolidación conserva los commits anteriores y retira los archivos del frontend antiguo de las versiones actuales. Los commits de Danilo y Francisco mantienen su autoría. Cambiar de cuenta de GitHub CLI no cambia el autor de los commits de Git.

## Backend disponible

- HU001: registro, roles públicos candidato/empresa y verificación de correo.
- HU002: login con token; rol efectivo de administrador para las cuentas administrativas.
- HU003: recuperación de contraseña con token de un solo uso y revocación del acceso anterior.
- HU004: consulta y edición de cuenta, cambio de contraseña, eliminación con confirmación y preferencias push.
- HU005–HU007: resúmenes con métricas propias de candidato, empresa aprobada y administrador.
- HU008: perfil estructurado y fotografía privada; consulta empresarial por postulación a una oferta propia.
- HU009/HU010: información empresarial, solicitud, aprobación, rechazo con motivo y reenvío.
- HU011: carga, consulta, reemplazo y retirada de un CV PDF privado.
- HU012: precarga del perfil, guardado y edición del CV, tres plantillas y generación de PDF.

Las dos últimas APIs están preparadas para integrar las pantallas Flutter del Sprint 3.
Los dashboards conservan accesos pendientes a sus módulos futuros. La selección
del CV dentro de una postulación depende de HU018; no queda implementada por
tener un documento guardado o una lista de opciones.

## Ejecutar en Windows / PowerShell

Desde `backend`, con Python 3.12 o superior y el entorno virtual activo:

```powershell
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py check
python manage.py test accounts candidate_dashboard curriculum --noinput
python manage.py runserver
```

Se utiliza la base SQLite local configurada en el proyecto. El runner crea y elimina su propia base de pruebas. Las pruebas de correo usan memoria; no envían correos reales.

### Correo y enlaces

La configuración SMTP de la integración se conserva. Para los envíos reales, completar `GMAIL_USER` y `GMAIL_APP_PASSWORD` en `backend/.env`, usando una contraseña de aplicación autorizada. Puede tomarse `backend/.env.example` como referencia. El archivo `.env` se mantiene fuera de Git.

Configurar `PASSWORD_RESET_FRONTEND_URL` con la pantalla Flutter de recuperación,
por ejemplo `http://localhost:55000/reset-password`. El puerto debe coincidir con
el frontend abierto. La guía de Postman usa correo a archivos y una base aislada;
esa ejecución no sustituye las comprobaciones de entrega SMTP real.

## API

| Método | Ruta | Autenticación |
|---|---|---|
| POST | `/api/register/` | Pública |
| POST | `/api/register/role/` | Ticket limitado de registro o token de cuenta sin rol |
| GET | `/api/verify-email/?token=...` | Enlace firmado |
| POST | `/api/login/` | Pública |
| POST | `/api/logout/` | Token; revoca el acceso usado |
| POST | `/api/password-recovery/request/` | Pública |
| POST | `/api/password-recovery/confirm/` | UID y token de recuperación |
| GET, PATCH | `/api/account/` | Token |
| POST | `/api/account/password/` | Token |
| DELETE | `/api/account/delete/` | Token y confirmación |
| GET, PATCH | `/api/account/notifications/` | Token |
| GET | `/api/dashboard/candidate/` | Token de candidato |
| GET | `/api/dashboard/company/` | Empresa aprobada |
| GET | `/api/dashboard/admin/` | Administrador |
| GET, POST, PATCH, DELETE | `/api/profile/candidate/` | Candidato propietario verificado |
| GET, POST | `/api/profile/candidate/<section>/` | Candidato propietario verificado |
| GET, PATCH, DELETE | `/api/profile/candidate/<section>/<uuid>/` | Candidato propietario verificado |
| GET, PUT, DELETE | `/api/profile/candidate/photo/` | Candidato propietario verificado |
| GET | `/api/company/applications/<id>/profile/` | Empresa aprobada dueña de la oferta |
| GET | `/api/company/applications/<id>/profile/photo/` | Empresa aprobada dueña de la oferta |
| GET, PATCH | `/api/company/` | Empresa propietaria |
| POST | `/api/company/submit/` | Empresa propietaria |
| GET, PUT, DELETE | `/api/company/logo/` | Empresa aprobada propietaria |
| GET | `/api/admin/companies/` | Administrador |
| POST | `/api/admin/companies/<id>/review/` | Administrador |
| GET | `/api/curriculum/` | Candidato propietario verificado |
| GET, PUT, DELETE | `/api/curriculum/uploaded/` | Candidato propietario verificado |
| GET, PUT, PATCH, DELETE | `/api/curriculum/generated/` | Candidato propietario verificado |
| POST | `/api/curriculum/generated/preview/` | Candidato propietario verificado |
| GET | `/api/curriculum/generated/pdf/` | Candidato propietario verificado |

Encabezado: `Authorization: Token <token>`. Después de cambiar la contraseña desde configuración, guardar el token nuevo. La recuperación de contraseña requiere un nuevo login.

El [contrato del perfil](backend/candidate_dashboard/PROFILE_API.md) detalla las
secciones, validaciones y permisos de selección. La [guía de Postman](backend/postman/README.md)
explica cómo preparar y repetir los casos, conservando las colecciones anteriores.

## Contrato de currículums

`GET /api/curriculum/` devuelve `uploaded`, `generated`, `options` y `limits`.
Los dos primeros son null si no hay documentos guardados. `options` contiene
`source` (`uploaded` o `generated`) y `label`; prepara la integración de selección
del documento, pero no crea una postulación ni concede acceso empresarial al CV.

### PDF subido

Enviar `PUT /api/curriculum/uploaded/` como multipart con un único campo `file`.
Se comprueban extensión `.pdf`, MIME `application/pdf`, estructura real, máximo
**5 MiB** y entre **1 y 50 páginas**. Se rechazan archivos cifrados, formularios,
acciones activas y adjuntos. Los enlaces HTTP, HTTPS y correo sí se admiten.
Una carga inválida conserva el archivo anterior. Primera carga HTTP 201;
reemplazo HTTP 200. La respuesta incluye nombre saneado, tamaño y fecha.

GET devuelve los bytes del PDF propio; DELETE retira solamente ese CV. El PDF
se guarda en una fila privada, sin ruta pública ni `MEDIA_URL`. Las respuestas
usan `private, no-store`, `Vary: Authorization` y `nosniff`; el token va en el
encabezado, nunca en la URL. La consulta de metadatos no carga los bytes del PDF.

### CV creado con plantillas

GET devuelve `exists` y `curriculum` con `template`, `data` y `updated_at`.
Si no existe, precarga nombre y correo de la cuenta, resumen y cuatro secciones
del perfil; consultar el borrador no crea registros. Un CV ya guardado conserva
su edición, aunque después cambie el perfil de origen.

PUT guarda el documento completo. PATCH con solo `template` cambia la presentación
sin perder datos. Si PATCH incluye `data`, ese bloque se reemplaza completo:
el editor debe enviar todas sus secciones. Los datos del CV son independientes
del nombre, correo y contraseña de la cuenta. No se aceptan IDs de propietarios
ni campos desconocidos.

| Campo de `data` | Contenido |
|---|---|
| `personal` | `full_name` obligatorio; `email`, `phone`, `location`, `website` opcionales |
| `professional_summary` | Resumen, hasta 5000 caracteres |
| `education` | Hasta 100 registros con `qualification`, `institution`, fechas y descripción |
| `experience` | Hasta 100 registros con `position`, `company`, fechas y descripción |
| `skills`, `languages` | Hasta 100 registros por lista; `name` y `level`, como en el perfil |
| `certifications` | Hasta 100 registros con `title`, `issuer`, `issue_date` y `description` |
| `extra_sections` | Hasta 10 secciones con `title` (120 caracteres) y `content` (3000) |

Las listas opcionales vacías se conservan. Fechas ISO `YYYY-MM-DD` o null;
en educación y experiencia, la final no puede preceder a la inicial. El bloque
de datos admite hasta 128 KiB de texto UTF-8. Las plantillas son `clasica`,
`moderna` y `minimalista`.

POST a `generated/preview/` recibe el mismo cuerpo que PUT y devuelve un PDF sin
guardar. GET a `generated/pdf/` descarga el documento guardado. El texto se
escapa antes de componer el PDF: no se interpreta HTML ni se cargan imágenes o
recursos remotos. Hay paginación automática y números de página. DELETE sobre
`generated/` conserva el CV subido, el perfil y la cuenta.

Sin sesión se devuelve 401; roles ajenos o candidato sin verificar, 403;
documento guardado ausente, 404. Los errores de datos devuelven 400 con `message`
y `errors`. La empresa todavía no descarga un CV: HU018/HU020 deberán conservar
el documento elegido en la postulación y aplicar la autorización correspondiente.

## HU005 y futuras historias

El resumen consulta datos persistentes en `candidate_dashboard`: perfil, ofertas,
postulaciones, guardados y notificaciones. Las siguientes historias deben extender
esas entidades, evitando tablas paralelas. La publicación y edición de ofertas,
búsqueda, historial, mensajería y gestión completa de postulantes corresponden a
sus propias historias.

La consulta empresarial del perfil usa una postulación existente y comprueba
la propiedad de su oferta en cada petición. No implementa el listado, filtros,
cambios de estado o selección de CV de los módulos futuros.

## Integración y evidencias

Trabajar por bloques funcionales. Ejecutar las pruebas de las áreas modificadas y el conjunto completo antes de integrar. Documentar resultados reales. Las capturas de UI y el resumen de una colección de API complementan la revisión; las operaciones de frontend deben verificarse contra la API real.
