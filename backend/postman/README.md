# Pruebas del backend en Postman

La colección contiene **212 peticiones con comprobaciones automáticas**, agrupadas en once fases. Todas llaman a Django real; no hay respuestas simuladas. Cada petición explica tarea, objetivo, preparación, método, URL, encabezados, cuerpo y resultado esperado. El catálogo completo está en [CASOS.md](CASOS.md).

Los resultados de las dos ejecuciones con **Newman 6.2.3** están en [el informe de evidencias](../docs/evidencias/postman/README.md). Newman ejecuta esta misma colección desde consola; no equivale a una ejecución visual en Postman.

## Preparar la base y abrir Django

Desde la raíz de Work_net, en PowerShell, con Python y Node.js instalados:

```powershell
python -m pip install -r backend/requirements.txt
Push-Location backend/postman
npm.cmd ci --ignore-scripts --no-audit --no-fund
Pop-Location
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
4. Ejecuta las carpetas **01 a 11 en orden**, con una iteración y sin paralelismo. Puedes usar Run folder o enviar cada petición con Send. Conserva los valores del entorno entre carpetas. Las fases cambian contraseñas, roles y tokens, por lo que no se deben repetir sobre una base ya usada.
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

Estos mensajes **no se envían a Gmail**. Para entrega real, usar un entorno de QA distinto con SMTP y un buzón autorizado: comprobar recepción, abrir su enlace y seguir el recorrido. No cambiar este servidor aislado a SMTP ni usar direcciones reales en la colección. La evidencia SMTP previa de WorkNet se conserva en [SMTP.md](../docs/evidencias/revision-sprint/SMTP.md); no se atribuye a esta ejecución de Postman.

## Ejecutar la misma colección por consola

Con el servidor anterior abierto, en otra terminal desde la raíz:

```powershell
node backend/postman/run.cjs
```

El runner ejecuta las once carpetas en orden y hace las dos lecturas de correo automáticamente entre fases. Exporta IDs y tokens a **su entorno privado**, sin imprimirlos. No añade endpoints ni altera la base para fabricar resultados. Si una fase falla, conserva el informe y detiene las siguientes; no se omiten casos para conseguir un resultado favorable.

Archivos de cada run:

- `resultado-sanitizado.json`: casos, códigos HTTP y comprobaciones, sin cuerpos, encabezados de autenticación ni enlaces firmados. Es el informe apto para publicar.
- `privado-01.json` … `privado-11.json`: informes completos de Newman, **con datos sensibles; no publicar**.
- `local.postman_environment.json`: contraseñas, IDs y tokens de ese run; **no publicar**.
- `qa.sqlite3`, `initial.sqlite3`, `mail/`, `state.json`: base de ejecución, copia inicial y estado privado.

## Repetir desde cero y conservar los resultados

Detén el servidor con **Ctrl+C** en su terminal. Repite:

```powershell
python backend/postman/qa.py prepare --port 8008
python backend/postman/qa.py serve
```

`prepare` restaura el **estado funcional inicial mediante una base nueva**, con las mismas cuentas, actividad y permisos. No borra ni sobrescribe la ejecución anterior. `initial.sqlite3` conserva además su fotografía inicial, pero no hay que copiarla sobre una base abierta. Los tokens, contraseñas y fechas cambian; los resultados funcionales esperados permanecen iguales.

Para repetir en Postman, importa y selecciona el entorno privado **del nuevo run**; vuelve a empezar en 01. Para repetir en consola, usa otra terminal y ejecuta `node backend/postman/run.cjs`. El runner rechaza sobrescribir un informe existente. Si necesitas seleccionar un run concreto: `python backend/postman/qa.py serve --run run-…` y `node backend/postman/run.cjs run-…`.

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

Tres pruebas internas se ejecutaron como apoyo en esta entrega: dos de vencimiento y una de fallos de envío que comprueba rollback del registro y respuesta de recuperación.

```powershell
Push-Location backend
python manage.py test accounts.tests.PasswordRecoveryTests.test_expired_token accounts.test_backend_integration.ConsolidatedBackendTests.test_expired_verification_does_not_activate_the_account --noinput
python manage.py test accounts.test_company_access.CompanyAccessTests.test_registration_send_failure_rolls_back_and_recovery_reports_failure --noinput
Pop-Location
```

El fallo de envío se provoca internamente mediante mock, separado de las peticiones reales de la colección; no acredita una incidencia SMTP real. Tampoco se inventa acceso empresarial autorizado al perfil: esa dependencia sigue pendiente y aquí se comprueba su restricción. Módulos futuros, validación nativa y revisión humana conservan su estado anterior.

La colección usa JSON **v2.1**, importación normal y Newman fijado en `package-lock.json`; no es el formato Native Git v3. Referencias oficiales: [importar en Postman](https://learning.postman.com/docs/getting-started/importing-and-exporting/importing-data/), [valores locales de entorno](https://learning.postman.com/docs/use/send-requests/variables/environment-variables/), [Newman como biblioteca](https://github.com/postmanlabs/newman#using-newman-as-a-library). Si cambias casos, edita `build_collection.py` y vuelve a generar colección y catálogo; conserva y vuelve a ejecutar la evidencia que corresponda.
