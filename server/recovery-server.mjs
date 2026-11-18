import http from 'node:http';
import {fileURLToPath} from 'node:url';
import {createNotePinRecovery,firestoreRecoveryStore,resendRecoveryMailer} from './note-pin-recovery.mjs';

export function createRecoveryServer({recovery,verifyToken,verifyAppCheck,allowedAppIds=[],origins=[]}) {
  const server=http.createServer(async(req,res)=>{
    const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'};
    const reply=(status,value)=>{res.writeHead(status,{...headers,'Content-Type':'application/json'});res.end(JSON.stringify(value));};
    const origin=req.headers.origin;
    if(origin&&!origins.includes(origin))return reply(403,{error:'Origin not allowed.'});
    if(origin) {
      res.setHeader('Access-Control-Allow-Origin',origin);res.setHeader('Vary','Origin');
      res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type, X-Firebase-AppCheck');
      res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
    }
    if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}
    if(req.method==='GET'&&req.url==='/health')return reply(200,{ready:true,protocolVersion:1,scope:'shared-note-pin'});
    if(req.method==='GET'&&req.url==='/recover') {
      res.writeHead(200,{...headers,'Content-Type':'text/html; charset=utf-8','Content-Security-Policy':"default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"});
      return res.end('<!doctype html><html lang="en"><meta name="viewport" content="width=device-width"><title>JotIt note PIN recovery</title><h1>Return to JotIt</h1><p>Open Settings → Recovery email → Reset note PIN on the enrolled device. Paste the original link from your email. Opening this page does not use the link.</p><p>No PINs or note content are collected on this page.</p></html>');
    }
    const match=/^\/v1\/recovery\/(enroll|status|request|redeem|disable)$/.exec(req.url||'');
    if(req.method!=='POST'||!match)return reply(404,{error:'Not found.'});
    try {
      const bearer=/^Bearer (\S+)$/.exec(req.headers.authorization||'');
      if(!bearer)throw Object.assign(new Error('Sign in required.'),{status:401});
      let user,app;
      try {
        [user,app]=await Promise.all([verifyToken(bearer[1]),verifyAppCheck(req.headers['x-firebase-appcheck'])]);
        if(!app?.appId||!allowedAppIds.includes(app.appId))throw new Error('Rejected app.');
      } catch {throw Object.assign(new Error('Sign in and verify this app before using recovery.'),{status:401});}
      if(!String(req.headers['content-type']||'').startsWith('application/json'))throw Object.assign(new Error('JSON required.'),{status:415});
      let size=0;const chunks=[];
      for await(const chunk of req){size+=chunk.length;if(size>6000)throw Object.assign(new Error('Request too large.'),{status:413});chunks.push(chunk);}
      let body;try{body=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw Object.assign(new Error('Invalid JSON.'),{status:400});}
      reply(200,await recovery.call(match[1],user,body));
    } catch(error) {
      reply(error.status||503,{error:error.status?error.message:'Recovery is temporarily unavailable. Your PIN is unchanged.'});
    }
  });
  server.requestTimeout=30000;server.headersTimeout=10000;return server;
}

if(process.argv[1]===fileURLToPath(import.meta.url)) {
  try {
    const projectId=process.env.FIREBASE_PROJECT_ID,resetUrl=process.env.RECOVERY_RESET_URL;
    const ids=(process.env.RECOVERY_APP_IDS||'').split(',').filter(Boolean);
    if(!projectId||!resetUrl||!ids.length)throw new Error('Missing recovery configuration.');
    const [{initializeApp},{getAuth},{getAppCheck},{getFirestore}]=await Promise.all([import('firebase-admin/app'),import('firebase-admin/auth'),import('firebase-admin/app-check'),import('firebase-admin/firestore')]);
    const app=initializeApp({projectId});
    const recovery=createNotePinRecovery({store:firestoreRecoveryStore(getFirestore(app)),sendMail:resendRecoveryMailer({apiKey:process.env.RECOVERY_EMAIL_API_KEY,from:process.env.RECOVERY_EMAIL_FROM}),resetUrl});
    createRecoveryServer({recovery,verifyToken:t=>getAuth(app).verifyIdToken(t,true),verifyAppCheck:t=>getAppCheck(app).verifyToken(t),allowedAppIds:ids,origins:(process.env.RECOVERY_ALLOWED_ORIGINS||'').split(',').filter(Boolean)}).listen(Number(process.env.RECOVERY_PORT)||8788,process.env.HOST||'127.0.0.1',()=>console.log('JotIt shared note PIN recovery ready. Request bodies and credentials are not logged.'));
  } catch {console.error('Recovery did not start. Configure Firebase credentials, allowed App IDs, HTTPS recovery URL and email sender.');process.exitCode=1;}
}
