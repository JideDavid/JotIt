import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {createNotePinRecovery,resendRecoveryMailer} from './note-pin-recovery.mjs';
const id=()=>randomBytes(32).toString('base64url');
function setup({sendFails=false}={}) {
  let time=1800000000000;
  const records=new Map(),mail=[];
  let queue=Promise.resolve();
  const store={transact:(key,update)=>{
    const run=queue.then(()=>{const {record,result}=update(structuredClone(records.get(key)??null));if(record)records.set(key,structuredClone(record));return result;});
    queue=run.catch(()=>{});return run;
  }};
  const recovery=createNotePinRecovery({store,resetUrl:'https://recovery.example.test/recover',now:()=>time,
    sendMail:async m=>{if(sendFails)throw new Error('private-provider-response');mail.push(m);}});
  const user={uid:'owner',email:'owner@example.test',email_verified:true,auth_time:time/1000};
  const binding={installationId:id(),deviceSecret:id(),epoch:id()};
  const call=(action,body={},identity=user)=>recovery.call(action,identity,{...binding,...body});
  const token=()=>new URL(mail.findLast(m=>m.kind==='reset').link).hash.slice('#token='.length);
  const resetBody=()=>({token:token(),resetId:id(),newEpoch:id(),fingerprint:'a'.repeat(64)});
  return {records,mail,user,binding,call,token,resetBody,advance:n=>time+=n};
}
test('only a verified recent account can enroll; an existing installation cannot be taken over',async()=>{
  const s=setup();
  await assert.rejects(s.call('enroll',{}, {...s.user,email_verified:false}),{status:401});
  await assert.rejects(s.call('enroll',{}, {...s.user,auth_time:s.user.auth_time-301}),{status:401});
  await s.call('enroll');
  await assert.rejects(s.call('enroll',{}, {...s.user,uid:'other'}),{status:403});
  await assert.rejects(s.call('enroll',{deviceSecret:id()}),{status:403});
});
test('link is short-lived and sent only to the enrolled verified email; secrets are hashed at rest',async()=>{
  const s=setup();await s.call('enroll');
  await s.call('request',{email:'attacker@example.test'});
  assert.equal(s.mail[0].to,s.user.email);
  const stored=JSON.stringify([...s.records]);
  assert.ok(!stored.includes(s.token()));assert.ok(!stored.includes(s.binding.deviceSecret));
  await assert.rejects(s.call('request'),{status:429});
  s.advance(900001);
  await assert.rejects(s.call('redeem',s.resetBody()),{status:400});
});
test('email updates require the enrolled UID/device and a fresh verified identity; old links stop working',async()=>{
  const s=setup();await s.call('enroll');await s.call('request');const old=s.resetBody();
  const updated={...s.user,email:'new-owner@example.test'};
  await s.call('enroll',{},updated);
  await assert.rejects(s.call('redeem',old),{status:403});
  await s.call('request',{},updated);assert.equal(s.mail.at(-1).to,updated.email);
});
test('wrong account, email, installation and device secret cannot redeem',async()=>{
  const s=setup();await s.call('enroll');await s.call('request');const reset=s.resetBody();
  for(const [body,user] of [[{}, {...s.user,uid:'other'}],[{}, {...s.user,email:'other@example.test'}],[{installationId:id()},s.user],[{deviceSecret:id()},s.user]]) {
    await assert.rejects(s.call('redeem',{...reset,...body},user),{status:403});
  }
  assert.equal((await s.call('redeem',reset)).resetId,reset.resetId);
});
test('a token authorizes one operation and only its identical idempotent retry',async()=>{
  const s=setup();await s.call('enroll');await s.call('request');const reset=s.resetBody();
  const first=await s.call('redeem',reset);
  assert.deepEqual(await s.call('redeem',reset),first);
  await assert.rejects(s.call('redeem',{...reset,resetId:id()}),{status:403});
  await assert.rejects(s.call('redeem',{...reset,fingerprint:'b'.repeat(64)}),{status:403});
  assert.equal(s.mail.filter(m=>m.kind==='notice').length,1);
});
test('concurrent different resets cannot both consume the same link',async()=>{
  const s=setup();await s.call('enroll');await s.call('request');
  const results=await Promise.allSettled([s.call('redeem',s.resetBody()),s.call('redeem',s.resetBody())]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
});
test('five invalid token attempts lock out the challenge',async()=>{
  const s=setup();await s.call('enroll');await s.call('request');const reset=s.resetBody();
  for(let n=0;n<5;n++)await assert.rejects(s.call('redeem',{...reset,token:id()}),{status:400});
  await assert.rejects(s.call('redeem',reset),{status:400});
});
test('resending supersedes old links and disabling invalidates outstanding links',async()=>{
  const s=setup();await s.call('enroll');await s.call('request');const old=s.resetBody();
  s.advance(60001);await s.call('request');
  await assert.rejects(s.call('redeem',old),{status:400});
  await s.call('disable');
  assert.equal((await s.call('status')).enabled,false);
  await assert.rejects(s.call('redeem',s.resetBody()),{status:403});
});
test('provider failure does not leave a usable challenge or leak provider text',async()=>{
  const s=setup({sendFails:true});await s.call('enroll');
  await assert.rejects(s.call('request'),e=>e.status===503&&!e.message.includes('private-provider'));
  assert.equal(s.records.get(`i_${s.binding.installationId}`).challenge,null);
});
test('durable per-account limits apply across installations',async()=>{
  const s=setup();await s.call('enroll');
  for(let n=0;n<29;n++)await s.call('status');
  await assert.rejects(s.call('enroll',{installationId:id()}),{status:429});
});
test('email adapter uses server-held credentials and idempotency without PIN content',async()=>{
  let request;
  const send=resendRecoveryMailer({apiKey:'server-only-secret',from:'JotIt <security@example.test>',fetchImpl:async(url,options)=>{request={url,...options};return {ok:true};}});
  await send({to:'owner@example.test',kind:'notice',id:'notice-one'});
  assert.equal(request.headers['Idempotency-Key'],'notice-one');
  assert.equal(request.headers.Authorization,'Bearer server-only-secret');
  assert.ok(!request.body.includes('server-only-secret'));assert.ok(!request.body.includes('2468'));
});
