import {photoAnalysisConfig} from '../../src/lib/photoAnalysis';
const config={enabled:true,provider:'openai',model:'TEST',allowedUserUids:['pilot'],userDailyLimit:10,globalDailyLimit:100};
test('explicit authenticated rollout accepts a different signed-in uid',()=>expect(()=>photoAnalysisConfig({...config,allowAuthenticatedUsers:true},'customer')).not.toThrow());
test('private rollout remains restricted',()=>expect(()=>photoAnalysisConfig(config,'customer')).toThrow());
test.each([false,'true',1,null])('non-boolean rollout %p never enables public access',value=>expect(()=>photoAnalysisConfig({...config,allowAuthenticatedUsers:value},'customer')).toThrow());
test('disabled switch remains authoritative',()=>expect(()=>photoAnalysisConfig({...config,allowAuthenticatedUsers:true,enabled:false},'customer')).toThrow());
test('quotas remain required in public rollout',()=>expect(()=>photoAnalysisConfig({...config,allowAuthenticatedUsers:true,globalDailyLimit:0},'customer')).toThrow());
