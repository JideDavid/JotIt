import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRecoveryServer} from './recovery-server.mjs';
async function fixture(t) {
  let calls=0;
  const server=createRecoveryServer({recovery:{call:async()=>{calls++;return {enabled:true};}},
    verifyToken:async token=>{if(token!=='valid')throw new Error('private-token');return {uid:'owner'};},
    verifyAppCheck:async token=>({appId:token==='allowed'?'android-app':'wrong-app'}),allowedAppIds:['android-app']});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>{server.close(resolve);server.closeAllConnections();}));
  const url=`http://127.0.0.1:${server.address().port}`;
  return {url,get calls(){return calls;},post:headers=>fetch(url+'/v1/recovery/request',{method:'POST',headers:{'Content-Type':'application/json',...headers},body:'{}'})};
}
test('HTTP recovery requires Firebase authentication and an allowed attested app',async t=>{
  const s=await fixture(t);
  for(const headers of [{},{Authorization:'Bearer invalid','X-Firebase-AppCheck':'allowed'},{Authorization:'Bearer valid'},{Authorization:'Bearer valid','X-Firebase-AppCheck':'wrong'}]){
    const r=await s.post(headers);assert.equal(r.status,401);assert.ok(!(await r.text()).includes('private-token'));
  }
  assert.equal(s.calls,0);
  assert.equal((await s.post({Authorization:'Bearer valid','X-Firebase-AppCheck':'allowed'})).status,200);
  assert.equal(s.calls,1);
});
test('landing page is inert and never consumes a reset link; origins and GET actions are rejected',async t=>{
  const s=await fixture(t);
  const page=await fetch(s.url+'/recover');
  assert.equal(page.status,200);assert.equal(page.headers.get('Referrer-Policy'),'no-referrer');
  assert.ok(page.headers.get('Content-Security-Policy').includes("default-src 'none'"));
  assert.equal((await fetch(s.url+'/v1/recovery/redeem')).status,404);
  assert.equal((await s.post({Origin:'https://unknown.example'})).status,403);
  assert.equal(s.calls,0);
});
