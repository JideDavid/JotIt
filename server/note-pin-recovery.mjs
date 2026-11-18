import {createHash, randomBytes, timingSafeEqual} from 'node:crypto';

const fail=(status,message)=>{throw Object.assign(new Error(message),{status});};
const hash=value=>createHash('sha256').update(value).digest('hex');
const secret=()=>randomBytes(32).toString('base64url');
const opaque=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{43}$/.test(value);
const equal=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
const denied=()=>fail(403,'Recovery is unavailable for this account or installation.');
const identity=user=>{
  if(!user?.uid||user.email_verified!==true||typeof user.email!=='string'||user.email.length>254)fail(401,'Sign in with a verified Google account.');
  return {uid:user.uid,email:user.email.toLowerCase()};
};

// Store.transact runs a pure synchronous update in a durable transaction.
// Mail is deliberately sent outside the transaction, which Firestore may retry.
export function createNotePinRecovery({store,sendMail,resetUrl,now=Date.now}) {
  const url=new URL(resetUrl);
  if(url.protocol!=='https:'||url.pathname!=='/recover'||url.username||url.password||url.search||url.hash)throw new Error('Use a fixed HTTPS recovery landing URL ending in /recover.');
  async function quota(uid) {
    await store.transact(`u_${hash(uid)}`,old=>{
      const r=old&&now()-old.since<3600000?old:{since:now(),count:0};
      if(r.count>=30)fail(429,'Too many recovery requests. Try again later.');
      return {record:{...r,count:r.count+1},result:null};
    });
  }
  function bound(record,user,body) {
    if(!record||record.uid!==user.uid||record.email!==user.email||!equal(record.deviceHash,hash(body.deviceSecret)))denied();
  }
  async function call(action,rawUser,body) {
    const user=identity(rawUser);
    if(!body||!opaque(body.installationId)||!opaque(body.deviceSecret)||!opaque(body.epoch))fail(400,'Invalid recovery request.');
    await quota(user.uid);
    const key=`i_${body.installationId}`;
    if(action==='enroll') {
      if(!Number.isFinite(rawUser.auth_time)||now()/1000-rawUser.auth_time>300||rawUser.auth_time>now()/1000+60)fail(401,'Sign in again before linking recovery.');
      return store.transact(key,old=>{
        if(old) {
          if(old.uid!==user.uid||!equal(old.deviceHash,hash(body.deviceSecret))||old.epoch!==body.epoch)denied();
        }
        return {record:{uid:user.uid,email:user.email,deviceHash:hash(body.deviceSecret),epoch:body.epoch,createdAt:old?.createdAt??now(),lastSent:0,challenge:null,receipt:null},result:{enabled:true,epoch:body.epoch}};
      });
    }
    if(action==='status')return store.transact(key,r=>{
      bound(r,user,body);
      return {record:r,result:{enabled:!r.disabled,epoch:r.epoch}};
    });
    if(action==='disable')return store.transact(key,r=>{
      bound(r,user,body);if(r.epoch!==body.epoch)denied();
      return {record:{...r,disabled:true,challenge:null,receipt:null},result:{enabled:false}};
    });
    if(action==='request') {
      const token=secret(),tokenHash=hash(token);
      await store.transact(key,r=>{
        bound(r,user,body);if(r.disabled||r.epoch!==body.epoch)denied();
        if(r.lastSent&&now()-r.lastSent<60000)fail(429,'Wait one minute before requesting another link.');
        return {record:{...r,lastSent:now(),challenge:{hash:tokenHash,expires:now()+900000,attempts:0}},result:null};
      });
      try {
        await sendMail({to:user.email,kind:'reset',link:`${url.href}#token=${token}`,id:`recovery-${tokenHash}`});
      } catch {
        await store.transact(key,r=>({record:r?.challenge?.hash===tokenHash?{...r,challenge:null}:r,result:null}));
        fail(503,'The recovery email could not be sent. Wait one minute and try again.');
      }
      return {sent:true,expiresInSeconds:900};
    }
    if(action==='redeem') {
      if(!opaque(body.token)||!opaque(body.resetId)||!opaque(body.newEpoch)||body.newEpoch===body.epoch||typeof body.fingerprint!=='string'||!/^[a-f0-9]{64}$/.test(body.fingerprint))fail(400,'Invalid reset request.');
      const tokenHash=hash(body.token);
      const result=await store.transact(key,r=>{
        bound(r,user,body);if(r.disabled)denied();
        const previous=r.receipt;
        if(previous&&previous.oldEpoch===body.epoch&&r.epoch===previous.newEpoch&&previous.resetId===body.resetId&&previous.newEpoch===body.newEpoch&&previous.fingerprint===body.fingerprint&&equal(previous.tokenHash,tokenHash)) {
          return {record:r,result:{resetId:previous.resetId,epoch:previous.newEpoch,fingerprint:previous.fingerprint}};
        }
        if(r.epoch!==body.epoch)denied();
        const c=r.challenge;
        if(!c||c.expires<=now()||c.attempts>=5)fail(400,'The recovery link has expired or was already used. Request another link.');
        if(!equal(c.hash,tokenHash))return {record:{...r,challenge:{...c,attempts:c.attempts+1}},result:{invalid:true}};
        const receipt={oldEpoch:r.epoch,newEpoch:body.newEpoch,resetId:body.resetId,fingerprint:body.fingerprint,tokenHash,notified:false};
        return {record:{...r,epoch:body.newEpoch,challenge:null,receipt},result:{resetId:body.resetId,epoch:body.newEpoch,fingerprint:body.fingerprint}};
      });
      if(result.invalid)fail(400,'The recovery link is invalid. Check the link or request another.');
      // A failed notification never reverses an already authorized reset.
      const notify=await store.transact(key,r=>({record:r,result:r?.receipt?.resetId===body.resetId&&!r.receipt.notified}));
      if(notify)try {
        await sendMail({to:user.email,kind:'notice',id:`recovery-notice-${body.resetId}`});
        await store.transact(key,r=>({record:r?.receipt?.resetId===body.resetId?{...r,receipt:{...r.receipt,notified:true}}:r,result:null}));
      } catch { /* The same idempotent redeem can retry the notification. */ }
      return result;
    }
    fail(404,'Not found.');
  }
  return {call};
}

export function firestoreRecoveryStore(db) {
  return {transact:(id,update)=>db.runTransaction(async tx=>{
    const ref=db.collection('jotitNotePinRecovery').doc(id);
    const snapshot=await tx.get(ref);
    const {record,result}=update(snapshot.exists?snapshot.data():null);
    if(record)tx.set(ref,record);
    return result;
  })};
}

export function resendRecoveryMailer({apiKey,from,fetchImpl=fetch}) {
  if(!apiKey||!from||/[\r\n]/.test(from))throw new Error('Configure the email sender.');
  return async ({to,kind,link,id})=>{
    const text=kind==='reset'
      ? `A reset of your JotIt shared note PIN was requested. This link expires in 15 minutes.\n\n${link}\n\nIn JotIt, open Recovery email and paste this link to choose a new note PIN. It works only on the enrolled installation. If you did not request this, ignore this email.`
      : 'A reset of your JotIt shared note PIN was authorized. If this was not you, secure your Google account. No PIN or note content is included in this email.';
    const response=await fetchImpl('https://api.resend.com/emails',{method:'POST',signal:AbortSignal.timeout(15000),headers:{Authorization:`Bearer ${apiKey}`,'Content-Type':'application/json','Idempotency-Key':id},body:JSON.stringify({from,to:[to],subject:kind==='reset'?'Reset your JotIt note PIN':'JotIt note PIN recovery notice',text})});
    if(!response.ok)throw new Error('Email delivery failed.');
  };
}
