'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),safe=require('./safe_message_query.cjs');
test('captures only the message list and bounded literal search/page',()=>{
  assert.equal(safe(new URL('http://127.0.0.1/messages?q=Candidato&page=2')),true);
  assert.equal(safe(new URL('http://127.0.0.1/messages?q=QA%20%26%20oferta')),true);
});
test('rejects foreign paths, repeated/unknown fields and unbounded/control values',()=>{
  for(const path of ['/messages/1?q=QA','/login?q=QA','/messages?token=private','/messages?q=a&q=b','/messages?page=0','/messages?page=-1','/messages?q=%00','/messages?q='+'x'.repeat(101)])assert.equal(safe(new URL('http://127.0.0.1'+path)),false);
});
