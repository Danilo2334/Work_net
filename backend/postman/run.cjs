/* Newman ejecuta la MISMA colección importable. Solo lee los correos locales entre fases. */
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const newman = require('newman');
const here = __dirname;
const runName = process.argv[2] || fs.readFileSync(path.join(here,'.local/latest.txt'),'utf8').trim();
if (!/^run-[a-zA-Z0-9-]+$/.test(runName)) throw Error('Run QA inválido');
const runPath = path.join(here,'.local',runName);
const envPath = path.join(runPath,'local.postman_environment.json');
const state = JSON.parse(fs.readFileSync(path.join(runPath,'state.json'),'utf8'));
if(state.qa_marker !== 'WORKNET_POSTMAN_AISLADO' || path.resolve(state.database) !== path.join(runPath,'qa.sqlite3')) throw Error('Base no aislada');
const localValues=Object.fromEntries(JSON.parse(fs.readFileSync(envPath,'utf8')).values.map(v=>[v.key,v.value]));
if(localValues.base_url!==`http://127.0.0.1:${state.port}/api` || localValues.qa_run_id!==runName || localValues.qa_confirmation!=='SOLO_BASE_AISLADA') throw Error('El entorno no coincide con la base y el puerto de este run');
const collectionFile = path.join(here,'WorkNet.postman_collection.json');
const collection = JSON.parse(fs.readFileSync(collectionFile,'utf8'));
const catalog = JSON.parse(fs.readFileSync(path.join(here,'casos.json'),'utf8'));
const report = {fecha:new Date().toISOString(), runner:'Newman '+require('newman/package.json').version,
  interfaz_postman:false, servidor:'Django HTTP real; SQLite exclusiva de este run; MAILERS filebased',
  correo:'Capturado en archivos locales; esta ejecución no prueba entrega SMTP ni recepción en buzón',
  run:runName, coleccion_sha256:crypto.createHash('sha256').update(fs.readFileSync(collectionFile)).digest('hex'),
  casos:[], errores_ejecucion:[]};
const output = path.join(runPath,'resultado-sanitizado.json');
let ownsReport=false;
function writeReport(){
  report.resumen={peticiones:report.casos.length, aprobadas:report.casos.filter(c=>c.resultado==='aprobado').length,
    fallidas:report.casos.filter(c=>c.resultado!=='aprobado').length,
    comprobaciones:report.casos.reduce((n,c)=>n+c.comprobaciones.length,0),
    comprobaciones_fallidas:report.casos.reduce((n,c)=>n+c.comprobaciones.filter(a=>!a.aprobada).length,0)};
  fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
}
function mail(kind){
  const r=cp.spawnSync(process.env.QA_PYTHON || 'python',['-X','utf8',path.join(here,'qa.py'),'mail',kind,'--run',runName],{encoding:'utf8'});
  if(r.status!==0) throw Error('No se pudo leer el correo capturado: '+kind+'. Revisa qa.py mail localmente.');
}
async function execute(folder){
  return new Promise((resolve,reject)=>{
    newman.run({collection,environment:JSON.parse(fs.readFileSync(envPath,'utf8')),folder:folder.name,
      workingDir:here,insecureFileRead:false,timeoutRequest:20000,timeoutScript:10000,
      reporters:['json'],reporter:{json:{export:path.join(runPath,'privado-'+folder.name.slice(0,2)+'.json')}}},(error,summary)=>{
      if(error){ report.errores_ejecucion.push({fase:folder.name,tipo:error.name || 'Error'}); writeReport(); return reject(Error('Error de ejecución; informe privado disponible.')); }
      fs.writeFileSync(envPath,JSON.stringify(summary.environment.toJSON(),null,2)+'\n');
      for(const execution of summary.run.executions){
        const id=execution.item.name.split(' ')[0];
        const spec=catalog.find(c=>c.id===id);
        const assertions=(execution.assertions||[]).map(a=>({nombre:a.assertion,aprobada:!a.error&&!a.skipped}));
        const actual=execution.response && execution.response.code;
        const okay=actual===Number(spec.esperado.match(/HTTP (\d+)/)[1]) && assertions.length>0 && assertions.every(a=>a.aprobada);
        report.casos.push({id,tarea:spec.tarea,objetivo:spec.objetivo,fase:folder.name,metodo:spec.metodo,
          ruta:spec.ruta.split('?')[0],esperado:spec.esperado,http_obtenido:actual||null,
          comprobaciones:assertions,resultado:okay?'aprobado':'fallido'});
      }
      if(summary.run.failures.length) report.errores_ejecucion.push({fase:folder.name,fallos:summary.run.failures.map(f=>({tipo:f.error.name,caso:f.source && f.source.name}))});
      writeReport();
      const bad=report.casos.filter(c=>c.fase===folder.name&&c.resultado!=='aprobado');
      console.log(folder.name+': '+summary.run.executions.length+' peticiones; '+bad.length+' fallos.');
      if(summary.run.failures.length||bad.length) return reject(Error('Falló la fase. No se ejecutarán las siguientes; conserva el resultado y prepara un run nuevo después de corregir la causa.'));
      resolve();
    });
  });
}
(async()=>{
  if(fs.existsSync(output)) throw Error('Este run ya tiene un resultado. Usa qa.py prepare para repetir desde cero sin sobrescribir evidencia.');
  ownsReport=true;
  for(let i=0;i<collection.item.length;i++){
    await execute(collection.item[i]);
    if(i===0)mail('verification');
    if(i===2)mail('recovery');
  }
  if(report.casos.length!==catalog.length)throw Error('No se ejecutaron todos los casos.');
  report.finalizado=new Date().toISOString();writeReport();
  console.log(JSON.stringify(report.resumen));
  console.log('Resultado sin secretos: '+output);
})().catch(error=>{if(ownsReport)writeReport();console.error(error.message);process.exitCode=1;});
