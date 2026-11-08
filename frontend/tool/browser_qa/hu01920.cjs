'use strict';
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');

module.exports=async({page,cfg,run,capture,bridge,ui,write,click,waitText,login,logout,semantics,fault,faults,results})=>{
  const seed=bridge('hu01920_seed');results.preparacion_qa=seed;
  const response=(method,suffix)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+suffix);
  const top=async()=>{await page.mouse.move(200,200);await page.mouse.wheel(0,-22000);await page.waitForTimeout(300);};
  const bottom=async()=>{await page.mouse.move(200,350);await page.mouse.wheel(0,22000);await page.waitForTimeout(300);};
  const actor=name=>{const r=bridge('hu01920_'+name);(results.actores_qa??=[]).push(r);return r;};
  const snap=()=>bridge('hu01920_snapshot');
  const goto=async(path,endpoint,status=200)=>{const p=response('GET',endpoint);await page.goto(cfg.web_origin+path);await semantics();const r=await p;assert.equal(r.status(),status);return status===200?await r.json():null;};
  const history=async()=>{const b=await goto('/applications','applications/');await waitText('13 postulaciones registradas');return b;};
  const ownDetail=async(id,status=200)=>{const b=await goto('/applications/'+id,'applications/'+id+'/',status);if(status===200)await waitText('Detalle de postulación');return b?.application;};
  const logoutAt=async(role)=>{await page.goto(cfg.web_origin+(role==='empresa'?'/company-dashboard':'/dashboard'));await semantics();await top();await logout();};
  const list=async(id=3)=>{const b=await goto('/company/offers/'+id+'/applicants','company/offers/'+id+'/applications/');await waitText(b.count+' postulantes encontrados');return b;};
  const companyDetail=async(offer,id,status=200)=>{const b=await goto(`/company/offers/${offer}/applicants/${id}`,'company/applications/'+id+'/',status);if(status===200)await waitText('Perfil actual del candidato');return b?.application;};
  const pdf=async(item,company=false)=>{
    const suffix=(company?'company/':'')+'applications/'+item.id+'/cv/';
    const p=response('GET',suffix);await click('Ver CV enviado');const r=await p;assert.equal(r.status(),200);
    assert.equal(createHash('sha256').update(await r.body()).digest('hex'),item.cv.sha256);
    await page.getByRole('img',{name:'Contenido del currículum, página 1',exact:true}).waitFor();
    await capture('pdf-'+item.cv.source);await click('Cerrar documento');
  };
  const filter=async(exp='',edu='',skill='')=>{
    await top();await write('Experiencia',exp);await write('Educación',edu);await write('Habilidad',skill);
    const p=response('GET','company/offers/3/applications/');await click('Aplicar filtros');const r=await p;assert.equal(r.status(),200);const b=await r.json();await waitText(b.count+' postulantes encontrados');return b;
  };
  const orderBy=async(label)=>{
    await top();let opened=false;
    for(const locator of [page.getByRole('button',{name:/Orden/}),page.getByRole('combobox',{name:/Orden/}),page.getByRole('button',{name:'Más recientes',exact:true})]){
      if(await locator.count()===1){await locator.scrollIntoViewIfNeeded();await locator.click();opened=true;break;}
    }
    assert.equal(opened,true);await click(label,'menuitem');
  };
  let latest,uploaded,generated;
  await login('candidate','/dashboard',true);
  await run('HU019-V01',async()=>{
    await waitText('Tus accesos');await capture('acceso-dashboard');const p=response('GET','applications/');await click('Mis postulaciones');
    const b=await(await p).json();assert.equal(b.count,13);assert.equal(b.applications.length,10);assert.equal(new Set(b.applications.map(a=>a.status)).size,4);
    await waitText('13 postulaciones registradas');await top();await capture('historial-estados');
  });
  await run('HU019-V02',async()=>{
    const button=page.getByRole('button',{name:'Ver detalle',exact:true}).first();await button.scrollIntoViewIfNeeded();
    const p=response('GET',`applications/${seed.controlled_state_target}/`);await button.click();
    latest=(await(await p).json()).application;assert.equal(latest.id,seed.controlled_state_target);assert.equal(latest.status,'submitted');
    await waitText('Detalle de postulación');await capture('detalle-enviada');await pdf(latest);
  });
  await run('HU019-V03',async()=>{
    const a=actor('review');assert.equal(a.antes,'submitted');const p=response('GET',`applications/${latest.id}/`);await click('Actualizar detalle');
    assert.equal((await(await p).json()).application.status,'in_review');await waitText('Estado de postulación: En revisión');await capture('detalle-revision-actor-qa');
    const h=response('GET','applications/');await click('Volver al historial');assert.equal((await(await h).json()).applications[0].status,'in_review');await capture('historial-al-volver');
  });
  await run('HU019-V04',async()=>{
    actor('accept');const p=response('GET','applications/');await click('Actualizar historial');assert.equal((await(await p).json()).applications[0].status,'accepted');
    await waitText('Estado de postulación: Aceptada');await top();await capture('historial-aceptada-actor-qa');
  });
  await run('HU019-V05',async()=>{
    actor('reject');latest=await ownDetail(latest.id);assert.equal(latest.status,'rejected');await waitText('Estado de postulación: Rechazada');await capture('detalle-rechazada-actor-qa');
  });
  await run('HU019-V06',async()=>{
    const first=await history();const p=response('GET','applications/');await click('Siguiente');const second=await(await p).json();
    assert.equal(second.page,2);assert.equal(second.applications.length,3);assert.ok(second.applications.every(x=>!first.applications.some(y=>x.id===y.id)));
    assert.equal(second.applications.filter(x=>x.cv===null).length,2);await waitText('Página 2 de 2');await top();await capture('pagina-dos-historicos');
    await ownDetail(1);await waitText('Esta postulación anterior no tiene un CV registrado.');assert.equal(await page.getByRole('button',{name:'Ver CV enviado',exact:true}).count(),0);await capture('detalle-historico-sin-cv');
  });
  await run('HU019-V07',async()=>{
    await history();let p=response('GET','applications/');await page.reload();await semantics();assert.equal((await(await p).json()).count,13);await capture('historial-recarga');
    await logoutAt('candidato');await login('candidate','/dashboard',true);await history();await top();await capture('historial-nueva-sesion');
  });
  await run('HU019-V08',async()=>{
    await logoutAt('candidato');await login('other','/dashboard',true);const empty=await goto('/applications','applications/');assert.equal(empty.count,0);
    await waitText('Todavía no tienes postulaciones.');await capture('otro-candidato-vacio');
    await ownDetail(seed.controlled_state_target,404);await waitText('No encontramos esa postulación');await capture('detalle-ajeno-404');
    await logoutAt('candidato');await login('candidate','/dashboard',true);
  });
  await run('HU019-V09',async()=>{
    await history();fault('GET','applications/','http',503,{detail:'Fallo QA inyectado'});await page.reload();await semantics();await waitText('El servicio no está disponible.');await capture('503-inyectado');
    faults.clear();const p=response('GET','applications/');await click('Reintentar');assert.equal((await p).status(),200);await waitText('13 postulaciones registradas');await capture('recuperacion-real');
  });
  await run('HU019-V10',async()=>{
    bridge('revoke_candidate');const p=response('GET','applications/');await click('Actualizar historial');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');await capture('sesion-revocada-401');
    await login('company','/company-dashboard',true);
  });
  await run('HU020-V01',async()=>{
    await waitText('Dashboard de empresa');await top();await capture('acceso-dashboard-empresa');let p=response('GET','company/applicant-offers/');await click('Gestionar postulantes');
    const first=await(await p).json();assert.equal(first.count,17);assert.ok(first.offers.every(o=>o.id!==seed.foreign_offer));await capture('selector-ofertas-propias');
    p=response('GET','company/applicant-offers/');await click('Siguiente');const b=await(await p).json();assert.equal(b.page,2);await waitText('Página 2 de 2');await top();await capture('selector-conservadas');
    const index=b.offers.findIndex(o=>o.id===3);assert.ok(index>=0);const button=page.getByRole('button',{name:'Ver postulantes',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(200);
    p=response('GET','company/offers/3/applications/');await button.click();assert.equal((await(await p).json()).count,14);await waitText('14 postulantes encontrados');await top();await capture('lista-propia');
  });
  await run('HU020-V02',async()=>{
    const first=await list();const p=response('GET','company/offers/3/applications/');await click('Siguiente');const b=await(await p).json();assert.equal(b.page,2);assert.equal(b.applications.length,4);
    assert.ok(b.applications.every(x=>!first.applications.some(y=>x.id===y.id)));await waitText('Página 2 de 2');await top();await capture('pagina-dos-estable');
  });
  await run('HU020-V03',async()=>{
    assert.equal((await filter('BACKEND')).count,9);await bottom();await capture('filtro-experiencia');
    assert.equal((await filter('','INGENIERIA')).count,6);await bottom();await capture('filtro-educacion');
    assert.equal((await filter('','','pYtHoN')).count,6);await bottom();await capture('filtro-habilidad');
  });
  await run('HU020-V04',async()=>{
    assert.equal((await filter('Backend','Ingenieria','Python')).count,4);await bottom();await capture('filtros-combinados');
    assert.equal((await filter('Backend','Ingenieria','Rust')).count,0);await waitText('No hay postulantes que coincidan');await capture('consulta-vacia');
    const p=response('GET','company/offers/3/applications/');await click('Limpiar filtros');assert.equal((await(await p).json()).count,14);await waitText('14 postulantes encontrados');await capture('filtros-limpios');
  });
  await run('HU020-V05',async()=>{
    await orderBy('Nombre A–Z');const first=await filter('QA');assert.equal(first.count,13);assert.equal(first.page,1);
    const p=response('GET','company/offers/3/applications/');await click('Siguiente');const second=await(await p).json();assert.equal(second.page,2);assert.equal(second.applications.length,3);
    assert.ok(second.applications.every(x=>!first.applications.some(y=>x.id===y.id)));assert.equal(new URL(page.url()).searchParams.get('experience'),'QA');assert.equal(new URL(page.url()).searchParams.get('order'),'name');
    await waitText('Página 2 de 2');await capture('filtro-orden-pagina-dos');const changed=await filter('Backend');assert.equal(changed.page,1);assert.equal(changed.count,9);await capture('cambio-reinicia-pagina');
  });
  await run('HU020-V06',async()=>{
    await list();let p=response('GET','company/offers/3/applications/');await click('Siguiente');const b=await(await p).json();await waitText('Página 2 de 2');
    const index=b.applications.findIndex(a=>a.id===seed.own_ids['3']);assert.ok(index>=0);const button=page.getByRole('button',{name:'Ver perfil y CV',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(200);
    p=response('GET',`company/applications/${seed.own_ids['3']}/`);await button.click();uploaded=(await(await p).json()).application;await waitText('Perfil actual del candidato');await top();await capture('detalle-cv-subido');await bottom();await capture('perfil-actual-autorizado');await pdf(uploaded,true);
  });
  await run('HU020-V07',async()=>{
    const b=await goto('/company/offers/preserved','company/offers/preserved/');await waitText('Ofertas conservadas');const index=b.offers.findIndex(o=>o.id===4);assert.ok(index>=0);
    const button=page.getByRole('button',{name:'Ver postulantes',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();let p=response('GET','company/offers/4/applications/');await button.click();assert.equal((await(await p).json()).offer.status,'archived');await waitText('1 postulantes encontrados');await capture('archivada-lista-conservada');
    p=response('GET',`company/applications/${seed.own_ids['4']}/`);await click('Ver perfil y CV');generated=(await(await p).json()).application;await waitText('Perfil actual del candidato');assert.equal(generated.cv.source,'generated');await capture('detalle-cv-generado');await pdf(generated,true);
  });
  await run('HU020-V08',async()=>{
    actor('replace_delete_sources');let item=await companyDetail(4,generated.id);assert.equal(item.cv.sha256,generated.cv.sha256);await pdf(item,true);await capture('copia-generada-sin-fuente');
    item=await companyDetail(3,uploaded.id);assert.equal(item.cv.sha256,uploaded.cv.sha256);await pdf(item,true);await capture('copia-subida-sin-fuente');const s=snap();assert.deepEqual(s.sources_remaining,{uploaded:0,generated:0});
  });
  await run('HU020-V09',async()=>{
    await logoutAt('empresa');await login('other_company','/company-dashboard',true);const own=await goto('/company/applicants','company/applicant-offers/');assert.equal(own.count,1);await capture('otra-empresa-solo-propia');
    await goto('/company/offers/3/applicants','company/offers/3/applications/',404);await waitText('No encontramos esa oferta');await capture('oferta-ajena-404');
    await companyDetail(3,uploaded.id,404);await waitText('No encontramos esa postulación');await capture('postulante-ajeno-404');
  });
  await run('HU020-V10',async()=>{
    await logoutAt('empresa');await login('other','/dashboard',true);const before=results.red.filter(r=>r.path==='/api/company/applicant-offers/').length;
    await page.goto(cfg.web_origin+'/company/applicants');await semantics();await page.waitForURL(cfg.web_origin+'/dashboard');assert.equal(results.red.filter(r=>r.path==='/api/company/applicant-offers/').length,before);await capture('rol-candidato-protegido');
    await logoutAt('candidato');await login('draft','/company',true);await goto('/company/applicants','company/applicant-offers/',403);await waitText('completa la aprobación');await capture('empresa-pendiente-403');
    await page.goto(cfg.web_origin+'/company');await semantics();await logout();await page.goto(cfg.web_origin+'/company/applicants');await semantics();await page.waitForURL(cfg.web_origin+'/login');await capture('anonimo-protegido');await login('company','/company-dashboard',true);
  });
  await run('HU020-V11',async()=>{
    await list();fault('GET','company/offers/3/applications/','http',503,{detail:'Fallo QA inyectado'});await page.reload();await semantics();await waitText('El servicio no está disponible.');await capture('503-inyectado-lista');faults.clear();
    let p=response('GET','company/offers/3/applications/');await click('Reintentar');assert.equal((await p).status(),200);await waitText('14 postulantes encontrados');await capture('recuperacion-real-lista');
    bridge('revoke_company');p=response('GET','company/offers/3/applications/');await click('Actualizar postulantes');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');await capture('sesion-empresa-401');await login('company','/company-dashboard',true);
  });
  await run('HU020-V12',async()=>{
    await page.setViewportSize({width:390,height:844});await list();await top();await capture('filtros-movil');await bottom();await capture('lista-movil');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
    await companyDetail(3,uploaded.id);await top();await capture('detalle-movil');await pdf(uploaded,true);await bottom();await capture('perfil-movil');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);await page.setViewportSize({width:1440,height:1000});
  });
  await run('HU020-V13',async()=>{
    await companyDetail(1,1);await waitText('Esta postulación anterior no tiene un CV registrado.');assert.equal(await page.getByRole('button',{name:'Ver CV enviado',exact:true}).count(),0);await capture('historico-sin-cv');
  });
  await run('REGRESION-V01',async()=>{
    await logoutAt('empresa');await login('other','/dashboard',true);await page.goto(cfg.web_origin+'/offers/search');await semantics();await write('Palabras clave','Oferta respuesta perdida QA');let p=response('GET','offers/search/');await click('Buscar');assert.equal((await(await p).json()).count,1);
    p=response('GET','offers/7/application/');await click('Postularme');assert.equal((await p).status(),200);await waitText('Postular a oferta');await click('Continuar');p=response('POST','offers/7/application/');await click('Confirmar postulación');const r=await p;assert.equal(r.status(),201);const item=(await r.json()).application;assert.equal(item.cv.source,'uploaded');await waitText('Postulación registrada correctamente.');await capture('hu018-postulacion-real');
    p=response('GET','offers/7/application/');await page.reload();await semantics();assert.equal((await(await p).json()).application.id,item.id);await waitText('Postulación registrada correctamente.');await capture('hu018-recarga-sin-duplicado');
  });
  await run('REGRESION-V02',async()=>{
    const b=await goto('/offers/saved','offers/saved/');assert.ok(b.offers.some(o=>o.id===3&&o.is_active===false));await waitText('Estado: Cerrada');await top();await capture('hu015-hu017-guardada-inactiva');
    const index=b.offers.findIndex(o=>o.id===3);assert.equal(await page.getByRole('button',{name:'Postularme',exact:true}).nth(index).isEnabled(),false);
  });
  await run('REGRESION-V03',async()=>{
    await logoutAt('candidato');await login('candidate','/dashboard',true);await history();await ownDetail(seed.own_ids['4']);await waitText('Estado de postulación: En revisión');await pdf(generated);await capture('hu012-documento-y-estado-conservados');
    const s=snap();assert.equal(s.applications,28);assert.equal(s.own_applications,13);assert.equal(s.new_applications,1);assert.equal(s.new_notices,1);assert.equal(s.duplicates,0);assert.equal(s.controlled_status,'rejected');results.hu01920=s;
  });
};
