# WorkNet · Entrega y guion de presentación

**Revisión final: 09/11/2026.** [Auditoría final](auditoria-final-20261109.json): 301 Django, 237 Flutter y 40 rondas concurrentes aprobadas sobre la versión corregida. Aceptación real HU028 conservada como referencia: [66d9f15](https://github.com/Danilo2334/Work_net/commit/66d9f154068aa3e33cbef0bb5a751ff6c35df6ae), [PR #236](https://github.com/Danilo2334/Work_net/pull/236).

## Alcance cerrado

| Alcance | Estado comprobado en GitHub |
| --- | --- |
| HU001–HU026 y HU028 | 27 historias closed/completed; cada contador nativo al 100 %. |
| Tareas de esas historias | 112 closed/completed. |
| HU027 y #137–#141 | Seis issues abiertas; cinco subtareas pendientes, 0/5. Segunda versión. |
| PR al iniciar la revisión | Ninguno abierto. |

Esta revisión volvió a consultar las issues y los 146 ítems de WORK_NET: 27 historias y 112 tareas closed/completed y Done, con todos los contadores nativos de la entrega al 100 %. HU027 y sus cinco tareas siguen abiertas y Backlog. Se conservan fechas, Sprint, responsables y un comentario por tarea, con sus evidencias.

## Preparación antes de exponer

1. Abrir un checkout limpio de la entrega y una base exclusiva para demostración. Conservar las bases de aceptación y los cambios de otros checkouts.
2. Aplicar migraciones y preparar cuentas ficticias de candidato, empresa y administrador principal. Crear el principal con `python manage.py createsuperuser` y configurar TOTP en privado. Candidato y empresa se registran/verifican mediante los flujos existentes.
3. Comprobar un correo real antes de exponer. Aprobar una empresa, preparar una oferta activa y una candidatura previa. Mantener otra oferta sin usar para demostrar el recorrido nuevo.
4. Comprobar Gemini con una generación ficticia y confirmar guardado/descarga del CV. Las llamadas consumen cuota; evitar repetirlas innecesariamente.
5. Abrir sesiones separadas por rol, el repositorio, la guía y los tres PDF de aceptación. Mantener claves, tokens, TOTP y recuperación fuera de la pantalla compartida.
6. Ensayar el recorrido una vez. No eliminar cuentas ni cerrar la oferta principal antes de terminar. Los datos preparados se presentan como preparación, no como acciones recién realizadas.

## Demostración en 12 minutos

| Tiempo | Mostrar | Mensaje principal |
| --- | --- | --- |
| 0:00–1:00 | Problema, roles y portada del repositorio | Un flujo común para candidatos, empresas y administración; 27 historias entregadas. |
| 1:00–4:00 | Perfil → CV → IA → revisión → aplicar → guardar → PDF | La IA organiza información aportada; el candidato controla el contenido y confirma el guardado. |
| 4:00–6:00 | Buscar, filtrar, guardar, postular eligiendo CV y abrir historial | La postulación conserva el documento enviado y su fecha. |
| 6:00–8:30 | Empresa: postulantes, filtros, CV, estado con comentario y mensaje | Propiedad y permisos en servidor; el candidato recibe el resultado y puede responder. |
| 8:30–10:00 | Avisos, estadísticas y exportación CSV/PDF | Datos reales de las cuentas autorizadas y exportación del conjunto filtrado. |
| 10:00–11:00 | Administración, doble factor, permisos y revisión de empresa | Acceso controlado y trazabilidad de acciones. |
| 11:00–12:00 | Pruebas, evidencias, límites y siguiente versión | 301 Django, 237 Flutter; LinkedIn v2; despliegue como siguiente fase. |

### Texto ficticio para la IA

> Soy Ana QA, estudiante de Ingeniería de Sistemas en Universidad QA. He colaborado como desarrolladora de prácticas en Equipo QA. Tengo conocimientos de Python, Django, Flutter y Git. Hablo español. Me interesa una oportunidad junior. No he indicado fechas completas ni certificaciones.

Verificar que la propuesta no añade empresas, títulos ni fechas no aportados. Revisar el resumen y completar lo que falte antes de guardar. No presentar una respuesta de IA como garantía de veracidad.

### Si falla una dependencia

Si Gemini no responde o agota cuota, mostrar el mensaje real, continuar con el editor manual y abrir la [evidencia publicada](../frontend/docs/REVISION.md#hu028--asistente-de-creación-de-currículum-con-ia--resultado-vigente-09112026), identificándola como aceptación anterior. Si falla el correo, explicar el bloqueo y mostrar el resultado previo documentado. No sustituir una llamada real por un doble sin indicarlo.

## Respaldo para preguntas técnicas

| Pregunta | Referencia |
| --- | --- |
| ¿Cómo se estructura Flutter? | [Capas, sesiones y rutas](../frontend/README.md). |
| ¿Cómo se protege un CV? | [Modelos privados](../backend/curriculum/models.py) y [copia en postulación](../backend/candidate_dashboard/models.py). |
| ¿Cómo se acredita Gemini real? | [Auditoría de cuatro llamadas aceptadas](../backend/docs/evidencias/hu028-real-20261109/provider-calls-accepted.json) y casos API, navegador y Desktop de la guía. |
| ¿Qué pruebas hay? | [Aceptación](../backend/docs/evidencias/hu028-real-20261109/aceptacion.json) y [verificación conjunta](../backend/docs/evidencias/hu028-real-20261109/verificacion-conjunta.json). |
| ¿Cuál es el modelo HU001? | [Historia modelo](https://github.com/Danilo2334/Work_net/issues/2) y comentarios únicos de cada tarea. |
| ¿Ya está en producción? | La página pública es informativa. El [plan de despliegue](DESPLIEGUE.md) identifica ajustes y validación pendientes. |

## Organización final de ramas

La preparación posterior conserva únicamente `main`, `frontend` y `develop` como ramas permanentes. Main es la entrega integrada para el despliegue; frontend mantiene Flutter e integración; develop mantiene Django. Las ramas temporales y de sprint se retiran preservando sus commits. [Inventario de limpieza](limpieza-ramas-20261109.json).

Las evidencias exclusivas HU008 quedan bajo el tag `archivo/20261109/hu008-evidencias`; una combinación de QA solo local se archiva localmente y en un respaldo Git verificado. Los checkouts, datos y configuraciones anteriores se conservan en su mismo commit, y se prepara una copia limpia main para continuar. Esto no inicia el despliegue ni cambia el alcance cerrado o HU027.

## Limpieza realizada

Se corrigieron los README que aún indicaban Gemini pendiente. La portada pública y la descripción del repositorio reflejan la IA entregada y LinkedIn v2. Se retiraron 45 ramas temporales cuyos commits estaban contenidos en main. Se conserva el [inventario con SHA](auditoria-cierre-20261109.json), el historial y las bases compartidas. En aquel corte HU008 conservó una rama con un commit exclusivo de evidencias. La limpieza posterior descrita arriba conserva ese commit mediante un tag de archivo, sin incorporarlo automáticamente ni acreditarlo como función nueva.

La limpieza documental previa no cambió código funcional. La revisión final posterior sí corrigió la concurrencia de preferencias HU023 y volvió a ejecutar 301 Django, 237 Flutter, análisis, build y migraciones, más 40 rondas de concurrencia. Conserva las aceptaciones históricas; no repite Gemini, SMTP, navegador o Postman. Los checkouts, cambios locales y configuración privada anteriores permanecen intactos.
