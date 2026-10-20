const fs=require('fs'),cp=require('child_process'),http=require('http'),path=require('path');
const root=path.resolve(__dirname,'../..'),build=path.join(__dirname,'full-build');
require(path.join(root,'.vercel/photo-diagnostic/photo.js'));
const fixture=path.join(root,'.vercel/photo-diagnostic/received.jpg');
fs.writeFileSync(fixture,Buffer.from(globalThis.photoFixture,'base64'));delete globalThis.photoFixture;
const profile=path.join(root,'.vercel/photo-diagnostic/full-chrome-'+Date.now());fs.mkdirSync(profile,{recursive:true});
const mime={'.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.html':'text/html','.png':'image/png'};
const server=http.createServer((req,res)=>{
 if(req.method==='POST'&&req.url==='/fixture'){const chunks=[];req.on('data',c=>chunks.push(c));req.on('end',()=>{fs.writeFileSync(fixture,Buffer.concat(chunks));res.end('ok');});return;}
 if(req.url==='/'){res.setHeader('content-type','text/html');res.end('<!DOCTYPE html><meta name="viewport" content="width=device-width,initial-scale=1"><script src="flutter_bootstrap.js" async></script>');return;}
 const file=path.resolve(build,'.'+decodeURIComponent(req.url.split('?')[0]));
 if(!file.startsWith(build+path.sep)){res.writeHead(403).end();return;}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404).end();return;}res.setHeader('content-type',mime[path.extname(file)]||'application/octet-stream');res.end(data);});
});
let browser,ws;const results=[];
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const port=server.address().port;
 browser=cp.spawn('C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',['--headless','--disable-gpu','--no-first-run','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
 let debugPort;
 for(let i=0;i<100;i++){try{debugPort=fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split('\n')[0];break;}catch{}await delay(100);}
 const tabs=await(await fetch('http://127.0.0.1:'+debugPort+'/json/list')).json();
 ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
 await new Promise(r=>ws.onopen=r);
 let id=0;const pending=new Map(),events=[];
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}else events.push(m);};
 const send=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;const timer=setTimeout(()=>{pending.delete(key);reject(new Error('CDP timeout '+method));},45000);pending.set(key,{resolve:v=>{clearTimeout(timer);resolve(v);},reject:e=>{clearTimeout(timer);reject(e);}});ws.send(JSON.stringify({id,method,params}));});
 const value=async expression=>(await send('Runtime.evaluate',{expression,returnByValue:true,userGesture:true,awaitPromise:true})).result?.value;
 await send('Runtime.enable');await send('Page.enable');
 await send('Page.setInterceptFileChooserDialog',{enabled:true});

const received=fs.readFileSync(fixture);
for(const mobile of [false,true]){
 await send('Emulation.setDeviceMetricsOverride',{width:mobile?393:1280,height:mobile?852:900,deviceScaleFactor:mobile?3:1,mobile});
 await send('Emulation.setTouchEmulationEnabled',{enabled:mobile});
 for(const kind of ['received-jpeg','large-jpeg','png','webp','unsupported','oversize','corrupt','cancel']){
   await send('Page.navigate',{url:'http://127.0.0.1:'+port+'/'});
   let ready=false;
   for(let i=0;i<120;i++){if(await value("!!document.getElementById('select-photo')")){ready=true;break;}await delay(500);}
   if(!ready)throw Error('App not ready');
   if(kind==='received-jpeg')fs.writeFileSync(fixture,received);
   else if(kind==='unsupported')fs.writeFileSync(fixture,Buffer.from('GIF89a'));
   else if(kind==='corrupt')fs.writeFileSync(fixture,Buffer.from([255,216,255,1,2,3]));
   else if(kind==='oversize'){const b=Buffer.alloc(20*1024*1024+1);b[0]=255;b[1]=216;b[2]=255;fs.writeFileSync(fixture,b);}
   else if(kind!=='cancel'){
     const large=kind==='large-jpeg',w=large?4000:320,h=large?3000:240,mime=kind==='png'?'image/png':kind==='webp'?'image/webp':'image/jpeg';
     await value("(()=>{const c=document.createElement('canvas');c.width="+w+";c.height="+h+";const x=c.getContext('2d'),d=x.createImageData(c.width,c.height);let seed=17;for(let i=0;i<d.data.length;i+=4){for(let j=0;j<3;j++){seed=(Math.imul(seed,1664525)+1013904223)|0;d.data[i+j]=seed>>>24;}d.data[i+3]=255;}x.putImageData(d,0,0);return new Promise(resolve=>c.toBlob(async b=>{await fetch('/fixture',{method:'POST',body:b});resolve(b.size);},'"+mime+"',0.82));})()");
   }
   events.length=0;
   await value("document.getElementById('select-photo').click()");
   let chooser;
   for(let i=0;i<30;i++){chooser=events.find(e=>e.method==='Page.fileChooserOpened');if(chooser)break;await delay(100);}
   if(!chooser)throw Error('No native chooser '+kind);
   const attributes=await value("(()=>{const e=document.querySelector('input[type=file]');return {accept:e.accept,capture:e.getAttribute('capture')};})()");
   if(kind==='cancel')await value("document.querySelector('input[type=file]').dispatchEvent(new Event('cancel'))");
   else await send('DOM.setFileInputFiles',{backendNodeId:chooser.params.backendNodeId,files:[fixture]});
   let output;
   for(let i=0;i<100;i++){output=await value("document.getElementById('result').textContent");if(output!=='PICKING')break;await delay(500);}
   const actual=JSON.parse(output),reason={unsupported:'unsupportedFormat',oversize:'inputTooLarge',corrupt:'processingFailed'}[kind];
   const ok=reason?actual.ok===false&&actual.reason===reason:actual.ok===(kind!=='cancel');
   results.push({mobile,kind,sourceBytes:kind==='cancel'?0:fs.statSync(fixture).size,attributes,actual,passed:ok});
   console.log((mobile?'mobile ':'desktop ')+kind+': '+(ok?'PASS':'FAIL'));
 }
}
 fs.writeFileSync(path.join(__dirname,'browser-matrix.json'),JSON.stringify(results,null,2));console.log('RESULT '+results.filter(r=>r.passed).length+'/'+results.length);if(results.some(r=>!r.passed))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{ws?.close();browser?.kill();server.close();});
