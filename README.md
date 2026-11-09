# Work_net

Bolsa de empleo con backend Django REST y frontend Flutter.
Las historias y sus criterios se mantienen en [GitHub Issues](https://github.com/Danilo2334/Work_net/issues).

## Alcance vigente

La entrega final comprende **HU001–HU026**. Por decisión expresa del usuario del **08/11/2026**, HU027 — Integración con LinkedIn y #137–#141 están **canceladas/fuera de alcance**, cerradas con motivo `not_planned` y estado **Cancelada** en WORK_NET. Su preparación estática se conserva como antecedente; no hay integración LinkedIn disponible ni se requieren credenciales externas.

HU023 está integrada y verificada por [#203](https://github.com/Danilo2334/Work_net/pull/203), main `5cdd951e7e0f4c7e9fb829e1adf94beece8c5bc9`. Continúan HU024–HU026 y la revisión de los pendientes anteriores de HU006/HU007. [Guía y evidencias vigentes](frontend/docs/REVISION.md).

<details>
<summary>Corte histórico del 07/11/2026; no es el estado vigente</summary>

Estado del 07/11/2026: cierre y archivado HU015 implementados y revisados por
delegación del titular; 159 Django, 124 Flutter y 18 casos nuevos de navegador
aprobados, con los mismos 18 casos repetidos en dos bases QA nuevas. La historia
mantiene pendientes los recorridos completos del buscador
HU016 y postulación HU018, todavía no implementados.
[Guía vigente, capturas y alcance](frontend/docs/REVISION.md#hu015-cierre-y-archivado-de-ofertas--07112026).
API en #156/#158, Flutter/QA en #157, entrega conjunta en #159 y main en #160;
las cabeceras y fusiones definitivas se registran en esos PR y en el seguimiento.
Los apartados históricos conservan
sus versiones y la procedencia de sus comprobaciones.

</details>

## Ramas

- `develop`: backend consolidado; base de las tareas de backend.
- `frontend`: nueva interfaz Flutter, dentro de `frontend/`, usando los criterios de las historias y los mockups revisados.
- `feature/backend-sprint-2`: rama compartida del backend; su nombre no determina la asignación de Sprint del Project.
- `feature/hu008-selection-profile`: consulta empresarial del perfil limitada a postulaciones propias.
- `feature/backend-sprint-3`: API de currículums subidos, edición de datos y generación de PDF.
- `main`: base estable; recibe las integraciones revisadas.

La consolidación conserva los commits anteriores y retira los archivos del frontend antiguo de las versiones actuales. Los commits de Danilo y Francisco mantienen su autoría. Cambiar de cuenta de GitHub CLI no cambia el autor de los commits de Git.

## Backend disponible

- HU001: creación de cuenta, selección posterior de rol público y verificación de correo.
- HU002: login con token, estados empresariales reales y cierre de sesión con revocación remota.
- HU003: recuperación de contraseña con token de un solo uso y revocación del acceso anterior.
- HU004: consulta y edición de cuenta, cambio de contraseña, eliminación con confirmación y preferencias push.
- HU005, tarea #48: resumen del candidato con métricas, completitud del perfil y ofertas recientes.
- HU008: CRUD del perfil propio, fotografía privada y reutilización efectiva para CV; consulta empresarial autorizada por postulación propia.
- HU009/HU010: información empresarial, solicitud, revisión administrativa, rechazo con motivo, corrección, reenvío y aprobación; avisos dentro de WorkNet.
- HU006/HU007: resúmenes de empresa aprobada y administrador, con datos reales y permisos por rol.
- HU011: carga, consulta, reemplazo y retirada de un CV PDF privado.
- HU012: precarga del perfil, guardado y edición del CV, tres plantillas y generación de PDF.
- HU013: catálogos y publicación de ofertas por la empresa aprobada propietaria.
- HU014: consulta y edición de ofertas propias activas, sin cambiar identidad ni requerir otra aprobación.
- HU015: cierre/archivado de ofertas propias con confirmación y consulta de conservadas; datos y postulaciones intactos, consultas activas filtradas y bloqueo de nuevas escrituras sobre inactivas. El buscador completo y la postulación de HU016/HU018 siguen pendientes.

El Project WORK_NET se consultó con Francisco y `read:project`: Sprint 1 contiene
HU001–HU004 y #29–#46; Sprint 2, HU005–HU010 y #47–#70; Sprint 3, HU011–HU017 y
#71–#79. La consulta del 07/11/2026 confirma #80–#83 en Sprint 3; no se modificaron los Sprint de las tareas futuras. Se conservaron esas
asignaciones. La revisión técnica delegada y su integración se documentan en la
guía vigente; los módulos futuros conservan su alcance pendiente.

La selección de CV al postular sigue pendiente de HU018.

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

La pantalla de recuperación ya existe. Configurar `PASSWORD_RESET_FRONTEND_URL=http://localhost:55000/reset-password` al ejecutar Flutter en ese puerto. Django instalado: 6.1.1; se conserva [MAILERS](https://docs.djangoproject.com/en/6.1/topics/email/#configuring-email). Registro SMTP verificado mediante el enlace recibido que aportó el usuario: HTTP 200, verificación persistida y login/dashboard desde Flutter correctos. Recuperación completada con el enlace recibido aportado por el usuario: cambio persistido, nueva contraseña aceptada desde Flutter, anterior y enlace usado rechazados; sesiones revocadas. [Estado del correo](https://github.com/Danilo2334/Work_net/issues/31#issuecomment-6272920035). El correo a archivos usado en la QA anterior no acredita entrega SMTP.

## API

| Método | Ruta | Autenticación |
|---|---|---|
| POST | `/api/register/` | Pública |
| POST | `/api/register/role/` | Autorización limitada del registro o sesión propia sin rol |
| GET | `/api/verify-email/?token=...` | Enlace firmado |
| POST | `/api/login/` | Pública |
| POST | `/api/logout/` | Token que se revoca |
| POST | `/api/password-recovery/request/` | Pública |
| POST | `/api/password-recovery/confirm/` | UID y token de recuperación |
| GET, PATCH | `/api/account/` | Token |
| POST | `/api/account/password/` | Token |
| DELETE | `/api/account/delete/` | Token y confirmación |
| GET, PATCH | `/api/account/notifications/` | Token |
| GET | `/api/dashboard/candidate/` | Token de candidato |
| GET, PATCH | `/api/company/` | Token de la empresa propietaria |
| POST | `/api/company/submit/` | Empresa con información completa |
| PUT, GET, DELETE | `/api/company/logo/` | Empresa aprobada propietaria; JPEG/PNG privado |
| GET | `/api/admin/companies/` | Administrador; listado paginado |
| POST | `/api/admin/companies/{id}/review/` | Administrador; versión y motivo si rechaza |
| GET | `/api/dashboard/company/` | Empresa aprobada |
| GET | `/api/dashboard/admin/` | Administrador |
| GET, POST, PATCH, DELETE | `/api/profile/candidate/` | Candidato propietario verificado |
| GET, POST | `/api/profile/candidate/<section>/` | Candidato propietario verificado |
| GET, PATCH, DELETE | `/api/profile/candidate/<section>/<uuid>/` | Candidato propietario verificado |
| GET, PUT, DELETE | `/api/profile/candidate/photo/` | Candidato propietario verificado |
| GET | `/api/company/applications/<id>/profile/` | Empresa aprobada dueña de la oferta |
| GET | `/api/company/applications/<id>/profile/photo/` | Empresa aprobada dueña de la oferta |
| POST | `/api/admin/companies/<id>/review/` | Administrador |
| GET | `/api/curriculum/` | Candidato propietario verificado |
| GET, PUT, DELETE | `/api/curriculum/uploaded/` | Candidato propietario verificado |
| GET, PUT, PATCH, DELETE | `/api/curriculum/generated/` | Candidato propietario verificado |
| POST | `/api/curriculum/generated/preview/` | Candidato propietario verificado |
| GET | `/api/curriculum/generated/pdf/` | Candidato propietario verificado |
| GET, POST | `/api/company/offers/` | Empresa propietaria aprobada y verificada |

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

El resumen consulta datos persistentes en `candidate_dashboard`: perfil, ofertas, postulaciones, guardados y notificaciones. El perfil propio ya se edita desde Flutter. CV subido/generado y publicación HU013 ya están implementados en los PR #146–#149 y comprobados en combinación aislada; su integración se valida en el bloque delegado actual. Gestión de ofertas, búsqueda, mensajes, estadísticas y gestión de postulantes pertenecen a historias futuras; no se iniciaron en este bloque. Las siguientes historias deben reutilizar las entidades existentes.

El login distingue empresa Pendiente/Aprobada/Rechazada. Solo la aprobada accede a su resumen. La consulta de perfiles requiere además una postulación a una oferta propia. [Contrato empresarial y sesión](backend/accounts/COMPANY_API.md).

La consulta empresarial del perfil usa una postulación existente y comprueba
la propiedad de su oferta en cada petición. No implementa el listado, filtros,
cambios de estado o selección de CV de los módulos futuros.

## Integración y evidencias

Trabajar por bloques funcionales. Ejecutar las pruebas de las áreas modificadas y el conjunto completo antes de integrar. Documentar resultados reales. Las capturas de UI y el resumen de una colección de API complementan la revisión; las operaciones de frontend deben verificarse contra la API real.

[Guía para revisar la aplicación](frontend/docs/REVISION.md) · [Frontend y arquitectura](frontend/README.md).

[Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues).


## Historial: retoma hasta HU013 — 07/11/2026

El seguimiento vigente y la aceptación técnica conjunta están en la [guía existente](frontend/docs/REVISION.md#retoma-de-danilo-aceptación-hasta-hu013--07112026), con [resultados sin secretos](frontend/docs/evidencias/retoma-20261107/resultados.json). Nuevo QA de aceptación/Postman/evidencias: Francisco; backend: Danilo. Se conserva la autoría histórica de sus implementaciones y pruebas.

Los PR #146–#149 continúan en borrador. HU013 está publicado en #148 (backend) y #149 (Flutter); las APIs de CV y ofertas todavía requieren incorporar de forma revisada #148/#147 al backend de entrega antes de #146. La combinación aislada pasó 141 Django, 110 Flutter, análisis y compilación JavaScript, más comprobaciones HTTP y Newman identificadas por separado. En el primer bloque no conectó Computer Use; su error de pipe nativo continúa y no se repitió Postman Desktop. En la continuación autorizada, un Chromium temporal independiente sí completó la aceptación visual restante HU012/HU013: [25 casos y 37 capturas inspeccionadas](frontend/docs/evidencias/retoma-20261107/aceptacion-visual/resultados.json). Se corrigió la reentrada rápida del editor después de descartar cambios; pasaron 46 pruebas pertinentes, análisis y compilación. [Resultados y revisiones preparadas](frontend/docs/REVISION.md#aceptación-visual-y-revisiones-preparadas--07112026). HU018 mantiene pendiente la selección del CV en postulaciones. La evidencia histórica conserva su fecha y alcance; no se inició HU014–HU027, no se fusionó ni se inventaron revisiones humanas.
