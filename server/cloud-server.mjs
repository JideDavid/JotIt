import http from 'node:http';
import {fileURLToPath} from 'node:url';
import {MAX_SNAPSHOT_BYTES,createNoteCloud,firestoreCloudStore} from './note-cloud.mjs';
import {createR2Objects} from './r2-cloud-objects.mjs';

export function createCloudServer({cloud,verifyToken,verifyAppCheck,allowedAppIds=[],origins=[]}) {
  const server=http.createServer(async(req,res)=>{
    const reply=(status,value)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(value));};
    const origin=req.headers.origin;
    if(origin&&!origins.includes(origin))return reply(403,{error:'Origin not allowed.'});
    if(origin){res.setHeader('Access-Control-Allow-Origin',origin);res.setHeader('Vary','Origin');res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type, X-Firebase-AppCheck');res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');}
    if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}
    if(req.method==='GET'&&req.url==='/health')return reply(200,{ready:true,protocolVersion:1,scope:'note-cloud'});
    const action=/^\/v1\/cloud\/(read|write|history)$/.exec(req.url||'');
    if(req.method!=='POST'||!action)return reply(404,{error:'Not found.'});
    try {
      const token=/^Bearer (\S+)$/.exec(req.headers.authorization||'');
      if(!token)throw Object.assign(new Error('Sign in required.'),{status:401});
      let user;
      try {
        const [identity,app]=await Promise.all([verifyToken(token[1]),verifyAppCheck(req.headers['x-firebase-appcheck'])]);
        if(!app?.appId||!allowedAppIds.includes(app.appId))throw new Error('Rejected app');user=identity;
      } catch {throw Object.assign(new Error('Sign in and verify this app.'),{status:401});}
      if(!String(req.headers['content-type']||'').startsWith('application/json'))throw Object.assign(new Error('JSON required.'),{status:415});
      const limit=action[1]==='write'?MAX_SNAPSHOT_BYTES+16384:2048;
      let size=0;const chunks=[];
      for await(const chunk of req){size+=chunk.length;if(size>limit)throw Object.assign(new Error('Library too large.'),{status:413});chunks.push(chunk);}
      let body;try{body=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw Object.assign(new Error('Invalid JSON.'),{status:400});}
      reply(200,await cloud.call(action[1],user,body));
    } catch(error){const status=Number.isInteger(error.status)?error.status:503;reply(status,{error:status<500?error.message:'Cloud sync is temporarily unavailable. Local notes are unchanged.'});}
  });
  server.requestTimeout=120000;server.headersTimeout=10000;return server;
}

if(process.argv[1]===fileURLToPath(import.meta.url)) {
  try {
    const projectId=process.env.FIREBASE_PROJECT_ID;
    const appIds=(process.env.CLOUD_APP_IDS||'').split(',').map(v=>v.trim()).filter(Boolean);
    if(!projectId||!appIds.length)throw new Error('Missing cloud configuration');
    const [{initializeApp},{getAuth},{getAppCheck},{getFirestore}]=await Promise.all([
      import('firebase-admin/app'),import('firebase-admin/auth'),import('firebase-admin/app-check'),import('firebase-admin/firestore')]);
    const app=initializeApp({projectId});
    const objects=createR2Objects({accountId:process.env.R2_ACCOUNT_ID,accessKeyId:process.env.R2_ACCESS_KEY_ID,
      secretAccessKey:process.env.R2_SECRET_ACCESS_KEY,bucket:process.env.R2_BUCKET});
    const cloud=createNoteCloud({store:firestoreCloudStore(getFirestore(app)),objects});
    createCloudServer({cloud,verifyToken:t=>getAuth(app).verifyIdToken(t,true),verifyAppCheck:t=>getAppCheck(app).verifyToken(t),allowedAppIds:appIds,
      origins:(process.env.CLOUD_ALLOWED_ORIGINS||'').split(',').filter(Boolean)}).listen(Number(process.env.CLOUD_PORT)||8789,process.env.HOST||'127.0.0.1',()=>console.log('JotIt note cloud ready. Note contents and credentials are not logged.'));
  } catch {console.error('Cloud did not start. Configure Firebase credentials, allowed App IDs and private R2 storage.');process.exitCode=1;}
}
