'use strict';
// New browser context and a newly prepared HU028 QA only. Never reads a provider key.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {createHash}=require('node:crypto');
const {spawnSync}=require('node:child_process');
const {createRequire}=require('node:module');

async function main(){
  const args=process.argv.slice(2),repo=path.resolve(args[0]||''),run=path.resolve(args[1]||'');
  const real=args.includes('--real');
  const g=spawnSync('git',['-C',repo,'rev-parse','--path-format=absolute','--git-common-dir'],{encoding:'utf8'});
  assert.equal(g.status,0);const allowed=path.join(g.stdout.trim(),'hu028-qa');
  assert.equal(path.dirname(run).toLowerCase(),allowed.toLowerCase());
  const marker=JSON.parse(fs.readFileSync(path.join(run,'marker.json'),'utf8'));
  assert.equal(marker.suite,'hu028');assert.equal(marker.provider,real?'hu028-isolated-real':'hu028-isolated-double');
  const seed=JSON.parse(fs.readFileSync(path.join(run,'private.json'),'utf8'));
  const api=`http://127.0.0.1:${seed.api_port}`,web=`http://127.0.0.1:${seed.web_port}`;
  const out=path.join(run,'artifacts',real?'browser-real':'browser-without-provider');fs.mkdirSync(out,{recursive:false});
  for(const url of [web+'/',api+'/api/curriculum/generated/assistant/']){
    const r=await fetch(url);assert.equal(r.headers.get('x-worknet-qa-run'),path.basename(run));
  }
  const requireQa=createRequire(path.join(repo,'frontend/tool/browser_qa/package.json'));
  const {chromium}=requireQa('playwright');
  const result={date_utc:new Date().toISOString(),run:path.basename(run),source_sha:spawnSync('git',['-C',repo,'rev-parse','HEAD'],{encoding:'utf8'}).stdout.trim(),browser_script_sha256:createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),platform:process.platform,playwright:requireQa('playwright/package.json').version,provider_real_mode:real,provider_generations_accepted:0,cases:[],screenshots:[],downloads:[],network:[],controlled_faults:[],personal_browser_profile:false,har_trace_storageState:false};
  let browser,context,page,authenticating=false,active='HU028-V00',phase='start',violations=0,token,latest;
  const save=()=>fs.writeFileSync(path.join(out,'resultados.json'),JSON.stringify(result,null,2));
  const mode=value=>fs.writeFileSync(path.join(run,'mode.json'),JSON.stringify({mode:value}));
  const response=(method,suffix)=>page.waitForResponse(r=>r.request().method()===method&&r.url()===api+'/api/'+suffix,{timeout:30000});
  const click=async(name,role='button')=>{phase='control '+role+': '+String(name);const b=page.getByRole(role,{name,exact:typeof name==='string'});await b.scrollIntoViewIfNeeded();await page.waitForTimeout(300);await b.click();};
  const write=async(name,value)=>{const f=page.getByRole('textbox',{name,exact:true});await f.focus();await page.waitForTimeout(220);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.press('Backspace');if(value)await page.keyboard.insertText(value);};
  const read=async name=>{const f=page.getByRole('textbox',{name,exact:true});await f.focus();await page.waitForTimeout(150);return f.inputValue();};
  const check=async(name,value=true)=>{const c=page.getByRole('checkbox',{name,exact:true});await c.scrollIntoViewIfNeeded();await c.focus();if(await c.isChecked()!==value)await page.keyboard.press('Space');};
  const text=async s=>{for(let n=0;n<80;n++){if((await page.locator('body').ariaSnapshot()).includes(s))return;await page.waitForTimeout(100);}throw Error('Expected UI text not ready: '+s);};
  const top=async()=>{await page.mouse.move(200,200);await page.mouse.wheel(0,-25000);await page.waitForTimeout(250);};
  const capture=async suffix=>{
    assert.equal(authenticating,false);assert.equal(new URL(page.url()).search,'');assert.equal(violations,0);
    const password=page.getByRole('textbox',{name:'Contraseña',exact:true});if(await password.count())assert.equal(await password.inputValue(),'');
    const visible=await page.locator('body').ariaSnapshot();assert.equal(/AIza[\w-]{20,}|\b[a-f0-9]{40}\b/.test(visible),false);
    await page.waitForTimeout(400);const name=active+'-'+suffix+'.png',b=await page.screenshot({path:path.join(out,name)});
    result.screenshots.push({file:name,case:active,viewport:page.viewportSize(),sha256:createHash('sha256').update(b).digest('hex')});
  };
  const test=async(id,fn)=>{active=id;const start=Date.now();try{await fn();assert.equal(violations,0);result.cases.push({id,passed:true,elapsed_ms:Date.now()-start});save();console.log(id+' PASS');}catch(e){result.cases.push({id,passed:false,type:e.name,phase,network_violations:violations,...(typeof e.actual==='number'&&typeof e.expected==='number'?{actual:e.actual,expected:e.expected}:{})});if(!authenticating&&violations===0){fs.writeFileSync(path.join(run,'browser-diagnostic.private.txt'),String(e.message)+'\n'+await page.locator('body').ariaSnapshot());try{await capture('fallo-no-aceptado');}catch{}}save();throw Error('Browser acceptance failed at '+id);}};
  const own=async(suffix='curriculum/generated/')=>{const r=await fetch(api+'/api/'+suffix,{headers:{Authorization:'Token '+token}});assert.equal(r.status,200);return r.json();};
  const persisted=async()=>JSON.stringify(await own());
  const open=async()=>{await top();const p=response('GET','curriculum/generated/assistant/');await click('Completar mi CV con IA');assert.equal((await p).status(),200);await text('Completar mi CV con IA');};
  const bio='Candidata HU028 QA. Ingeniera de Software de Universidad QA. Desarrolladora en Equipo QA. Python avanzado. Español nativo.';
  const consent='Autorizo este envío para preparar mi CV.';
  const reviewed='He revisado la propuesta y quiero llevarla al editor.';
  const fill=async(profile=false)=>{await write('Mi información profesional',bio);if(profile)await check('Incluir los datos de mi perfil de WorkNet y mi nombre y correo de cuenta.');await check(consent);};
  const generate=async(profile=false)=>{
    await fill(profile);const p=response('POST','curriculum/generated/assistant/');await click('Generar propuesta');const r=await p;assert.equal(r.status(),200);
    const body=await r.json();assert.equal(body.provider,'Gemini');assert.equal(body.saved,false);assert.ok(body.model);assert.ok(body.suggestion.missing_information.length);
    assert.equal(JSON.stringify(body).includes('PERFIL_AJENO_NO_COMPARTIR'),false);
    latest=body;result.provider_generations_accepted++;fs.writeFileSync(path.join(out,active+'-respuesta-real.json'),JSON.stringify(body,null,2));await text('Información por completar');return body;
  };
  const select=async name=>{await top();phase='template: '+name;await page.getByRole('button',{name:/^Tu currículum, a tu manera/}).focus();await page.waitForTimeout(250);await page.keyboard.press('Enter');await click(name,'menuitem');};
  const saveCv=async()=>{const p=response('PUT','curriculum/generated/');await click('Guardar CV');const r=await p;assert.ok([200,201].includes(r.status()));return r.json();};
  try{
    browser=await chromium.launch({headless:true});result.chromium=browser.version();
    context=await browser.newContext({viewport:{width:1440,height:1000},acceptDownloads:true,serviceWorkers:'block'});
    await context.route('**/*',async route=>{
      const u=new URL(route.request().url());if(![api,web].includes(u.origin)&&!['blob:','data:','about:'].includes(u.protocol)){violations++;return route.abort('blockedbyclient');}
      assert.equal(Object.keys(route.request().headers()).some(k=>k.toLowerCase()==='x-goog-api-key'),false);await route.continue();
    });
    page=await context.newPage();page.setDefaultTimeout(15000);
    page.on('response',r=>{const u=new URL(r.url());if(u.origin===api)result.network.push({method:r.request().method(),path:u.pathname,status:r.status(),case:active});});
    await page.goto(web+'/login');await page.waitForTimeout(1000);const a=page.getByRole('button',{name:'Enable accessibility',exact:true});if(await a.count()){await a.focus();await page.keyboard.press('Enter');}
    authenticating=true;await write('Correo electrónico',seed.email);await write('Contraseña',seed.password);const login=response('POST','login/');await click('Iniciar sesión');const lr=await login;assert.equal(lr.status(),200);token=(await lr.json()).token;await page.waitForURL(web+'/dashboard');authenticating=false;
    await test('HU028-V01',async()=>{
      await click('Mi currículum');await page.waitForURL(web+'/curriculum');await text('Usa la información de tu perfil');await click('Crear mi CV');await page.waitForURL(web+'/curriculum/create');await text('Completar mi CV con IA');await select('Moderna');
      await write('Correo electrónico','cv.hu028@example.test');await write('Teléfono (opcional)','0000000000');await write('Perfil profesional','Resumen manual HU028 QA.');await saveCv();await top();await capture('editor-manual-plantilla-contactos');
    });
    let before=await persisted();
    await test('HU028-V02',async()=>{mode('unconfigured');await open();await text('El asistente está pendiente de configuración.');await capture('sin-configuracion-edicion-manual-disponible');await click('Cancelar');assert.equal(await read('Perfil profesional'),'Resumen manual HU028 QA.');assert.equal(await persisted(),before);});
    if(!real){await test('HU028-V02M',async()=>{await page.setViewportSize({width:390,height:844});await open();await text('El asistente está pendiente de configuración.');await capture('movil-sin-configuracion-cancelacion');await click('Cancelar');assert.equal(await persisted(),before);});result.scope='Desktop/mobile browser UI with unavailable provider only; no generation or Gemini calls.';save();return;}
    mode('real');
    await test('HU028-V03',async()=>{await open();assert.equal(await page.getByRole('button',{name:'Generar propuesta',exact:true}).isDisabled(),true);await write('Mi información profesional',bio);await check(consent);await capture('texto-consentimiento-perfil-optativo');await click('Cancelar');assert.equal(await persisted(),before);});
    await test('HU028-V04',async()=>{await open();await generate();assert.equal(await persisted(),before);assert.equal(await page.getByRole('button',{name:'Aplicar al borrador',exact:true}).isDisabled(),true);await capture('propuesta-real-faltantes-revision-obligatoria');await check(reviewed);await click('Aplicar al borrador');assert.equal(await persisted(),before);assert.equal(await read('Correo electrónico'),'cv.hu028@example.test');assert.equal(await read('Teléfono (opcional)'),'0000000000');await top();await capture('aplicada-sin-guardar-conserva-plantilla');});
    await test('HU028-V05',async()=>{await write('Perfil profesional','Resumen revisado y editado HU028 QA. '+latest.suggestion.data.professional_summary);await saveCv();before=await persisted();assert.equal((await own()).curriculum.template,'moderna');await top();await capture('edicion-y-guardado-expresos');});
    for(const [template,label]of [['clasica','Clásica'],['moderna','Moderna'],['minimalista','Minimalista']]){
      await test('HU028-PDF-'+template,async()=>{
        await select(label);const previous=await persisted();const p=response('POST','curriculum/generated/preview/');await click('Vista previa');const preview=await p;assert.equal(preview.status(),200);assert.equal((await preview.body()).subarray(0,5).toString(),'%PDF-');assert.equal(await persisted(),previous);await text('Página 1');await capture('vista-previa-pdf-'+template);await click('Cerrar vista previa');
        await saveCv();const pending=page.waitForEvent('download');const req=response('GET','curriculum/generated/pdf/');await click('Descargar PDF guardado');assert.equal((await req).status(),200);const d=await pending;const file='HU028-CV-'+template+'-generacion-real.pdf';await d.saveAs(path.join(out,file));const b=fs.readFileSync(path.join(out,file));assert.equal(b.subarray(0,5).toString(),'%PDF-');result.downloads.push({file,template,bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')});await capture('descarga-real-'+template);
      });
    }
    before=await persisted();
    await test('HU028-V06',async()=>{await page.setViewportSize({width:390,height:844});await open();await fill(true);await capture('movil-consentimiento-perfil-propio');const p=response('POST','curriculum/generated/assistant/');await click('Generar propuesta');const r=await p;assert.equal(r.status(),200);const b=await r.json();assert.equal(b.saved,false);assert.equal(b.provider,'Gemini');assert.equal(b.suggestion.data.personal.email,seed.email);assert.equal(JSON.stringify(b).includes('PERFIL_AJENO_NO_COMPARTIR'),false);result.provider_generations_accepted++;await text('Información por completar');await capture('movil-propuesta-real-y-descarte');await click('Descartar propuesta');assert.equal(await persisted(),before);await top();await capture('movil-descartada-cv-previo-intacto');});
    await test('HU028-V07',async()=>{
      await page.setViewportSize({width:1440,height:1000});await open();await fill();const pattern=api+'/api/curriculum/generated/assistant/';
      await page.route(pattern,async route=>{if(route.request().method()==='POST'){await new Promise(r=>setTimeout(r,900));await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(latest)});}else await route.fallback();});
      await click('Generar propuesta');await click('Cancelar');await page.waitForTimeout(1300);assert.equal(await persisted(),before);await page.unroute(pattern);result.controlled_faults.push('V07 delayed locally replayed response; no provider request');await top();await capture('cancelacion-respuesta-tardia-controlada');
    });
    for(const status of [503,429])await test('HU028-E'+status,async()=>{
      await open();await fill();const pattern=api+'/api/curriculum/generated/assistant/';await page.route(pattern,async route=>route.request().method()==='POST'?route.fulfill({status,contentType:'application/json',body:JSON.stringify({message:'Fallo QA identificado; tu edición se conserva.'})}):route.fallback());
      await click('Generar propuesta');await text('Fallo QA identificado');await capture('error-'+status+'-inyectado-identificado');await page.unroute(pattern);await click('Volver a comprobar');await text('Mi información profesional');await click('Cancelar');assert.equal(await persisted(),before);result.controlled_faults.push('E'+status+' local browser route, not an actual provider outage/quota');
    });
    await test('HU028-V08',async()=>{const r=await fetch(api+'/api/curriculum/generated/pdf/',{headers:{Authorization:'Token '+seed.tokens.other}});assert.equal(r.status,404);result.other_candidate_pdf_http=404;await capture('aislamiento-contraste-api-separado');});
    await test('HU028-V09',async()=>{const r=await fetch(api+'/api/logout/',{method:'POST',headers:{Authorization:'Token '+token}});assert.equal(r.status,200);await top();await click('Completar mi CV con IA');await page.waitForURL(web+'/login');await capture('sesion-revocada-sin-propuesta-privada');});
    result.scope='Two actual Gemini generations in a fresh QA; desktop apply/edit/explicit save and three PDF previews/downloads; mobile own-profile generation and discard. Cancellation/error routes are controlled and separately identified. No real-person data or physical-device claim.';
    save();
  }finally{save();if(context)await context.close();if(browser)await browser.close();}
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
