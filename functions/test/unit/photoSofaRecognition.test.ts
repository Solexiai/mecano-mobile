
import { analyzeWithOpenAi } from '../../src/lib/openAiPhotoAnalyzer';
test('vision contract distinguishes seating identity from uncertain size and background furniture', async () => {
  const sofa = {category:'sofa',label:'Divan sectionnel en tissu',confidence:'high',special_handling:false,reason:'ordinary',size_estimate:null};
  const transport = jest.fn(async()=>new Response(JSON.stringify({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(sofa)}]}]})));
  expect(await analyzeWithOpenAi({bytes:Buffer.from([255,216,255,0]),locale:'fr',model:'FAKE',apiKey:'FAKE'},transport as typeof fetch)).toEqual(sofa);
  const args=transport.mock.calls[0] as unknown as [string,RequestInit];
  const body=JSON.parse(args[1].body as string);
  expect(body.instructions).toContain('divan');
  expect(body.instructions).toContain('sectional');
  expect(body.instructions).toContain('armchair');
  expect(body.instructions).toContain('Do not lower category confidence just because dimensions or weight are unknown');
  expect(body.instructions).toContain('Background furniture');
  expect(body.input[0].content[1].detail).toBe('high');
  expect(body.store).toBe(false);
});
