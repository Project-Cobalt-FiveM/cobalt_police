import { t } from './locale.svelte';
import type { Bolo, ChargeClass, IncidentKind, LicenceStatus, UnitStatus, VehicleState, Warrant, WarrantType } from './types';

const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

const weekdays = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

export function toDate(seconds: number): Date {
  return new Date(seconds * 1000);
}

export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

function pad(value: number): string {
  return value.toString().padStart(2, '0');
}

export function clockTime(seconds: number): string {
  const date = toDate(seconds);
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function monthShort(date: Date): string {
  return t(`ui.date.month_short.${months[date.getMonth()]}`);
}

export function shortDate(seconds: number): string {
  const date = toDate(seconds);
  return t('ui.date.short', date.getDate(), monthShort(date));
}

export function longDate(seconds: number): string {
  const date = toDate(seconds);
  return t('ui.date.long', date.getDate(), monthShort(date), date.getFullYear());
}

export function dateTime(seconds: number): string {
  return t('ui.date.date_time', shortDate(seconds), clockTime(seconds));
}

export function shiftLabel(seconds: number): string {
  const date = toDate(seconds);
  const hour = date.getHours();
  const shift = hour >= 6 && hour < 18 ? 'ui.date.day_shift' : 'ui.date.night_shift';
  return t(shift, t(`ui.date.weekday.${weekdays[date.getDay()]}`), date.getDate(), t(`ui.date.month.${months[date.getMonth()]}`));
}

function span(diff: number): string {
  if (diff < 3600) return t('ui.time.minutes', Math.floor(diff / 60));
  if (diff < 86400) return t('ui.time.hours', Math.floor(diff / 3600));
  return t('ui.time.days', Math.floor(diff / 86400));
}

export function age(seconds: number, now: number): string {
  const diff = Math.max(0, now - seconds);

  if (diff < 60) return t('ui.time.now');
  return span(diff);
}

export function ago(seconds: number, now: number): string {
  return now - seconds < 60 ? t('ui.time.just_now') : t('ui.time.ago', age(seconds, now));
}

export function elapsed(seconds: number, now: number): string {
  const diff = Math.max(0, now - seconds);

  if (diff < 60) return `0:${pad(diff)}`;
  return span(diff);
}

export function filedAt(seconds: number, now: number): string {
  const date = toDate(seconds);
  const today = toDate(now);
  const days = Math.floor(
    (new Date(today.toDateString()).getTime() - new Date(date.toDateString()).getTime()) / 86400000,
  );

  if (days === 0) return clockTime(seconds);
  if (days === 1) return t('ui.date.yesterday');
  return shortDate(seconds);
}

export function remaining(seconds: number, now: number): string {
  const diff = seconds - now;

  if (diff <= 0) return t('ui.time.ended');
  if (diff < 3600) return t('ui.time.minutes', Math.ceil(diff / 60));
  if (diff < 172800) return t('ui.time.hours', Math.floor(diff / 3600));
  return t('ui.time.days', Math.floor(diff / 86400));
}

export function money(value: number): string {
  return `$${value.toLocaleString('en-US')}`;
}

export function distance(meters: number): string {
  if (meters < 1000) return t('ui.common.meters', Math.round(meters));
  return t('ui.common.kilometers', (meters / 1000).toFixed(1));
}

export function initials(name: string): string {
  const parts = name.replace(/^(Ofc|Sgt|Lt|Cpt|Det|Dep)\.\s+/, '').split(/\s+/);
  return parts
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');
}

export function plural(count: number, key: string): string {
  return t(`${key}.${count === 1 ? 'one' : 'other'}`, count);
}

export const unitStatuses: UnitStatus[] = ['available', 'busy', 'enroute', 'onscene'];

export function statusLabel(status: UnitStatus | 'offduty'): string {
  return t(`ui.status.${status}`);
}

export const statusDots: Record<UnitStatus, string> = {
  available: 'bg-success',
  busy: 'bg-destructive',
  enroute: 'bg-primary',
  onscene: 'bg-warning',
};

export function classLabel(value: ChargeClass): string {
  return t(`ui.charge_class.${value}`);
}

export const classDots: Record<ChargeClass, string> = {
  felony: 'bg-destructive',
  misdemeanor: 'bg-warning',
  infraction: 'bg-muted-foreground',
};

export function warrantTypeLabel(type: WarrantType): string {
  return t(`ui.warrant_type.${type}`);
}

export function warrantStatusLabel(status: Warrant['status']): string {
  return t(`ui.warrant_status.${status}`);
}

export function boloTypeLabel(type: Bolo['type']): string {
  return t(`ui.bolo_type.${type}`);
}

export function kindLabel(kind: IncidentKind): string {
  return t(`ui.kind.${kind}`);
}

export function vehicleStateLabel(state: VehicleState): string {
  return t(`ui.vehicle_state.${state}`);
}

export function licenceStatusLabel(status: LicenceStatus): string {
  return t(`ui.licence_status.${status}`);
}
