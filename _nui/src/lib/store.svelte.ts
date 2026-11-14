import { fetchNui } from './nui';
import { nowSeconds } from './format';
import { setLocales, t } from './locale.svelte';
import type {
  Call,
  CallChange,
  Counts,
  IncidentKind,
  Keybinds,
  Messages,
  Officer,
  Ok,
  Page,
  Permission,
  Person,
  Settings,
  Unit,
  UnitStatus,
} from './types';

export type Editor = { id: number | null; kind: IncidentKind; suspects: Person[] };

export type Route =
  | { page: Exclude<Page, 'citizens' | 'incidents' | 'vehicles' | 'weapons'> }
  | { page: 'citizens'; citizenid: string | null }
  | { page: 'vehicles'; plate: string | null }
  | { page: 'weapons'; serial: string | null }
  | { page: 'incidents'; editor: Editor | null };

export type Alert = {
  call: Call;
  distance: number;
  seconds: number;
  respondKey: string;
  key: number;
};

export type Toast = { key: number; tone: 'error' | 'success'; text: string };

const TOAST_MS = 5000;

type OpenData = Extract<Messages, { action: 'open' }>['data'];

let sequence = 0;

function routeFor(page: Page, citizenid: string | null): Route {
  switch (page) {
    case 'citizens':
      return { page, citizenid };
    case 'vehicles':
      return { page, plate: null };
    case 'weapons':
      return { page, serial: null };
    case 'incidents':
      return { page, editor: null };
    default:
      return { page };
  }
}

class Mdt {
  visible = $state(false);
  officer = $state<Officer | null>(null);
  settings = $state<Settings | null>(null);
  keybinds = $state<Keybinds>({ respond: 'E', panic: 'O' });
  route = $state<Route>({ page: 'dashboard' });
  calls = $state<Call[]>([]);
  units = $state<Unit[]>([]);
  counts = $state<Counts>({ warrants: 0, bolos: 0 });
  alerts = $state<Alert[]>([]);
  toast = $state<Toast | null>(null);
  now = $state(nowSeconds());

  openCalls = $derived(this.calls.filter((call) => call.status === 'open'));
  myUnit = $derived(
    this.units.find((unit) => unit.members.some((member) => member.citizenid === this.officer?.citizenid)) ?? null,
  );

  #layers: (() => void)[] = [];
  #toastTimer: ReturnType<typeof setTimeout> | undefined;

  constructor() {
    $effect.root(() => {
      $effect(() => {
        if (!this.visible && this.alerts.length === 0) return;

        this.now = nowSeconds();
        const timer = setInterval(() => (this.now = nowSeconds()), 1000);
        return () => clearInterval(timer);
      });
    });
  }

  can(permission: Permission): boolean {
    const permissions = this.officer?.permissions;
    if (!permissions) return false;

    return permissions.administrator || permissions[permission];
  }

  has(page: Page): boolean {
    return this.officer?.pages.includes(page) ?? false;
  }

  navigate(route: Route): void {
    if (!this.has(route.page)) return;
    this.route = route;
  }

  go(page: Page): void {
    this.navigate(routeFor(page, null));
  }

  openCitizen(citizenid: string): void {
    this.navigate({ page: 'citizens', citizenid });
  }

  openIncident(id: number): void {
    this.navigate({ page: 'incidents', editor: { id, kind: 'incident', suspects: [] } });
  }

  newIncident(kind: IncidentKind = 'incident', suspects: Person[] = []): void {
    this.navigate({ page: 'incidents', editor: { id: null, kind, suspects } });
  }

  pushLayer(close: () => void): () => void {
    this.#layers.push(close);
    return () => {
      this.#layers = this.#layers.filter((layer) => layer !== close);
    };
  }

  escape(): void {
    const layer = this.#layers.at(-1);
    if (layer) {
      layer();
      return;
    }

    this.close();
  }

  close(): void {
    if (!this.visible) return;

    this.visible = false;
    void fetchNui('close');
  }

  notify(text: string, tone: Toast['tone'] = 'success'): void {
    this.toast = { key: ++sequence, tone, text };
    this.resumeToast();
  }

  pauseToast(): void {
    clearTimeout(this.#toastTimer);
  }

  resumeToast(): void {
    clearTimeout(this.#toastTimer);
    this.#toastTimer = setTimeout(() => (this.toast = null), TOAST_MS);
  }

  report(result: Ok | false, success?: string): boolean {
    if (!result || !result.ok) {
      this.notify(result ? result.error : t('ui.common.request_failed'), 'error');
      return false;
    }

    if (success) this.notify(success);
    return true;
  }

  async boot(): Promise<void> {
    const reply = await fetchNui('boot');
    setLocales(reply.locales);
  }

  async refreshCounts(): Promise<void> {
    const counts = await fetchNui('getCounts');
    if (!counts || !('warrants' in counts)) return;

    this.counts = counts;
  }

  async refreshCalls(): Promise<void> {
    const calls = await fetchNui('getCalls');
    if (Array.isArray(calls)) this.calls = calls;
  }

  async refreshUnits(): Promise<void> {
    const units = await fetchNui('getUnits');
    if (Array.isArray(units)) this.units = units;
  }

  async setStatus(status: UnitStatus): Promise<void> {
    if (!this.officer) return;

    const previous = this.officer.status;
    this.officer.status = status;

    if (!this.report(await fetchNui('setStatus', { status }))) this.officer.status = previous;
  }

  #open(data: OpenData): void {
    this.officer = data.officer;
    this.settings = data.settings;
    this.keybinds = data.keybinds;
    this.visible = true;

    const page =
      data.page && data.officer.pages.includes(data.page) ? data.page : (data.officer.pages[0] ?? 'dashboard');
    this.route = routeFor(page, data.citizenid);

    if (page !== 'dashboard') void this.refreshCounts();
    void this.refreshCalls();
    void this.refreshUnits();
  }

  #upsertCall(call: Call): void {
    const index = this.calls.findIndex((existing) => existing.id === call.id);

    if (index === -1) {
      this.calls = [call, ...this.calls];
      return;
    }

    this.calls[index] = call;
  }

  #applyChange(change: CallChange): void {
    const call = this.calls.find((existing) => existing.id === change.id);
    if (!call) return;

    switch (change.change) {
      case 'responders':
        call.responders = change.responders;
        break;
      case 'note':
        if (change.dropOldest) call.notes.shift();
        call.notes.push(change.note);
        break;
      case 'status':
        call.status = change.status;
        break;
      default: {
        const exhaustive: never = change;
        return exhaustive;
      }
    }
  }

  #dropAlert(id: number): void {
    this.alerts = this.alerts.filter((alert) => alert.call.id !== id);
  }

  handle(message: Messages): void {
    switch (message.action) {
      case 'open':
        this.#open(message.data);
        break;
      case 'close':
        this.visible = false;
        break;
      case 'callAdded':
        this.#upsertCall(message.data);
        break;
      case 'callUpdated':
        this.#applyChange(message.data);
        break;
      case 'callRemoved':
        this.calls = this.calls.filter((call) => call.id !== message.data.id);
        break;
      case 'unitsUpdated':
        this.units = message.data;
        break;
      case 'alert': {
        const { call, distance, seconds, respondKey } = message.data;
        const key = ++sequence;
        this.alerts = [
          { call, distance, seconds, respondKey, key },
          ...this.alerts.filter((alert) => alert.call.id !== call.id),
        ];
        setTimeout(() => {
          this.alerts = this.alerts.filter((alert) => alert.key !== key);
        }, seconds * 1000);
        break;
      }
      case 'alertClear':
        this.#dropAlert(message.data.id);
        break;
      default: {
        const exhaustive: never = message;
        return exhaustive;
      }
    }
  }
}

export const mdt = new Mdt();
