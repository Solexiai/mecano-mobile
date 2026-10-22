import { assertPhotoBytes, assertPhotoDraft, checkPhotoQuota, parsePhotoRequest, parsePhotoSuggestion, photoAnalysisConfig } from '../../src/lib/photoAnalysis';
import { analyzeWithOpenAi } from '../../src/lib/openAiPhotoAnalyzer';
const suggestion=()=>({category:'sofa',label:'Canape fictif',confidence:'high',special_handling:false,reason:'ordinary'});
const req=()=>({draftId:'draft-fictitious',itemId:'item',photoPath:'booking_photos/fake/draft-fictitious/item/0.jpg',locale:'fr',consent:true});
const draft=()=>({owner_uid:'fake',draft_id:'draft-fictitious',expires_at:{toMillis:()=>2000},draft:{intake_mode:'photo_assisted',items:[{id:'item',photos:[req().photoPath]}]}});
const cfg=()=>({enabled:true,provider:'openai',model:'TEST-MODEL',allowedUserUids:['fake'],userDailyLimit:2,globalDailyLimit:3});
const input=()=>({bytes:Buffer.from([255,216,255,0]),locale:'fr' as const,model:'TEST-MODEL',apiKey:'FAKE-KEY'});
const envelope=(s:unknown=suggestion())=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(s)}]}]});
test('valid suggestion has no prices, measurements or confirmation',()=>expect(parsePhotoSuggestion(suggestion())).toEqual(suggestion()));
test.each(['weight','price','driverId'])('additional model field %s rejected',field=>expect(()=>parsePhotoSuggestion({...suggestion(),[field]:1})).toThrow());
test.each([{category:'not-catalog'},{label:''},{label:'x'.repeat(161)},{special_handling:'false'},{confidence:0.99},{reason:'whatever'}])('malformed output %p rejected',patch=>expect(()=>parsePhotoSuggestion({...suggestion(),...patch})).toThrow());
test.each([{confidence:'low'},{reason:'uncertain'},{reason:'multiple_objects'}])('ambiguous output %p never eligible ordinary',patch=>expect(parsePhotoSuggestion({...suggestion(),...patch})).toMatchObject({category:'other',special_handling:true}));
test.each(['materials','other'])('special category %s cannot bypass',category=>expect(parsePhotoSuggestion({...suggestion(),category})).toMatchObject({special_handling:true}));
test('request owner exact and locale validated',()=>expect(parsePhotoRequest('fake',req()).photoPath).toBe(req().photoPath));
test.each([{photoPath:'https://example.invalid/photo.jpg'},{photoPath:'booking_photos/other/draft-fictitious/item/0.jpg'},{draftId:'../bad'},{itemId:'../bad'},{consent:false},{locale:'zz'}])('request %p rejected',patch=>expect(()=>parsePhotoRequest('fake',{...req(),...patch})).toThrow());
test('owned live draft accepted',()=>expect(()=>assertPhotoDraft('fake',parsePhotoRequest('fake',req()),draft(),1000)).not.toThrow());
test.each(['owner','id','expired','item','path','mode'])('draft %s mismatch rejected',which=>{
 const d:any=draft();if(which==='owner')d.owner_uid='other';if(which==='id')d.draft_id='other';if(which==='expired')d.expires_at={toMillis:()=>1000};if(which==='item')d.draft.items[0].id='other';if(which==='path')d.draft.items[0].photos=[];if(which==='mode')d.draft.intake_mode='legacy';
 expect(()=>assertPhotoDraft('fake',parsePhotoRequest('fake',req()),d,1000)).toThrow();
});
test.each([Buffer.alloc(0),Buffer.from('not jpeg'),Buffer.alloc(5*1024*1024+1)])('bad photo bytes rejected',b=>expect(()=>assertPhotoBytes(b)).toThrow());
test.each([{enabled:false},{model:''},{allowedUserUids:[]},{userDailyLimit:0},{globalDailyLimit:0}])('missing approved config %p disabled',patch=>expect(()=>photoAnalysisConfig({...cfg(),...patch},'fake')).toThrow());
test('quota tracks both global and user; busy requests refused',()=>{
 const c=photoAnalysisConfig(cfg(),'fake');expect(()=>checkPhotoQuota({}, {},c,1000)).not.toThrow();
 for(const [u,g] of [[{count:2},{}],[{busyUntil:1001},{}],[{},{count:3}],[{count:-1},{}]])expect(()=>checkPhotoQuota(u,g,c,1000)).toThrow();
});
test('real adapter request sends private bytes, strict schema, no storage and no tools',async()=>{
 const transport=jest.fn(async()=>new Response(JSON.stringify(envelope())));
 expect(await analyzeWithOpenAi(input(),transport as typeof fetch)).toEqual(suggestion());
 const [url,opts]=transport.mock.calls[0] as unknown as [string,RequestInit];const body=JSON.parse(opts.body as string);
 expect(url).toBe('https://api.openai.com/v1/responses');expect(opts.redirect).toBe('error');
 expect(body.store).toBe(false);expect(body.tools).toBeUndefined();expect(body.text.format.strict).toBe(true);
 expect(body.input[0].content[1].image_url).toBe('data:image/jpeg;base64,/9j/AA==');
 expect(JSON.stringify(body)).not.toContain('FAKE-KEY');
});
test.each([
 {status:'incomplete',output:[]},
 {status:'completed',output:[{type:'message',content:[{type:'refusal',refusal:'secret'}]}]},
 {status:'completed',output:[]},
 envelope({...suggestion(),price:1}),
])('provider output refused safely %p',async body=>{
 const transport=jest.fn(async()=>new Response(JSON.stringify(body)));
 await expect(analyzeWithOpenAi(input(),transport as typeof fetch)).rejects.toMatchObject({code:'unavailable',message:'Photo analysis unavailable.'});
 expect(transport).toHaveBeenCalledTimes(1);
});
test.each([401,429,500])('HTTP %s has no raw error leak or automatic retry',async status=>{
 const transport=jest.fn(async()=>new Response('secret error',{status}));
 await expect(analyzeWithOpenAi(input(),transport as typeof fetch)).rejects.toMatchObject({code:'unavailable'});
 expect(transport).toHaveBeenCalledTimes(1);
});
test('timeout aborts and cleans timers',async()=>{
 jest.useFakeTimers();const transport=jest.fn((_url:unknown,opts:RequestInit)=>new Promise<Response>((_resolve,reject)=>opts.signal!.addEventListener('abort',()=>reject(Error('timeout')))));
 const result=analyzeWithOpenAi(input(),transport as typeof fetch);const assertion=expect(result).rejects.toMatchObject({code:'unavailable'});
 await jest.advanceTimersByTimeAsync(25000);await assertion;expect(jest.getTimerCount()).toBe(0);jest.useRealTimers();
});
test('default real transport forbidden in demo/test environments',async()=>{
 const old=process.env.GCLOUD_PROJECT;process.env.GCLOUD_PROJECT='demo-movik-test';
 try {await expect(analyzeWithOpenAi(input())).rejects.toMatchObject({code:'failed-precondition'});}
 finally {if(old===undefined)delete process.env.GCLOUD_PROJECT;else process.env.GCLOUD_PROJECT=old;}
});

test.each(['line\nbreak','<hidden>'])('control/markup label rejected %p',label=>expect(()=>parsePhotoSuggestion({...suggestion(),label})).toThrow());
