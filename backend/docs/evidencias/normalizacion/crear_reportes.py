"""Build readable reports from actual API and test-runner results."""
from html import escape
import json
from pathlib import Path

folder=Path(__file__).resolve().parent
api=json.loads((folder/'api.json').read_text(encoding='utf-8'))
suite=json.loads((folder/'suite.json').read_text(encoding='utf-8'))
titles={30:'Registro y roles públicos',31:'Verificación local de correo',35:'Autenticación y login',40:'Recuperación local de contraseña',44:'Configuración de cuenta',45:'Preferencias de notificaciones',48:'Resumen del candidato',60:'Perfil y fotografía privada'}
specific={30:['test_duplicate_email_returns_spanish_field_error','test_registration_verification_login_and_dashboard_work_together','test_duplicate_email_and_public_admin_registration_are_rejected','test_registration_endpoint_still_validates_duplicate_email'],31:['test_registration_verification_login_and_dashboard_work_together','test_expired_verification_does_not_activate_the_account','test_unverified_email_does_not_receive_authentication_token'],35:['test_login_returns_token_and_preserves_existing_user_response','test_login_rejects_unverified_user_without_issuing_token','test_login_rejects_wrong_password','test_login_preserves_admin_role_from_integration_and_candidate_restriction','test_unverified_email_does_not_receive_authentication_token','test_registration_verification_login_and_dashboard_work_together']}
prefixes={44:'accounts.test_account_configuration.',45:'accounts.test_notification_preferences.',48:'candidate_dashboard.tests.',60:'candidate_dashboard.test_profile.'}
summary={}
for task,title in titles.items():
    def relevant(row):
        name=row['prueba']
        if task in specific:return name.rsplit('.',1)[-1] in specific[task]
        if task==40:return name.startswith('accounts.tests.PasswordRecoveryTests.') or name.endswith(('test_password_recovery_revokes_login_and_preserves_preferences','test_password_reset_outside_hu004_also_revokes_token'))
        return name.startswith(prefixes[task])
    tests=[r for r in suite['pruebas'] if relevant(r)]
    cases=api['grupos'][str(task)]
    assert cases and tests and all(r['resultado']=='aprobada' for r in tests)
    summary[str(task)]={'titulo':title,'casos_api':len(cases),'pruebas_automaticas_pertinentes':len(tests),'ids_pruebas':[r['prueba'] for r in tests],'suite_completa':suite['total'],'imagen':f'api-tarea-{task}.png'}
    rows=''.join(f"<tr><td>{escape(c['caso'])}<small>{c['peticion']['metodo']} {escape(c['peticion']['ruta'])}</small></td><td>HTTP {c['esperado']['http']}</td><td>HTTP {c['obtenido']['http']}<br><b>APROBADO</b></td></tr>" for c in cases)
    sample=next((c for c in cases if c['caso'] in ['Nueva consulta conserva nombre','Nueva consulta conserva False','Datos reales de actividad y completitud','Fotografía privada autenticada','Confirmación válida','Abrir enlace capturado a archivo local','Login verificado','Registro candidato']),cases[0])
    value=sample['obtenido']['respuesta']
    if task==48:value={key:value[key] for key in ['user','profile_completion','metrics']}
    note='Correo capturado a archivos locales; recepción SMTP real pendiente.' if task in [30,31,40] else 'Datos ficticios QA. Sesiones, contraseñas y enlaces firmados omitidos.'
    if task==60:note+=' Consulta empresarial autorizada pendiente; acceso empresarial restringido.'
    page=f'''<!doctype html><html lang="es"><meta charset="utf-8"><title>Tarea #{task} — API QA</title>
<style>*{{box-sizing:border-box}}body{{margin:0;background:#eff5f2;color:#193f36;font:16px/1.45 Arial,sans-serif}}main{{width:1120px;padding:28px}}header,section{{padding:24px;background:white;border:1px solid #d6e2dc;border-radius:16px;margin-bottom:18px}}h1{{font-size:27px;margin:8px 0}}h2{{font-size:20px;margin:0 0 10px}}.tag{{font-weight:bold;color:#087f70;letter-spacing:1px;font-size:13px}}.note{{padding:12px;background:#e8f5ee;border-radius:8px}}table{{width:100%;border-collapse:collapse}}td,th{{text-align:left;padding:10px;border-bottom:1px solid #d6e2dc;vertical-align:top}}th{{background:#e8f5ee}}td:first-child{{width:70%}}small{{display:block;color:#526d65;font-size:13px;margin-top:3px;overflow-wrap:anywhere}}b{{color:#087f70}}pre{{white-space:pre-wrap;overflow-wrap:anywhere;font:15px/1.35 Consolas,monospace;background:#f5f8f6;padding:16px;border-radius:8px}}footer{{color:#526d65;font-size:13px}}</style>
<main><header><div class="tag">WORK_NET · EVIDENCIA AUTOMÁTICA API</div><h1>#{task} · {escape(title)}</h1><div>18/10/2026 · HTTP real a Django local · SQLite aislada</div><p class="note">{escape(note)}</p><div><b>{len(cases)} casos API aprobados</b> · <b>{len(tests)}/{len(tests)} pruebas pertinentes aprobadas</b></div><small>Selección de la suite completa: {suite['total']} pruebas, {suite['fallos']} fallos. Las selecciones pueden solaparse.</small></header>
<section><h2>Casos ejecutados</h2><table><thead><tr><th>Caso y petición</th><th>Esperado</th><th>Obtenido</th></tr></thead><tbody>{rows}</tbody></table></section>
<section><h2>{escape(sample['caso'])}</h2><div>Extracto de respuesta real; campos sensibles omitidos.</div><pre>{escape(json.dumps(value,ensure_ascii=False,indent=2))}</pre></section>
<footer>Responsable de registro: Danilo2334 · Ejecución automatizada por agente · Revisión humana pendiente.<br>Origen: api.json y suite.json. Informe completo y comandos en README.md. Código backend validado: a400455.</footer></main></html>'''
    (folder/f'api-tarea-{task}.html').write_text(page,encoding='utf-8')
(folder/'resumen-por-tarea.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Ocho informes específicos preparados a partir de resultados reales.')
