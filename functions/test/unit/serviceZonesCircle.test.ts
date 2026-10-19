jest.mock('../../src/lib/admin', () => ({db:{doc:jest.fn()}}));
import {isWithinServiceZones} from '../../src/lib/serviceZones';
const lat=45.39856, lng=-72.72225;
const config:any={enabled:true,zones:[{name:'Granby',type:'circle',center_lat:lat,center_lng:lng,radius_km:40}]};
function point(km:number,bearing:number):[number,number] {
  const a=lat*Math.PI/180,b=lng*Math.PI/180,d=km/6371.0088,t=bearing*Math.PI/180;
  const p=Math.asin(Math.sin(a)*Math.cos(d)+Math.cos(a)*Math.sin(d)*Math.cos(t));
  return [p*180/Math.PI,(b+Math.atan2(Math.sin(t)*Math.sin(d)*Math.cos(a),Math.cos(d)-Math.sin(a)*Math.sin(p)))*180/Math.PI];
}
test('city center is served',()=>expect(isWithinServiceZones(lat,lng,config)).toBe(true));
test.each([0,45,90,135,180,225,270,315])('inside/outside at bearing %s',bearing=>{
  expect(isWithinServiceZones(...point(39.999,bearing),config)).toBe(true);
  expect(isWithinServiceZones(...point(40.001,bearing),config)).toBe(false);
});
test.each([NaN,Infinity,91])('invalid latitude %s rejected',value=>expect(isWithinServiceZones(value,lng,config)).toBe(false));
test('invalid circle fails closed',()=>expect(isWithinServiceZones(lat,lng,{enabled:true,zones:[{...config.zones[0],radius_km:-1}]})).toBe(false));
test('legacy rectangle retained',()=>expect(isWithinServiceZones(lat,lng,{enabled:true,zones:[{name:'legacy',min_lat:45,max_lat:46,min_lng:-73,max_lng:-72}]})).toBe(true));
test('disabled legacy behavior retained',()=>expect(isWithinServiceZones(lat,lng,{enabled:false,zones:[]})).toBe(true));
