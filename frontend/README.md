# WorkNet · Flutter conectado a Django

El registro, acceso, recuperación, configuración, dashboard y perfil del candidato
están conectados a Django. La empresa completa su información, envía la solicitud,
consulta su estado y puede corregir un rechazo. El administrador revisa solicitudes
y aprueba o rechaza con motivo. Los dashboards usan métricas reales del backend.

La revisión humana sigue pendiente y el PR #146 permanece en borrador. La
pertenencia real de las tareas al Sprint 2 no se ha confirmado por falta del
alcance `read:project` en GitHub CLI. El nombre de una rama no acredita esa asignación.

## Recorrido actual

El formulario envía nombre, correo y contraseñas a `POST /api/register/`.
**Después del HTTP 201 se muestra el selector Candidato/Empresa** y se guarda el
rol mediante una autorización de registro de propósito limitado. La contraseña
se borra de los controladores al crear la cuenta y no se vuelve a enviar para
elegir el rol. No existe registro público de administrador.

El correo debe verificarse antes del login. Si se pospuso o perdió la elección
del rol, después de verificar e iniciar sesión se vuelve al selector. Candidato
abre su dashboard; empresa pendiente/rechazada abre información y estado; empresa
aprobada abre su dashboard; administrador abre administración.

La empresa registra razón social, NIT, sector, ubicación, correo de contacto y
descripción. No puede enviar información incompleta, aprobarse ni modificar otra
cuenta. La solicitud enviada permanece protegida durante la revisión. El rechazo
conserva el motivo, permite corregir y reenviar; la aprobación permite completar
sitio web, redes sociales y logo privado opcional. El resultado se notifica dentro
de WorkNet. Estos avisos no son pruebas de entrega de correo o notificaciones push.

El dashboard candidato muestra completitud, métricas y trabajos de Django. Perfil
permite CRUD de descripción y registros estructurados y fotografía privada. La
configuración guarda nombre y preferencias, cambia contraseña renovando el token
y elimina la cuenta solo después de contraseña y confirmación explícita.

Recordar sesión conserva la credencial con `flutter_secure_storage`, sin guardar
contraseñas. Cambiar la contraseña sustituye el token respetando esa elección.
**Cerrar sesión llama a Django para revocar el token y después borra el acceso
local.** Si falla la red no anuncia revocación confirmada y permite reintentar;
un token ya inválido también permite terminar el cierre local. HTTP 401 limpia la
sesión. La recuperación invalida los tokens anteriores y exige nuevo login.

## Arquitectura

Cada funcionalidad usa `features/<funcionalidad>/data`, `domain` y `presentation`:
`registration`, `access`, `account`, `dashboard`, `profile` y `company`.

- **Domain** define entidades, contratos de repositorio y reglas independientes
  de Flutter/HTTP. `SessionLifecycle` establece restauración, persistencia, salida
  y reemplazo de sesión; `CreateAccount`, `SubmitCompany` y `ReviewCompany`
  representan las operaciones que requieren una política propia. Las validaciones
  de registro, fechas, fotografía y datos empresariales viven en dominio.
- **Data** implementa esos contratos, interpreta las respuestas y valida su forma.
  `core/api/WorkNetApi` es la fuente HTTP compartida, con JSON/PATCH/DELETE,
  archivos, autenticación y errores. La persistencia segura y serialización de
  sesión están en `access/data`. Una respuesta incompleta produce error: no se
  reemplazan métricas o preferencias ausentes con datos de demostración.
- **Presentation** conserva pantallas, formularios y estado visual. Las pantallas
  reciben repositorios y no construyen peticiones HTTP ni interpretan JSON de red.
  El controlador de sesión comunica a Flutter los cambios de `SessionLifecycle`.
- **Composición:** `lib/composition.dart` selecciona adaptadores concretos y los
  inyecta; `lib/app.dart` conecta rutas y protege la construcción de vistas por rol,
  incluida la restauración asíncrona. El registro permite inyectar su adaptador en
  pruebas desde la raíz de la aplicación.

No se añadieron paquetes para esta reorganización ni casos de uso que solo
dupliquen cada método CRUD. Los registros profesionales conservan sus campos
estructurados para reutilizarlos en un futuro CV; todavía no se genera ese CV.

`WorkNetColors`, `ThemeData` y `ColorScheme` siguen en
`lib/core/theme/worknet_theme.dart`. Los colores compartidos, incluido el texto
secundario sobre la marca, están centralizados allí. No hay hexadecimales en
pantallas ni una paleta paralela. Paneles, formularios, tipografía y errores
consumen el tema y los componentes comunes.

## Rutas

| Ruta | Función |
| --- | --- |
| /register | Crear cuenta y elegir rol después |
| /login, /choose-role | Acceso y recuperación de una selección de rol pendiente |
| /forgot-password, /reset-password | Solicitar correo y confirmar contraseña |
| /password-updated | Resultado sin parámetros privados en la URL |
| /dashboard, /profile | Resumen y perfil del candidato |
| /account | Configuración de cuenta autenticada |
| /company | Información, estado, corrección y complementos de la empresa |
| /company-dashboard | Resumen de empresa aprobada |
| /admin-dashboard | Métricas, avisos y eventos administrativos |
| /company-reviews | Listado paginado y revisión inicial de empresas |

## Ejecutar

Backend actualizado, con migraciones aplicadas y dependencias instaladas. Desde
`backend`, iniciar `python manage.py runserver`. Desde `frontend`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 55000 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

Para correo real, completar localmente `backend/.env` a partir de `.env.example`:
`GMAIL_USER`, `GMAIL_APP_PASSWORD` y
`PASSWORD_RESET_FRONTEND_URL=http://localhost:55000/reset-password`.
No compartir ni versionar credenciales. El backend usa Django 6.1.1 y conserva
MAILERS. Registro SMTP comprobado con el enlace recibido aportado por el usuario:
verificación persistida y login/dashboard desde Flutter correctos. Recuperación
SMTP completada con el enlace recibido aportado por el usuario: cambio persistido,
login nuevo correcto, contraseña anterior y enlace usado rechazados. [Estado SMTP separado](../backend/docs/evidencias/revision-sprint/SMTP.md).
Los enlaces de la QA anterior se capturaron a archivos y no acreditan recepción.

El hosting debe resolver las rutas de Flutter a `index.html`. En desarrollo web
el origen de recuperación debe coincidir con el puerto usado. La validación
visual corresponde a escritorio y **móvil web**, no ejecución nativa.

## Pruebas y límites

Esta fase pasó `flutter analyze` sin incidencias y **77 pruebas Flutter**. La
regresión backend pasó **103 pruebas** y sus comprobaciones de configuración y
migraciones. El build web se generó correctamente; WASM no se utilizó para esta
validación. [Evidencias de la revisión actual](docs/evidencias/revision-sprint/README.md).

Siguen pendientes consulta de perfil por empresa
autorizada dentro de selección, módulos de CV/búsqueda/mensajes/historial y
detalle/postulación, gestión empresarial de ofertas/postulantes/estadísticas y
gestión de administradores/permisos. Los accesos inexistentes se identifican
claramente, sin aparentar que sus módulos están implementados. Falta revisión
humana y validación nativa; no se declara terminado el Sprint.

[Guía breve para revisar y explicar lo que funciona](docs/REVISION.md).

[Preparación de cierre: tabla por tarea, criterios y pendientes](docs/REVISION_CIERRE.md).
