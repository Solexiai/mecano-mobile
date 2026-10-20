import { normalizeDriverAgenda, intervalIsAvailable } from '../../src/lib/driverAgenda';
const slot=(start='2026-11-01T13:00:00Z',end='2026-11-01T20:00:00Z')=>({start,end});
test('an absent answer never becomes availability',()=>{expect(()=>normalizeDriverAgenda({})).toThrow();});
test('normalizes explicit UTC intervals without invented working hours',()=>{
 const a=normalizeDriverAgenda({windows:[slot()],blocked:[]});
 expect(a.windows[0].start).toBe('2026-11-01T13:00:00.000Z');
 expect(intervalIsAvailable(a,slot())).toBe(true);
});
test.each([null,{},'bad'])('rejects malformed intervals %s',v=>{
 expect(()=>normalizeDriverAgenda({windows:[v],blocked:[]})).toThrow();
});
test.each([
 slot('2026-11-01T13:00:00','2026-11-01T14:00:00'),
 slot('2026-11-01T15:00:00Z','2026-11-01T14:00:00Z'),
 slot('2026-11-01T15:00:00Z','2026-11-01T15:00:00Z'),
 slot('2026-02-30T13:00:00Z','2026-03-01T15:00:00Z'),
])('rejects ambiguous/invalid dates %j',v=>expect(()=>normalizeDriverAgenda({windows:[v],blocked:[]})).toThrow());
test('blocked periods override available windows',()=>{
 const a=normalizeDriverAgenda({windows:[slot()],blocked:[slot('2026-11-01T15:00:00Z','2026-11-01T16:00:00Z')]});
 expect(intervalIsAvailable(a,slot('2026-11-01T14:30:00Z','2026-11-01T15:30:00Z'))).toBe(false);
 expect(intervalIsAvailable(a,slot('2026-11-01T16:00:00Z','2026-11-01T17:00:00Z'))).toBe(true);
});
test('whole mission interval must fit, not just its start',()=>{
 const a=normalizeDriverAgenda({windows:[slot()],blocked:[]});
 expect(intervalIsAvailable(a,slot('2026-11-01T19:00:00Z','2026-11-01T21:00:00Z'))).toBe(false);
});
test('contiguous windows merge; a gap never counts as free time',()=>{
 const a=normalizeDriverAgenda({windows:[slot('2026-11-01T13:00:00Z','2026-11-01T14:00:00Z'),slot('2026-11-01T14:00:00Z','2026-11-01T15:00:00Z')],blocked:[]});
 expect(a.windows).toHaveLength(1);
 expect(intervalIsAvailable(a,slot('2026-11-01T13:30:00Z','2026-11-01T14:30:00Z'))).toBe(true);
});
test('empty calendar is explicitly unavailable',()=>{
 expect(intervalIsAvailable(normalizeDriverAgenda({windows:[],blocked:[]}),slot())).toBe(false);
});
test('offsets are converted to UTC, including daylight-saving fallback',()=>{
 const a=normalizeDriverAgenda({windows:[slot('2026-11-01T01:30:00-04:00','2026-11-01T01:30:00-05:00')],blocked:[]});
 expect(Date.parse(a.windows[0].end)-Date.parse(a.windows[0].start)).toBe(3600000);
});
