// Run after an emulator-only release build on local preview port 8091.
// No credential entry, real customer or payment data are used.
const puppeteer = require(process.env.PUPPETEER_MODULE || 'puppeteer');
const fs = require('fs');
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_PATH || 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',args:['--no-sandbox','--enable-webgl','--ignore-gpu-blocklist','--enable-unsafe-swiftshader']});
 const page=await browser.newPage(); const errors=[];page.on('pageerror',e=>errors.push(e.message));
 // The compiled app uses demo-movik-test. Avoid depending on local Functions
 // startup for the anonymous layout capture; no fake quote/mission is shown.
 await page.setRequestInterception(true);
 page.on('request',request=>{
   if(request.url().includes(':5001/demo-movik-test/') && request.url().endsWith('/getBookingConfiguration')) return request.respond({status:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify({result:{policy:null}})});
   request.continue();
 });
 for(const [name,width,height] of [['mobile',390,844],['desktop',1440,1000]]){
  await page.setViewport({width,height,deviceScaleFactor:1});
  await page.goto('http://127.0.0.1:8091/fr/livraison/demande',{waitUntil:'networkidle2'});
  await new Promise(resolve=>setTimeout(resolve,2500));
  await page.screenshot({path:`artifacts/booking-${name}.png`});
 }
 fs.writeFileSync('artifacts/booking-browser-errors.json',JSON.stringify(errors,null,2));
 await browser.close(); if(errors.length)process.exitCode=1;
})();
