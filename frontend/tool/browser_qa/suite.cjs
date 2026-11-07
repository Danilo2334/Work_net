'use strict';
// Recupera los pasos interactivos del 07/11/2026 en 25 casos repetibles.
// Nunca conecta a un navegador existente ni guarda traces/HAR/storageState.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const { chromium } = require('playwright');
process.on('unhandledRejection', () => {
  console.log('QA_ASYNC_FAILED; excepción privada omitida.');
  process.exitCode = 1;
});

async function main() {
  const manifest = path.resolve(process.env.WORKNET_QA_MANIFEST || 'missing');
  const cfg = JSON.parse(fs.readFileSync(manifest, 'utf8'));
  const root = path.dirname(manifest);
  const python = path.join(root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
  assert.equal(path.resolve(process.env.WORKNET_QA_PYTHON || 'missing'), python);
  const bridge = (action, ...args) => {
    const r = spawnSync(python, [path.join(__dirname, 'bridge.py'), manifest, action, ...args], { encoding: 'utf8' });
    if (r.status !== 0) throw new Error('QA_GUARD_OR_CONTRAST_FAILED');
    return JSON.parse(r.stdout);
  };
  bridge('validate');
  // Antes de leer credenciales o abrir UI, probar ambos servicios propios.
  for (const url of [cfg.web_origin, cfg.api_origin + '/api/company/offers/']) {
    const response = await fetch(url);
    assert.equal(response.headers.get('x-worknet-qa-run'), cfg.nonce);
  }
  bridge('start');
  const values = Object.fromEntries(JSON.parse(fs.readFileSync(path.join(root, cfg.environment), 'utf8')).values.map(v => [v.key, v.value]));
  const out = path.join(root, 'artifacts');
  fs.mkdirSync(out, { recursive: true });
  const results = { schema: 'worknet-browser-qa-results-v1', fecha: new Date().toISOString(), frontend_sha: cfg.frontend_sha, backend_sha: cfg.backend_sha, playwright: require('playwright/package.json').version, modo: 'Chromium headless nuevo, contextos temporales; sin perfil personal', escritorio: '1440x1000/1100', movil: 'Viewport 390x844, ratón/teclado; no dispositivo físico', casos: [], capturas: [], red: [], controles: { solo_base_qa_nueva: true, smtp: false, traces_har_storageState: false }, revision_humana: false };
  let browser, context, page, active = 'NAVEGADOR-01', phase = 'inicio', authenticating = false, violations = 0;
  const faults = new Map();
  const marker = 'Aceptación visual HU012: resumen ficticio conservado.';
  const save = () => fs.writeFileSync(path.join(out, 'resultados.json'), JSON.stringify(results, null, 2) + '\n');
  const endpoint = (r, method, suffix) => r.request().method() === method && r.url() === cfg.api_origin + '/api/' + suffix;
  const ui = () => page.locator('body').ariaSnapshot();
  const waitText = async text => {
    phase = 'esperar texto de interfaz';
    for (let i = 0; i < 50; i++) {
      if ((await ui()).includes(text)) return;
      await page.waitForTimeout(100);
    }
    throw new Error('UI_TEXT_NOT_READY');
  };
  const click = async (name, role = 'button') => {
    phase = 'control ' + role + ': ' + String(name);
    const target = page.getByRole(role, { name, exact: typeof name === 'string' });
    await target.scrollIntoViewIfNeeded();
    await page.waitForTimeout(180); // Semántica y canvas deben terminar el scroll.
    await target.click();
  };
  const write = async (name, value) => {
    phase = 'escribir campo: ' + name;
    await page.getByRole('textbox', { name, exact: true }).focus();
    await page.waitForTimeout(300); // Flutter conecta el input y desplaza su canvas.
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.press('Backspace');
    if (value) await page.keyboard.insertText(value);
  };
  const read = async name => {
    phase = 'leer campo: ' + name;
    await page.getByRole('textbox', { name, exact: true }).focus();
    await page.waitForTimeout(300);
    return page.getByRole('textbox', { name, exact: true }).inputValue();
  };
  const top = async () => {
    await page.mouse.move(300, 300);
    await page.mouse.wheel(0, -12000);
    await page.waitForTimeout(350);
  };
  const capture = async suffix => {
    assert.equal(authenticating, false);
    assert.equal(new URL(page.url()).search, '');
    const password = page.getByRole('textbox', { name: 'Contraseña', exact: true });
    if (await password.count()) assert.equal(await password.inputValue(), '');
    await page.waitForTimeout(450);
    const name = active + (suffix ? '-' + suffix : '') + '.png';
    const buffer = await page.screenshot({ path: path.join(out, name) });
    results.capturas.push({ archivo: name, caso: active, viewport: page.viewportSize(), sha256: createHash('sha256').update(buffer).digest('hex') });
  };
  const run = async (id, test) => {
    active = id;
    const start = Date.now();
    try {
      await test();
      assert.equal(violations, 0);
      results.casos.push({ id, resultado: 'aprobado', duracion_ms: Date.now() - start });
      console.log(id + ' OK');
      save();
    } catch (error) {
      results.casos.push({ id, resultado: 'fallido', paso: phase, tipo: error.name, error: 'Aserción, guard o control no satisfecho; sin volcado de datos privados' });
      if (!authenticating) {
        try { await capture('fallo'); } catch (_) { /* Nunca capturar login relleno. */ }
      }
      save();
      throw new Error('CASE_FAILED');
    }
  };
  const semantics = async () => {
    await page.waitForTimeout(800);
    const enable = page.getByRole('button', { name: 'Enable accessibility', exact: true });
    if (await enable.count()) {
      await enable.focus();
      await page.keyboard.press('Enter');
      await page.waitForTimeout(250);
    }
  };
  const login = async (account, home, remember = false) => {
    authenticating = true;
    if (remember) await page.getByRole('checkbox', { name: 'Recordar sesión', exact: true }).check();
    await write('Correo electrónico', values[account + '_email']);
    await write('Contraseña', values.qa_password);
    const response = page.waitForResponse(r => endpoint(r, 'POST', 'login/'));
    await click('Iniciar sesión');
    assert.equal((await response).status(), 200);
    await page.waitForURL(cfg.web_origin + home);
    await page.waitForTimeout(400);
    authenticating = false;
  };
  const logout = async () => {
    await click('Cerrar sesión');
    await page.waitForURL(cfg.web_origin + '/login');
    await page.waitForTimeout(400);
  };
  const editor = async () => {
    await click('Mi currículum');
    await page.waitForURL(cfg.web_origin + '/curriculum');
    await waitText('Todavía no has subido un currículum');
    await page.waitForTimeout(400);
    await click('Crear mi CV');
    await waitText('Información personal');
  };
  const leaveEditor = async () => {
    await click('Volver a mi currículum');
    await page.waitForURL(cfg.web_origin + '/curriculum');
    await page.waitForTimeout(400);
  };
  const saveCV = async status => {
    const response = page.waitForResponse(r => endpoint(r, 'PUT', 'curriculum/generated/'));
    await click('Guardar CV');
    assert.equal((await response).status(), status);
    await waitText('Tu currículum se guardó correctamente.');
  };
  const preview = async filename => {
    const response = page.waitForResponse(r => endpoint(r, 'POST', 'curriculum/generated/preview/'));
    await click('Vista previa');
    const r = await response;
    assert.equal(r.status(), 200);
    if (filename) fs.writeFileSync(path.join(out, filename), await r.body());
    await page.getByRole('img', { name: /Vista previa de tu edición/ }).waitFor();
    await page.waitForTimeout(400);
  };
  const download = async filename => {
    const pending = page.waitForEvent('download');
    await click('Descargar PDF guardado');
    await (await pending).saveAs(path.join(out, filename));
  };
  const countPosts = () => results.red.filter(x => x.method === 'POST' && x.path === '/api/company/offers/').length;
  const fillOffer = async (title, salary = '900000') => {
    for (const [name, value] of [['Título', title], ['Descripción', 'Descripción ficticia para aceptación HU013.'], ['Requisitos', 'Requisitos ficticios QA.'], ['Salario', salary], ['Ubicación', 'Pasto QA']]) await write(name, value);
  };
  const choices = async contract => {
    await click('Categoría'); await click('Tecnología', 'menuitem');
    await click('Tipo de contrato'); await click(contract, 'menuitem');
  };
  const fault = (method, suffix, kind, status, body) => faults.set(method + ' /api/' + suffix, { kind, status, body });
  try {
    browser = await chromium.launch({ headless: true, channel: 'chromium' });
    results.chromium = browser.version();
    context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'es-CO', acceptDownloads: true, serviceWorkers: 'block' });
    await context.route('**/*', async route => {
      const url = new URL(route.request().url());
      if (!['data:', 'blob:'].includes(url.protocol) && ![cfg.api_origin, cfg.web_origin].includes(url.origin)) {
        violations++;
        return route.abort('blockedbyclient');
      }
      const injected = faults.get(route.request().method() + ' ' + url.pathname);
      if (url.origin === cfg.api_origin && injected) {
        if (injected.kind === 'abort') {
          results.red.push({ method: route.request().method(), path: url.pathname, status: null, inyectada: true, fallo: 'abort' });
          return route.abort('failed');
        }
        return route.fulfill({ status: injected.status, contentType: 'application/json', headers: { 'X-WorkNet-QA-Run': cfg.nonce, 'X-WorkNet-QA-Injected': 'true', 'Access-Control-Allow-Origin': cfg.web_origin }, body: JSON.stringify(injected.body) });
      }
      return route.continue();
    });
    page = await context.newPage();
    page.setDefaultTimeout(10000);
    page.on('response', r => {
      if (r.url().startsWith(cfg.api_origin + '/api/')) {
        if (r.headers()['x-worknet-qa-run'] !== cfg.nonce) violations++;
        results.red.push({ method: r.request().method(), path: new URL(r.url()).pathname, status: r.status(), inyectada: r.headers()['x-worknet-qa-injected'] === 'true' });
      }
    });
    await run('NAVEGADOR-01', async () => {
      await page.goto(cfg.web_origin + '/');
      await semantics();
      assert.equal(page.url(), cfg.web_origin + '/login');
      assert.equal(await page.title(), 'WorkNet');
      await page.getByRole('textbox', { name: 'Correo electrónico', exact: true }).waitFor();
      await capture('login');
    });
    await login('candidate', '/dashboard');
    await run('HU012-V01', async () => {
      await editor();
      await page.setViewportSize({ width: 390, height: 844 });
      assert.equal(await read('Nombre completo'), 'Candidato principal QA');
      assert.equal(await read('Correo electrónico'), values.candidate_email);
      assert.equal(await read('Perfil profesional'), 'Resumen ficticio QA');
      const text = await ui();
      for (const term of ['Formación QA', 'Experiencia QA', 'Django']) assert.ok(text.includes(term));
      assert.equal(bridge('snapshot').curricula.length, 0);
      await top(); await capture('precarga');
    });
    await run('HU012-V02', async () => {
      await write('Nombre completo', ''); await write('Correo electrónico', 'correo-invalido'); await write('Sitio web (opcional)', 'ftp://ejemplo.test');
      await click('Guardar CV');
      for (const term of ['Escribe tu nombre.', 'Escribe un correo electrónico válido.', 'Escribe una URL HTTP o HTTPS válida.']) await waitText(term);
      assert.equal(bridge('snapshot').curricula.length, 0);
      await click('Nombre completo', 'textbox'); await capture('validaciones');
      await write('Nombre completo', 'Candidato principal QA'); await write('Correo electrónico', values.candidate_email); await write('Sitio web (opcional)', '');
    });
    await run('HU012-V03', async () => {
      await click('Editar Educación');
      await write('Fecha de inicio', '2025-01-01'); await write('Fecha de finalización', '2024-01-01');
      await click('Guardar registro'); await waitText('La fecha final no puede ser anterior a la inicial.'); await capture('fechas');
      await write('Fecha de finalización', '2026-01-01'); await click('Guardar registro');
      await page.getByRole('alertdialog').waitFor({ state: 'hidden' });
    });
    await run('HU012-V04', async () => {
      await write('Perfil profesional', marker);
      for (const template of ['Moderna', 'Clásica', 'Minimalista']) {
        await click(/Tu currículum, a tu manera/); await click(template, 'menuitem');
        assert.equal(await read('Perfil profesional'), marker);
      }
      assert.ok((await ui()).includes('Formación QA'));
      await top(); await capture('plantilla');
    });
    await run('HU012-V05', async () => {
      await click('Volver a mi currículum'); await waitText('Cambios sin guardar'); await capture('salida');
      await click('Seguir editando'); assert.equal(await read('Perfil profesional'), marker);
    });
    await run('HU012-V06', async () => {
      fault('PUT', 'curriculum/generated/', 'abort'); await click('Guardar CV'); await waitText('No pudimos conectarnos.');
      assert.equal(await read('Perfil profesional'), marker);
      assert.equal(bridge('snapshot').curricula.length, 0);
      await top(); await capture('red'); faults.clear(); await saveCV(201);
      assert.equal(bridge('snapshot').curricula[0].data.professional_summary, marker);
    });
    await run('HU012-V07', async () => {
      await preview('preview-inicial.pdf'); await download('guardado-inicial.pdf');
      assert.equal(bridge('pdf_compare', 'preview-inicial.pdf', 'guardado-inicial.pdf').equal_text, true);
      const state = bridge('snapshot'); assert.ok(state.profile_unchanged && state.account_unchanged);
      await page.getByRole('img', { name: /Vista previa de tu edición/ }).scrollIntoViewIfNeeded(); await capture('pdf-movil');
      await click('Cerrar vista previa');
    });
    await run('HU012-V08', async () => {
      await click('Agregar idiomas'); await write('Idioma', 'Inglés QA'); await click('Guardar registro');
      await click('Agregar certificaciones'); await write('Certificación', 'Certificación ficticia QA'); await write('Entidad emisora', 'Entidad QA'); await click('Guardar registro');
      await click('Agregar otras secciones'); await write('Título de la sección', 'Proyectos QA'); await write('Contenido', 'Proyecto ficticio de aceptación.'); await click('Guardar registro');
      await saveCV(200); await preview('preview-final.pdf'); await download('guardado-final.pdf');
      assert.equal(bridge('pdf_compare', 'preview-final.pdf', 'guardado-final.pdf').optional_sections, true);
      await page.setViewportSize({ width: 1440, height: 1100 });
      await page.getByRole('img', { name: /Vista previa de tu edición/ }).scrollIntoViewIfNeeded();
      await page.mouse.move(1200, 800); await page.mouse.wheel(0, 500); await capture('pdf-secciones');
      await click('Cerrar vista previa');
    });
    await run('HU012-V09', async () => {
      await page.setViewportSize({ width: 390, height: 844 }); await write('Teléfono (opcional)', '000-QA-503');
      fault('PUT', 'curriculum/generated/', 'http', 503, { detail: 'Servicio QA temporalmente no disponible.' });
      await click('Guardar CV'); await waitText('El servicio no está disponible.');
      assert.equal(await read('Teléfono (opcional)'), '000-QA-503'); await top(); await capture('503-controlado');
      faults.clear(); await saveCV(200);
    });
    await run('HU012-V12', async () => {
      await write('Perfil profesional', 'BORRADOR DESCARTADO QA'); await click('Volver a mi currículum');
      const fresh = page.waitForResponse(r => endpoint(r, 'GET', 'curriculum/generated/'));
      // Sin espera entre confirmar salida y volver: cubre la transición saliente.
      await page.getByRole('button', { name: 'Salir sin guardar', exact: true }).click();
      await page.getByRole('button', { name: 'Crear mi CV', exact: true }).click();
      assert.equal((await fresh).status(), 200); assert.equal(await read('Perfil profesional'), marker); await capture('reentrada');
    });
    await run('HU012-V11', async () => {
      await leaveEditor(); fault('GET', 'curriculum/generated/', 'abort'); await click('Crear mi CV');
      await waitText('No pudimos conectarnos.'); await capture('carga'); faults.clear();
      const fresh = page.waitForResponse(r => endpoint(r, 'GET', 'curriculum/generated/'));
      await click('Reintentar'); assert.equal((await fresh).status(), 200); assert.equal(await read('Perfil profesional'), marker);
    });
    await run('HU012-V10', async () => {
      await page.setViewportSize({ width: 1440, height: 1000 }); await preview(); bridge('revoke_candidate');
      const expired = page.waitForResponse(r => endpoint(r, 'GET', 'curriculum/generated/'));
      await click('Volver a consultar'); assert.equal((await expired).status(), 401); await page.waitForURL(cfg.web_origin + '/login');
      await waitText('Tu sesión ya no es válida.'); assert.equal(await page.getByRole('img').count(), 0); await capture('401');
      await login('other', '/dashboard'); await editor(); await page.setViewportSize({ width: 390, height: 844 });
      assert.equal(await read('Nombre completo'), 'Otro candidato QA'); assert.equal(await read('Perfil profesional'), '');
      assert.ok(!(await ui()).includes(marker)); await top(); await capture('otra-cuenta');
      await leaveEditor(); await click('Volver al dashboard'); await logout();
    });
    await run('HU012-V13', async () => {
      await login('candidate', '/dashboard'); await editor(); bridge('revoke_candidate');
      const expired = page.waitForResponse(r => endpoint(r, 'POST', 'curriculum/generated/preview/'));
      await click('Vista previa'); assert.equal((await expired).status(), 401); await page.waitForURL(cfg.web_origin + '/login');
      await page.goBack(); await page.waitForURL(cfg.web_origin + '/login');
      assert.equal(await page.getByRole('img').count(), 0); await capture('sesion-atras');
    });
    let catalog;
    await login('company', '/company-dashboard');
    await run('HU013-V01', async () => {
      await page.setViewportSize({ width: 1440, height: 1000 }); await waitText('Ofertas activas: 2');
      const loaded = page.waitForResponse(r => endpoint(r, 'GET', 'company/offers/'));
      await click('Publicar oferta'); const response = await loaded; assert.equal(response.status(), 200); catalog = await response.json();
      for (const name of ['Título', 'Descripción', 'Requisitos', 'Salario', 'Ubicación']) await page.getByRole('textbox', { name, exact: true }).waitFor();
      await capture('formulario');
    });
    await run('HU013-V02', async () => {
      await click('Categoría'); await page.waitForTimeout(400); let text = await ui();
      for (const value of catalog.categories) assert.ok(text.includes(value)); await capture('categorias'); await click('Tecnología', 'menuitem');
      await click('Tipo de contrato'); await page.waitForTimeout(400); text = await ui();
      for (const value of catalog.contract_types) assert.ok(text.includes(value)); await capture('contratos'); await click('Indefinido', 'menuitem');
    });
    await run('HU013-V04', async () => {
      await fillOffer('Oferta visual escritorio QA', '-1'); const before = countPosts(); await click('Publicar oferta');
      await waitText('Escribe un salario no negativo'); assert.equal(countPosts(), before); await capture('salario'); await write('Salario', '1250000,50');
    });
    await run('HU013-V05', async () => {
      const published = page.waitForResponse(r => endpoint(r, 'POST', 'company/offers/')); await click('Publicar oferta');
      assert.equal((await published).status(), 201); await waitText('Oferta publicada correctamente. Número 3.'); await capture('confirmacion');
      const row = bridge('snapshot').offers[2]; assert.equal(row.company_id, 3); assert.equal(row.status, 'published'); assert.equal(row.salary, 1250000.5);
      await click('Volver al dashboard'); await waitText('Ofertas activas: 3'); await page.setViewportSize({ width: 390, height: 844 }); await capture('dashboard-3');
    });
    await run('HU013-V06', async () => {
      fault('GET', 'company/offers/', 'abort'); await click('Publicar oferta'); await waitText('No pudimos conectarnos.'); await capture('catalogo-red');
      faults.clear(); const loaded = page.waitForResponse(r => endpoint(r, 'GET', 'company/offers/')); await click('Reintentar'); assert.equal((await loaded).status(), 200);
    });
    await run('HU013-V03', async () => {
      const before = countPosts();
      for (const [width, height, name] of [[1440, 1000, 'escritorio'], [390, 844, 'movil']]) {
        await page.setViewportSize({ width, height }); await click('Publicar oferta');
        for (const term of ['Completa este campo.', 'Selecciona una categoría.', 'Selecciona un contrato.']) await waitText(term);
        await top(); await capture('obligatorios-' + name); assert.equal(countPosts(), before);
      }
    });
    await run('HU013-V07', async () => {
      await fillOffer('Oferta visual móvil QA'); await choices('Fijo'); fault('POST', 'company/offers/', 'abort');
      await click('Publicar oferta'); await waitText('No pudimos conectarnos.'); assert.equal(await read('Título'), 'Oferta visual móvil QA');
      assert.equal(bridge('snapshot').offers.length, 3); await top(); await capture('red-borrador'); faults.clear();
    });
    await run('HU013-V08', async () => {
      fault('POST', 'company/offers/', 'http', 400, { salary: ['Salario QA rechazado por validación controlada.'] });
      await click('Publicar oferta'); await waitText('Salario QA rechazado por validación controlada.');
      assert.equal(await read('Título'), 'Oferta visual móvil QA'); assert.equal(bridge('snapshot').offers.length, 3); await top(); await capture('400-controlado'); faults.clear();
    });
    await run('HU013-V09', async () => {
      const published = page.waitForResponse(r => endpoint(r, 'POST', 'company/offers/')); await click('Publicar oferta');
      assert.equal((await published).status(), 201); await waitText('Oferta publicada correctamente. Número 4.'); await capture('confirmacion');
      await click('Volver al dashboard'); await waitText('Ofertas activas: 4'); await capture('dashboard-4');
      const state = bridge('snapshot'); assert.equal(state.offers.length, 4); assert.equal(state.offers[3].contract_type, 'Fijo'); assert.equal(state.offers[3].salary, 900000);
    });
    await run('HU013-V10', async () => {
      await click('Publicar oferta'); await fillOffer('Sesión expirada QA', '1'); await choices('Indefinido'); bridge('revoke_company');
      const expired = page.waitForResponse(r => endpoint(r, 'POST', 'company/offers/')); await click('Publicar oferta'); assert.equal((await expired).status(), 401);
      await page.waitForURL(cfg.web_origin + '/login'); await waitText('Tu sesión ya no es válida.'); assert.equal(bridge('snapshot').offers.length, 4); await capture('401');
    });
    await run('HU013-V11', async () => {
      await login('draft', '/company', true); assert.equal(await page.getByRole('button', { name: 'Publicar oferta', exact: true }).count(), 0); await capture('empresa-pendiente');
      const denied = page.waitForResponse(r => endpoint(r, 'GET', 'company/offers/')); await page.goto(cfg.web_origin + '/company/offers/new'); await semantics();
      assert.equal((await denied).status(), 403); await waitText('espera la aprobación de tu empresa'); assert.equal(await page.getByRole('textbox').count(), 0); await capture('403');
    });
    assert.equal(results.casos.length, 25);
    assert.equal(new Set(results.casos.map(x => x.id)).size, 25);
    const final = bridge('snapshot'); assert.ok(final.profile_unchanged && final.account_unchanged);
    results.contrastes = { profile_unchanged: final.profile_unchanged, account_unchanged: final.account_unchanged, ofertas: final.offers.length, cv_generados: final.curricula.length, pdf_texto_coincidente: true };
    results.resultado = 'aprobado'; save(); console.log('25/25 OK; sin aprobación humana.');
  } catch (error) {
    results.resultado = 'fallido'; results.ultimo_caso = active; save();
    console.log('QA_SUITE_FAILED en ' + active + '; no se imprimen excepciones ni credenciales.');
    process.exitCode = 1;
  } finally {
    if (context) await context.close();
    if (browser) await browser.close();
  }
}

main().catch(() => {
  console.log('QA_GUARD_OR_SETUP_FAILED; no se abrió una sesión personal ni se imprimieron datos privados.');
  process.exitCode = 1;
});
