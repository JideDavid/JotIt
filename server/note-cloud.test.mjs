import test from 'node:test';
import assert from 'node:assert/strict';
import {createNoteCloud,encodeSnapshot} from './note-cloud.mjs';

const user={uid:'owner',email_verified:true};
const operation=n=>String(n).padStart(43,'a');
const note=(id,body='hello')=>({id,title:id,body,timestamp:'2026-11-17T00:00:00.000Z',color:0,isLocked:true,richText:null,paper:null,media:null});
function fixture(now=()=>Date.now()) {
  const records=new Map(),blobs=new Map();let serial=Promise.resolve(),failPut=false;
  const store={async read(uid){return structuredClone(records.get(uid)??null);},transact(uid,fn){const result=serial.then(()=>{const next=fn(structuredClone(records.get(uid)??null));records.set(uid,structuredClone(next.state));return next.result;});serial=result.catch(()=>{});return result;}};
  const objects={async put(k,b){if(failPut)throw new Error('private storage error');if(!blobs.has(k))blobs.set(k,Buffer.from(b));},async get(k){return blobs.get(k);}};
  return {cloud:createNoteCloud({store,objects,now}),records,blobs,failPut:()=>{failPut=true;}};
}

test('snapshot schema includes locked notes and attachments but rejects credential fields',()=>{
  const n={...note('a'),media:'[{"bytes":"c3ludGhldGlj"}]'};
  assert.equal(JSON.parse(encodeSnapshot([n])).notes[0].isLocked,true);
  assert.throws(()=>encodeSnapshot([{...n,pin:'1234'}]),/Invalid note/);
  assert.throws(()=>encodeSnapshot([n,n]),/Invalid note/);
});
test('verified account isolation and immutable backup history',async()=>{
  const {cloud}=fixture();
  await assert.rejects(cloud.call('read',{...user,email_verified:false}),{status:403});
  assert.equal((await cloud.call('read',user)).revision,0);
  await cloud.call('write',user,{expectedRevision:0,operationId:operation(1),notes:[note('a')]});
  await cloud.call('write',user,{expectedRevision:1,operationId:operation(2),notes:[note('a','new')]});
  assert.equal((await cloud.call('read',user,{revision:1})).notes[0].body,'hello');
  assert.equal((await cloud.call('read',user)).notes[0].body,'new');
  assert.equal((await cloud.call('read',{...user,uid:'other'})).revision,0);
  assert.equal((await cloud.call('history',user)).backups.length,2);
});
test('concurrent sync commits cannot overwrite a newer revision; retries are idempotent',async()=>{
  const {cloud}=fixture();
  const request={expectedRevision:0,operationId:operation(1),notes:[note('a')]};
  const result=await Promise.allSettled([cloud.call('write',user,request),cloud.call('write',user,{...request,operationId:operation(2),notes:[note('b')]})]);
  assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(result.find(r=>r.status==='rejected').reason.status,409);
  assert.equal((await cloud.call('write',user,request)).revision,1);
  await assert.rejects(cloud.call('write',user,{...request,notes:[note('c')]}),{status:409});
});
test('failed uploads cannot advance the head and corrupted blobs cannot restore',async()=>{
  const f=fixture();f.failPut();
  await assert.rejects(f.cloud.call('write',user,{expectedRevision:0,operationId:operation(1),notes:[] }));
  assert.equal((await f.cloud.call('read',user)).revision,0);
  const g=fixture();await g.cloud.call('write',user,{expectedRevision:0,operationId:operation(1),notes:[note('a')]});
  for(const k of g.blobs.keys())g.blobs.set(k,Buffer.from('corrupt'));
  await assert.rejects(g.cloud.call('read',user),{status:503});
});
test('twenty acknowledged revisions are retained and old restores fail explicitly',async()=>{
  const {cloud}=fixture();
  for(let i=0;i<22;i++)await cloud.call('write',user,{expectedRevision:i,operationId:operation(i),notes:[note('a',String(i))]});
  assert.equal((await cloud.call('history',user)).backups.length,20);
  await assert.rejects(cloud.call('read',user,{revision:1}),{status:410});
});

test('durable account limits survive service instances and reset after an hour',async()=>{
  let time=0;
  const {cloud}=fixture(()=>time);
  for(let i=0;i<360;i++)await cloud.call('history',user);
  await assert.rejects(cloud.call('history',user),{status:429});
  time=3600000;
  assert.equal((await cloud.call('history',user)).revision,0);
  await assert.rejects(cloud.call('history',user,{note_lock_pin:'synthetic'}),{status:400});
});
