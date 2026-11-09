'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
module.exports=async({page,cfg,run,capture,bridge,ui,write,click:baseClick,waitText:baseWait,login,logout,semantics,fault,faults,results})=>{
  const seed=bridge('hu025_seed');results.preparacion_qa=seed;
  const artifacts=path.join(path.dirname(process.env.WORKNET_QA_MANIFEST),'artifacts');
  const response=(method,p)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+p);
  const top=async()=>{await page.mouse.move(150,200);await page.mouse.wheel(0,-25000);await page.waitForTimeout(250);};
  const reveal=async(locator)=>{if(await locator().count())return;await top();for(let i=0;i<35&&await locator().count()===0;i++){await page.mouse.move(150,350);await page.mouse.wheel(0,Math.floor(page.viewportSize().height*.65));await page.waitForTimeout(150);await semantics();}assert.ok(await locator().count());};
  const click=async(name,role='button')=>{await reveal(()=>page.getByRole(role,{name,exact:typeof name==='string'}));await baseClick(name,role);};
  const text=async(value)=>{if(!(await ui()).includes(value)){await top();for(let i=0;i<35&&!(await ui()).includes(value);i++){await page.mouse.move(150,350);await page.mouse.wheel(0,Math.floor(page.viewportSize().height*.65));await page.waitForTimeout(150);await semantics();}}await baseWait(value);};
  const list=async(query='',offer=3,code=200)=>{const p=response('GET',`company/offers/${offer}/applications/`);await page.goto(cfg.web_origin+`/company/offers/${offer}/applicants`+(query?'?'+query:''));await semantics();const r=await p;assert.equal(r.status(),code);if(code===200){const b=await r.json();await text(b.count+' postulantes encontrados');return b;}};
  const filter=async(experience='',education='',skill='')=>{await top();for(const [key,value]of [['Experiencia',experience],['Educación',education],['Habilidad',skill]])await write(key,value);const p=response('GET','company/offers/3/applications/');await click('Aplicar filtros');const r=await p;assert.equal(r.status(),200);const b=await r.json();await text(b.count+' postulantes encontrados');return b;};
  const download=async(type,name,query='',count=14)=>{
    const p=response('GET','company/offers/3/applications/export/');const pending=page.waitForEvent('download');
    await click('Exportar '+type.toUpperCase());const r=await p;assert.equal(r.status(),200);
    const d=await pending;assert.equal(d.suggestedFilename(),'postulantes-oferta-3.'+type);const filename='HU025-'+name+'.'+type;await d.saveAs(path.join(artifacts,filename));
    const verified=bridge('hu025_download',filename,'3',query);assert.equal(verified.row_count,count);assert.equal(verified.sql_equal,true);(results.descargas??=[]).push(verified);
    await text(`Descarga solicitada: ${count} coincidencias en ${type.toUpperCase()}.`);return verified;
  };
  await run('HU025-V01',async()=>{
    await login('company','/company-dashboard',true);const p=response('GET','company/applicant-offers/');await click('Gestionar postulantes');assert.equal((await p).status(),200);await capture('seleccion-oferta-propia');
    const b=await list();assert.equal(b.count,14);await reveal(()=>page.getByRole('button',{name:'Exportar CSV',exact:true}));await capture('controles-alcance-todas-las-paginas');
  });
  await run('HU025-V02',async()=>{const x=await download('csv','todas');assert.equal(x.formula_cells_neutralized,4);await capture('csv-descargado-14-coincidencias');});
  await run('HU025-V03',async()=>{const x=await download('pdf','todas');assert.ok(x.pages>1);await capture('pdf-descargado-multipagina');});
  await run('HU025-V04',async()=>{
    const p=response('GET','company/offers/3/applications/');await click('Siguiente');const b=await(await p).json();assert.equal(b.page,2);assert.equal(b.applications.length,4);
    const x=await download('csv','desde-pagina2');assert.equal(x.row_count,14);assert.equal(new URL(page.url()).searchParams.get('page'),'2');await capture('pagina2-exporta-todas-sin-cambiar-consulta');
  });
  await run('HU025-V05',async()=>{
    for(const [exp,edu,skill,query,count]of [['Backend','','','experience=Backend',9],['','Ingenieria','','education=Ingenieria',6],['','','Python','skill=Python',6]]){
      const b=await filter(exp,edu,skill);assert.equal(b.count,count);assert.equal(b.page,1);await download('csv','filtro-'+query.split('=')[0],query,count);await capture('filtro-'+query.split('=')[0]);
    }
  });
  await run('HU025-V06',async()=>{
    await filter('Backend','Ingenieria','Python');await top();
    const order=page.getByRole('button',{name:/Orden/});await order.click();await click('Nombre A–Z','menuitem');
    const p=response('GET','company/offers/3/applications/');await click('Aplicar filtros');const b=await(await p).json();assert.equal(b.count,4);
    const q='experience=Backend&education=Ingenieria&skill=Python&order=name';const a=await download('csv','combinado-ordenado',q,4),c=await download('pdf','combinado-ordenado',q,4);assert.deepEqual(a.application_ids,c.application_ids);await capture('filtros-combinados-orden-preservado');
  });
  await run('HU025-V07',async()=>{
    const b=await filter('','','Ausente');assert.equal(b.count,0);await reveal(()=>page.getByRole('button',{name:'Exportar CSV',exact:true}));
    for(const name of ['Exportar CSV','Exportar PDF'])assert.equal(await page.getByRole('button',{name,exact:true}).isDisabled(),true);
    await capture('vacio-controles-deshabilitados');
  });
  await run('HU025-V08',async()=>{const b=await list('',17);assert.equal(b.count,0);await reveal(()=>page.getByRole('button',{name:'Exportar PDF',exact:true}));assert.equal(await page.getByRole('button',{name:'Exportar PDF',exact:true}).isDisabled(),true);await capture('oferta-sin-postulaciones');});
  await run('HU025-V09',async()=>{
    await page.setViewportSize({width:390,height:844});await list('skill=Python&order=name_desc');
    await download('csv','movil-python','skill=Python&order=name_desc',6);await capture('movil-csv-real');await download('pdf','movil-python','skill=Python&order=name_desc',6);await capture('movil-pdf-real');
  });
  await run('HU025-V10',async()=>{
    await page.setViewportSize({width:1440,height:1000});await list();fault('GET','company/offers/3/applications/export/','http',503,{detail:'Fallo QA identificado'});
    await click('Exportar CSV');await text('El servicio no está disponible. Inténtalo de nuevo más tarde.');await capture('error-exportacion-inyectado-identificado');
    faults.delete('GET /api/company/offers/3/applications/export/');await download('csv','reintento-real');await capture('reintento-http200-datos-conservados');
  });
  await run('HU025-V11',async()=>{await list('',seed.foreign_offer,404);await text('No encontramos esa oferta entre las de tu empresa.');assert.equal(await page.getByRole('button',{name:'Exportar CSV',exact:true}).count(),0);await capture('oferta-ajena-sin-datos-ni-exportacion');});
  await run('HU025-V12',async()=>{
    await list();assert.equal(bridge('hu025_revoke').revoked,true);const p=response('GET','company/offers/3/applications/export/');await click('Exportar PDF');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');await text('Tu sesión ya no es válida.');await capture('sesion-revocada-sin-archivo');
    results.persistencia=bridge('hu025_snapshot');assert.equal(results.persistencia.new_business_records,0);assert.equal(results.persistencia.duplicates,0);
    results.alcance='12 casos HU025 más inicio. Descargas reales en escritorio y móvil web emulado, contraste SQL independiente fila/campo/orden de CSV y contenido/páginas de PDF. Actor API solo revoca sesión. Sin mutaciones de negocio; no prueba de Android físico.';
  });
};
