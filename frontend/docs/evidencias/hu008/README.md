# HU008 — perfil profesional del candidato

Fecha de seguimiento: **18/10/2026**, America/Bogota. Historia #9; tareas #59–#62.
Backend: **Danilo2334** (#60). Interfaz/integración: **francisco3788** (#59/#61).
QA automatizado por el agente, registrado como **Danilo2334** (#62).
La revisión humana por otro integrante sigue pendiente.

## Commits y contratos

| Parte | Commit y publicación |
| --- | --- |
| Backend privado y fotografía | [a400455](https://github.com/Danilo2334/Work_net/commit/a40045545ff874b079392d55786992786093ee83), Danilo; publicado en `feature/backend-sprint-2` y consolidado por fast-forward en `develop` |
| Incorporación de backend a Flutter | [b280152](https://github.com/Danilo2334/Work_net/commit/b280152a43f6d26e3a02d9209727801bf578255b), después de publicar `develop`; conserva las autorías |
| Formulario e integración | [1a903ab](https://github.com/Danilo2334/Work_net/commit/1a903ab28c549c0a2e12da000782d2da73e5b4cd), Francisco |
| Lectura de fotografía y regresión | [c104b02](https://github.com/Danilo2334/Work_net/commit/c104b0280bad34c9e264ec0fccef3fadc9b1cb76), Francisco |

[Contrato backend completo](../../../../backend/candidate_dashboard/PROFILE_API.md):

- `GET/POST/PATCH/DELETE /api/profile/candidate/`: consulta, creación,
  actualización de descripción y vaciado del perfil, conservando la cuenta.
- `GET/POST /api/profile/candidate/<section>/`: consulta y creación de registros
  de `education`, `experience`, `skills` y `languages`.
- `GET/PATCH/DELETE /api/profile/candidate/<section>/<id>/`: consulta, edición
  parcial y eliminación del registro propio mediante su identificador.
- `PUT/GET/DELETE /api/profile/candidate/photo/`: carga multipart, lectura
  autenticada y eliminación de fotografía opcional.

Los cambios devuelven el perfil completo y la completitud calculada por Django.
Se conservan las listas históricas y sus claves adicionales; los nuevos registros
tienen campos estructurados e identificadores. [Muestra real de respuesta con
datos ficticios](perfil-estructurado-qa.json), reutilizable por un futuro CV.
Esto acredita disponibilidad de datos estructurados, no generación de un PDF/CV.

La fotografía admite JPEG/PNG estáticos hasta 2 MiB, 4096 px por lado y 16 MP.
El servidor verifica su contenido y recodifica los píxeles sin metadatos. Los bytes
se guardan en la fila privada; no hay URL pública de archivos. Flutter lee la
imagen con Authorization Token y acepta JPEG y JSON para los errores de DRF;
no pone credenciales en la URL. Una carga inválida conserva la imagen anterior.

## Qué funciona en Flutter

El dashboard abre «Perfil del candidato» en `/profile`, con sesión y rol candidato.
El formulario permite guardar/editar descripción, agregar/consultar/editar/eliminar
los cuatro tipos de registro, cargar/cambiar/eliminar foto y vaciar el perfil con
confirmación. Hay carga, estado vacío, errores, validaciones y reintento.
Un error al guardar un registro conserva el borrador en el editor para reintentar.

Al volver o recargar se consultan los datos persistidos. Al regresar al dashboard
se consulta otra vez Django: se observó 17% vacío, 100% con las seis secciones,
33% después de eliminar los registros y 17% después de vaciar el perfil.
La fotografía es opcional y no suma ni resta una sección de completitud.

## Entorno y pruebas

- Windows, Flutter web y Chrome. Escritorio **1440×1280**; móvil **390×844**.
- Flutter `http://localhost:55003` → Django `http://127.0.0.1:8004/api/`.
- Otra SQLite creada con `frontend/tool/qa_backend.py`; cuentas verificadas,
  nombres, estudios y empresas ficticios identificados como QA. La base habitual
  no se usó para pruebas ni para eliminar datos.
- `python manage.py test accounts candidate_dashboard --noinput`: **87 aprobadas**,
  incluidas 17 nuevas del perfil y la regresión de las 70 anteriores.
- `python manage.py makemigrations --check --dry-run`: sin cambios pendientes;
  la migración aditiva `0002_candidateprofile_photo_data` se aplicó en la base QA.
- `flutter analyze`: **sin incidencias**.
- `flutter test`: **67 aprobadas**, incluidas las 54 anteriores y 13 nuevas.
- **47 comprobaciones nuevas aprobadas** en navegador y consultas auxiliares a
  Django real. [Informe sanitizado](resultados-qa.json). Los conteos corresponden
  al bloque conjunto, no a cada tarea individual.
- Regresión automatizada de registro, login, recuperación, dashboard y cuenta.
  Las evidencias anteriores conservan sus resultados de fase y no se presentan
  como una nueva ejecución manual en esta entrega.

| Caso | Esperado | Obtenido |
| --- | --- | --- |
| Sin sesión | Ruta al login; API protegida | Redirección y HTTP 401 en perfil/foto |
| Perfil inicial vacío | Consultar sin crear una fila | 17%, formularios vacíos; backend GET sin escritura |
| Descripción | Crear/editar y persistir | HTTP 201/200; texto recuperado desde Django |
| Educación, experiencia, habilidades e idiomas | Crear, leer, editar y eliminar registros | Los cuatro tipos comprobados contra API/base QA |
| Obligatorios y fecha imposible | Bloquear antes de enviar | Error visible; 2026-02-31 rechazado |
| Fechas invertidas y PATCH parcial | Rechazar sin perder lo anterior | Pruebas Flutter/backend aprobadas |
| Recargar / regresar | Recuperar datos guardados | Registros visibles después de nueva consulta |
| Completitud | Usar cálculo del servidor | Dashboard 17 → 100 → 33 → 17 según datos guardados |
| Foto válida | Guardar, consultar con token y mostrar | HTTP 200, JPEG privado y fotografía visible en web |
| Foto ausente/eliminada | Ser opcional | HTTP 404; no altera completitud |
| Archivo falso `.png` | Rechazar y conservar foto previa | HTTP 400 y error visible; foto previa continúa disponible |
| Tamaño/formato/MIME/dimensiones inválidos | Rechazar | Suite backend cubre SVG, contenido falso, MIME/extensión incorrectos, >2 MiB, >4096 px y múltiples archivos; Flutter cubre tamaño antes de subir |
| Otro candidato | Sin acceso a registros/foto ajenos | GET/PATCH/DELETE de id ajeno HTTP 404; solo consulta su propio perfil |
| Empresa/administrador | Sin acceso implícito | HTTP 403; también se prueba empresa con postulación existente en backend |
| Cancelar eliminación de registro | Conservar el registro | Consulta posterior conserva educación |
| Vaciar perfil | Confirmar, borrar perfil/foto/registros y conservar cuenta | HTTP 200; cuenta sigue autenticada y dashboard vuelve a 17% |
| Red desconectada/reintento | Error recuperable | Aviso visible; reintento recupera los datos |
| Reutilización para CV | Campos y fechas estructurados | JSON ficticio con educación, experiencia, habilidades e idiomas, sin credenciales |

La revisión visual detectó y corrigió la negociación de contenido de la fotografía
(HTTP 406 con Accept solo JPEG). Se añadió JSON al Accept de esa petición y una
regresión automatizada; se volvió a comprobar HTTP 200 y la imagen visible. El
informe conserva esa incidencia corregida separada de las respuestas finales.

## Capturas vigentes

**14 capturas de interfaz**, más [una imagen sintética QA](foto-qa.png) usada como
archivo de fotografía de prueba. No representa a una persona real. Las capturas
solo contienen información ficticia, sin tokens, contraseñas ni cabeceras.

| Estado | Capturas |
| --- | --- |
| Perfil vacío | [Escritorio](perfil-vacio-escritorio.png), [móvil](perfil-vacio-movil.png) |
| Descripción y datos completos | [Perfil completo](perfil-completo-escritorio.png) |
| Registros guardados | [Escritorio](registros-escritorio.png), [móvil](registros-movil.png) |
| Validación y editor | [Fecha inválida](educacion-fecha-invalida.png), [experiencia en móvil](experiencia-editor-movil.png) |
| Fotografía | [Guardada](fotografia-guardada.png), [móvil](perfil-fotografia-movil.png), [archivo inválido](fotografia-invalida.png) |
| Dashboard actualizado | [Completitud 100%](dashboard-completitud.png) |
| Error recuperable | [Error y reintento](perfil-error-reintento.png) |
| Vaciado | [Confirmación](vaciar-perfil-confirmacion.png), [perfil vaciado](perfil-vaciado.png) |

Las vistas largas se desplazan verticalmente; una captura de una sección no
pretende mostrar todo el perfil en un solo viewport.

## Reproducir y actualizar

Instalar `backend/requirements.txt`, incluida Pillow 13.0.0. En cada entorno
actualizado ejecutar `python manage.py migrate` para añadir el campo de fotografía.
Para repetir QA desde la raíz:

```powershell
python frontend/tool/qa_backend.py --port 8004 --frontend-origin http://localhost:55003
```

Desde otra terminal en `frontend`:

```powershell
flutter pub get
flutter run -d chrome --web-port 55003 --dart-define=API_BASE_URL=http://127.0.0.1:8004/api/
```

La cuenta ficticia `perfil.qa@worknet.test` empieza sin perfil. Las contraseñas
aleatorias están únicamente en `.dart_tool/worknet_qa/latest.json`, ignorado por
Git. Cada ejecución crea otra base; no publicar la base ni las credenciales.

## Estado preciso y pendientes

| Tarea | Estado |
| --- | --- |
| #59, interfaz | Implementada para el candidato; evidencia disponible; revisión formal pendiente |
| #60, backend | CRUD/foto del propietario implementados y probados; consulta por empresas autorizadas pendiente de su dependencia; revisión pendiente |
| #61, integración | Perfil/foto/completitud integrados para el candidato; revisión formal pendiente |
| #62, QA | Casos del candidato y denegación de permisos comprobados; QA parcial del criterio de consulta empresarial; revisión humana pendiente |

**Falta implementar una autorización comprobable de empresa dentro del proceso
de selección.** Una postulación básica no otorga ese permiso. Hasta que exista y
se pruebe la dependencia, la empresa recibe HTTP 403. No se declara satisfecho
ese criterio original de HU008.

Faltan revisión por otro integrante y validación nativa. La generación de CV
pertenece a su módulo posterior; los datos estructurados están disponibles.
SMTP real, estados empresariales y los otros accesos del dashboard se conservan
en sus historias y no se usan para bloquear indebidamente HU004. Sus revisiones
humanas anunciadas por el equipo todavía no se registran como ocurridas.
No se alteran Sprints, fechas ni criterios originales, ni se cierran tareas.
El PR #146 continúa en borrador y sin fusionar.
