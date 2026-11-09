'use strict';
const assert=require('node:assert/strict');
module.exports=async({page,cfg,run,capture,bridge,ui,write,click,waitText,login,logout,semantics,fault,faults,results,privacy,privateCredentials})=>{
  const seed=bridge('hu026_seed');results.preparacion_qa=seed;
  const backups=new Map();
  const response=(method,path)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+path);
  const top=async()=>{await page.mouse.move(200,200);await page.mouse.wheel(0,-25000);await page.waitForTimeout(250);};
  const text=async(value)=>{await waitText(value);await page.waitForTimeout(150);};
  const checkbox=async(name)=>{const c=page.getByRole('checkbox',{name,exact:true});await c.scrollIntoViewIfNeeded();await c.focus();await page.waitForTimeout(200);await page.keyboard.press('Space');await page.waitForTimeout(200);};
  const tokenless=b=>assert.equal(Object.hasOwn(b,'token'),false);
  const passwordStep=async(actor,{enrollment=false,status=202}={})=>{
    privacy(true);
    const credential=privateCredentials(actor==='created'?'created_admin':actor);
    const remember=page.getByRole('checkbox',{name:'Recordar sesión',exact:true});
    if(!(await remember.isChecked()))await checkbox('Recordar sesión');
    await write('Correo electrónico',credential.email);await write('Contraseña',credential.password);
    const pending=response('POST','login/');await click('Iniciar sesión');const r=await pending;assert.equal(r.status(),status);
    const body=await r.json();tokenless(body);
    if(status===202){assert.equal(body.enrollment_required,enrollment);await text(enrollment?'Configurar doble factor':'Verificar doble factor');privacy(false);}
    return body;
  };
  const prepare=async()=>{privacy(true);const p=response('POST','admin/mfa/setup/');await click('Preparar autenticador');assert.equal((await p).status(),200);await text('Mostrar clave privada');assert.equal((await ui()).includes('text: '+('A'.repeat(32))),false);privacy(false);};
  const finish=async(actor,{enrollment=false}={})=>{
    privacy(true);const code=bridge('hu026_code',actor).code;
    await write('Código del autenticador',code);
    const p=response('POST','admin/mfa/verify/');await click('Verificar segundo factor');const r=await p;assert.equal(r.status(),200);
    const body=await r.json();assert.equal(body.user.mfa_verified,true);
    if(enrollment){assert.equal(body.recovery_codes.length,8);backups.set(actor,body.recovery_codes[0]);await text('Autenticador confirmado');privacy(false);await capture('autenticador-confirmado-codigos-ocultos');await checkbox('He guardado mis códigos de recuperación.');await click('Continuar a administración');}
    await page.waitForURL(cfg.web_origin+'/admin-dashboard');await text('Administración');privacy(false);
  };
  const goList=async()=>{const p=response('GET','admin/accounts/');await click('Administradores y permisos');const r=await p;assert.equal(r.status(),200);const b=await r.json();await text('Administradores y permisos');return b;};
  const firstEditor=async()=>{
    await top();const buttons=page.getByRole('button',{name:'Configurar cuenta y permisos',exact:true});
    // The API's stable ID order puts the named reviewer first; assert before acting.
    await text('Revisora HU026 QA');await buttons.first().scrollIntoViewIfNeeded();await buttons.first().click();await text('Configurar Revisora HU026 QA');await top();
  };
  const saveEditor=async()=>{const p=response('PATCH','admin/accounts/'+seed.reviewer_id+'/');await click('Guardar cambios');const r=await p;assert.equal(r.status(),200);await text('Cambios guardados.');return(await r.json()).administrator;};
  const toggleState=async(label)=>{
    const c=page.getByRole('switch',{name:label,exact:true});
    if(await c.count()){await c.scrollIntoViewIfNeeded();await c.click();}
    else{await checkbox(label);}
  };

  await run('HU026-V01',async()=>{
    await page.goto(cfg.web_origin+'/admin/accounts');await semantics();await page.waitForURL(cfg.web_origin+'/login');await capture('ruta-administrativa-protegida');
  });
  await run('HU026-V02',async()=>{await passwordStep('principal',{enrollment:true});assert.equal(await page.getByRole('button',{name:'Administradores y permisos',exact:true}).count(),0);await capture('contrasena-sin-sesion-exige-doble-factor');});
  await run('HU026-V03',async()=>{await prepare();assert.equal(await page.getByText(/^[A-Z2-7]{32}$/).count(),0);await capture('preparacion-autenticador-clave-oculta');});
  await run('HU026-V04',async()=>{
    privacy(true);const invalid=bridge('hu026_wrong_code','principal').code;await write('Código del autenticador',invalid);
    const p=response('POST','admin/mfa/verify/');await click('Verificar segundo factor');assert.equal((await p).status(),400);await text('Código incorrecto, utilizado o temporalmente bloqueado.');await write('Código del autenticador','');privacy(false);await capture('codigo-incorrecto-rechazado');
    await page.waitForTimeout(1200);await finish('principal',{enrollment:true});
  });
  await run('HU026-V05',async()=>{
    await top();await text('Candidatos registrados:');await text('Solicitudes pendientes: 1');
    for(const name of ['Administradores y permisos','Eventos administrativos','Revisar empresas'])assert.equal(await page.getByRole('button',{name,exact:true}).count(),1);
    assert.equal(await page.getByRole('button',{name:'Gestionar postulantes',exact:true}).count(),0);await capture('hu007-dashboard-conteos-accesos');
    const review=response('GET','admin/companies/');await click('Revisar empresas');assert.equal((await review).status(),200);await text('Empresa solicitante HU026 QA');await capture('solicitud-empresarial-pendiente');
    await page.goto(cfg.web_origin+'/admin-dashboard');await semantics();await text('Administradores y permisos');
  });
  await run('HU026-V06',async()=>{
    let b=await goList();assert.equal(b.count,28);assert.equal(b.results.length,20);assert.equal(b.results[0].id,seed.reviewer_id);assert.equal(b.results[1].id,seed.principal_id);
    assert.equal(await page.getByRole('button',{name:'Configurar cuenta y permisos',exact:true}).nth(1).isDisabled(),true);await capture('listado-nombre-correo-rol-estado-principal-protegido');
    const p=response('GET','admin/accounts/');await click('Siguiente');b=await(await p).json();assert.equal(b.page,2);assert.equal(b.results.length,8);await top();await capture('paginacion-segunda-pagina');
    const back=response('GET','admin/accounts/');await click('Anterior');assert.equal((await back).status(),200);await top();
  });
  await run('HU026-V07',async()=>{
    await click('Crear administrador');privacy(true);
    await write('Nombre completo','Administradora creada HU026 QA');await write('Correo electrónico',privateCredentials('created_admin').email);await write('Contraseña inicial privada',privateCredentials('created_admin').password);
    await page.getByRole('button',{name:/Rol administrativo/}).click();await click('Gestor','menuitem');
    for(const name of ['Gestionar cuentas administrativas','Configurar permisos administrativos'])await checkbox(name);
    const p=response('POST','admin/accounts/');await click('Guardar cambios');const r=await p;assert.equal(r.status(),201);const b=await r.json();assert.equal(b.administrator.email_verified,false);assert.equal(b.administrator.permissions.length,5);
    await text('Cuenta creada.');privacy(false);await top();await capture('alta-confirmada-verificacion-y-mfa-pendientes');
  });
  await run('HU026-V08',async()=>{
    await firstEditor();await checkbox('Validar empresas');const b=await saveEditor();assert.equal(b.version,1);assert.equal(b.permissions.includes('review_companies'),false);await top();await capture('permisos-retirados-guardados');
  });
  await run('HU026-V09',async()=>{
    await firstEditor();await toggleState('Cuenta activa');let b=await saveEditor();assert.equal(b.is_active,false);assert.equal(b.version,2);await top();await capture('cuenta-desactivada');
    await firstEditor();await toggleState('Cuenta inactiva');b=await saveEditor();assert.equal(b.is_active,true);assert.equal(b.version,3);await top();await capture('cuenta-reactivada');
  });
  await run('HU026-V10',async()=>{
    fault('GET','admin/accounts/','http',503,{detail:'Fallo QA identificado'});await click('Actualizar listado');await text('El servicio no está disponible.');await capture('error-carga-inyectado-identificado');
    faults.delete('GET /api/admin/accounts/');const p=response('GET','admin/accounts/');await click('Reintentar');assert.equal((await p).status(),200);await text('Revisora HU026 QA');await capture('reintento-real-listado');
  });
  await run('HU026-V11',async()=>{
    await page.setViewportSize({width:390,height:844});await top();await capture('movil-listado-administrativo');await firstEditor();await page.getByRole('button',{name:'Guardar cambios',exact:true}).scrollIntoViewIfNeeded();await page.waitForTimeout(250);await capture('movil-configuracion-permisos-guardar');await click('Cancelar');
  });
  await run('HU026-V12',async()=>{
    await click('Volver a administración');await text('Administración');await logout();await passwordStep('manager',{enrollment:true});await prepare();await finish('manager',{enrollment:true});
    assert.equal(await page.getByRole('button',{name:'Revisar empresas',exact:true}).count(),0);assert.equal(await page.getByRole('button',{name:'Eventos administrativos',exact:true}).count(),0);await capture('gestor-accesos-limitados-por-permisos');
    await goList();assert.equal(await page.getByRole('button',{name:'Crear administrador',exact:true}).count(),0);await firstEditor();assert.equal(await page.getByRole('checkbox',{name:'Validar empresas',exact:true}).isDisabled(),true);await capture('gestor-sin-edicion-de-permisos');await click('Cancelar');
  });
  await run('HU026-V13',async()=>{
    await page.setViewportSize({width:1440,height:1000});await click('Volver a administración');await text('Administración');await logout();await passwordStep('created',{status:400});
    // The real file-mail link is consumed privately by a QA API actor, not claimed as SMTP delivery.
    assert.equal(bridge('hu026_verify_created').verified,true);
    await write('Contraseña','');await passwordStep('created',{enrollment:true});await capture('cuenta-nueva-correo-verificado-exige-mfa');await prepare();await finish('created',{enrollment:true});
  });
  await run('HU026-V14',async()=>{
    const p=response('GET','admin/events/');await click('Eventos administrativos');assert.equal((await p).status(),200);await text('Autenticador configurado');await capture('eventos-altas-y-doble-factor');
    await click('Volver a administración');await text('Administración');assert.equal(await page.getByRole('button',{name:'Crear administrador',exact:true}).count(),0);
  });
  await run('HU026-V15',async()=>{
    await logout();await passwordStep('created',{enrollment:false});await click('Perdí mi autenticador');privacy(true);await write('Código de recuperación privado',backups.get('created'));
    const p=response('POST','admin/mfa/verify/');await click('Verificar segundo factor');const r=await p;assert.equal(r.status(),202);tokenless(await r.json());await text('Configurar doble factor');privacy(false);await capture('recuperacion-obliga-a-reenrolar');
    await prepare();await finish('created',{enrollment:true});await capture('acceso-recuperado-con-segundo-factor');
  });
  await run('HU026-V16',async()=>{
    await goList();assert.equal(bridge('hu026_revoke').revoked,true);const p=response('GET','admin/accounts/');await click('Actualizar listado');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');await text('Tu sesión ya no es válida.');await capture('sesion-revocada-sin-cuentas-privadas');
  });
  await run('HU026-V17',async()=>{
    await login('candidate','/dashboard',true);await page.goto(cfg.web_origin+'/admin/accounts');await semantics();await page.waitForURL(cfg.web_origin+'/dashboard');assert.equal(await page.getByRole('button',{name:'Administradores y permisos',exact:true}).count(),0);await capture('candidato-sin-acceso-administrativo');
    results.persistencia=bridge('hu026_snapshot');assert.equal(results.persistencia.business_unchanged,true);assert.equal(results.persistencia.non_admin_accounts_unchanged,true);assert.equal(results.persistencia.no_duplicate_emails,true);
    results.alcance='17 casos HU026 más inicio: UI real de escritorio y móvil web emulado, contraseñas sin sesión antes de TOTP, alta/estado/permisos, cuenta principal protegida, error inyectado identificado y reintento real, enlace real de correo a archivos, autenticador software QA local con reloj real y servidor django-otp, recuperación/reenrolamiento y revocación. No acredita SMTP ni dispositivo físico. Sin cambios a negocio ni cuentas no administrativas.';
  });
};
