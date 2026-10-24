# Casos de la colección

Generado por `python backend/postman/build_collection.py`. Cada petición conserva preparación, encabezados, cuerpo y scripts en la colección importable.

| Caso | Tarea | Objetivo | Método y ruta | Esperado |
|---|---|---|---|---|
| PM001 | #30 | Campos obligatorios ausentes | `POST register/` | HTTP 400. Rechazo con explicación en JSON. |
| PM002 | #30 | Correo inválido | `POST register/` | HTTP 400. Rechazo con explicación en JSON. |
| PM003 | #30 | Contraseñas diferentes | `POST register/` | HTTP 400. Rechazo con explicación en JSON. |
| PM004 | #30 | Contraseña débil | `POST register/` | HTTP 400. Rechazo con explicación en JSON. |
| PM005 | #30 | No se permite registrar administrador | `POST register/` | HTTP 400. Rechazo con explicación en JSON. |
| PM006 | #30 | Registro sin rol previo | `POST register/` | HTTP 201. Cuenta sin rol y correo todavía no verificado; ticket limitado presente |
| PM007 | #30 | Correo duplicado sin distinguir mayúsculas | `POST register/` | HTTP 400. Error de correo en español |
| PM008 | #30 | Ticket inválido para elegir rol | `POST register/role/` | HTTP 400. Rechazo con explicación en JSON. |
| PM009 | #30 | Ticket no permite elegir administrador | `POST register/role/` | HTTP 400. Rechazo con explicación en JSON. |
| PM010 | #30 | Candidato elegido después del registro | `POST register/role/` | HTTP 200. Rol candidato guardado |
| PM011 | #30 | No se permite reasignar el rol | `POST register/role/` | HTTP 409. Rechazo con explicación en JSON. |
| PM012 | #35 | Login sin verificar rechazado | `POST login/` | HTTP 400. Rechazo con explicación en JSON. |
| PM013 | #31 | Verificación sin enlace | `GET verify-email/` | HTTP 400. Rechazo con explicación en JSON. |
| PM014 | #31 | Firma inválida | `GET verify-email/?token=invalido-qa` | HTTP 400. Rechazo con explicación en JSON. |
| PM015 | #31 | Verificación con enlace del correo capturado | `GET verify-email/?token={{verification_token}}` | HTTP 200. Correo verificado correctamente |
| PM016 | #31 | Repetición de verificación idempotente | `GET verify-email/?token={{verification_token}}` | HTTP 200. Verificación repetida reconocida |
| PM017 | #35 | Login sin datos | `POST login/` | HTTP 400. Rechazo con explicación en JSON. |
| PM018 | #35 | Contraseña incorrecta | `POST login/` | HTTP 400. Rechazo con explicación en JSON. |
| PM019 | #35 | Login después de verificar acredita persistencia | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM020 | #30 | Consulta conserva el rol y la verificación | `GET account/` | HTTP 200. Rol y verificación persistentes |
| PM021 | #35 | Logout sin autenticación | `POST logout/` | HTTP 401. Rechazo con explicación en JSON. |
| PM022 | #35 | Logout revoca el token utilizado | `POST logout/` | HTTP 200. Respuesta JSON válida. |
| PM023 | #35 | Token revocado recibe 401 | `GET account/` | HTTP 401. Rechazo con explicación en JSON. |
| PM024 | #35 | Nuevo login después de logout | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM025 | #35 | Login de candidate | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM026 | #35 | Login de other | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM027 | #35 | Login de company | `POST login/` | HTTP 200. Token real y cuenta verificada; estado approved |
| PM028 | #35 | Login de draft | `POST login/` | HTTP 200. Token real y cuenta verificada; estado pending |
| PM029 | #35 | Login de other_company | `POST login/` | HTTP 200. Token real y cuenta verificada; estado pending |
| PM030 | #35 | Login de admin | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM031 | #35 | Login de disposable | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM032 | #40 | Solicitud sin correo | `POST password-recovery/request/` | HTTP 400. Rechazo con explicación en JSON. |
| PM033 | #40 | Solicitud con correo inválido | `POST password-recovery/request/` | HTTP 400. Rechazo con explicación en JSON. |
| PM034 | #40 | Correo desconocido recibe respuesta genérica | `POST password-recovery/request/` | HTTP 200. Respuesta JSON válida. |
| PM035 | #40 | Solicitud válida captura un correo local | `POST password-recovery/request/` | HTTP 200. Respuesta no revela si existe la cuenta |
| PM036 | #40 | Enlace inválido | `POST password-recovery/confirm/` | HTTP 400. Rechazo con explicación en JSON. |
| PM037 | #40 | Contraseñas nuevas diferentes | `POST password-recovery/confirm/` | HTTP 400. Rechazo con explicación en JSON. |
| PM038 | #40 | Nueva contraseña débil | `POST password-recovery/confirm/` | HTTP 400. Rechazo con explicación en JSON. |
| PM039 | #40 | Cambio mediante enlace del correo capturado | `POST password-recovery/confirm/` | HTTP 200. Cambio confirmado |
| PM040 | #40 | Enlace usado rechazado | `POST password-recovery/confirm/` | HTTP 400. Rechazo con explicación en JSON. |
| PM041 | #40 | Token anterior al cambio revocado | `GET account/` | HTTP 401. Rechazo con explicación en JSON. |
| PM042 | #40 | Contraseña anterior rechazada | `POST login/` | HTTP 400. Rechazo con explicación en JSON. |
| PM043 | #40 | Login con nueva contraseña acredita persistencia | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM044 | #44 | Cuenta sin token | `GET account/` | HTTP 401. Rechazo con explicación en JSON. |
| PM045 | #44 | Cuenta con token inválido | `GET account/` | HTTP 401. Rechazo con explicación en JSON. |
| PM046 | #44 | Consultar propia cuenta | `GET account/` | HTTP 200. Solo datos públicos de la cuenta propia |
| PM047 | #44 | Nombre vacío rechazado | `PATCH account/` | HTTP 400. Rechazo con explicación en JSON. |
| PM048 | #44 | Correo rol y verificación no son editables | `PATCH account/` | HTTP 400. Rechazo con explicación en JSON. |
| PM049 | #44 | No se permite indicar otro propietario | `PATCH account/` | HTTP 400. Rechazo con explicación en JSON. |
| PM050 | #44 | Actualizar nombre propio | `PATCH account/` | HTTP 200. Nombre actualizado |
| PM051 | #44 | Nueva consulta conserva el nombre | `GET account/` | HTTP 200. Nombre persistido |
| PM052 | #44 | Otro usuario conserva sus datos | `GET account/?user_id={{candidate_id}}` | HTTP 200. No se consulta una cuenta ajena mediante parámetros |
| PM053 | #44 | Contraseña actual incorrecta | `POST account/password/` | HTTP 400. Rechazo con explicación en JSON. |
| PM054 | #44 | Confirmación de contraseña diferente | `POST account/password/` | HTTP 400. Rechazo con explicación en JSON. |
| PM055 | #44 | Contraseña nueva débil | `POST account/password/` | HTTP 400. Rechazo con explicación en JSON. |
| PM056 | #44 | Cambio devuelve token nuevo | `POST account/password/` | HTTP 200. Token nuevo distinto del anterior |
| PM057 | #44 | Token anterior rechazado | `GET account/` | HTTP 401. Rechazo con explicación en JSON. |
| PM058 | #44 | Token nuevo autorizado | `GET account/` | HTTP 200. Cuenta propia accesible |
| PM059 | #44 | Contraseña antigua rechazada tras cambio | `POST login/` | HTTP 400. Rechazo con explicación en JSON. |
| PM060 | #44 | Nuevo login conserva el cambio de contraseña | `POST login/` | HTTP 200. Token real y cuenta verificada |
| PM061 | #45 | Preferencias sin autenticación | `GET account/notifications/` | HTTP 401. Rechazo con explicación en JSON. |
| PM062 | #45 | Preferencia inicial activada | `GET account/notifications/` | HTTP 200. Valor inicial booleano true |
| PM063 | #45 | Desactivar notificaciones | `PATCH account/notifications/` | HTTP 200. Booleano false guardado |
| PM064 | #45 | False permanece en una nueva consulta | `GET account/notifications/` | HTTP 200. Persistencia de false |
| PM065 | #45 | Otra cuenta no hereda la preferencia | `GET account/notifications/` | HTTP 200. Segunda cuenta permanece en true |
| PM066 | #45 | Texto false no es booleano | `PATCH account/notifications/` | HTTP 400. Rechazo con explicación en JSON. |
| PM067 | #45 | Número cero no es booleano | `PATCH account/notifications/` | HTTP 400. Rechazo con explicación en JSON. |
| PM068 | #45 | Campo ajeno rechazado | `PATCH account/notifications/` | HTTP 400. Rechazo con explicación en JSON. |
| PM069 | #45 | Los errores no alteran la preferencia | `GET account/notifications/` | HTTP 200. False sigue guardado |
| PM070 | #45 | Activar notificaciones | `PATCH account/notifications/` | HTTP 200. Booleano true guardado |
| PM071 | #45 | True permanece en una nueva consulta | `GET account/notifications/` | HTTP 200. Persistencia de true |
| PM072 | #48 | Resumen sin autenticación | `GET dashboard/candidate/` | HTTP 401. Rechazo con explicación en JSON. |
| PM073 | #48 | Resumen con token inválido | `GET dashboard/candidate/` | HTTP 401. Rechazo con explicación en JSON. |
| PM074 | #48 | Resumen restringido al rol correcto | `GET dashboard/candidate/` | HTTP 403. Rechazo con explicación en JSON. |
| PM075 | #52 | Resumen sin autenticación | `GET dashboard/company/` | HTTP 401. Rechazo con explicación en JSON. |
| PM076 | #52 | Resumen con token inválido | `GET dashboard/company/` | HTTP 401. Rechazo con explicación en JSON. |
| PM077 | #52 | Resumen restringido al rol correcto | `GET dashboard/company/` | HTTP 403. Rechazo con explicación en JSON. |
| PM078 | #56 | Resumen sin autenticación | `GET dashboard/admin/` | HTTP 401. Rechazo con explicación en JSON. |
| PM079 | #56 | Resumen con token inválido | `GET dashboard/admin/` | HTTP 401. Rechazo con explicación en JSON. |
| PM080 | #56 | Resumen restringido al rol correcto | `GET dashboard/admin/` | HTTP 403. Rechazo con explicación en JSON. |
| PM081 | #48 | Métricas y completitud del candidato principal | `GET dashboard/candidate/` | HTTP 200. 83 por ciento y métricas 2 1 2; dos trabajos publicados |
| PM082 | #48 | Segundo candidato vacío y separado | `GET dashboard/candidate/?user_id={{candidate_id}}` | HTTP 200. 17 por ciento y métricas propias en cero; ofertas globales válidas |
| PM083 | #48 | Resumen no admite escritura | `POST dashboard/candidate/` | HTTP 405. Rechazo con explicación en JSON. |
| PM084 | #52 | Empresa aprobada muestra su actividad real | `GET dashboard/company/` | HTTP 200. Dos ofertas activas y dos postulaciones propias |
| PM085 | #52 | Empresa pendiente no accede al resumen | `GET dashboard/company/` | HTTP 403. Rechazo con explicación en JSON. |
| PM086 | #56 | Resumen administrador con conteos de la base QA | `GET dashboard/admin/` | HTTP 200. Cuatro candidatos tres empresas y cero solicitudes completas |
| PM087 | #56 | Empresa no accede al resumen administrador | `GET dashboard/admin/` | HTTP 403. Rechazo con explicación en JSON. |
| PM088 | #60 | Perfil sin autenticación | `GET profile/candidate/` | HTTP 401. Rechazo con explicación en JSON. |
| PM089 | #60 | Empresa no consulta el perfil del candidato | `GET profile/candidate/` | HTTP 403. Rechazo con explicación en JSON. |
| PM090 | #60 | Perfil vacío sin creación implícita | `GET profile/candidate/` | HTTP 200. Perfil todavía inexistente |
| PM091 | #60 | Crear perfil propio | `POST profile/candidate/` | HTTP 201. Perfil creado sin foto obligatoria |
| PM092 | #60 | Crear perfil duplicado rechazado | `POST profile/candidate/` | HTTP 409. Rechazo con explicación en JSON. |
| PM093 | #60 | Modificar descripción profesional | `PATCH profile/candidate/` | HTTP 200. Descripción editada |
| PM094 | #60 | Descripción persiste al consultar | `GET profile/candidate/` | HTTP 200. Descripción recuperada |
| PM095 | #60 | No se permite cambiar propietario | `PATCH profile/candidate/` | HTTP 400. Rechazo con explicación en JSON. |
| PM096 | #60 | education: validar campos obligatorios | `POST profile/candidate/education/` | HTTP 400. Rechazo con explicación en JSON. |
| PM097 | #60 | education: agregar registro | `POST profile/candidate/education/` | HTTP 201. Registro estructurado con identificador real |
| PM098 | #60 | education: consultar registro persistido | `GET profile/candidate/education/{{education_id}}/` | HTTP 200. education conserva campos enviados |
| PM099 | #60 | education: editar registro | `PATCH profile/candidate/education/{{education_id}}/` | HTTP 200. Cambio en registro propio |
| PM100 | #60 | education: nueva consulta conserva edición | `GET profile/candidate/education/{{education_id}}/` | HTTP 200. Edición persistida |
| PM101 | #60 | education: otro candidato no lee el registro | `GET profile/candidate/education/{{education_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM102 | #60 | education: otro candidato no modifica el registro | `PATCH profile/candidate/education/{{education_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM103 | #60 | education: otro candidato no elimina el registro | `DELETE profile/candidate/education/{{education_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM104 | #60 | experience: validar campos obligatorios | `POST profile/candidate/experience/` | HTTP 400. Rechazo con explicación en JSON. |
| PM105 | #60 | experience: agregar registro | `POST profile/candidate/experience/` | HTTP 201. Registro estructurado con identificador real |
| PM106 | #60 | experience: consultar registro persistido | `GET profile/candidate/experience/{{experience_id}}/` | HTTP 200. experience conserva campos enviados |
| PM107 | #60 | experience: editar registro | `PATCH profile/candidate/experience/{{experience_id}}/` | HTTP 200. Cambio en registro propio |
| PM108 | #60 | experience: nueva consulta conserva edición | `GET profile/candidate/experience/{{experience_id}}/` | HTTP 200. Edición persistida |
| PM109 | #60 | experience: otro candidato no lee el registro | `GET profile/candidate/experience/{{experience_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM110 | #60 | experience: otro candidato no modifica el registro | `PATCH profile/candidate/experience/{{experience_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM111 | #60 | experience: otro candidato no elimina el registro | `DELETE profile/candidate/experience/{{experience_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM112 | #60 | skills: validar campos obligatorios | `POST profile/candidate/skills/` | HTTP 400. Rechazo con explicación en JSON. |
| PM113 | #60 | skills: agregar registro | `POST profile/candidate/skills/` | HTTP 201. Registro estructurado con identificador real |
| PM114 | #60 | skills: consultar registro persistido | `GET profile/candidate/skills/{{skills_id}}/` | HTTP 200. skills conserva campos enviados |
| PM115 | #60 | skills: editar registro | `PATCH profile/candidate/skills/{{skills_id}}/` | HTTP 200. Cambio en registro propio |
| PM116 | #60 | skills: nueva consulta conserva edición | `GET profile/candidate/skills/{{skills_id}}/` | HTTP 200. Edición persistida |
| PM117 | #60 | skills: otro candidato no lee el registro | `GET profile/candidate/skills/{{skills_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM118 | #60 | skills: otro candidato no modifica el registro | `PATCH profile/candidate/skills/{{skills_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM119 | #60 | skills: otro candidato no elimina el registro | `DELETE profile/candidate/skills/{{skills_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM120 | #60 | languages: validar campos obligatorios | `POST profile/candidate/languages/` | HTTP 400. Rechazo con explicación en JSON. |
| PM121 | #60 | languages: agregar registro | `POST profile/candidate/languages/` | HTTP 201. Registro estructurado con identificador real |
| PM122 | #60 | languages: consultar registro persistido | `GET profile/candidate/languages/{{languages_id}}/` | HTTP 200. languages conserva campos enviados |
| PM123 | #60 | languages: editar registro | `PATCH profile/candidate/languages/{{languages_id}}/` | HTTP 200. Cambio en registro propio |
| PM124 | #60 | languages: nueva consulta conserva edición | `GET profile/candidate/languages/{{languages_id}}/` | HTTP 200. Edición persistida |
| PM125 | #60 | languages: otro candidato no lee el registro | `GET profile/candidate/languages/{{languages_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM126 | #60 | languages: otro candidato no modifica el registro | `PATCH profile/candidate/languages/{{languages_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM127 | #60 | languages: otro candidato no elimina el registro | `DELETE profile/candidate/languages/{{languages_id}}/` | HTTP 404. Rechazo con explicación en JSON. |
| PM128 | #60 | Fechas invertidas rechazadas | `POST profile/candidate/education/` | HTTP 400. Rechazo con explicación en JSON. |
| PM129 | #60 | Nivel de idioma inválido | `POST profile/candidate/languages/` | HTTP 400. Rechazo con explicación en JSON. |
| PM130 | #60 | Dashboard refleja las seis secciones completas | `GET dashboard/candidate/` | HTTP 200. Completitud real de Django al cien sin fotografía |
| PM131 | #60 | Foto opcional ausente | `GET profile/candidate/photo/` | HTTP 404. Rechazo con explicación en JSON. |
| PM132 | #60 | Subir PNG válido | `PUT profile/candidate/photo/` | HTTP 200. Foto cargada |
| PM133 | #60 | Recuperar fotografía privada | `GET profile/candidate/photo/` | HTTP 200. JPEG privado sin caché y sin URL pública |
| PM134 | #60 | Fotografía sin autenticación rechazada | `GET profile/candidate/photo/` | HTTP 401. Rechazo con explicación en JSON. |
| PM135 | #60 | Otro candidato no recibe la fotografía ajena | `GET profile/candidate/photo/?user_id={{other_id}}` | HTTP 404. Rechazo con explicación en JSON. |
| PM136 | #60 | Empresa sin autorización no accede a foto | `GET profile/candidate/photo/` | HTTP 403. Rechazo con explicación en JSON. |
| PM137 | #60 | Extensión no admitida rechazado | `PUT profile/candidate/photo/` | HTTP 400. Rechazo con explicación en JSON. |
| PM138 | #60 | PNG corrupto rechazado | `PUT profile/candidate/photo/` | HTTP 400. Rechazo con explicación en JSON. |
| PM139 | #60 | Más de 4096 píxeles rechazado | `PUT profile/candidate/photo/` | HTTP 400. Rechazo con explicación en JSON. |
| PM140 | #60 | Más de dos MiB rechazado | `PUT profile/candidate/photo/` | HTTP 400. Rechazo con explicación en JSON. |
| PM141 | #60 | Errores de archivo conservan foto anterior | `GET profile/candidate/photo/` | HTTP 200. JPEG privado sin caché y sin URL pública |
| PM142 | #60 | Quitar fotografía opcional | `DELETE profile/candidate/photo/` | HTTP 200. Foto eliminada |
| PM143 | #60 | Nueva consulta confirma foto ausente | `GET profile/candidate/photo/` | HTTP 404. Rechazo con explicación en JSON. |
| PM144 | #60 | Quitar foto conserva completitud al cien | `GET dashboard/candidate/` | HTTP 200. Foto no participa en las seis secciones |
| PM145 | #60 | education: eliminar registro propio | `DELETE profile/candidate/education/{{education_id}}/` | HTTP 200. Sección vaciada |
| PM146 | #60 | education: consulta confirma eliminación | `GET profile/candidate/education/` | HTTP 200. Sin registros persistidos |
| PM147 | #60 | experience: eliminar registro propio | `DELETE profile/candidate/experience/{{experience_id}}/` | HTTP 200. Sección vaciada |
| PM148 | #60 | experience: consulta confirma eliminación | `GET profile/candidate/experience/` | HTTP 200. Sin registros persistidos |
| PM149 | #60 | skills: eliminar registro propio | `DELETE profile/candidate/skills/{{skills_id}}/` | HTTP 200. Sección vaciada |
| PM150 | #60 | skills: consulta confirma eliminación | `GET profile/candidate/skills/` | HTTP 200. Sin registros persistidos |
| PM151 | #60 | languages: eliminar registro propio | `DELETE profile/candidate/languages/{{languages_id}}/` | HTTP 200. Sección vaciada |
| PM152 | #60 | languages: consulta confirma eliminación | `GET profile/candidate/languages/` | HTTP 200. Sin registros persistidos |
| PM153 | #60 | Eliminar perfil propio | `DELETE profile/candidate/` | HTTP 200. Perfil eliminado |
| PM154 | #60 | Consulta confirma perfil eliminado | `GET profile/candidate/` | HTTP 200. Perfil permanece ausente |
| PM155 | #60 | Eliminar perfil conserva la cuenta | `GET account/` | HTTP 200. Cuenta del segundo candidato sigue vigente |
| PM156 | #60 | Otro perfil no fue alterado | `GET profile/candidate/` | HTTP 200. Resumen principal intacto |
| PM157 | #64 | Información empresarial sin autenticación | `GET company/` | HTTP 401. Rechazo con explicación en JSON. |
| PM158 | #64 | Candidato no usa información empresarial | `GET company/` | HTTP 403. Rechazo con explicación en JSON. |
| PM159 | #64 | Datos iniciales de empresa sin solicitud | `GET company/` | HTTP 200. Pendiente sin enviar y sin datos ajenos |
| PM160 | #64 | No se permite enviar información incompleta | `POST company/submit/` | HTTP 400. Rechazo con explicación en JSON. |
| PM161 | #64 | Correo de contacto inválido | `PATCH company/` | HTTP 400. Rechazo con explicación en JSON. |
| PM162 | #64 | NIT inválido | `PATCH company/` | HTTP 400. Rechazo con explicación en JSON. |
| PM163 | #64 | No se permite editar estado ni propietario | `PATCH company/` | HTTP 400. Rechazo con explicación en JSON. |
| PM164 | #64 | Guardar los seis datos empresariales | `PATCH company/` | HTTP 200. Datos completos guardados como borrador |
| PM165 | #64 | Nueva consulta conserva los datos empresariales | `GET company/` | HTTP 200. Persistencia de todos los datos |
| PM166 | #64 | Otra empresa no consulta datos de la solicitante | `GET company/?company={{company_profile_id}}` | HTTP 200. Información exclusivamente propia |
| PM167 | #64 | Otra empresa no puede duplicar NIT | `PATCH company/` | HTTP 400. Rechazo con explicación en JSON. |
| PM168 | #64 | Logo requiere aprobación previa | `PUT company/logo/` | HTTP 403. Rechazo con explicación en JSON. |
| PM169 | #64 | Enviar solicitud completa | `POST company/submit/` | HTTP 200. Solicitud pendiente y enviada con versión real |
| PM170 | #64 | Solicitud enviada bloquea edición | `PATCH company/` | HTTP 400. Rechazo con explicación en JSON. |
| PM171 | #64 | Solicitud no se envía dos veces | `POST company/submit/` | HTTP 400. Rechazo con explicación en JSON. |
| PM172 | #68 | Listado de solicitudes sin autenticación | `GET admin/companies/` | HTTP 401. Rechazo con explicación en JSON. |
| PM173 | #68 | Candidato no consulta solicitudes administrativas | `GET admin/companies/` | HTTP 403. Rechazo con explicación en JSON. |
| PM174 | #68 | Empresa no puede aprobarse | `POST admin/companies/{{company_profile_id}}/review/` | HTTP 403. Rechazo con explicación en JSON. |
| PM175 | #68 | Administrador consulta solicitud completa | `GET admin/companies/` | HTTP 200. Listado contiene la solicitud y sus datos completos |
| PM176 | #56 | Dashboard cuenta y notifica solicitud pendiente | `GET dashboard/admin/` | HTTP 200. Una solicitud pendiente y notificación persistida |
| PM177 | #68 | Rechazo sin motivo no modifica solicitud | `POST admin/companies/{{company_profile_id}}/review/` | HTTP 400. Rechazo con explicación en JSON. |
| PM178 | #68 | Decisión inválida rechazada | `POST admin/companies/{{company_profile_id}}/review/` | HTTP 400. Rechazo con explicación en JSON. |
| PM179 | #68 | Rechazar solicitud con motivo y responsable | `POST admin/companies/{{company_profile_id}}/review/` | HTTP 200. Rechazo con motivo revisor y fecha |
| PM180 | #68 | Empresa consulta rechazo y notificación persistidos | `GET company/` | HTTP 200. Motivo y notificación conservados |
| PM181 | #35 | Login informa empresa rechazada | `POST login/` | HTTP 200. Token real y cuenta verificada; estado rejected |
| PM182 | #52 | Empresa rechazada no accede al dashboard | `GET dashboard/company/` | HTTP 403. Rechazo con explicación en JSON. |
| PM183 | #68 | Corregir datos de la empresa rechazada | `PATCH company/` | HTTP 200. Sede corregida |
| PM184 | #68 | Reenviar solicitud corregida | `POST company/submit/` | HTTP 200. Pendiente nuevamente y motivo anterior limpiado |
| PM185 | #68 | Nueva consulta confirma corrección y reenvío | `GET admin/companies/` | HTTP 200. Administrador recibe la sede corregida con nueva versión |
| PM186 | #68 | Aprobar solicitud corregida | `POST admin/companies/{{company_profile_id}}/review/` | HTTP 200. Aprobación con responsable administrativo |
| PM187 | #68 | Decisión obsoleta no sobrescribe aprobación | `POST admin/companies/{{company_profile_id}}/review/` | HTTP 409. Rechazo con explicación en JSON. |
| PM188 | #68 | Empresa consulta aprobación notificada | `GET company/` | HTTP 200. Aprobación y notificación persistidas |
| PM189 | #35 | Login informa empresa aprobada | `POST login/` | HTTP 200. Token real y cuenta verificada; estado approved |
| PM190 | #52 | Empresa recién aprobada no hereda actividad ajena | `GET dashboard/company/` | HTTP 200. Métricas propias vacías |
| PM191 | #56 | Dashboard conserva historial real de revisión | `GET dashboard/admin/` | HTTP 200. Cero pendientes e historial de envío rechazo y aprobación |
| PM192 | #64 | Datos aprobados protegidos | `PATCH company/` | HTTP 400. Rechazo con explicación en JSON. |
| PM193 | #64 | Completar sitio web y redes de empresa aprobada | `PATCH company/` | HTTP 200. Sitio web guardado |
| PM194 | #64 | Sitio y redes persisten al consultar | `GET company/` | HTTP 200. Sitio y redes persistentes |
| PM195 | #64 | Cargar logo después de aprobación | `PUT company/logo/` | HTTP 200. Logo guardado |
| PM196 | #64 | Consultar logo privado | `GET company/logo/` | HTTP 200. JPEG privado sin caché y sin URL pública |
| PM197 | #64 | Logo sin autenticación rechazado | `GET company/logo/` | HTTP 401. Rechazo con explicación en JSON. |
| PM198 | #64 | Otra empresa no recibe el logo ajeno | `GET company/logo/?company={{company_profile_id}}` | HTTP 403. Rechazo con explicación en JSON. |
| PM199 | #64 | Logo corrupto rechazado | `PUT company/logo/` | HTTP 400. Rechazo con explicación en JSON. |
| PM200 | #64 | Logo previo conservado tras error | `GET company/logo/` | HTTP 200. JPEG privado sin caché y sin URL pública |
| PM201 | #64 | Eliminar logo opcional | `DELETE company/logo/` | HTTP 200. Logo eliminado |
| PM202 | #64 | Nueva consulta confirma ausencia de logo | `GET company/logo/` | HTTP 404. Rechazo con explicación en JSON. |
| PM203 | #44 | Eliminación sin autenticación | `DELETE account/delete/` | HTTP 401. Rechazo con explicación en JSON. |
| PM204 | #44 | Eliminación sin confirmación | `DELETE account/delete/` | HTTP 400. Rechazo con explicación en JSON. |
| PM205 | #44 | Eliminación cancelada con false | `DELETE account/delete/` | HTTP 400. Rechazo con explicación en JSON. |
| PM206 | #44 | Texto true no confirma eliminación | `DELETE account/delete/` | HTTP 400. Rechazo con explicación en JSON. |
| PM207 | #44 | Contraseña incorrecta impide eliminación | `DELETE account/delete/` | HTTP 400. Rechazo con explicación en JSON. |
| PM208 | #44 | Errores y cancelación conservan la cuenta | `GET account/` | HTTP 200. Cuenta desechable sigue existiendo |
| PM209 | #44 | Eliminar con contraseña y true explícito | `DELETE account/delete/` | HTTP 200. Eliminación confirmada |
| PM210 | #44 | Token de cuenta eliminada rechazado | `GET account/` | HTTP 401. Rechazo con explicación en JSON. |
| PM211 | #44 | Cuenta eliminada ya no inicia sesión | `POST login/` | HTTP 400. Rechazo con explicación en JSON. |
| PM212 | #44 | Eliminar una cuenta no afecta a otra | `GET account/` | HTTP 200. Candidato principal permanece intacto |
| PM213 | #60 | Obtener postulación propia desde el dashboard empresarial | `GET dashboard/company/` | HTTP 200. Dos postulaciones propias con identificador real |
| PM214 | #60 | Empresa dueña consulta el perfil del postulante | `GET company/applications/{{selection_application_id}}/profile/` | HTTP 200. Perfil correcto sin datos de acceso ni preferencias |
| PM215 | #60 | Consulta sin sesión rechazada | `GET company/applications/{{selection_application_id}}/profile/` | HTTP 401. Rechazo con explicación en JSON. |
| PM216 | #60 | Candidato no usa la ruta empresarial | `GET company/applications/{{selection_application_id}}/profile/` | HTTP 403. Rechazo con explicación en JSON. |
| PM217 | #60 | Administrador no usa la ruta empresarial | `GET company/applications/{{selection_application_id}}/profile/` | HTTP 403. Rechazo con explicación en JSON. |
| PM218 | #60 | Empresa pendiente no consulta postulantes | `GET company/applications/{{selection_application_id}}/profile/` | HTTP 403. Rechazo con explicación en JSON. |
| PM219 | #60 | Otra empresa aprobada no consulta la postulación ajena | `GET company/applications/{{selection_application_id}}/profile/` | HTTP 404. Rechazo con explicación en JSON. |
| PM220 | #60 | Postulación inexistente no revela otros candidatos | `GET company/applications/999999999/profile/` | HTTP 404. Misma respuesta para postulación ajena e inexistente |
| PM221 | #60 | Parámetros ajenos no cambian el candidato autorizado | `GET company/applications/{{selection_application_id}}/profile/?candidate={{other_id}}&company={{draft_id}}` | HTTP 200. Consulta sigue limitada a la postulación propia |
| PM222 | #60 | Empresa no recibe foto que aún no existe | `GET company/applications/{{selection_application_id}}/profile/photo/` | HTTP 404. Rechazo con explicación en JSON. |
| PM223 | #60 | Candidato agrega foto para la consulta de selección | `PUT profile/candidate/photo/` | HTTP 200. Fotografía guardada por su propietario |
| PM224 | #60 | Empresa dueña recibe la foto privada del postulante | `GET company/applications/{{selection_application_id}}/profile/photo/` | HTTP 200. JPEG privado sin caché y sin URL pública |
| PM225 | #60 | Otra empresa aprobada no recibe la fotografía | `GET company/applications/{{selection_application_id}}/profile/photo/` | HTTP 404. Rechazo con explicación en JSON. |
| PM226 | #60 | Fotografía de selección sin sesión rechazada | `GET company/applications/{{selection_application_id}}/profile/photo/` | HTTP 401. Rechazo con explicación en JSON. |
| PM227 | #60 | Empresa no puede usar POST en perfil | `POST company/applications/{{selection_application_id}}/profile/` | HTTP 405. Rechazo con explicación en JSON. |
| PM228 | #60 | Empresa no puede usar PUT en perfil | `PUT company/applications/{{selection_application_id}}/profile/` | HTTP 405. Rechazo con explicación en JSON. |
| PM229 | #60 | Empresa no puede usar PATCH en perfil | `PATCH company/applications/{{selection_application_id}}/profile/` | HTTP 405. Rechazo con explicación en JSON. |
| PM230 | #60 | Empresa no puede usar DELETE en perfil | `DELETE company/applications/{{selection_application_id}}/profile/` | HTTP 405. Rechazo con explicación en JSON. |
| PM231 | #60 | Empresa no puede usar POST en fotografía | `POST company/applications/{{selection_application_id}}/profile/photo/` | HTTP 405. Rechazo con explicación en JSON. |
| PM232 | #60 | Empresa no puede usar PUT en fotografía | `PUT company/applications/{{selection_application_id}}/profile/photo/` | HTTP 405. Rechazo con explicación en JSON. |
| PM233 | #60 | Empresa no puede usar PATCH en fotografía | `PATCH company/applications/{{selection_application_id}}/profile/photo/` | HTTP 405. Rechazo con explicación en JSON. |
| PM234 | #60 | Empresa no puede usar DELETE en fotografía | `DELETE company/applications/{{selection_application_id}}/profile/photo/` | HTTP 405. Rechazo con explicación en JSON. |
| PM235 | #60 | Candidato conserva su perfil después de los intentos empresariales | `GET profile/candidate/` | HTTP 200. Resumen y foto propios intactos |
| PM236 | #60 | Candidato retira su fotografía opcional | `DELETE profile/candidate/photo/` | HTTP 200. Fotografía retirada por su propietario |
| PM237 | #60 | Empresa ya no recibe la fotografía retirada | `GET company/applications/{{selection_application_id}}/profile/photo/` | HTTP 404. Rechazo con explicación en JSON. |
