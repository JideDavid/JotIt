import test from 'node:test';
import assert from 'node:assert/strict';
import {Readable} from 'node:stream';
import {createR2Objects} from './r2-cloud-objects.mjs';

const path=`${'a'.repeat(64)}/${'b'.repeat(64)}.json`;
const config={accountId:'a'.repeat(32),accessKeyId:'synthetic-access',secretAccessKey:'synthetic-secret',bucket:'jotit-private'};

test('R2 uses private content-addressed objects and conditional writes without public ACLs',async()=>{
  const requests=[];
  const objects=createR2Objects({...config,client:{async send(command){requests.push(command);if(command.constructor.name==='GetObjectCommand')return {Body:Readable.from([Buffer.from('synthetic')]),ContentLength:9};}}});
  await objects.put(path,Buffer.from('synthetic'));
  assert.equal((await objects.get(path)).toString(),'synthetic');
  assert.equal(requests[0].input.IfNoneMatch,'*');
  assert.equal(requests[0].input.Bucket,'jotit-private');
  assert.equal(requests[0].input.Key,`jotit-note-cloud/${path}`);
  assert.equal(requests[0].input.ACL,undefined);
  assert.equal(requests[0].input.CacheControl,'private, no-store');
  await assert.rejects(objects.get('../other-account'),/Invalid cloud object path/);
});

test('R2 duplicates are accepted but authentication and quota failures propagate',async()=>{
  let status=412;
  const objects=createR2Objects({...config,client:{async send(){throw {$metadata:{httpStatusCode:status}};}}});
  await objects.put(path,Buffer.from('synthetic'));
  status=403;await assert.rejects(objects.put(path,Buffer.from('synthetic')));
  status=429;await assert.rejects(objects.put(path,Buffer.from('synthetic')));
  assert.throws(()=>createR2Objects({...config,accountId:'https://wrong-host.invalid'}),/R2 configuration/);
});

test('R2 rejects oversized response metadata without buffering object content',async()=>{
  const objects=createR2Objects({...config,client:{async send(){return {Body:Readable.from([]),ContentLength:65*1024*1024};}}});
  await assert.rejects(objects.get(path),/Invalid cloud object/);
});
