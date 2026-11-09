'use strict';
const assert=require('node:assert/strict');
module.exports=async({page,cfg,run,capture,bridge,ui,click:baseClick,waitText:baseWait,login,logout,semantics,fault,faults,results})=>{
  const seed=bridge('hu023_seed');results.preparacion_qa=seed;
  const response=(method,path)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+path);
  const top=async()=>{await page.mouse.move(180,200);await page.mouse.wheel(0,-25000);await page.waitForTimeout(300);};
  const bottom=async()=>{await page.mouse.move(180,350);await page.mouse.wheel(0,25000);await page.waitForTimeout(300);};
  const reveal=async(locator)=>{
    if(await locator().count())return;
    await top();
    for(let i=0;i<20 && await locator().count()===0;i++){
      await page.mouse.move(180,350);await page.mouse.wheel(0,Math.floor(page.viewportSize().height*.65));await page.waitForTimeout(180);await semantics();
    }
    assert.ok(await locator().count());
  };
  const click=async(name,role='button')=>{await reveal(()=>page.getByRole(role,{name,exact:typeof name==='string'}));await baseClick(name,role);};
  const text=async(value)=>{if(!(await ui()).includes(value))await top();if(!(await ui()).includes(value))await bottom();await baseWait(value);};
  const actor=name=>{const result=bridge('hu023_'+name);(results.actores_qa??=[]).push(result);return result;};
  const snapshot=()=>bridge('hu023_snapshot');
  let current=null,home=null,first=null,later=null,initialReadDate=null;
  const as=async(role,target)=>{
    await page.setViewportSize({width:1440,height:1000});
    if(current){await page.goto(cfg.web_origin+home);await semantics();await top();await logout();}
    await login(role,target,true);current=role;home=target;await top();
  };
  const centre=async()=>{const p=response('GET','notifications/');await click('Notificaciones');const r=await p;assert.equal(r.status(),200);await page.waitForURL(cfg.web_origin+'/notifications');await text('Centro de notificaciones');return r.json();};
  const refresh=async()=>{await top();const p=response('GET','notifications/');await click('Actualizar notificaciones');const r=await p;assert.equal(r.status(),200);return r.json();};
  const filter=async(label)=>{
    await top();let opened=false;
    for(const role of ['combobox','button']){const l=page.getByRole(role,{name:/Mostrar notificaciones/});if(await l.count()===1){await l.click();opened=true;break;}}
    assert.equal(opened,true);const p=response('GET','notifications/');await click(label,'menuitem');const r=await p;assert.equal(r.status(),200);return r.json();
  };
  const readFirst=async()=>{await top();const target=()=>page.getByRole('button',{name:'Marcar como leída',exact:true});await reveal(target);const p=response('POST','notifications/read/');await target().first().click();const r=await p;assert.equal(r.status(),200);return {result:await r.json(),ids:r.request().postDataJSON().notification_ids};};
  const save=async()=>{const p=response('PATCH','notifications/preferences/');await click('Guardar preferencias');const r=await p;assert.equal(r.status(),200);await text('Preferencias guardadas para los eventos nuevos.');return r.json();};
  const toggleMessages=async()=>{const get=()=>page.getByRole('switch',{name:/Nuevos mensajes/});await reveal(get);await get().click();};
  await run('HU023-V01',async()=>{
    await as('candidate','/dashboard');const b=await centre();assert.equal(b.count,seed.candidate_notices);assert.equal(b.unread_count,13);assert.equal(b.notifications.length,10);assert.equal(b.notifications[0].read_at,null);await top();await capture('historial-y-contador-escritorio');
  });
  await run('HU023-V02',async()=>{
    const a=await refresh();const p=response('GET','notifications/');await click('Página siguiente');const r=await p;assert.equal(r.status(),200);const b=await r.json();assert.equal(b.page,2);assert.equal(b.through_id,a.through_id);assert.ok(b.notifications.every(n=>!a.notifications.some(x=>x.id===n.id)));await top();await capture('pagina-dos-sin-repeticiones');
  });
  await run('HU023-V03',async()=>{
    assert.equal((await filter('Pendientes')).count,13);await top();await capture('filtro-pendientes');const b=await filter('Leídas');assert.ok(b.count>0);assert.ok(b.notifications.every(n=>n.read_at!==null));await capture('filtro-leidas');await filter('Todas');
  });
  await run('HU023-V04',async()=>{
    const b=await readFirst();assert.equal(b.result.marked_read,1);assert.equal(b.result.unread_count,12);assert.equal(b.ids.length,1);const read=await filter('Leídas');const item=read.notifications.find(n=>n.id===b.ids[0]);assert.ok(item?.read_at);initialReadDate={id:item.id,date:item.read_at};await top();await capture('lectura-explicita-y-fecha');await filter('Todas');
  });
  await run('HU023-V05',async()=>{
    const action=actor('status');assert.equal(action.replayed,false);const b=await refresh();assert.equal(b.notifications[0].event_kind,'application_status_changed');assert.equal(b.notifications[0].application_id,seed.own_ids['13']);await top();await capture('aviso-real-cambio-de-estado');const p=response('GET','applications/'+seed.own_ids['13']+'/');await page.getByRole('button',{name:'Consultar evento',exact:true}).first().click();assert.equal((await p).status(),200);await text('En revisión');await capture('detalle-del-aviso-real');await page.goBack();await semantics();await text('Centro de notificaciones');assert.equal(actor('status').replayed,true);
  });
  await run('HU023-V06',async()=>{
    first=actor('message');assert.ok(first.notification_id);assert.equal(actor('message_repeat').notification_id,first.notification_id);const b=await refresh();assert.equal(b.notifications[0].id,first.notification_id);assert.equal(b.notifications[0].event_kind,'message_received');await top();await capture('aviso-mensaje-destinatario');
  });
  await run('HU023-V07',async()=>{
    const url=cfg.api_origin+'/api/notifications/read/';
    await page.route(url,async route=>{later=actor('message_later');await route.continue();},{times:1});
    const b=await readFirst();assert.deepEqual(b.ids,[first.notification_id]);assert.equal(b.result.marked_read,1);const view=await refresh();assert.equal(view.notifications[0].id,later.notification_id);assert.equal(view.notifications[0].read_at,null);assert.equal(snapshot().new_messages_read,0);await top();await capture('llegada-nueva-sigue-pendiente');
  });
  await run('HU023-V08',async()=>{
    const p=response('GET','conversations/'+seed.conversation_ids['3']+'/messages/');await page.getByRole('button',{name:'Consultar evento',exact:true}).first().click();assert.equal((await p).status(),200);await text('Conversación del proceso');await text('Volver a notificaciones');await capture('conversacion-del-aviso');await click('Volver a notificaciones');await text('Centro de notificaciones');const b=await refresh();assert.equal(b.notifications.find(n=>n.id===later.notification_id).read_at,null);assert.equal(snapshot().new_messages_read,2);await top();await capture('leer-chat-no-lee-aviso');
  });
  await run('HU023-V09',async()=>{
    await toggleMessages();assert.equal((await save()).preferences.message_received,false);const before=snapshot();const result=actor('message_suppressed');assert.equal(result.notification_id,null);assert.equal(snapshot().new_notices,before.new_notices);await bottom();await capture('preferencia-futura-deshabilitada');
  });
  await run('HU023-V10',async()=>{
    await toggleMessages();assert.equal((await save()).preferences.message_received,true);assert.equal(actor('message_suppressed_repeat').notification_id,null);const result=actor('message_after_enable');assert.ok(result.notification_id);const b=await refresh();assert.equal(b.notifications[0].id,result.notification_id);await top();await capture('evento-nuevo-despues-de-habilitar');
  });
  await run('HU023-V11',async()=>{
    const a=actor('application');await as('company','/company-dashboard');const b=await centre();assert.equal(b.unread_count,1);assert.equal(b.notifications[0].event_kind,'application_created');assert.equal(b.notifications[0].application_id,a.application_id);await capture('empresa-recibe-nueva-postulacion');
  });
  await run('HU023-V12',async()=>{
    assert.equal(actor('approve').state,'approved');await as('approval','/company-dashboard');const b=await centre();assert.equal(b.count,1);assert.equal(b.notifications[0].event_kind,'company_reviewed');await text('Tu empresa fue aprobada.');await capture('aprobacion-propia');
  });
  await run('HU023-V13',async()=>{
    assert.equal(actor('reject').state,'rejected');await as('rejection','/company');const b=await centre();assert.equal(b.count,1);await text('Tu solicitud fue rechazada');await capture('rechazo-propio-sin-dashboard');await click('Consultar evento');await text('Estado: Rechazada');await capture('cuenta-rechazada-conserva-restricciones');
  });
  await run('HU023-V14',async()=>{
    await as('candidate','/dashboard');await page.setViewportSize({width:390,height:844});await centre();await top();await capture('historial-movil');const b=await readFirst();assert.equal(b.result.marked_read,1);await top();await capture('lectura-y-contador-movil');await bottom();await capture('preferencias-movil');
  });
  await run('HU023-V15',async()=>{
    await as('other','/dashboard');const b=await centre();assert.equal(b.count,0);await text('No hay notificaciones para este filtro.');await capture('historial-vacio-otro-usuario');
  });
  await run('HU023-V16',async()=>{
    fault('GET','notifications/','http',503,{message:'Fallo temporal QA identificado'});await click('Actualizar notificaciones');await text('Fallo temporal QA identificado');await capture('error-inyectado-identificado');faults.delete('GET /api/notifications/');const p=response('GET','notifications/');await click('Reintentar');assert.equal((await p).status(),200);await text('No hay notificaciones para este filtro.');await capture('reintento-real');
  });
  await run('HU023-V17',async()=>{
    assert.equal(actor('revoke_other').revoked,true);const p=response('GET','notifications/');await click('Actualizar notificaciones');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');await text('Tu sesión ya no es válida.');await capture('sesion-revocada-sin-datos');
    const final=snapshot();assert.equal(final.new_notices,7);assert.deepEqual(final.new_notice_kinds,{application_created:1,application_status_changed:1,message_received:3,company_reviewed:2});assert.equal(final.new_messages,4);assert.equal(final.new_applications,1);assert.equal(final.duplicate_notices,0);assert.equal(final.old_notice_ids_marked_read.length,1);results.persistencia=final;results.alcance_actores='Eventos reales de actores API ficticios identificados; consulta, filtros, lectura, preferencias y navegación por UI. No se atribuye a UI la creación de los eventos API.';
    assert.ok(initialReadDate);
  });
};
