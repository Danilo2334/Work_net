# WorkNet · Flutter conectado a Django

## Alcance vigente — HU001–HU026

Por decisión del usuario del **08/11/2026**, HU027 — Integración con LinkedIn está **cancelada y fuera de alcance**. #28 y #137–#141 están cerradas como `not_planned` y con estado **Cancelada** en WORK_NET; no son historias implementadas ni aceptadas. No se necesita crear una aplicación ni proporcionar credenciales. WorkNet mantiene el perfil y CV manuales.

La preparación estática de #196/#197 se conserva como antecedente, sin anunciar conexión disponible. La entrega final requiere completar y comprobar HU001–HU026, incluidas estadísticas, exportaciones y doble factor administrativo. Los avances se registran en la guía existente.

<details>
<summary>Preparación histórica de LinkedIn, cancelada; no ejecutar estos pasos</summary>

Esta propuesta anterior nunca se implementó ni tuvo aceptación OAuth real. Se conserva para trazabilidad. Sus instrucciones y variables no forman parte de la configuración vigente.

## Preparar una aplicación de LinkedIn — HU027

La conexión es opcional. Esta preparación de la aplicación externa no acredita
todavía una aceptación OAuth real ni el cierre de HU027. No solicita un CV completo
ni cambia la identidad o el correo verificado de WorkNet.

1. Abre [LinkedIn Developer](https://www.linkedin.com/developers/apps) e inicia
   sesión personalmente. Elige **Create app**. Nombre: **WorkNet**. Descripción:
   «Bolsa de empleo para gestionar perfiles, currículums, ofertas, postulaciones
   y comunicación autorizada entre candidatos y empresas».
2. Selecciona una LinkedIn Page que represente realmente al proyecto y que puedas
   administrar. Si no existe, utiliza la opción de crear una página y completa
   sus datos reales. No asocies la aplicación a una organización ajena. Si el
   portal ofrece una página predeterminada para desarrolladores individuales,
   utiliza esa opción solo cuando corresponda al producto solicitado.
3. Sitio del proyecto: `https://danilo2334.github.io/Work_net/`.
   Política: `https://danilo2334.github.io/Work_net/privacy.html`.
   Logo: `docs/branding/worknet-logo.png`, PNG cuadrado de512×512; el SVG editable
   permanece junto a él. Estos recursos son preparación de marca, no evidencia QA.
4. Revisa los términos y crea la aplicación. Si LinkedIn solicita verificar su
   asociación con la Page, completa personalmente esa verificación como su
   administrador. No publiques enlaces privados de verificación.
5. En **Products**, solicita **Sign In with LinkedIn using OpenID Connect**.
   Espera a que figure aprobado/habilitado. En **Auth**, comprueba que estén
   disponibles `openid` y `profile`; WorkNet pedirá solamente esos permisos.
   No necesita `email`, publicaciones, contactos ni permisos de Marketing.
6. En **Auth → Authorized redirect URLs**, añade exactamente:
   `https://danilo2334.github.io/Work_net/linkedin/callback.html`.
   Respeta HTTPS, mayúsculas del nombre del repositorio, ruta y ausencia de barra
   final. La página de retorno quedará conectada al flujo de WorkNet al implementar
   HU027; registrar la URL ahora no equivale a haber ejecutado una autorización.
7. Copia Client ID y Client Secret únicamente a un archivo privado local
   `linkedin.env`, fuera del repositorio. Conserva estas claves:

   ```dotenv
   LINKEDIN_CLIENT_ID=
   LINKEDIN_CLIENT_SECRET=
   LINKEDIN_REDIRECT_URI=https://danilo2334.github.io/Work_net/linkedin/callback.html
   LINKEDIN_SCOPES=openid profile
   ```

   No lo adjuntes al chat ni a GitHub, no lo incluyas en capturas y no guardes las
   claves en el entorno público de Postman. El servidor recibirá la ruta del
   archivo mediante `WORKNET_LINKEDIN_ENV_FILE`; el secreto nunca se compila en
   Flutter. La carga de esa configuración forma parte de la implementación HU027.
8. Comunica únicamente «aplicación creada, producto habilitado y archivo privado
   guardado», junto al nombre del producto y los permisos que aparecen en Auth.
   La aceptación real se hará después, con consentimiento personal en LinkedIn;
   las pruebas simuladas se registrarán por separado.

Referencias: [crear aplicación](https://www.linkedin.com/help/lms/answer/a1672377),
[OIDC y permisos](https://learn.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2),
[flujo OAuth y URI de retorno](https://learn.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow).

</details>

El registro, acceso, recuperación, configuración, dashboard y perfil del candidato
están conectados a Django. La empresa completa su información, envía la solicitud,
consulta su estado y puede corregir un rechazo. El administrador revisa solicitudes
y aprueba o rechaza con motivo. Los dashboards usan métricas reales del backend.

La revisión humana sigue pendiente y el PR #146 permanece en borrador.
El Project WORK_NET se consultó con Francisco y `read:project`: HU005–HU010
y #47–#70 están en Sprint 2; HU011–HU017 y #71–#79, en Sprint 3.
Las tareas #80–#99 todavía no tienen Sprint asignado, aunque sus historias sí.

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
`registration`, `access`, `account`, `dashboard`, `profile`, `company` y `curriculum`.

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
y descarga del PDF guardado. La aceptación visual y de Postman Desktop de este
nuevo recorrido sigue pendiente; las pruebas automáticas no la sustituyen.

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
visual corresponde a escritorio y **móvil web**, no ejecución nativa.

## Pruebas y límites

Los resultados y las capturas de Flutter y Postman se conservan en el comentario único de cada tarea en GitHub. Las instrucciones de ejecución anteriores permiten iniciar la aplicación; las cuentas y datos de QA se describen en la guía de revisión.

La consulta de perfil por empresa autorizada ya tiene backend y evidencia
en `feature/backend-sprint-3`; falta su recorrido empresarial en Flutter.
Siguen pendientes búsqueda/mensajes/historial y
detalle/postulación, gestión empresarial de ofertas/postulantes/estadísticas y
gestión de administradores/permisos. Los accesos inexistentes se identifican
claramente, sin aparentar que sus módulos están implementados. Falta revisión
humana y validación nativa; no se declara terminado el Sprint.

[Guía breve para revisar y explicar lo que funciona](docs/REVISION.md).

[Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues).
