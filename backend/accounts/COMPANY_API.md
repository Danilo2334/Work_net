# Empresa, registro y sesión

Implementación de las dependencias #64/#68, resúmenes #52/#56 y ajustes de
#30–#33/#35/#36/#38. Publicación backend: Danilo2334. Revisión humana pendiente.
La pertenencia a Sprint 2 no se ha confirmado: GitHub CLI carece de `read:project`.
Se implementa el alcance autorizado en las issues, sin reasignarlas ni cerrarlas.

## Registro y correo

El formulario público crea primero la cuenta con `POST /api/register/`, sin rol.
HTTP 201 devuelve `user.role: ""` y una autorización firmada `registration_token`
de propósito limitado, distinta del token de sesión. El selector posterior llama
`POST /api/register/role/` con esa autorización y `role: candidato|empresa`.
Solo se permite asignarlo una vez, nunca administrador. Para clientes anteriores,
se conserva el registro que ya enviaba un rol público en el primer POST.

La autorización de selección vence en 24 horas. Si se pierde o vence, después de
verificar el correo se puede iniciar sesión con rol `unassigned` y seleccionar
el rol con la autenticación de esa cuenta. Esto evita dejar cuentas sin salida.
La autorización de registro no permite consultar cuenta, dashboard ni perfil.

Django instalado: 6.1.1; se conserva `MAILERS`, Gmail TLS/587 y timeout de 15 s.
Las variables `GMAIL_USER`, `GMAIL_APP_PASSWORD` y `PASSWORD_RESET_FRONTEND_URL`
pertenecen a `backend/.env`, ignorado por Git. El ejemplo no contiene credenciales.
Un error SMTP/red conocido produce HTTP 503 con un mensaje controlado. En
registro, la transacción revierte la creación para permitir volver a intentarlo.
La recuperación devuelve el error sin cambiar la contraseña. Los casos sin fallo
mantienen su respuesta genérica. Los tests no envían correo real.

La configuración privada quedó completada y los recorridos de registro y
recuperación mediante SMTP real están comprobados en una SQLite independiente.
El usuario aportó los dos enlaces recibidos; el agente comprobó verificación
persistida, cambio de contraseña, login/dashboard desde Flutter y revocación.
No se accedió directamente al buzón ni se registró revisión humana del código.
[Resultados sanitizados y alcance](../docs/evidencias/revision-sprint/SMTP.md).
Un 201, un SMTP aceptado o correo a archivos por sí solos no acreditan recepción.
No se publican autorizaciones, contraseñas ni enlaces firmados.

<details>
<summary>Historial: pendiente de correo anterior a la comprobación SMTP</summary>

Falta configurar `.env` y acreditar recepción real en el buzón indicado por el
usuario. Un 201, un SMTP aceptado o correo a archivos no acreditan esa recepción.
No se publican autorizaciones, contraseñas ni enlaces firmados.

</details>

## Sesión

`POST /api/logout/` exige `Authorization: Token <sesión>` y elimina el token usado.
Devuelve HTTP 200; la siguiente consulta con ese token recibe 401. Un cierre local
por pérdida de sesión no se presenta como una revocación remota confirmada.
Login y configuración exponen el rol efectivo `admin` de staff/superusuario.
Para empresa, login añade `user.company_state`: pending/approved/rejected.

## Empresa y revisión

| Método y ruta | Alcance |
| --- | --- |
| GET /api/company/ | Información/estado propios y avisos de la cuenta |
| PATCH /api/company/ | Guardar razón social, NIT, sector, ubicación, correo de contacto y descripción |
| POST /api/company/submit/ | Exigir datos completos y enviar solicitud a revisión |
| GET /api/admin/companies/?page=1 | Solicitudes completas pendientes; 20 por página, solo administrador |
| POST /api/admin/companies/{id}/review/ | Aprobar/rechazar con decisión y versión; motivo obligatorio al rechazar |
| GET /api/dashboard/company/ | Métricas y postulaciones recientes propias, solo empresa aprobada |
| GET /api/dashboard/admin/ | Conteos, avisos y eventos de validación, solo administrador |
| PUT/GET/DELETE /api/company/logo/ | Logo propio opcional después de aprobación; JPEG/PNG privado |

El estado inicial es Pendiente y `submitted: false`; todavía no es una solicitud
completa para el listado administrativo. El envío válido fija `submitted: true`,
notifica a administradores activos y bloquea modificaciones durante la revisión.
Un rechazo conserva el motivo para que la empresa corrija y vuelva a enviar.
Una aprobación habilita el resumen empresarial. No se aprueba a sí misma ni puede
modificar otra cuenta: los endpoints de empresa siempre usan al usuario autenticado.

La decisión requiere `decision: approved|rejected`, `version` del listado y, al
rechazar, `reason` no vacío de hasta 2000 caracteres. Se registra administrador,
fecha y copia de los datos revisados. Una decisión sobre versión/estado obsoletos
devuelve 409. Las notificaciones del resultado son **avisos persistidos dentro
de WorkNet**, no correos cuya recepción se atribuya a SMTP.

El NIT admite de 6 a 15 dígitos y un dígito de verificación opcional separado por
guion; es único si está informado. Correo y URL tienen validación de formato.
Después de aprobar se puede editar `website` y `social_links` (hasta 10 URL),
y cargar/eliminar logo. Los datos básicos aprobados quedan protegidos.
Logo usa la validación de imagen ya existente del perfil: 2 MiB, JPEG/PNG estático,
4096 px/lado, 16 MP, recodificación sin metadatos. Lectura autenticada y no-store;
una imagen inválida conserva la anterior. No se crea una URL pública.

Las métricas empresariales filtran ofertas y postulaciones por propietario.
Ofertas activas: publicadas y no vencidas. Cerradas: estado `closed`.
El resumen administrativo no permite intervenir en postulaciones. La gestión de
ofertas/postulantes, mensajes, estadísticas y administración de permisos siguen
fuera de este bloque y deben conservarse como dependencias pendientes.
El acceso empresarial autorizado al perfil del candidato continúa restringido
hasta que exista el proceso de selección correspondiente.

## Migraciones y pruebas

Aplicar las migraciones aditivas de accounts 0003/0004 en cada entorno actualizado.
Los datos y roles anteriores se conservan. No se requiere reiniciar la base.

```powershell
python manage.py migrate
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test accounts candidate_dashboard --noinput
```

Las pruebas utilizan bases temporales y correo de memoria: **103 aprobadas** en
esta fase. Incluyen la regresión anterior, rol posterior, errores de envío,
logout remoto, solicitud completa/incompleta, persistencia, NIT duplicado,
autoaprobación/acceso cruzado rechazados, motivo, corrección/reenvío, decisión
obsoleta, notificaciones/eventos, métricas por propietario y logo privado/inválido.
Los recorridos de Flutter y sus capturas se documentan en su entrega correspondiente.
