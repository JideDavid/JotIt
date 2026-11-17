// An explicit live smoke check. Uses synthetic notes and never prints the key.
import {askGemini} from './server.mjs';
const request={mode:'Create',prompt:'Create a short YouTube tutorial posting checklist. Include a section heading, exactly two native checklist steps, one pinned-paper reminder sticker and one star doodle. Insert everything at offset 0.',text:'',styles:[{id:'section-title',name:'Section title'},{id:'amber-brush',name:'Amber brush'}],catalog:[{id:'pinned-paper',name:'Pinned paper',kind:'sticker'},{id:'star',name:'Star',kind:'doodle'}]};
try {
  const plan=await askGemini(request,{apiKey:process.env.GEMINI_API_KEY,model:process.env.GEMINI_MODEL});
  const blocks=plan.edits.flatMap(e=>e.blocks);
  console.log(JSON.stringify({success:true,edits:plan.edits.length,nativeTypes:blocks.map(b=>b.type),formats:blocks.filter(b=>b.formatId).map(b=>b.formatId)}));
  if(process.argv.includes('--save')){const {writeFile}=await import('node:fs/promises');await writeFile(new URL('.gemini-smoke.json',import.meta.url),JSON.stringify(plan));}
} catch(error){console.log(JSON.stringify({success:false,status:error.status||502,message:error.status===429?'Gemini quota reached.':'Gemini did not return a valid native edit plan.',reason:['Invalid AI response.','Gemini request failed.','Gemini did not complete the proposal.'].includes(error.message)?error.message:'Response parsing failed.'}));process.exitCode=1;}
