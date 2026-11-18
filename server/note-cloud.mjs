import {createHash} from 'node:crypto';

export const MAX_SNAPSHOT_BYTES = 64 * 1024 * 1024;
const digest = value => createHash('sha256').update(value).digest('hex');
const fail = (status, message) => { throw Object.assign(new Error(message), {status}); };
const noteKeys = ['id','title','body','timestamp','color','isLocked','richText','paper','media'];

export function encodeSnapshot(notes) {
  if (!Array.isArray(notes) || notes.length > 2000) fail(400, 'Invalid note collection.');
  const ids = new Set();
  const sorted = notes.map(n => {
    if (!n || typeof n !== 'object' || Array.isArray(n) || Object.keys(n).some(k=>!noteKeys.includes(k)) ||
        typeof n.id !== 'string' || !n.id.length || n.id.length>160 || ids.has(n.id) ||
        typeof n.title !== 'string' || typeof n.body !== 'string' || typeof n.isLocked !== 'boolean' ||
        !Number.isSafeInteger(n.color) || !((n.color>=0&&n.color<9)||(n.color>=0xff000000&&n.color<=0xffffffff)) ||
        typeof n.timestamp !== 'string' || !Number.isFinite(Date.parse(n.timestamp)) ||
        ['richText','paper','media'].some(k=>n[k]!==null&&typeof n[k]!=='string')) fail(400,'Invalid note data.');
    ids.add(n.id);
    return Object.fromEntries(noteKeys.map(k=>[k,n[k]]));
  }).sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
  const bytes=Buffer.from(JSON.stringify({schema:1,notes:sorted}));
  if(bytes.length>MAX_SNAPSHOT_BYTES)fail(413,'This library exceeds the 64 MiB backup limit.');
  return bytes;
}

// The service never receives PIN records or recovery/device credentials. Cloud
// content is account-accessible; provider-managed at-rest encryption is not E2EE.
export function createNoteCloud({store,objects,now=()=>Date.now()}) {
  return {async call(action,user,body={}) {
    if(!user?.uid||user.email_verified!==true)fail(403,'A verified account is required.');
    if(!body||typeof body!=='object'||Array.isArray(body))fail(400,'Invalid request.');
    const allowed={history:[],read:['revision'],write:['expectedRevision','operationId','notes']}[action];
    if(!allowed||Object.keys(body).some(k=>!allowed.includes(k)))fail(400,'Unsupported cloud request.');
    const uid=digest(user.uid);
    const charge=bytes=>store.transact(`quota-${uid}`,state=>{
      if(!state||now()-state.start>=3600000)state={start:now(),actions:0,bytes:0};
      if(state.actions>=360||state.bytes+bytes>512*1024*1024)fail(429,'Cloud transfer limit reached. Retry later.');
      return {state:{...state,actions:state.actions+1,bytes:state.bytes+bytes},result:null};
    });
    await charge(0);
    if(action==='history') {
      const state=await store.read(uid);
      return {revision:state?.revision||0,backups:(state?.history||[]).map(({revision,createdAt,count})=>({revision,createdAt,count}))};
    }
    if(action==='read') {
      const state=await store.read(uid);
      if(!state)return {revision:0,notes:[],createdAt:null};
      const revision=body.revision??state.revision;
      if(!Number.isSafeInteger(revision)||revision<1)fail(400,'Invalid backup revision.');
      const entry=state.history.find(v=>v.revision===revision);
      if(!entry)fail(410,'This backup is no longer retained.');
      await charge(entry.bytes||0);
      const bytes=await objects.get(`${uid}/${entry.digest}.json`);
      if(bytes.length>MAX_SNAPSHOT_BYTES||digest(bytes)!==entry.digest)fail(503,'Backup integrity check failed.');
      const parsed=JSON.parse(bytes.toString('utf8'));
      if(parsed.schema!==1)fail(503,'Unsupported cloud snapshot.');
      return {revision,notes:parsed.notes,createdAt:entry.createdAt};
    }
    if(action==='write') {
      if(!Number.isSafeInteger(body.expectedRevision)||body.expectedRevision<0||
         !/^[A-Za-z0-9_-]{43}$/.test(body.operationId))fail(400,'Invalid sync operation.');
      const bytes=encodeSnapshot(body.notes), hash=digest(bytes);
      await charge(bytes.length);
      // Immutable content-addressed objects prevent a failed CAS or duplicate
      // operation from overwriting a snapshot another device already references.
      await objects.put(`${uid}/${hash}.json`,bytes);
      return store.transact(uid,state=>{
        state??={revision:0,history:[]};
        const previous=state.history.find(v=>v.operationId===body.operationId);
        if(previous) {
          if(previous.digest!==hash||previous.expectedRevision!==body.expectedRevision)fail(409,'Sync operation changed.');
          return {state,result:{revision:previous.revision}};
        }
        if(state.revision!==body.expectedRevision)fail(409,'Another device updated the library. Retry sync.');
        const revision=state.revision+1;
        const entry={revision,createdAt:new Date(now()).toISOString(),count:body.notes.length,
          digest:hash,bytes:bytes.length,operationId:body.operationId,expectedRevision:body.expectedRevision};
        return {state:{revision,history:[entry,...state.history].slice(0,20)},result:{revision}};
      });
    }
    fail(404,'Unknown cloud action.');
  }};
}

export function firestoreCloudStore(db) {
  const ref=uid=>db.collection('jotitCloudLibraries').doc(uid);
  return {
    async read(uid){return (await ref(uid).get()).data()??null;},
    transact(uid,update){return db.runTransaction(async tx=>{
      const doc=ref(uid),result=update((await tx.get(doc)).data()??null);
      tx.set(doc,result.state);return result.result;
    });},
  };
}

export function bucketCloudObjects(bucket) {
  const file=path=>bucket.file(`jotit-note-cloud/${path}`);
  return {
    async put(path,bytes) {
      try {await file(path).save(bytes,{resumable:false,gzip:true,
        preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:'application/json',cacheControl:'private, no-store'}});}
      catch(error){if(Number(error.code)!==412)throw error;}
    },
    async get(path) {const [bytes]=await file(path).download();return bytes;},
  };
}
