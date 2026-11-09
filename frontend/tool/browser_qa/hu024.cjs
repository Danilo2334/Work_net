'use strict';
const assert=require('node:assert/strict');
module.exports=async({page,cfg,run,capture,bridge,ui,click:baseClick,waitText:baseWait,login,logout,semantics,fault,faults,results})=>{
  const seed=bridge('hu024_seed');results.preparacion_qa=seed;
  const response=(method,path)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+path);
  const top=async()=>{await page.mouse.move(180,200);await page.mouse.wheel(0,-25000);await page.waitForTimeout(250);};
  const reveal=async(locator)=>{
    if(await locator().count())return;
    await top();
    for(let i=0;i<35&&await locator().count()===0;i++){
      await page.mouse.move(180,350);await page.mouse.wheel(0,Math.floor(page.viewportSize().height*.65));await page.waitForTimeout(150);await semantics();
    }
    assert.ok(await locator().count());
  };
  const click=async(name)=>{await reveal(()=>page.getByRole('button',{name,exact:true}));await baseClick(name);};
  const text=async(value)=>{if(!(await ui()).includes(value))await reveal(()=>page.getByText(value,{exact:false}));await baseWait(value);};
  const actor=name=>{const r=bridge('hu024_'+name);(results.actores_qa??=[]).push(r);return r;};
  const sql=()=>bridge('hu024_sql');
  const verify=(body,role)=>{
    const expected=sql()[role];assert.equal(body.applications_count,expected.applications_count);assert.deepEqual(body.states,expected.states);
    if(['company','stats_empty'].includes(role)){
      assert.equal(body.active_offers_count,expected.active_offers_count);assert.equal(body.offers.count,expected.offer_count);
      for(const o of body.offers.rows)assert.deepEqual(o,expected.offers.find(x=>x.id===o.id));
    }
    (results.contrastes_sql??=[]).push({role,applications:body.applications_count,states:body.states,page:body.offers?.page??null,sql_equal:true});
    return body;
  };
  let current=null,home=null;
  const as=async(role,target)=>{
    await page.setViewportSize({width:1440,height:1000});
    if(current){await page.goto(cfg.web_origin+home);await semantics();await top();await logout();}
    await login(role,target,true);current=role;home=target;await top();
  };
  const open=async(role)=>{const path=role==='candidate'||role==='other'?'statistics/candidate/':'statistics/company/';const p=response('GET',path);await click('Estadísticas');const r=await p;assert.equal(r.status(),200);await page.waitForURL(cfg.web_origin+'/statistics');await text('Resumen de actividad');return verify(await r.json(),role);};
  const refresh=async(role)=>{await top();const path=role==='candidate'||role==='other'?'statistics/candidate/':'statistics/company/';const p=response('GET',path);await click('Actualizar estadísticas');const r=await p;assert.equal(r.status(),200);return verify(await r.json(),role);};
  await run('HU024-V01',async()=>{
    await as('candidate','/dashboard');await reveal(()=>page.getByRole('button',{name:'Estadísticas',exact:true}));await capture('acceso-candidato');const b=await open('candidate');assert.equal(b.applications_count,13);await top();await capture('conteos-y-estados-candidato');
  });
  await run('HU024-V02',async()=>{
    const p=response('GET','applications/');await click('Consultar mi historial');assert.equal((await p).status(),200);assert.equal(actor('status').replayed,false);
    const h=response('GET','applications/');await click('Actualizar historial');assert.equal((await h).status(),200);await text('En revisión');await top();await capture('historial-cambio-real');
    const back=response('GET','statistics/candidate/');await click('Volver a estadísticas');assert.equal((await back).status(),200);const b=await refresh('candidate');assert.equal(b.states.in_review,seed.initial_statistics_sql.candidate.states.in_review+1);await capture('retorno-candidato-actualizado');
  });
  await run('HU024-V03',async()=>{
    await as('other','/dashboard');const b=await open('other');assert.equal(b.applications_count,0);await text('Todavía no hay postulaciones para mostrar.');await capture('candidato-vacio-real');
  });
  await run('HU024-V04',async()=>{
    await as('company','/company-dashboard');await top();await capture('dashboard-empresa-accesos-y-metricas');const b=await open('company');assert.equal(b.offers.rows.length,10);await top();await capture('totales-empresa-primera-pagina');
  });
  await run('HU024-V05',async()=>{
    const before=await refresh('company');const p=response('GET','statistics/company/');await click('Página siguiente');const r=await p;assert.equal(r.status(),200);const b=verify(await r.json(),'company');assert.equal(b.offers.page,2);assert.ok(b.offers.rows.every(o=>!before.offers.rows.some(x=>x.id===o.id)));await top();await capture('segunda-pagina-mismo-total');
    await reveal(()=>page.getByText('Oferta CV subido QA',{exact:true}));await text('Postulaciones recibidas: 14');await capture('oferta-cerrada-conserva-catorce');
  });
  await run('HU024-V06',async()=>{
    const p=response('GET','company/offers/3/applications/');await click('Consultar postulantes de Oferta CV subido QA');const r=await p;assert.equal(r.status(),200);assert.equal((await r.json()).count,14);
    const next=response('GET','company/offers/3/applications/');await click('Siguiente');assert.equal((await next).status(),200);await text('Página 2 de 2');await top();await capture('postulantes-paginados-retorno-contextual');
    assert.ok(actor('application').application_id);const back=response('GET','statistics/company/');await click('Volver a estadísticas');const rr=await back;assert.equal(rr.status(),200);const b=verify(await rr.json(),'company');assert.equal(b.applications_count,seed.initial_statistics_sql.company.applications_count+1);assert.equal(b.offers.page,2);await top();await capture('retorno-empresa-tras-alta-real');
  });
  await run('HU024-V07',async()=>{
    actor('close');const b=await refresh('company');assert.equal(b.active_offers_count,seed.initial_statistics_sql.company.active_offers_count-1);await top();await capture('cierre-reduce-activas-conserva-postulaciones');
    const p=response('GET','dashboard/company/');await click('Volver al dashboard');const r=await p;assert.equal(r.status(),200);const d=await r.json();assert.equal(d.metrics.applications,b.applications_count);assert.equal(d.metrics.active_offers,b.active_offers_count);await text('Ofertas activas: '+b.active_offers_count);await capture('dashboard-actualizado-al-volver');
  });
  await run('HU024-V08',async()=>{
    await as('other','/dashboard');await page.setViewportSize({width:390,height:844});const b=await open('other');assert.equal(b.applications_count,1);await top();await capture('nueva-postulacion-candidato-movil');await text('Rechazadas: 0');await capture('estados-candidato-movil');
  });
  await run('HU024-V09',async()=>{
    await as('company','/company-dashboard');await page.setViewportSize({width:390,height:844});await open('company');await top();await capture('empresa-movil-totales');const p=response('GET','statistics/company/');await click('Página siguiente');const r=await p;assert.equal(r.status(),200);verify(await r.json(),'company');await top();await capture('empresa-movil-segunda-pagina');
  });
  await run('HU024-V10',async()=>{
    await as('stats_empty','/company-dashboard');const b=await open('stats_empty');assert.equal(b.offers.total_pages,0);await text('Todavía no has creado ofertas.');await top();await capture('empresa-vacia-conteos-cero');
  });
  await run('HU024-V11',async()=>{
    await page.setViewportSize({width:390,height:844});await refresh('stats_empty');await top();await capture('vacio-movil-sin-dividir-por-cero');await text('Sin ofertas · 0 resultados');await capture('paginacion-vacia-honesta');
  });
  await run('HU024-V12',async()=>{
    await top();fault('GET','statistics/company/','http',503,{message:'Fallo QA identificado'});await click('Actualizar estadísticas');await text('El servicio no está disponible. Inténtalo de nuevo más tarde.');await capture('error-inyectado-identificado');faults.delete('GET /api/statistics/company/');const p=response('GET','statistics/company/');await click('Reintentar');const r=await p;assert.equal(r.status(),200);verify(await r.json(),'stats_empty');await capture('reintento-real-http200');
  });
  await run('HU024-V13',async()=>{
    assert.equal(actor('revoke_empty').revoked,true);await top();const p=response('GET','statistics/company/');await click('Actualizar estadísticas');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');await text('Tu sesión ya no es válida.');await capture('sesion-revocada-sin-datos');current=null;
  });
  await run('HU024-V14',async()=>{
    await as('rejection','/company');await page.goto(cfg.web_origin+'/statistics');await semantics();await page.waitForURL(cfg.web_origin+'/company');await text('Estado: Pendiente');assert.equal(await page.getByRole('button',{name:'Estadísticas',exact:true}).count(),0);await capture('empresa-pendiente-sin-acceso');
  });
  await run('HU024-V15',async()=>{
    await as('company','/company-dashboard');
    for(const [label,path] of [['Publicar oferta','company/offers/'],['Mis ofertas activas','company/offers/active/'],['Gestionar postulantes','company/applicant-offers/'],['Mensajes','conversations/']]){
      const p=response('GET',path);await click(label);assert.equal((await p).status(),200);await page.goto(cfg.web_origin+'/company-dashboard');await semantics();await text('Dashboard de empresa');
    }
    await top();await capture('hu006-accesos-funcionales');await open('company');await top();await capture('hu006-estadisticas-integradas');
    const final=bridge('hu024_snapshot');assert.equal(final.new_applications,1);assert.equal(final.new_notices,2);assert.equal(final.new_status_events,1);assert.equal(final.closed_offer_ids.length,1);assert.equal(final.duplicates,0);results.persistencia=final;
    results.alcance_actores='Actores API ficticios generan una transición, una postulación y un cierre reales. La UI acredita conteos, páginas, enlaces, retorno/actualización, vacío/error/reintento/sesión y móvil. SQL independiente contrasta cada respuesta; no es una instantánea congelada entre páginas.';
  });
};
