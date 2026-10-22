import { parsePhotoSuggestion } from '../../src/lib/photoAnalysis';
const base={category:'armchair',label:'Fauteuil',confidence:'high',special_handling:false,reason:'ordinary'};
const hint={basis:'typical_object',confidence:'low',length_cm:{min:70,max:110},width_cm:{min:70,max:110},height_cm:{min:70,max:120}};
test('accepts bounded advisory ranges, without actual measurements or price',()=>{
 expect(parsePhotoSuggestion({...base,size_estimate:hint})).toMatchObject({size_estimate:hint});
 expect(parsePhotoSuggestion({...base,size_estimate:hint})).not.toHaveProperty('weight');
});
test('unknown size stays null',()=>expect(parsePhotoSuggestion({...base,size_estimate:null})).toMatchObject({size_estimate:null}));
test.each([{}, {...hint,length_cm:{min:-1,max:100}},{...hint,width_cm:{min:100,max:80}},{...hint,height_cm:{min:1,max:999999}},{...hint,confidence:'high'},{...hint,basis:'measured'},{...hint,price:1}])('rejects malformed or overconfident estimate %p',size_estimate=>expect(()=>parsePhotoSuggestion({...base,size_estimate})).toThrow());
test('ambiguous object never supplies apparent measured dimensions',()=>expect(parsePhotoSuggestion({...base,confidence:'low',size_estimate:hint})).toMatchObject({category:'other',size_estimate:null}));
test('v1 identification remains compatible',()=>expect(parsePhotoSuggestion(base)).toEqual(base));
