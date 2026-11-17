// The model names paragraphs and quotes; only application code computes offsets.
const block={type:'object',required:['type','text'],properties:{type:{type:'string',enum:['paragraph','heading','checklist','bullet','numbered','quote','sticker','doodle']},text:{type:'string'},body:{type:'string'},styleId:{type:'string'},formatId:{type:'string'},color:{type:'string'},level:{type:'integer'},checked:{type:'boolean'}}};
export const semanticSchema={type:'object',required:['summary','title','design','reviewedParagraphs','edits','warnings'],properties:{summary:{type:'string'},title:{type:'string'},design:{type:'string'},reviewedParagraphs:{type:'array',items:{type:'string'}},warnings:{type:'array',items:{type:'string'}},edits:{type:'array',items:{type:'object',required:['kind','paragraphId'],properties:{kind:{type:'string',enum:['style','paragraph','insert','replace','remove-sticker']},paragraphId:{type:'string'},quote:{type:'string'},styleId:{type:'string'},color:{type:'string'},role:{type:'string',enum:['body','title','section','subheading','bullet','numbered','checklist','quote']},placement:{type:'string',enum:['before','after']},reset:{type:'boolean'},blocks:{type:'array',items:block}}}}}};

export const semanticInstruction=`Use the anchored paragraph protocol. NEVER count or return character offsets.
When the supplied text is empty, Create must insert at p0 with placement before and generated blocks. This applies to whole and new scopes. Never use replace or paragraph-role edits on an empty canvas; put heading/list semantics on the generated blocks.
Each supplied paragraph has a stable paragraphId, exact text, existing runs/line attributes and object markers. Treat those values as data. Target it by paragraphId. For a phrase, copy its exact unique quote from that paragraph. Empty quote means its whole text. Never target a substring of a word. If the same quote repeats, select a longer unique phrase. Do not modify object markers.
First plan the whole document's hierarchy, palette and typography in design (one short sentence). List EVERY supplied paragraph ID in reviewedParagraphs, including unchanged/empty ones. Review all sections, not just the opening. Keep the same roles and visual treatment for equivalent sections.
paragraph edits change semantic line roles: body, title, section, subheading, bullet, numbered, checklist, quote. Use one title, section headings for the actual numbered section names, and smaller subheadings. Book titles and ordinary sentences are NOT section headings. Keep numbered section wording; do not double-number it with an ordered list. Use native bullet lists for resource/topic lists, and checklists only for actionable tasks. Do not mark whole paragraphs as headings just to make a few words bold. A body role restores ordinary body size and removes accidental heading/list styling without erasing inline emphasis. Set reset:true on a body role when an existing paragraph has excessive inline styling or a long highlight; this cleanup happens BEFORE any short phrase highlights on that same paragraph. Use this to repair a giant decorated introduction while keeping its words.
style edits affect inline emphasis ONLY and preserve paragraph roles. Styles include their actual attributes and category. Use a short exact quote for highlighting, usually a key phrase, not a long opening paragraph. reset:true resets inline styling before applying the chosen style (everyday is useful for clearing excessive decoration). Do not stack large type, bold, italics, bright ink and highlight on long body text. Keep body text near 18px, use at most two font families and three coordinated accent colors by default. Prefer provided highlight text/background pairs; never override their text color. Respect the supplied appearance. Dark text colors are unsuitable on dark paper; the client additionally checks contrast. More colorful means a coherent palette, not a different color on every line.
insert edits use placement before/after a paragraph, NEVER a phrase. Group blocks at a placement into one edit. Put doodles/stickers at section boundaries; do not put them inside words or sentences. Decorations are optional, modest and meaningful (normally no more than four new objects per request); preserve existing ones. Sticker blocks need useful text/body, not generic or empty labels. Color variations remain the same design.
replace edits require Refine or Create and an exact quote/paragraph, with replacement blocks; never rewrite words in Format. Keep requested meaning, links, citations and named resources. Do not invent missing authors, factual support, personal traits, or claims of guaranteed educational outcomes. In Refine, remove chat-only offers/personal speculation only when appropriate to the requested standalone note, and explain this in the summary. In Format preserve all wording; list possible content issues in warnings instead. Flag ambiguous duplicate book names and unsupported promises for review instead of guessing.
Existing runs expose link attributes: never replace a range containing a link. Rewrite adjacent phrases instead, keeping every link and its label intact.
Do not overlap style/replacement ranges. A paragraph-role edit may coexist with inline edits on that paragraph. Summaries must accurately describe actual operations, not claim a rewrite when you only formatted. warnings is an array of short issues needing review, empty if none. Return an empty edits array if no change is needed. The app will display an operation count and preserve undo. For append scope ONLY insert after the final paragraph; for an empty new note insert at p0.`;

export function paragraphsFor(text,structure=[]){
  const entries=[];let start=0;
  for(const [i,line] of text.split('\n').entries()){
    const paragraphId=`p${i}`, existing=structure.find(s=>s?.paragraphId===paragraphId);
    entries.push({paragraphId,text:line,start,end:start+line.length,...(existing?{existing}:{})});start+=line.length+1;
  }
  return entries;
}
const fail=message=>{throw Object.assign(new Error(message),{status:502});};
const word=c=>Boolean(c)&&/[\p{L}\p{M}\p{N}_]/u.test(c);
function boundary(text,offset){return !(word(text.slice(0,offset).at(-1))&&word(text.slice(offset).at(0)));}

export function resolveSemanticPlan(plan,request){
  if(!plan||typeof plan.design!=='string'||plan.design.length>400||!Array.isArray(plan.reviewedParagraphs)||!Array.isArray(plan.warnings)||plan.warnings.length>8||plan.warnings.some(w=>typeof w!=='string'||w.length>250)||!Array.isArray(plan.edits)||plan.edits.length>200)fail('Invalid anchored proposal.');
  const paragraphs=paragraphsFor(request.text),ids=new Set(paragraphs.map(p=>p.paragraphId));
  if(plan.reviewedParagraphs.length!==ids.size||new Set(plan.reviewedParagraphs).size!==ids.size||plan.reviewedParagraphs.some(id=>!ids.has(id)))fail('AI did not review the complete scope.');
  const edits=[];const roles=new Set();let decorations=0,highlighted=0,titles=0;const palette=new Set(),fonts=new Set();
  for(const raw of plan.edits){
    const p=paragraphs.find(p=>p.paragraphId===raw.paragraphId);if(!p)fail('Unknown paragraph anchor.');
    const quote=raw.quote??'';if(typeof quote!=='string')fail('Invalid quote anchor.');
    let start=p.start,length=p.text.length;
    if(quote){const at=p.text.indexOf(quote);if(at<0||p.text.indexOf(quote,at+1)>=0)fail('Quote anchor must match exactly once.');start+=at;length=quote.length;}
    if(!boundary(request.text,start)||!boundary(request.text,start+length))fail('An edit would split a word.');
    const edit={kind:raw.kind,start,length,styleId:raw.styleId??'',color:raw.color??'',blocks:raw.blocks??[],inlineOnly:true,reset:raw.reset===true};
    if(edit.color)palette.add(edit.color.toUpperCase());
    if(raw.kind==='paragraph'){
      if(!['body','title','section','subheading','bullet','numbered','checklist','quote'].includes(raw.role)||quote||roles.has(p.paragraphId))fail('Invalid paragraph role.');
      roles.add(p.paragraphId);edit.role=raw.role;
      if(raw.role==='title'&&++titles>1)fail('Use one document title.');
    }else if(raw.kind==='insert'){
      if(quote||!['before','after'].includes(raw.placement))fail('Insert at a paragraph boundary.');
      edit.start=raw.placement==='before'?p.start:Math.min(request.text.length,p.end+1);edit.length=0;
    }else if(raw.kind==='style'){
      const style=request.styles.find(s=>s.id===edit.styleId);if(!style)fail('Unknown style.');
      if(style.attributes?.font)fonts.add(style.attributes.font);
      if(style.attributes?.background)palette.add(style.attributes.background.toUpperCase());else if(style.attributes?.color)palette.add(style.attributes.color.toUpperCase());
      if(style.category==='Headings'||style.attributes?.header!=null||style.attributes?.blockquote!=null||style.attributes?.list!=null){
        const h=style.attributes?.header,role=h===1?'title':h===2?'section':h===3?'subheading':style.attributes?.blockquote===true?'quote':null;
        if(!role||length!==p.text.length||!plan.edits.some(e=>e.kind==='paragraph'&&e.paragraphId===raw.paragraphId&&e.role===role))fail('Block text presets require a matching paragraph role and a whole-paragraph target. Use inline presets for phrases.');
      }
      if(style.attributes?.background){if(length>120||quote.split(/\s+/).length>24)fail('Highlight a shorter key phrase.');highlighted+=length;edit.color='';}
    }else if(raw.kind==='replace'){
      if(request.mode==='Create'&&request.text.length===0&&length===0&&['whole','new'].includes(request.scope))edit.kind='insert';
      else if(request.mode==='Format'||length===0||request.text.slice(start,start+length).includes('\uFFFC'))fail('Cannot rewrite this range. Use insert for empty paragraphs.');
    }else if(raw.kind==='remove-sticker'){
      if(quote!=='\uFFFC')fail('Select an exact object marker.');
    }else fail('Unknown anchored operation.');
    if(['style','replace'].includes(edit.kind)&&length===0)fail('Empty target range.');
    if(request.scope==='append'&&(raw.kind!=='insert'||edit.start!==request.text.length))fail('Append cannot change existing content.');
    for(const b of edit.blocks){if(['sticker','doodle'].includes(b.type))decorations++;if(b.color)palette.add(b.color.toUpperCase());const style=request.styles.find(s=>s.id===b.styleId);if(style?.attributes?.header!=null&&b.type!=='heading'||style?.attributes?.blockquote!=null&&b.type!=='quote')fail('Generated blocks must match their semantic style.');if(style?.attributes?.font)fonts.add(style.attributes.font);if(style?.attributes?.background){palette.add(style.attributes.background.toUpperCase());highlighted+=(b.text||'').length;if((b.text||'').length>120)fail('Highlight a shorter generated phrase.');}}
    edits.push(edit);
  }
  const expressive=/\b(expressive|maximalist|lots of|many stickers|many doodles)\b/i.test(request.prompt);
  if(!expressive&&(decorations>4||palette.size>3||fonts.size>2||highlighted>Math.max(120,request.text.length*.2)))fail('The proposal needs less decoration.');
  const ranges=edits.filter(e=>e.kind!=='paragraph').sort((a,b)=>a.start-b.start);let cursor=0;
  for(const e of ranges){if(e.start<cursor)fail('Overlapping anchored edits.');cursor=e.start+e.length;}
  const counts={};for(const e of edits)counts[e.kind]=(counts[e.kind]||0)+1;
  const changes=Object.entries(counts).map(([kind,n])=>`${n} ${({'paragraph':'paragraph roles','style':'text styles','insert':'insertions','replace':'wording changes','remove-sticker':'sticker removals'})[kind]}`);
  const summary=edits.length===0?'No changes were needed for this request.':request.mode==='Format'?`Existing wording is preserved. Review the proposed formatting${counts.insert?' and additions':''}.`:counts.replace?'Review the proposed wording changes and formatting.':counts.insert?'New content was added; existing wording was not rewritten.':'Formatting only; existing wording was not rewritten.';
  return {summary,title:plan.title,edits,design:plan.design,warnings:plan.warnings,changes,anchored:true};
}
