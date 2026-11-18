import {S3Client,PutObjectCommand,GetObjectCommand} from '@aws-sdk/client-s3';
import {MAX_SNAPSHOT_BYTES} from './note-cloud.mjs';

export function createR2Objects({accountId,accessKeyId,secretAccessKey,bucket,client}) {
  if(!/^[a-f0-9]{32}$/i.test(accountId||'') ||
     !/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/.test(bucket||'') ||
     !accessKeyId || !secretAccessKey)throw new Error('Missing or invalid R2 configuration.');
  const s3=client??new S3Client({
    region:'auto',endpoint:`https://${accountId}.r2.cloudflarestorage.com`,
    credentials:{accessKeyId,secretAccessKey},maxAttempts:2,
    requestChecksumCalculation:'WHEN_REQUIRED',responseChecksumValidation:'WHEN_REQUIRED',
  });
  const key=path=>{
    if(!/^[a-f0-9]{64}\/[a-f0-9]{64}\.json$/.test(path))throw new Error('Invalid cloud object path.');
    return `jotit-note-cloud/${path}`;
  };
  return {
    async put(path,bytes) {
      if(bytes.length>MAX_SNAPSHOT_BYTES)throw new Error('Cloud object exceeds the supported size.');
      try {
        await s3.send(new PutObjectCommand({Bucket:bucket,Key:key(path),Body:bytes,
          ContentType:'application/json',CacheControl:'private, no-store',IfNoneMatch:'*'}),
          {abortSignal:AbortSignal.timeout(30000)});
      } catch(error) {
        // Only immutable-object duplicates are harmless. Auth, quota and network
        // failures must prevent the Firestore head from advancing.
        if(error?.$metadata?.httpStatusCode!==412)throw error;
      }
    },
    async get(path) {
      const result=await s3.send(new GetObjectCommand({Bucket:bucket,Key:key(path)}),
        {abortSignal:AbortSignal.timeout(30000)});
      if(!result.Body||result.ContentLength>MAX_SNAPSHOT_BYTES){result.Body?.destroy?.();throw new Error('Invalid cloud object.');}
      const chunks=[];let length=0;
      try {
        for await(const chunk of result.Body) {
          length+=chunk.length;
          if(length>MAX_SNAPSHOT_BYTES)throw new Error('Cloud object exceeds the supported size.');
          chunks.push(Buffer.from(chunk));
        }
      } catch(error){result.Body.destroy?.();throw error;}
      return Buffer.concat(chunks);
    },
  };
}
