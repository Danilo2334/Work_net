# Correo real — registro verificado y recuperación en curso

19/10/2026, America/Bogota. QA registrado como **Danilo2334**; comprobaciones automáticas por agente. El usuario aportó el enlace del mensaje de registro recibido. No se accedió directamente a su buzón y esto no se registra como revisión de código por otro integrante. [Resultados sanitizados](smtp-real.json).

| Caso / etapa | Esperado | Obtenido | Tipo de evidencia |
| --- | --- | --- | --- |
| Credenciales locales | Privadas y fuera de Git | `.env` ignorado; `.env.example` sin valores privados | Comprobación local |
| Conexión Gmail | TLS y autenticación correctos | Correctos | SMTP real |
| Crear cuenta y después elegir rol | HTTP 201, después HTTP 200 | 201 y 200 | Flutter → API, SMTP real |
| Recepción del mensaje de registro | Mensaje accesible por el usuario | Usuario aportó el enlace firmado de su mensaje | Evidencia del usuario; sin inspección directa del buzón |
| Abrir el enlace recibido | HTTP 200 | HTTP 200 | API sobre el enlace aportado, ejecutada por agente |
| Persistencia de la verificación | `email_verified=true` | `true` en SQLite independiente | Consulta directa de la base de QA |
| Login después de verificar | HTTP 200 | HTTP 200 en API y desde Flutter | API + navegador |
| Destino del candidato | Dashboard autenticado | HTTP 200 y dashboard candidato en Flutter | API + navegador |
| Logout | Revocar el token utilizado | HTTP 200; ese token después recibe 401 | Flutter + API |
| Solicitar recuperación | HTTP 200 y envío SMTP sin error | HTTP 200 desde Flutter; SMTP real aceptó el mensaje de la cuenta existente | Navegador + API |
| Recepción/apertura de recuperación | Mensaje recibido y enlace válido | Pendiente del usuario | No acreditado todavía |
| Cambiar contraseña y probar nueva/anterior | Nueva aceptada, anterior rechazada | Pendiente con el correo real | La prueba anterior a archivos se conserva separada |

El recorrido usa una SQLite nueva separada de la base habitual y de la QA a archivos. Django: `127.0.0.1:8007`; Flutter: `localhost:55007`. Solo ese proceso configura recuperación hacia `http://localhost:55007/reset-password`; la configuración local ordinaria conserva 55000. Código de producto sin cambios: backend `f9e4dea`, Flutter `04e7e5c`.

Los **50 casos de navegador/API**, **49 HTTP adicionales**, **77 pruebas Flutter** y **103 Django** de la fase anterior conservan su fecha y alcance; no se reejecutaron ni se suman a estos pasos SMTP. Las imágenes existentes corresponden a datos ficticios y correo local; no se usan como capturas del buzón real. Los errores SMTP y vencimientos ya tienen pruebas automáticas, identificadas en el informe anterior.

No se publican destinatario/remitente reales, contraseña, enlace firmado, tokens, correo ni base. El enlace aportado se guardó solo en un auxiliar privado ignorado. El build web SMTP se generó con ruta absoluta después de corregir un error de escritura de shaders por la ruta relativa, sin modificar la aplicación. No se acredita WASM ni ejecución nativa.

**Estado:** registro real/verificación/login disponibles para revisión de #31/#32/#33. Recuperación real #40/#41/#42 pendiente de recepción, cambio y login; la solicitud ya fue enviada. Revisión humana de código todavía pendiente; PR #146 debe permanecer en borrador y sin fusionar. No se cierran issues ni se alteran criterios, Sprints o fechas.
