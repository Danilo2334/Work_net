# Guía para revisar WorkNet

Actualización: 19/10/2026. Código Flutter `04e7e5c`; backend `f9e4dea`.
La aplicación y sus pruebas están preparadas para revisión humana. El PR #146 sigue en borrador.

## Abrir una demostración aislada

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

La configuración privada ya se completó en esta sesión: TLS/autenticación y registro HTTP 201 con SMTP real comprobados en una SQLite separada (Django 8007, Flutter 55007). Falta acreditar recepción efectiva en el buzón, abrir ambos correos recibidos (registro y recuperación) y completar sus recorridos. Una respuesta SMTP aceptada no demuestra recepción. Las evidencias públicas deben ocultar tokens y enlaces firmados.

## Pendientes que deben decirse claramente

- Falta acceso `read:project` para confirmar qué issues pertenecen realmente al Sprint 2. La rama no define ese alcance; no se modificaron Sprint ni fechas.
- SMTP ya autentica y acepta el registro; recepción en buzón, apertura y recuperación real siguen pendientes del usuario.
- Dashboard candidato: CV, búsqueda, mensajes, historial y detalle/postulación pertenecen a módulos todavía ausentes.
- Dashboard empresa: crear/gestionar ofertas, gestionar postulantes, mensajes y estadísticas siguen pendientes. Las métricas y postulaciones recientes sí usan datos reales.
- Administración: gestión de administradores y permisos pendiente. Revisión de empresas, métricas y eventos de validación sí están implementados.
- Perfil candidato: falta consulta positiva por empresas con autorización dentro de selección. Hoy se conserva el acceso restringido; un HTTP 403 no cumple ese criterio positivo.
- Revisión por otro integrante y validación nativa pendientes. Ninguna prueba automática se registra como aprobación humana.

[Resultados y capturas de esta fase](evidencias/revision-sprint/README.md). [Contratos empresariales](../../backend/accounts/COMPANY_API.md). [PR #146](https://github.com/Danilo2334/Work_net/pull/146).
