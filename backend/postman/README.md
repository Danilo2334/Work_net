# Pruebas del backend en Postman

La colección contiene **237 peticiones con comprobaciones automáticas**, agrupadas en doce fases. Todas llaman a Django real; no hay respuestas simuladas. Cada petición explica tarea, objetivo, preparación, método, URL, encabezados, cuerpo y resultado esperado. El catálogo completo está en [CASOS.md](CASOS.md).

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
4. Ejecuta las carpetas **01 a 12 en orden**, con una iteración y sin paralelismo. Puedes usar Run folder o enviar cada petición con Send. Conserva los valores del entorno entre carpetas. Las fases cambian contraseñas, roles y tokens, por lo que no se deben repetir sobre una base ya usada.
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

### Quince casos adicionales de consulta empresarial — #60 y #62

Después de completar las fases 01–12, importa también **`WorkNet.HU008-selection.postman_collection.json`**. Conserva la colección anterior y selecciona **el mismo entorno privado**, sin reimportarlo: Postman ya obtuvo las sesiones y `selection_application_id` mediante respuestas reales. Esta segunda colección contiene **15 casos con 44 comprobaciones**, separados en carpetas A–F.

Desde la raíz del checkout, utiliza el mismo Python con el que preparaste QA. Si usas un entorno virtual, actívalo antes. En PowerShell:

```powershell
$qaRun = (Get-Content backend/postman/.local/latest.txt).Trim()
$applicationId = [int](Read-Host 'ID selection_application_id obtenido en PM213')
python backend/postman/selection_qa.py prepare --run $qaRun --application-id $applicationId
python backend/postman/selection_qa.py before A --run $qaRun
```

Confirma que `$qaRun` sea el valor `qa_run_id` del entorno activo y que el identificador impreso por la preparación coincida con `selection_application_id`. Ejecuta **solo la carpeta A** en Postman Desktop, con una iteración, conservando los valores del entorno y las respuestas. Después:

```powershell
python backend/postman/selection_qa.py after A --run $qaRun
```

Continúa en el orden siguiente. **Antes de cada carpeta**, ejecuta su preparación y `before` con la letra correspondiente; **al terminarla**, ejecuta `after` con esa misma letra. No ejecutes las seis carpetas juntas: los cambios de estado necesitan estas pausas.

| Carpeta | Preparación: `python backend/postman/selection_qa.py ACCIÓN --run $qaRun` | Casos | Resultado esperado |
|---|---|---:|---|
| A | `prepare --application-id $applicationId` — ya realizada arriba | 5 | Perfil propio de la postulación: 200 y solo campos permitidos. Empresa ajena con parámetros manipulados: 404. Candidato y administrador en la ruta empresarial de foto: 403. |
| B | `unverified` | 2 | Empresa propietaria aprobada, pero sin correo verificado: 403 para perfil y foto. |
| C | `rejected` | 2 | Empresa verificada, pero rechazada: 403 para perfil y foto. |
| D | `removed` | 2 | Al retirar esa postulación: 404 para perfil y foto, aunque permanece otra postulación del candidato a la misma empresa. |
| E | `missing` | 2 | Se restablece la postulación y se retira el perfil de prueba: 200 con `exists: false`; foto 404. Consultar no crea un perfil. |
| F | `restore` | 2 | Perfil y foto de QA restablecidos: 200, campos históricos privados filtrados y JPEG con protección de caché. |

Por ejemplo, para B ejecuta `selection_qa.py unverified --run $qaRun`, luego `selection_qa.py before B --run $qaRun`; ejecuta B en Postman y termina con `selection_qa.py after B --run $qaRun`. El procedimiento es el mismo para C–F.

Todas estas peticiones son `GET` sin cuerpo, con `Authorization: Token {{variable_del_rol}}`, sobre `/company/applications/{{selection_application_id}}/profile/` o su subruta `photo/`. Las variables `company_token`, `draft_token`, `candidate_token` y `admin_token` proceden de la colección principal; no deben copiarse al código ni compartirse. El caso de parámetros manipulados utiliza la sesión de `draft`, ya aprobada y ajena a las ofertas consultadas. Los 25 casos principales incluyen además sesión ausente, identificadores inexistentes y métodos de escritura rechazados.

`selection_qa.py` lee las cuentas ficticias del entorno local generado por `qa.py`. Verifica el marcador, la ruta de SQLite, el run y las relaciones de propiedad antes de cambiar datos. Solo modifica la base aislada indicada; no modifica `db.sqlite3`, no cambia contraseñas ni publica credenciales. La foto requerida es `fixtures/foto-qa.png`, ya utilizada por la colección principal. La preparación conserva una copia previa de SQLite y las fixtures en `.local/run-…/selection/`. `before` y `after` comparan las huellas y los recuentos de todas las tablas; no exportan filas y rechazan una lectura que escriba datos.

Conserva esa carpeta y las exportaciones de Postman en privado. Para otra pasada, crea una base nueva con `qa.py prepare`, importa su nuevo entorno y repite desde 01. La preparación adicional rechaza reutilizar su carpeta o saltar etapas. Los datos sembrados de ofertas y postulaciones sirven para comprobar permisos; no implementan todo HU018/HU020.

**Ejecución conservada del 24/10/2026:** código de producto `2547c3786bbbe8abcc1b887a3767ba9223c123aa`, Python 3.12.10, Django 6.1.1 y Postman Desktop 12.33.3, contra `127.0.0.1:8012` y SQLite aislada. Pasaron 114 pruebas Django; en Postman, 212 peticiones previas/631 comprobaciones, 25 casos principales/75 comprobaciones y 15 casos adicionales/44 comprobaciones, sin fallos ni errores. No se sustituyó Postman por Newman. Las capturas públicas están en `backend/docs/evidencias/postman/capturas/hu008-seleccion/` y en los comentarios únicos de #60/#62. Las exportaciones originales permanecen privadas. La preparación publicada se comprobó posteriormente en otra base aislada, incluyendo sus seis etapas y el rechazo de entradas incorrectas; esa comprobación local no es una nueva corrida de Postman ni reemplaza la evidencia del 24/10.

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

La colección comprueba también que un archivo rechazado conserve la fotografía anterior, que otro usuario no la reciba, que quitarla persista y que no reduzca la completitud del perfil.

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

Las capturas anteriores de Postman Desktop corresponden a las 212 peticiones originales del 19/10. La ejecución intermedia con Newman se conserva como antecedente. El 24/10 se ejecutaron en Postman Desktop los 25 casos de fase 12 y los 15 adicionales descritos arriba; esa evidencia nueva no cambia la fecha ni el alcance de las capturas anteriores.

La colección usa JSON **v2.1**, importación normal y Newman fijado en `package-lock.json`; no es el formato Native Git v3. Referencias oficiales: [importar en Postman](https://learning.postman.com/docs/getting-started/importing-and-exporting/importing-data/), [valores locales de entorno](https://learning.postman.com/docs/use/send-requests/variables/environment-variables/), [Newman como biblioteca](https://github.com/postmanlabs/newman#using-newman-as-a-library). Si cambias casos, edita `build_collection.py` y vuelve a generar colección y catálogo; conserva y vuelve a ejecutar la evidencia que corresponda.
