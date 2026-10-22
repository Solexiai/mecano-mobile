import { parseBookingPolicy, requireBookingConsent } from '../../src/lib/bookingContract';
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
test('approval, versioned documents and payment cycle are mandatory',()=>{
 for(const value of [null,{}, {...testBookingPolicy(),approved:false},{...testBookingPolicy(),schema_version:1},{...testBookingPolicy(),payment_cycle:'immediate_capture'},{...testBookingPolicy(),documents:{}},{...testBookingPolicy(),approval_reference:''}]) expect(parseBookingPolicy(value)).toBeNull();
});
test('hash is stable across object key ordering and ignores forged supplied hash',()=>{
 const p=testBookingPolicy();
 expect(parseBookingPolicy({...p,contract_hash:'forged'})?.contract_hash).toBe(p.contract_hash);
 expect(parseBookingPolicy(Object.fromEntries(Object.entries(p).reverse()))?.contract_hash).toBe(p.contract_hash);
});
test.each(['booking','terms','privacy'])('missing or unsafe %s document is refused',key=>{
 const p=testBookingPolicy();
 for(const url of ['http://example.invalid/terms','javascript:alert(1)','https://user:password@example.invalid/terms']) expect(parseBookingPolicy({...p,documents:{...p.documents,[key]:{...p.documents.terms,url}}})).toBeNull();
 expect(parseBookingPolicy({...p,documents:{...p.documents,[key]:{...p.documents.terms,content:{fr:''}}}})).toBeNull();
});
test('same version with changed summary or body invalidates acceptance',()=>{
 const p=testBookingPolicy(),c=testBookingConsent();
 expect(()=>requireBookingConsent(p,c)).not.toThrow();
 for(const updated of [{...p,payment_text:{fr:'OTHER TEST TEXT'}},{...p,documents:{...p.documents,privacy:{...p.documents.privacy,content:{fr:'OTHER PRIVACY TEXT'}}}}]) {
  const next=parseBookingPolicy(updated)!;expect(next.contract_hash).not.toBe(p.contract_hash);expect(()=>requireBookingConsent(next,c)).toThrow();
 }
});
test('privacy presentation alone cannot imply contract acceptance',()=>{
 expect(()=>requireBookingConsent(testBookingPolicy(),{...testBookingConsent(),accepted:false})).toThrow();
});
