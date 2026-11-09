# WorkNet · Flutter conectado a Django

## Alcance vigente

HU001–HU026 y **HU028** están entregadas en main: 27 historias y 112 subtareas completadas. **HU027 — Integración con LinkedIn queda para la segunda versión** (#28 y #137–#141 abiertas); su preparación específica se retiró de los archivos vigentes. El perfil y CV manuales siguen disponibles. El antecedente de #196/#197 permanece en Git, sin callback operativo ni pasos de configuración activos.

**HU028 — Asistente de creación de currículum con IA (#224)** añade una propuesta revisable al generador existente. Se informa el envío a Gemini y se exige consentimiento; el perfil propio se incluye solo al marcarlo. Generar no guarda: aplicar cambia el borrador local y Guardar confirma la persistencia. Las tres plantillas y la descarga PDF reutilizan HU012. Clave y modelo se configuran únicamente en backend, fuera de Git. La aceptación real quedó completada y fusionada mediante [PR #236](https://github.com/Danilo2334/Work_net/pull/236): API 8/8, navegador 14/14 y Postman Desktop 18 peticiones/52 comprobaciones aprobadas.

La procedencia, comprobaciones y límites se registran en [la guía existente](docs/REVISION.md).

El registro, acceso, recuperación, configuración, dashboard y perfil del candidato
están conectados a Django. La empresa completa su información, envía la solicitud,
consulta su estado y puede corregir un rechazo. El administrador revisa solicitudes
y aprueba o rechaza con motivo. Los dashboards usan métricas reales del backend.

<details>
<summary>Antecedente de revisión y planificación del 07/11/2026</summary>

La revisión humana sigue pendiente y el PR #146 permanece en borrador.
El Project WORK_NET se consultó con Francisco y `read:project`: HU005–HU010
y #47–#70 están en Sprint 2; HU011–HU017 y #71–#79, en Sprint 3.
Las tareas #80–#99 todavía no tienen Sprint asignado, aunque sus historias sí.

</details>

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

Para cuentas administrativas, la contraseña devuelve HTTP202 con un desafío y ningún Token. El panel de doble factor configura el autenticador y exige TOTP confirmado antes de aceptar la sesión; las claves y los códigos de recuperación permanecen ocultos por defecto. Recuperar el acceso obliga a enrolar otro autenticador. El principal crea cuentas desde `/admin/accounts`; los permisos determinan los accesos a cuentas, solicitudes y `/admin/events`.

Las respuestas tardías de operaciones anteriores no pueden modificar ni cerrar otra sesión. La descarga de CV generado usa el selector nativo de documentos en Android y conserva el guardado de bytes en web; no expone Tokens en enlaces.

## Arquitectura

Las funcionalidades usan `features/<funcionalidad>/data`, `domain` y `presentation`.
Incluyen acceso, cuenta, dashboards, perfil, empresa, CV, ofertas, postulaciones,
postulantes, estados, mensajes, notificaciones, estadísticas y administración.

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
estructurados para reutilizarlos en CV. El editor de HU012 usa la precarga del
backend, conserva una copia independiente y ofrece tres plantillas, vista previa
y descarga del PDF guardado. La aceptación visual y de Postman Desktop está
documentada en la guía, incluida la selección del CV en HU018. La revisión final
añade el guardado auténtico por SAF en Android emulado, con cancelación y contraste
del PDF contra la base QA independiente.

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
| /curriculum | PDF subido y acceso al creador |
| /curriculum/create | Edición del CV generado, plantillas, vista previa y descarga |
| /account | Configuración de cuenta autenticada |
| /company | Información, estado, corrección y complementos de la empresa |
| /company-dashboard | Resumen de empresa aprobada |
| /admin-dashboard | Métricas, avisos y eventos administrativos |
| /company-reviews | Listado paginado y revisión inicial de empresas |
| /offers/search, /offers/saved | Buscador y favoritos del candidato |
| /offers/:id/apply | Postulación y selección del CV |
| /applications, /applications/:id | Historial y detalle propio |
| /company/offers, /company/offers/preserved | Ofertas propias activas y conservadas |
| /company/applicants, /company/offers/:id/applicants | Postulantes autorizados y filtros |
| /messages, /messages/:id | Conversaciones autorizadas |
| /notifications, /statistics | Avisos y métricas según rol |
| /admin/accounts, /admin/events | Cuentas, permisos y eventos administrativos |

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
login nuevo correcto, contraseña anterior y enlace usado rechazados. [Estado SMTP separado](https://github.com/Danilo2334/Work_net/issues/31#issuecomment-6272920035).
Los enlaces de la QA anterior se capturaron a archivos y no acreditan recepción.

El hosting debe resolver las rutas de Flutter a `index.html`. En desarrollo web
el origen de recuperación debe coincidir con el puerto usado. La validación
visual general corresponde a escritorio y **móvil web**; las comprobaciones
nativas específicas de exportación y CV en Android emulado se describen aparte.

## Pruebas y límites

Los resultados y las capturas de Flutter y Postman se conservan en el comentario único de cada tarea en GitHub. Las instrucciones de ejecución anteriores permiten iniciar la aplicación; las cuentas y datos de QA se describen en la guía de revisión.

La aceptación final de HU028 aprobó **237 pruebas Flutter y 301 Django**;
análisis sin incidencias y compilación web release correcta. Se acreditaron cuatro
generaciones Gemini entre API, navegador y Desktop, con PDF en las tres plantillas.
El corte anterior HU026 conserva 55 peticiones/90 PASS de Postman Desktop,
18/18 casos de navegador y su comprobación específica de APK/Android emulado.
La guía distingue corridas, capturas y renders, con versiones, fuentes y límites.
La revisión final HU028 fue del agente principal, sin atribuir aprobación humana
ni revisión delegada. [Guion de exposición](../docs/ENTREGA.md) y
[plan de despliegue](../docs/DESPLIEGUE.md).

La aceptación incluye escritorio, móvil web emulado y recorridos específicos de
exportación/CV en Android emulado. No acredita todos los recorridos en un teléfono
físico, iOS, una prueba de carga ni un despliegue productivo. Los cortes anteriores
de planificación se conservan como antecedentes; Sprint y fechas no se cambiaron.

[Guía breve para revisar y explicar lo que funciona](docs/REVISION.md).

[Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues).
