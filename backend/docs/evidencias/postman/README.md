# QA backend reproducible — Postman y Newman

Fecha: **19/10/2026**. Responsable de backend y QA: **Danilo2334**. Base publicada de Django: `2f8d226`; esta entrega añade herramientas, colección y evidencia, sin modificar los endpoints del producto.

## Qué se entregó

[Colección Postman](../../../postman/WorkNet.postman_collection.json), [entorno de ejemplo sin credenciales](../../../postman/WorkNet.local.postman_environment.json), [instrucciones de importación y repetición](../../../postman/README.md) y [catálogo de casos](../../../postman/CASOS.md). El script local prepara migraciones, datos ficticios, contraseñas aleatorias, correo a archivos y una SQLite nueva; conserva cada ejecución anterior.

[Comentarios publicados por tarea y comprobación de conservación](seguimiento.md).

Se encontraron tres colecciones originales en Descargas: #44 (7 peticiones), #45 (8) y #48 (10). Se respaldaron junto con sus carpetas y el perfil de Postman **antes de crear la nueva colección**. Las originales permanecen intactas; sus SHA-256 constan en [respaldo.json](respaldo.json). También se respaldaron los comentarios de las doce tareas. Los comentarios históricos y sus 26 capturas recuperadas no se reformatean ni sustituyen.

## Qué se probó

| Ejecución | Preparación | Peticiones | Comprobaciones | Resultado |
|---|---|---:|---:|---|
| [1](ejecucion-1.json) | SQLite nueva, Django real en puerto 8009 | 212 | 631 | Todas aprobadas |
| [2](ejecucion-2.json) | Otra SQLite nueva, mismos datos funcionales iniciales, puerto 8010 | 212 | 631 | Todas aprobadas |
| Interna Django | Base temporal del test runner | 3 tests | Verificación vencida, recuperación vencida y fallo de envío controlado | Todas aprobadas |

Las dos pasadas ejecutaron **el mismo JSON de colección**, con el mismo SHA-256. Newman 6.2.3 envió las peticiones HTTP y ejecutó sus scripts Post-response. No se consultó la base habitual ni se enviaron mensajes a Gmail. Los informes publicados omiten cuerpos, encabezados de autenticación, contraseñas y URLs firmadas. Las respuestas y entornos completos permanecen únicamente en archivos privados ignorados.

Git convierte los finales CRLF del archivo ejecutado en Windows a LF al publicarlo. [normalizacion.json](normalizacion.json) conserva ambos hashes y la comprobación de contenido JSON idéntico; los informes originales mantienen su hash de ejecución sin alterar. `.gitattributes` fija LF para las próximas importaciones y ejecuciones.

También pasaron `manage.py check`, `makemigrations --check --dry-run` y la [validación de la colección contra el esquema oficial v2.1](schema-validacion.json). No se atribuyen aquí las 103 pruebas Django ni las pruebas Flutter de fases anteriores: no se volvieron a ejecutar en este bloque.

Durante la preparación hubo una ejecución fallida del script por declarar `data`, nombre global reservado por el sandbox de Postman. Se corrigió a `payloadQA`, se conservó el diagnóstico privado y se prepararon dos bases nuevas antes de las dos ejecuciones completas indicadas arriba. No se cambió ningún resultado HTTP esperado para ocultar ese fallo.

| Tarea | Qué se comprobó | Peticiones por ejecución | Esperado / obtenido |
|---|---|---:|---|
| #30 Registro y roles | Validaciones, correo duplicado, alta antes del rol, ticket limitado, rol persistido y no reasignable | 12 | Estados y contenido esperados; 12 aprobadas |
| #31 Verificación | Enlace ausente, inválido, enlace del mensaje capturado y repetición idempotente | 4 | 400 para ausente/inválido; 200 para válido/repetido; 4 aprobadas |
| #35 Login y sesión | Login verificado/no verificado, error, roles y estados empresariales, logout y token revocado | 17 | Token real cuando corresponde; rechazo y revocación esperados; 17 aprobadas |
| #40 Recuperación | Solicitud genérica, validaciones, enlace local válido, reutilizado, contraseña anterior y revocación | 12 | Cambio persistido; enlace usado/contraseña anterior rechazados y token 401; 12 aprobadas |
| #44 Cuenta y eliminación | Lectura propia, edición, campos protegidos, rotación de token, eliminación cancelada/inválida/confirmada | 27 | Persistencia propia, separación y eliminación solo desechable; 27 aprobadas |
| #45 Preferencias | Booleanos, persistencia de false/true, errores y separación entre cuentas | 11 | Valores conservados y entradas incorrectas rechazadas; 11 aprobadas |
| #48 Resumen candidato | 83 % y métricas 2/1/2; segundo candidato 17 % y métricas cero; permisos y método | 6 | Valores y restricciones coincidentes; 6 aprobadas |
| #52 Resumen empresa | Empresa aprobada con dos ofertas/dos postulaciones; estados pendientes/rechazados; nueva aprobada sin actividad ajena | 7 | Métricas propias y acceso según estado; 7 aprobadas |
| #56 Resumen administrador | Roles, conteos reales, pendiente completo y eventos de revisión persistidos | 7 | Conteos y eventos coincidentes; 7 aprobadas |
| #60 Perfil y fotografía | CRUD de perfil y cuatro secciones, fechas, niveles, permisos entre usuarios y foto privada/opcional/inválida | 69 | Persistencia, restricciones y completitud real; 69 aprobadas |
| #64 Información empresarial | Datos completos, validaciones, separación, NIT único, envío, edición protegida, web/redes y logo | 26 | Persistencia y restricciones coincidentes; 26 aprobadas |
| #68 Validación empresarial | Solo administrador, motivo, rechazo, corrección, reenvío, aprobación, versión obsoleta y avisos | 14 | Decisiones persistidas con revisor; versión obsoleta 409; 14 aprobadas |

Los datos de entorno, versiones y límites están en [entorno.json](entorno.json). El [catálogo](../../../postman/CASOS.md) identifica método, ruta, preparación y esperado por caso; la colección conserva además los cuerpos y todas las comprobaciones.

## Capturas

**Pendiente la ejecución visual en Postman y sus capturas auténticas.** Postman 12.31.7 se abrió usando una copia privada del perfil respaldado; no se consiguió completar la importación ni ejecutar la colección desde esa interfaz. No se publica una pantalla de Postman vacía, un informe HTML o una captura de consola como si acreditaran los casos en su interfaz.

La lista para completar esa evidencia está en [capturas/README.md](capturas/README.md). Las capturas históricas recuperadas siguen siendo evidencia histórica de sus ejecuciones; no se presentan como capturas de esta colección nueva.

## Estado y pendientes

- **Comprobado:** colección v2.1 válida, entorno de ejemplo, preparación/restauración por base nueva, dos pasadas completas con Newman, correo capturado localmente, permisos, persistencia y tres tests internos separados.
- **Pendiente de este entregable:** importar y ejecutar visualmente en Postman, guardar las capturas descritas y registrar sus resultados reales.
- **Correo real:** su evidencia anterior se conserva en [SMTP.md](../revision-sprint/SMTP.md). Estas dos pasadas prueban el contenido del correo capturado y los endpoints; no una nueva entrega SMTP.
- **Criterios de otras funcionalidades:** consulta empresarial autorizada al perfil, accesos a módulos futuros y gestión de administradores conservan sus pendientes. Una respuesta 403 no acredita el caso positivo de autorización todavía ausente.
- **Revisión humana:** no realizada. No se cierran tareas; PR #146 debe continuar en borrador y sin fusionar.
