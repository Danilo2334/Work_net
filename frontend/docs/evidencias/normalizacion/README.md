> **Pruebas actuales:** capturas de la app Flutter para interfaz y de Postman para backend. Los informes anteriores conservan su fecha e historial.

> **Historial del 18/10/2026.** El seguimiento actual está en [preparación de revisión](../revision-sprint/README.md). Las referencias a pendientes de rol, logout y estados empresariales de este informe ya fueron actualizadas allí. Se conserva este índice y sus enlaces para consultar la evidencia de esa fase.

# Seguimiento vigente de evidencias — HU001, HU002, HU003, HU004, HU005 y HU008

Normalización del **18/10/2026**, America/Bogota. Este índice reúne **25 tareas
y 26 comentarios vigentes**: #46 mantiene separados integración y QA.
Backend y QA se registran con **Danilo2334**; Flutter e integración con
**francisco3788**. Falta la revisión por otro integrante.

Cada comentario presenta función realizada, tabla de casos con tipo y resultado
esperado/obtenido, imágenes embebidas con título y leyenda, referencias y
pendientes específicos. El código se consulta en commits/PR y los comandos en
los informes técnicos. No se copió código de producto en el seguimiento vigente.

## Comentarios por tarea

Se editaron los comentarios actuales conservando autor, identificador y fecha de
creación. En #29 y #48 no había comentario: se añadió uno con su responsable.
Los comentarios anteriores de otras entregas se identifican como históricos y
se pliegan, conservando su texto; las casillas históricas dejan de renderizarse
como listas de cierre. No se cambian cuerpos de issues, criterios, asignaciones,
estados, Sprints, fechas ni hitos. No se cerró ninguna tarea.

| Historia | Tarea y comentario vigente | Área | Responsable |
| --- | --- | --- | --- |
| HU001 | [#29](https://github.com/Danilo2334/Work_net/issues/29#issuecomment-6259568713) | Interfaz | francisco3788 |
| HU001 | [#30](https://github.com/Danilo2334/Work_net/issues/30#issuecomment-5945401868) | Backend | Danilo2334 |
| HU001 | [#31](https://github.com/Danilo2334/Work_net/issues/31#issuecomment-6245223656) | Backend | Danilo2334 |
| HU001 | [#32](https://github.com/Danilo2334/Work_net/issues/32#issuecomment-6245224132) | Integración | francisco3788 |
| HU001 | [#33](https://github.com/Danilo2334/Work_net/issues/33#issuecomment-6245223825) | QA | Danilo2334 |
| HU002 | [#34](https://github.com/Danilo2334/Work_net/issues/34#issuecomment-6245479135) | Interfaz | francisco3788 |
| HU002 | [#35](https://github.com/Danilo2334/Work_net/issues/35#issuecomment-5978133170) | Backend | Danilo2334 |
| HU002 | [#36](https://github.com/Danilo2334/Work_net/issues/36#issuecomment-6245479333) | Integración | francisco3788 |
| HU002 | [#38](https://github.com/Danilo2334/Work_net/issues/38#issuecomment-6245480254) | QA | Danilo2334 |
| HU003 | [#39](https://github.com/Danilo2334/Work_net/issues/39#issuecomment-6245479481) | Interfaz | francisco3788 |
| HU003 | [#40](https://github.com/Danilo2334/Work_net/issues/40#issuecomment-5982522310) | Backend | Danilo2334 |
| HU003 | [#41](https://github.com/Danilo2334/Work_net/issues/41#issuecomment-6245479640) | Integración | francisco3788 |
| HU003 | [#42](https://github.com/Danilo2334/Work_net/issues/42#issuecomment-6245480431) | QA | Danilo2334 |
| HU004 | [#43](https://github.com/Danilo2334/Work_net/issues/43#issuecomment-6245716590) | Interfaz | francisco3788 |
| HU004 | [#44](https://github.com/Danilo2334/Work_net/issues/44#issuecomment-5988732139) | Backend | Danilo2334 |
| HU004 | [#45](https://github.com/Danilo2334/Work_net/issues/45#issuecomment-5988956782) | Backend | Danilo2334 |
| HU004 | [#46](https://github.com/Danilo2334/Work_net/issues/46#issuecomment-6245718106) | QA | Danilo2334 |
| HU004 | [#46](https://github.com/Danilo2334/Work_net/issues/46#issuecomment-6245716821) | Integración | francisco3788 |
| HU005 | [#47](https://github.com/Danilo2334/Work_net/issues/47#issuecomment-6245479801) | Interfaz | francisco3788 |
| HU005 | [#48](https://github.com/Danilo2334/Work_net/issues/48#issuecomment-6259566675) | Backend | Danilo2334 |
| HU005 | [#49](https://github.com/Danilo2334/Work_net/issues/49#issuecomment-6245479981) | Integración | francisco3788 |
| HU005 | [#50](https://github.com/Danilo2334/Work_net/issues/50#issuecomment-6245480602) | QA | Danilo2334 |
| HU008 | [#59](https://github.com/Danilo2334/Work_net/issues/59#issuecomment-6246221677) | Interfaz | francisco3788 |
| HU008 | [#60](https://github.com/Danilo2334/Work_net/issues/60#issuecomment-6246223175) | Backend | Danilo2334 |
| HU008 | [#61](https://github.com/Danilo2334/Work_net/issues/61#issuecomment-6246221840) | Integración | francisco3788 |
| HU008 | [#62](https://github.com/Danilo2334/Work_net/issues/62#issuecomment-6246223309) | QA | Danilo2334 |

## Pruebas nuevas y evidencia reutilizada

En esta normalización se ejecutaron **60 comprobaciones HTTP reales** con
Django local, otra SQLite y correo a archivos, y la suite backend existente:
**87 pruebas aprobadas, cero fallos**. No se modificó lógica del producto.
Se añadieron **8 capturas** de los informes automáticos de API en Chrome para
#30, #31, #35, #40, #44, #45, #48 y #60, con respuestas sanitizadas y los tests
pertinentes. No se presentan como capturas manuales de Postman. Las selecciones
de tests por tarea pueden solaparse; no se suman para obtener el total de 87.

[Informe backend y reproducción](https://github.com/Danilo2334/Work_net/blob/5173b1686817708ad5b09bfb22cd060ed9f16c33/backend/docs/evidencias/normalizacion/README.md) · [Resultados HTTP](https://github.com/Danilo2334/Work_net/blob/5173b1686817708ad5b09bfb22cd060ed9f16c33/backend/docs/evidencias/normalizacion/api.json) · [Suite](https://github.com/Danilo2334/Work_net/blob/5173b1686817708ad5b09bfb22cd060ed9f16c33/backend/docs/evidencias/normalizacion/suite.json).

Las capturas Flutter se reutilizan desde el avance publicado en `2970dea`.
Conservan el entorno, fecha y alcance de cada fase; no se afirma haber vuelto a
ejecutar navegador ni Flutter para este ajuste documental. La regresión más
reciente publicada de Flutter tiene **67 pruebas aprobadas y análisis limpio**.
Los 21/40/54 tests de fases anteriores se conservan como resultados históricos,
no se suman ni se anuncian como pruebas nuevas. Los 19/28/47 casos de las fases
de acceso, cuenta y perfil son conteos conjuntos, no resultados individuales
repetidos para cada tarea.

| Bloque | Informe técnico y casos originales |
| --- | --- |
| Registro | [HU001](../hu001/README.md) y [verificación local](../hu001/verificacion-correo-local.json) |
| Login | [HU002](../hu002/README.md) y [19 casos conjuntos de acceso](../acceso-candidato/resultados-qa.json) |
| Recuperación | [HU003](../hu003/README.md) y el informe conjunto anterior |
| Cuenta | [HU004](../hu004/README.md), [28 casos](../hu004/resultados-qa.json) |
| Dashboard | [HU005](../hu005/README.md), casos de acceso y completitud en HU008 |
| Perfil | [HU008](../hu008/README.md), [47 casos](../hu008/resultados-qa.json) |

La persistencia se respalda con consultas posteriores a Django y los permisos
con solicitudes de usuarios distintos o sin sesión. Una imagen de pantalla no
reemplaza esas comprobaciones. Las fotos nuevas de HU008 son sintéticas de QA;
no se adjuntan contraseñas ni enlaces firmados ni credenciales de sesión.

## Evidencias y dependencias aún pendientes

| Historia | Qué falta acreditar o completar |
| --- | --- |
| HU001 | Entrega SMTP real, recepción en el buzón y enlace recibido; información/estados de empresa (#64/#68), revisión del orden registro/rol y revisión formal. El recorrido del candidato ya existe. |
| HU002 | Estados empresariales reales (#37/#64/#68), destinos Empresa/Administrador y su QA, además de revisión formal. El cierre de sesión es local: no se atribuye revocación remota al botón. |
| HU003 | Entrega SMTP y recorrido desde el buzón real, además de revisión formal. Generación a archivos, vencimiento, cambio y revocación local sí están acreditados. |
| HU004 | Revisión de Danilo de #43/#46 y de Francisco de #44/#45. SMTP y estados empresariales no impiden esta revisión. La preferencia push no equivale a entrega push a un dispositivo. |
| HU005 | Módulos de CV, búsqueda, mensajes, historial y detalle/postulación, con sus recorridos y QA. El acceso a Perfil del candidato ya funciona. Revisión formal pendiente. |
| HU008 | Consulta empresarial autorizada dentro de selección cuando exista esa dependencia, y revisión formal. El 403 actual solo demuestra restricción. Datos estructurados disponibles no equivalen a generar un CV. |

La comprobación visual móvil corresponde a **web 390×844**, no ejecución
nativa. La validación nativa sigue pendiente y no se atribuye a estas capturas.
**#37 permanece sin implementación publicada:** no se añadió como evidencia de
avance ni se actualizó su documentación para darlo por implementado.

El [PR #146](https://github.com/Danilo2334/Work_net/pull/146) debe permanecer
**en borrador y sin fusionar**. Esta normalización no acredita revisión humana,
aprobación final ni cierre completo de las historias.

[Índice estructurado de comentarios, capturas y pendientes](tareas.json).
