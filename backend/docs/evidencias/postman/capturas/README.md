# Capturas directas de Postman

Postman Desktop 12.31.7, API real de Django y datos ficticios en bases aisladas. Cada imagen conserva la respuesta y/o sus comprobaciones en la aplicación. Las variables sensibles se mantuvieron ocultas.

## #30 · Registro y correo duplicado

**PM007; esperado y obtenido: HTTP 400.** Postman muestra el alta 201 en el listado y el rechazo del correo repetido con su respuesta en español y cuatro comprobaciones aprobadas.

![PM007: Registro y correo duplicado](hu001-registro-duplicado.png)

## #31 · Verificación: respuesta de Django

**PM016; esperado y obtenido: HTTP 200.** Petición real con el enlace representado por una variable secreta. Repetir la verificación devuelve 200 y el mensaje de cuenta ya verificada.

![PM016: Verificación: respuesta de Django](hu001-verificacion-respuesta.png)

## #31 · Verificación: Test Results

**PM016; esperado y obtenido: HTTP 200.** Las tres comprobaciones de la petición están aprobadas en Postman; corresponde a la respuesta de la captura anterior.

![PM016: Verificación: Test Results](hu001-verificacion-pruebas.png)

## #35 · Logout y token revocado

**PM023; esperado y obtenido: HTTP 401.** El logout devuelve 200 y la consulta posterior con el token revocado recibe 401. Se ven la respuesta y los checks del Runner.

![PM023: Logout y token revocado](hu002-token-revocado.png)

## #40 · Solicitud de recuperación

**PM035; esperado y obtenido: HTTP 200.** La API conserva la respuesta genérica al solicitar el enlace. Correo capturado en archivos locales, sin nueva entrega SMTP.

![PM035: Solicitud de recuperación](hu003-solicitud.png)

## #40 · Cambio de contraseña confirmado

**PM039; esperado y obtenido: HTTP 200.** Django confirma el cambio; el Runner conserva los checks de confirmación y de los rechazos posteriores.

![PM039: Cambio de contraseña confirmado](hu003-cambio-confirmado.png)

## #44 · Nombre recuperado en otra consulta

**PM051; esperado y obtenido: HTTP 200.** Una nueva consulta devuelve el nombre actualizado. La prueba se realizó con la cuenta ficticia propia.

![PM051: Nombre recuperado en otra consulta](hu004-nombre-persistente.png)

## #44 · Token anterior rechazado al cambiar contraseña

**PM057; esperado y obtenido: HTTP 401.** La consulta con el token anterior al cambio de contraseña es rechazada por Django.

![PM057: Token anterior rechazado al cambiar contraseña](hu004-token-anterior.png)

## #44 · Eliminación de la cuenta desechable

**PM209; esperado y obtenido: HTTP 200.** La cuenta ficticia desechable se elimina con contraseña y confirmación explícita.

![PM209: Eliminación de la cuenta desechable](hu004-eliminacion.png)

## #44 · Sesión de cuenta eliminada rechazada

**PM210; esperado y obtenido: HTTP 401.** La consulta posterior con el token de la cuenta eliminada confirma que ya no autoriza acceso.

![PM210: Sesión de cuenta eliminada rechazada](hu004-cuenta-eliminada-401.png)

## #45 · Preferencia false persistida

**PM064; esperado y obtenido: HTTP 200.** Otra petición GET conserva el booleano false; se muestran respuesta y comprobaciones en Postman.

![PM064: Preferencia false persistida](hu004-preferencia-persistente.png)

## #48 · Resumen del candidato

**PM081; esperado y obtenido: HTTP 200.** La respuesta real devuelve completitud 83 %, métricas 2/1/2 y trabajos publicados de la base de QA.

![PM081: Resumen del candidato](hu005-resumen.png)

## #52 · Resumen de empresa

**PM084; esperado y obtenido: HTTP 200.** La empresa aprobada recibe sus dos ofertas activas y dos postulaciones, sin actividad de otra empresa.

![PM084: Resumen de empresa](hu006-resumen.png)

## #56 · Resumen administrativo

**PM086; esperado y obtenido: HTTP 200.** Django devuelve los cuatro candidatos, tres empresas y cero solicitudes completas pendientes del estado inicial de QA.

![PM086: Resumen administrativo](hu007-resumen.png)

## #60 · Educación editada y recuperada

**PM100; esperado y obtenido: HTTP 200.** La consulta independiente devuelve la edición del registro estructurado de educación.

![PM100: Educación editada y recuperada](hu008-educacion-persistente.png)

## #60 · Otro candidato no modifica el registro

**PM102; esperado y obtenido: HTTP 404.** Se intenta modificar el registro ajeno con otra cuenta; Django no lo expone y devuelve 404.

![PM102: Otro candidato no modifica el registro](hu008-permisos.png)

## #60 · Fotografía corrupta rechazada

**PM138; esperado y obtenido: HTTP 400.** Postman envía el archivo corrupto multipart y muestra la validación real de Django.

![PM138: Fotografía corrupta rechazada](hu008-foto-invalida.png)

## #64 · Información empresarial persistida

**PM165; esperado y obtenido: HTTP 200.** Los seis datos ficticios guardados se recuperan en una nueva consulta.

![PM165: Información empresarial persistida](hu009-informacion-persistente.png)

## #68 · Rechazo con motivo y aviso

**PM180; esperado y obtenido: HTTP 200.** La empresa consulta el estado rechazado, el motivo y la notificación guardada.

![PM180: Rechazo con motivo y aviso](hu010-rechazo-notificado.png)

## #68 · Aprobación administrativa

**PM186; esperado y obtenido: HTTP 200.** La respuesta acredita estado approved, responsable administrativo y fecha de revisión.

![PM186: Aprobación administrativa](hu010-aprobacion.png)

## #68 · Decisión con versión obsoleta

**PM187; esperado y obtenido: HTTP 409.** El intento de sobrescribir una decisión mediante una versión anterior se rechaza con conflicto.

![PM187: Decisión con versión obsoleta](hu010-version-obsoleta.png)

## #44 · Segunda pasada desde otra base inicial

**PM210; esperado y obtenido: HTTP 401.** El último bloque de la segunda pasada termina sin fallos; la cuenta desechable eliminada ya no permite consultar la API.

![PM210: Segunda pasada desde otra base inicial](segunda-ejecucion.png)
