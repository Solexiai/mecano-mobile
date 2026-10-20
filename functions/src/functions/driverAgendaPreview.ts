import { onCall } from 'firebase-functions/v2/https';
import { db } from '../lib/admin';
import { requireSignedIn, requireAnyRole } from '../lib/auth';
import { PlatformRoles } from '../lib/types';
import { failedPrecondition } from '../lib/errors';
import { normalizeDriverAgenda, normalizeAgendaInterval, intervalIsAvailable } from '../lib/driverAgenda';
import { expandRecurrence } from '../lib/agendaRecurrence';
import { overlap, reservationStillActive } from '../lib/driverScheduling';
export const previewDriverAvailability = onCall(async (request) => {
    const ctx = requireSignedIn(request);
    requireAnyRole(ctx, [PlatformRoles.DRIVER]);
    const period = normalizeAgendaInterval(request.data?.period), agenda = normalizeDriverAgenda(request.data?.agenda);
    if (Date.parse(period.end) - Date.parse(period.start) > 35 * 86400000)
        throw failedPrecondition('Consultez au maximum 35 jours à la fois.');
    const external = (await db.doc('driver_calendar_busy/' + ctx.uid).get()).data();
    const reservations = await db.collection('driver_agendas/' + ctx.uid + '/reservations').where('active', '==', true).get();
    const occupied: {
        mission_id: string;
        start: string;
        end: string;
        conflict: boolean;
    }[] = [];
    for (const d of reservations.docs) {
        const r = d.data();
        if (!overlap(period, r as never))
            continue;
        const m = (await db.doc('delivery_requests/' + d.id).get()).data();
        if (reservationStillActive(m, ctx.uid))
            occupied.push({ mission_id: d.id, start: r.start, end: r.end,
                conflict: !intervalIsAvailable(agenda, r as never) || (external?.busy ?? []).some((b: never) => overlap(r as never, b)) });
    }
    return { windows: [...agenda.windows, ...(agenda.recurrence ? expandRecurrence(agenda.recurrence, period) : [])].filter(s => overlap(s, period)),
        blocked: agenda.blocked.filter(s => overlap(s, period)), external_busy: (external?.busy ?? []).filter((s: never) => overlap(s, period)),
        external_status: external?.required ? external.status : 'not_connected', occupied };
});
