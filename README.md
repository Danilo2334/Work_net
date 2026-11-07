# Work_net

Bolsa de empleo con backend Django REST y frontend Flutter en reconstrucción.
Las historias y sus criterios se mantienen en [GitHub Issues](https://github.com/Danilo2334/Work_net/issues).

## Ramas

- `develop`: backend consolidado; base de las tareas de backend.
- `frontend`: nueva interfaz Flutter, dentro de `frontend/`, usando los criterios de las historias y los mockups revisados.
- `feature/backend-sprint-2`: rama compartida del backend; su nombre no determina la asignación de Sprint del Project.
- `main`: base estable; recibe las integraciones revisadas.

La consolidación conserva los commits anteriores y retira los archivos del frontend antiguo de las versiones actuales. Los commits de Danilo y Francisco mantienen su autoría. Cambiar de cuenta de GitHub CLI no cambia el autor de los commits de Git.

## Backend disponible

- HU001: creación de cuenta, selección posterior de rol público y verificación de correo.
- HU002: login con token, estados empresariales reales y cierre de sesión con revocación remota.
- HU003: recuperación de contraseña con token de un solo uso y revocación del acceso anterior.
- HU004: consulta y edición de cuenta, cambio de contraseña, eliminación con confirmación y preferencias push.
- HU005, tarea #48: resumen del candidato con métricas, completitud del perfil y ofertas recientes.
- HU008: CRUD del perfil propio y fotografía privada, con datos estructurados para un futuro CV.
- HU009/HU010: información empresarial, solicitud, revisión administrativa, rechazo con motivo, corrección, reenvío y aprobación; avisos dentro de WorkNet.
- HU006/HU007: resúmenes de empresa aprobada y administrador, con datos reales y permisos por rol.

El Project WORK_NET se consultó con Francisco y `read:project`: Sprint 1 contiene
HU001–HU004 y #29–#46; Sprint 2, HU005–HU010 y #47–#70; Sprint 3, HU011–HU017 y
#71–#79. La consulta del 07/11/2026 confirma #80–#83 en Sprint 3; no se modificaron los Sprint de las tareas futuras. Se conservaron esas
asignaciones. Los módulos futuros y la revisión humana siguen pendientes;
el PR #146 permanece en borrador.

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

Encabezado: `Authorization: Token <token>`. Después de cambiar la contraseña desde configuración, guardar el token nuevo. La recuperación de contraseña requiere un nuevo login.

## HU005 y futuras historias

El resumen consulta datos persistentes en `candidate_dashboard`: perfil, ofertas, postulaciones, guardados y notificaciones. El perfil propio ya se edita desde Flutter. CV subido/generado y publicación HU013 ya están implementados en los PR #146–#149 y comprobados en combinación aislada; conservan revisión humana e integración pendientes. Gestión de ofertas, búsqueda, mensajes, estadísticas y gestión de postulantes pertenecen a historias futuras; no se iniciaron en este bloque. Las siguientes historias deben reutilizar las entidades existentes.

El login distingue empresa Pendiente/Aprobada/Rechazada. Solo la aprobada accede a su resumen. La revisión inicial de empresa no acredita una autorización de selección para consultar perfiles de candidatos: esa consulta sigue restringida. [Contrato empresarial y sesión](backend/accounts/COMPANY_API.md).

## Integración y evidencias

Trabajar por bloques funcionales. Ejecutar las pruebas de las áreas modificadas y el conjunto completo antes de integrar. Documentar resultados reales. Las capturas de UI y el resumen de una colección de API complementan la revisión; las operaciones de frontend deben verificarse contra la API real.

[Guía para revisar la aplicación](frontend/docs/REVISION.md) · [Frontend y arquitectura](frontend/README.md).

[Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues).


## Retoma hasta HU013 — 07/11/2026

El seguimiento vigente y la aceptación técnica conjunta están en la [guía existente](frontend/docs/REVISION.md#retoma-de-danilo-aceptación-hasta-hu013--07112026), con [resultados sin secretos](frontend/docs/evidencias/retoma-20261107/resultados.json). Nuevo QA de aceptación/Postman/evidencias: Francisco; backend: Danilo. Se conserva la autoría histórica de sus implementaciones y pruebas.

Los PR #146–#149 continúan en borrador. HU013 está publicado en #148 (backend) y #149 (Flutter); las APIs de CV y ofertas todavía requieren incorporar de forma revisada #148/#147 al backend de entrega antes de #146. La combinación aislada pasó 141 Django, 110 Flutter, análisis y compilación JavaScript, más comprobaciones HTTP y Newman identificadas por separado. En el primer bloque no conectó Computer Use; su error de pipe nativo continúa y no se repitió Postman Desktop. En la continuación autorizada, un Chromium temporal independiente sí completó la aceptación visual restante HU012/HU013: [25 casos y 37 capturas inspeccionadas](frontend/docs/evidencias/retoma-20261107/aceptacion-visual/resultados.json). Se corrigió la reentrada rápida del editor después de descartar cambios; pasaron 46 pruebas pertinentes, análisis y compilación. [Resultados y revisiones preparadas](frontend/docs/REVISION.md#aceptación-visual-y-revisiones-preparadas--07112026). HU018 mantiene pendiente la selección del CV en postulaciones. La evidencia histórica conserva su fecha y alcance; no se inició HU014–HU027, no se fusionó ni se inventaron revisiones humanas.
