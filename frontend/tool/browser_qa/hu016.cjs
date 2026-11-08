'use strict';
const assert = require('node:assert/strict');

module.exports = async ({page,cfg,run,capture,bridge,ui,write,click,waitText,login,logout,semantics,fault,faults,results}) => {
  const path='offers/search/';
  const matches=r=>r.request().method()==='GET'&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+path;
  const response=()=>page.waitForResponse(matches);
  const top=async()=>{await page.mouse.move(200,250);await page.mouse.wheel(0,-18000);await page.waitForTimeout(350);};
  const bottom=async()=>{await page.mouse.move(200,400);await page.mouse.wheel(0,18000);await page.waitForTimeout(350);};
  const search=async(count,button='Buscar')=>{const pending=response();await click(button);const r=await pending;assert.equal(r.status(),200);await waitText(`${count} ofertas encontradas`);return r;};
  const clear=async()=>search(1017,'Limpiar filtros');
  const choose=async(label,value)=>{await click(new RegExp('^'+label));await click(value,'menuitem');};
  const inspect=async(r,expected)=>{const p=new URL(r.url()).searchParams;for(const [k,v] of Object.entries(expected))assert.equal(p.get(k),v,k);};
  const unchanged=()=>{const s=bridge('hu016_snapshot');for(const k of ['information_unchanged','other_offers_unchanged','applications_unchanged','saved_unchanged'])assert.equal(s[k],true,k);return s;};
  await login('candidate','/dashboard',true);
  await run('HU016-V01',async()=>{
    await waitText('Buscar ofertas');await capture('dashboard-acceso');
    let release;const gate=new Promise(resolve=>{release=resolve;});
    const target=cfg.api_origin+'/api/offers/search/**';
    const delay=async route=>{await gate;await route.continue();};await page.route(target,delay);
    const pending=response();await click('Buscar ofertas');await waitText('Buscando ofertas…');await capture('carga-escritorio');release();
    assert.equal((await pending).status(),200);await page.unroute(target,delay);await waitText('1017 ofertas encontradas');await top();await capture('resultados-escritorio');
  });
  await run('HU016-V02',async()=>{
    await write('Palabras clave','Python Django');const r=await search(24);const b=await r.json();
    assert.equal(b.offers[0].title,'Python Django líder QA');assert.equal(b.offers[0].relevance,16);await top();await capture('relevancia');
  });
  await run('HU016-V03',async()=>{
    await write('Ubicación','Pasto');await write('Salario mínimo','1000000');await write('Salario máximo','23000000');
    await choose('Categoría','Tecnología');await choose('Tipo de contrato','Indefinido');await choose('Ordenar por','Fecha de publicación');
    const first=await search(12);const ids=(await first.json()).offers.map(o=>o.id);
    const second=await search(12,'Siguiente');await inspect(second,{q:'Python Django',location:'Pasto',salary_min:'1000000',salary_max:'23000000',category:'Tecnología',contract_type:'Indefinido',sort:'date',page:'2'});
    const b=await second.json();assert.equal(b.offers.length,2);for(const o of b.offers)assert.ok(!ids.includes(o.id));await waitText('Página 2 de 2');await bottom();await capture('pagina-2-filtros-conservados');
    await search(12,'Anterior');await waitText('Página 1 de 2');
  });
  await run('HU016-V04',async()=>{
    await search(12,'Siguiente');await write('Palabras clave','NoExisteOfertaHU016');
    const r=await search(0);await inspect(r,{page:'1'});await waitText('No encontramos ofertas con estos filtros.');await top();await capture('vacio-real');await clear();
  });
  await run('HU016-V05',async()=>{
    await write('Palabras clave','Python Django');await write('Ubicación','Pasto');await write('Salario mínimo','3000000');await write('Salario máximo','5000000');
    await choose('Categoría','Tecnología');await choose('Tipo de contrato','Indefinido');
    const b=await (await search(2)).json();assert.deepEqual(b.offers.map(o=>o.salary),['5000000.00','3000000.00']);await top();await capture('combinacion-todos');await bottom();await capture('tarjetas-salarios');
  });
  await run('HU016-V06',async()=>{
    await write('Salario mínimo','5000001');const before=results.red.filter(r=>r.path==='/api/'+path).length;
    await click('Buscar');await waitText('El máximo debe ser mayor o igual al mínimo.');assert.equal(results.red.filter(r=>r.path==='/api/'+path).length,before);await top();await capture('validacion-rango');await clear();
  });
  await run('HU016-V07',async()=>{
    await write('Palabras clave','técnico C++ [A]');await write('Ubicación','Bogotá');const b=await (await search(1)).json();assert.equal(b.offers[0].title,'TÉCNICO QA C++ [A]');assert.equal(b.offers[0].salary,'0.00');await bottom();await capture('unicode-literal');await clear();
  });
  await run('HU016-V08',async()=>{
    await write('Palabras clave','Python');let b=await(await search(24)).json();assert.equal(b.offers[0].title,'Python Django líder QA');
    await choose('Ordenar por','Fecha de publicación');const r=await search(24);await inspect(r,{sort:'date',page:'1'});b=await r.json();assert.equal(b.offers[0].title,'Python Django reciente QA');await top();await capture('orden-fecha');
  });
  await run('HU016-V09',async()=>{
    fault('GET',path,'abort');await click('Buscar');await waitText('No pudimos conectarnos.');await top();await capture('red-inyectada');faults.clear();await search(24,'Reintentar');
    fault('GET',path,'http',503,{detail:'Indisponibilidad QA inyectada.'});await click('Buscar');await waitText('El servicio no está disponible.');await top();await capture('503-inyectado');faults.clear();await search(24,'Reintentar');await capture('reintento-real');
  });
  await run('HU016-V10',async()=>{
    await page.setViewportSize({width:390,height:844});await clear();await write('Palabras clave','Python');await write('Ubicación','Pasto');await search(12);await top();await capture('filtros-movil');
    await search(12,'Siguiente');await waitText('Página 2 de 2');await bottom();await capture('resultados-pagina-2-movil');
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);await page.setViewportSize({width:1440,height:1000});
  });
  await run('HU016-V11',async()=>{
    const pending=response();await page.reload();await semantics();assert.equal((await pending).status(),200);await waitText('1017 ofertas encontradas');await top();await capture('sesion-restaurada');
    await click('Volver al dashboard');await page.waitForURL(cfg.web_origin+'/dashboard');await waitText('Buscar ofertas');await logout();
  });
  await run('HU016-V12',async()=>{
    await login('company','/company-dashboard',true);const before=results.red.filter(r=>r.path==='/api/'+path).length;
    await page.goto(cfg.web_origin+'/offers/search');await semantics();await page.waitForURL(cfg.web_origin+'/company-dashboard');assert.equal(results.red.filter(r=>r.path==='/api/'+path).length,before);await capture('rol-empresa-protegido');
    await click('Mis ofertas activas');await waitText('Mis ofertas activas');
    let pending=page.waitForResponse(r=>r.request().method()==='POST'&&new URL(r.url()).pathname==='/api/company/offers/1/transition/');
    let button=page.getByRole('button',{name:'Cerrar oferta',exact:true}).nth(2);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(250);await button.click();await click('Confirmar cierre');assert.equal((await pending).status(),200);await waitText('Oferta cerrada correctamente.');
    pending=page.waitForResponse(r=>r.request().method()==='POST'&&new URL(r.url()).pathname==='/api/company/offers/2/transition/');
    button=page.getByRole('button',{name:'Archivar oferta',exact:true}).nth(1);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(250);await button.click();await click('Confirmar archivado');assert.equal((await pending).status(),200);await waitText('Oferta archivada correctamente.');
    assert.deepEqual(unchanged().states,{'1':'closed','2':'archived'});await click('Volver al dashboard');await logout();await login('candidate','/dashboard',true);await click('Buscar ofertas');await waitText('1015 ofertas encontradas');
    await write('Palabras clave','Oferta Flutter QA');await search(0);await top();await capture('cerrada-excluida-real');await write('Palabras clave','Oferta Django QA');await search(0);await top();await capture('archivada-excluida-real');
  });
  await run('HU016-V13',async()=>{
    bridge('revoke_candidate');const pending=response();await click('Buscar');assert.equal((await pending).status(),401);await page.waitForURL(cfg.web_origin+'/login');await waitText('Tu sesión ya no es válida.');await capture('sesion-401-real');
  });
  await run('HU016-V14',async()=>{
    await page.goto(cfg.web_origin+'/offers/search');await semantics();await page.waitForURL(cfg.web_origin+'/login');await capture('acceso-anonimo-protegido');results.hu016=unchanged();
  });
};
