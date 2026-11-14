import type { Charge, Licence, SuspectCharge } from './types';

export type Totals = { months: number; fine: number; points: number };

export function totals(items: SuspectCharge[], charges: ReadonlyMap<number, Charge>): Totals {
  return items.reduce<Totals>(
    (sum, item) => {
      const charge = charges.get(item.chargeId);
      if (!charge) return sum;

      return {
        months: sum.months + charge.months * item.counts,
        fine: sum.fine + charge.fine * item.counts,
        points: sum.points + charge.points * item.counts,
      };
    },
    { months: 0, fine: 0, points: 0 },
  );
}

export type PointsOutcome = { licence: Licence; reaches: number; limit: number; suspends: boolean };

export function pointsOutcome(licences: Licence[], added: number): PointsOutcome | null {
  const licence = licences.find((entry) => entry.pointsLimit != null && entry.status === 'valid');
  if (licence?.pointsLimit == null) return null;

  const reaches = licence.points + added;
  return { licence, reaches, limit: licence.pointsLimit, suspends: added > 0 && reaches >= licence.pointsLimit };
}

export function toLocalInput(seconds: number): string {
  const date = new Date(seconds * 1000);
  const offset = date.getTimezoneOffset() * 60000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 16);
}

export function fromLocalInput(value: string): number | null {
  const time = new Date(value).getTime();
  return Number.isNaN(time) ? null : Math.floor(time / 1000);
}
