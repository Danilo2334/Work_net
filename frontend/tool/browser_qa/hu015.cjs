'use strict';
const assert = require('node:assert/strict');

module.exports = async ({ page, cfg, run, capture, bridge, ui, write, read, click, waitText, login, logout, semantics, fault, faults, results }) => {
  const snap = () => bridge('hu015_snapshot');
  const endpoint = (r, method, path) => r.request().method() === method && new URL(r.url()).origin === cfg.api_origin && new URL(r.url()).pathname === '/api/' + path;
  const response = (method, path) => page.waitForResponse(r => endpoint(r, method, path));
  const posts = () => results.red.filter(r => r.method === 'POST' && r.path.endsWith('/transition/')).length;
  const path = id => `company/offers/${id}/transition/`;
  const act = async (name, index = 0) => {
    const button = page.getByRole('button', { name, exact: true }).nth(index);
    await button.scrollIntoViewIfNeeded(); await page.waitForTimeout(250); await button.click();
  };
  const confirm = async (id, archive) => {
    const pending = response('POST', path(id));
    await click(archive ? 'Confirmar archivado' : 'Confirmar cierre');
    assert.equal((await pending).status(), 200);
    await waitText(archive ? 'Oferta archivada correctamente.' : 'Oferta cerrada correctamente.');
  };
  const open = async () => { const pending = response('GET', 'company/offers/active/'); await click('Mis ofertas activas'); assert.equal((await pending).status(), 200); await waitText('ofertas activas'); };
  const preserved = async count => { const pending = response('GET', 'company/offers/preserved/'); await click('Ver ofertas conservadas'); assert.equal((await pending).status(), 200); await waitText(`${count} ofertas conservadas`); };
  const active = async count => { const pending = response('GET', 'company/offers/active/'); await click('Ver ofertas activas'); assert.equal((await pending).status(), 200); await waitText(`${count} ofertas activas`); };
  const reload = async (list, count) => { const pending = response('GET', `company/offers/${list}/`); await page.reload(); await semantics(); assert.equal((await pending).status(), 200); await waitText(`${count} ofertas ${list === 'active' ? 'activas' : 'conservadas'}`); };
  const top = async () => { await page.mouse.move(300, 300); await page.mouse.wheel(0, -12000); await page.waitForTimeout(350); };
  const unchanged = () => { const s = snap(); for (const key of ['information_unchanged','other_offers_unchanged','relations_unchanged','company_approval_unchanged','reviews_unchanged']) assert.equal(s[key], true, key); return s; };

  await login('company', '/company-dashboard', true);
  await run('HU015-V01', async () => {
    await open(); await waitText('3 ofertas activas'); let text = await ui();
    for (const title of ['Oferta ajena QA','Oferta archivada QA','Oferta cerrada QA','Borrador QA','Oferta vencida QA']) assert.ok(!text.includes(title));
    await top(); await capture('activas-escritorio'); await preserved(2); text = await ui();
    assert.ok(text.includes('Estado: Cerrada') && text.includes('Estado: Archivada'));
    assert.equal(await page.getByRole('button', { name: 'Editar oferta', exact: true }).count(), 0);
    await top(); await capture('conservadas-iniciales'); await active(3);
  });
  await run('HU015-V02', async () => {
    const before = snap().offers, count = posts(); await act('Archivar oferta', 2);
    await waitText('¿Archivar esta oferta?'); await waitText('postulaciones existentes se conservarán'); await capture('confirmacion-archivar');
    await click('Cancelar'); assert.equal(posts(), count); assert.deepEqual(snap().offers, before); await capture('cancelacion-sin-cambios');
  });
  await run('HU015-V03', async () => {
    await act('Cerrar oferta', 2); await waitText('¿Cerrar esta oferta?'); await capture('confirmacion-cerrar'); await confirm(1, false);
    await waitText('2 ofertas activas'); assert.equal(snap().offers[0].status, 'closed'); unchanged(); await top(); await capture('cerrada-excluida'); await reload('active', 2);
    const pending = response('GET', 'company/offers/1/'); await page.goto(cfg.web_origin + '/company/offers/1/edit'); await semantics(); assert.equal((await pending).status(), 409);
    await waitText('La oferta ya no está activa'); assert.equal(await page.getByRole('textbox').count(), 0); await capture('cerrada-no-editable');
    await click('Volver a mis ofertas'); await waitText('2 ofertas activas');
  });
  await run('HU015-V04', async () => {
    await preserved(3); const before = snap().offers, count = posts(); await act('Archivar oferta', 1); await click('Cancelar'); assert.equal(posts(), count); assert.deepEqual(snap().offers, before);
    await act('Archivar oferta', 1); await confirm(1, true); assert.equal(snap().offers[0].status, 'archived'); unchanged(); await reload('preserved', 3); await top(); await capture('archivada-persistida'); await active(2);
  });
  await run('HU015-V05', async () => {
    await page.setViewportSize({width:390,height:844}); const before = snap().offers, count = posts(); await act('Archivar oferta', 1); await capture('confirmacion-movil'); await click('Cancelar'); assert.equal(posts(), count); assert.deepEqual(snap().offers, before);
    await act('Archivar oferta', 1); await confirm(2, true); await waitText('1 ofertas activas'); unchanged(); await capture('archivada-movil'); await preserved(4); await reload('preserved', 4); await top(); await capture('conservadas-movil'); await active(1);
  });
  await run('HU015-V06', async () => {
    const before = snap().offers, count = posts(); await act('Cerrar oferta'); await capture('cerrar-movil'); await click('Cancelar'); assert.equal(posts(), count); assert.deepEqual(snap().offers, before);
  });
  await run('HU015-V07', async () => {
    const before = snap().offers; fault('POST', path(8), 'abort'); await act('Cerrar oferta'); await click('Confirmar cierre'); await waitText('No pudimos conectarnos.'); await capture('red-cierre'); assert.deepEqual(snap().offers, before); faults.clear();
    const pending = response('GET', 'company/offers/active/'); await click('Reintentar'); assert.equal((await pending).status(), 200); await waitText('1 ofertas activas');
  });
  await run('HU015-V08', async () => {
    const before = snap().offers; fault('POST', path(8), 'http', 503, {detail:'Servicio QA no disponible.'}); await act('Archivar oferta'); await click('Confirmar archivado'); await waitText('El servicio no está disponible.'); await capture('503-archivado'); assert.deepEqual(snap().offers, before); faults.clear();
  });
  await run('HU015-V09', async () => {
    const before = snap().offers; fault('POST', path(8), 'http', 400, {confirm:['Confirmación QA rechazada.']}); await act('Archivar oferta'); await click('Confirmar archivado'); await waitText('Confirmación QA rechazada.'); await capture('400-archivado'); assert.deepEqual(snap().offers, before); faults.clear();
  });
  await run('HU015-V10', async () => {
    fault('GET', 'company/offers/preserved/', 'abort'); await click('Ver ofertas conservadas'); await waitText('No pudimos conectarnos.'); await capture('red-conservadas'); faults.clear();
    const pending = response('GET', 'company/offers/preserved/'); await click('Reintentar'); assert.equal((await pending).status(), 200); await waitText('4 ofertas conservadas'); await active(1);
  });
  await run('HU015-V11', async () => {
    fault('GET', 'company/offers/preserved/', 'http', 503, {detail:'Servicio QA no disponible.'}); await click('Ver ofertas conservadas'); await waitText('El servicio no está disponible.'); await capture('503-conservadas'); faults.clear();
    const pending = response('GET', 'company/offers/preserved/'); await click('Reintentar'); assert.equal((await pending).status(), 200); await waitText('4 ofertas conservadas'); await click('Volver al dashboard'); await waitText('Ofertas activas: 1');
  });
  await run('HU015-V12', async () => {
    await click('Publicar oferta'); await waitText('Publicar oferta');
    for (const [name,value] of Object.entries({'Título':'Regresión publicación HU015','Descripción':'Descripción regresión QA','Requisitos':'Requisitos regresión QA','Salario':'2400000,50','Ubicación':'Bogotá QA'})) await write(name,value);
    await click(/^Categoría/); await click('Tecnología','menuitem'); await click(/^Tipo de contrato/); await click('Indefinido','menuitem');
    const pending = response('POST','company/offers/'); await click('Publicar oferta'); assert.equal((await pending).status(),201); await waitText('Oferta publicada correctamente. Número 9.'); await capture('regresion-publicacion');
    assert.equal(snap().offers[8].status,'published'); await click('Volver al dashboard'); await waitText('Ofertas activas: 2'); await open();
  });
  await run('HU015-V13', async () => {
    let pending = response('GET','company/offers/9/'); await act('Editar oferta'); assert.equal((await pending).status(),200); await waitText('Guardar cambios'); assert.equal(await read('Título'),'Regresión publicación HU015');
    await write('Título','Regresión edición HU015'); pending=response('PATCH','company/offers/9/'); await click('Guardar cambios'); assert.equal((await pending).status(),200); await waitText('Cambios guardados correctamente.'); await capture('regresion-edicion');
    await click('Volver a mis ofertas'); await waitText('2 ofertas activas'); pending=response('GET','company/offers/9/'); await act('Editar oferta'); assert.equal((await pending).status(),200); await waitText('Guardar cambios');
    pending=response('GET','company/offers/9/'); await page.reload(); await semantics(); assert.equal((await pending).status(),200); await waitText('Guardar cambios'); assert.equal(await read('Título'),'Regresión edición HU015'); assert.equal(snap().offers[8].title,'Regresión edición HU015'); await capture('regresion-persistencia');
    await click('Volver a mis ofertas'); await waitText('2 ofertas activas');
  });
  await run('HU015-V14', async () => {
    const target=cfg.api_origin+'/api/'+path(9); let forwarded=false;
    const lost=async route => { const result=await route.fetch(); assert.equal(result.status(),200); assert.equal(result.headers()['x-worknet-qa-run'],cfg.nonce); forwarded=true; results.red.push({method:'POST',path:'/api/'+path(9),status:200,inyectada:false,respuesta_perdida:true}); await route.abort('failed'); };
    await page.route(target,lost); await act('Cerrar oferta'); await click('Confirmar cierre'); await waitText('No pudimos conectarnos.'); assert.equal(forwarded,true); assert.equal(snap().offers[8].status,'closed'); await capture('respuesta-perdida'); await page.unroute(target,lost);
    await act('Cerrar oferta'); await confirm(9,false); await waitText('1 ofertas activas'); assert.equal(snap().offers.length,9); unchanged(); await capture('reintento-idempotente');
    await page.setViewportSize({width:1440,height:1000}); await click('Volver al dashboard'); await logout();
    results.hu015_respuesta_perdida={post_real_200:true,respuesta_abortada:true,reintento_200:true,sin_duplicados:true};
  });
  await run('HU015-V15', async () => {
    await login('candidate','/dashboard',true); let text=await ui(); assert.ok(!text.includes('Oferta Flutter QA') && !text.includes('Oferta Django QA') && !text.includes('Regresión edición HU015'));
    assert.ok(text.includes('Oferta errores QA')); assert.equal(snap().applications,2); await capture('candidato-activas');
    await page.goto(cfg.web_origin+'/company/offers'); await semantics(); await page.waitForURL(cfg.web_origin+'/dashboard'); assert.equal(await page.getByRole('button',{name:'Cerrar oferta',exact:true}).count(),0); await logout();
  });
  await run('HU015-V16', async () => {
    await login('draft','/company',true); let pending=response('GET','company/offers/active/'); await page.goto(cfg.web_origin+'/company/offers'); await semantics(); assert.equal((await pending).status(),403); await waitText('espera la aprobación de tu empresa');
    pending=response('GET','company/offers/preserved/'); await click('Ver ofertas conservadas'); assert.equal((await pending).status(),403); await waitText('espera la aprobación de tu empresa'); assert.equal(await page.getByRole('button',{name:'Archivar oferta',exact:true}).count(),0); await capture('empresa-pendiente-403');
    await page.goto(cfg.web_origin+'/company'); await semantics(); await logout();
  });
  await run('HU015-V17', async () => {
    await login('company','/company-dashboard',true); await open(); await page.setViewportSize({width:390,height:844}); const before=snap().offers;
    await act('Cerrar oferta'); bridge('revoke_company'); const pending=response('POST',path(8)); await click('Confirmar cierre'); assert.equal((await pending).status(),401); await page.waitForURL(cfg.web_origin+'/login'); await waitText('Tu sesión ya no es válida.'); assert.deepEqual(snap().offers,before); await capture('sesion-401');
    await page.goBack(); await page.waitForURL(cfg.web_origin+'/login'); const s=unchanged();
    results.hu015={information_unchanged:s.information_unchanged,relations_unchanged:s.relations_unchanged,other_offers_unchanged:s.other_offers_unchanged,company_approval_unchanged:s.company_approval_unchanged,reviews_unchanged:s.reviews_unchanged,applications:s.applications,saved:s.saved,ofertas:s.offers.length,dependencias_pendientes:['HU016: buscador completo no implementado','HU018: flujo de postulación no implementado']};
  });
};
