# Guía para revisar WorkNet

## Presentación de evidencias HU001–HU015 y regla para HU016–HU027 — 07/11/2026

**Cierre de evidencias comprobado el 08/11/2026.** Los once faltantes de
Postman quedaron resueltos documentalmente. #60 reutiliza tres capturas auténticas
del 24/10/2026; #62 reutiliza esas fuentes y añade la precarga perfil→CV nueva.
Las otras tareas incorporan respuestas seleccionadas y Test Results de la nueva
QA. Se verificaron en GitHub las 63 subtareas: un comentario por tarea, mismos
ID y autores, apartados de alcance/preparación, 215 apariciones de imagen visibles
fuera de históricos y 144 URL de imagen distintas. #84 y #86 permanecen íntegros.
Solo se editaron #60, #62, #76, #77, #79, #81, #83, #85, #87, #89 y #91.
Criterios, estados, responsables, etiquetas, hitos y fechas de cierre se cotejaron
sin cambios; no se alteraron Sprint, fechas ni relaciones de Project.

**Ejecución nueva.** Postman Desktop **12.34.1**, Django **6.1.1**, Python
**3.12.10**; producto servido del árbol funcional
`399caa93b51bc23cc2c6d5a8d05ac21f7a1d9608`. Los commits siguientes de este
bloque solo contienen documentación/evidencias. Las **55 capturas nuevas**
son originales de Desktop, revisadas visualmente; sus URL permanentes en
`94481398738b9f7e43a4e47d7da1cce619253cc0` devolvieron HTTP 200 y los bytes
coincidieron con Git y con la captura inspeccionada. No se publicaron entornos,
contraseñas, tokens, bases, sesiones ni correos. Las imágenes PDF muestran
`PDF File`, estado y PASS del contrato binario; no se presentan como un visor
del interior del documento.

| Conjunto focalizado | Corrida nueva / puerto | Peticiones / PASS | Resultado |
|---|---|---:|---|
| HU012, PM255–PM275 y casos complementarios de descarga/rol | `run-20261108T073316-8bb751d2` / 8092 | 25 / 66 | Sin fallos, errores ni omitidas |
| HU013, catálogos/publicación/empresa pendiente | `run-20261108T073316-3311b183` / 8093 | 3 / 9 | Sin fallos, errores ni omitidas |
| HU014, edición/persistencia/validación/permisos/estados | `run-20261108T073316-cf600cde` / 8094 | 15 / 35 | Sin fallos, errores ni omitidas |
| HU015, transiciones/consultas/permisos/conservación | `run-20261108T073316-a657df23` / 8095 | 15 / 39 | Sin fallos, errores ni omitidas |
| Total nuevo, una iteración por colección | Cuatro bases exclusivas | **58 / 149** | **0 fallos, 0 errores** |

**Preparación reproducible y aislamiento.** Se reutilizaron `qa.py prepare`,
las colecciones existentes HU012/HU013 y los módulos de fixtures HU014/HU015.
La [preparación reproducible](../../backend/docs/evidencias/postman/20261108/preparacion-reproducible.json)
conserva el código exacto del generador local y sus pasos; es evidencia de la
preparación, no código funcional nuevo. Para otro checkout, extraer su campo
`source` al `relative_script_path` indicado y ejecutar el rol con un puerto libre.
Cada invocación crea un run nuevo; después servirlo con `qa.py serve --run RUN_NUEVO`,
importar su colección focalizada y entorno privado y ejecutar una sola iteración
en Desktop, conservando respuestas/variables. Los guards comparan origen local,
puerto e identificador de run exactos antes de enviar. No reutilizar las bases
consumidas de esta evidencia. Las sesiones de preparación se obtuvieron localmente
en Django verificando la contraseña del entorno privado; no se contabilizan como
login Desktop. El nombre de cuenta esperado de HU012 se prepara con QA012-P01;
el CV posterior conserva su independencia de cuenta/perfil. Correo a archivos,
sin SMTP, sin modificar los entornos anteriores. Las postulaciones son fixtures
existentes de dominio: no se implementa HU018.

**Contraste observado.** HU012 conservó el perfil y mantuvo independientes nombre
de cuenta y CV; persistieron certificación y sección adicional. HU013 creó una
sola oferta de la empresa correcta y el rechazo no creó otra. HU014 conservó
identidad, otras ofertas, relaciones y aprobación/revisiones empresariales.
HU015 solo cambió el estado de las ofertas 1/2: ocho ofertas, dos postulaciones
y un guardado conservados. Se detuvieron exclusivamente los cuatro servidores
propios y se comprobaron cerrados 8092–8095. No se repitieron suites completas
válidas para cambiar el formato documental.

[Resultados y versiones](../../backend/docs/evidencias/postman/20261108/resultados-desktop.json) ·
[Capturas y hashes](../../backend/docs/evidencias/postman/20261108/capturas-nuevas.json) ·
[Contrastes de persistencia](../../backend/docs/evidencias/postman/20261108/contrastes-persistencia.json) ·
[Imágenes publicadas verificadas](../../backend/docs/evidencias/postman/20261108/verificacion-imagenes-publicadas.json) ·
[Auditoría de 63 subtareas](../../backend/docs/evidencias/postman/20261108/verificacion-63-subtareas.json).

**Acceso resuelto, atribución e integración.** El usuario completó la carga local
de los recursos en el selector nativo; después el agente ejecutó las cuatro
colecciones, seleccionó las respuestas y capturó Desktop. El fallo de pipe del
07/11 y el bloqueo de importación previo del 08/11 se conservan abajo como
históricos, sin describirlos como impedimentos actuales. Nueva QA, imágenes y
documentación se publican como **francisco3788**, con cuenta, autor y committer
verificados por separado. Los comentarios conservan ID/autor original mediante
edición con su cuenta. Django: **Danilo2334**; Flutter/integración/QA pendiente:
**francisco3788**. La revisión es técnica por agente autorizado; no se atribuyen
revisiones personales ni aprobaciones humanas. Entrega documental por
[PR #161 hacia frontend](https://github.com/Danilo2334/Work_net/pull/161), seguida
del flujo existente mediante PR a main, comprobando que el diff solo contenga
documentación y evidencias y respetando las protecciones.

**Pendientes funcionales conservados.** HU011/HU012/#79 mantienen la selección
del CV al postular pendiente de HU018. HU015/#90/#91 mantienen buscador HU016 y
flujo/API de postulación HU018. Completar las imágenes no cierra esos criterios.
**HU016–HU027 no se iniciaron.** Los cortes y bloqueos anteriores se conservan
como históricos con su fecha y procedencia.

**Qué se hizo en la normalización del 07/11/2026.** Se leyeron completos los comentarios de #29–#33 y se tomó #29
como modelo Flutter, #30/#31 como modelo de API/Postman. Se revisaron las 63
subtareas #29–#91 y sus 15 historias padre, incluidas las abiertas. Se corrigieron
45 comentarios existentes y se conservaron 18 que ya seguían el modelo. #84 no
se editó: mismo ID, contenido, imágenes e histórico. Un comentario de seguimiento
por subtarea; las presentaciones anteriores permanecen en históricos secundarios.
Los resúmenes padre conservan los criterios y enlazan todos sus seguimientos.

**Preparación y comprobaciones de esta edición.** Referencia integrada main
`9a9dfb8dd382c4e910e51ace514cfe186cbe336b`; no había avance posterior de main al
contrastar las referencias remotas. Se cotejaron ID, autor, cuerpo, estado,
responsables y relaciones antes y después. Se verificaron el HTML renderizado
por GitHub y las imágenes fuera de históricos; las 98 referencias de imagen
previstas cargaron por HTTP 200 y sus bytes coincidieron con los archivos
publicados. Son 124 apariciones visibles de 88 imágenes distintas, reutilizadas
en los casos pertinentes, no 124 capturas nuevas. Las referencias originales
adicionales se conservan en sus históricos. La inspección de las imágenes
contrasta legibilidad, caso y ausencia de contraseñas, tokens o sesiones visibles.
No se volvieron a ejecutar suites, no se cambiaron código funcional ni entornos
y no se enviaron correos.

<details>
<summary>Importación pendiente antes de la acción local del 08/11/2026, conservada</summary>

**Actualización documental del 08/11/2026.** El control de la ventana de Postman
Desktop 12.34.1 funciona desde la aplicación Windows. La captura de acceso mostraba
resultados históricos de HU011 y no acredita una ejecución nueva. Para #60 se
recuperaron y revisaron tres capturas específicas del 24/10/2026 que estaban
dentro de su histórico: perfil autorizado (PM214), fotografía privada (PM224)
y empresa ajena (PM219). Sus URL permanentes devolvieron HTTP 200 y los bytes
coincidieron con Git; ahora son visibles en el mismo comentario de #60, conservando
ID, autor e histórico. El faltante de esa tarea queda resuelto por reutilización,
sin repetir la QA. La consulta de perfil y la fotografía de #62 pueden reutilizar
esas fuentes; su contrato perfil→CV y los demás casos siguen pendientes.

Se prepararon cuatro corridas nuevas exclusivas para HU012–HU015 en 8092–8095,
con el preparador existente, credenciales privadas, bases separadas y correo
a archivos. La importación de recursos encuentra una limitación en el diálogo
nativo de carpetas: `point (600, 442) is over Postman.exe "", not target window
Postman.exe "Import"`. Se solicitó pulsar localmente **Cargar**; preparar bases
o importar una colección no cuenta como ejecución Desktop aprobada. La
normalización continúa incompleta hasta obtener y verificar las demás evidencias.


</details>

<details>
<summary>Bloqueo de acceso y once faltantes registrados el 07/11/2026</summary>

**Acceso a Postman Desktop y alcance pendiente en ese corte.** La comprobación de disponibilidad
con `mcp__node_repl__js`, `@oai/sky`, `sky.list_apps` devolvió:
`Computer Use native pipe is unavailable: failed to connect native pipe: El sistema no puede encontrar el archivo especificado. (os error 2)`.
Falta conexión con el helper nativo de Windows. No se pudo abrir una petición QA
ni obtener una nueva captura de Desktop. No se reintentó ese mecanismo ni se
cambió cuenta, plan o workspace. Newman no acredita control de Desktop.
Se reutilizan capturas auténticas existentes; el resumen del Runner no acredita
un cuerpo de respuesta que no muestra. Quedan faltantes concretos en
**#60, #62, #76, #77, #79, #81, #83, #85, #87, #89 y #91**, detallados en la tabla.
La normalización de evidencias **no está completa** mientras falten esas capturas.
Eso no cambia retrospectivamente los estados funcionales.

</details>

**Responsables y atribución.** Danilo2334 conserva backend y los QA históricos
que realmente publicó; francisco3788 conserva Flutter/integración y nuevo
QA/evidencias. Esta reorganización la realiza el agente autorizado, usando la
cuenta del autor original para editar su mismo comentario. Cuenta de publicación,
autor y committer de la aportación de documentación se verifican por separado.
La comprobación personal mínima comunicada por Francisco el 06/11 en #38 y la
recepción SMTP aportada por el usuario conservan su alcance y fecha; no se
atribuyen nuevas revisiones personales ni aprobaciones cruzadas.

**Regla de presentación desde HU016 hasta HU027.** Aplicar este formato al
seguimiento existente de cada subtarea, sin iniciar esas historias en este bloque:

1. Comenzar con **Qué se hizo**, seguido de una explicación breve y específica
   del alcance realizado en esa subtarea. A continuación, **Preparación** con
   entorno, fixtures ficticias, pasos reproducibles, fecha, versiones y límites.
2. Incorporar las imágenes pertinentes directamente mediante
   `![Caso y resultado](URL_PERMANENTE)` antes de cualquier histórico plegado.
   Debajo de cada imagen explicar caso, resultado esperado, resultado obtenido,
   qué demuestra y qué queda pendiente. No usar el mismo resumen como evidencia
   de tareas diferentes. Los enlaces a esta guía no sustituyen las imágenes.
3. Flutter/integración: mostrar recorridos y resultados reales de interfaz,
   distinguir escritorio, móvil web emulado y dispositivo físico, y separar
   respuestas reales de errores inyectados. Backend/QA API: capturas auténticas
   de Postman Desktop con petición, respuesta HTTP y Test Results de los casos
   correspondientes, como #30/#31. Runner general, Newman, terminal o widgets
   conservan su alcance; no se rotulan como otra herramienta ni como cuerpos
   JSON/PDF que no muestran. Una imagen de diálogo previo no demuestra guardado.
4. Reutilizar imágenes válidas conservando fecha, SHA de producto y SHA de
   publicación, distinguiéndolos. Comprobar carga, bytes, legibilidad y el caso
   explicado. No presentar reorganización como ejecución nueva. Si falta una
   evidencia, identificar tarea y caso; si se requiere otra comprobación, usar
   otra base QA aislada, correo a archivos y credenciales del entorno privado.
   No publicar secretos, enlaces de verificación, sesiones ni datos personales.
5. Editar el mismo comentario: conservar ID, autor, responsables, criterios,
   estados, Sprint, fechas y relaciones. Mantener exactamente un seguimiento
   por subtarea y conservar los históricos en una sección secundaria. No borrar
   declaraciones exigidas ni atribuciones originales. Distinguir responsable
   de publicación de quien comunicó una comprobación personal.
6. Verificar primero un ejemplo de interfaz y otro de API en GitHub y después
   comprobar todas las tareas publicadas, no solo archivos locales. Los ejemplos
   de este bloque fueron [#88](https://github.com/Danilo2334/Work_net/issues/88#issuecomment-6713608969)
   y [#60](https://github.com/Danilo2334/Work_net/issues/60#issuecomment-6272924156);
   #60 deja explícito su caso Desktop posterior pendiente. Corregir formato no
   acredita funcionalidad pendiente ni justifica cerrar tareas o simular revisión.

**Fuentes, fechas y versiones de la tabla.** Las claves evitan repetir SHA completos
en cada fila. Las fechas son las de las evidencias, no una ejecución de este bloque.

- **P19:** Postman Desktop del **19/10/2026**, Django `f9e4dea9bd8078170d899b402a537952ad508d53`; capturas publicadas en `8b5e975d630dfaff16d85e383f5041029a738b91`. La versión numérica de Desktop no consta en ese registro.
- **P24:** Postman Desktop **12.33.3**, ejecución histórica del **24/10/2026**, Django `2547c3786bbbe8abcc1b887a3767ba9223c123aa`, QA 8012; capturas específicas publicadas en `d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93`. Consulta PM214, fotografía PM224 y aislamiento PM219 revisados visualmente el 08/11/2026, URL HTTP 200 y bytes cotejados con Git. No se ejecutó de nuevo HU008.
- **N12:** Postman Desktop **12.34.1**, **08/11/2026**, producto `399caa93b51bc23cc2c6d5a8d05ac21f7a1d9608`, corrida `run-20261108T073316-8bb751d2`, 8092: 25 peticiones/66 PASS; capturas en `94481398738b9f7e43a4e47d7da1cce619253cc0`. Precarga, JSON persistido, tres plantillas, PDF y permisos.
- **N13:** Mismas versiones y publicación que N12; corrida `run-20261108T073316-3311b183`, 8093: 3 peticiones/9 PASS. Catálogos, POST 201 y empresa pendiente 403.
- **N14:** Mismas versiones y publicación que N12; corrida `run-20261108T073316-cf600cde`, 8094: 15 peticiones/35 PASS. Edición y reconsulta, invalidez atómica y permisos/estados.
- **N15:** Mismas versiones y publicación que N12; corrida `run-20261108T073316-a657df23`, 8095: 15 peticiones/39 PASS. Transiciones, activas/conservadas, permisos y relaciones. Los cuatro conjuntos nuevos no tuvieron fallos ni errores.
- **F19:** Flutter Web del **19/10/2026**, código `04e7e5cc942c12b234bed4e2809b6c6d72cbaa82`, Django `f9e4dea9bd8078170d899b402a537952ad508d53`; imágenes publicadas en `677aebad368977ca5f7cf96d5ec5b9bc1aac681d`. Móvil web es viewport emulado, no dispositivo físico.
- **P11:** Postman Desktop **12.33.3**, ejecución del **24/10/2026** y capturas conservadas el **25/10/2026**, Django `84746c36efb8ef49e044e2889e677a1f70e9fb25`; imágenes publicadas en `47d5f1ec039d8f18321d8fafe9ff2ed0b2568493`. Consultar el resultado histórico para distinguir la fecha de ejecución de la fecha de captura.
- **F11:** Flutter Web de HU011 del **24–25/10/2026**, backend `84746c36efb8ef49e044e2889e677a1f70e9fb25`; base Flutter registrada `0eb65d495b20157a910ff18e1e68cfaf5d75b7ae` y material publicado en `91207ad37f13f1dd9f647264b48717ae514cb2f7`. La cancelación nativa del 25/10 se identifica por separado; no se atribuye al móvil emulado.
- **F12:** Aceptación de navegador del **07/11/2026**, Flutter y Django de `940f8a917511da833755f24a8071f4849e0dedf0`, Chromium **158.0.8127.18** y Playwright **1.65.0**. Imágenes originales en la entrega hasta HU013, conservadas en main `9a9dfb8`; escritorio y móvil web emulado 390×844, no dispositivo físico.
- **P12:** Postman Desktop **12.35.4**, **06/11/2026**, Django `84746c36efb8ef49e044e2889e677a1f70e9fb25`, material `3959d08385a8fd14161c53216179f3a01e769d42`: 31 solicitudes (4 de preparación y 27 casos), 87 aserciones aprobadas, sin fallos. La imagen es resumen histórico del Runner, no un cuerpo JSON ni un PDF seleccionado.
- **P13:** Postman Desktop **12.35.4**, **06/11/2026**, Django `2f1b2f78e01e5e8da69295c5bca97c51e09fb04b`: 10 solicitudes y 21 aserciones aprobadas. Se conserva el ensayo inicial 15/21 por codificación de la colección, corregida sin cambiar producto. El resumen disponible no muestra el cuerpo de publicación ni el rechazo por aprobación.
- **F14:** Aceptación de navegador del **07/11/2026**, Flutter/suite `6484120a49e58a269f09eb96abeafad1c8babfbd`, Django `344606382c98274edb701627108ed4700430c236`, Chromium **158.0.8127.18** / Playwright **1.65.0**. Capturas de HU014 publicadas en `b0351ec2ef246787bd3869dedc39a8f47b783078`. Móvil web emulado 390×844, no dispositivo físico.
- **F15:** Segunda aceptación de navegador HU015 del **07/11/2026**, Flutter y Django de `8a1d4fc7bd130b0c3f395b5f2868810876f837f5`, Chromium **158.0.8127.18** / Playwright **1.65.0**; publicada en main `9a9dfb8dd382c4e910e51ace514cfe186cbe336b`. Escritorio 1440×1000 y móvil web emulado 390×844; no dispositivo físico.
- **F18/19:** Flutter: capturas del **18/10/2026**, publicadas en `2970dea6ae115177e7d6044ad1f084acf4818730`; regresión del **19/10/2026** con Flutter `04e7e5cc942c12b234bed4e2809b6c6d72cbaa82` / Django `f9e4dea9bd8078170d899b402a537952ad508d53`. El SHA de publicación de las imágenes no se presenta como la versión ejecutada el 18/10: ese registro no declara su SHA exacto de producto.
- **S19:** Recuperación con SMTP del **19/10/2026**, Flutter `04e7e5cc942c12b234bed4e2809b6c6d72cbaa82` / Django `f9e4dea9bd8078170d899b402a537952ad508d53`, QA distinta 55007/8007; imágenes publicadas en `1f0de2b`. La recepción fue aportada por el usuario y se conserva como tal; no se reenvió correo en esta normalización.

**Comprobación de las 63 subtareas.** Los enlaces de la primera columna abren el
comentario existente; la segunda enlaza todas sus imágenes visibles actuales.
«Sin faltante específico identificado» se refiere a esta revisión documental,
no a una nueva prueba funcional. Los pendientes funcionales abiertos se distinguen
de los faltantes de captura. #85/#89 incorporan ahora 16 capturas Desktop específicas cada una; los bloqueos
anteriores se conservan en sus históricos y no son faltantes actuales.

| Tarea / comentario | Imágenes visibles actuales | Procedencia, fecha y versión | Faltantes o bloqueos concretos |
|---|---|---|---|
| [#29](https://github.com/Danilo2334/Work_net/issues/29#issuecomment-6259568713) | 2: [Cuenta creada antes del rol](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/registro-candidato-rol-posterior.png); [Correo duplicado](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/registro-correo-duplicado.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#30](https://github.com/Danilo2334/Work_net/issues/30#issuecomment-6272919540) | 1: [hu001 registro duplicado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu001-registro-duplicado.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#31](https://github.com/Danilo2334/Work_net/issues/31#issuecomment-6272920035) | 2: [hu001 verificacion respuesta](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu001-verificacion-respuesta.png); [hu001 verificacion pruebas](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu001-verificacion-pruebas.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#32](https://github.com/Danilo2334/Work_net/issues/32#issuecomment-6245224132) | 2: [Cuenta creada antes del rol](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/registro-candidato-rol-posterior.png); [Registro y rol confirmados](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/registro-candidato-confirmado.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#33](https://github.com/Danilo2334/Work_net/issues/33#issuecomment-6245223825) | 2: [hu001 registro duplicado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu001-registro-duplicado.png); [hu001 verificacion pruebas](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu001-verificacion-pruebas.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#34](https://github.com/Danilo2334/Work_net/issues/34#issuecomment-6245479135) | 2: [Error de acceso](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/login-error-vigente.png); [Empresa rechazada en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/empresa-rechazada-movil.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#35](https://github.com/Danilo2334/Work_net/issues/35#issuecomment-6272920507) | 1: [hu002 token revocado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu002-token-revocado.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#36](https://github.com/Danilo2334/Work_net/issues/36#issuecomment-6245479333) | 2: [Error de acceso](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/login-error-vigente.png); [Empresa rechazada en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/empresa-rechazada-movil.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#37](https://github.com/Danilo2334/Work_net/issues/37#issuecomment-6260288501) | 2: [Empresa rechazada en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/empresa-rechazada-movil.png); [Dashboard de empresa sin actividad](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/empresa-dashboard-vacio.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#38](https://github.com/Danilo2334/Work_net/issues/38#issuecomment-6245480254) | 2: [hu002 token revocado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu002-token-revocado.png); [empresa rechazada movil](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-rechazada-movil.png) | P19, F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#39](https://github.com/Danilo2334/Work_net/issues/39#issuecomment-6245479481) | 1: [Recuperación confirmada](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/recuperacion-confirmada.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#40](https://github.com/Danilo2334/Work_net/issues/40#issuecomment-6272921015) | 2: [hu003 solicitud](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu003-solicitud.png); [hu003 cambio confirmado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu003-cambio-confirmado.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#41](https://github.com/Danilo2334/Work_net/issues/41#issuecomment-6245479640) | 3: [Recuperación con correo recibido — escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/1f0de2b/frontend/docs/evidencias/correo-real/recuperacion-smtp-escritorio.png); [Recuperación con correo recibido — móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/1f0de2b/frontend/docs/evidencias/correo-real/recuperacion-smtp-movil.png); [Recuperación confirmada](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/recuperacion-confirmada.png) | F19, S19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#42](https://github.com/Danilo2334/Work_net/issues/42#issuecomment-6245480431) | 3: [hu003 solicitud](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu003-solicitud.png); [hu003 cambio confirmado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu003-cambio-confirmado.png); [recuperacion confirmada](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/recuperacion-confirmada.png) | P19, F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#43](https://github.com/Danilo2334/Work_net/issues/43#issuecomment-6245716590) | 2: [Cuenta en escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu004/cuenta-escritorio.png); [Nombre guardado](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu004/nombre-guardado.png) | F18/19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#44](https://github.com/Danilo2334/Work_net/issues/44#issuecomment-6272921535) | 4: [hu004 nombre persistente](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu004-nombre-persistente.png); [hu004 token anterior](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu004-token-anterior.png); [hu004 eliminacion](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu004-eliminacion.png); [hu004 cuenta eliminada 401](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu004-cuenta-eliminada-401.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#45](https://github.com/Danilo2334/Work_net/issues/45#issuecomment-6272922011) | 1: [hu004 preferencia persistente](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu004-preferencia-persistente.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#46](https://github.com/Danilo2334/Work_net/issues/46#issuecomment-6245716821) | 4: [Nombre y sesión actualizados](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu004/nombre-guardado.png); [Preferencia guardada](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu004/preferencias-guardadas.png); [Confirmación móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu004/eliminacion-confirmacion-movil.png); [Resultado de eliminación QA](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu004/eliminacion-completada.png) | F18/19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#47](https://github.com/Danilo2334/Work_net/issues/47#issuecomment-6245479801) | 1: [candidato regresion](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/candidato-regresion.png) | F19 | La tarea sigue abierta por búsqueda HU016, mensajes HU022 e historial HU019. |
| [#48](https://github.com/Danilo2334/Work_net/issues/48#issuecomment-6272922606) | 1: [Resumen del candidato](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975/backend/docs/evidencias/postman/capturas/hu005-resumen.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#49](https://github.com/Danilo2334/Work_net/issues/49#issuecomment-6245479981) | 1: [Regresión del candidato](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/candidato-regresion.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#50](https://github.com/Danilo2334/Work_net/issues/50#issuecomment-6245480602) | 2: [hu005 resumen](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu005-resumen.png); [candidato regresion](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/candidato-regresion.png) | P19, F19 | La tarea sigue abierta por los accesos completos a búsqueda HU016, mensajes HU022 e historial HU019. |
| [#51](https://github.com/Danilo2334/Work_net/issues/51#issuecomment-6260291090) | 2: [empresa dashboard escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-dashboard-escritorio.png); [empresa dashboard movil](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-dashboard-movil.png) | F19 | Continúa abierta por postulantes HU020, mensajes HU022 y estadísticas HU024. HU014/HU015 ya están integradas y dejan de listarse como pendientes de implementación. |
| [#52](https://github.com/Danilo2334/Work_net/issues/52#issuecomment-6272923113) | 1: [Resumen de empresa](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975/backend/docs/evidencias/postman/capturas/hu006-resumen.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#53](https://github.com/Danilo2334/Work_net/issues/53#issuecomment-6260291383) | 2: [empresa dashboard vacio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-dashboard-vacio.png); [HU015 V01 activas escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/hu015-20261107/integracion/HU015-V01-activas-escritorio.png) | F19, F15 | Sigue abierta por navegación a postulantes HU020, mensajes HU022 y estadísticas HU024; la gestión de ofertas HU014/HU015 ya no es un faltante de implementación. |
| [#54](https://github.com/Danilo2334/Work_net/issues/54#issuecomment-6260276785) | 2: [hu006 resumen](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu006-resumen.png); [HU015 V01 activas escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/hu015-20261107/integracion/HU015-V01-activas-escritorio.png) | P19, F15 | Siguen pendientes postulantes HU020, mensajes HU022 y estadísticas HU024. El buscador completo continúa en HU016; esta tarea no se cierra por reorganizar imágenes. |
| [#55](https://github.com/Danilo2334/Work_net/issues/55#issuecomment-6260291727) | 2: [administracion escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/administracion-escritorio.png); [administracion movil](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/administracion-movil.png) | F19 | Sigue abierta por gestión de administradores y permisos HU026. |
| [#56](https://github.com/Danilo2334/Work_net/issues/56#issuecomment-6272923641) | 1: [Resumen administrativo](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975/backend/docs/evidencias/postman/capturas/hu007-resumen.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#57](https://github.com/Danilo2334/Work_net/issues/57#issuecomment-6260292130) | 2: [Dashboard administrativo](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/administracion-escritorio.png); [Administración en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/677aeba/frontend/docs/evidencias/revision-sprint/administracion-movil.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#58](https://github.com/Danilo2334/Work_net/issues/58#issuecomment-6260277494) | 1: [hu007 resumen](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu007-resumen.png) | P19 | La tarea sigue abierta por el recorrido de gestión de administradores y permisos de HU026. |
| [#59](https://github.com/Danilo2334/Work_net/issues/59#issuecomment-6246221677) | 2: [Perfil en escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu008/perfil-completo-escritorio.png); [Registros en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu008/registros-movil.png) | F18/19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#60](https://github.com/Danilo2334/Work_net/issues/60#issuecomment-6272924156) | 6: [Educación editada y recuperada en Postman](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu008-educacion-persistente.png); [Otro candidato no modifica el registro en Postman](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu008-permisos.png); [PNG corrupto rechazado en Postman](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu008-foto-invalida.png); [Consulta autorizada PM214](https://raw.githubusercontent.com/Danilo2334/Work_net/d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93/backend/docs/evidencias/postman/capturas/hu008-seleccion/consulta-autorizada.png); [Fotografía privada PM224](https://raw.githubusercontent.com/Danilo2334/Work_net/d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93/backend/docs/evidencias/postman/capturas/hu008-seleccion/fotografia-privada.png); [Empresa ajena PM219](https://raw.githubusercontent.com/Danilo2334/Work_net/d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93/backend/docs/evidencias/postman/capturas/hu008-seleccion/empresa-ajena.png) | P19, P24 | Sin faltante específico identificado: consulta empresarial y fotografía recuperadas del histórico y verificadas el 08/11/2026; no es una ejecución nueva. |
| [#61](https://github.com/Danilo2334/Work_net/issues/61#issuecomment-6246221840) | 2: [Fotografía guardada](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu008/fotografia-guardada.png); [Archivo inválido](https://raw.githubusercontent.com/Danilo2334/Work_net/2970dea6ae115177e7d6044ad1f084acf4818730/frontend/docs/evidencias/hu008/fotografia-invalida.png) | F18/19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#62](https://github.com/Danilo2334/Work_net/issues/62#issuecomment-6246223309) | 4: [PM214: perfil empresarial autorizado](https://raw.githubusercontent.com/Danilo2334/Work_net/d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93/backend/docs/evidencias/postman/capturas/hu008-seleccion/consulta-autorizada.png); [PM224: fotografía privada](https://raw.githubusercontent.com/Danilo2334/Work_net/d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93/backend/docs/evidencias/postman/capturas/hu008-seleccion/fotografia-privada.png); [PM219: otra empresa rechazada](https://raw.githubusercontent.com/Danilo2334/Work_net/d18bbbdd6359973cca15c9b04e6d7f1bbcab5d93/backend/docs/evidencias/postman/capturas/hu008-seleccion/empresa-ajena.png); [PM255 · #76 · Precargar el CV desde el perfil sin guardarlo: 02-precarga-perfil-pm255](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/02-precarga-perfil-pm255.png) | P24, N12 | Consulta/foto históricas P24 verificadas y contrato perfil→CV nuevo; sin faltante documental específico. |
| [#63](https://github.com/Danilo2334/Work_net/issues/63#issuecomment-6260293510) | 2: [empresa pendiente escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-pendiente-escritorio.png); [empresa logo](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-logo.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#64](https://github.com/Danilo2334/Work_net/issues/64#issuecomment-6272924656) | 1: [Información empresarial persistida](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975/backend/docs/evidencias/postman/capturas/hu009-informacion-persistente.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#65](https://github.com/Danilo2334/Work_net/issues/65#issuecomment-6260293907) | 2: [empresa rechazada movil](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-rechazada-movil.png); [empresa reenvio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/empresa-reenvio.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#66](https://github.com/Danilo2334/Work_net/issues/66#issuecomment-6260278891) | 3: [hu009 informacion persistente](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu009-informacion-persistente.png); [hu010 rechazo notificado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-rechazo-notificado.png); [hu010 aprobacion](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-aprobacion.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#67](https://github.com/Danilo2334/Work_net/issues/67#issuecomment-6260294278) | 2: [solicitudes escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/solicitudes-escritorio.png); [rechazo motivo obligatorio](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/rechazo-motivo-obligatorio.png) | F19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#68](https://github.com/Danilo2334/Work_net/issues/68#issuecomment-6272925177) | 3: [hu010 rechazo notificado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-rechazo-notificado.png); [hu010 aprobacion](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-aprobacion.png); [hu010 version obsoleta](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-version-obsoleta.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#69](https://github.com/Danilo2334/Work_net/issues/69#issuecomment-6260294733) | 2: [aprobacion confirmacion](https://raw.githubusercontent.com/Danilo2334/Work_net/677aebad368977ca5f7cf96d5ec5b9bc1aac681d/frontend/docs/evidencias/revision-sprint/aprobacion-confirmacion.png); [hu010 rechazo notificado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-rechazo-notificado.png) | F19, P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#70](https://github.com/Danilo2334/Work_net/issues/70#issuecomment-6260279554) | 2: [hu010 rechazo notificado](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-rechazo-notificado.png); [hu010 version obsoleta](https://raw.githubusercontent.com/Danilo2334/Work_net/8b5e975d630dfaff16d85e383f5041029a738b91/backend/docs/evidencias/postman/capturas/hu010-version-obsoleta.png) | P19 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#71](https://github.com/Danilo2334/Work_net/issues/71#issuecomment-6393908663) | 2: [02 carga confirmada](https://raw.githubusercontent.com/Danilo2334/Work_net/91207ad37f13f1dd9f647264b48717ae514cb2f7/frontend/docs/evidencias/hu011/02-carga-confirmada.png); [10 movil visor](https://raw.githubusercontent.com/Danilo2334/Work_net/91207ad37f13f1dd9f647264b48717ae514cb2f7/frontend/docs/evidencias/hu011/10-movil-visor.png) | F11 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#72](https://github.com/Danilo2334/Work_net/issues/72#issuecomment-6393909036) | 3: [02 carga pdf valido](https://raw.githubusercontent.com/Danilo2334/Work_net/47d5f1ec039d8f18321d8fafe9ff2ed0b2568493/backend/docs/evidencias/hu011/02-carga-pdf-valido.png); [07 candidato ajeno](https://raw.githubusercontent.com/Danilo2334/Work_net/47d5f1ec039d8f18321d8fafe9ff2ed0b2568493/backend/docs/evidencias/hu011/07-candidato-ajeno.png); [10 candidato sin verificar](https://raw.githubusercontent.com/Danilo2334/Work_net/47d5f1ec039d8f18321d8fafe9ff2ed0b2568493/backend/docs/evidencias/hu011/10-candidato-sin-verificar.png) | P11 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#73](https://github.com/Danilo2334/Work_net/issues/73#issuecomment-6393908849) | 2: [04 pdf reemplazado](https://raw.githubusercontent.com/Danilo2334/Work_net/91207ad37f13f1dd9f647264b48717ae514cb2f7/frontend/docs/evidencias/hu011/04-pdf-reemplazado.png); [07 persistencia recarga](https://raw.githubusercontent.com/Danilo2334/Work_net/91207ad37f13f1dd9f647264b48717ae514cb2f7/frontend/docs/evidencias/hu011/07-persistencia-recarga.png) | F11 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#74](https://github.com/Danilo2334/Work_net/issues/74#issuecomment-6393909202) | 3: [04 reemplazo persistido](https://raw.githubusercontent.com/Danilo2334/Work_net/47d5f1ec039d8f18321d8fafe9ff2ed0b2568493/backend/docs/evidencias/hu011/04-reemplazo-persistido.png); [05 pdf corrupto](https://raw.githubusercontent.com/Danilo2334/Work_net/47d5f1ec039d8f18321d8fafe9ff2ed0b2568493/backend/docs/evidencias/hu011/05-pdf-corrupto.png); [08 eliminacion persistida](https://raw.githubusercontent.com/Danilo2334/Work_net/47d5f1ec039d8f18321d8fafe9ff2ed0b2568493/backend/docs/evidencias/hu011/08-eliminacion-persistida.png) | P11, F11 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#75](https://github.com/Danilo2334/Work_net/issues/75#issuecomment-6677450277) | 2: [HU012 V04 plantilla](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU012-V04-plantilla.png); [HU012 V05 salida](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU012-V05-salida.png) | F12 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#76](https://github.com/Danilo2334/Work_net/issues/76#issuecomment-6677473873) | 8: [PM262 · #76 · Consultar nuevamente conserva el CV guardado: 01-reconsulta-json-pm262](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/01-reconsulta-json-pm262.png); [PM258 · #76 · Guardar el CV precargado con plantilla Clásica: 04-guardar-json-pm258](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/04-guardar-json-pm258.png); [PM259 · #76 · Cambiar a plantilla moderna sin perder datos: 05-plantilla-moderna-pm259](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/05-plantilla-moderna-pm259.png); [PM260 · #76 · Cambiar a plantilla minimalista sin perder datos: 07-plantilla-minimalista-pm260](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/07-plantilla-minimalista-pm260.png); [PM263 · #76 · Editar datos personales, resumen y secciones opcionales: 09-edicion-secciones-pm263](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/09-edicion-secciones-pm263.png); [PM263 · #76 · Editar datos personales, resumen y secciones opcionales: 10-certificacion-extra-pm263](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/10-certificacion-extra-pm263.png); [PM271 · #76 · Plantilla desconocida rechazada: 18-plantilla-invalida-pm271](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/18-plantilla-invalida-pm271.png); [PM275 · #79 · Errores no destruyen el CV guardado: 19-reconsulta-tras-errores-pm275](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/19-reconsulta-tras-errores-pm275.png) | N12 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#77](https://github.com/Danilo2334/Work_net/issues/77#issuecomment-6677474163) | 10: [DOC12 PDF guardado moderna: 06-descarga-moderna](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/06-descarga-moderna.png); [DOC12 PDF guardado minimalista: 08-descarga-minimalista](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/08-descarga-minimalista.png); [PM265 · #77 · Generar PDF de vista previa clasica: 11-previa-clasica-pm265](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/11-previa-clasica-pm265.png); [PM266 · #77 · Generar PDF de vista previa moderna: 12-previa-moderna-pm266](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/12-previa-moderna-pm266.png); [PM267 · #77 · Generar PDF de vista previa minimalista: 13-previa-minimalista-pm267](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/13-previa-minimalista-pm267.png); [PM268 · #77 · Descargar el PDF del CV guardado: 14-descarga-clasica-pm268](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/14-descarga-clasica-pm268.png); [PM268 · #77 · Descargar el PDF del CV guardado: 15-descarga-headers-pm268](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/15-descarga-headers-pm268.png); [PM269 · #77 · Descarga sin sesión rechazada: 16-sin-sesion-pm269](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/16-sin-sesion-pm269.png); [PM270 · #77 · Otra cuenta no descarga el CV ajeno: 17-otra-cuenta-pm270](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/17-otra-cuenta-pm270.png); [DOC12 Descarga empresa rechazada: 20-empresa-rechazada](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/20-empresa-rechazada.png) | N12 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#78](https://github.com/Danilo2334/Work_net/issues/78#issuecomment-6677451237) | 2: [HU012 V12 reentrada](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU012-V12-reentrada.png); [HU012 V07 pdf movil](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU012-V07-pdf-movil.png) | F12 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#79](https://github.com/Danilo2334/Work_net/issues/79#issuecomment-6677474473) | 13: [PM255 · #76 · Precargar el CV desde el perfil sin guardarlo: 02-precarga-perfil-pm255](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/02-precarga-perfil-pm255.png); [PM258 · #76 · Guardar el CV precargado con plantilla Clásica: 04-guardar-json-pm258](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/04-guardar-json-pm258.png); [DOC12 PDF guardado moderna: 06-descarga-moderna](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/06-descarga-moderna.png); [DOC12 PDF guardado minimalista: 08-descarga-minimalista](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/08-descarga-minimalista.png); [PM263 · #76 · Editar datos personales, resumen y secciones opcionales: 10-certificacion-extra-pm263](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/10-certificacion-extra-pm263.png); [PM265 · #77 · Generar PDF de vista previa clasica: 11-previa-clasica-pm265](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/11-previa-clasica-pm265.png); [PM266 · #77 · Generar PDF de vista previa moderna: 12-previa-moderna-pm266](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/12-previa-moderna-pm266.png); [PM267 · #77 · Generar PDF de vista previa minimalista: 13-previa-minimalista-pm267](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/13-previa-minimalista-pm267.png); [PM268 · #77 · Descargar el PDF del CV guardado: 14-descarga-clasica-pm268](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/14-descarga-clasica-pm268.png); [PM269 · #77 · Descarga sin sesión rechazada: 16-sin-sesion-pm269](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/16-sin-sesion-pm269.png); [PM270 · #77 · Otra cuenta no descarga el CV ajeno: 17-otra-cuenta-pm270](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/17-otra-cuenta-pm270.png); [PM275 · #79 · Errores no destruyen el CV guardado: 19-reconsulta-tras-errores-pm275](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/19-reconsulta-tras-errores-pm275.png); [DOC12 Descarga empresa rechazada: 20-empresa-rechazada](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu012/20-empresa-rechazada.png) | N12 | Sin faltante documental específico. HU018: seleccionar el CV al postular continúa pendiente; #79/HU012 conservan ese criterio abierto. |
| [#80](https://github.com/Danilo2334/Work_net/issues/80#issuecomment-6679336067) | 2: [HU013 V01 formulario](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU013-V01-formulario.png); [HU013 V04 salario](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU013-V04-salario.png) | F12 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#81](https://github.com/Danilo2334/Work_net/issues/81#issuecomment-6679337039) | 3: [HU013-02 Catalogos: 01-catalogos](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu013/01-catalogos.png); [HU013-03 Publicar oferta: 02-publicacion-201](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu013/02-publicacion-201.png); [HU013-09 Empresa pendiente rechazada: 03-empresa-pendiente-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu013/03-empresa-pendiente-403.png) | N13 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#82](https://github.com/Danilo2334/Work_net/issues/82#issuecomment-6679338031) | 3: [HU013 V05 confirmacion](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU013-V05-confirmacion.png); [HU013 V05 dashboard 3](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU013-V05-dashboard-3.png); [HU013 V07 red borrador](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/retoma-20261107/integracion/HU013-V07-red-borrador.png) | F12 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#83](https://github.com/Danilo2334/Work_net/issues/83#issuecomment-6679338987) | 3: [HU013-02 Catalogos: 01-catalogos](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu013/01-catalogos.png); [HU013-03 Publicar oferta: 02-publicacion-201](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu013/02-publicacion-201.png); [HU013-09 Empresa pendiente rechazada: 03-empresa-pendiente-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu013/03-empresa-pendiente-403.png) | N13 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#84](https://github.com/Danilo2334/Work_net/issues/84#issuecomment-6713011975) | 2: [Oferta editada y reconsultada en escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/b0351ec2ef246787bd3869dedc39a8f47b783078/frontend/docs/evidencias/hu014-20261107/HU014-V04-persistencia.png); [Oferta editada y reconsultada en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/b0351ec2ef246787bd3869dedc39a8f47b783078/frontend/docs/evidencias/hu014-20261107/HU014-V05-persistencia-movil.png) | F14 | Conservado íntegramente por instrucción: ID, imágenes e histórico sin edición. |
| [#85](https://github.com/Danilo2334/Work_net/issues/85#issuecomment-6713013329) | 16: [D14-01 Listado propio activo: 01-listado-activo](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/01-listado-activo.png); [D14-01 Listado propio activo: 01b-listado-propietarios-estados](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/01b-listado-propietarios-estados.png); [D14-02 Precarga: 02-precarga](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/02-precarga.png); [D14-03 PATCH siete campos: 03-patch-valido](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/03-patch-valido.png); [D14-04 Reconsulta persistida: 04-reconsulta-persistida](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/04-reconsulta-persistida.png); [D14-05 Inválidos sin escritura: 05-invalido-400](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/05-invalido-400.png); [D14-06 Reconsulta tras inválidos: 06-sin-escritura-parcial](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/06-sin-escritura-parcial.png); [D14-07 Sin sesión: 07-sin-sesion-401](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/07-sin-sesion-401.png); [D14-08 Candidato: 08-candidato-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/08-candidato-403.png); [D14-09 Empresa pendiente: 09-empresa-pendiente-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/09-empresa-pendiente-403.png); [D14-10 Oferta ajena: 10-oferta-ajena-404](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/10-oferta-ajena-404.png); [D14-11 PATCH ajeno: 11-patch-ajeno-404](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/11-patch-ajeno-404.png); [D14-12 Archivada: 12-archivada-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/12-archivada-409.png); [D14-13 Cerrada: 13-cerrada-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/13-cerrada-409.png); [D14-14 Borrador: 14-borrador-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/14-borrador-409.png); [D14-15 Vencida: 15-vencida-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/15-vencida-409.png) | N14 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#86](https://github.com/Danilo2334/Work_net/issues/86#issuecomment-6713014288) | 2: [HU014 V04 persistencia](https://raw.githubusercontent.com/Danilo2334/Work_net/b0351ec2ef246787bd3869dedc39a8f47b783078/frontend/docs/evidencias/hu014-20261107/HU014-V04-persistencia.png); [HU014 V08 red borrador](https://raw.githubusercontent.com/Danilo2334/Work_net/b0351ec2ef246787bd3869dedc39a8f47b783078/frontend/docs/evidencias/hu014-20261107/HU014-V08-red-borrador.png) | F14 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#87](https://github.com/Danilo2334/Work_net/issues/87#issuecomment-6713015077) | 16: [D14-01 Listado propio activo: 01-listado-activo](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/01-listado-activo.png); [D14-01 Listado propio activo: 01b-listado-propietarios-estados](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/01b-listado-propietarios-estados.png); [D14-02 Precarga: 02-precarga](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/02-precarga.png); [D14-03 PATCH siete campos: 03-patch-valido](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/03-patch-valido.png); [D14-04 Reconsulta persistida: 04-reconsulta-persistida](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/04-reconsulta-persistida.png); [D14-05 Inválidos sin escritura: 05-invalido-400](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/05-invalido-400.png); [D14-06 Reconsulta tras inválidos: 06-sin-escritura-parcial](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/06-sin-escritura-parcial.png); [D14-07 Sin sesión: 07-sin-sesion-401](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/07-sin-sesion-401.png); [D14-08 Candidato: 08-candidato-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/08-candidato-403.png); [D14-09 Empresa pendiente: 09-empresa-pendiente-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/09-empresa-pendiente-403.png); [D14-10 Oferta ajena: 10-oferta-ajena-404](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/10-oferta-ajena-404.png); [D14-11 PATCH ajeno: 11-patch-ajeno-404](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/11-patch-ajeno-404.png); [D14-12 Archivada: 12-archivada-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/12-archivada-409.png); [D14-13 Cerrada: 13-cerrada-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/13-cerrada-409.png); [D14-14 Borrador: 14-borrador-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/14-borrador-409.png); [D14-15 Vencida: 15-vencida-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu014/15-vencida-409.png) | N14 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#88](https://github.com/Danilo2334/Work_net/issues/88#issuecomment-6713608969) | 2: [Confirmación de archivado en escritorio](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/hu015-20261107/integracion/HU015-V02-confirmacion-archivar.png); [Confirmación de archivado en móvil web](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/hu015-20261107/integracion/HU015-V05-confirmacion-movil.png) | F15 | Sin faltante específico identificado; se conserva el alcance histórico. |
| [#89](https://github.com/Danilo2334/Work_net/issues/89#issuecomment-6713609559) | 16: [D15-01 Activas iniciales: 01-activas-iniciales](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/01-activas-iniciales.png); [D15-02 Conservadas iniciales: 02-conservadas-iniciales](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/02-conservadas-iniciales.png); [D15-03 Archivado sin confirmar: 03-confirmacion-invalida-400](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/03-confirmacion-invalida-400.png); [D15-04 Sin cambio tras inválido: 04-invalido-sin-cambio](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/04-invalido-sin-cambio.png); [D15-05 Cierre válido: 05-cierre-200](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/05-cierre-200.png); [D15-06 Archivado confirmado: 06-archivado-200](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/06-archivado-200.png); [D15-07 Activas tras transiciones: 07-activas-exclusion](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/07-activas-exclusion.png); [D15-08 Historial conservado: 08-historial-count](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/08-historial-count.png); [D15-08 Historial conservado: 08b-historial-estados](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/08b-historial-estados.png); [D15-09 Transición incompatible: 09-transicion-incompatible-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/09-transicion-incompatible-409.png); [D15-10 Oferta ajena: 10-oferta-ajena-404](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/10-oferta-ajena-404.png); [D15-11 Sin sesión: 11-sin-sesion-401](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/11-sin-sesion-401.png); [D15-12 Candidato: 12-candidato-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/12-candidato-403.png); [D15-13 Empresa pendiente: 13-empresa-pendiente-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/13-empresa-pendiente-403.png); [D15-14 Reintento idempotente: 14-reintento-idempotente](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/14-reintento-idempotente.png); [D15-15 Relaciones del dashboard: 15-relaciones-dashboard](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/15-relaciones-dashboard.png) | N15 | Sin faltante documental específico; evidencia Desktop nueva del 08/11/2026 verificada. |
| [#90](https://github.com/Danilo2334/Work_net/issues/90#issuecomment-6713610102) | 2: [HU015 V03 cerrada excluida](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/hu015-20261107/integracion/HU015-V03-cerrada-excluida.png); [HU015 V04 archivada persistida](https://raw.githubusercontent.com/Danilo2334/Work_net/9a9dfb8dd382c4e910e51ace514cfe186cbe336b/frontend/docs/evidencias/hu015-20261107/integracion/HU015-V04-archivada-persistida.png) | F15 | Continúa abierta: falta integrar/acreditar exclusión en el buscador completo de HU016, aún inexistente. HU018 mantiene pendiente el recorrido completo de postulación en #16/#91. |
| [#91](https://github.com/Danilo2334/Work_net/issues/91#issuecomment-6713610614) | 16: [D15-01 Activas iniciales: 01-activas-iniciales](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/01-activas-iniciales.png); [D15-02 Conservadas iniciales: 02-conservadas-iniciales](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/02-conservadas-iniciales.png); [D15-03 Archivado sin confirmar: 03-confirmacion-invalida-400](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/03-confirmacion-invalida-400.png); [D15-04 Sin cambio tras inválido: 04-invalido-sin-cambio](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/04-invalido-sin-cambio.png); [D15-05 Cierre válido: 05-cierre-200](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/05-cierre-200.png); [D15-06 Archivado confirmado: 06-archivado-200](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/06-archivado-200.png); [D15-07 Activas tras transiciones: 07-activas-exclusion](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/07-activas-exclusion.png); [D15-08 Historial conservado: 08-historial-count](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/08-historial-count.png); [D15-08 Historial conservado: 08b-historial-estados](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/08b-historial-estados.png); [D15-09 Transición incompatible: 09-transicion-incompatible-409](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/09-transicion-incompatible-409.png); [D15-10 Oferta ajena: 10-oferta-ajena-404](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/10-oferta-ajena-404.png); [D15-11 Sin sesión: 11-sin-sesion-401](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/11-sin-sesion-401.png); [D15-12 Candidato: 12-candidato-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/12-candidato-403.png); [D15-13 Empresa pendiente: 13-empresa-pendiente-403](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/13-empresa-pendiente-403.png); [D15-14 Reintento idempotente: 14-reintento-idempotente](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/14-reintento-idempotente.png); [D15-15 Relaciones del dashboard: 15-relaciones-dashboard](https://raw.githubusercontent.com/Danilo2334/Work_net/94481398738b9f7e43a4e47d7da1cce619253cc0/backend/docs/evidencias/postman/20261108/hu015/15-relaciones-dashboard.png) | N15 | Sin faltante documental específico. HU016: buscador completo; HU018: postulación. HU015/#90/#91 conservan esas dependencias abiertas. |

**Seguimiento funcional conservado.** HU005/HU006/HU007 mantienen sus dependencias
de módulos futuros; HU013/HU014 y el alcance existente de HU015 están integrados.
HU011/HU012/#79 continúan abiertos por selección del CV al postular (HU018).
HU015/#90/#91 continúan abiertos por buscador completo HU016 y postulación HU018;
la regla ORM y las consultas actuales no acreditan esos recorridos inexistentes.
No se iniciaron HU016–HU027 ni se cerraron tareas durante esta normalización.

## HU015: cierre y archivado de ofertas — 07/11/2026

**Alcance y responsables.** HU015 #16 asignada a ambos integrantes. #89 backend:
Danilo2334; #88 acciones, #90 integración y #91 QA/evidencias: francisco3788.
Base main `b0351ec`, sin avances posteriores al iniciar; checkouts nuevos y
entornos anteriores conservados. Revisión técnica delegada al agente por el
titular; publicación con las identidades indicadas, sin atribuir comprobaciones
personales ni aprobaciones humanas a integrantes.

**Preparación y pasos.** Empresa aprobada → Mis ofertas activas. Cerrar oferta
explica sus efectos y pide confirmación. Archivar oferta exige confirmación;
Cancelar no envía la transición. Ver ofertas conservadas permite consultar
cerradas/archivadas, su información y estado; no se ofrece edición ni reapertura.
La ruta de conservadas persiste al recargar. Las acciones preservan ID,
propietario, información, postulaciones y guardados; no requieren nueva aprobación.
Ante errores se conserva la oferta y se pide reconsultar antes de repetir.
La API acepta reintentos al mismo estado sin duplicar ni reabrir.

**Automatización reutilizable.** Otra corrida nueva con el preparador existente,
SQLite y venv exclusivos, Chromium temporal y correo a archivos. Fixtures
ficticias solo tras validar el guard; acciones mediante la interfaz, contraste
de persistencia/relaciones y revocación de sesión mediante el puente QA privado.
Credenciales del entorno privado, sin SMTP, perfiles personales, trazas, HAR,
storageState ni registros de autenticación. Dependencias fijadas en requirements
y lockfile; Node 20+, Python 3.12+ y Flutter como en los apartados existentes.

```powershell
git fetch origin
python frontend/tool/browser_qa/run.py --suite hu015 --backend-ref origin/feature/hu015-estados
```

En la entrega integrada, usar `--backend-ref HEAD` y ejecutar desde ese checkout.
El ejecutor exporta únicamente commits, crea otros puertos y rechaza una base
consumida. Las corridas y credenciales quedan privadas en `.git/worknet-browser-qa`.
HU015 añade cancelación, cierre/archivado persistidos, exclusión activa,
conservación de historial, errores, sesión y regresión de publicación/edición.
Móvil web emulado a 390×844 con ratón/teclado; no dispositivo físico.

**Resultados y pruebas.** API `79d45e30422f0973a86e53e34919f071895c1499` y Flutter/suite
`fd5ad27695c231131ea1f73dffeb5e837cccd446`: 159 Django, 124 Flutter y 12 guards aprobados;
análisis limpio, sintaxis Node y compilación JavaScript release correctos.
Migraciones aplicadas en otra QA, sin pendientes ni cambios de modelos.
18 casos de navegador (login y 17 HU015) aprobados, 26 capturas originales.
Chromium 158.0.8127.18 / Playwright 1.65.0, escritorio 1440×1000 y móvil web
390×844 emulado. Los cambios posteriores de esta aportación solo documentan
el resultado; no se atribuye una prueba de dispositivo físico.

Se conservaron la información y relaciones de las ocho ofertas iniciales:
solo cambiaron los estados de las seleccionadas. Las dos postulaciones y el
guardado permanecen intactos, así como aprobación y revisiones empresariales;
las ofertas ajenas/no seleccionadas, el perfil y la cuenta de origen no cambian.
Una novena oferta se publicó y editó por la interfaz para regresión HU013/HU014,
con reconsulta y recarga. Las cerradas/archivadas desaparecen de las consultas
activas y su edición recibe 409. Las pruebas Django comprueban los permisos,
ofertas ajenas 404, transiciones inválidas, confirmación inválida sin escrituras,
paginación, historial consultable y bloqueo de creación individual/masiva de
postulaciones en inactivas. Esta última comprobación es del dominio actual;
no existe aún la API/pantalla de HU018.

V07–V11 usan abortos y 400/503 **inyectados** y comprueban que no cambia la base.
V14 realiza un POST real, comprueba 200 de Django, descarta su respuesta y
verifica el estado persistido; repetir desde UI devuelve 200 sin duplicar ni
reabrir. V16/V17 reciben 403/401 reales de la QA. Tras revocar el token de
prueba, el login queda vacío y volver atrás no muestra ofertas protegidas.
El navegador y los dos servicios propios se cerraron; reutilizar la corrida
consumida fue rechazado sin modificar la base. Credenciales, sesiones y entornos
permanecen privados. [Resultado, respuestas sanitizadas y hashes](evidencias/hu015-20261107/resultados.json).

Se inspeccionaron directamente estas siete imágenes; las otras se conservan
junto al resultado y están asociadas a las aserciones de los 18 casos:

| Captura | Resultado comprobado |
|---|---|
| [V02 confirmación](evidencias/hu015-20261107/HU015-V02-confirmacion-archivar.png) | Identifica oferta y efectos; cancelar no envía POST ni cambia la base |
| [V03 cierre](evidencias/hu015-20261107/HU015-V03-cerrada-excluida.png) | Confirmación y dos activas restantes; la cerrada desaparece |
| [V04 conservadas](evidencias/hu015-20261107/HU015-V04-archivada-persistida.png) | Cerradas/archivadas con información después de recargar, sin edición |
| [V05 móvil](evidencias/hu015-20261107/HU015-V05-conservadas-movil.png) | Listado de conservadas legible en móvil web; archivado directo persistido |
| [V07 red](evidencias/hu015-20261107/HU015-V07-red-cierre.png) | Error visible, oferta conservada y acción recuperable mediante consulta |
| [V14 reintento](evidencias/hu015-20261107/HU015-V14-reintento-idempotente.png) | Cierre confirmado tras perder la primera respuesta real, sin duplicados |
| [V17 sesión](evidencias/hu015-20261107/HU015-V17-sesion-401.png) | 401 real; login sin credenciales y sin escritura de la transición |

**Hallazgos y procedencia.** La revisión reprodujo una reasignación de postulación
mediante `bulk_create(update_conflicts=True)`; se rechaza ese modo y la nueva
prueba pasa dentro de las 159 Django. Se conserva el ensayo de navegador
`0d47453`/`149de96`, fallido en V13: las fixtures usaban fechas ISO con T y
alteraban el orden frente a las fechas SQLite de Django; se normalizó el
preparador en `fd5ad27`. No se presenta ese fallo QA como defecto de producto.
Fechas/versiones del ensayo y de la corrida aprobada constan en el JSON.

**Revisión e integración.** [#156 backend](https://github.com/Danilo2334/Work_net/pull/156)
y [#157 Flutter/QA](https://github.com/Danilo2334/Work_net/pull/157). Se verificaron
contratos, permisos, bloqueos de empresa/oferta, conservación de relaciones,
sesión/navegación y aislamiento del ejecutor. Flujo: API→backend-sprint-3→develop;
Flutter→frontend; backend revisado→entrega→frontend; verificar otra corrida QA
del conjunto antes de main. Los PR y el comentario único de cada subtarea
registran las cabeceras y SHA resultantes. Sin modificar protecciones ni bypass.
Autor, committer y cuenta de publicación se verifican por separado; las fusiones
del servidor conservan committer GitHub. Contrato y pruebas backend en
[COMPANY_API.md](../../backend/accounts/COMPANY_API.md#hu015-cierre-y-archivado-sin-eliminar-historial--07112026).

**Verificación de la entrega combinada.** Tras #156→backend-sprint-3,
[#158→develop](https://github.com/Danilo2334/Work_net/pull/158) y #157→frontend,
se incorporó el backend en `8a1d4fc7bd130b0c3f395b5f2868810876f837f5`.
Su backend coincide con `79d45e3` y su Flutter con `abc496d` (código de `fd5ad27`).
Otra ejecución de `--suite hu015 --backend-ref HEAD` exportó ambos componentes
de ese mismo commit: **18/18 aprobados y otras 26 capturas**. Son los mismos 18
casos repetidos en otra base, no 36 casos distintos. Preparador y dependencias
desde Git, venv/SQLite/Chromium/puertos nuevos, compilación release y migración
desde cero, correo a archivos. Las comprobaciones técnicas válidas anteriores
se reutilizan al coincidir los árboles funcionales; no se repite una auditoría general.

[Resultados integrados, versiones, respuestas y hashes](evidencias/hu015-20261107/integracion/resultados.json).
La primera evidencia permanece intacta con sus fechas y fuentes. En esta segunda
se inspeccionaron directamente [V03 cierre y exclusión](evidencias/hu015-20261107/integracion/HU015-V03-cerrada-excluida.png),
[V05 confirmación en móvil web](evidencias/hu015-20261107/integracion/HU015-V05-confirmacion-movil.png)
y [V17 sesión vencida](evidencias/hu015-20261107/integracion/HU015-V17-sesion-401.png):
confirman presentación del resultado, efectos/cancelación accesibles y login vacío.
La persistencia y conservación de datos/relaciones se contrastan además con Django.
Se rechazó reutilizar la corrida consumida sin cambiar su base y se comprobaron
cerrados los servicios propios. Ninguna credencial, sesión ni base se publica.

La integración conjunta se entrega por [#159](https://github.com/Danilo2334/Work_net/pull/159)
y la cabecera resultante se coteja antes de [#160 hacia main](https://github.com/Danilo2334/Work_net/pull/160).
Los cambios posteriores a `8a1d4fc` solo agregan documentación y esta segunda
evidencia, comprobados por diff. Los PR y comentarios de seguimiento registran
los SHA remotos definitivos y los cierres únicamente después de verificarlos.
Backend publicado como Danilo2334; Flutter/integración/QA como francisco3788.
La revisión es técnica y delegada; no se registran aprobaciones personales.

**Criterios pendientes reales.** HU016 no tiene buscador completo y HU018 no
tiene API/pantalla de postulación. Se verifica la exclusión de las consultas
activas existentes y el bloqueo de escrituras `Application` (creación individual
y por lotes), conservando las relaciones; no se presenta como recorrido de
postulación ni de búsqueda completo. #16/#90/#91 mantienen esos criterios
pendientes hasta acreditar las dependencias. HU011/HU012/#79 siguen abiertos
por selección de CV en HU018. No se inicia HU016–HU027. Los siguientes apartados
son históricos y conservan fechas, versiones y procedencia.

## HU014: edición de ofertas propias activas — 07/11/2026

**Alcance y responsables.** #84 pantalla, #86 integración y #87 nuevo QA/evidencias:
francisco3788. #85 API: Danilo2334. HU014 pertenece a ambos. Se parte de main
`15833c8`, sin avances posteriores al iniciar; la rama backend conserva el mismo
árbol backend y el flujo backend-sprint-3→develop. Los checkouts y entornos
anteriores se conservan. La revisión técnica está delegada por el titular al
agente; no se atribuyen revisiones personales ni aprobaciones humanas.

**Preparación y pasos.** Empresa aprobada → Mis ofertas activas → Editar oferta.
Se precargan título, descripción, requisitos, salario, ubicación, categoría y
contrato. Guardar cambios confirma la actualización; volver al listado, abrir y
recargar permite consultar lo persistido. La consulta paginada solo da soporte a
esa edición. Activa comparte el filtro del dashboard: publicada y no vencida.
No hay cierre ni archivado de HU015.

El ejecutor versionado añade `--suite hu014`, con otra SQLite, venv y Chromium
temporales y correo a archivos. Reutiliza el preparador existente; sus fixtures
añaden ofertas ajenas, archivadas, cerradas, borradores y vencidas solo después
del guard de una base nueva. Editar/guardar se hace por la interfaz; SQL se usa
para fixtures, contraste y revocación QA de sesión. Credenciales únicamente del
entorno privado. No se conectan perfiles personales ni se reutilizan corridas.

Mientras las ramas están separadas:

```powershell
git fetch origin
python frontend/tool/browser_qa/run.py --suite hu014 --backend-ref origin/feature/hu014-api
```

En la entrega integrada ambos componentes se toman del HEAD confirmado:

```powershell
python frontend/tool/browser_qa/run.py --suite hu014
```

**Resultados y pruebas.** Fuente API `344606382c98274edb701627108ed4700430c236`
y Flutter/suite `6484120a49e58a269f09eb96abeafad1c8babfbd`. Los cambios siguientes
solo documentan esta ejecución. Pasaron 150 pruebas Django, 120 Flutter y 10
guards, sintaxis Node, análisis y compilación web JavaScript release. No hay
migraciones nuevas ni pendientes; la nueva base QA se migró antes de los casos.
La suite aprobó 16 casos (login más 15 HU014) y produjo 21 capturas originales.
Chromium 158.0.8127.18 / Playwright 1.65.0; escritorio 1440×1000 y móvil web
390×844 con ratón/teclado, sin dispositivo físico. No se ejecutaron binarios nativos.

Identidad, empresa, fechas, estado y relaciones de la oferta conservados;
otras ofertas intactas y aprobación/revisiones empresariales sin cambios.
El perfil/cuenta de origen también se conservaron. Las filas ajenas y los
estados no editables solo se prepararon como fixtures; no se creó ninguna
acción de cierre/archivado. Guardado y edición se ejecutaron mediante UI.
Los abortos de red y 400/503 están identificados como inyectados; los 200,
401, 403, 404 y 409 proceden del Django QA real. Ningún error probado guardó
parcialmente el borrador. El servidor y navegador propios se cerraron; un
intento de reiniciar la corrida consumida fue rechazado sin cambiar su SQLite.
Contraseñas, sesiones, manifest, bases y entornos permanecen privados.

[Resultados, respuestas sanitizadas y hashes de todas las capturas](evidencias/hu014-20261107/resultados.json).
Se inspeccionaron directamente las imágenes enlazadas en esta tabla; las demás
se conservan junto al resultado y las aserciones de UI cubren los 16 casos.

| Caso / captura | Comprobación |
|---|---|
| [V01 listado](evidencias/hu014-20261107/HU014-V01-ofertas-propias.png) | Solo dos ofertas propias activas; ajenas y no editables ausentes |
| [V02 precarga](evidencias/hu014-20261107/HU014-V02-precarga.png) | Datos iniciales y selecciones de la oferta recibidos de Django |
| [V04 escritorio](evidencias/hu014-20261107/HU014-V04-persistencia.png) | Siete campos modificados, guardados y reconsultados después de recargar |
| [V05 móvil](evidencias/hu014-20261107/HU014-V05-persistencia-movil.png) | Modificación y persistencia de los siete campos en móvil web |
| [V08 red](evidencias/hu014-20261107/HU014-V08-red-borrador.png) | Borrador conservado y base intacta durante el fallo inyectado, antes de reintentar |
| [V12 archivada](evidencias/hu014-20261107/HU014-V12-no-editable-4.png) | Respuesta real 409, sin formulario de edición |
| [V15 sesión](evidencias/hu014-20261107/HU014-V15-sesion-401.png) | 401 real después de revocar el token QA; login sin datos del borrador y sin escritura |

V03 cubre obligatorios y salario inválido sin PATCH. V06/V07, error y reintento
en listado/precarga. V09/V10, 503/400 con borrador conservado. V11, oferta ajena
404. V12 cubre archivada, cerrada, borrador y vencida. V13/V14, candidato y
empresa pendiente; las rutas por rol se comprueban en escritorio y la sesión
vencida en móvil. Los tests API verifican también PATCH no autorizado, campos
protegidos, atomicidad y conservación de relaciones.

**Preparaciones conservadas.** Los ensayos anteriores no se cuentan como
aceptación aprobada. Se ajustó el selector de catálogos con valor precargado,
se guardó la sesión QA antes de navegar a URLs completas y se esperó el control
Recordar sesión después de desplazarse y se activó con foco/barra espaciadora;
los casos de rol fijan escritorio.
Sus fuentes y casos de fallo constan en el JSON. Estos ajustes pertenecen al
ejecutor; no se atribuyen a defectos del producto ni a revisiones humanas.

El diagnóstico focalizado comprobó activación/desactivación por teclado y
restauración de dos sesiones después de recargar contra otra base Django nueva.
Solo ese diagnóstico reutilizó el artefacto JavaScript de `ab86653`, cuya UI no
cambió. La aceptación de 16 casos exportó las fuentes indicadas arriba, instaló
dependencias y compiló de nuevo; no reutilizó una base ni un navegador anterior.

**Revisión e integración.** [#151 API](https://github.com/Danilo2334/Work_net/pull/151)
y [#152 Flutter/QA](https://github.com/Danilo2334/Work_net/pull/152). Flujo:
API→backend-sprint-3→develop; Flutter→frontend; incorporar backend revisado a
frontend por PR y comprobar la cabecera antes de main. Se coteja cada árbol
resultante con estas fuentes funcionales; los cambios posteriores de esta
aportación son documentación y capturas. Los PR y comentarios únicos de
#84–#87 registran los SHA definitivos y su cierre tras la entrega remota.
No se cambian protecciones ni se usa bypass. Las cuentas de publicación,
autores y committers se comprueban por separado; los commits de fusión del
servidor tienen committer GitHub. La revisión técnica es del agente por
delegación, sin aprobación personal atribuida a los integrantes.
HU011/HU012/#79 conservan selección de CV pendiente por HU018.
HU015–HU027 no se iniciaron. Los cortes HU013 siguientes son históricos.

## Integración revisada hasta HU013 — 07/11/2026

**Alcance y responsables.** Revisión de los diffs vigentes #146–#149 y de la
entrega combinada #150. Danilo2334 conserva Django, modelos, APIs, migraciones
y servicios; francisco3788 publica Flutter, integración y nuevo QA/evidencias.
La revisión técnica fue realizada por el agente por delegación expresa del titular,
que sustituyó la espera manual anterior. No se presentan aprobaciones GitHub ni
comprobaciones personales de los integrantes. Sus comprobaciones históricas
conservan abajo sus fechas, versiones y atribuciones.

**Preparación.** Se conservaron los checkouts y entornos previos. La fuente
combinada confirmada y publicada es `940f8a917511da833755f24a8071f4849e0dedf0`:
backend idéntico a `develop` después de #148/#147, Flutter después de #149 y la
corrección `c2c19d0`. Solo README tuvo conflictos; se conservaron contratos,
resultados y enlaces de ambas aportaciones. La cuenta de publicación y autor/
committer de esos dos commits se comprobaron por separado como Francisco.
Los commits de fusión del servidor tienen el autor de la cuenta que integra y
committer GitHub (`web-flow`), distinto de la cuenta autenticada.

| Paquete | Cabecera evaluada / resultado |
|---|---|
| [#148](https://github.com/Danilo2334/Work_net/pull/148) | `2f1b2f7`; migración aditiva, catálogo y publicación; propietario, estado y fecha de servidor; empresa aprobada/verificada. Integrado en backend-sprint-3: `e037d85` |
| [#147](https://github.com/Danilo2334/Work_net/pull/147) | Se comprobó `e037d85` después de #148; árbol igual al backend probado. Perfil propio y consulta empresarial por oferta propia, validación PDF, privacidad, modelos y migraciones. Integrado en develop: `b897123` |
| [#149](https://github.com/Danilo2334/Work_net/pull/149) | `c2c19d0`; formulario, contrato, reentrada del editor, sesión/navegación, aislamiento y dependencias del ejecutor. Integrado en frontend: `e15b3d6` |
| [#150](https://github.com/Danilo2334/Work_net/pull/150) | Incorporación del backend a entrega. Fuente funcional evaluada `940f8a9`; el resto de esta aportación documenta y conserva sus resultados |
| [#146](https://github.com/Danilo2334/Work_net/pull/146) | Entrega a main después de #150. La cabecera y el árbol definitivos se verifican contra esta fuente; los SHA de las fusiones constan en el PR y el seguimiento de las tareas |

Se contrastaron permisos por rol/propietario, ausencia de acceso empresarial al
PDF privado, `no-store`/`Vary: Authorization`, texto escapado y ausencia de recursos
externos en generación; límites y rechazo de PDF activo/cifrado; precarga sin
escritura y separación CV/perfil/cuenta. La publicación valida los campos y
vuelve a comprobar aprobación dentro de la transacción. No se encontró otro
defecto de backend en los cambios examinados.

**Hallazgo y corrección.** Respuestas 200/201 de HU013 con estructura inválida
provocaban errores de tipos no controlados en el adaptador. Dos pruebas fallaron
antes de la corrección. `c2c19d0` valida catálogos no vacíos e ID entero positivo,
genera un error controlado y permite recargar el catálogo. Si no puede confirmar
la publicación, indica consultar el dashboard antes de reenviar. Ocho pruebas
de ofertas, incluida la recuperación de pantalla, pasaron después. Son respuestas
simuladas y widgets, separadas del recorrido real descrito abajo.

**Pasos y resultados.** Desde la raíz de la fuente integrada confirmada:

```powershell
python frontend/tool/browser_qa/run.py
python -m unittest discover -s frontend/tool/browser_qa -p test_safety.py
node --check frontend/tool/browser_qa/suite.cjs
cd frontend
flutter test --no-pub
flutter analyze --no-pub
```

El ejecutor exportó **ambos componentes del HEAD confirmado**, creó otro venv,
instaló requirements y npm desde sus versiones fijadas, compiló web JavaScript
con recursos locales y reutilizó `backend/postman/qa.py prepare` para otra SQLite.
Credenciales desde el entorno privado, correo a archivos y Chromium temporal;
sin perfil personal, SMTP, traces, HAR ni sesiones publicadas. Conserva todas las
corridas anteriores. Los puertos propios quedaron cerrados y un nuevo inicio
sobre la corrida consumida fue rechazado sin cambiar su base.

| Comprobación nueva del conjunto | Resultado |
|---|---|
| Django accounts/candidate_dashboard/curriculum | 141 aprobadas, en entorno QA y base de test independiente |
| `check`, `makemigrations --check --dry-run` y plan aplicado | Sin incidencias ni cambios pendientes |
| Migración HU013 con datos previos | Se descendió a `0002_candidateprofile_photo_data` en otra base QA y se reaplicó `0003`; dos ofertas previas conservaron ID, título, empresa y estado |
| Flutter unidad/widgets | 114 aprobadas |
| Análisis Flutter | Sin incidencias |
| Guard QA / sintaxis Node | 8 aprobadas / correcto |
| Compilación release del ejecutor | Web JavaScript correcta; no acredita Wasm ni binarios nativos |
| Navegador real | 25/25 casos; Chromium 158.0.8127.18 con Playwright 1.65.0; 31 capturas originales nuevas |
| Persistencia y PDF | Cuatro ofertas y un CV generado; perfil/cuenta de origen intactos; texto de vista previa y descarga coincidente |

El primer ensayo auxiliar de migración usó un nombre de migración inexistente.
Se corrigió el comprobador y se repitió en otra base nueva; no fue un defecto del
producto ni se cuenta ese ensayo como aprobado. Las pruebas anteriores de HTTP,
Newman y Postman Desktop conservan su alcance: no se repitió Desktop aquí.

**Capturas y recorrido.** [Resultados, 25 identificadores, respuestas y hashes](evidencias/retoma-20261107/integracion/resultados.json).
Las 31 imágenes se conservan junto a ese JSON. Se inspeccionaron directamente
estas seis; los 25 casos incorporan además aserciones de controles y respuestas:

| Captura | Qué se comprobó |
|---|---|
| [Salida del editor](evidencias/retoma-20261107/integracion/HU012-V05-salida.png) | Diálogo que permite seguir editando el borrador |
| [PDF móvil](evidencias/retoma-20261107/integracion/HU012-V07-pdf-movil.png) | Vista previa del CV con datos ficticios; texto contrastado con la descarga |
| [Publicación escritorio](evidencias/retoma-20261107/integracion/HU013-V05-confirmacion.png) | Confirmación de oferta 3, HTTP 201 y fila de la empresa QA; dashboard pasa a 3 |
| [Publicación móvil](evidencias/retoma-20261107/integracion/HU013-V09-confirmacion.png) | Confirmación de oferta 4 y dashboard actualizado a 4 |
| [Sesión vencida](evidencias/retoma-20261107/integracion/HU013-V10-401.png) | Login sin credenciales visibles tras 401 real; no se creó otra oferta |
| [Empresa sin aprobar](evidencias/retoma-20261107/integracion/HU013-V11-403.png) | Mensaje de permiso y ausencia de formulario tras 403 real |

HU012-V01–V13 cubren precarga, obligatorios, fechas, plantillas, salida/borrador,
red, PDF, opcionales, 503, sesión/segunda cuenta, error de carga, reentrada rápida
y retroceso después de 401. HU013-V01–V11 cubren acceso, campos, catálogos,
obligatorios, salario, publicación, dashboard, errores de carga/red/400 y sesión/
aprobación. NAVEGADOR-01 comprobó login, URL y captura antes del recorrido.
Los abortos de red y respuestas 400/503 son inyectados e identificados; 401/403,
guardados y publicaciones proceden del Django QA real. Móvil es un viewport web
390×844 con ratón/teclado, no un teléfono físico. Los PDF/SQLite/entornos quedan
privados; las imágenes contienen únicamente datos ficticios de QA.

**Entrega y pendientes reales.** Orden autorizado: #148→#147, #149→frontend,
#150→frontend y comprobación de #146→main. GitHub no mostraba protecciones activas;
se usa la fusión normal, sin cambiar reglas ni bypass. Consultar el estado y SHA
final de cada operación en sus PR y en el comentario único de cada subtarea.
La aprobación técnica delegada permite integrar; no crea una revisión humana.
Crear ofertas está implementado y aceptado. HU008 incluye la consulta empresarial
API por postulación propia; no implementa la futura gestión HU020. HU011/HU012 y
#79 conservan abierto seleccionar el CV en una postulación por HU018. HU005
conserva búsqueda/mensajes/historial; HU006 gestión de ofertas/postulantes,
mensajes/estadísticas; HU007 gestión de administradores/permisos. HU014–HU027 no
se iniciaron. Los apartados siguientes son históricos y sus esperas anteriores
no sustituyen este estado.

## Revisión técnica de HU013 — 07/11/2026

**Alcance y responsable:** contrato del formulario de ofertas de #149; publicación
Flutter e integración a cargo de francisco3788. La comprobación la ejecutó el
agente por delegación del titular; no se registra una revisión personal de Danilo
ni de Francisco. Esta autorización sustituye la espera de revisión manual.

**Preparación y pasos:** checkout separado de `4851c3e`, sin modificar los entornos
anteriores. Se inyectaron respuestas HTTP 200/201 sin catálogo, con elementos de
tipo incorrecto y sin identificador válido. Dos pruebas reprodujeron errores de
tipos que escapaban al manejo de errores de la pantalla.

**Corrección y resultados:** el adaptador valida catálogos no vacíos y el ID
entero positivo de publicación. Los fallos se convierten en mensajes recuperables;
una respuesta inválida no confirma una oferta. Si la confirmación es ambigua,
el mensaje indica consultar el dashboard antes de volver a enviar. El caso de
catálogo inválido permite reintentar y cargar el formulario sin una excepción
no controlada. `flutter test test/publish_offer_test.dart --no-pub`: 8 aprobadas.
Son pruebas HTTP simuladas y widgets, sin capturas nuevas ni correos enviados.
Los recorridos reales y sus capturas conservan abajo sus fechas y versiones.

**Enlaces:** [diff vigente #149](https://github.com/Danilo2334/Work_net/pull/149/files),
[adaptador](../lib/features/offers/data/offer_repository.dart) y
[pruebas](../test/publish_offer_test.dart).

> **Estado vigente:** consultar «Integración revisada hasta HU013 — 07/11/2026».
> Los apartados anteriores a ese corte conservan las versiones y condiciones de
> sus ejecuciones, incluida la espera de revisión personal que el titular sustituyó
> después por una revisión técnica delegada. No acreditan aprobaciones humanas nuevas.

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

[Verificación final de estados, revisores y comentarios](evidencias/retoma-20261107/aceptacion-visual/seguimiento.json):
55 subtareas con un único comentario cada una; asignaciones, Sprint, fechas y
relaciones intactas. Cuenta, autor y committer del bloque publicados como Francisco.
Project actualizado con la autorización existente de Danilo. Navegador y servicios
de esta corrida cerrados; bases y entornos anteriores y la nueva SQLite conservados.

## Repetir los 25 casos con el ejecutor Playwright versionado

El recorrido anterior se hizo por tramos en una sesión interactiva de Node. En
`18bb060` se publicaron sus resultados y capturas, pero faltaba un ejecutor único.
[`tool/browser_qa`](../tool/browser_qa/) reúne ahora esos pasos en una suite
reutilizable con los mismos 25 identificadores: 1 prueba mínima, 13 HU012 y 11
HU013. Esta nueva ejecución automatizada no cambia las fechas, versiones ni el
alcance de las evidencias históricas. Tampoco constituye revisión humana.

Requisitos: Git, Python 3.12+, Node 20+ con npm y Flutter compatible con el
`pubspec.lock` publicado. Playwright está fijado a **1.65.0** en `package.json` y
`package-lock.json`; su Chromium se instala con la revisión que fija ese paquete.
El venv nuevo instala las versiones de `backend/requirements.txt` de la fuente
backend exportada. No es necesario preparar manualmente cuentas, contraseñas,
navegador o Postman.

Desde la raíz de un checkout que contenga esta herramienta:

```powershell
git fetch origin --prune
python frontend/tool/browser_qa/run.py
```

En la entrega integrada, por defecto exporta **el HEAD confirmado** tanto de
Flutter/suite como del backend. No copia modificaciones sin commit, archivos
privados ni entornos del checkout. Debe ejecutarse desde una versión que contenga
ambos componentes. La primera reproducción, conservada abajo, fijaba el backend
`2f1b2f78e01e5e8da69295c5bca97c51e09fb04b`; ese valor ya no es el predeterminado.
Para repetir explícitamente aquella combinación y elegir puertos libres:

```powershell
python frontend/tool/browser_qa/run.py --frontend-ref HEAD --backend-ref 2f1b2f78e01e5e8da69295c5bca97c51e09fb04b --api-port 8025 --web-port 55032
```

Sin esos argumentos, el orquestador elige dos puertos libres. Un puerto solicitado
ocupado causa rechazo; no detiene ni reutiliza el servicio que lo ocupa. Cada
ejecución crea otra carpeta privada `worknet-browser-qa/browser-qa-*` dentro del
directorio Git común, conservando todas las anteriores. Allí exporta las fuentes,
crea un venv, ejecuta `npm ci`, instala Chromium y compila Flutter JavaScript con
recursos web locales. Reutiliza **el preparador backend existente** `postman/qa.py
prepare` y su configuración de SQLite/correo a archivos. La configuración SMTP
no se reutiliza, y el servidor comprueba el backend de correo antes de arrancar.

Las credenciales se leen en tiempo de ejecución del
`local.postman_environment.json` privado que genera ese preparador. No se pasan
como argumentos, no están en el código y no se imprimen. El ejecutor no publica
cabeceras/cuerpos de autenticación, excepciones con valores de formularios,
traces, HAR ni `storageState`. Rechaza capturas durante login o con contraseña
rellena. Solo controla un Chromium/contexto temporal nuevo; no admite perfil
personal ni conexión a un navegador abierto. Bloquea solicitudes fuera de sus
dos orígenes locales; los recursos Flutter se sirven localmente.

Antes de actuar verifica marcador QA, rutas canónicas de base/entorno, cuentas
ficticias exactas, URLs/puertos y la identidad de **ambos servicios propios** con
un nonce de esa corrida. Exige que la base coincida con su copia inicial y que
la suite no haya sido iniciada. Si algo falla, se detiene. Los únicos cambios SQL
directos son revocar tokens QA para provocar los 401 y contrastar la persistencia;
guardar/publicar/editar/descargar se ejecuta desde la interfaz. No implementa HU018
ni toca HU014–HU027. Los errores de red/400/503 se marcan como inyectados; los
401/403, guardados y publicaciones proceden del Django QA real.

La consola muestra los identificadores y el resultado, nunca credenciales. El
archivo nuevo `artifacts/resultados.json` registra commits exactos, versiones,
25 resultados, rutas/códigos de respuesta sanitizados y hashes de las capturas.
Las capturas y los PDF ficticios permanecen en esa carpeta privada; no se copian
automáticamente al repositorio. Se comparan los PDF de vista previa/descarga y la
SQLite inicial/final. Ante fallo se conserva la corrida y se devuelve salida no
cero. Al terminar se cierra Chromium y se detienen únicamente los servidores
propios; no se borran bases, artefactos ni entornos anteriores. Para repetir se
ejecuta otra vez `run.py`, que crea una corrida distinta.

Los guards pueden comprobarse sin arrancar servicios:

```powershell
python -m unittest discover -s frontend/tool/browser_qa -p test_safety.py
node --check frontend/tool/browser_qa/suite.cjs
```

**Reproducción comprobada el 07/11/2026:** [resultado nuevo sanitizado](evidencias/retoma-20261107/ejecutor-playwright/reproduccion.json).
El comando anterior exportó la fuente confirmada `215cf729fb935b26af64e5fe7063072a51754527`
y el backend fijado `2f1b2f7`, instaló desde cero sus dependencias en otra carpeta,
compiló y ejecutó **25/25 casos aprobados**, con 31 capturas nuevas privadas.
Se usaron Python 3.12.10, Node 22.23.3, Flutter 3.47.5/Dart 3.13.4 y Chromium
158.0.8127.18. Pasaron 8 pruebas del guard y el análisis sintáctico de la suite.
Un intento directo de iniciar otra vez la corrida consumida fue rechazado sin
modificar su SQLite. Perfil/cuenta iniciales intactos, cuatro ofertas QA y un CV
generado al final; vista previa y descarga PDF coincidentes. Los puertos quedaron
libres al terminar. Las dependencias y scripts de esa fuente son los publicados
en este bloque; los cambios posteriores solo documentan el resultado.

Los dos primeros ensayos del nuevo ejecutor se detuvieron en HU012-V01: faltaba
esperar la pantalla y los clics de campos podían coincidir con un desplazamiento
del canvas Flutter. Se conservan esas corridas como fallidas; no son 25 casos
aprobados ni fallos nuevos del producto. El ejecutor corregido espera la carga
y usa foco/teclado para campos, manteniendo los controles reales y las aserciones
de UI. No se repitieron Postman, la auditoría general ni las suites técnicas del
producto; no se solicitó una comprobación manual adicional.

### Historial: paquetes de revisión preparados antes de la delegación

| Persona / PR | Alcance concreto del paquete |
|---|---|
| Danilo / [#146](https://github.com/Danilo2334/Work_net/pull/146) | Cabecera `91207ad37f13f1dd9f647264b48717ae514cb2f7`: pantallas/integración y HU011/HU012. El ejecutor nuevo está en #149, todavía fuera de esta cabecera. Revisar esa dependencia y la incorporación posterior del backend antes de main |
| Danilo / [#149](https://github.com/Danilo2334/Work_net/pull/149) | Formulario HU013, corrección de reentrada HU012 y ahora ejecutor/lockfile/guards: aislamiento, lectura de secretos, aserciones reales, fallos inyectados y limpieza de servicios. Su descripción fija la nueva cabecera y el diff completo inmutable para revisión |
| Francisco / [#147](https://github.com/Danilo2334/Work_net/pull/147) | Cabecera `3959d08385a8fd14161c53216179f3a01e769d42`: código de Danilo de perfil/CV/PDF, permisos, validación, límites y migraciones. Incorporar #148 primero y verificar de nuevo la cabecera resultante |
| Francisco / [#148](https://github.com/Danilo2334/Work_net/pull/148) | Cabecera `2f1b2f78e01e5e8da69295c5bca97c51e09fb04b`: migración y contrato de oferta, aprobación/verificación, propietario/estado/fecha y bloqueo transaccional |

Los enlaces a diff completo, cabeceras y este paquete se fijan también en las
descripciones de los cuatro PR. No se presentó revisión, aprobación ni cierre de
casillas por cambiar de cuenta. HU012/#79 y la selección de CV conservan HU018
pendiente. Estados, roles, criterios pendientes y orden #148→#147, #149→frontend,
backend revisado→entrega→#146 permanecen vigentes. No se fusionó ningún PR, no se
cerró una historia ni se inició HU014–HU027.
