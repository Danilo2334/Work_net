'use strict';
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');

module.exports=async({page,cfg,run,capture,bridge,ui,write:baseWrite,click:baseClick,waitText,login,logout,semantics,fault,faults,results})=>{
  const seed=bridge('hu02122_seed');results.preparacion_qa=seed;
  const response=(method,suffix)=>page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).origin===cfg.api_origin&&new URL(r.url()).pathname==='/api/'+suffix);
  const top=async()=>{await page.mouse.move(220,220);await page.mouse.wheel(0,-25000);await page.waitForTimeout(300);};
  const bottom=async()=>{await page.mouse.move(220,350);await page.mouse.wheel(0,25000);await page.waitForTimeout(300);};
  const click=async(name,role='button')=>{
    const target=()=>page.getByRole(role,{name,exact:typeof name==='string'});
    if(await target().count()===0)await top();
    if(await target().count()===0)await bottom();
    await baseClick(name,role);
  };
  const write=async(name,value)=>{
    const target=()=>page.getByRole('textbox',{name,exact:true});
    if(await target().count()===0)await top();
    if(await target().count()===0)await bottom();
    await baseWrite(name,value);
  };
  const snap=()=>bridge('hu02122_snapshot');
  const actor=name=>{const a=bridge('hu02122_'+name);(results.actores_qa??=[]).push(a);return a;};
  const goto=async(path,suffix,status=200)=>{
    const p=response('GET',suffix);await page.goto(cfg.web_origin+path);await semantics();
    const r=await p;assert.equal(r.status(),status);return status===200?await r.json():null;
  };
  let account=null;
  const as=async(name)=>{
    await page.setViewportSize({width:1440,height:1000});
    if(account){await page.goto(cfg.web_origin+(account==='draft'?'/company':account==='company'||account==='other_company'?'/company-dashboard':'/dashboard'));await semantics();await top();await logout();}
    const home=name==='draft'?'/company':name==='company'||name==='other_company'?'/company-dashboard':'/dashboard';
    await login(name,home,true);account=name;await top();
  };
  const companyDetail=async(offer,status=200)=>{
    const id=seed.own_ids[String(offer)]??offer;
    const p=status===200?response('GET',`company/applications/${id}/status/`):null;
    const b=await goto(`/company/offers/${offer}/applicants/${id}`,`company/applications/${id}/`,status);
    if(p){assert.equal((await p).status(),200);await waitText('Cambiar estado de postulación');}
    return b?.application;
  };
  const candidateDetail=async(offer)=>{
    const id=seed.own_ids[String(offer)];const b=await goto('/applications/'+id,'applications/'+id+'/');
    await waitText('Detalle de postulación');return b.application;
  };
  const selectState=async(label)=>{
    let opened=false;
    for(const target of [page.getByRole('combobox',{name:/Nuevo estado/}),page.getByRole('button',{name:/Nuevo estado/})]){
      if(await target.count()===1){await target.scrollIntoViewIfNeeded();await page.waitForTimeout(200);await target.click();opened=true;break;}
    }
    assert.equal(opened,true);await click(label,'menuitem');
  };
  const prepareState=async(label,comment='')=>{await selectState(label);await write('Comentario opcional',comment);await click('Revisar cambio');await waitText('Confirmar cambio de estado');};
  const confirmState=async(offer,label,comment='')=>{
    await prepareState(label,comment);const p=response('POST',`company/applications/${seed.own_ids[String(offer)]}/status/`);
    await click('Confirmar cambio');const r=await p;assert.equal(r.status(),200);const b=await r.json();
    await waitText('Estado de postulación: '+label);await page.waitForTimeout(300);return b;
  };
  const pdf=async(item,company=false)=>{
    const p=response('GET',(company?'company/':'')+`applications/${item.id}/cv/`);await click('Ver CV enviado');const r=await p;
    assert.equal(r.status(),200);assert.equal(createHash('sha256').update(await r.body()).digest('hex'),item.cv.sha256);
    await page.getByRole('img',{name:'Contenido del currículum, página 1',exact:true}).waitFor();await capture('pdf-'+item.cv.source);await click('Cerrar documento');
  };
  const listConversations=async()=>{const b=await goto('/messages','conversations/');await waitText('Conversaciones encontradas: '+b.count);return b;};
  let chatId,review,accepted,rejected;
  await as('company');
  await run('HU021-V01',async()=>{
    await waitText('Dashboard de empresa');await capture('acceso-empresa');
    const before=await companyDetail(3);assert.equal(before.status,'submitted');assert.equal(before.status_change.version,0);
    assert.equal(before.offer.status,'closed');await bottom();await capture('controles-y-contexto-propio');
  });
  await run('HU021-V02',async()=>{
    const before=snap();await prepareState('En revisión','Comentario cancelado QA');await capture('confirmacion-antes-de-cancelar');
    await click('Cancelar');assert.equal(snap().status_events,before.status_events);
    const p=response('GET',`company/applications/${seed.own_ids['3']}/`);await click('Actualizar detalle');const b=(await(await p).json()).application;
    assert.deepEqual(b.status_change,{version:0,modified_at:null,comment:''});assert.equal(b.status,'submitted');await bottom();await capture('cancelacion-sin-modificar');
  });
  await run('HU021-V03',async()=>{
    review=await confirmState(3,'En revisión','Revisión empresarial desde pantalla QA');
    assert.equal(review.application.status_change.version,1);assert.equal(review.application.status_change.comment,'Revisión empresarial desde pantalla QA');
    assert.equal(review.event.changed_at,review.application.status_change.modified_at);assert.equal(review.replayed,false);
    await top();await capture('revision-confirmada-empresa');assert.equal(snap().status_events,1);
  });
  await run('HU021-V04',async()=>{
    await as('candidate');await waitText('Últimos avisos');await bottom();await capture('aviso-real-recibido-candidato');
    const p=response('GET',`applications/${seed.own_ids['3']}/`);await click('Consultar postulación del aviso');const b=(await(await p).json()).application;
    assert.equal(b.status,'in_review');assert.equal(b.status_change.comment,review.event.comment);await capture('detalle-desde-aviso');
    await goto('/applications','applications/');const h=response('GET','applications/');await click('Siguiente');const history=(await(await h).json()).applications;
    assert.equal(history.find(a=>a.id===seed.own_ids['3']).status,'in_review');await bottom();await capture('historial-actualizado-cambio-empresarial');
  });
  await run('HU021-V05',async()=>{
    await as('company');await companyDetail(3);accepted=await confirmState(3,'Aceptada');
    assert.equal(accepted.application.status_change.version,2);assert.equal(accepted.application.status_change.comment,'');
    assert.equal(accepted.application.created_at,review.application.created_at);assert.deepEqual(accepted.application.cv,review.application.cv);
    await top();await capture('aceptada-sin-comentario');await bottom();await waitText('Esta decisión es final.');
  });
  await run('HU021-V06',async()=>{
    const old=await companyDetail(4);assert.equal(old.status,'in_review');assert.equal(old.status_change.modified_at,null);
    rejected=await confirmState(4,'Rechazada','Decisión empresarial comunicada QA');
    assert.equal(rejected.application.status_change.version,1);assert.deepEqual(rejected.application.cv,old.cv);await top();await capture('rechazada-fecha-y-comentario');await pdf(rejected.application,true);
  });
  await run('HU021-V07',async()=>{
    await as('candidate');const dashboard=await goto('/dashboard','dashboard/candidate/');
    assert.equal(dashboard.metrics.pending_notifications_count,seed.candidate_metrics.pending_notifications_count+3);
    assert.equal(dashboard.notifications.filter(n=>n.event_kind==='application_status_changed').length,3);await bottom();await capture('tres-avisos-con-fechas-y-contexto');
    let b=await candidateDetail(3);assert.equal(b.status,'accepted');await capture('aceptada-candidato');
    b=await candidateDetail(4);assert.equal(b.status,'rejected');assert.equal(b.status_change.comment,rejected.event.comment);await capture('rechazada-candidato');
  });
  await run('HU021-V08',async()=>{
    await as('other_company');await goto(`/company/offers/3/applicants/${seed.own_ids['3']}`,`company/applications/${seed.own_ids['3']}/`,404);
    await waitText('No encontramos esa postulación');await capture('otra-empresa-rechazada');
    await as('draft');await goto(`/company/offers/3/applicants/${seed.own_ids['3']}`,`company/applications/${seed.own_ids['3']}/`,403);await capture('empresa-pendiente-rechazada');
    await as('candidate');await page.goto(cfg.web_origin+`/company/offers/3/applicants/${seed.own_ids['3']}`);await semantics();await page.waitForURL(cfg.web_origin+'/dashboard');await capture('rol-candidato-protegido');
  });
  await run('HU021-V09',async()=>{
    await as('company');const id=seed.own_ids['13'];fault('GET',`company/applications/${id}/status/`,'http',503,{detail:'Fallo QA inyectado'});
    await goto(`/company/offers/13/applicants/${id}`,`company/applications/${id}/`);await waitText('El servicio no está disponible.');await bottom();await capture('error-estado-inyectado');
    faults.clear();const p=response('GET',`company/applications/${id}/status/`);await click('Reintentar estado');assert.equal((await p).status(),200);await waitText('Estado vigente: Enviada');await capture('estado-recuperado-por-get');
  });
  await run('HU021-V10',async()=>{
    const id=seed.own_ids['13'],target=cfg.api_origin+`/api/company/applications/${id}/status/`;let command;
    const lost=async route=>{if(route.request().method()!=='POST')return route.fallback();command=route.request().postDataJSON();const r=await route.fetch();assert.equal(r.status(),200);assert.equal(r.headers()['x-worknet-qa-run'],cfg.nonce);results.red.push({method:'POST',path:new URL(target).pathname,status:200,respuesta_perdida:true,inyectada:false});await route.abort('failed');};
    await page.route(target,lost);await prepareState('En revisión','Respuesta perdida de cambio real QA');await click('Confirmar cambio');await waitText('Comprobar cambio');
    assert.equal(snap().status_events,4);await bottom();await capture('respuesta-aceptada-perdida');await page.unroute(target,lost);
    const p=response('GET',`company/applications/${id}/status/operations/${command.request_id}/`);await click('Comprobar cambio');const b=await(await p).json();
    assert.equal(b.replayed,true);assert.equal(b.application.status,'in_review');assert.equal(snap().status_events,4);await top();await capture('cambio-conciliado-sin-reenvio');
  });
  await run('HU021-V11',async()=>{
    const id=seed.own_ids['11'];await companyDetail(11);await prepareState('Aceptada','Confirmación tras concurrencia QA');
    const a=actor('concurrent_review');assert.equal(a.event.version,1);
    const p=response('POST',`company/applications/${id}/status/`);await click('Confirmar cambio');assert.equal((await p).status(),409);
    await waitText('Estado de postulación: En revisión');await top();await capture('conflicto-sin-sobrescribir');
    const b=await confirmState(11,'Aceptada','Nueva revisión de datos vigentes QA');assert.equal(b.application.status_change.version,2);await capture('confirmacion-nueva-version');
  });
  await run('HU021-V12',async()=>{
    await companyDetail(7);await page.setViewportSize({width:390,height:844});
    await prepareState('Rechazada','Decisión móvil web QA');await capture('confirmacion-movil');const p=response('POST',`company/applications/${seed.own_ids['7']}/status/`);await click('Confirmar cambio');assert.equal((await p).status(),200);
    await waitText('Estado de postulación: Rechazada');await top();await capture('rechazo-confirmado-movil');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
    await as('candidate');await page.setViewportSize({width:390,height:844});const b=await candidateDetail(7);assert.equal(b.status,'rejected');await capture('rechazo-recibido-movil');await pdf(b);await page.setViewportSize({width:1440,height:1000});
  });
  await run('HU021-V13',async()=>{
    await as('company');await companyDetail(13);bridge('revoke_company');const p=response('GET',`company/applications/${seed.own_ids['13']}/`);await click('Actualizar detalle');assert.equal((await p).status(),401);
    await page.waitForURL(cfg.web_origin+'/login');account=null;await capture('sesion-empresa-revocada');await as('company');
  });
  const openChat=async(id,status=200)=>{const b=await goto('/messages/'+id,`conversations/${id}/messages/`,status);if(b)await waitText('Pendientes de lectura en esta conversación:');return b;};
  const sendChat=async(text)=>{
    await bottom();await write('Mensaje de texto',text);const p=response('POST',`conversations/${chatId}/messages/`),load=response('GET',`conversations/${chatId}/messages/`);
    await click('Enviar mensaje');const r=await p;assert.equal(r.status(),201);const b=await r.json();assert.equal(b.message.text,text);assert.equal((await load).status(),200);
    await top();await waitText('Mensaje enviado correctamente.');await bottom();
    (results.mensajes_ui??=[]).push({actor:account,id:b.message.id,client_message_id:b.message.client_message_id,created_at:b.message.created_at});return b.message;
  };
  const openFromList=async(id)=>{
    const b=await listConversations(),index=b.conversations.findIndex(c=>c.id===id);assert.ok(index>=0);
    const p=response('GET',`conversations/${id}/messages/`);const button=page.getByRole('button',{name:'Abrir conversación',exact:true}).nth(index);await button.scrollIntoViewIfNeeded();await page.waitForTimeout(200);await button.click();const r=await p;assert.equal(r.status(),200);return r.json();
  };
  await run('HU022-V01',async()=>{
    await waitText('Dashboard de empresa');await waitText('Mensajes sin leer: 0');await capture('mensajes-desde-dashboard-empresa');
    const p=response('GET','conversations/');await click('Mensajes');assert.equal((await(await p).json()).count,13);await waitText('Conversaciones encontradas: 13');await capture('lista-contactos-y-contexto');
  });
  await run('HU022-V02',async()=>{
    await companyDetail(13);const p=response('POST','conversations/');await click('Conversar con el candidato');const r=await p;assert.equal(r.status(),201);const b=await r.json();chatId=b.conversation.id;
    assert.equal(b.conversation.application_id,seed.own_ids['13']);assert.equal(b.conversation.contact.id,seed.candidate_id);
    await waitText('Esta conversación todavía no tiene mensajes.');await top();await capture('conversacion-nueva-autorizada-vacia');
  });
  await run('HU022-V03',async()=>{
    const m=await sendChat('Hola, te invitamos a conversar sobre la oferta QA.');assert.equal(m.sender_id,seed.company_id);assert.equal(m.recipient_id,seed.candidate_id);
    await capture('envio-empresarial-fecha-hora');assert.equal(snap().new_messages,1);
  });
  await run('HU022-V04',async()=>{
    await as('candidate');await waitText('Mensajes sin leer: 1');await bottom();await capture('indicador-candidato-antes-de-leer');
    const target=cfg.api_origin+`/api/conversations/${chatId}/read/`;let injected=false;
    const arriving=async route=>{if(route.request().method()==='POST'&&!injected){injected=true;actor('message_during_read');}return route.fallback();};
    await page.route(target,arriving);const read=response('POST',`conversations/${chatId}/read/`);const b=await openFromList(chatId);assert.equal(b.count,1);
    const acknowledged=await(await read).json();assert.equal(acknowledged.marked_read,1);assert.equal(acknowledged.unread_count,1);await page.unroute(target,arriving);
    await waitText('Pendientes de lectura en esta conversación: 1');assert.ok(!(await ui()).includes('Mensaje nuevo durante lectura QA'));await capture('nuevo-mensaje-conserva-pendiente');
  });
  await run('HU022-V05',async()=>{
    const read=response('POST',`conversations/${chatId}/read/`),load=response('GET',`conversations/${chatId}/messages/`);await click('Actualizar conversación');
    assert.equal((await(await load).json()).count,2);assert.equal((await(await read).json()).unread_count,0);await waitText('Pendientes de lectura en esta conversación: 0');
    await bottom();await capture('lectura-solo-ventana-consultada');
  });
  await run('HU022-V06',async()=>{
    const m=await sendChat('Confirmo mi interés. Gracias por contactar, QA.');assert.equal(m.sender_id,seed.candidate_id);assert.equal(m.recipient_id,seed.company_id);
    await capture('conversacion-bidireccional-candidato');
  });
  await run('HU022-V07',async()=>{
    await as('company');await waitText('Mensajes sin leer: 1');await capture('indicador-empresa-antes-de-leer');
    const read=response('POST',`conversations/${chatId}/read/`);await openFromList(chatId);assert.equal((await(await read).json()).unread_count,0);
    await waitText('Pendientes de lectura en esta conversación: 0');await bottom();await capture('respuesta-candidata-recibida-empresa');
  });
  await run('HU022-V08',async()=>{
    const target=cfg.api_origin+`/api/conversations/${chatId}/messages/`;let command;
    const lost=async route=>{if(route.request().method()!=='POST')return route.fallback();command=route.request().postDataJSON();const r=await route.fetch();assert.equal(r.status(),201);assert.equal(r.headers()['x-worknet-qa-run'],cfg.nonce);results.red.push({method:'POST',path:new URL(target).pathname,status:201,respuesta_perdida:true,inyectada:false});await route.abort('failed');};
    await page.route(target,lost);await bottom();await write('Mensaje de texto','Respuesta perdida del chat QA');await click('Enviar mensaje');await waitText('Comprobar envío');await capture('envio-aceptado-respuesta-perdida');
    const count=snap().new_messages;assert.equal(count,4);await page.unroute(target,lost);
    const p=response('GET',`conversations/${chatId}/messages/operations/${command.client_message_id}/`);await click('Comprobar envío');assert.equal((await p).status(),200);
    await top();await waitText('Mensaje enviado correctamente.');assert.equal(snap().new_messages,count);await bottom();await capture('recibo-por-get-sin-duplicar');
  });
  await run('HU022-V09',async()=>{
    const suffix=`conversations/${chatId}/messages/`,before=snap().new_messages;fault('POST',suffix,'abort');await bottom();await write('Mensaje de texto','Intento conservado de mensaje QA');await click('Enviar mensaje');await waitText('Comprobar envío');assert.equal(snap().new_messages,before);
    const p=page.waitForResponse(r=>r.request().method()==='GET'&&new URL(r.url()).pathname.includes(`/conversations/${chatId}/messages/operations/`));await click('Comprobar envío');assert.equal((await p).status(),404);await waitText('Reintentar mismo envío');await capture('fallo-antes-de-escribir');faults.clear();
    const sent=response('POST',suffix);await click('Reintentar mismo envío');assert.equal((await sent).status(),201);await top();await waitText('Mensaje enviado correctamente.');assert.equal(snap().new_messages,before+1);await bottom();await capture('reintento-misma-intencion');
  });
  await run('HU022-V10',async()=>{
    const a=await sendChat('Texto legítimo repetido QA'),b=await sendChat('Texto legítimo repetido QA');assert.notEqual(a.id,b.id);assert.notEqual(a.client_message_id,b.client_message_id);await capture('mismo-texto-dos-intenciones-validas');
  });
  await run('HU022-V11',async()=>{
    let b=await listConversations();assert.equal(b.count,14);await write('Contacto u oferta','Candidato');let p=response('GET','conversations/');await click('Buscar conversaciones');b=await(await p).json();assert.equal(b.count,13);const first=b.conversations.map(c=>c.id);
    p=response('GET','conversations/');await click('Más conversaciones');b=await(await p).json();assert.equal(b.page,2);assert.equal(b.conversations.length,3);assert.ok(b.conversations.every(c=>!first.includes(c.id)));assert.equal(new URL(page.url()).searchParams.get('q'),'Candidato');await capture('busqueda-conservada-pagina-dos');
    await write('Contacto u oferta','Inexistente');p=response('GET','conversations/');await click('Buscar conversaciones');b=await(await p).json();assert.equal(b.page,1);assert.equal(b.count,0);await waitText('No hay conversaciones para esta búsqueda.');await capture('cambio-reinicia-y-vacio');
    p=response('GET','conversations/');await click('Limpiar búsqueda');assert.equal((await(await p).json()).count,14);
  });
  await run('HU022-V12',async()=>{
    const id=seed.conversation_ids['4'],first=await openChat(id);assert.equal(first.count,23);assert.equal(first.messages.length,10);actor('message_outside_window');
    const p=response('GET',`conversations/${id}/messages/`);await click('Ver mensajes anteriores');const second=await(await p).json();assert.equal(second.count,23);assert.equal(second.through_id,first.through_id);assert.ok(second.messages.every(m=>!first.messages.some(x=>x.id===m.id)));
    await top();await waitText('Pendientes de lectura en esta conversación: 1');await capture('ancla-paginacion-sin-consumir-nuevo');
    const read=response('POST',`conversations/${id}/read/`),load=response('GET',`conversations/${id}/messages/`);await click('Actualizar conversación');assert.equal((await(await load).json()).count,24);assert.equal((await(await read).json()).unread_count,0);await bottom();await capture('actualizar-incluye-nuevo-mensaje');
  });
  await run('HU022-V13',async()=>{
    const id=seed.conversation_ids['4'];let p=response('GET',`conversations/${id}/messages/`);await page.reload();await semantics();assert.equal((await(await p).json()).count,24);await bottom();await capture('mensajes-conservados-al-recargar');
    await as('company');const b=await openChat(chatId);assert.equal(b.messages.filter(m=>m.text==='Texto legítimo repetido QA').length,2);await bottom();await capture('mensajes-en-nueva-sesion');
  });
  await run('HU022-V14',async()=>{
    await bottom();const before=snap().new_messages;await write('Mensaje de texto','   ');await click('Enviar mensaje');await waitText('Escribe un mensaje de 1 a 4000 caracteres.');assert.equal(snap().new_messages,before);await capture('mensaje-vacio-sin-envio');
    fault('GET',`conversations/${chatId}/messages/`,'http',503,{detail:'Fallo QA inyectado'});await page.reload();await semantics();await waitText('El servicio no está disponible.');await capture('error-chat-inyectado');faults.clear();let p=response('GET',`conversations/${chatId}/messages/`);await click('Reintentar');assert.equal((await p).status(),200);await waitText('Pendientes de lectura en esta conversación:');
    actor('candidate_pending');fault('POST',`conversations/${chatId}/read/`,'http',503,{detail:'Lectura QA inyectada'});p=response('GET',`conversations/${chatId}/messages/`);await click('Actualizar conversación');assert.equal((await p).status(),200);await waitText('Lectura sin confirmar:');await capture('lectura-pendiente-por-fallo-inyectado');faults.clear();p=response('POST',`conversations/${chatId}/read/`);await click('Reintentar lectura');assert.equal((await(await p).json()).unread_count,0);await waitText('Pendientes de lectura en esta conversación: 0');await capture('lectura-recuperada-ids-consultados');
  });
  await run('HU022-V15',async()=>{
    await openChat(seed.foreign_conversation,404);await capture('conversacion-ajena-empresa-404');
    await as('other');const empty=await listConversations();assert.equal(empty.count,0);await capture('tercero-lista-aislada');await openChat(chatId,404);await capture('tercero-acceso-directo-404');
    await as('draft');await goto('/messages','conversations/',403);await capture('mensajeria-empresa-pendiente-403');
    await page.goto(cfg.web_origin+'/company');await semantics();await logout();account=null;await page.goto(cfg.web_origin+'/messages/'+chatId);await semantics();await page.waitForURL(cfg.web_origin+'/login');await capture('conversacion-sin-sesion-protegida');
  });
  await run('HU022-V16',async()=>{
    await as('candidate');await page.setViewportSize({width:390,height:844});await bottom();await capture('mensajes-dashboard-candidato-movil');
    const read=response('POST',`conversations/${chatId}/read/`);await openFromList(chatId);assert.equal((await(await read).json()).unread_count,0);await top();await capture('contacto-y-lectura-movil');
    const m=await sendChat('Respuesta móvil candidata QA');assert.equal(m.sender_id,seed.candidate_id);await capture('envio-candidato-movil');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
    await as('company');await page.setViewportSize({width:390,height:844});await waitText('Mensajes sin leer: 1');const read2=response('POST',`conversations/${chatId}/read/`);await openFromList(chatId);assert.equal((await(await read2).json()).unread_count,0);await bottom();await capture('respuesta-movil-recibida-empresa');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
  });
  await run('HU022-V17',async()=>{
    bridge('revoke_company');const p=response('GET',`conversations/${chatId}/messages/`);await click('Actualizar conversación');assert.equal((await p).status(),401);await page.waitForURL(cfg.web_origin+'/login');account=null;await capture('sesion-chat-revocada');await page.setViewportSize({width:1440,height:1000});
  });
  await run('REGRESION-V01',async()=>{
    actor('delete_sources');await as('candidate');const d=await goto('/dashboard','dashboard/candidate/');assert.equal(d.profile_completion.percentage,100);assert.equal(d.metrics.applications_count,13);assert.equal(d.metrics.saved_offers_count,6);assert.equal(d.metrics.pending_notifications_count,seed.candidate_metrics.pending_notifications_count+7);assert.ok(d.recent_jobs.length>0);await top();await capture('hu005-metricas-completitud-y-notificaciones');await bottom();await capture('hu005-todos-los-accesos-y-avisos');
    let p=response('GET','profile/candidate/');await click('Perfil del candidato');assert.equal((await p).status(),200);await capture('hu005-acceso-perfil');await page.goto(cfg.web_origin+'/dashboard');await semantics();await waitText('Tus accesos');
    p=response('GET','curriculum/');await click('Mi currículum');const cv=await(await p).json();assert.equal(cv.uploaded,null);assert.equal(cv.generated,null);await capture('hu005-acceso-curriculum');await page.goto(cfg.web_origin+'/dashboard');await semantics();await waitText('Tus accesos');
    p=response('GET','offers/search/');await click('Buscar ofertas');assert.equal((await p).status(),200);await capture('hu005-acceso-busqueda');await page.goto(cfg.web_origin+'/dashboard');await semantics();await waitText('Tus accesos');
    p=response('GET','offers/saved/');await click('Guardados');assert.equal((await(await p).json()).count,6);await capture('hu005-guardados-conservados');await page.goto(cfg.web_origin+'/dashboard');await semantics();await waitText('Tus accesos');
    p=response('GET','applications/');await click('Mis postulaciones');assert.equal((await(await p).json()).count,13);await capture('hu005-historial-real');const b=await candidateDetail(4);await pdf(b);
  });
  await run('REGRESION-V02',async()=>{
    await as('company');const d=await goto('/company-dashboard','dashboard/company/');assert.deepEqual(d.metrics,seed.company_metrics);await capture('hu006-metricas-mensajes-y-accesos');
    const p=response('GET','company/applicant-offers/');await click('Gestionar postulantes');assert.equal((await(await p).json()).count,17);
    await goto('/company/offers/3/applicants','company/offers/3/applications/');await write('Experiencia','Backend');await write('Educación','Ingenieria');await write('Habilidad','Python');const filtered=response('GET','company/offers/3/applications/');await click('Aplicar filtros');assert.equal((await(await filtered).json()).count,4);await bottom();await capture('hu020-filtros-conservados');
    const b=await companyDetail(3);assert.equal(b.status,'accepted');await pdf(b,true);assert.equal(snap().principal_sources_remaining,0);await top();await capture('hu020-detalle-y-copia-sin-fuente');
  });
  await run('REGRESION-V03',async()=>{
    await as('other');const form=await goto('/offers/12/apply','offers/12/application/');assert.equal(form.application,null);await waitText('Elige el currículum');await click('Continuar');await waitText('Revisa tu postulación');const p=response('POST','offers/12/application/');await click('Confirmar postulación');const r=await p;assert.equal(r.status(),201);const b=await r.json();assert.equal(b.created,true);await waitText('Postulación registrada correctamente.');await capture('hu018-postulacion-real-sin-regresion');
    const reload=response('GET','offers/12/application/');await page.reload();await semantics();assert.equal((await(await reload).json()).application.id,b.application.id);await waitText('Postulación registrada correctamente.');assert.equal(await page.getByRole('button',{name:'Confirmar postulación',exact:true}).count(),0);await capture('hu018-recarga-sin-duplicados');
    const final=snap();assert.equal(final.new_applications,1);assert.equal(final.new_status_notices,7);assert.equal(final.new_messages,10);assert.equal(final.new_conversations,1);results.persistencia=final;
  });
};
