# WorkNet · Frontend Flutter

Reconstrucción del registro HU001 y del recorrido de acceso del candidato:
login, recuperación, dashboard, configuración de cuenta y perfil profesional conectados a Django. Se conservan el formulario,
los componentes y la paleta del bloque de registro publicado en `acb48b5`.

## Alcance

- Nombre completo, correo, contraseña y confirmación con validaciones visibles.
- Primero se completan los datos del formulario y luego se elige Candidato o Empresa.
- Se envían juntos en `POST /api/register/`, como requiere la API existente.
- El correo duplicado y las validaciones de Django se muestran al usuario.
- El envío en curso bloquea acciones que puedan repetir la petición.
- El éxito solo se anuncia al recibir HTTP 201 y los datos esperados.
- La contraseña se conserva únicamente en memoria durante el formulario y se limpia al terminar.
- Diseño adaptable a móvil y escritorio con la paleta verde de los mockups.

Este bloque no declara terminadas todas las historias. La navegación de login
al dashboard del candidato está implementada. Los estados y destinos de empresa
y administrador y el formulario de información/validación de empresa siguen pendientes.
El correo de verificación lo envía Django; al abrir su enlace se utiliza el
endpoint de verificación que ya existe. Esta entrega no agrega reenvío de correo.

## Acceso, recuperación y dashboard

- `/login`: correo, contraseña, errores, Recordar sesión, registro y recuperación.
- `/register`: registro existente con acceso al inicio de sesión.
- `/forgot-password`: solicitud al endpoint `password-recovery/request/`.
- `/reset-password?uid=…&token=…`: confirmación al endpoint `password-recovery/confirm/`.
- `/password-updated`: confirmación del cambio sin conservar el enlace en la URL.
- `/dashboard`: candidato autenticado; consume `dashboard/candidate/` con `Authorization: Token`.
- `/account`: configuración autenticada, accesible desde el icono del dashboard;
  consulta cuenta, guarda nombre/preferencias, cambia contraseña y elimina con confirmación explícita.
- `/profile`: candidato autenticado; descripción, educación, experiencia,
  habilidades, idiomas y fotografía opcional, con CRUD conectado a Django.
- `/access-pending`: aviso explícito para empresa o administrador, sin inventar estados empresariales.

Recordar sesión guarda la credencial mediante `flutter_secure_storage`, sin
guardar contraseñas. Sin esa opción, el acceso solo permanece en memoria y se
pierde al recargar o cerrar la aplicación. Cerrar sesión elimina la credencial
local. Un HTTP 401 también limpia la sesión y pide autenticarse de nuevo.
La API actual no ofrece logout remoto: el cierre local no revoca el token del
servidor; la recuperación y el cambio de contraseña sí invalidan el token anterior en Django.
Cambiar la contraseña en configuración sustituye el token y conserva la elección
de Recordar sesión. Guardar el nombre actualiza también la sesión. El correo, rol
y verificación son de solo lectura. La eliminación pide contraseña y confirmación,
y limpia la sesión después del éxito. La preferencia push se guarda en Django;
esta entrega no acredita envío de notificaciones al dispositivo.

Los enlaces web usan rutas de navegador. El hosting deberá redirigir esas
rutas a `index.html`. Configurar `PASSWORD_RESET_FRONTEND_URL` con el origen
y `/reset-password` para que el correo abra la pantalla correcta.

El dashboard presenta exclusivamente los datos recibidos de la API: completitud,
postulaciones, guardados, notificaciones y trabajos recientes. El acceso al perfil
ya funciona y al volver se actualiza la completitud desde Django. CV,
búsqueda, mensajes, historial y detalle/postulación de ofertas se identifican
como módulos pendientes, sin botones que aparenten navegar a pantallas inexistentes.

## Ejecutar en Chrome

En otra terminal, desde `backend`, activar el entorno virtual y ejecutar:

```powershell
python manage.py runserver
```

Si se van a crear cuentas reales, el correo SMTP debe estar configurado en el
archivo local `backend/.env`, según el README del repositorio. Esta entrega no
modifica esa configuración.

Desde `frontend`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 55000 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

Se incluye la plataforma Android para continuar posteriormente. La prueba
inicial indicada arriba es web, contra el servidor local de Django. Los
permisos de Internet quedan habilitados; el HTTP sin cifrar se permite solo en
los manifiestos de desarrollo de Android. Para publicar se debe usar una API HTTPS.

## Comprobación funcional breve

1. Continuar con campos vacíos: errores visibles y ninguna petición de registro.
2. Contraseñas diferentes: no permite pasar a la selección de rol.
3. Datos válidos: solo aparecen Candidato y Empresa. Volver conserva los datos.
4. Correo ya registrado: Django lo rechaza y el error aparece junto al correo.
5. Crear un candidato y una empresa con correos nuevos: respuesta 201, rol
   correcto y pantalla de revisar correo. Abrir el enlace recibido verifica
   la dirección en Django. Después se puede iniciar sesión para abrir el dashboard del candidato.

6. Probar credenciales incorrectas, Recordar sesión, recarga, cierre y token revocado.
7. Recuperar la contraseña con un enlace válido; rechazar contraseñas distintas,
   enlaces vencidos y reutilizados; comprobar que solo la nueva contraseña permite entrar.
8. Actualizar el dashboard y comprobar carga, error/reintento y ausencia de ofertas publicadas.

## Verificación de esta entrega

La reconstrucción se validó en Windows con el SDK instalado en el equipo del
proyecto. `flutter analyze` terminó sin incidencias y las **67 pruebas Flutter**
aprobaron. Incluyen registro, sesión, recuperación, permisos, navegación directa,
dashboard, configuración, perfil, fotografía y tamaños de pantalla; HU008 añadió 13 pruebas a las 54 previas.
Las **87 pruebas del backend** también aprobaron, incluidas las 70 de la base anterior.

La corrección de correo duplicado del backend está separada en el commit
`763fceb`, de Danilo2334, en `feature/backend-sprint-2` y, tras fast-forward,
en `develop`. Las 70 pruebas de
`accounts` y `candidate_dashboard` aprobaron, incluida la regresión del mensaje
en español con correos repetidos, mayúsculas y espacios.

La comprobación visual conectó Flutter en `http://localhost:55000` con Django
en `http://127.0.0.1:8001/api/`, porque el puerto 8000 estaba ocupado. Se
verificaron el registro HTTP 201, el duplicado HTTP 400 y la presentación de
escritorio. Se usó una copia aislada de SQLite y captura local del correo;
esto no comprueba entrega real a Gmail ni verificación desde el correo recibido.

Las [capturas y límites de la validación](docs/evidencias/hu001/README.md)
corresponden a la reconstrucción y complementan las tareas #29, #32 y #33.
La revisión adicional de la API verificó localmente el enlace, el cambio de
`email_verified` y el login posterior: 13 comprobaciones aprobadas con correo
en memoria y base temporal. El informe no contiene enlaces firmados ni tokens.
SMTP real quedó bloqueado por ausencia de `backend/.env`, `GMAIL_USER`,
`GMAIL_APP_PASSWORD` y sesión del buzón. No se modificó la lógica de envío.

## QA aislada y evidencias nuevas

Desde la raíz, con las dependencias Python instaladas:

```powershell
python frontend/tool/qa_backend.py
```

Este comando crea otra SQLite, cuentas verificadas y ofertas identificadas como QA,
y captura los correos en archivos. Se ejecuta en `127.0.0.1:8002`; no usa la base
habitual ni envía SMTP. Las credenciales generadas, los correos y la SQLite quedan
solo en `frontend/.dart_tool/worknet_qa/`, ignorado por Git. No publicar su contenido.

En otra terminal desde `frontend`:

```powershell
flutter run -d chrome --web-port 55001 --dart-define=API_BASE_URL=http://127.0.0.1:8002/api/
```

Se revisaron escritorio 1440×1280 y móvil 390×844, con **19 comprobaciones de
navegador aprobadas** contra Django y datos de QA. La recuperación usó mensajes
capturados localmente; la entrega SMTP real sigue bloqueada y no se acredita
recepción en Gmail. No se publican contraseñas ni tokens en las evidencias.

- [HU002 — login, sesión e integración](docs/evidencias/hu002/README.md): #34, #36 y #38.
- [HU003 — recuperación](docs/evidencias/hu003/README.md): #39, #41 y #42.
- [HU004 — configuración e integración/QA](docs/evidencias/hu004/README.md): #43 y #46;
  28 comprobaciones nuevas contra Django y 12 capturas de escritorio/móvil, con
  eliminación solo de una cuenta desechable en otra SQLite (puertos 8003/55002).
- [HU005 — dashboard](docs/evidencias/hu005/README.md): #47, #49 y #50.
- [HU008 — perfil profesional y fotografía](docs/evidencias/hu008/README.md): #59–#62;
  47 comprobaciones nuevas, 14 capturas y una imagen sintética QA. Backend consolidado
  en develop antes de incorporarlo a frontend. Requiere instalar Pillow y aplicar
  `python manage.py migrate` en los entornos actualizados; para QA aislada, puertos 8004/55003.
- [Informe del navegador](docs/evidencias/acceso-candidato/resultados-qa.json).

Las versiones de navegación y almacenamiento están fijadas al conjunto validado.
Los overrides de `path_provider` evitan hooks nativos incompatibles con las rutas
con espacios de este SDK en Windows; deben revisarse al actualizar el SDK.
La validación manual es web; Android y otras plataformas nativas no se declaran probadas.
En producción, la persistencia web necesita HTTPS y las condiciones indicadas por
la [documentación de flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage/versions/9.2.4).

SMTP real, estados y destinos empresariales/administrativos, módulos de los accesos
del dashboard y revisión del orden registro/rol siguen pendientes. **HU001, HU002,
HU003, HU005 y HU008 no se declaran completas.** HU008 mantiene restringido el acceso
de empresa hasta implementar autorización en selección. El PR #146 permanece en borrador.
