// Local emulator-only review; no production data or authenticated transactions.
const puppeteer=require('C:/Users/Utilisateur/AppData/Local/npm-cache/_npx/4b4c857f6efdfb61/node_modules/puppeteer');
const fs=require('fs');
(async()=>{
 const out='artifacts/review-20261006';fs.mkdirSync(out,{recursive:true});
 const browser=await puppeteer.launch({headless:true,executablePath:'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',args:['--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader']});
 const page=await browser.newPage();const errors=[],failures=[],visits=[];
 page.on('pageerror',e=>errors.push({url:page.url(),message:e.message}));page.on('requestfailed',r=>failures.push({url:r.url(),error:r.failure()?.errorText}));
 async function open(path){
  await page.goto('http://127.0.0.1:8092/'+path,{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForSelector('flt-semantics-placeholder',{timeout:20000});
  await page.$eval('flt-semantics-placeholder',el=>el.click());
  await page.waitForFunction(()=>document.querySelector('flt-semantics-host')?.textContent.length>20,{timeout:20000});
  // Readiness comes from visible Flutter semantics, not background Firebase traffic.
  await new Promise(r=>setTimeout(r,4000));
 }
 try{
  for(const locale of ['fr','en','es'])for(const suffix of ['', '/granby']){
   await page.setViewport({width:1280,height:900,deviceScaleFactor:1});await open(locale+suffix);
   for(const width of [320,390,768,1280]){
    await page.setViewport({width,height:900,deviceScaleFactor:1});await new Promise(r=>setTimeout(r,1500));
    const name=locale+'-'+(suffix?'granby':'home')+'-'+width;
    const text=await page.$eval('flt-semantics-host',el=>el.textContent);
    if(!text.includes('Granby'))throw new Error('Expected launch text missing: '+name);
    await page.screenshot({path:out+'/'+name+'.png'});
    visits.push({path:page.url(),width,text,file:name+'.png'});console.log('captured '+name);
   }
  }
  await page.setViewport({width:390,height:844,deviceScaleFactor:1});
  for(const suffix of ['livraison','devenir-chauffeur','connexion','faq','tarifs','securite','contact','legal/privacy','legal/terms','legal/cancellation','legal/dispute','livraison/demande?category=cat_furniture']){
   await open('fr/'+suffix);const text=await page.$eval('flt-semantics-host',el=>el.textContent);
   visits.push({path:page.url(),width:390,text});
   if(suffix.startsWith('livraison/demande')){
    if(!text.includes('Catégorie sélectionnée : Meubles'))throw new Error('Selected furniture category missing');
    const invented=await page.$$eval('input',els=>els.some(el=>el.value==='Autre objet'));
    if(invented)throw new Error('Generic object was invented');
    await page.screenshot({path:out+'/fr-guest-request.png'});
   }
   console.log('visited fr/'+suffix);
  }
 }finally{
  fs.writeFileSync(out+'/browser-validation.json',JSON.stringify({date:new Date().toISOString(),environment:'local demo-movik-test build; no emulator services active',visits,errors,failures,limitations:['No signed-in user or official quote exercised','200 percent text verified by Flutter widget tests, not browser zoom','Route loading alone does not prove link click behavior']},null,2));await browser.close();
 }
 console.log(JSON.stringify({visits:visits.length,pageErrors:errors.length,requestFailures:failures.length}));if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
