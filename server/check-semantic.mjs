import {writeFile} from 'node:fs/promises';
import {askGemini,validateRequest} from './server.mjs';
const text=['A practical learning roadmap','Use a sustainable pace and review what you learn.','',...Array.from({length:14},(_,i)=>[`${i+1}. Learning topic ${i+1}`,'Practice a small example.','Resources:','Reference guide','Practice workbook','']).flat()].join('\n').trim();
const request=validateRequest({version:2,mode:'Format',scope:'whole',prompt:'Format this entire learning roadmap consistently. Keep every word. Make all fourteen numbered section titles native section headings, keep body paragraphs readable, make resources native bullet lists, highlight at most two short key phrases, and add one star doodle at a section boundary. Do not format book/resource titles as headings.',text,appearance:{dark:true,background:'#17191A',foreground:'#F3F0E8'},styles:[{id:'everyday',name:'Everyday',category:'Essentials',attributes:{}},{id:'strong',name:'Strong',category:'Essentials',attributes:{bold:true,size:'20'}},{id:'amber-brush',name:'Amber brush',category:'Highlights',attributes:{bold:true,italic:true,background:'#ffb52e',color:'#30240e'}},{id:'lemon-marker',name:'Lemon marker',category:'Highlights',attributes:{background:'#f6df62',color:'#30240e'}}],catalog:[{id:'star',name:'Star',kind:'doodle'}]});
try{
  const plan=await askGemini(request,{apiKey:process.env.GEMINI_API_KEY,model:process.env.GEMINI_MODEL});
  const sections=plan.edits.filter(e=>e.kind==='paragraph'&&e.role==='section').length;
  console.log(JSON.stringify({success:true,sections,operations:plan.edits.length,changes:plan.changes,warnings:plan.warnings.length}));
  if(sections!==14)throw Error('Incomplete section formatting');
  await writeFile(new URL('../test/gemini_semantic_plan.fixture.json',import.meta.url),JSON.stringify({text,plan},null,2));
}catch(error){console.log(JSON.stringify({success:false,status:error.status||502,reason:error.message?.replaceAll(process.env.GEMINI_API_KEY||'never-match','[redacted]')}));process.exitCode=1;}
