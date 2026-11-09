'use strict';
// Complemento visual independiente: no suma casos a la aceptación HU021/HU022.
const assert=require('node:assert/strict');
module.exports=async({page,cfg,run,capture,bridge,login,semantics,waitText,results})=>{
  const response=suffix=>page.waitForResponse(r=>r.request().method()==='GET'&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+suffix);
  const top=async()=>{await page.mouse.move(180,350);await page.mouse.wheel(0,-20000);await page.waitForTimeout(500);};
  results.complemento={scope:'Otra QA nueva; cuatro comprobaciones visuales/de acceso más el control de arranque. No se suman a34/34 HU021/HU022.',preparacion:bridge('hu02122_seed')};
  await run('HU005-C01',async()=>{
    results.complemento.actor_qa=bridge('hu02122_unread_for_access');
    await login('candidate','/dashboard',true);
    const load=response('dashboard/candidate/');await page.goto(cfg.web_origin+'/dashboard');await semantics();const d=await(await load).json();
    assert.equal(d.profile_completion.percentage,100);assert.equal(d.metrics.applications_count,13);assert.equal(d.metrics.saved_offers_count,6);assert.equal(d.metrics.pending_notifications_count,2);
    await page.getByRole('button',{name:'Mensajes',exact:true}).waitFor();await top();await waitText('Mensajes sin leer: 1');await capture('dashboard-escritorio-accesos');
  });
  await run('HU005-C02',async()=>{
    await page.setViewportSize({width:390,height:844});await top();
    // Rueda real sobre Flutter: scrollIntoView del árbol semántico no acredita
    // que el botón esté dibujado en la misma región del canvas.
    for(let i=0;i<4;i++){await page.mouse.wheel(0,400);await page.waitForTimeout(400);}
    const text=await page.locator('body').ariaSnapshot();assert.ok(text.includes('Consulta el detalle y postúlate desde Buscar ofertas.'));
    await page.getByRole('button',{name:'Mensajes',exact:true}).waitFor();await capture('dashboard-movil-acceso-y-contador');
  });
  await run('HU005-C03',async()=>{
    const load=response('conversations/');await page.getByRole('button',{name:'Mensajes',exact:true}).click();const r=await load;assert.equal(r.status(),200);const d=await r.json();assert.equal(d.count,12);
    await waitText('Conversaciones encontradas: 12');await capture('clic-real-mensajes-movil');
    const id=results.complemento.preparacion.conversation_ids['3'],index=d.conversations.findIndex(c=>c.id===id);assert.ok(index>=0);
    const loaded=response(`conversations/${id}/messages/`),read=page.waitForResponse(r=>r.request().method()==='POST'&&new URL(r.url()).pathname===`/api/conversations/${id}/read/`);
    await page.getByRole('button',{name:'Abrir conversación',exact:true}).nth(index).click();assert.equal((await loaded).status(),200);assert.equal((await(await read).json()).unread_count,0);await waitText('Pendientes de lectura en esta conversación: 0');await capture('mensaje-recibido-leido');
    results.complemento.click={actor:'candidate',viewport:page.viewportSize(),method:'GET',path:'/api/conversations/',status:200,count:12};
  });
  await run('HU005-C04',async()=>{
    const conversations=response('conversations/');await page.getByRole('button',{name:'Volver a conversaciones',exact:true}).click();assert.equal((await conversations).status(),200);await waitText('Conversaciones encontradas: 12');
    await page.getByRole('button',{name:'Volver al dashboard',exact:true}).click();await page.waitForTimeout(600);await top();for(let i=0;i<4;i++){await page.mouse.wheel(0,400);await page.waitForTimeout(400);}
    await waitText('Mensajes sin leer: 0');await capture('contador-dashboard-despues-de-leer');
    await top();const load=response('dashboard/candidate/');await page.getByRole('button',{name:'Actualizar datos',exact:true}).click();const summary=await(await load).json();assert.equal(summary.metrics.applications_count,13);assert.equal(summary.metrics.saved_offers_count,6);
    await page.setViewportSize({width:1440,height:1000});await top();await capture('regreso-dashboard-sin-alterar-datos');
    const d=bridge('hu02122_snapshot');assert.equal(d.new_applications,0);assert.equal(d.status_events,0);assert.equal(d.new_conversations,0);assert.equal(d.new_messages,1);
    results.complemento.persistencia=d;
  });
};
