import {test} from 'node:test';
import assert from 'node:assert/strict';
import {paragraphsFor,resolveSemanticPlan} from './semantic-plan.mjs';
import {askGemini,validateRequest,validatePlan} from './server.mjs';
const text='A study roadmap\n\n1. Choose your tools\nUse the reference guide.\n\n2. Make a plan\nReview your progress.';
const request=validateRequest({version:2,mode:'Format',prompt:'Format the whole note consistently',text,styles:[{id:'everyday',name:'Everyday',category:'Essentials',attributes:{}},{id:'amber-brush',name:'Amber brush',category:'Highlights',attributes:{background:'#ffb52e',color:'#30240e'}},{id:'editorial',name:'Editorial',category:'Headings',attributes:{header:1}}],catalog:[{id:'star',name:'Star',kind:'doodle'}]});
const result=edits=>({summary:'Organized the note',title:'',design:'One title, consistent sections and short amber highlights.',reviewedParagraphs:paragraphsFor(text).map(p=>p.paragraphId),warnings:[],edits});
test('paragraph IDs and exact anchors resolve without model-counted offsets',()=>{
  const plan=resolveSemanticPlan(result([{kind:'paragraph',paragraphId:'p0',role:'title'},{kind:'paragraph',paragraphId:'p2',role:'section'},{kind:'style',paragraphId:'p3',quote:'reference guide',styleId:'amber-brush',color:'#FFFFFF'},{kind:'insert',paragraphId:'p5',placement:'after',blocks:[{type:'doodle',formatId:'star',text:''}]}]),request);
  assert.equal(plan.edits[2].start,text.indexOf('reference guide'));assert.equal(plan.edits[2].color,'');
  assert.equal(plan.edits[3].start,text.indexOf('Review your progress.'));assert.equal(plan.anchored,true);assert.equal(plan.changes.length,3);
  validatePlan(plan,request);
});
test('rejects missing paragraphs, unknown IDs and ambiguous repeated quotes',()=>{
  assert.throws(()=>resolveSemanticPlan({...result([]),reviewedParagraphs:['p0']},request));
  assert.throws(()=>resolveSemanticPlan(result([{kind:'style',paragraphId:'unknown',quote:'study',styleId:'everyday'}]),request));
  const repeated={...request,text:'a word and word'};assert.throws(()=>resolveSemanticPlan({...result([{kind:'style',paragraphId:'p0',quote:'word',styleId:'everyday'}]),reviewedParagraphs:['p0']},repeated));
});
test('rejects mid-word styling and phrase-level sticker insertion',()=>{
  assert.throws(()=>resolveSemanticPlan(result([{kind:'style',paragraphId:'p0',quote:'road',styleId:'everyday'}]),request));
  assert.throws(()=>resolveSemanticPlan(result([{kind:'insert',paragraphId:'p0',quote:'study',placement:'after',blocks:[]}]),request));
});
test('inline styles cannot smuggle heading roles into sentences',()=>{
  assert.throws(()=>resolveSemanticPlan(result([{kind:'style',paragraphId:'p3',quote:'reference guide',styleId:'editorial'}]),request));
  assert.throws(()=>resolveSemanticPlan(result([{kind:'paragraph',paragraphId:'p3',quote:'reference guide',role:'section'}]),request));
});
test('whole heading typography is accepted with its matching explicit role',()=>{
  const plan=resolveSemanticPlan(result([
    {kind:'paragraph',paragraphId:'p0',role:'title'},
    {kind:'style',paragraphId:'p0',styleId:'editorial'},
  ]),request);
  assert.equal(plan.edits[1].inlineOnly,true);
  assert.throws(()=>resolveSemanticPlan(result([
    {kind:'paragraph',paragraphId:'p0',role:'section'},
    {kind:'style',paragraphId:'p0',styleId:'editorial'},
  ]),request));
});
test('Format preserves words; Refine explicitly records wording changes',()=>{
  const edits=[{kind:'replace',paragraphId:'p3',quote:'reference guide',blocks:[{type:'paragraph',text:'study guide'}]}];
  assert.throws(()=>resolveSemanticPlan(result(edits),request));
  const p=resolveSemanticPlan(result(edits),{...request,mode:'Refine'});assert.deepEqual(p.changes,['1 wording changes']);
});
test('rejects overlapping edits and excessive highlights/decorations',()=>{
  assert.throws(()=>resolveSemanticPlan(result([{kind:'style',paragraphId:'p0',styleId:'everyday'},{kind:'style',paragraphId:'p0',quote:'study',styleId:'amber-brush'}]),request));
  assert.throws(()=>resolveSemanticPlan(result([{kind:'insert',paragraphId:'p0',placement:'after',blocks:Array.from({length:5},()=>({type:'doodle',formatId:'star',text:''}))}]),request));
  const long={...request,text:'word '.repeat(40)};assert.throws(()=>resolveSemanticPlan({...result([{kind:'style',paragraphId:'p0',styleId:'amber-brush'}]),reviewedParagraphs:['p0']},long));
});
test('append preserves existing content and new empty notes use p0',()=>{
  assert.throws(()=>resolveSemanticPlan(result([{kind:'paragraph',paragraphId:'p0',role:'title'}]),{...request,scope:'append'}));
  const p=resolveSemanticPlan({...result([{kind:'insert',paragraphId:'p0',placement:'after',blocks:[{type:'heading',text:'New note'}]}]),reviewedParagraphs:['p0']},{...request,text:'',scope:'new'});assert.equal(p.edits[0].start,0);
});
test('Create empty-canvas replacements normalize to insertions only in whole/new scope',()=>{
  const empty={...result([{kind:'replace',paragraphId:'p0',blocks:[{type:'paragraph',text:'A new guide'}]}]),reviewedParagraphs:['p0']};
  for(const scope of ['whole','new']){
    const p=resolveSemanticPlan(empty,{...request,text:'',mode:'Create',scope});
    assert.equal(p.edits[0].kind,'insert');assert.equal(p.edits[0].length,0);
  }
  for(const mode of ['Format','Refine'])assert.throws(()=>resolveSemanticPlan(empty,{...request,text:'',mode,scope:'whole'}));
});
test('context includes actual style properties and strips unrelated metadata',()=>{
  const parsed=validateRequest({...request,structure:[{paragraphId:'p0',line:{header:1},runs:[{text:'Title',attributes:{bold:true,secret:'omit'},mediaBytes:'omit'}]}],appearance:{dark:true,background:'#17191A',foreground:'#FFFFFF',apiKey:'omit'}});
  assert.equal(parsed.styles[1].attributes.background,'#ffb52e');assert.equal(parsed.structure[0].runs[0].attributes.secret,undefined);assert.equal(parsed.appearance.apiKey,undefined);
});
test('Gemini receives semantic schema and paragraph IDs, and app resolves its output',async()=>{
  const p=await askGemini(request,{apiKey:'test',fetchImpl:async(_,options)=>{
    const payload=JSON.parse(options.body),input=JSON.parse(payload.contents[0].parts[0].text);
    assert.equal(input.paragraphs[2].paragraphId,'p2');assert.equal(payload.generationConfig.responseJsonSchema.properties.edits.items.properties.start,undefined);
    return new Response(JSON.stringify({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(result([{kind:'paragraph',paragraphId:'p2',role:'section'}]))}]}}]}));
  }});assert.equal(p.edits[0].start,text.indexOf('1. Choose'));assert.deepEqual(p.changes,['1 paragraph roles']);
});
