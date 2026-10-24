"""Genera la colección v2.1 y su catálogo; no ejecuta peticiones ni contiene secretos."""
from pathlib import Path
import json
import re
import uuid

HERE = Path(__file__).resolve().parent
folders = []
catalog = []
current = None


def folder(name, preparation):
    global current
    current = {'name': name, 'description': preparation, 'item': []}
    folders.append(current)


def case(task, title, method, route, status=200, body=None, auth=None, check=None, save='', file=None, required=()):
    number = f'PM{len(catalog)+1:03}'
    name = f'{number} · #{task} · {title}'
    headers = [{'key': 'Accept', 'value': 'application/json'}]
    if auth:
        headers.append({'key': 'Authorization', 'value': 'Token {{' + auth + '}}'})
    request = {'method': method, 'header': headers, 'url': '{{base_url}}/' + route,
               'auth': {'type': 'noauth'}}
    if body is not None:
        headers.append({'key': 'Content-Type', 'value': 'application/json'})
        request['body'] = {'mode': 'raw', 'raw': json.dumps(body, ensure_ascii=False, indent=2),
                           'options': {'raw': {'language': 'json'}}}
    if file:
        request['body'] = {'mode': 'formdata', 'formdata': [{'key': 'photo', 'type': 'file', 'src': file}]}
    expected = f'HTTP {status}. ' + (check[0] if check else ('Rechazo con explicación en JSON.' if status >= 400 else 'Respuesta JSON válida.'))
    description = (f'**Tarea:** [#{task}](https://github.com/Danilo2334/Work_net/issues/{task})\n\n'
                   f'**Objetivo:** {title}.\n\n**Preparación:** {current["description"]} '
                   'Ejecutar las peticiones anteriores de esta fase en orden; usar exclusivamente el entorno privado del run aislado.\n\n'
                   f'**Petición:** `{method} {{{{base_url}}}}/{route}`. Encabezados y cuerpo en las pestañas de esta petición.\n\n'
                   f'**Esperado:** {expected}\n\n**Automatización:** scripts Post-response verifican el estado y los datos descritos. '
                   'Los identificadores y tokens se guardan desde respuestas reales. Véase README.md para reiniciar y para las pausas de correo.')
    request['description'] = description
    scripts = [f'pm.test("HTTP {status}", () => pm.response.to.have.status({status}));']
    binary = method == 'GET' and status == 200 and (route.endswith('profile/photo/') or route in ('profile/candidate/photo/', 'company/logo/'))
    if not binary:
        scripts += ['let data;', 'pm.test("Respuesta JSON", () => { data = pm.response.json(); pm.expect(data).to.be.an("object"); });']
    scripts.append('const v = (key) => pm.environment.get(key);')
    if status >= 400:
        scripts.append('pm.test("El rechazo explica el problema", () => pm.expect(Object.keys(data || {})).not.to.be.empty);')
    if check:
        scripts.append('pm.test(' + json.dumps(check[0], ensure_ascii=False) + ', () => { ' + check[1] + ' });')
    if save:
        scripts.append(f'if (pm.response.code === {status}) {{ {save} }}')
    # Postman ya expone un global legado llamado `data` (iteration data).
    scripts = [re.sub(r'\bdata\b', 'payloadQA', line) for line in scripts]
    event = [{'listen': 'test', 'script': {'type': 'text/javascript', 'exec': scripts}}]
    if required:
        event.insert(0, {'listen': 'prerequest', 'script': {'type': 'text/javascript', 'exec': [
            'for (const key of ' + json.dumps(required) + ') { if (!pm.environment.get(key)) { throw new Error("Falta variable local: " + key + ". Consulta README antes de esta fase."); } }']}})
    current['item'].append({'id': str(uuid.uuid5(uuid.NAMESPACE_URL, 'worknet-postman-' + number)),
                            'name': name, 'request': request, 'event': event, 'response': []})
    catalog.append({'id': number, 'tarea': task, 'objetivo': title, 'fase': current['name'], 'metodo': method,
                    'ruta': route, 'esperado': expected, 'auth': auth, 'cuerpo': body, 'archivo': file})


def eq(label, expression, expected):
    return label, f'pm.expect({expression}).to.deep.equal({json.dumps(expected, ensure_ascii=False)});'


def token_save(key):
    return f'pm.environment.set("{key}_token", data.token); pm.environment.set("{key}_id", data.user.id);'


def login(task, key, password='qa_password', title=None, state=None):
    js = 'pm.expect(data.token).to.match(/^[a-f0-9]{40}$/); pm.expect(data.user.email_verified).to.equal(true); pm.expect(data.user).not.to.have.property("password");'
    if state:
        js += f'pm.expect(data.user.company_state).to.equal("{state}");'
    case(task, title or 'Login de ' + key, 'POST', 'login/', body={'email': '{{'+key+'_email}}', 'password': '{{'+password+'}}'},
         check=('Token real y cuenta verificada' + (f'; estado {state}' if state else ''), js), save=token_save(key))


folder('01 · HU001 #30 · Registro y roles', 'Base inicial creada con qa.py prepare; ninguna cuenta de registro previa.')
registration = {'full_name': 'Persona ficticia Postman', 'email': '{{registered_email}}', 'password': '{{registered_password}}', 'password_confirm': '{{registered_password}}'}
case(30, 'Campos obligatorios ausentes', 'POST', 'register/', 400, {})
case(30, 'Correo inválido', 'POST', 'register/', 400, {**registration, 'email': 'no-es-correo'})
case(30, 'Contraseñas diferentes', 'POST', 'register/', 400, {**registration, 'password_confirm': 'distinta-qa'})
case(30, 'Contraseña débil', 'POST', 'register/', 400, {**registration, 'password': '123', 'password_confirm': '123'})
case(30, 'No se permite registrar administrador', 'POST', 'register/', 400, {**registration, 'role': 'admin'})
case(30, 'Registro sin rol previo', 'POST', 'register/', 201, registration,
     check=('Cuenta sin rol y correo todavía no verificado; ticket limitado presente', 'pm.expect(data.user.role).to.equal(""); pm.expect(data.user.email_verified).to.equal(false); pm.expect(data.registration_token).to.be.a("string").and.not.empty; pm.expect(data.user).not.to.have.property("password");'),
     save='pm.environment.set("registration_ticket", data.registration_token); pm.environment.set("registered_id", data.user.id);')
case(30, 'Correo duplicado sin distinguir mayúsculas', 'POST', 'register/', 400, {**registration, 'email': 'REGISTRO.POSTMAN@WORKNET.TEST'}, check=('Error de correo en español', 'pm.expect(data.errors.email.join(" ")).to.include("ya está registrado");'))
case(30, 'Ticket inválido para elegir rol', 'POST', 'register/role/', 400, {'registration_token': 'invalido-qa', 'role': 'candidato'})
case(30, 'Ticket no permite elegir administrador', 'POST', 'register/role/', 400, {'registration_token': '{{registration_ticket}}', 'role': 'admin'})
case(30, 'Candidato elegido después del registro', 'POST', 'register/role/', body={'registration_token': '{{registration_ticket}}', 'role': 'candidato'}, check=eq('Rol candidato guardado', 'data.user.role', 'candidato'))
case(30, 'No se permite reasignar el rol', 'POST', 'register/role/', 409, {'registration_token': '{{registration_ticket}}', 'role': 'empresa'})
case(35, 'Login sin verificar rechazado', 'POST', 'login/', 400, {'email': '{{registered_email}}', 'password': '{{registered_password}}'})

folder('02 · HU001 #31 y HU002 #35 · Verificación y sesión', 'Después de fase 01: ejecutar qa.py mail verification e importar SOLO verification_token al entorno activo; conservar las demás variables.')
case(31, 'Verificación sin enlace', 'GET', 'verify-email/', 400)
case(31, 'Firma inválida', 'GET', 'verify-email/?token=invalido-qa', 400)
case(31, 'Verificación con enlace del correo capturado', 'GET', 'verify-email/?token={{verification_token}}', check=eq('Correo verificado correctamente', 'data.message', 'Correo verificado correctamente.'), required=['verification_token'])
case(31, 'Repetición de verificación idempotente', 'GET', 'verify-email/?token={{verification_token}}', check=eq('Verificación repetida reconocida', 'data.message', 'El correo ya había sido verificado.'))
case(35, 'Login sin datos', 'POST', 'login/', 400, {})
case(35, 'Contraseña incorrecta', 'POST', 'login/', 400, {'email': '{{registered_email}}', 'password': 'incorrecta-qa'})
login(35, 'registered', 'registered_password', 'Login después de verificar acredita persistencia')
case(30, 'Consulta conserva el rol y la verificación', 'GET', 'account/', auth='registered_token', check=('Rol y verificación persistentes', 'pm.expect(data.user.role).to.equal("candidato"); pm.expect(data.user.email_verified).to.equal(true); pm.expect(data.user.id).to.equal(v("registered_id"));'))
case(35, 'Logout sin autenticación', 'POST', 'logout/', 401, {})
case(35, 'Logout revoca el token utilizado', 'POST', 'logout/', body={}, auth='registered_token', save='pm.environment.set("revoked_token", v("registered_token"));')
case(35, 'Token revocado recibe 401', 'GET', 'account/', 401, auth='revoked_token')
login(35, 'registered', 'registered_password', 'Nuevo login después de logout')
for key in ['candidate', 'other', 'company', 'draft', 'other_company', 'admin', 'disposable']:
    login(35, key, state='approved' if key == 'company' else 'pending' if key in ('draft', 'other_company') else None)

folder('03 · HU003 #40 · Solicitud de recuperación', 'Registro verificado y sesión obtenida en fase 02; el correo se captura en archivos, no se entrega a un buzón.')
case(40, 'Solicitud sin correo', 'POST', 'password-recovery/request/', 400, {})
case(40, 'Solicitud con correo inválido', 'POST', 'password-recovery/request/', 400, {'email': 'incorrecto'})
case(40, 'Correo desconocido recibe respuesta genérica', 'POST', 'password-recovery/request/', body={'email': 'desconocido@worknet.test'}, save='pm.environment.set("generic_recovery_message", data.message);')
case(40, 'Solicitud válida captura un correo local', 'POST', 'password-recovery/request/', body={'email': '{{registered_email}}'}, check=('Respuesta no revela si existe la cuenta', 'pm.expect(data.message).to.equal(v("generic_recovery_message"));'))

folder('04 · HU003 #40 · Confirmación de recuperación', 'Después de fase 03: qa.py mail recovery; copiar SOLO reset_uid y reset_token al entorno activo.')
reset = {'uid': '{{reset_uid}}', 'token': '{{reset_token}}', 'new_password': '{{new_password}}', 'new_password_confirm': '{{new_password}}'}
case(40, 'Enlace inválido', 'POST', 'password-recovery/confirm/', 400, {**reset, 'uid': 'invalido', 'token': 'invalido-qa'})
case(40, 'Contraseñas nuevas diferentes', 'POST', 'password-recovery/confirm/', 400, {**reset, 'new_password_confirm': 'diferente-qa'}, required=['reset_uid', 'reset_token'])
case(40, 'Nueva contraseña débil', 'POST', 'password-recovery/confirm/', 400, {**reset, 'new_password': '123', 'new_password_confirm': '123'})
case(40, 'Cambio mediante enlace del correo capturado', 'POST', 'password-recovery/confirm/', body=reset, check=eq('Cambio confirmado', 'data.message', 'Contraseña restablecida correctamente.'), save='pm.environment.set("old_registered_password", v("registered_password")); pm.environment.set("registered_password", v("new_password"));')
case(40, 'Enlace usado rechazado', 'POST', 'password-recovery/confirm/', 400, reset)
case(40, 'Token anterior al cambio revocado', 'GET', 'account/', 401, auth='registered_token')
case(40, 'Contraseña anterior rechazada', 'POST', 'login/', 400, {'email': '{{registered_email}}', 'password': '{{old_registered_password}}'})
login(40, 'registered', 'registered_password', 'Login con nueva contraseña acredita persistencia')

folder('05 · HU004 #44 · Configuración y contraseña', 'Fases 01–04 completas; candidato principal y segundo usuario sembrados, con tokens obtenidos por login real.')
case(44, 'Cuenta sin token', 'GET', 'account/', 401)
case(44, 'Cuenta con token inválido', 'GET', 'account/', 401, auth='invalid_token')
case(44, 'Consultar propia cuenta', 'GET', 'account/', auth='candidate_token', check=('Solo datos públicos de la cuenta propia', 'pm.expect(data.user.email).to.equal(v("candidate_email")); pm.expect(data.user.id).to.equal(v("candidate_id")); pm.expect(data.user).not.to.have.property("password");'))
case(44, 'Nombre vacío rechazado', 'PATCH', 'account/', 400, {'full_name': ''}, 'candidate_token')
case(44, 'Correo rol y verificación no son editables', 'PATCH', 'account/', 400, {'email': 'otro@worknet.test', 'role': 'admin', 'email_verified': False}, 'candidate_token')
case(44, 'No se permite indicar otro propietario', 'PATCH', 'account/', 400, {'user_id': '{{other_id}}', 'full_name': 'Intrusión QA'}, 'candidate_token')
case(44, 'Actualizar nombre propio', 'PATCH', 'account/', body={'full_name': 'Candidato actualizado Postman'}, auth='candidate_token', check=eq('Nombre actualizado', 'data.user.full_name', 'Candidato actualizado Postman'))
case(44, 'Nueva consulta conserva el nombre', 'GET', 'account/', auth='candidate_token', check=eq('Nombre persistido', 'data.user.full_name', 'Candidato actualizado Postman'))
case(44, 'Otro usuario conserva sus datos', 'GET', 'account/?user_id={{candidate_id}}', auth='other_token', check=('No se consulta una cuenta ajena mediante parámetros', 'pm.expect(data.user.id).to.equal(v("other_id")); pm.expect(data.user.full_name).to.equal("Otro candidato QA");'))
change = {'current_password': '{{candidate_password}}', 'new_password': '{{account_new_password}}', 'new_password_confirm': '{{account_new_password}}'}
case(44, 'Contraseña actual incorrecta', 'POST', 'account/password/', 400, {**change, 'current_password': 'incorrecta-qa'}, 'candidate_token')
case(44, 'Confirmación de contraseña diferente', 'POST', 'account/password/', 400, {**change, 'new_password_confirm': 'otra-qa'}, 'candidate_token')
case(44, 'Contraseña nueva débil', 'POST', 'account/password/', 400, {**change, 'new_password': '123', 'new_password_confirm': '123'}, 'candidate_token')
case(44, 'Cambio devuelve token nuevo', 'POST', 'account/password/', body=change, auth='candidate_token', check=('Token nuevo distinto del anterior', 'pm.expect(data.token).to.match(/^[a-f0-9]{40}$/); pm.expect(data.token).not.to.equal(v("candidate_token"));'), save='pm.environment.set("old_candidate_token", v("candidate_token")); pm.environment.set("candidate_token", data.token); pm.environment.set("candidate_password", v("account_new_password"));')
case(44, 'Token anterior rechazado', 'GET', 'account/', 401, auth='old_candidate_token')
case(44, 'Token nuevo autorizado', 'GET', 'account/', auth='candidate_token', check=('Cuenta propia accesible', 'pm.expect(data.user.id).to.equal(v("candidate_id"));'))
case(44, 'Contraseña antigua rechazada tras cambio', 'POST', 'login/', 400, {'email': '{{candidate_email}}', 'password': '{{qa_password}}'})
login(44, 'candidate', 'candidate_password', 'Nuevo login conserva el cambio de contraseña')

folder('06 · HU004 #45 · Preferencias', 'Fase 05 completa; conserva el token nuevo y los dos usuarios independientes.')
case(45, 'Preferencias sin autenticación', 'GET', 'account/notifications/', 401)
case(45, 'Preferencia inicial activada', 'GET', 'account/notifications/', auth='candidate_token', check=eq('Valor inicial booleano true', 'data.preferences.push_notifications', True))
case(45, 'Desactivar notificaciones', 'PATCH', 'account/notifications/', body={'push_notifications': False}, auth='candidate_token', check=eq('Booleano false guardado', 'data.preferences.push_notifications', False))
case(45, 'False permanece en una nueva consulta', 'GET', 'account/notifications/', auth='candidate_token', check=eq('Persistencia de false', 'data.preferences.push_notifications', False))
case(45, 'Otra cuenta no hereda la preferencia', 'GET', 'account/notifications/', auth='other_token', check=eq('Segunda cuenta permanece en true', 'data.preferences.push_notifications', True))
case(45, 'Texto false no es booleano', 'PATCH', 'account/notifications/', 400, {'push_notifications': 'false'}, 'candidate_token')
case(45, 'Número cero no es booleano', 'PATCH', 'account/notifications/', 400, {'push_notifications': 0}, 'candidate_token')
case(45, 'Campo ajeno rechazado', 'PATCH', 'account/notifications/', 400, {'push_notifications': True, 'user_id': '{{other_id}}'}, 'candidate_token')
case(45, 'Los errores no alteran la preferencia', 'GET', 'account/notifications/', auth='candidate_token', check=eq('False sigue guardado', 'data.preferences.push_notifications', False))
case(45, 'Activar notificaciones', 'PATCH', 'account/notifications/', body={'push_notifications': True}, auth='candidate_token', check=eq('Booleano true guardado', 'data.preferences.push_notifications', True))
case(45, 'True permanece en una nueva consulta', 'GET', 'account/notifications/', auth='candidate_token', check=eq('Persistencia de true', 'data.preferences.push_notifications', True))

folder('07 · HU005 HU006 HU007 · Resúmenes #48 #52 #56', 'Base inicial más registro de fases anteriores: cuatro candidatos, tres empresas, una empresa aprobada, ninguna solicitud pendiente completa.')
for task, endpoint, role in [(48,'candidate','candidate'),(52,'company','company'),(56,'admin','admin')]:
    case(task, 'Resumen sin autenticación', 'GET', f'dashboard/{endpoint}/', 401)
    case(task, 'Resumen con token inválido', 'GET', f'dashboard/{endpoint}/', 401, auth='invalid_token')
    wrong = 'company_token' if endpoint == 'candidate' else 'candidate_token'
    case(task, 'Resumen restringido al rol correcto', 'GET', f'dashboard/{endpoint}/', 403, auth=wrong)
case(48, 'Métricas y completitud del candidato principal', 'GET', 'dashboard/candidate/', auth='candidate_token', check=('83 por ciento y métricas 2 1 2; dos trabajos publicados', 'pm.expect(data.profile_completion.percentage).to.equal(83); pm.expect(data.metrics).to.deep.equal({applications_count:2,saved_offers_count:1,pending_notifications_count:2}); pm.expect(data.recent_jobs).to.have.lengthOf(2); pm.expect(data.recent_jobs.every(j=>j.id && j.title && j.company_name)).to.equal(true);'))
case(48, 'Segundo candidato vacío y separado', 'GET', 'dashboard/candidate/?user_id={{candidate_id}}', auth='other_token', check=('17 por ciento y métricas propias en cero; ofertas globales válidas', 'pm.expect(data.user.id).to.equal(v("other_id")); pm.expect(data.profile_completion.percentage).to.equal(17); pm.expect(data.metrics).to.deep.equal({applications_count:0,saved_offers_count:0,pending_notifications_count:0}); pm.expect(data.recent_jobs).to.have.lengthOf(2);'))
case(48, 'Resumen no admite escritura', 'POST', 'dashboard/candidate/', 405, {}, 'candidate_token')
case(52, 'Empresa aprobada muestra su actividad real', 'GET', 'dashboard/company/', auth='company_token', check=('Dos ofertas activas y dos postulaciones propias', 'pm.expect(data.metrics).to.deep.equal({active_offers:2,closed_offers:0,applications:2}); pm.expect(data.recent_applications).to.have.lengthOf(2); pm.expect(data.recent_applications.every(a=>a.candidate__full_name === "Candidato actualizado Postman")).to.equal(true);'))
case(52, 'Empresa pendiente no accede al resumen', 'GET', 'dashboard/company/', 403, auth='draft_token')
case(56, 'Resumen administrador con conteos de la base QA', 'GET', 'dashboard/admin/', auth='admin_token', check=eq('Cuatro candidatos tres empresas y cero solicitudes completas', 'data.metrics', {'candidates':4,'companies':3,'pending_companies':0}))
case(56, 'Empresa no accede al resumen administrador', 'GET', 'dashboard/admin/', 403, auth='company_token')

folder('08 · HU008 #60 · Perfil y fotografía', 'Usar other_token para el segundo candidato sin perfil; fotos de QA en fixtures y .local/fixtures. El perfil principal debe permanecer intacto.')
case(60, 'Perfil sin autenticación', 'GET', 'profile/candidate/', 401)
case(60, 'Empresa no consulta el perfil del candidato', 'GET', 'profile/candidate/', 403, auth='company_token')
case(60, 'Perfil vacío sin creación implícita', 'GET', 'profile/candidate/', auth='other_token', check=eq('Perfil todavía inexistente', 'data.profile.exists', False))
case(60, 'Crear perfil propio', 'POST', 'profile/candidate/', 201, {'professional_summary': 'Descripción profesional ficticia QA'}, 'other_token', check=eq('Perfil creado sin foto obligatoria', 'data.profile.has_photo', False))
case(60, 'Crear perfil duplicado rechazado', 'POST', 'profile/candidate/', 409, {'professional_summary': 'Duplicado'}, 'other_token')
case(60, 'Modificar descripción profesional', 'PATCH', 'profile/candidate/', body={'professional_summary': 'Descripción corregida QA'}, auth='other_token', check=eq('Descripción editada', 'data.profile.professional_summary', 'Descripción corregida QA'))
case(60, 'Descripción persiste al consultar', 'GET', 'profile/candidate/', auth='other_token', check=eq('Descripción recuperada', 'data.profile.professional_summary', 'Descripción corregida QA'))
case(60, 'No se permite cambiar propietario', 'PATCH', 'profile/candidate/', 400, {'candidate': '{{candidate_id}}', 'professional_summary': 'Intrusión'}, 'other_token')
sections = {
    'education': ({'qualification':'Ingeniería QA','institution':'Institución ficticia','start_date':'2020-01-01','end_date':'2024-01-01'}, {'institution':'Institución corregida QA'}),
    'experience': ({'position':'Desarrollo QA','company':'Empresa ficticia','start_date':'2024-01-01','end_date':'2025-01-01'}, {'company':'Empresa corregida QA'}),
    'skills': ({'name':'Django','level':'intermedio'}, {'level':'avanzado'}),
    'languages': ({'name':'Español','level':'B2'}, {'level':'nativo'}),
}
for section,(data,edit) in sections.items():
    path = 'profile/candidate/'+section+'/'
    case(60, f'{section}: validar campos obligatorios', 'POST', path, 400, {}, 'other_token')
    case(60, f'{section}: agregar registro', 'POST', path, 201, data, 'other_token', check=('Registro estructurado con identificador real', f'pm.expect(data.profile.{section}).to.have.lengthOf(1); pm.expect(data.profile.{section}[0].id).to.be.a("string");'), save=f'pm.environment.set("{section}_id", data.profile.{section}[0].id);')
    rowpath = path + '{{'+section+'_id}}/'
    case(60, f'{section}: consultar registro persistido', 'GET', rowpath, auth='other_token', check=(f'{section} conserva campos enviados', 'pm.expect(data.record).to.include('+json.dumps(data,ensure_ascii=False)+');'))
    case(60, f'{section}: editar registro', 'PATCH', rowpath, body=edit, auth='other_token', check=('Cambio en registro propio', 'pm.expect(data.profile.'+section+'[0]).to.include('+json.dumps(edit,ensure_ascii=False)+');'))
    case(60, f'{section}: nueva consulta conserva edición', 'GET', rowpath, auth='other_token', check=('Edición persistida', 'pm.expect(data.record).to.include('+json.dumps(edit,ensure_ascii=False)+');'))
    case(60, f'{section}: otro candidato no lee el registro', 'GET', rowpath, 404, auth='candidate_token')
    case(60, f'{section}: otro candidato no modifica el registro', 'PATCH', rowpath, 404, edit, 'candidate_token')
    case(60, f'{section}: otro candidato no elimina el registro', 'DELETE', rowpath, 404, auth='candidate_token')
case(60, 'Fechas invertidas rechazadas', 'POST', 'profile/candidate/education/', 400, {'qualification':'QA','start_date':'2025-01-01','end_date':'2020-01-01'}, 'other_token')
case(60, 'Nivel de idioma inválido', 'POST', 'profile/candidate/languages/', 400, {'name':'Inglés','level':'experto-inventado'}, 'other_token')
case(60, 'Dashboard refleja las seis secciones completas', 'GET', 'dashboard/candidate/', auth='other_token', check=eq('Completitud real de Django al cien sin fotografía', 'data.profile_completion.percentage', 100))
case(60, 'Foto opcional ausente', 'GET', 'profile/candidate/photo/', 404, auth='other_token')
case(60, 'Subir PNG válido', 'PUT', 'profile/candidate/photo/', auth='other_token', file='fixtures/foto-qa.png', check=eq('Foto cargada', 'data.profile.has_photo', True))
photo_check = ('JPEG privado sin caché y sin URL pública', 'pm.expect(pm.response.headers.get("Content-Type")).to.include("image/jpeg"); pm.expect(pm.response.headers.get("Cache-Control")).to.include("no-store"); pm.expect(pm.response.headers.get("Cache-Control")).to.include("private"); pm.expect(pm.response.text().length).to.be.above(0);')
case(60, 'Recuperar fotografía privada', 'GET', 'profile/candidate/photo/', auth='other_token', check=photo_check)
case(60, 'Fotografía sin autenticación rechazada', 'GET', 'profile/candidate/photo/', 401)
case(60, 'Otro candidato no recibe la fotografía ajena', 'GET', 'profile/candidate/photo/?user_id={{other_id}}', 404, auth='candidate_token')
case(60, 'Empresa sin autorización no accede a foto', 'GET', 'profile/candidate/photo/', 403, auth='company_token')
for name,file in [('Extensión no admitida','fixtures/no-imagen.txt'),('PNG corrupto','fixtures/corrupta.png'),('Más de 4096 píxeles','.local/fixtures/ancha.png'),('Más de dos MiB','.local/fixtures/exceso.png')]:
    case(60, name+' rechazado', 'PUT', 'profile/candidate/photo/', 400, auth='other_token', file=file)
case(60, 'Errores de archivo conservan foto anterior', 'GET', 'profile/candidate/photo/', auth='other_token', check=photo_check)
case(60, 'Quitar fotografía opcional', 'DELETE', 'profile/candidate/photo/', auth='other_token', check=eq('Foto eliminada', 'data.profile.has_photo', False))
case(60, 'Nueva consulta confirma foto ausente', 'GET', 'profile/candidate/photo/', 404, auth='other_token')
case(60, 'Quitar foto conserva completitud al cien', 'GET', 'dashboard/candidate/', auth='other_token', check=eq('Foto no participa en las seis secciones', 'data.profile_completion.percentage', 100))
for section in sections:
    path='profile/candidate/'+section+'/'
    case(60, f'{section}: eliminar registro propio', 'DELETE', path+'{{'+section+'_id}}/', auth='other_token', check=eq('Sección vaciada', 'data.profile.'+section, []))
    case(60, f'{section}: consulta confirma eliminación', 'GET', path, auth='other_token', check=eq('Sin registros persistidos', 'data.records', []))
case(60, 'Eliminar perfil propio', 'DELETE', 'profile/candidate/', auth='other_token', check=eq('Perfil eliminado', 'data.profile.exists', False))
case(60, 'Consulta confirma perfil eliminado', 'GET', 'profile/candidate/', auth='other_token', check=eq('Perfil permanece ausente', 'data.profile.exists', False))
case(60, 'Eliminar perfil conserva la cuenta', 'GET', 'account/', auth='other_token', check=('Cuenta del segundo candidato sigue vigente', 'pm.expect(data.user.id).to.equal(v("other_id"));'))
case(60, 'Otro perfil no fue alterado', 'GET', 'profile/candidate/', auth='candidate_token', check=eq('Resumen principal intacto', 'data.profile.professional_summary', 'Resumen ficticio QA'))

folder('09 · HU009 #64 · Información empresarial', 'Empresa solicitante draft, otra empresa independiente other_company y administrador; ninguna solicitud enviada todavía.')
case(64, 'Información empresarial sin autenticación', 'GET', 'company/', 401)
case(64, 'Candidato no usa información empresarial', 'GET', 'company/', 403, auth='candidate_token')
case(64, 'Datos iniciales de empresa sin solicitud', 'GET', 'company/', auth='draft_token', check=('Pendiente sin enviar y sin datos ajenos', 'pm.expect(data.company.state).to.equal("pending"); pm.expect(data.company.submitted).to.equal(false); pm.expect(data.company.id).to.equal(null);'))
case(64, 'No se permite enviar información incompleta', 'POST', 'company/submit/', 400, {}, 'draft_token')
case(64, 'Correo de contacto inválido', 'PATCH', 'company/', 400, {'contact_email':'no-correo'}, 'draft_token')
case(64, 'NIT inválido', 'PATCH', 'company/', 400, {'tax_id':'abc'}, 'draft_token')
case(64, 'No se permite editar estado ni propietario', 'PATCH', 'company/', 400, {'company':'{{company_id}}','state':'approved'}, 'draft_token')
company_data = {'legal_name':'Empresa solicitante Postman QA','tax_id':'900000002-1','sector':'Tecnología QA','location':'Pasto','contact_email':'solicitud@worknet.test','description':'Información ficticia para la revisión Postman.'}
case(64, 'Guardar los seis datos empresariales', 'PATCH', 'company/', body=company_data, auth='draft_token', check=('Datos completos guardados como borrador', 'pm.expect(data.company).to.include('+json.dumps(company_data,ensure_ascii=False)+'); pm.expect(data.company.submitted).to.equal(false);'), save='pm.environment.set("company_profile_id", data.company.id);')
case(64, 'Nueva consulta conserva los datos empresariales', 'GET', 'company/', auth='draft_token', check=('Persistencia de todos los datos', 'pm.expect(data.company).to.include('+json.dumps(company_data,ensure_ascii=False)+');'))
case(64, 'Otra empresa no consulta datos de la solicitante', 'GET', 'company/?company={{company_profile_id}}', auth='other_company_token', check=('Información exclusivamente propia', 'pm.expect(data.company.legal_name).to.equal(""); pm.expect(data.company.id).not.to.equal(v("company_profile_id"));'))
case(64, 'Otra empresa no puede duplicar NIT', 'PATCH', 'company/', 400, company_data, 'other_company_token')
case(64, 'Logo requiere aprobación previa', 'PUT', 'company/logo/', 403, auth='draft_token', file='fixtures/foto-qa.png')
case(64, 'Enviar solicitud completa', 'POST', 'company/submit/', body={}, auth='draft_token', check=('Solicitud pendiente y enviada con versión real', 'pm.expect(data.company.state).to.equal("pending"); pm.expect(data.company.submitted).to.equal(true); pm.expect(data.company.version).to.be.a("number");'), save='pm.environment.set("company_version", data.company.version);')
case(64, 'Solicitud enviada bloquea edición', 'PATCH', 'company/', 400, {'location':'Cambio indebido'}, 'draft_token')
case(64, 'Solicitud no se envía dos veces', 'POST', 'company/submit/', 400, {}, 'draft_token')

folder('10 · HU010 #68 · Rechazo corrección reenvío y aprobación', 'Solicitud completa enviada en fase 09. company_profile_id y company_version provienen de respuestas reales; admin_token de login con cuenta administrativa QA.')
review='admin/companies/{{company_profile_id}}/review/'
case(68, 'Listado de solicitudes sin autenticación', 'GET', 'admin/companies/', 401)
case(68, 'Candidato no consulta solicitudes administrativas', 'GET', 'admin/companies/', 403, auth='candidate_token')
case(68, 'Empresa no puede aprobarse', 'POST', review, 403, {'decision':'approved','version':'{{company_version}}'}, 'draft_token')
case(68, 'Administrador consulta solicitud completa', 'GET', 'admin/companies/', auth='admin_token', check=('Listado contiene la solicitud y sus datos completos', 'pm.expect(data.count).to.equal(1); const company=data.companies.find(c=>c.id===v("company_profile_id")); pm.expect(company).to.include({legal_name:"Empresa solicitante Postman QA",tax_id:"900000002-1"}); pm.expect(company.version).to.equal(v("company_version"));'))
case(56, 'Dashboard cuenta y notifica solicitud pendiente', 'GET', 'dashboard/admin/', auth='admin_token', check=('Una solicitud pendiente y notificación persistida', 'pm.expect(data.metrics.pending_companies).to.equal(1); pm.expect(data.notifications.some(n=>n.title.includes("Nueva solicitud"))).to.equal(true);'))
case(68, 'Rechazo sin motivo no modifica solicitud', 'POST', review, 400, {'decision':'rejected','version':'__NUMBER_company_version__'}, 'admin_token')
case(68, 'Decisión inválida rechazada', 'POST', review, 400, {'decision':'inventada','version':'__NUMBER_company_version__'}, 'admin_token')
case(68, 'Rechazar solicitud con motivo y responsable', 'POST', review, body={'decision':'rejected','version':'__NUMBER_company_version__','reason':'Corrige la sede ficticia QA.'}, auth='admin_token', check=('Rechazo con motivo revisor y fecha', 'pm.expect(data.company.state).to.equal("rejected"); pm.expect(data.company.rejection_reason).to.equal("Corrige la sede ficticia QA."); pm.expect(data.company.reviewed_by).to.equal(v("admin_id")); pm.expect(data.company.reviewed_at).to.be.a("string");'))
case(68, 'Empresa consulta rechazo y notificación persistidos', 'GET', 'company/', auth='draft_token', check=('Motivo y notificación conservados', 'pm.expect(data.company.state).to.equal("rejected"); pm.expect(data.company.rejection_reason).to.equal("Corrige la sede ficticia QA."); pm.expect(data.notifications.some(n=>n.title.includes("rechazada"))).to.equal(true);'))
login(35, 'draft', title='Login informa empresa rechazada', state='rejected')
case(52, 'Empresa rechazada no accede al dashboard', 'GET', 'dashboard/company/', 403, auth='draft_token')
case(68, 'Corregir datos de la empresa rechazada', 'PATCH', 'company/', body={'location':'Sede corregida Postman QA'}, auth='draft_token', check=eq('Sede corregida', 'data.company.location', 'Sede corregida Postman QA'))
case(68, 'Reenviar solicitud corregida', 'POST', 'company/submit/', body={}, auth='draft_token', check=('Pendiente nuevamente y motivo anterior limpiado', 'pm.expect(data.company.state).to.equal("pending"); pm.expect(data.company.rejection_reason).to.equal(""); pm.expect(data.company.reviewed_by).to.equal(null);'), save='pm.environment.set("company_version", data.company.version);')
case(68, 'Nueva consulta confirma corrección y reenvío', 'GET', 'admin/companies/', auth='admin_token', check=('Administrador recibe la sede corregida con nueva versión', 'const company=data.companies.find(c=>c.id===v("company_profile_id")); pm.expect(company.location).to.equal("Sede corregida Postman QA"); pm.expect(company.version).to.equal(v("company_version"));'))
case(68, 'Aprobar solicitud corregida', 'POST', review, body={'decision':'approved','version':'__NUMBER_company_version__'}, auth='admin_token', check=('Aprobación con responsable administrativo', 'pm.expect(data.company.state).to.equal("approved"); pm.expect(data.company.reviewed_by).to.equal(v("admin_id"));'))
case(68, 'Decisión obsoleta no sobrescribe aprobación', 'POST', review, 409, {'decision':'rejected','version':'__NUMBER_company_version__','reason':'Versión antigua QA'}, 'admin_token')
case(68, 'Empresa consulta aprobación notificada', 'GET', 'company/', auth='draft_token', check=('Aprobación y notificación persistidas', 'pm.expect(data.company.state).to.equal("approved"); pm.expect(data.notifications.some(n=>n.title.includes("aprobada"))).to.equal(true);'))
login(35, 'draft', title='Login informa empresa aprobada', state='approved')
case(52, 'Empresa recién aprobada no hereda actividad ajena', 'GET', 'dashboard/company/', auth='draft_token', check=('Métricas propias vacías', 'pm.expect(data.metrics).to.deep.equal({active_offers:0,closed_offers:0,applications:0}); pm.expect(data.recent_applications).to.have.lengthOf(0);'))
case(56, 'Dashboard conserva historial real de revisión', 'GET', 'dashboard/admin/', auth='admin_token', check=('Cero pendientes e historial de envío rechazo y aprobación', 'pm.expect(data.metrics.pending_companies).to.equal(0); for(const action of ["submitted","rejected","approved"]) pm.expect(data.recent_events.some(e=>e.action===action)).to.equal(true);'))
case(64, 'Datos aprobados protegidos', 'PATCH', 'company/', 400, {'legal_name':'Modificar sin revisión QA'}, 'draft_token')
case(64, 'Completar sitio web y redes de empresa aprobada', 'PATCH', 'company/', body={'website':'https://example.org/qa','social_links':['https://example.org/social-qa']}, auth='draft_token', check=eq('Sitio web guardado', 'data.company.website', 'https://example.org/qa'))
case(64, 'Sitio y redes persisten al consultar', 'GET', 'company/', auth='draft_token', check=('Sitio y redes persistentes', 'pm.expect(data.company.website).to.equal("https://example.org/qa"); pm.expect(data.company.social_links).to.deep.equal(["https://example.org/social-qa"]);'))
case(64, 'Cargar logo después de aprobación', 'PUT', 'company/logo/', auth='draft_token', file='fixtures/foto-qa.png', check=eq('Logo guardado', 'data.company.has_logo', True))
case(64, 'Consultar logo privado', 'GET', 'company/logo/', auth='draft_token', check=photo_check)
case(64, 'Logo sin autenticación rechazado', 'GET', 'company/logo/', 401)
case(64, 'Otra empresa no recibe el logo ajeno', 'GET', 'company/logo/?company={{company_profile_id}}', 403, auth='other_company_token')
case(64, 'Logo corrupto rechazado', 'PUT', 'company/logo/', 400, auth='draft_token', file='fixtures/corrupta.png')
case(64, 'Logo previo conservado tras error', 'GET', 'company/logo/', auth='draft_token', check=photo_check)
case(64, 'Eliminar logo opcional', 'DELETE', 'company/logo/', auth='draft_token', check=eq('Logo eliminado', 'data.company.has_logo', False))
case(64, 'Nueva consulta confirma ausencia de logo', 'GET', 'company/logo/', 404, auth='draft_token')

folder('11 · HU004 #44 · Eliminación de cuenta desechable', 'Solamente disposable_email de la base aislada; su token proviene de fase 02. Ninguna cuenta real se usa en estos casos.')
delete={'current_password':'{{qa_password}}','confirmation':True}
case(44, 'Eliminación sin autenticación', 'DELETE', 'account/delete/', 401, delete)
case(44, 'Eliminación sin confirmación', 'DELETE', 'account/delete/', 400, {'current_password':'{{qa_password}}'}, 'disposable_token')
case(44, 'Eliminación cancelada con false', 'DELETE', 'account/delete/', 400, {**delete,'confirmation':False}, 'disposable_token')
case(44, 'Texto true no confirma eliminación', 'DELETE', 'account/delete/', 400, {**delete,'confirmation':'true'}, 'disposable_token')
case(44, 'Contraseña incorrecta impide eliminación', 'DELETE', 'account/delete/', 400, {**delete,'current_password':'incorrecta-qa'}, 'disposable_token')
case(44, 'Errores y cancelación conservan la cuenta', 'GET', 'account/', auth='disposable_token', check=('Cuenta desechable sigue existiendo', 'pm.expect(data.user.id).to.equal(v("disposable_id"));'))
case(44, 'Eliminar con contraseña y true explícito', 'DELETE', 'account/delete/', body=delete, auth='disposable_token', check=eq('Eliminación confirmada', 'data.message', 'Cuenta eliminada correctamente.'))
case(44, 'Token de cuenta eliminada rechazado', 'GET', 'account/', 401, auth='disposable_token')
case(44, 'Cuenta eliminada ya no inicia sesión', 'POST', 'login/', 400, {'email':'{{disposable_email}}','password':'{{qa_password}}'})
case(44, 'Eliminar una cuenta no afecta a otra', 'GET', 'account/', auth='candidate_token', check=('Candidato principal permanece intacto', 'pm.expect(data.user.id).to.equal(v("candidate_id")); pm.expect(data.user.full_name).to.equal("Candidato actualizado Postman");'))

folder('12 · HU008 #60 · Consulta autorizada por postulación', 'Fases anteriores completas. company es dueña de las dos ofertas; draft ya fue aprobada, pero no tiene postulaciones propias. other_company continúa pendiente. Se obtiene la postulación desde el dashboard, sin IDs fijos.')
case(60, 'Obtener postulación propia desde el dashboard empresarial', 'GET', 'dashboard/company/', auth='company_token', check=('Dos postulaciones propias con identificador real', 'pm.expect(data.recent_applications).to.have.lengthOf(2); pm.expect(data.recent_applications[0].id).to.be.a("number");'), save='pm.environment.set("selection_application_id", data.recent_applications[0].id);')
selection = 'company/applications/{{selection_application_id}}/profile/'
case(60, 'Empresa dueña consulta el perfil del postulante', 'GET', selection, auth='company_token', check=('Perfil correcto sin datos de acceso ni preferencias', 'pm.expect(data.candidate).to.deep.equal({id:v("candidate_id"),full_name:"Candidato actualizado Postman"}); pm.expect(data.profile.professional_summary).to.equal("Resumen ficticio QA"); for (const section of ["education","experience","skills"]) pm.expect(data.profile[section]).to.have.lengthOf(1); for (const key of ["password","token","push_notifications","email"]) pm.expect(data.candidate).not.to.have.property(key); pm.expect(pm.response.headers.get("Cache-Control")).to.include("no-store");'), required=['selection_application_id'])
case(60, 'Consulta sin sesión rechazada', 'GET', selection, 401)
case(60, 'Candidato no usa la ruta empresarial', 'GET', selection, 403, auth='candidate_token')
case(60, 'Administrador no usa la ruta empresarial', 'GET', selection, 403, auth='admin_token')
case(60, 'Empresa pendiente no consulta postulantes', 'GET', selection, 403, auth='other_company_token')
case(60, 'Otra empresa aprobada no consulta la postulación ajena', 'GET', selection, 404, auth='draft_token', save='pm.environment.set("selection_not_found", data.detail);')
case(60, 'Postulación inexistente no revela otros candidatos', 'GET', 'company/applications/999999999/profile/', 404, auth='draft_token', check=('Misma respuesta para postulación ajena e inexistente', 'pm.expect(data.detail).to.equal(v("selection_not_found"));'))
case(60, 'Parámetros ajenos no cambian el candidato autorizado', 'GET', selection+'?candidate={{other_id}}&company={{draft_id}}', auth='company_token', check=('Consulta sigue limitada a la postulación propia', 'pm.expect(data.candidate.id).to.equal(v("candidate_id")); pm.expect(data.profile.professional_summary).to.equal("Resumen ficticio QA");'))
case(60, 'Empresa no recibe foto que aún no existe', 'GET', selection+'photo/', 404, auth='company_token')
case(60, 'Candidato agrega foto para la consulta de selección', 'PUT', 'profile/candidate/photo/', auth='candidate_token', file='fixtures/foto-qa.png', check=eq('Fotografía guardada por su propietario', 'data.profile.has_photo', True))
case(60, 'Empresa dueña recibe la foto privada del postulante', 'GET', selection+'photo/', auth='company_token', check=photo_check)
case(60, 'Otra empresa aprobada no recibe la fotografía', 'GET', selection+'photo/', 404, auth='draft_token')
case(60, 'Fotografía de selección sin sesión rechazada', 'GET', selection+'photo/', 401)
for suffix in ('', 'photo/'):
    for method in ('POST','PUT','PATCH','DELETE'):
        case(60, f'Empresa no puede usar {method} en '+('fotografía' if suffix else 'perfil'), method, selection+suffix, 405, {'professional_summary':'No modificar'}, 'company_token')
case(60, 'Candidato conserva su perfil después de los intentos empresariales', 'GET', 'profile/candidate/', auth='candidate_token', check=('Resumen y foto propios intactos', 'pm.expect(data.profile.professional_summary).to.equal("Resumen ficticio QA"); pm.expect(data.profile.has_photo).to.equal(true);'))
case(60, 'Candidato retira su fotografía opcional', 'DELETE', 'profile/candidate/photo/', auth='candidate_token', check=eq('Fotografía retirada por su propietario', 'data.profile.has_photo', False))
case(60, 'Empresa ya no recibe la fotografía retirada', 'GET', selection+'photo/', 404, auth='company_token')

# Las versiones se envían como números JSON, sin comillas alrededor de {{...}}.
for f in folders:
    for item in f['item']:
        body=item['request'].get('body',{})
        if body.get('mode')=='raw':
            body['raw']=body['raw'].replace('"__NUMBER_company_version__"','{{company_version}}')

collection={'info':{'name':'WorkNet · QA backend reproducible · Postman',
    '_postman_id':str(uuid.uuid5(uuid.NAMESPACE_URL,'worknet-postman-backend-qa-20261019')),
    'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    'description':'QA contra Django real y SQLite aislada. Ejecutar carpetas en orden. Pausas obligatorias de correo después de 01 y 03. Ver backend/postman/README.md. No contiene mocks ni credenciales publicadas. No acredita revisión humana ni ejecución visual de Postman por usar Newman.'},
    'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':[
        'const base=pm.environment.get("base_url") || "";',
        r'if (!/^http:\/\/(127\.0\.0\.1|localhost):\d+\/api$/.test(base) || pm.environment.get("qa_confirmation") !== "SOLO_BASE_AISLADA" || !/^run-/.test(pm.environment.get("qa_run_id") || "")) throw new Error("Importa el entorno privado generado por qa.py prepare. Solo base QA local.");']}}],
    'item':folders}
keys={'base_url':'http://127.0.0.1:8008/api','qa_confirmation':'','qa_run_id':'','qa_password':'','candidate_password':'','registered_password':'','new_password':'','account_new_password':'','invalid_token':'invalido-qa'}
for key in ['candidate','other','company','draft','other_company','admin','disposable','registered']:
    keys[key+'_email']=''
    keys[key+'_token']=''
    keys[key+'_id']=''
for key in ['registration_ticket','verification_token','reset_uid','reset_token','revoked_token','old_candidate_token','old_registered_password','generic_recovery_message','company_profile_id','company_version','selection_application_id','selection_not_found']+ [s+'_id' for s in sections]:
    keys[key]=''
env={'id':str(uuid.uuid5(uuid.NAMESPACE_URL,'worknet-postman-env-example')),'name':'WorkNet · ejemplo SIN credenciales · generar entorno con qa.py prepare',
     'values':[{'key':key,'value':value,'type':'secret' if any(s in key for s in ('password','token','ticket')) else 'default','enabled':True} for key,value in keys.items()], '_postman_variable_scope':'environment'}
for name,data in [('WorkNet.postman_collection.json',collection),('WorkNet.local.postman_environment.json',env),('casos.json',catalog)]:
    (HERE/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['# Casos de la colección','', 'Generado por `python backend/postman/build_collection.py`. Cada petición conserva preparación, encabezados, cuerpo y scripts en la colección importable.','', '| Caso | Tarea | Objetivo | Método y ruta | Esperado |','|---|---|---|---|---|']
for c in catalog:
    lines.append(f'| {c["id"]} | #{c["tarea"]} | {c["objetivo"]} | `{c["metodo"]} {c["ruta"]}` | {c["esperado"]} |')
(HERE/'CASOS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'Colección generada: {len(catalog)} peticiones en {len(folders)} fases; ningún secreto incorporado.')
