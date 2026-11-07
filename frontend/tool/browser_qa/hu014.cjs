'use strict';
const assert = require('node:assert/strict');

module.exports = async ({ page, cfg, run, capture, bridge, ui, write, read, click, waitText, login, logout, semantics, fault, faults, results }) => {
  const snap = () => bridge('hu014_snapshot');
  const endpoint = (r, method, suffix) => r.request().method() === method && new URL(r.url()).origin === cfg.api_origin && new URL(r.url()).pathname === '/api/' + suffix;
  const path = 'company/offers/1/';
  const response = (method, suffix = path) => page.waitForResponse(r => endpoint(r, method, suffix));
  const values = { 'Título': 'Oferta Flutter QA', 'Descripción': 'Descripción inicial QA', 'Requisitos': 'Requisitos iniciales QA', 'Salario': '1000000.00', 'Ubicación': 'Pasto' };
  const patches = () => results.red.filter(r => r.method === 'PATCH').length;
  const fill = async (title, mobile = false) => {
    for (const [name, value] of Object.entries({ 'Título': title, 'Descripción': mobile ? 'Descripción móvil QA' : 'Descripción escritorio QA', 'Requisitos': mobile ? 'Requisitos móvil QA' : 'Requisitos escritorio QA', 'Salario': mobile ? '3200000,75' : '2500000,50', 'Ubicación': mobile ? 'Medellín QA' : 'Bogotá QA' })) await write(name, value);
    await click(/^Categoría/); await click(mobile ? 'Ventas' : 'Educación', 'menuitem');
    await click(/^Tipo de contrato/); await click(mobile ? 'Prestación de servicios' : 'Fijo', 'menuitem');
  };
  const check = async expected => { for (const [name, value] of Object.entries(expected)) assert.equal(await read(name), value); };
  const openList = async () => { const pending = response('GET', 'company/offers/active/'); await click('Mis ofertas activas'); assert.equal((await pending).status(), 200); await waitText('Mis ofertas activas'); };
  const openOne = async () => { const pending = response('GET'); await page.getByRole('button', { name: 'Editar oferta', exact: true }).nth(1).click(); assert.equal((await pending).status(), 200); await waitText('Guardar cambios'); assert.equal(new URL(page.url()).pathname, '/company/offers/1/edit'); };
  const save = async () => { const pending = response('PATCH'); await click('Guardar cambios'); assert.equal((await pending).status(), 200); await waitText('Cambios guardados correctamente.'); };
  const returnEditor = async () => { await click('Volver a mis ofertas'); await waitText('2 ofertas activas'); await openOne(); };
  const reload = async () => { const pending = response('GET'); await page.reload(); await semantics(); assert.equal((await pending).status(), 200); await waitText('Guardar cambios'); };
  const screenshotTop = async suffix => { await page.mouse.move(300, 300); await page.mouse.wheel(0, -12000); await page.waitForTimeout(350); await capture(suffix); };

  await login('company', '/company-dashboard', true);
  await run('HU014-V01', async () => {
    await openList(); const text = await ui(); assert.ok(text.includes('2 ofertas activas'));
    for (const title of ['Oferta ajena QA', 'Oferta archivada QA', 'Oferta cerrada QA', 'Borrador QA', 'Oferta vencida QA']) assert.ok(!text.includes(title));
    await capture('ofertas-propias'); await openOne();
  });
  await run('HU014-V02', async () => {
    await check(values); assert.ok((await ui()).includes('Tecnología')); assert.ok((await ui()).includes('Indefinido'));
    await screenshotTop('precarga');
  });
  await run('HU014-V03', async () => {
    const before = snap().offers; const count = patches();
    await write('Título', ''); await write('Salario', '-1'); await click('Guardar cambios'); await waitText('Completa este campo.'); await waitText('Escribe un salario no negativo');
    assert.equal(patches(), count); assert.deepEqual(snap().offers, before); await screenshotTop('invalidos');
  });
  await run('HU014-V04', async () => {
    await fill('Edición escritorio HU014'); await save(); await capture('confirmacion'); await returnEditor(); await reload();
    await check({ 'Título': 'Edición escritorio HU014', 'Descripción': 'Descripción escritorio QA', 'Requisitos': 'Requisitos escritorio QA', 'Salario': '2500000.50', 'Ubicación': 'Bogotá QA' });
    const row = snap().offers[0]; assert.equal(row.category, 'Educación'); assert.equal(row.contract_type, 'Fijo');
    await screenshotTop('persistencia');
  });
  await run('HU014-V05', async () => {
    await page.setViewportSize({ width: 390, height: 844 }); await fill('Edición móvil HU014', true); await save(); await capture('confirmacion-movil'); await returnEditor(); await reload();
    await check({ 'Título': 'Edición móvil HU014', 'Descripción': 'Descripción móvil QA', 'Requisitos': 'Requisitos móvil QA', 'Salario': '3200000.75', 'Ubicación': 'Medellín QA' });
    const row = snap().offers[0]; assert.equal(row.category, 'Ventas'); assert.equal(row.contract_type, 'Prestación de servicios'); await screenshotTop('persistencia-movil');
  });
  await run('HU014-V06', async () => {
    fault('GET', 'company/offers/active/', 'abort'); await click('Volver a mis ofertas'); await waitText('No pudimos conectarnos.'); await capture('error-lista'); faults.clear();
    const pending = response('GET', 'company/offers/active/'); await click('Reintentar'); assert.equal((await pending).status(), 200); await waitText('2 ofertas activas');
  });
  await run('HU014-V07', async () => {
    fault('GET', path, 'abort'); await page.getByRole('button', { name: 'Editar oferta', exact: true }).nth(1).click(); await waitText('No pudimos conectarnos.'); assert.equal(await page.getByRole('textbox').count(), 0); await capture('error-precarga'); faults.clear();
    const pending = response('GET'); await click('Reintentar'); assert.equal((await pending).status(), 200); await check({ 'Título': 'Edición móvil HU014' });
  });
  await run('HU014-V08', async () => {
    const before = snap().offers; await write('Título', 'Borrador red HU014'); fault('PATCH', path, 'abort'); await click('Guardar cambios'); await waitText('No pudimos conectarnos.');
    await check({ 'Título': 'Borrador red HU014' }); assert.deepEqual(snap().offers, before); await screenshotTop('red-borrador'); faults.clear(); await save(); await returnEditor();
  });
  await run('HU014-V09', async () => {
    const before = snap().offers; await write('Título', 'Borrador servidor HU014'); fault('PATCH', path, 'http', 503, { detail: 'Servicio QA no disponible.' }); await click('Guardar cambios'); await waitText('El servicio no está disponible.');
    await check({ 'Título': 'Borrador servidor HU014' }); assert.deepEqual(snap().offers, before); await screenshotTop('503-borrador'); faults.clear(); await save(); await returnEditor();
  });
  await run('HU014-V10', async () => {
    const before = snap().offers; await write('Título', 'Edición final HU014'); fault('PATCH', path, 'http', 400, { salary: ['Salario QA rechazado.'] }); await click('Guardar cambios'); await waitText('Salario QA rechazado.');
    await check({ 'Título': 'Edición final HU014' }); assert.deepEqual(snap().offers, before); await screenshotTop('400-borrador'); faults.clear(); await save();
  });
  await run('HU014-V11', async () => {
    const pending = response('GET', 'company/offers/3/'); await page.goto(cfg.web_origin + '/company/offers/3/edit'); await semantics(); assert.equal((await pending).status(), 404); await waitText('No encontramos esa oferta'); assert.equal(await page.getByRole('textbox').count(), 0); await capture('ajena-404');
  });
  await run('HU014-V12', async () => {
    for (const id of [4, 5, 6, 7]) {
      const pending = response('GET', `company/offers/${id}/`); await page.goto(cfg.web_origin + `/company/offers/${id}/edit`); await semantics(); assert.equal((await pending).status(), 409); await waitText('La oferta ya no está activa'); assert.equal(await page.getByRole('textbox').count(), 0); await capture('no-editable-' + id);
    }
  });
  await run('HU014-V13', async () => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(cfg.web_origin + '/company-dashboard'); await semantics(); await logout(); await login('candidate', '/dashboard', true);
    await page.goto(cfg.web_origin + '/company/offers/1/edit'); await semantics(); await page.waitForURL(cfg.web_origin + '/dashboard'); assert.ok(!(await ui()).includes('Guardar cambios')); await capture('candidato'); await logout();
  });
  await run('HU014-V14', async () => {
    await login('draft', '/company', true); const pending = response('GET', 'company/offers/'); await page.goto(cfg.web_origin + '/company/offers/1/edit'); await semantics(); assert.equal((await pending).status(), 403); await waitText('espera la aprobación de tu empresa'); assert.equal(await page.getByRole('textbox').count(), 0); await capture('pendiente-403');
    await click('Volver a mis ofertas'); await click('Volver al dashboard'); await page.waitForURL(cfg.web_origin + '/company-dashboard');
    // La empresa pendiente no debe permanecer en el resumen; salir desde su información.
    await page.goto(cfg.web_origin + '/company'); await semantics(); await logout();
  });
  await run('HU014-V15', async () => {
    await login('company', '/company-dashboard', true); await openList(); await openOne(); await page.setViewportSize({ width: 390, height: 844 }); await write('Título', 'No guardar sesión vencida'); const before = snap().offers;
    bridge('revoke_company'); const pending = response('PATCH'); await click('Guardar cambios'); assert.equal((await pending).status(), 401); await page.waitForURL(cfg.web_origin + '/login'); await waitText('Tu sesión ya no es válida.'); assert.deepEqual(snap().offers, before); await capture('sesion-401');
    await page.goBack(); await page.waitForURL(cfg.web_origin + '/login'); assert.equal(await page.getByRole('textbox', { name: 'Título', exact: true }).count(), 0);
    const state = snap(); for (const key of ['identity_unchanged','relations_unchanged','other_offers_unchanged','company_approval_unchanged','reviews_unchanged']) assert.equal(state[key], true);
    results.hu014 = { identity_unchanged:true,relations_unchanged:true,other_offers_unchanged:true,company_approval_unchanged:true,reviews_unchanged:true,offers:state.offers.length };
  });
};
