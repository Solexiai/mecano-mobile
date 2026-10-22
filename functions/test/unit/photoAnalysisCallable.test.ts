jest.mock('../../src/lib/admin',()=>({db:{doc:jest.fn(),runTransaction:jest.fn()},admin:{storage:jest.fn()}}));
jest.mock('../../src/lib/openAiPhotoAnalyzer',()=>({analyzeWithOpenAi:jest.fn()}));
jest.mock('firebase-functions/params',()=>({defineSecret:()=>({value:()=> 'FAKE-KEY'})}));
import {db,admin} from '../../src/lib/admin';
import {analyzeWithOpenAi} from '../../src/lib/openAiPhotoAnalyzer';
import {handleAnalyzeBookingPhoto} from '../../src/functions/analyzeBookingPhoto';
const path='booking_photos/fake/draft-fictitious/item/0.jpg';
let data:Record<string,any>, tx:any, file:any;
const request=()=>({auth:{uid:'fake',token:{}},data:{draftId:'draft-fictitious',itemId:'item',photoPath:path,locale:'fr',consent:true}} as any);
beforeEach(()=>{
 jest.clearAllMocks();
 data={
 'system_config/photo_analysis':{enabled:true,provider:'openai',model:'TEST-MODEL',allowedUserUids:['fake'],userDailyLimit:2,globalDailyLimit:3},
 'booking_drafts/fake':{owner_uid:'fake',draft_id:'draft-fictitious',expires_at:{toMillis:()=>Date.now()+60000},draft:{intake_mode:'photo_assisted',items:[{id:'item',photos:[path]}]}},
 };
 (db.doc as jest.Mock).mockImplementation((path:string)=>({path,get:async()=>({data:()=>data[path]})}));
 let wrote=false;tx={get:jest.fn(async(ref:any)=>{if(wrote)throw Error('read after write');return {data:()=>data[ref.path]};}),
 set:jest.fn((ref:any,value:any)=>{wrote=true;data[ref.path]=value;}),update:jest.fn((ref:any,value:any)=>{wrote=true;data[ref.path]={...data[ref.path],...value};})};
 (db.runTransaction as jest.Mock).mockImplementation(async fn=>{wrote=false;return fn(tx);});
 file={getMetadata:jest.fn(async()=>[{size:4,contentType:'image/jpeg',generation:'123'}]),download:jest.fn(async()=>[Buffer.from([255,216,255,0])])};
 (admin.storage as unknown as jest.Mock).mockReturnValue({bucket:()=>({file:jest.fn(()=>file)})});
 (analyzeWithOpenAi as jest.Mock).mockResolvedValue({category:'sofa',label:'Fictitious sofa',confidence:'high',special_handling:false,reason:'ordinary'});
});
test('authorized callable reserves budgets, releases lease; no mission or money writes',async()=>{
 const result=await handleAnalyzeBookingPhoto(request());expect(result).toMatchObject({photoPath:path,requiresConfirmation:true,measurementsVerified:false,quoteAuthorized:false});
 expect(analyzeWithOpenAi).toHaveBeenCalledTimes(1);
 expect(file.download).toHaveBeenCalledWith({start:0,end:5242880});
 const writes=[...tx.set.mock.calls,...tx.update.mock.calls];expect(writes.every(([ref]:any)=>ref.path.startsWith('photo_analysis_usage/'))).toBe(true);
 const users=Object.entries(data).filter(([k])=>k.startsWith('photo_analysis_usage/')&&!k.includes('global_'));
 expect(users[0][1]).toMatchObject({count:1,busyUntil:0,token:null});
});
test('unauthenticated rejected before all I/O',async()=>{
 await expect(handleAnalyzeBookingPhoto({...request(),auth:undefined})).rejects.toMatchObject({code:'unauthenticated'});
 expect(db.doc).not.toHaveBeenCalled();expect(admin.storage).not.toHaveBeenCalled();
});
test.each(['disabled','foreign','expired','missing-photo','wrong-path','consent'])('%s never reaches provider',async reason=>{
 const r=request();
 if(reason==='disabled')data['system_config/photo_analysis'].enabled=false;
 if(reason==='foreign')data['booking_drafts/fake'].owner_uid='other';
 if(reason==='expired')data['booking_drafts/fake'].expires_at={toMillis:()=>1};
 if(reason==='missing-photo')data['booking_drafts/fake'].draft.items[0].photos=[];
 if(reason==='wrong-path')r.data.photoPath='booking_photos/other/draft-fictitious/item/0.jpg';
 if(reason==='consent')r.data.consent=false;
 await expect(handleAnalyzeBookingPhoto(r)).rejects.toBeDefined();expect(analyzeWithOpenAi).not.toHaveBeenCalled();
});
test.each(['large','type','signature'])('invalid storage %s refused',async kind=>{
 if(kind==='large')file.getMetadata.mockResolvedValue([{size:6000000,contentType:'image/jpeg',generation:'123'}]);
 if(kind==='type')file.getMetadata.mockResolvedValue([{size:4,contentType:'text/plain',generation:'123'}]);
 if(kind==='signature')file.download.mockResolvedValue([Buffer.from('bad')]);
 await expect(handleAnalyzeBookingPhoto(request())).rejects.toMatchObject({code:'invalid-argument'});
 expect(analyzeWithOpenAi).not.toHaveBeenCalled();
});
test('provider failure consumes one attempt and releases busy lease; retry then allowed',async()=>{
 (analyzeWithOpenAi as jest.Mock).mockRejectedValueOnce(Error('RAW SECRET ERROR'));
 await expect(handleAnalyzeBookingPhoto(request())).rejects.toMatchObject({code:'unavailable',message:'Photo analysis unavailable.'});
 await expect(handleAnalyzeBookingPhoto(request())).resolves.toMatchObject({requiresConfirmation:true});
 await expect(handleAnalyzeBookingPhoto(request())).rejects.toMatchObject({code:'resource-exhausted'});
 expect(analyzeWithOpenAi).toHaveBeenCalledTimes(2);
});
test('draft replaced during provider request returns no suggestion',async()=>{
 (analyzeWithOpenAi as jest.Mock).mockImplementation(async()=>{data['booking_drafts/fake'].draft_id='new-draft';return {};});
 await expect(handleAnalyzeBookingPhoto(request())).rejects.toMatchObject({code:'permission-denied'});
});
test('concurrent second request refused while first awaits provider',async()=>{
 let finish!:(x:any)=>void;
 (analyzeWithOpenAi as jest.Mock).mockImplementation(()=>new Promise(resolve=>{finish=resolve;}));
 const first=handleAnalyzeBookingPhoto(request());
 for(let i=0;i<30&&!finish;i++)await Promise.resolve();
 expect(finish).toBeDefined();
 await expect(handleAnalyzeBookingPhoto(request())).rejects.toMatchObject({code:'resource-exhausted'});
 finish({category:'sofa'});await first;expect(analyzeWithOpenAi).toHaveBeenCalledTimes(1);
});
