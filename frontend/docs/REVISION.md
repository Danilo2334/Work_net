# Guía para revisar WorkNet

Actualización de HU011: 25/10/2026. Backend de PDF probado: `84746c3`; Flutter de HU011 en el PR #146.
La demostración anterior de acceso, perfiles y empresas usaba Flutter `04e7e5c` y backend `f9e4dea`; se conserva abajo con sus cuentas y puertos propios.
Esta guía permite iniciar la demostración y recorrer las funciones disponibles. El PR #146 sigue en borrador.

[Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues).

Los resultados y capturas se registran en el comentario existente de cada tarea. Las pruebas de interfaz usan la app Flutter y las del backend, Postman. [Instrucciones para preparar y repetir los casos en Postman](../../backend/postman/README.md).

## Revisar HU011: subir, reemplazar y ver el PDF

Utilizar el backend de `feature/backend-sprint-3` con las dependencias de esa rama. El backend de la demostración anterior no contiene necesariamente estos endpoints.

Desde la raíz del checkout del backend: `python backend/postman/qa.py prepare --port 8015` y después `python backend/postman/qa.py serve --run RUN_NUEVO`. Si el puerto está ocupado, usar otro libre y ajustar también `API_BASE_URL`. Desde el directorio `frontend` de la rama Flutter: `flutter run -d chrome --web-port 55014 --dart-define=API_BASE_URL=http://127.0.0.1:8015/api/`.

El entorno privado está en `backend/postman/.local/RUN_NUEVO/local.postman_environment.json`: consultar allí `qa_password`. Las cuentas `candidate.postman@worknet.test` y `other.postman@worknet.test` ya están verificadas y empiezan sin PDF. Este entorno captura los correos en archivos; el registro de una cuenta nueva no envía mensajes a Gmail.

1. Iniciar sesión y abrir **Mi currículum** desde el dashboard. Debe mostrar el estado vacío y los límites recibidos de Django.
2. Abrir el selector y cancelar: debe permitir seguir usando la pantalla. Subir `backend/postman/fixtures/curriculum-valido.pdf`: esperar la confirmación y comprobar nombre y tamaño. Abrir **Ver currículum** y leer su contenido; el visor admite ampliación y cambio de página.
3. Reemplazar por `curriculum-reemplazo.pdf`. Cancelar otro reemplazo: deben conservarse nombre y contenido. Probar `curriculum-corrupto.pdf` y `.local/fixtures/exceso-cv.pdf`: muestran error y conservan el documento guardado.
4. Volver al dashboard, regresar y recargar con **Recordar sesión**: la app vuelve a consultar los datos persistidos. Comprobar error y reintento interrumpiendo temporalmente la conexión de esa pestaña en las herramientas de Chrome.
5. Cerrar sesión e iniciar con el segundo candidato: no debe aparecer el documento del primero. Para repetir desde vacío, crear otra base con `qa.py prepare`; no borrar ni sustituir la base de una ejecución anterior.

El 24/10/2026 pasaron 91 pruebas Flutter (14 nuevas), análisis y compilación web JavaScript. La compilación avisó sobre compatibilidad Wasm de `flutter_secure_storage_web` y una fuente Cupertino. Los recorridos de la app se comprobaron contra Django en escritorio y móvil web. El 25/10/2026 el usuario confirmó la cancelación sin CV; después se comprobaron ambos casos con automatización de escritorio sobre el botón **Cancelar del diálogo real de Windows**, sin cargas durante la cancelación y con el PDF anterior conservado. Esa ejecución del agente no constituye una revisión humana del código. No se ejecutaron binarios nativos de Windows, Android o iOS.

Los 5 MiB, 50 páginas y las restricciones de documentos cifrados o interactivos son políticas actuales del backend. El editor de plantillas corresponde a HU012 y seleccionar el CV en una postulación depende de HU018.

## Abrir la demostración anterior de acceso, perfiles y empresas

Desde la raíz, con las dependencias Django instaladas:

```powershell
python frontend/tool/qa_backend.py --port 8006 --frontend-origin http://localhost:55006
```

En otra terminal, desde `frontend`:

```powershell
flutter pub get
flutter run -d chrome --web-port 55006 --dart-define=API_BASE_URL=http://127.0.0.1:8006/api/
```

Si esos puertos ya tienen la demostración de esta sesión, abrir `http://localhost:55006`.
No iniciar un segundo servidor en el mismo puerto. Cada nueva ejecución del backend de QA crea otra SQLite y cuentas ficticias. Las contraseñas aleatorias se consultan **solo localmente** en `frontend/.dart_tool/worknet_qa/latest.json`; no publicar ese archivo. Las cuentas no existen en la base habitual.

| Cuenta de QA | Recorrido |
| --- | --- |
| `candidato.qa@worknet.test` | Dashboard con actividad, perfil y configuración |
| `perfil.qa@worknet.test` | Perfil inicialmente vacío |
| `empresa.qa@worknet.test` | Empresa aprobada, dos ofertas y dos postulaciones controladas |
| `nueva.empresa.qa@worknet.test` | Completar información y solicitar validación |
| `admin.qa@worknet.test` | Revisar solicitudes, aprobar o rechazar con motivo |
| `eliminar.qa@worknet.test` | Cuenta desechable para probar eliminación |

## Recorridos para explicar

1. **Registro:** completar los datos. Primero se crea la cuenta; después aparece Candidato/Empresa. Contraseñas distintas impiden enviar y un correo existente muestra el error en español. En QA el mensaje de verificación queda en archivos privados, no se envía a Gmail.
2. **Acceso del candidato:** iniciar sesión, editar el perfil y volver al dashboard. La completitud viene de Django. Probar Recordar sesión y recargar; cerrar sesión revoca el token en el servidor cuando la respuesta se confirma.
3. **Recuperación:** solicitar el correo, abrir el enlace del mensaje capturado en el buzón de archivos de QA y cambiar la contraseña. La anterior se rechaza y el enlace usado no puede volver a cambiarla. No compartir ni capturar el enlace firmado.
4. **Configuración:** cambiar el nombre y preferencias, volver a consultar, cambiar contraseña y comprobar nueva sesión. Probar eliminación solo con la cuenta desechable y confirmación expresa.
5. **Empresa:** completar razón social, NIT, sector, ubicación, contacto y descripción; enviar solicitud. En Pendiente los datos enviados quedan bloqueados hasta la decisión.
6. **Administrador:** abrir Revisar empresas. Rechazar exige motivo. La empresa puede corregir y reenviar; aprobar permite su dashboard. Los avisos y decisiones se guardan en Django. El logo, sitio web y redes son complementos opcionales después de la aprobación.
7. Repetir las pantallas principales en un viewport móvil web; comprobar desplazamiento y mensajes. Esto no sustituye probar Android/iOS.

## Correo real: comprobación separada

El servidor `qa_backend.py` **siempre captura correo a archivos**. Para SMTP se necesita otro proceso Django con configuración local real y una base de prueba separada; no convertir una prueba de archivos en evidencia de entrega.

En `backend/.env`, ignorado por Git, configurar `GMAIL_USER` (remitente), `GMAIL_APP_PASSWORD` (contraseña de aplicación generada por Google, no contraseña normal) y `PASSWORD_RESET_FRONTEND_URL=http://localhost:55000/reset-password` para Flutter en 55000. No compartir esas credenciales. La URL debe coincidir con el origen de la aplicación usada en esa comprobación.

La configuración privada quedó completada. En la SQLite SMTP separada (Django 8007, Flutter 55007) el enlace de registro recibido y aportado por el usuario devolvió 200, guardó la verificación y permitió login/dashboard desde Flutter. La recuperación también se completó usando el enlace recibido aportado por el usuario: cambio persistido, login/dashboard con la nueva contraseña y rechazo de anterior, sesión previa y enlace usado. [Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues). Una respuesta SMTP aceptada no demuestra recepción. Las evidencias públicas deben ocultar tokens y enlaces firmados.

## Pendientes que deben decirse claramente

- Falta acceso `read:project` para confirmar qué issues pertenecen realmente al Sprint 2. La rama no define ese alcance; no se modificaron Sprint ni fechas.
- Registro y recuperación mediante correo real comprobados con los enlaces recibidos. Falta la revisión del código por otro integrante.
- Dashboard candidato: el PDF subido está disponible mediante el backend de HU011 indicado arriba. El editor de CV de HU012, búsqueda, mensajes, historial y detalle/postulación continúan pendientes en Flutter.
- Dashboard empresa: crear/gestionar ofertas, gestionar postulantes, mensajes y estadísticas siguen pendientes. Las métricas y postulaciones recientes sí usan datos reales.
- Administración: gestión de administradores y permisos pendiente. Revisión de empresas, métricas y eventos de validación sí están implementados.
- Perfil candidato: falta consulta positiva por empresas con autorización dentro de selección. Hoy se conserva el acceso restringido; un HTTP 403 no cumple ese criterio positivo.
- Revisión por otro integrante y pruebas en Android/iOS pendientes.

[Tareas y evidencias en GitHub](https://github.com/Danilo2334/Work_net/issues). [Contratos empresariales](../../backend/accounts/COMPANY_API.md). [PR #146](https://github.com/Danilo2334/Work_net/pull/146).

## Revisión cruzada de Danilo y Francisco

La demostración se renovó el 19/10/2026 en otra SQLite. La base anterior se conserva; la cuenta SMTP y sus evidencias están en otra instancia y no se reiniciaron. Las cuentas de la tabla anterior están disponibles en `http://localhost:55006`. Las siete usan la contraseña aleatoria del `latest.json` privado de QA, sin publicarla ni incluirla en capturas.

| Quién revisa | Trabajo que contrasta | Referencias |
| --- | --- | --- |
| Danilo | Pantallas, textos, navegación, integración y diseño de Francisco | #29/#32, #34/#36/#37, #39/#41, #43/#46, #47/#49, #51/#53, #55/#57, #59/#61, #63/#65, #67/#69 |
| Francisco | Contratos, persistencia, permisos y estados del backend de Danilo | #30/#31/#35/#40/#44/#45/#48/#52/#56/#60/#64/#68 |
| Francisco, como otro integrante | Contrastar los resultados de QA de Danilo y registrar observaciones | #33/#38/#42/#46/#50/#54/#58/#62/#66/#70 |

Orden sugerido para conservar cuentas útiles:

1. Abrir dos sesiones de navegador separadas para alternar empresa/administrador. Revisar primero los datos iniciales: candidato con 83%, dos postulaciones, un guardado y dos notificaciones; empresa aprobada con dos ofertas activas, cero cerradas y dos postulaciones; administrador con cuatro candidatos, dos empresas y cero solicitudes completas pendientes. Esos valores cambian legítimamente al crear o editar datos en esta base.
2. Usar `perfil.qa@worknet.test` para crear, modificar y borrar registros/foto; volver al dashboard y comprobar la completitud. Probar archivo inválido y permiso de otra cuenta. No marcar cumplida la consulta empresarial autorizada: todavía no existe.
3. Con `nueva.empresa.qa@worknet.test`, completar seis datos, solicitar validación y comprobar espera. Con `admin.qa@worknet.test`, rechazar con motivo. Volver a empresa, corregir/reenviar; aprobar desde administrador y comprobar dashboard/avisos/logo. Intentar decidir como empresa debe ser rechazado. La aprobación no implementa las funciones futuras de ofertas/postulantes/mensajes/estadísticas.
4. Probar registro con un correo nuevo `@worknet.test` y una contraseña solo de prueba. Revisar que la cuenta se cree antes del rol. Abrir localmente el mensaje en la carpeta `mail` indicada por el archivo privado de QA; verificar, iniciar sesión y recuperar la contraseña de **esa cuenta nueva**. Estos mensajes de demostración van a archivos; el SMTP real ya tiene su informe separado.
5. Dejar para el final `eliminar.qa@worknet.test`: nombre, preferencias, cambio de contraseña/token y eliminación cancelada/confirmada. No usar la cuenta candidata principal para eliminarla o cambiar su contraseña antes de terminar el resto de la demostración.
6. Repetir las pantallas principales en móvil web. Android/iOS quedan pendientes de sus comprobaciones propias. Revisar los criterios de módulos faltantes como pendientes, aunque aparezcan sus avisos.

Después de probar la app o los servicios en Postman, cada integrante actualiza el comentario existente de la tarea con una explicación breve del resultado, las capturas necesarias y cualquier fallo encontrado.

Para HU004, Danilo revisa #43/#46 y Francisco #44/#45. En #46 hay un comentario que identifica la integración de Francisco y el QA de Danilo. Los cierres se decidirán después de revisar los criterios; el alcance del Sprint sigue pendiente de confirmación en el Project.
