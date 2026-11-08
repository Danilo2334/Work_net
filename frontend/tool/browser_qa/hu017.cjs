'use strict';
const assert = require('node:assert/strict');

module.exports = async ({page,cfg,run,capture,bridge,ui,write,click,waitText,login,logout,semantics,fault,faults,results}) => {
  const saved='offers/saved/', search='offers/search/';
  const path=id=>`offers/${id}/saved/`;
  const response=(method,suffix)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+suffix);
  const top=async()=>{await page.mouse.move(200,250);await page.mouse.wheel(0,-18000);await page.waitForTimeout(350);};
  const bottom=async()=>{await page.mouse.move(200,400);await page.mouse.wheel(0,18000);await page.waitForTimeout(350);};
  const snap=()=>bridge('hu017_snapshot');
  const unchanged=()=>{const s=snap();for(const key of ['information_unchanged','other_offers_unchanged','applications_unchanged','other_saved_unchanged','database_unique_constraint'])assert.equal(s[key],true,key);assert.equal(s.duplicates,0);assert.equal(s.offers,17);return s;};
  const openSaved=async count=>{const pending=response('GET',saved);await click('Guardados');assert.equal((await pending).status(),200);await page.waitForURL(cfg.web_origin+'/offers/saved');await waitText(`${count} ofertas guardadas`);};
  const query=async(q,count)=>{await write('Palabras clave',q);const pending=response('GET',search);await click('Buscar');const r=await pending;assert.equal(r.status(),200);await waitText(`${count} ofertas encontradas`);return r;};
  const toDashboard=async(company=false)=>{await click('Volver al dashboard');await page.waitForURL(cfg.web_origin+(company?'/company-dashboard':'/dashboard'));await waitText(company?'Dashboard de empresa':'Tus accesos');};
  const toSearch=async()=>{await click('Volver al buscador');await page.waitForURL(cfg.web_origin+'/offers/search');await waitText('Buscar ofertas');};
  const mutate=async(method,id,label,index=0)=>{
    const pending=response(method,path(id));const button=page.getByRole('button',{name:label,exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();assert.equal((await pending).status(),200);await page.waitForTimeout(300);
  };
  const remove=async(id,count,index=0)=>{await mutate('DELETE',id,'Quitar de Guardados',index);await waitText(`${count} ofertas guardadas`);};
  await login('candidate','/dashboard',true);
  await run('HU017-V01',async()=>{
    await waitText('Guardados');await capture('dashboard-acceso-y-acciones');
    let release;const gate=new Promise(resolve=>{release=resolve;});const target=cfg.api_origin+'/api/offers/saved/**';
    const delayed=async route=>{await gate;await route.continue();};await page.route(target,delayed);
    const pending=response('GET',saved);await click('Guardados');await waitText('Cargando Guardados…');await capture('carga-real-retenida');release();assert.equal((await pending).status(),200);await page.unroute(target,delayed);
    await waitText('1 ofertas guardadas');await waitText('Oferta Flutter QA');await waitText('Estado: Activa');await top();await capture('guardado-inicial');
  });
  await run('HU017-V02',async()=>{
    await toSearch();await waitText('13 ofertas encontradas');await query('Oferta Django QA',1);
    await mutate('PUT',2,'Guardar oferta');await waitText('Oferta guardada.');await top();await capture('guardar-desde-busqueda');
    await openSaved(2);await top();await capture('lista-sincronizada');await remove(2,1);const refreshed=response('GET',search);await toSearch();const result=await refreshed;assert.equal(new URL(result.url()).searchParams.get('q'),'Oferta Django QA');await waitText('1 ofertas encontradas');
    const text=await ui();assert.ok(!text.includes('Oferta guardada.'));assert.ok(text.includes('Guardar oferta'));await top();await capture('retiro-reflejado-en-busqueda');
  });
  await run('HU017-V03',async()=>{
    await mutate('PUT',2,'Guardar oferta');let pending=response('GET',search);await page.reload();await semantics();assert.equal((await pending).status(),200);await waitText('13 ofertas encontradas');assert.equal(snap().own_saved.length,2);
    await openSaved(2);pending=response('GET',saved);await page.reload();await semantics();assert.equal((await pending).status(),200);await waitText('2 ofertas guardadas');await top();await capture('persistencia-recarga');
    await toDashboard();await logout();await login('candidate','/dashboard',true);await openSaved(2);await capture('persistencia-nueva-sesion');
  });
  await run('HU017-V04',async()=>{
    await toDashboard();await logout();await login('other','/dashboard',true);await openSaved(2);const text=await ui();assert.ok(!text.includes('Oferta Django QA'));assert.ok(text.includes('Favorito QA 03'));await top();await capture('otro-candidato-solo-propios');
    await toSearch();await query('Oferta Django QA',1);assert.equal(await page.getByRole('button',{name:'Guardar oferta',exact:true}).count(),1);await top();await capture('estado-privado-por-candidato');
    await toDashboard();await logout();await login('candidate','/dashboard',true);await openSaved(2);
  });
  await run('HU017-V05',async()=>{
    await remove(2,1);await remove(1,0);await waitText('Todavía no tienes ofertas guardadas.');unchanged();await top();await capture('vacio-real');await toDashboard();
  });
  await run('HU017-V06',async()=>{
    fault('GET',saved,'abort');await click('Guardados');await waitText('No pudimos conectarnos.');await top();await capture('red-inyectada');faults.clear();let pending=response('GET',saved);await click('Reintentar');assert.equal((await pending).status(),200);await waitText('0 ofertas guardadas');
    fault('GET',saved,'http',503,{detail:'Fallo QA inyectado.'});await page.reload();await semantics();await waitText('El servicio no está disponible.');await capture('503-inyectado');faults.clear();pending=response('GET',saved);await click('Reintentar');assert.equal((await pending).status(),200);await waitText('0 ofertas guardadas');await capture('reintento-real');
  });
  await run('HU017-V07',async()=>{
    await toDashboard();await mutate('PUT',2,'Guardar oferta');await waitText('Quitar de Guardados');assert.ok(snap().own_saved.includes(2));await capture('guardar-en-ofertas-recientes');await click('Buscar ofertas');await waitText('13 ofertas encontradas');await query('Oferta Flutter QA',1);
  });
  await run('HU017-V08',async()=>{
    fault('PUT',path(1),'abort');await click('Guardar oferta');await waitText('No pudimos conectarnos.');assert.ok(!snap().own_saved.includes(1));await top();await capture('fallo-al-guardar-inyectado');faults.clear();const pending=response('GET',search);await click('Reintentar');assert.equal((await pending).status(),200);await waitText('1 ofertas encontradas');assert.equal(await page.getByRole('button',{name:'Guardar oferta',exact:true}).count(),1);
  });
  await run('HU017-V09',async()=>{
    let forwarded=false;const target=cfg.api_origin+'/api/'+path(1);const lost=async route=>{const r=await route.fetch();assert.equal(r.status(),200);assert.equal(r.headers()['x-worknet-qa-run'],cfg.nonce);forwarded=true;results.red.push({method:'PUT',path:'/api/'+path(1),status:200,inyectada:false,respuesta_perdida:true});await route.abort('failed');};
    await page.route(target,lost);await click('Guardar oferta');await waitText('No pudimos conectarnos.');assert.equal(forwarded,true);assert.ok(snap().own_saved.includes(1));await top();await capture('respuesta-put-perdida');await page.unroute(target,lost);
    const pending=response('GET',search);await click('Reintentar');assert.equal((await pending).status(),200);await waitText('1 ofertas encontradas');await waitText('Quitar de Guardados');assert.equal(snap().own_saved.length,2);await capture('reconciliacion-sin-duplicados');
  });
  await run('HU017-V10',async()=>{
    await query('Favorito QA',11);
    for(let i=0;i<10;i++){
      const pending=page.waitForResponse(r=>r.request().method()==='PUT'&&new URL(r.url()).pathname.startsWith('/api/offers/')&&new URL(r.url()).pathname.endsWith('/saved/'));
      const button=page.getByRole('button',{name:'Guardar oferta',exact:true}).first();await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();assert.equal((await pending).status(),200);await page.waitForTimeout(200);
    }
    const pending=response('GET',search);await click('Siguiente');assert.equal((await pending).status(),200);await waitText('Página 2 de 2');
    const single=page.waitForResponse(r=>r.request().method()==='PUT'&&new URL(r.url()).pathname.endsWith('/saved/'));await click('Guardar oferta');assert.equal((await single).status(),200);await waitText('Oferta guardada.');assert.equal(snap().own_saved.length,13);await openSaved(13);await top();await capture('trece-guardados-paginados');
  });
  await run('HU017-V11',async()=>{
    await page.setViewportSize({width:390,height:844});const pending=response('GET',saved);await click('Siguiente');const r=await pending;assert.equal(r.status(),200);assert.equal(new URL(r.url()).searchParams.get('page'),'2');await waitText('Página 2 de 2');await top();await capture('guardados-movil');await bottom();await capture('pagina-dos-movil');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);await page.setViewportSize({width:1440,height:1000});
  });
  await run('HU017-V12',async()=>{
    await toDashboard();await logout();await login('company','/company-dashboard',true);await click('Mis ofertas activas');await waitText('Mis ofertas activas');
    let pending=response('POST','company/offers/1/transition/');let button=page.getByRole('button',{name:'Cerrar oferta',exact:true}).nth(1);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();await click('Confirmar cierre');assert.equal((await pending).status(),200);await waitText('Oferta cerrada correctamente.');
    pending=response('POST','company/offers/2/transition/');button=page.getByRole('button',{name:'Archivar oferta',exact:true}).first();await button.scrollIntoViewIfNeeded();await page.waitForTimeout(180);await button.click();await click('Confirmar archivado');assert.equal((await pending).status(),200);await waitText('Oferta archivada correctamente.');
    await toDashboard(true);await logout();await login('candidate','/dashboard',true);await openSaved(13);pending=response('GET',saved);await click('Siguiente');assert.equal((await pending).status(),200);await waitText('Estado: Cerrada');await waitText('Estado: Archivada');unchanged();await top();await capture('inactivas-conservadas-con-estado');await bottom();await capture('inactivas-cerrada-archivada');
    await toSearch();await query('Oferta Flutter QA',0);await top();await capture('cerrada-excluida-buscador');await query('Oferta Django QA',0);await capture('archivada-excluida-buscador');await openSaved(13);pending=response('GET',saved);await click('Siguiente');assert.equal((await pending).status(),200);await waitText('Página 2 de 2');
  });
  await run('HU017-V13',async()=>{
    await page.setViewportSize({width:390,height:844});await bottom();await capture('inactivas-antes-retiro-movil');await remove(1,12,1);await remove(2,11,1);const s=unchanged();assert.ok(!s.own_saved.includes(1)&&!s.own_saved.includes(2));assert.deepEqual(s.other_saved,[1,3]);await top();await capture('retirar-inactivas-movil');await page.setViewportSize({width:1440,height:1000});
  });
  await run('HU017-V14',async()=>{
    const before=snap().own_saved;bridge('revoke_candidate');const pending=response('DELETE',path(13));await click('Quitar de Guardados');assert.equal((await pending).status(),401);await page.waitForURL(cfg.web_origin+'/login');await waitText('Tu sesión ya no es válida.');assert.deepEqual(snap().own_saved,before);await capture('sesion-401-real');
  });
  await run('HU017-V15',async()=>{
    await login('company','/company-dashboard',true);const before=results.red.filter(r=>r.path==='/api/'+saved).length;await page.goto(cfg.web_origin+'/offers/saved');await semantics();await page.waitForURL(cfg.web_origin+'/company-dashboard');assert.equal(results.red.filter(r=>r.path==='/api/'+saved).length,before);await capture('rol-empresa-protegido');await logout();
  });
  await run('HU017-V16',async()=>{
    await page.goto(cfg.web_origin+'/offers/saved');await semantics();await page.waitForURL(cfg.web_origin+'/login');await capture('anonimo-protegido');const s=unchanged();assert.deepEqual(s.states,{'1':'closed','2':'archived'});assert.equal(s.own_saved.length,11);results.hu017=s;
  });
};
