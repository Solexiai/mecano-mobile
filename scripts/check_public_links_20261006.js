// Click the rendered Flutter accessibility buttons; emulator-only review.
const puppeteer=require('C:/Users/Utilisateur/AppData/Local/npm-cache/_npx/4b4c857f6efdfb61/node_modules/puppeteer');
const fs=require('fs');
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',args:['--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader']});
 const page=await browser.newPage();await page.setViewport({width:1280,height:900});const results=[];
 const links=[['Obtenir mon devis','/fr/livraison/demande'],['Devenir chauffeur','/fr/devenir-chauffeur'],['Connexion','/fr/connexion'],['FAQ','/fr/faq'],['Tarifs','/fr/tarifs'],['Sécurité','/fr/securite'],['Contact','/fr/contact'],['Comment ça marche','/fr/comment-ca-marche'],['Politique de confidentialité','/fr/legal/privacy'],["Conditions d'utilisation",'/fr/legal/terms'],["Politique d'annulation",'/fr/legal/cancellation']];
 const categories=[['Meubles','cat_furniture'],['Appareils électroménagers','cat_appliances'],['Achats Marketplace','cat_marketplace'],['Matériaux de construction','cat_building_materials'],['Grand téléviseur','cat_tv'],['Achats Costco','cat_costco']];
 const categoryMode=process.argv.includes('categories');
 const checks=categoryMode?categories.map(([label,key])=>['Commencer un devis pour '+label,'/fr/livraison/demande?category='+key]):links;
 try{
  for(const [label,path] of checks){
   await page.goto('http://127.0.0.1:8092/fr',{waitUntil:'domcontentloaded'});
   await page.waitForSelector('flt-semantics-placeholder');await page.$eval('flt-semantics-placeholder',e=>e.click());
   await page.waitForFunction(()=>document.querySelector('flt-semantics-host')?.textContent.includes('Granby'));
   await page.evaluate(label=>{
    const el=[...document.querySelectorAll('flt-semantics-host [role="button"]')].find(e=>e.textContent===label||e.getAttribute('aria-label')?.startsWith(label+'\n'));
    if(!el)throw new Error('Button missing: '+label);el.click();
   },label);
   await page.waitForFunction(path=>location.pathname+location.search===path,{timeout:15000},path);
   results.push({label,url:page.url(),passed:true});console.log('clicked '+label+' -> '+page.url());
  }
 }finally{fs.writeFileSync('artifacts/review-20261006/'+(categoryMode?'category-validation':'link-validation')+'.json',JSON.stringify({results,limitations:['Desktop French accessibility clicks only; category and login resume also covered by Flutter tests']},null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
