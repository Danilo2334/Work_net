# Capturas visuales de Postman pendientes

No hay capturas funcionales nuevas de Postman en esta entrega. Las dos ejecuciones publicadas fueron realizadas con Newman por consola.

Al realizar la comprobación en Postman, conservar petición, código HTTP, respuesta y Test Results. Se pueden usar dos capturas por caso si respuesta y comprobaciones no caben juntas. Cada imagen debe indicar el ID PM de [CASOS.md](../../../../postman/CASOS.md), su tarea, el run aislado y qué demuestra.

Capturas útiles, sin repetir todo el catálogo:

- #30/#31: registro 201 con variables secretas sin revelar; verificación 200 con el parámetro firmado oculto.
- #35/#40: token revocado 401; recuperación confirmada 200 y contraseña anterior rechazada, sin mostrar cuerpos ni respuestas con secretos.
- #44/#45: nombre conservado tras nueva consulta; preferencia false persistida; cuenta desechable eliminada y token rechazado.
- #48/#52/#56: los tres resúmenes y el rechazo de un rol no autorizado.
- #60: registro estructurado recuperado, foto inválida rechazada y otro candidato sin acceso a un registro ajeno.
- #64/#68: información recuperada, solicitud rechazada con motivo, reenvío, aprobación y versión obsoleta 409.

Mantener Authorization contraído y las variables sensibles enmascaradas. No capturar contraseñas, tokens en respuestas de login/registro, enlaces firmados o entornos revelados. Las capturas complementan los informes; por sí solas no demuestran recepción en un buzón ni revisión humana.
