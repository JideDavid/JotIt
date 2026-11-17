import {test} from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createAssistServer,askGemini,validateRequest,validatePlan} from './server.mjs';

const request={mode:'Format',prompt:'Make it colorful',text:'My note',styles:[{id:'strong',name:'Strong'}],catalog:[{id:'star',name:'Star',kind:'doodle'}]};
const plan={summary:'Added emphasis',title:'',edits:[{kind:'style',start:0,length:7,styleId:'strong',color:'#FFBB00',blocks:[]}]};
async function withServer(options,fn){const server=createAssistServer({apiKey:'test-key',verifyToken:async t=>{if(t!=='valid')throw Error();return {uid:'user-1'};},generate:async()=>structuredClone(plan),...options});server.listen(0,'127.0.0.1');await once(server,'listening');try{await fn(`http://127.0.0.1:${server.address().port}`);}finally{server.closeAllConnections();await new Promise(r=>server.close(r));}}
const post=(url,body=request,headers={})=>fetch(`${url}/v1/assist`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer valid',...headers},body:JSON.stringify(body)});

test('authenticated requests return a validated native edit plan',async()=>withServer({},async url=>{const response=await post(url);assert.equal(response.status,200);assert.deepEqual(await response.json(),plan);assert.equal(response.headers.get('cache-control'),'no-store');}));
test('missing or invalid auth cannot consume Gemini',async()=>withServer({generate:()=>{throw Error('should not run');}},async url=>{for(const Authorization of ['', 'Bearer invalid'])assert.equal((await post(url,request,{Authorization})).status,401);}));
test('CORS accepts explicit origins only',async()=>withServer({origins:['http://localhost:7357']},async url=>{assert.equal((await post(url,request,{Origin:'https://untrusted.test'})).status,403);const r=await post(url,request,{Origin:'http://localhost:7357'});assert.equal(r.status,200);assert.equal(r.headers.get('access-control-allow-origin'),'http://localhost:7357');}));
test('per-user requests are rate limited',async()=>withServer({perMinute:1},async url=>{assert.equal((await post(url)).status,200);const r=await post(url);assert.equal(r.status,429);assert.equal(r.headers.get('retry-after'),'60');}));
test('rejects invalid input and unavailable configuration',async()=>{assert.throws(()=>validateRequest({...request,text:'a'.repeat(50001)}));assert.throws(()=>validateRequest({...request,styles:[{id:'https://evil',name:'x'}]}));await withServer({apiKey:''},async url=>{assert.equal((await post(url)).status,503);});});
test('Gemini key stays in upstream header and structured output is requested',async()=>{
  const result=await askGemini(request,{apiKey:'secret-test-value',fetchImpl:async(url,options)=>{assert.match(url,/generativelanguage.googleapis.com/);assert.equal(options.headers['x-goog-api-key'],'secret-test-value');assert.equal(options.body.includes('secret-test-value'),false);const body=JSON.parse(options.body);assert.equal(body.generationConfig.responseMimeType,'application/json');assert.ok(body.generationConfig.responseJsonSchema);return new Response(JSON.stringify({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(plan)}]}}]}),{status:200});}});assert.deepEqual(result,plan);
});
test('quota, truncation, safety and invalid native content fail without a partial result',async()=>{
  await assert.rejects(askGemini(request,{apiKey:'test',fetchImpl:async()=>new Response('',{status:429})}),{status:429});
  for(const finishReason of ['MAX_TOKENS','SAFETY'])await assert.rejects(askGemini(request,{apiKey:'test',fetchImpl:async()=>new Response(JSON.stringify({candidates:[{finishReason,content:{parts:[{text:JSON.stringify(plan)}]}}]}))}));
  assert.throws(()=>validatePlan({...plan,edits:[{...plan.edits[0],start:100}]},request));
  assert.throws(()=>validatePlan({...plan,edits:[{...plan.edits[0],styleId:'invented'}]},request));
});
test('upstream errors never reveal key or request content to the caller',async()=>withServer({generate:async()=>{throw Error('secret-test-value and private note');}},async url=>{const r=await post(url);assert.equal(r.status,502);const body=await r.text();assert.equal(body.includes('secret-test-value'),false);assert.equal(body.includes('private note'),false);}));
