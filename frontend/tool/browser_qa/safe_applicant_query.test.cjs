const {test}=require('node:test');const assert=require('node:assert/strict');
const allowed=require('./safe_applicant_query.cjs');
const check=q=>allowed(new URL('http://127.0.0.1/company/offers/3/applicants'+q));
test('permite solo filtros públicos y páginas del recorrido',()=>assert.equal(check('?page=2&page_size=10&order=name&skill=Python&education=Ingenier%C3%ADa'),true));
test('rechaza credenciales y parámetros ajenos o repetidos',()=>{for(const q of ['?token=privado','?skill=x&skill=y','?company=1','?nonce=x'])assert.equal(check(q),false);});
test('rechaza límites, controles y orden inválido',()=>{for(const q of ['?page=0','?page_size=500','?order=bad','?skill=%0Atoken','?skill='+'x'.repeat(101)])assert.equal(check(q),false);});
test('no habilita otras rutas para capturas con query',()=>assert.equal(allowed(new URL('http://127.0.0.1/login?skill=x')),false));
