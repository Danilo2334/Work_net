'use strict';
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');

module.exports=async({page,cfg,run,capture,bridge,ui,write,click,waitText,login,logout,semantics,fault,faults,results})=>{
  const response=(method,suffix)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+suffix);
  const snap=()=>bridge('hu018_snapshot');
  const actor=name=>{const result=bridge('hu018_'+name);(results.actores_qa??=[]).push(result);return result;};
  const top=async()=>{await page.mouse.move(200,250);await page.mouse.wheel(0,-18000);await page.waitForTimeout(350);};
  const bottom=async()=>{await page.mouse.move(200,400);await page.mouse.wheel(0,18000);await page.waitForTimeout(350);};
  const unchanged=()=>{const s=snap();for(const k of ['information_unchanged','other_offers_unchanged','legacy_applications_unchanged','saved_unchanged','other_uploaded_unchanged','other_generated_unchanged','old_notifications_unchanged','correct_recipient_and_one_notice_per_new','snapshot_hashes_and_pdf_valid','database_unique_constraint'])assert.equal(s[k],true,k);assert.equal(s.duplicates,0);assert.equal(s.offers,17);return s;};
  let form,uploadedReceipt,generatedReceipt,lostReceipt;
  const history=async count=>{const pending=response('GET','applications/');await page.goto(cfg.web_origin+'/applications');await semantics();assert.equal((await pending).status(),200);await waitText(`${count} postulaciones registradas`);};
  const dashboard=async()=>{await page.goto(cfg.web_origin+'/dashboard');await semantics();await waitText('Tus accesos');};
  const openForm=async(id,title)=>{
    await page.goto(cfg.web_origin+'/offers/search');await semantics();await waitText('Buscar ofertas');
    await write('Palabras clave',title);let pending=response('GET','offers/search/');await click('Buscar');assert.equal((await pending).status(),200);await waitText('1 ofertas encontradas');
    pending=response('GET',`offers/${id}/application/`);await click('Postularme');const r=await pending;assert.equal(r.status(),200);form=await r.json();await page.waitForURL(cfg.web_origin+`/offers/${id}/apply`);await waitText('Postular a oferta');return form;
  };
  const chooseGenerated=async()=>{
    const candidates=[page.getByRole('button',{name:/Currículum/}),page.getByRole('combobox',{name:/Currículum/}),page.getByRole('button',{name:/CV subido:/})];
    let opened=false;for(const item of candidates){if(await item.count()===1){await item.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await item.click();opened=true;break;}}
    assert.equal(opened,true,'selector de CV accesible');
    const label='CV generado: '+form.cv_options.find(c=>c.source==='generated').label;
    await click(label,'menuitem');
  };
  const submit=async(id,source)=>{
    await click('Continuar');await waitText('Revisa tu postulación');await top();await capture('revision-'+source);
    const pending=response('POST',`offers/${id}/application/`);await click('Confirmar postulación');const r=await pending;assert.equal(r.status(),201);const b=await r.json();assert.equal(b.application.cv.source,source);await waitText('Postulación registrada correctamente.');await top();await capture('confirmacion-'+source);return b.application;
  };
  const openPdf=async(item,index=0)=>{
    const pending=response('GET',`applications/${item.id}/cv/`);const button=page.getByRole('button',{name:'Ver CV enviado',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();const r=await pending;assert.equal(r.status(),200);const bytes=await r.body();assert.equal(createHash('sha256').update(bytes).digest('hex'),item.cv.sha256);
    await page.getByRole('img',{name:'Contenido del currículum, página 1',exact:true}).waitFor();await capture('pdf-'+item.cv.source);await click('Cerrar documento');
  };
  const transition=async(id,archive)=>{
    const pending=response('GET','company/offers/active/');await click('Mis ofertas activas');const rows=(await(await pending).json()).offers;await waitText('Mis ofertas activas');const index=rows.findIndex(o=>o.id===id);assert.ok(index>=0);
    const action=response('POST',`company/offers/${id}/transition/`);const button=page.getByRole('button',{name:archive?'Archivar oferta':'Cerrar oferta',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();await click(archive?'Confirmar archivado':'Confirmar cierre');assert.equal((await action).status(),200);await waitText(archive?'Oferta archivada correctamente.':'Oferta cerrada correctamente.');await click('Volver al dashboard');await page.waitForURL(cfg.web_origin+'/company-dashboard');
  };

  await login('candidate','/dashboard',true);
  await run('HU018-V01',async()=>{
    await waitText('Mis postulaciones');await capture('accesos-dashboard');
    await page.goto(cfg.web_origin+'/offers/search');await semantics();await write('Palabras clave','Oferta CV subido QA');let pending=response('GET','offers/search/');await click('Buscar');assert.equal((await pending).status(),200);await waitText('1 ofertas encontradas');
    let release;const gate=new Promise(resolve=>{release=resolve;});const target=cfg.api_origin+'/api/offers/3/application/**';const delayed=async route=>{await gate;await route.continue();};await page.route(target,delayed);
    pending=response('GET','offers/3/application/');await click('Postularme');await waitText('Cargando postulación…');await capture('carga-real-retenida');release();const r=await pending;assert.equal(r.status(),200);form=await r.json();await page.unroute(target,delayed);await waitText('Elige el currículum');assert.deepEqual(form.cv_options.map(c=>c.source),['uploaded','generated']);await top();await capture('selector-dos-cv');
  });
  await run('HU018-V02',async()=>{uploadedReceipt=await submit(3,'uploaded');await openPdf(uploadedReceipt);assert.equal(unchanged().new_notices,1);});
  await run('HU018-V03',async()=>{
    await dashboard();const pending=response('GET','offers/saved/');await click('Guardados');const rows=(await(await pending).json()).offers;await waitText('6 ofertas guardadas');const index=rows.findIndex(o=>o.id===4);assert.ok(index>=0);
    const context=response('GET','offers/4/application/');const button=page.getByRole('button',{name:'Postularme',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();form=await(await context).json();await waitText('Elige el currículum');await chooseGenerated();generatedReceipt=await submit(4,'generated');await openPdf(generatedReceipt);assert.equal(unchanged().new_notices,2);
  });
  await run('HU018-V04',async()=>{
    await history(4);await top();await capture('historial-ambos-cv');let pending=response('GET','applications/');await page.reload();await semantics();assert.equal((await pending).status(),200);await waitText('4 postulaciones registradas');await capture('historial-recarga');await dashboard();await logout();await login('candidate','/dashboard',true);await history(4);await capture('historial-nueva-sesion');
  });
  await run('HU018-V05',async()=>{
    await dashboard();await logout();await login('other','/dashboard',true);await history(0);await capture('otro-candidato-historial-vacio');await openForm(3,'Oferta CV subido QA');assert.equal(form.application,null);assert.equal(form.cv_options.length,1);assert.equal(form.cv_options[0].source,'uploaded');await capture('cv-propio-del-otro-candidato');await dashboard();await logout();
  });
  await run('HU018-V06',async()=>{
    await login('company','/company-dashboard',true);await waitText('Nueva postulación: Candidato principal QA');await bottom();await capture('avisos-empresa-destinataria');await logout();await login('other_company','/company-dashboard',true);await waitText('Todavía no has recibido postulaciones.');assert.ok(!(await ui()).includes('Nueva postulación:'));await capture('otra-empresa-sin-avisos');await logout();await login('candidate','/dashboard',true);
  });
  await run('HU018-V07',async()=>{
    await openForm(5,'Oferta cambia a cerrada QA');await click('Continuar');actor('close_stale');const before=snap().applications;const pending=response('POST','offers/5/application/');await click('Confirmar postulación');assert.equal((await pending).status(),404);await waitText('ya no está activa');assert.equal(snap().applications,before);await capture('cierre-posterior-formulario-rechazado');const refreshed=response('GET','offers/5/application/');await click('Comprobar postulación');assert.equal((await refreshed).status(),200);await waitText('Esta oferta ya no está activa y no recibe nuevas postulaciones.');await capture('cerrada-no-permite-continuar');
  });
  await run('HU018-V08',async()=>{
    await openForm(6,'Oferta cambia a archivada QA');await chooseGenerated();await click('Continuar');actor('archive_stale');const pending=response('POST','offers/6/application/');await click('Confirmar postulación');assert.equal((await pending).status(),404);await waitText('ya no está activa');await capture('archivado-posterior-formulario-rechazado');assert.equal(snap().applications,4);
  });
  await run('HU018-V09',async()=>{
    await openForm(8,'Oferta CV eliminado QA');await click('Continuar');actor('delete_uploaded');let pending=response('POST','offers/8/application/');await click('Confirmar postulación');assert.equal((await pending).status(),400);await waitText('no está disponible');await capture('cv-eliminado-tras-seleccion');actor('delete_generated');await openForm(9,'Oferta sin CV QA');await waitText('Necesitas un currículum');await capture('sin-cv');assert.equal(await page.getByRole('button',{name:'Continuar',exact:true}).count(),0);
    // La continuación real sin CV se completa desde el editor existente.
    await click('Ir a Mi currículum');await page.waitForURL(cfg.web_origin+'/curriculum?apply_offer=9');await waitText('Crear mi CV');await click('Crear mi CV');await waitText('Información personal');
    await write('Nombre completo','CV creado para continuar HU018 QA');const save=response('PUT','curriculum/generated/');await click('Guardar CV');assert.ok([200,201].includes((await save).status()));await waitText('Tu currículum se guardó correctamente.');await click('Continuar postulación');await page.waitForURL(cfg.web_origin+'/offers/9/apply');await waitText('Elige el currículum');await capture('retorno-oferta-despues-crear-cv');assert.equal(snap().applications,4);actor('restore_sources');
  });
  await run('HU018-V10',async()=>{
    await openForm(10,'Oferta CV cambiado QA');await chooseGenerated();await click('Continuar');actor('change_generated');const pending=response('POST','offers/10/application/');await click('Confirmar postulación');assert.equal((await pending).status(),400);await waitText('El CV cambió');await capture('cv-cambio-version-rechazado');assert.equal(snap().applications,4);
  });
  await run('HU018-V11',async()=>{
    await history(4);await openPdf(generatedReceipt,0);await openPdf(uploadedReceipt,1);await capture('copias-conservadas-tras-cambios');unchanged();
  });
  await run('HU018-V12',async()=>{
    fault('GET','applications/','abort');await page.reload();await semantics();await waitText('No pudimos conectarnos.');await capture('red-inyectada-historial');faults.clear();let pending=response('GET','applications/');await click('Reintentar');assert.equal((await pending).status(),200);await waitText('4 postulaciones registradas');
    fault('GET','applications/','http',503,{detail:'Fallo QA inyectado'});await page.reload();await semantics();await waitText('El servicio no está disponible.');await capture('503-inyectado-historial');faults.clear();pending=response('GET','applications/');await click('Reintentar');assert.equal((await pending).status(),200);await waitText('4 postulaciones registradas');await capture('recuperacion-real-historial');
  });
  await run('HU018-V13',async()=>{
    await openForm(7,'Oferta respuesta perdida QA');await click('Continuar');fault('POST','offers/7/application/','abort');await click('Confirmar postulación');await waitText('No pudimos conectarnos.');assert.equal(snap().applications,4);await capture('fallo-envio-sin-registro');faults.clear();let pending=response('GET','offers/7/application/');await click('Comprobar postulación');assert.equal((await pending).status(),200);await waitText('No hay una postulación registrada.');await click('Continuar');
    const target=cfg.api_origin+'/api/offers/7/application/';const lost=async route=>{const r=await route.fetch();assert.equal(r.status(),201);assert.equal(r.headers()['x-worknet-qa-run'],cfg.nonce);lostReceipt=(await r.json()).application;results.red.push({method:'POST',path:'/api/offers/7/application/',status:201,inyectada:false,respuesta_perdida:true});await route.abort('failed');};await page.route(target,lost);await click('Confirmar postulación');await waitText('No pudimos conectarnos.');assert.equal(snap().applications,5);assert.ok(!(await ui()).includes('Postulación registrada correctamente.'));await capture('respuesta-aceptada-perdida');await page.unroute(target,lost);
    pending=response('GET','offers/7/application/');await click('Comprobar postulación');assert.equal((await pending).status(),200);await waitText('Postulación registrada correctamente.');await capture('reconciliacion-real-sin-reenvio');
  });
  await run('HU018-V14',async()=>{
    const pending=response('GET','offers/7/application/');await page.reload();await semantics();const data=await(await pending).json();assert.equal(data.application.id,lostReceipt.id);await waitText('Postulación registrada correctamente.');assert.equal(await page.getByRole('button',{name:'Confirmar postulación',exact:true}).count(),0);const s=unchanged();assert.equal(s.new_notices,3);assert.equal(s.applications,5);await capture('recarga-registro-unico');
  });
  await run('HU018-V15',async()=>{
    await dashboard();await logout();await login('company','/company-dashboard',true);await transition(3,false);await transition(4,true);await waitText('Nueva postulación: Candidato principal QA');await bottom();await capture('historial-y-avisos-tras-inactivacion');const s=unchanged();assert.deepEqual(s.states,{'3':'closed','4':'archived','5':'closed','6':'archived'});assert.equal(s.applications,5);assert.equal(s.new_notices,3);await logout();await login('candidate','/dashboard',true);
  });
  await run('HU018-V16',async()=>{
    await history(5);await top();await capture('historial-con-postulaciones-conservadas');await openPdf(generatedReceipt,1);await openPdf(uploadedReceipt,2);await bottom();await capture('historial-cv-subido-conservado');
  });
  await run('HU018-V17',async()=>{
    await page.setViewportSize({width:390,height:844});await history(5);await top();await capture('historial-movil');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
    await dashboard();let pending=response('GET','offers/saved/');await click('Guardados');const b=await(await pending).json();assert.equal(b.offers[0].id,17);await waitText('Estado: Vencida');await top();await capture('vencida-guardada-no-postulable-movil');assert.equal(await page.getByRole('button',{name:'Postularme',exact:true}).first().isEnabled(),false);await page.setViewportSize({width:1440,height:1000});
  });
  await run('HU018-V18',async()=>{
    await openForm(11,'Oferta sesión revocada QA');await click('Continuar');bridge('revoke_candidate');const pending=response('POST','offers/11/application/');await click('Confirmar postulación');assert.equal((await pending).status(),401);await page.waitForURL(cfg.web_origin+'/login');await waitText('Tu sesión ya no es válida.');assert.equal(snap().applications,5);await capture('sesion-401-real');
  });
  await run('HU018-V19',async()=>{
    await login('company','/company-dashboard',true);let before=results.red.filter(r=>r.path==='/api/applications/').length;await page.goto(cfg.web_origin+'/applications');await semantics();await page.waitForURL(cfg.web_origin+'/company-dashboard');assert.equal(results.red.filter(r=>r.path==='/api/applications/').length,before);await page.goto(cfg.web_origin+'/offers/11/apply');await semantics();await page.waitForURL(cfg.web_origin+'/company-dashboard');await capture('rol-empresa-protegido');await logout();await page.goto(cfg.web_origin+'/offers/11/apply');await semantics();await page.waitForURL(cfg.web_origin+'/login');await capture('anonimo-protegido');results.hu018=unchanged();assert.equal(results.hu018.applications,5);assert.equal(results.hu018.new_notices,3);
  });
};
