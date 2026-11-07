# Guía para revisar WorkNet

> **Estado vigente:** consultar «Aceptación visual y revisiones preparadas — 07/11/2026» al final. Los apartados fechados anteriores conservan su evidencia histórica; sus bloqueos visuales describen esas ejecuciones. Publicado e implementado no significa integrado ni revisado por otro integrante.

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

## Revisar HU012: crear y editar un CV

La interfaz usa los endpoints existentes de `feature/backend-sprint-3`; el backend
que todavía acompaña a la rama `frontend` no contiene esas APIs. Conservar los
servicios y las bases de las demostraciones anteriores. Para una corrida nueva,
usar `qa.py prepare --port 8019` desde un checkout con ese backend y
`qa.py serve --run RUN_NUEVO`; desde Flutter ejecutar
`flutter run -d chrome --web-port 55019 --dart-define=API_BASE_URL=http://127.0.0.1:8019/api/`.
Consultar `qa_password` solamente en el entorno privado de esa corrida.

1. Entrar como `candidate.postman@worknet.test`, abrir Mi currículum → Crear mi CV.
   Contrastar nombre, correo, resumen y secciones precargadas con el perfil de
   esa misma cuenta. La consulta inicial no guarda un CV.
2. Editar información personal, educación, experiencia, habilidades e idiomas;
   agregar certificación y otra sección. Cambiar entre Clásica, Moderna y
   Minimalista: los datos deben conservarse. Abrir Vista previa: muestra el PDF
   del borrador sin guardarlo.
3. Guardar, volver a consultar y regresar al editor. Descargar PDF guardado;
   comprobar su texto. La descarga requiere guardar la última edición y no debe
   confundirse con la vista previa. La edición del CV no modifica el perfil ni
   la cuenta de origen.
4. Probar campos obligatorios, fechas invertidas y un fallo de red. Conservar el
   borrador y permitir reintento. Salir con cambios pide confirmación. Expirar la
   sesión o cambiar de cuenta debe retirar datos y PDF privados.
5. Contrastar el recorrido en escritorio y móvil web. Ejecutar los 27 casos de
   fase 14 en Postman Desktop con su preparación completa de la guía backend;
   las pruebas automáticas de Flutter no sustituyen esa ejecución.

Resultados automáticos nuevos y límites se registran en #75/#78.
El 06/11/2026 Francisco confirmó manualmente en la corrida aislada de integración:
login, datos ficticios del CV, edición y guardado del perfil profesional, cambio
de plantilla sin pérdida de datos y frase editada visible en el PDF de vista
previa. Una consulta posterior de la SQLite confirmó el resumen modificado y la
plantilla guardada. Francisco confirmó después que guardó, descargó y abrió el
archivo: contiene la frase editada y la plantilla elegida. La lectura local del
PDF descargado confirmó un documento válido de una página y el resumen guardado.
El resto de aceptación visual y sus capturas siguen pendientes. Desktop HU012 ya pasó 31 solicitudes/87 aserciones el 06/11/2026; evidencia en backend 3959d08. La revisión del código frontend por
Danilo y del backend por Francisco se registran por separado de ese recorrido.
HU008 #62 conserva el seguimiento de la reutilización efectiva del perfil.
Seleccionar el CV al postular depende de HU018; HU011/HU012 permanecen abiertas.

En la preparación original 8015/55008, corrida
`run-20261106T031216-109fd1a7`, Francisco confirmó manualmente login y dashboard:
83 % de completitud, dos postulaciones, un guardado y dos notificaciones. Este
control mínimo no repite la batería histórica. Postman Desktop abrió su workspace
y colecciones, pero mostró «Editor failed to load»; no se ejecutaron colecciones
durante esa comprobación. Francisco no completó Retry. En la preparación
automatizada posterior, el agente pudo controlar la interfaz principal e importar
la colección pública HU012; esto no acredita solicitudes ejecutadas. La importación
del entorno privado se completó y la ejecución Desktop HU012 pasó 87 aserciones. Chrome permanece bloqueado por verificación de URL; no se acredita el resto del recorrido visual.

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

- Project consultado: HU005–HU010 y #47–#70 en Sprint 2; HU011–HU017 y #71–#79 en Sprint 3. #80–#83 ya están en Sprint 3 según la consulta del 07/11/2026; #84–#99 conservan su planificación sin modificarla en este bloque. No se cambiaron esas asignaciones.
- Registro y recuperación mediante correo real comprobados con los enlaces recibidos. Falta la revisión del código por otro integrante.
- Dashboard candidato: PDF subido y editor de HU012 disponibles con el backend indicado. La aceptación visual restante del editor quedó comprobada en el bloque de abajo; su revisión humana y la selección en postulación HU018 siguen pendientes. Postman Desktop pasó el 06/11/2026 (31 solicitudes/87 aserciones); búsqueda, mensajes, historial y detalle/postulación continúan pendientes.
- Dashboard empresa: **crear/publicar ofertas HU013 ya está implementado y publicado en #148/#149**. Su aceptación visual de escritorio/móvil web quedó completada en el bloque de abajo; quedan revisión humana e integración a las ramas destino. Gestionar ofertas HU014/HU015, postulantes HU020, mensajes HU022 y estadísticas HU024 siguen pendientes y no se iniciaron aquí. Las métricas y postulaciones recientes sí usan datos reales.
- Administración: gestión de administradores y permisos pendiente. Revisión de empresas, métricas y eventos de validación sí están implementados.
- Perfil candidato: la consulta empresarial positiva y sus restricciones ya tienen API y evidencia en #60/#62; falta revisión cruzada y el recorrido empresarial Flutter. La reutilización efectiva para CV se contrasta con HU012.
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

Para HU004, Danilo revisa #43/#46 y Francisco #44/#45. En #46 hay un comentario que identifica la integración de Francisco y el QA de Danilo. Los cierres se decidirán después de revisar los criterios; el alcance del Sprint fue contrastado en WORK_NET el 07/11/2026 sin cambiar sus asignaciones.

## Revisar HU013: publicar una oferta

Con el backend HU013 y su migración, preparar una base nueva en 8021
según la guía de Postman. Configurar Flutter con
`--dart-define=API_BASE_URL=http://127.0.0.1:8021/api/`. Entrar como
empresa aprobada del entorno privado; Dashboard de empresa → Publicar oferta.
Completar título, descripción, requisitos, salario, ubicación, categoría
y contrato. Catálogos se consultan a Django, no se duplican en Flutter.
Campos vacíos/salario inválido impiden enviar. Publicar muestra confirmación
e identificador y bloquea un segundo envío desde esa pantalla. Volver
al dashboard consulta las métricas actualizadas.

Ante un fallo de red, conservar los campos y permitir reintento; un 401
expira la sesión. Empresa sin aprobación no publica aunque llegue por URL
directa: el backend valida permisos en cada solicitud. No se implementa
gestión/edición HU014 en este bloque.

06/11/2026: 110 pruebas Flutter aprobadas (5 nuevas), análisis limpio.
`dart run tool/hu013_api_smoke.dart RUTA_ENTORNO_PRIVADO` hizo 7
comprobaciones HTTP con el adaptador real contra Django 8021; agrega una
oferta ficticia por ejecución y verifica denegaciones sin escritura.
No es navegador real ni Postman. Desktop HU013 pasó por separado
10 solicitudes/21 aserciones. Aceptación visual real, capturas de la
interfaz y revisiones humanas continúan pendientes.


## Retoma de Danilo: aceptación hasta HU013 — 07/11/2026

Esta sección actualiza la guía y las auditorías de las issues existentes; no reemplaza sus resultados históricos. El nuevo QA de aceptación, Postman y evidencias corresponde a Francisco (`francisco3788`); Django/modelos/APIs/migraciones/servicios, a Danilo (`Danilo2334`). Las pruebas que acompañan una implementación mantienen el responsable del código. El QA histórico de Danilo, incluidas #66/#70, no se reasigna retroactivamente.

### Estado local y remoto contrastado

Los PR #146–#149 siguen abiertos y en borrador, sin revisiones humanas registradas. Sus bases publicadas son frontend `91207ad`, backend Sprint 3 `3959d08`, HU013 backend `2f1b2f7` y HU013 Flutter `5cfb9a2`. Los checkouts anteriores permanecen intactos: frontend local `0ee9603`, backend local `47d5f1e`, HU008 `d18bbbd` y backend Sprint 2 `5d3b10a`. Antes de trabajar no había commits sin publicar; se conservó el entorno no rastreado `.venv-hu008-qa/`.

Se creó otro worktree para combinar las dos ramas HU013, sin actualizar ni sustituir bases privadas. El único conflicto fue README; se conservaron los contratos de las APIs nuevas, la documentación SMTP y el seguimiento previo. **La combinación es local de aceptación; no fusiona los PR ni incorpora todavía las APIs a la rama de entrega `main`.**

### Comprobaciones nuevas y preparación reproducible

[Resultados sin secretos](evidencias/retoma-20261107/resultados.json) y [Newman HU013](evidencias/retoma-20261107/hu013-newman.json).

- 141 pruebas Django y 110 pruebas Flutter de unidad/widgets aprobadas. Análisis limpio después de añadir las llaves que faltaban en el comprobador HTTP de HU013. Compilación web JavaScript release correcta; conserva los avisos conocidos de Wasm y fuente Cupertino. No acredita binarios nativos ni salida Wasm.
- Consistencia de migraciones: `makemigrations --check --dry-run` sin cambios. Las bases nuevas de QA se migraron desde cero con las APIs de ambas ramas.
- HU013: 7 comprobaciones del adaptador Dart contra Django real. La colección existente pasó además 10 solicitudes/21 aserciones mediante **Newman 6.2.3**, no Postman Desktop.
- HU008/HU012: 18 comprobaciones del adaptador Dart real: precarga del perfil, cuatro secciones sin IDs privados, tres plantillas, persistencia y conservación de perfil/cuenta; otro candidato no recibe el documento. Los tres PDF guardados contienen el resumen, educación, experiencia y habilidad del perfil ficticio. Se comprobaron mediante pypdf; no es una descarga manual nueva.
- El primer borrador del comprobador de CV comparaba de forma demasiado estricta fechas omitidas y `null`. Se contrastó esa normalización en las SQLite aisladas y se corrigió el comprobador, sin cambiar el producto. Las 18 comprobaciones aprobadas corresponden a otra base nueva.

Para repetir, reunir en un worktree aislado el frontend HU013 y el backend HU013 de los PR apilados. Crear un venv nuevo e instalar `backend/requirements.txt`; no reutilizar a ciegas el Python global. Ejecutar las suites anteriores y `flutter analyze`. La preparación `qa.py prepare --port PUERTO_LIBRE` siempre crea otra base y otro entorno privado; servir con `qa.py serve --run RUN_NUEVO`.

Para el comprobador existente de HU013, el puerto permitido es 8021; respetar su guard y ejecutar `dart run tool/hu013_api_smoke.dart ENTORNO_PRIVADO_NUEVO`. El comprobador `tool/hu012_api_smoke.dart` valida localhost, puerto, marcador QA, ruta de base y run-*; exige empezar sin CV generado y guarda los PDF ficticios exclusivamente junto al entorno privado. Usar **otra corrida** para repetirlo: `dart run tool/hu012_api_smoke.dart ENTORNO_PRIVADO_NUEVO`. No imprimir ni publicar las credenciales de esos entornos.

**Límite comprobado de escritorio:** Computer Use devolvió `Computer Use native pipe is unavailable: failed to connect native pipe (os error 2)`. No se controló Chrome ni Postman Desktop y no se eludió el bloqueo anterior de verificación de URL. HU012 conserva móvil web, validaciones, errores, red y sesión visuales pendientes; HU013 conserva su aceptación visual real pendiente. Los widgets y HTTP anteriores no sustituyen esos recorridos. Se mantienen las capturas históricas explicadas en el comentario único de cada tarea; no se fabricaron capturas nuevas.

### Seguimiento por historia y subtarea

| Historia | Subtareas y alcance actual | Pendiente que impide el cierre |
|---|---|---|
| HU001–HU004 | #29–#46 conservan cierre; regresión Django/Flutter aprobada | No se demostró una incidencia que justifique reabrir |
| HU005 | #48/#49 cerradas. #47/#50 ya incluyen acceso al CV; métricas y perfil conservan evidencias | Búsqueda HU016, historial HU019, mensajes HU022 y revisiones aplicables |
| HU006 | #52 cerrada. #51/#53/#54 tienen métricas y acceso de publicación HU013 en el código apilado | Aceptación visual de publicación; gestión de ofertas HU014/HU015, postulantes HU020, mensajes HU022 y estadísticas HU024 |
| HU007 | #56/#57 cerradas. #55/#58 cubren métricas, solicitudes y eventos | Acceso a gestión de administradores/permisos HU026 y revisión aplicable |
| HU008 | #59/#61 cerradas. #60 implementa lectura empresarial autorizada; #62 añade prueba técnica de perfil→CV→PDF | Revisión humana del backend y contraste de aceptación pendiente; no se exige crear en este bloque una pantalla HU020 |
| HU009 | #63–#66 cerradas; criterios propios contrastados con código, evidencia histórica y pruebas de validación, NIT, estados y complementos | Historia #10 cerrada y Project Done verificados el 07/11; no se dedujo el cierre solo del número de subtareas |
| HU010 | #67–#70 y la historia conservan cierre; se completan responsables históricos | Sin incidencia nueva demostrada; #66/#70 conservan QA de Danilo |
| HU011 | #71/#73 implementación e integración probadas; #72 almacenamiento y permisos; #74 QA histórico completo conservado | Revisiones humanas; seleccionar el CV al postular pertenece a HU018. Historia abierta |
| HU012 | #76/#77 modelos/PDF probados. #75/#78/#79 tienen editor y Desktop histórico, más apoyo HTTP nuevo | Aceptación visual restante y revisiones humanas; selección durante postulación HU018. Historia abierta |
| HU013 | #81 API probada. #80/#82/#83 formulario, contrato y QA automatizados publicados | Recorrido visual real y revisiones humanas. Historia abierta |

Las asignaciones QA abiertas #50/#54/#58/#62/#74/#79/#83 pasan a Francisco por la instrucción del 07/11/2026. #63/#65/#67/#69 quedan históricamente en Francisco; #66/#68/#70, en Danilo, conforme a comentarios y commits. Ambas historias empresariales quedan asignadas a los dos responsables por su alcance.

WORK_NET permitió lectura y escritura como Danilo (`viewerCanUpdate=true`). Sprint Planning, vista 6: HU001–HU004/#29–#46 en Sprint 1; HU005–HU010/#47–#70 en Sprint 2; HU011–HU013/#71–#83 en Sprint 3. #80–#83 ya tenían Sprint 3: no se rellenaron ni cambiaron por suponer lo contrario. Se conservan fechas y asignaciones futuras. El cierre de una issue y el campo Status del Project se comprueban por separado.

### Orden de integración y revisiones

1. PR #148 → `feature/backend-sprint-3`, una vez aceptado y revisado. Conserva la implementación HU013 de Danilo.
2. PR #147 → `develop`, incluyendo el resultado anterior y sus APIs de perfil/CV/ofertas; comprobar destino, migraciones y resultado real.
3. PR #149 → `frontend`, una vez completada su aceptación y revisión. Conserva el formulario HU013 y esta aportación QA de Francisco.
4. Antes del PR #146 → `main`, incorporar de forma revisada la base backend actualizada a la rama de entrega y repetir la comprobación conjunta. El backend antiguo incluido en `frontend` no basta para HU011–HU013. El checkout aislado acredita que se pueden conservar ambas implementaciones, no una fusión remota.

Las dos pilas pueden avanzar independientemente hasta sus puntos de revisión, pero #146 no debe entregarse sin las APIs de #147/#148. Se mantienen los cuatro PR en borrador mientras falten aceptación y revisiones cruzadas. Danilo revisa frontend/integración de Francisco; Francisco revisa backend de Danilo. El nuevo QA de Francisco también requiere el contraste aplicable; un agente, cambiar de cuenta o pasar pruebas no constituye una revisión humana. HU014–HU027 no se iniciaron.


**Verificación final del seguimiento, 07/11/2026.** [Snapshot sanitizado por historia/subtarea](evidencias/retoma-20261107/seguimiento.json): HU009 #10 cerrada y Done; HU001–HU004/HU010 conservan cierre; HU011/HU012 abiertas. Un único comentario por cada subtarea #29–#83. Responsables, estados y relaciones padre/subtarea contrastados después de editar. Los campos Sprint/fechas y el alcance de HU014–HU027 permanecen intactos. Las referencias a PR se comprobaron también en las cronologías de #50/#62/#79/#83. No hay fusiones remotas ni revisiones humanas nuevas; se solicitaron Danilo en #146/#149 y Francisco en #147/#148. La combinación de aceptación `f188c76` queda únicamente local, sin publicar bases, venv, entornos, credenciales o temporales.


## Aceptación visual y revisiones preparadas — 07/11/2026

Continuación de `df14f3d` y `8407619`. Francisco conserva Flutter, integración y
nuevo QA; Danilo conserva Django. [Casos, versiones, respuestas y persistencia
sanitizados](evidencias/retoma-20261107/aceptacion-visual/resultados.json).
La combinación local `f188c76` se conserva y su corrección es `33ec3fc`; se publica
la misma corrección sobre la rama fuente de #149. No se fusionaron ramas.

Computer Use vuelve a fallar por pipe nativo ausente (os error 2). La skill
disponible documenta reintento/reset para timeout, pero no un reinicio del pipe
para este error. No se ejecutaron helpers ni se retomó la sesión personal antes
bloqueada. La alternativa expresamente autorizada sí pasó su prueba mínima:
**Playwright, Chrome for Testing/Chromium 158.0.8127.18**, headless, con navegador y
contextos temporales nuevos; URL `http://127.0.0.1:55031/login`, título WorkNet y
[captura real inspeccionada](evidencias/retoma-20261107/aceptacion-visual/00-login.png).
No usa perfil personal. La base QA nueva y el correo a archivos están separados
de todos los servicios, bases y entornos anteriores. No se hizo envío SMTP.

Escritorio: 1440 × 1000/1100. **Móvil web: viewport 390 × 844 con ratón/teclado**;
no equivale a dispositivo físico, Android/iOS ni prueba táctil. Las acciones de
aceptación se ejecutaron con controles, teclado y desplazamiento reales de la
app. Las capturas se inspeccionaron; las consultas SQLite y la lectura PDF son
contrastes adicionales, no sustitutos del recorrido.

| Recorrido aprobado | Capturas reales |
|---|---|
| HU012: precarga móvil, plantillas, nombre/correo/URL y fechas | [Precarga](evidencias/retoma-20261107/aceptacion-visual/02-hu012-movil-precarga.png), [validaciones](evidencias/retoma-20261107/aceptacion-visual/03-hu012-movil-validacion.png), [fechas](evidencias/retoma-20261107/aceptacion-visual/04-hu012-movil-fechas.png), [plantillas](evidencias/retoma-20261107/aceptacion-visual/05-hu012-movil-plantillas.png) |
| HU012: seguir editando, borrador tras red/503 y reintento de carga | [Salida](evidencias/retoma-20261107/aceptacion-visual/06-hu012-movil-salida.png), [borrador](evidencias/retoma-20261107/aceptacion-visual/07-hu012-movil-red-borrador.png), [red](evidencias/retoma-20261107/aceptacion-visual/08-hu012-movil-error-red.png), [503](evidencias/retoma-20261107/aceptacion-visual/11-hu012-error-servidor-simulado.png), [carga](evidencias/retoma-20261107/aceptacion-visual/33-hu012-carga-red.png) |
| HU012: guardado, PDF/descarga, secciones opcionales, perfil intacto | [PDF móvil](evidencias/retoma-20261107/aceptacion-visual/09-hu012-movil-pdf.png), [PDF completo](evidencias/retoma-20261107/aceptacion-visual/13-hu012-escritorio-pdf-completo.png) |
| HU012: 401 real retira datos/PDF, otra cuenta y Atrás no los recuperan | [Sesión](evidencias/retoma-20261107/aceptacion-visual/14-hu012-sesion-expirada.png), [otra cuenta](evidencias/retoma-20261107/aceptacion-visual/15-hu012-otra-cuenta.png), [móvil y Atrás](evidencias/retoma-20261107/aceptacion-visual/35-hu012-movil-sesion-y-atras.png) |
| HU013: empresa aprobada, siete campos, catálogos, obligatorios y salario | [Formulario](evidencias/retoma-20261107/aceptacion-visual/17-hu013-escritorio-formulario.png), [obligatorios](evidencias/retoma-20261107/aceptacion-visual/18-hu013-escritorio-obligatorios.png), [categorías](evidencias/retoma-20261107/aceptacion-visual/19-hu013-catalogo-categorias.png), [contratos](evidencias/retoma-20261107/aceptacion-visual/20-hu013-catalogo-contratos.png), [salario](evidencias/retoma-20261107/aceptacion-visual/21-hu013-salario-invalido.png) |
| HU013: publicación escritorio/móvil, confirmaciones y dashboard 2 → 3 → 4 | [Escritorio](evidencias/retoma-20261107/aceptacion-visual/22-hu013-escritorio-confirmacion.png), [3 activas](evidencias/retoma-20261107/aceptacion-visual/23-hu013-movil-dashboard-3.png), [móvil](evidencias/retoma-20261107/aceptacion-visual/28-hu013-movil-confirmacion.png), [4 activas](evidencias/retoma-20261107/aceptacion-visual/29-hu013-movil-dashboard-4.png) |
| HU013: catálogo/red, obligatorios móvil, fallo de envío/campo y sesión | [Carga](evidencias/retoma-20261107/aceptacion-visual/24-hu013-movil-catalogo-red.png), [obligatorios](evidencias/retoma-20261107/aceptacion-visual/25-hu013-movil-obligatorios.png), [borrador](evidencias/retoma-20261107/aceptacion-visual/26-hu013-movil-error-red-borrador.png), [400 controlado](evidencias/retoma-20261107/aceptacion-visual/27-hu013-movil-error-campo-simulado.png), [401 real](evidencias/retoma-20261107/aceptacion-visual/30-hu013-movil-sesion-expirada.png) |
| HU013: empresa no aprobada sin acceso; URL directa recibe 403 real sin formulario | [Empresa](evidencias/retoma-20261107/aceptacion-visual/31-hu013-empresa-no-aprobada.png), [403](evidencias/retoma-20261107/aceptacion-visual/32-hu013-acceso-directo-denegado.png) |

Los fallos de red se inyectaron únicamente en las solicitudes de la pestaña QA;
503 de CV y 400 de oferta son respuestas controladas de Playwright. No se
atribuyen a un fallo observado en Django. Los 401 y 403 sí proceden del backend;
para el 401 se revocó solo el token correspondiente de la SQLite nueva.
Los reintentos de guardado/publicación y las confirmaciones proceden de Django.
La SQLite conserva una única oferta por envío exitoso, ambas con propietario QA,
estado `published`, categoría/contrato y salario correctos. Los intentos fallidos
no crearon ofertas. La comparación con la SQLite inicial confirma perfil intacto.
Vista previa y descarga UI coinciden por texto tanto antes como después de añadir
idiomas, certificación y otra sección; ambos PDF tienen una página. Concuerda con
las 18 comprobaciones HTTP y tres plantillas PDF anteriores, conservadas con su alcance.

**Defecto demostrado y corregido (HU012):** al confirmar salir y volver antes de
terminar la transición, la `GlobalKey` compartida recuperaba el estado descartado.
[Antes](evidencias/retoma-20261107/aceptacion-visual/10-hu012-reabrir.png).
El widget reprodujo clave duplicada y una consulta en vez de dos. Ahora se renueva
la clave al confirmar salida y cada página captura la suya; cancelar salida sigue
conservando el borrador. [Después, nueva consulta y resumen guardado](evidencias/retoma-20261107/aceptacion-visual/34-hu012-descarte-corregido.png).
Pasaron 46 pruebas pertinentes (CV generado/subido, ofertas y páginas de acceso),
análisis y compilación JavaScript release. No se repitió toda la batería técnica.
Persisten los avisos conocidos de Wasm/Cupertino. No hubo cambios de producto backend.

### Revisión técnica preparada y condiciones de integración

[Comprobaciones automáticas de los PR](evidencias/retoma-20261107/aceptacion-visual/revision-automatizada.json):
diff completo base...head sin errores de whitespace; contratos, permisos,
persistencia, normalización salarial, PDF privado y manejo de sesión contrastados
de forma dirigida con código/recorrido/evidencia existente. Los cuatro PR siguen
abiertos y en borrador. GitHub devuelve cero check-runs y cero contextos de status:
el `pending` agregado no acredita CI ejecutada. Los resultados locales anteriores
se conservan. No se presentó una revisión humana ni una aprobación por cambiar cuenta.

| Revisor humano pendiente | Cambios/evidencias que debe contrastar | Condición concreta |
|---|---|---|
| Danilo, #146 | Acceso/perfiles/dashboards y HU011/HU012 de Francisco; evidencia histórica y nueva, salida sin guardar/401/PDF; corrección publicada por #149 | Registrar revisión real. El arreglo y nuevo QA entran por #149; #146 todavía no los contiene. Antes de entregar a main necesita backend revisado de #147/#148 e inspección del resultado conjunto |
| Danilo, #149 | Formulario HU013, errores y publicación → dashboard; regresión de reentrada HU012 y 46 pruebas pertinentes | Revisar la nueva cabecera y su diff. Verificar capturas y autorización. No basta la solicitud de revisión existente |
| Francisco, #147 | Backend de perfil empresarial autorizado, CV subido/generado, serializers/límites y privacidad del PDF; 141 pruebas y Desktop históricos | Revisión real del código de Danilo. HU018 no está implementada. Incorporar primero #148 y volver a comprobar la cabecera/resultante antes de integrar a develop |
| Francisco, #148 | Migración de campos, contratos/catálogos, bloqueo por empresa verificada/aprobada y propietario/estado/fecha fijados en servidor | Revisar código y migración; contrastar 403 y oferta persistida de UI y evidencia Postman. No convertir este QA automatizado en revisión humana |

**Estados por resultado:** #75/#78 pasan a In review tras aceptación propia;
#76/#77 se mantienen In review. #79 continúa QA / Testing porque su objetivo
incluye postulación (HU018), además de revisión humana pendiente; HU012 permanece
abierta en QA / Testing. #80/#82/#83 y HU013 pasan a In review; #81 se mantiene
In review. Su aceptación propia está comprobada, pero ninguna se cierra sin las
revisiones aplicables. HU011 conserva el criterio pendiente de HU018. Las casillas
de revisión por otro integrante permanecen abiertas. Las asignaciones, Sprint,
fechas y registros históricos se conservan, con un único comentario por subtarea.

Orden intacto: #148 → backend-sprint-3 antes de #147 → develop; #149 → frontend;
incorporar el backend revisado a entrega y verificar después antes de #146 → main.
Ni estar mergeable ni completar aceptación suplen revisión o integración. No se
inició HU014–HU027, no se fusionó ni aprobó ningún PR y este bloque termina aquí.
