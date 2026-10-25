# Pruebas del backend en Postman

La colección contiene **281 peticiones con comprobaciones automáticas**, agrupadas en catorce fases. Todas llaman a Django real; no hay respuestas simuladas. Cada petición explica tarea, objetivo, preparación, método, URL, encabezados, cuerpo y resultado esperado. El catálogo completo está en [CASOS.md](CASOS.md).

Los resultados y capturas se conservan en el comentario único de cada tarea en GitHub. Esta guía explica cómo preparar y repetir los casos desde Postman.

## Preparar la base y abrir Django

Desde la raíz de Work_net, en PowerShell, con Python y la aplicación Postman instalados:

```powershell
python -m pip install -r backend/requirements.txt
python backend/postman/qa.py prepare --port 8008
python backend/postman/qa.py serve
```

Deja abierta esa terminal. Si 8008 está ocupado, prepara otro puerto libre, por ejemplo `--port 8011`; el entorno generado usará ese puerto. No ejecutes `manage.py runserver` para esta colección: el servidor de QA selecciona una SQLite independiente y captura el correo en archivos aunque tengas Gmail configurado en `.env`.

`prepare` crea `backend/postman/.local/run-…/` con migraciones, siete usuarios ficticios verificados, dos ofertas, dos postulaciones, un favorito y dos avisos. El candidato principal empieza con 83 % de completitud; el segundo, con 17 %. Hay tres empresas: una aprobada y dos sin solicitud completa. La cuenta de registro todavía no existe. Los IDs se obtienen de respuestas, no se fijan en la colección.

Las contraseñas aleatorias y los tokens permanecen en `.local/`, ignorado por Git. El archivo `WorkNet.local.postman_environment.json` publicado es solo un **ejemplo sin credenciales**: por sí solo no habilita las pruebas.

## Importar y ejecutar desde Postman

1. Abre tu Postman habitual y usa **Import** para cargar `backend/postman/WorkNet.postman_collection.json`. Se llama **WorkNet · QA backend reproducible · Postman** y se añade como colección nueva. Conserva tus tres colecciones originales.
2. Importa el archivo privado **`local.postman_environment.json` de la carpeta run-… que indicó prepare** y selecciónalo como entorno activo. Usa los valores locales de Postman; no los compartas con el equipo ni publiques el entorno exportado. Las variables sensibles están marcadas como secretas.
3. En Settings → General → Working directory, selecciona la ruta absoluta de `backend/postman`. Así los archivos multipart se resuelven dentro de esa carpeta. Si tu versión no conserva la ruta relativa, selecciona el archivo indicado manualmente en Body → form-data → photo.
4. Ejecuta las carpetas **01 a 14 en orden**, con una iteración y sin paralelismo. Puedes usar Run folder o enviar cada petición con Send. Conserva los valores del entorno entre carpetas. Las fases cambian contraseñas, roles y tokens, por lo que no se deben repetir sobre una base ya usada.
5. Haz las dos pausas de correo indicadas en la tabla. En Postman, abre el entorno y cambia **solo las variables indicadas**. No reimportes el entorno entero a mitad de la ejecución: perderías IDs y tokens que Postman acaba de obtener.
6. Revisa **Test Results** en cada respuesta y el resumen del Runner. Un HTTP 400, 401, 403, 404, 405 o 409 es correcto únicamente donde el caso lo espera; el script también comprueba el contenido pertinente.

| Fase | Tarea y recorrido | Preparación adicional |
|---|---|---|
| 01 | #30: registro, validaciones, duplicado y selección posterior del rol; #35: login sin verificar | Estado inicial |
| 02 | #31: verificación; #35: login, logout y tokens por usuario | **Antes**, cargar `verification_token` desde el mensaje generado por 01 |
| 03 | #40: solicitar recuperación y respuesta genérica | Sesión de 02 |
| 04 | #40: confirmar cambio, enlace reutilizado, contraseña anterior y token revocado | **Antes**, cargar `reset_uid` y `reset_token` desde el mensaje generado por 03 |
| 05 | #44: consultar, editar nombre, cambiar contraseña y rotar token | Tokens obtenidos en 02 |
| 06 | #45: preferencias booleanas, persistencia y separación entre usuarios | Token nuevo de 05 |
| 07 | #48, #52 y #56: métricas reales y restricciones por rol | Antes de modificar perfiles y enviar solicitudes |
| 08 | #60: perfil, cuatro secciones, permisos y fotografía opcional | Fixtures de fotografía preparados |
| 09 | #64: información empresarial y envío completo | Empresa `draft`, todavía sin enviar |
| 10 | #68: revisión, rechazo, corrección, reenvío y aprobación; #35/#52/#56: efectos reales | ID y versión de 09; token administrativo de 02 |
| 11 | #44: eliminación cancelada, inválida y confirmada | Solo la cuenta desechable `disposable` |
| 12 | #60: lectura del perfil y foto de un postulante por la empresa dueña; aislamiento y bloqueo de escritura | ID real obtenido de su dashboard; `draft` ya aprobada, sin postulaciones propias |
| 13 | #72/#74: PDF válido, corrupto, cifrado, activo, tamaño, aislamiento y reemplazo | Campo multipart `file`; fixtures PDF descritos debajo |
| 14 | #76/#77/#79: precarga real, edición, tres plantillas, vista previa, persistencia, PDF y permisos | `cv_data` procede de la respuesta de Django; no requiere editar JSON manualmente |

### Leer los enlaces del correo local

Después de fase 01, desde otra terminal en la raíz:

```powershell
python backend/postman/qa.py mail verification
```

Abre **localmente en tu editor** el archivo `local.postman_environment.json` del run activo. Copia únicamente el valor de `verification_token` a la variable del mismo nombre en Postman, manteniéndola secreta. El enlace fue generado por Django y leído del mensaje guardado en `run-…/mail/`; el script no crea ni firma otro enlace.

Después de fase 03:

```powershell
python backend/postman/qa.py mail recovery
```

Copia únicamente `reset_uid` y `reset_token` al entorno activo. No compartas enlaces firmados ni capturas de sus valores. La API de confirmación recibe los parámetros del enlace; el recorrido visual del formulario Flutter se documenta por separado.

Estos mensajes **no se envían a Gmail**. Para entrega real, usar un entorno de QA distinto con SMTP y un buzón autorizado: comprobar recepción, abrir su enlace y seguir el recorrido. No cambiar este servidor aislado a SMTP ni usar direcciones reales en la colección. La evidencia SMTP previa de WorkNet se conserva en [SMTP.md](https://github.com/Danilo2334/Work_net/issues/31#issuecomment-6272920035); no se atribuye a esta ejecución de Postman.

## Evidencia que se registra

Ejecutar en la aplicación Postman, usando Send o el Collection Runner. Capturar petición, respuesta y Test Results. Para frontend, guardar únicamente capturas directas de la app Flutter. Conservar los enlaces firmados, contraseñas y tokens fuera de las imágenes.

## Repetir desde cero y conservar los resultados

Detén el servidor con **Ctrl+C** en su terminal. Repite:

```powershell
python backend/postman/qa.py prepare --port 8008
python backend/postman/qa.py serve
```

`prepare` restaura el **estado funcional inicial mediante una base nueva**, con las mismas cuentas, actividad y permisos. No borra ni sobrescribe la ejecución anterior. `initial.sqlite3` conserva además su fotografía inicial, pero no hay que copiarla sobre una base abierta. Los tokens, contraseñas y fechas cambian; los resultados funcionales esperados permanecen iguales.

Para repetir en Postman, importa y selecciona el entorno privado **del nuevo run**; vuelve a empezar en 01. Cada entorno tiene un identificador propio para conservar la pasada anterior. Si necesitas abrir un run concreto: `python backend/postman/qa.py serve --run run-…`.

## Fotografías de prueba

| Archivo relativo a backend/postman | Caso esperado |
|---|---|
| `fixtures/foto-qa.png` | PNG sintético válido, reutilizado de la evidencia HU008; Django lo devuelve como JPEG privado |
| `fixtures/no-imagen.txt` | Extensión no admitida: HTTP 400 |
| `fixtures/corrupta.png` | Archivo con extensión PNG y contenido inválido: HTTP 400 |
| `.local/fixtures/ancha.png` | Imagen de 4097 × 1 generada por prepare: HTTP 400 |
| `.local/fixtures/exceso.png` | Archivo de más de 2 MiB generado por prepare: HTTP 400 por tamaño |
| `fixtures/curriculum-valido.pdf` | CV ficticio de una página: primera carga HTTP 201 |
| `fixtures/curriculum-reemplazo.pdf` | CV ficticio diferente: reemplazo HTTP 200; el SHA-256 debe cambiar |
| `fixtures/curriculum-corrupto.pdf` | Cabecera PDF con estructura inválida: HTTP 400 |
| `.local/fixtures/cifrado.pdf` | PDF con contraseña generado por prepare: HTTP 400 |
| `.local/fixtures/activo.pdf` | PDF con JavaScript de prueba generado por prepare: HTTP 400; no abrirlo ni ejecutarlo |
| `.local/fixtures/exceso-cv.pdf` | Archivo de más de 5 MiB generado por prepare: HTTP 400 |

La colección comprueba también que un archivo rechazado conserve la fotografía anterior, que otro usuario no la reciba, que quitarla persista y que no reduzca la completitud del perfil.

## Repetir únicamente HU011: PDF subido

Código de producto probado: `84746c36efb8ef49e044e2889e677a1f70e9fb25`.
El 24/10/2026 se ejecutaron en **Postman Desktop 12.33.3** cuatro peticiones de preparación/12 comprobaciones, 17 casos principales/48 comprobaciones y 20 adicionales/54 comprobaciones; todos aprobados. Ese día también pasaron 133 pruebas Django. Los resultados originales se conservan privados; el resumen sin credenciales y las capturas están en `backend/docs/evidencias/hu011/`. Publicar esos materiales no constituye otra ejecución.

1. Desde la raíz de este backend, con sus dependencias fijadas instaladas, ejecutar `python backend/postman/qa.py prepare --port 8016`. Anotar el `run-...` generado. Cada preparación crea otra base sin sobrescribir la anterior. Iniciar `python backend/postman/qa.py serve --run RUN_NUEVO` en una terminal que permanezca abierta.
2. Ejecutar `python backend/postman/hu011_qa.py fixtures --run RUN_NUEVO`. Genera los PDF de 50 y 51 páginas y el archivo con estructura de formulario en `.local/hu011-extra/`, sin sobrescribir contenidos diferentes. Los demás archivos proceden de `fixtures/` y de `qa.py prepare`.
3. Importar `WorkNet.HU011.postman_collection.json`, `WorkNet.HU011.adicional.postman_collection.json` y **el entorno privado del nuevo run**. Directorio de trabajo de Postman: la ruta absoluta de `backend/postman`. Las contraseñas permanecen en el entorno local; los cuatro login obtienen tokens nuevos. No copiar tokens de una exportación anterior.
4. Ejecutar la carpeta **00 — sesiones** (4/12) y después **13 — carga y reemplazo** (17/48), con una iteración y conservando variables y respuestas. Son copias de PM025, PM026, PM027, PM030 y PM238–PM254, sin modificar sus IDs ni comprobaciones. La colección original de 281 peticiones se conserva intacta. Para este bloque no hacen falta las fases de correo ni las de currículum generado.
5. Ejecutar la carpeta adicional **A** (13 peticiones/35 comprobaciones): permisos, separación entre usuarios, reemplazos rechazados y límites de páginas. Requiere haber terminado los 17 casos, que dejan guardado `curriculum-reemplazo.pdf`.
6. Pausar Postman y ejecutar `python backend/postman/hu011_qa.py unverified --run RUN_NUEVO`. Ejecutar **B** (2/6): el candidato sin verificar recibe 403 al consultar o reemplazar. Restaurar inmediatamente con `python backend/postman/hu011_qa.py verified --run RUN_NUEVO`, incluso si B falla. Estos comandos solo admiten una SQLite con el marcador QA creado por `qa.py`; no son endpoints públicos.
7. Ejecutar **C** (5/13): lectura posterior, eliminación propia, consulta 404, metadata vacía y documento del otro candidato conservado. `python backend/postman/hu011_qa.py inspect --run RUN_NUEVO` permite contrastar filas, tamaños y SHA-256 sin mostrar contraseñas ni tokens. Al finalizar queda únicamente el PDF del segundo candidato.

El envío es **PUT `/api/curriculum/uploaded/`**, multipart con un único campo `file`: 201 al crear y 200 al reemplazar. GET del mismo endpoint devuelve PDF privado; GET `/api/curriculum/` devuelve metadata. Las comprobaciones comparan los bytes recuperados; un reemplazo inválido debe conservarlos. Un parámetro `candidate` no cambia al propietario: cada candidato opera exclusivamente sobre su propio documento.

El requisito original exige PDF válido y un tamaño máximo, pero no fija su número. **5 MiB**, **50 páginas** y el rechazo de documentos cifrados, formularios, acciones y adjuntos son políticas de la implementación validada. A acepta 50 páginas y rechaza 51; no transforma esas políticas en nuevos criterios originales. La selección del CV durante una postulación sigue dependiendo de HU018.

## Casos internos y límites

La colección comprueba enlaces inválidos y recuperación reutilizada. La verificación de correo es idempotente: repetir su enlace devuelve 200, conforme al contrato actual. Forzar el reloj para crear firmas vencidas y simular fallos SMTP son **pruebas internas de Django**, no endpoints públicos de QA.

Las pruebas internas de apoyo incluyen dos casos de vencimiento y uno de fallos de envío que comprueba rollback del registro y respuesta de recuperación. Se pueden repetir con estos comandos:

```powershell
Push-Location backend
python manage.py test accounts.tests.PasswordRecoveryTests.test_expired_token accounts.test_backend_integration.ConsolidatedBackendTests.test_expired_verification_does_not_activate_the_account --noinput
python manage.py test accounts.test_company_access.CompanyAccessTests.test_registration_send_failure_rolls_back_and_recovery_reports_failure --noinput
Pop-Location
```

El fallo de envío se provoca internamente mediante mock, separado de las peticiones reales de la colección; no acredita una incidencia SMTP real. La fase 12 consulta perfiles únicamente mediante una postulación a una oferta de la empresa autenticada y aprobada. La empresa ajena recibe 404; no se habilitan escrituras empresariales sobre perfiles. El proceso completo de gestión de postulantes pertenece a HU020.

Las 212 peticiones originales tienen sus ejecuciones anteriores en Postman Desktop. El 24/10/2026 se acreditaron también los casos del perfil empresarial de HU008 (25 principales/75 comprobaciones y 15 adicionales/44; evidencia publicada en `d18bbbd`) y los de HU011 descritos arriba. Los 27 casos de la fase 14, de HU012, continúan pendientes de Postman Desktop; su ejecución previa con Newman se mantiene como apoyo. Estos resultados pertenecen a corridas y versiones identificadas, no a una nueva pasada completa de 281 peticiones.

Las fases 13 y 14 comprueban las opciones de CV disponibles, pero no una postulación con CV: ese recorrido depende de HU018. La selección del documento dentro de una postulación y su consulta empresarial deben probarse cuando exista ese flujo. No se da por cumplido ese criterio por recibir una lista de opciones.

La colección usa JSON **v2.1**, importación normal y Newman fijado en `package-lock.json`; no es el formato Native Git v3. Referencias oficiales: [importar en Postman](https://learning.postman.com/docs/getting-started/importing-and-exporting/importing-data/), [valores locales de entorno](https://learning.postman.com/docs/use/send-requests/variables/environment-variables/), [Newman como biblioteca](https://github.com/postmanlabs/newman#using-newman-as-a-library). Si cambias casos, edita `build_collection.py` y vuelve a generar colección y catálogo; conserva y vuelve a ejecutar la evidencia que corresponda.
