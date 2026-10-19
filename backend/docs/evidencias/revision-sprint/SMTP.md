# Correo real — avance separado de las pruebas a archivos

Actualización del **19/10/2026**, posterior a los 49 casos HTTP de `resultados-api.json`. QA registrado como Danilo2334; ejecución automatizada por agente. [Resultado sanitizado](smtp-real.json).

| Etapa | Resultado comprobado |
| --- | --- |
| Credenciales locales | Guardadas en `backend/.env`, ignorado y sin versionar; `.env.example` conserva solo ejemplos |
| Conexión Gmail | TLS y autenticación SMTP correctos |
| Registro desde Flutter | HTTP 201 con backend SMTP real, sin captura a archivos |
| Selección posterior de rol | Candidato, HTTP 200 |
| Envío del registro | Aceptado sin error SMTP; esto **no demuestra recepción** |
| Llegada a bandeja/spam | Pendiente de confirmación del usuario |
| Abrir enlace del mensaje recibido | Pendiente |
| `email_verified=true` y login posterior | Pendientes; la consulta inicial confirmó `false` |
| Recuperación con recepción real y cambio de contraseña | Pendiente de completar con el usuario |

Se usó una SQLite nueva e independiente de la base habitual y de la anterior QA a archivos. Django se ejecuta en 127.0.0.1:8007 y Flutter en localhost:55007; solo ese proceso usa `PASSWORD_RESET_FRONTEND_URL=http://localhost:55007/reset-password`. La configuración local ordinaria conserva el origen 55000. El código de aplicación es el mismo `f9e4dea`/`04e7e5c`.

El build web para SMTP se generó correctamente con salida absoluta. El primer intento con salida relativa fuera de `frontend` falló al escribir shaders; se corrigió la ruta de salida, sin cambiar código de producto. No se acredita compatibilidad WASM.

No se publican destinatario real, remitente, contraseñas, enlaces firmados, buzón ni SQLite. La evidencia de correo a archivos sigue identificada como tal y no se convierte en recepción real por haber habilitado SMTP después. Mantener #31/#32/#33 y #40/#41/#42 pendientes en sus criterios de correo recibido, así como revisión humana pendiente.
