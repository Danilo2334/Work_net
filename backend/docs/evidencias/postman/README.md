# Pruebas del backend ejecutadas en Postman

**Evidencia vigente: Postman Desktop 12.31.7 contra Django real.** Fecha: 19/10/2026. Ejecución por agente; QA registrado como **Danilo2334**. La revisión humana permanece pendiente.

Se registran únicamente capturas directas de Postman: petición, respuesta y comprobaciones. Las pantallas de frontend se acreditan con capturas de la app Flutter. Los informes HTML y las ejecuciones de consola anteriores se conservan como historial técnico y quedan fuera de la evidencia de aceptación solicitada.

## Resultado en Postman

| Pasada | Base inicial | Peticiones | Comprobaciones aprobadas | Fallos |
|---|---|---:|---:|---:|
| 1 | SQLite nueva, Django en 8008 | 212 | 631 | 0 |
| 2 | Otra SQLite nueva, Django en 8009 | 212 | 631 | 0 |

Las once carpetas se ejecutaron desde el Collection Runner de **la aplicación Postman**, con el entorno correspondiente, una iteración y conservación de variables. Los datos iniciales son ficticios; IDs y tokens se obtuvieron de respuestas reales. Se comprobaron validaciones, persistencia mediante otra consulta, roles y separación entre usuarios, revocación de sesión, CRUD, fotografías y revisión empresarial.

La primera preparación de recuperación se detuvo por una variable de enlace ausente; se cargó y se completó en Postman. No se modificó ningún resultado esperado. Las dos pasadas completas de la tabla quedaron aprobadas. Además se volvió a enviar la petición idempotente PM016 en el editor para capturar respuesta y Test Results sin exponer su enlace.

## Capturas directas por tarea

| Tarea | Evidencia de Postman |
|---|---|
| #30 | [PM007: Registro y correo duplicado](capturas/hu001-registro-duplicado.png) |
| #31 | [PM016: Verificación: respuesta de Django](capturas/hu001-verificacion-respuesta.png), [PM016: Verificación: Test Results](capturas/hu001-verificacion-pruebas.png) |
| #35 | [PM023: Logout y token revocado](capturas/hu002-token-revocado.png) |
| #40 | [PM035: Solicitud de recuperación](capturas/hu003-solicitud.png), [PM039: Cambio de contraseña confirmado](capturas/hu003-cambio-confirmado.png) |
| #44 | [PM051: Nombre recuperado en otra consulta](capturas/hu004-nombre-persistente.png), [PM057: Token anterior rechazado al cambiar contraseña](capturas/hu004-token-anterior.png), [PM209: Eliminación de la cuenta desechable](capturas/hu004-eliminacion.png), [PM210: Sesión de cuenta eliminada rechazada](capturas/hu004-cuenta-eliminada-401.png) |
| #45 | [PM064: Preferencia false persistida](capturas/hu004-preferencia-persistente.png) |
| #48 | [PM081: Resumen del candidato](capturas/hu005-resumen.png) |
| #52 | [PM084: Resumen de empresa](capturas/hu006-resumen.png) |
| #56 | [PM086: Resumen administrativo](capturas/hu007-resumen.png) |
| #60 | [PM100: Educación editada y recuperada](capturas/hu008-educacion-persistente.png), [PM102: Otro candidato no modifica el registro](capturas/hu008-permisos.png), [PM138: Fotografía corrupta rechazada](capturas/hu008-foto-invalida.png) |
| #64 | [PM165: Información empresarial persistida](capturas/hu009-informacion-persistente.png) |
| #68 | [PM180: Rechazo con motivo y aviso](capturas/hu010-rechazo-notificado.png), [PM186: Aprobación administrativa](capturas/hu010-aprobacion.png), [PM187: Decisión con versión obsoleta](capturas/hu010-version-obsoleta.png) |

[Ver todas las capturas con su explicación](capturas/README.md) · [Seguimiento de las tareas](seguimiento.md).

## Repetir las pruebas

[Importar la colección, preparar los datos y ejecutar en Postman](../../../postman/README.md). La colección está organizada por historia y tarea; cada petición conserva preparación, encabezados, cuerpo, respuesta esperada y scripts. Antes de las fases 02 y 04 se cargan las variables del enlace leído del correo local, sin revelarlas en capturas.

Los archivos de fotografía se cargaron desde el directorio de trabajo de Postman, con las mismas rutas relativas de la colección. Para repetir, seleccionar `backend/postman` como directorio de trabajo o copiar allí los cinco fixtures indicados en las instrucciones. Se conservan las tres colecciones originales y las capturas históricas recuperadas.

## Qué queda pendiente

- Revisión por otro integrante y validación nativa. No se cierran tareas ni se registra una aprobación humana.
- Estas pasadas usan correo capturado en archivos. La recepción real anterior conserva su [evidencia SMTP separada](../revision-sprint/SMTP.md).
- Consulta empresarial autorizada al perfil y módulos futuros conservan sus dependencias. Un 403 no acredita un acceso positivo todavía inexistente.
- PR #146 continúa en borrador y sin fusionar; Sprints, fechas y criterios se conservan.

Los detalles de las dos observaciones del Runner y los hashes de las imágenes están en [entorno.json](entorno.json). Las imágenes son capturas de la aplicación; este documento solamente explica sus casos.
