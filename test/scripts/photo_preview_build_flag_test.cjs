'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const test=require('node:test');
const root=path.resolve(__dirname,'../..');
const bash=process.env.MOVIK_TEST_BASH || (process.platform==='win32'?'C:/Program Files/Git/bin/bash.exe':'bash');
for(const value of [undefined,'true','false','invalid']){
 test('photo preview flag '+String(value),()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'movik-build-flag-'));
  const sdk=path.join(dir,'.flutter/bin');
  fs.mkdirSync(sdk,{recursive:true});
  fs.writeFileSync(path.join(sdk,'flutter'),'#!/usr/bin/env bash\nprintf "%s\\n" "$@" >> calls.txt\nmkdir -p build/web\nprintf "fixture" > build/web/index.html\n',{mode:0o755});
  const env={...process.env,GOOGLE_MAPS_API_KEY:'',FCM_WEB_VAPID_KEY:''};
  delete env.ENABLE_PHOTO_INTAKE;
  if(value!==undefined)env.ENABLE_PHOTO_INTAKE=value;
  const run=spawnSync(bash,[path.join(root,'scripts/vercel_build.sh').replaceAll('\\','/')],{cwd:dir,env,encoding:'utf8',timeout:15000});
  if(run.error)throw run.error;
  if(value==='invalid'){assert.notEqual(run.status,0,'invalid value must stop build');return;}
  assert.equal(run.status,0,run.stderr);
  const calls=fs.readFileSync(path.join(dir,'calls.txt'),'utf8');
  assert.ok(calls.split(/\r?\n/).includes('--dart-define=ENABLE_PHOTO_INTAKE='+(value??'false')),'missing exact compile-time flag');
 });
}
