import test from 'node:test';
import assert from 'node:assert/strict';
import {createCloudServer} from './cloud-server.mjs';

test('HTTP boundary requires authentication, approved App Check and explicit web origins',async()=>{
  let calls=0;
  const server=createCloudServer({cloud:{async call(action,user){calls++;return {revision:0,action,uid:user.uid};}},
    verifyToken:async token=>{if(token!=='synthetic-id')throw new Error('private token error');return {uid:'owner',email_verified:true};},
    verifyAppCheck:async token=>({appId:token==='synthetic-app'?'approved':'other'}),allowedAppIds:['approved'],origins:['https://jotit.test']});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const headers={'Content-Type':'application/json','Authorization':'Bearer synthetic-id','X-Firebase-AppCheck':'synthetic-app'};
  try {
    assert.equal((await fetch(`${base}/v1/cloud/history`,{method:'POST',body:'{}'})).status,401);
    assert.equal((await fetch(`${base}/v1/cloud/history`,{method:'POST',headers:{...headers,'X-Firebase-AppCheck':'wrong'},body:'{}'})).status,401);
    assert.equal((await fetch(`${base}/v1/cloud/history`,{method:'POST',headers:{...headers,Origin:'https://evil.test'},body:'{}'})).status,403);
    assert.equal(calls,0);
    const ok=await fetch(`${base}/v1/cloud/history`,{method:'POST',headers,body:'{}'});
    assert.equal(ok.status,200);assert.equal(ok.headers.get('cache-control'),'no-store');assert.equal((await ok.json()).uid,'owner');
    assert.equal((await fetch(`${base}/v1/cloud/write`)).status,404);
    assert.equal((await fetch(`${base}/v1/cloud/history`,{method:'POST',headers,body:'invalid'})).status,400);
    assert.equal((await fetch(`${base}/v1/cloud/read`,{method:'POST',headers,body:JSON.stringify({x:'x'.repeat(2100)})})).status,413);
  } finally {await new Promise(resolve=>server.close(resolve));}
});

test('internal cloud failures never leak note contents or infrastructure diagnostics',async()=>{
  const server=createCloudServer({cloud:{async call(){throw new Error('private note and secret diagnostics');}},
    verifyToken:async()=>({uid:'owner'}),verifyAppCheck:async()=>({appId:'approved'}),allowedAppIds:['approved']});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try {
    const response=await fetch(`http://127.0.0.1:${server.address().port}/v1/cloud/read`,{method:'POST',headers:{Authorization:'Bearer synthetic','Content-Type':'application/json'},body:'{}'});
    assert.equal(response.status,503);assert.doesNotMatch(await response.text(),/private|secret|diagnostics/);
  } finally {await new Promise(resolve=>server.close(resolve));}
});
