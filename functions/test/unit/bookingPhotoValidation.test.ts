jest.mock('../../src/lib/admin',()=>({admin:{storage:jest.fn()}}));
import {admin} from '../../src/lib/admin';
import {validateBookingPhotos} from '../../src/lib/bookingPhotoValidation';
import {normalizeLoad} from '../../src/lib/booking';
let file:jest.Mock,metadata:jest.Mock;
function load(){return normalizeLoad({draft_id:'synthetic-draft',intake_mode:'photo_assisted',timing_mode:'immediate',requested_at:null,items:[{id:'one',category:'sofa',label:'Synthetic sofa',quantity:1,length:null,width:null,height:null,weight:null,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true,identification_confirmed:true,special_handling:false,photos:['booking_photos/synthetic/synthetic-draft/one/0.jpg']}],pickup:{floor:0,stairs:false,elevator:false,help:false},dropoff:{floor:0,stairs:false,elevator:false,help:false},handlers:1,equipment:[]});}
beforeEach(()=>{
 jest.clearAllMocks();metadata=jest.fn(async()=>[{contentType:'image/jpeg',size:123,generation:'1'}]);file=jest.fn(()=>({getMetadata:metadata}));
 (admin.storage as unknown as jest.Mock).mockReturnValue({bucket:()=>({file})});
});
test('owned immutable existing photo validated without downloading or public URL',async()=>{
 await validateBookingPhotos(load(),'synthetic');
 expect(file).toHaveBeenCalledWith('booking_photos/synthetic/synthetic-draft/one/0.jpg');
 expect(metadata).toHaveBeenCalledTimes(1);
});
test.each(['foreign-customer','foreign-item','bad-slot','public-url','duplicate'])('%s refused before Storage',async kind=>{
 const b=load(),p=b.items[0].photos[0];
 b.items[0].photos=kind==='foreign-customer'?[p.replace('/synthetic/','/other/')]:kind==='foreign-item'?[p.replace('/one/','/two/')]:kind==='bad-slot'?[p.replace('0.jpg','3.jpg')]:kind==='public-url'?['https://example.invalid/photo.jpg']:[p,p];
 await expect(validateBookingPhotos(b,'synthetic')).rejects.toMatchObject({code:'invalid-argument'});expect(admin.storage).not.toHaveBeenCalled();
});
test.each(['missing','oversized','invalid-type','zero-size','missing-generation'])('%s fails closed',async kind=>{
 if(kind==='missing')metadata.mockRejectedValue(Object.assign(Error('private raw exception'),{code:404}));
 else metadata.mockResolvedValue([{contentType:kind==='invalid-type'?'text/plain':'image/jpeg',size:kind==='oversized'?5242881:kind==='zero-size'?0:123,generation:kind==='missing-generation'?undefined:'1'}]);
 await expect(validateBookingPhotos(load(),'synthetic')).rejects.toMatchObject({code:'failed-precondition',message:'Une photo est indisponible. Ajoutez une photo avant de demander le devis.'});
});
test('legacy booking never introduces a new Storage call',async()=>{
 const b=load();delete b.intake_mode;await validateBookingPhotos(b,'synthetic');expect(admin.storage).not.toHaveBeenCalled();
});
test('missing photo remains a review validation, no network call',async()=>{
 const b=load();b.items[0].photos=[];await validateBookingPhotos(b,'synthetic');expect(admin.storage).not.toHaveBeenCalled();
});
