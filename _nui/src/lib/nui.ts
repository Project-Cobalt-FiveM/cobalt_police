import type { Messages, Requests } from './types';

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

type Payload<K extends keyof Requests> = Requests[K][0];
type Reply<K extends keyof Requests> = Requests[K][1];
type Args<K extends keyof Requests> = Payload<K> extends void ? [] : [Payload<K>];

export type MockHandlers = { [K in keyof Requests]: (payload: Payload<K>) => Reply<K> };

export const inGame = 'GetParentResourceName' in window;

const resourceName = window.GetParentResourceName?.() ?? 'cobalt_police';

let mocks: Promise<MockHandlers> | null = null;

async function fetchMock<K extends keyof Requests>(name: K, payload: Payload<K>): Promise<Reply<K>> {
  mocks ??= import('./mock').then((module) => module.handlers);
  const handler = (await mocks)[name] as (payload: Payload<K>) => Reply<K>;
  return structuredClone(handler(payload));
}

export async function fetchNui<K extends keyof Requests>(name: K, ...args: Args<K>): Promise<Reply<K>> {
  const payload = args[0];

  if (import.meta.env.DEV && !inGame) return fetchMock(name, payload as Payload<K>);

  const response = await fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload ?? {}),
  });

  return (await response.json()) as Reply<K>;
}

const actions: ReadonlySet<string> = new Set<Messages['action']>([
  'open',
  'close',
  'callAdded',
  'callUpdated',
  'callRemoved',
  'unitsUpdated',
  'alert',
  'alertClear',
]);

function isMessage(value: unknown): value is Messages {
  if (typeof value !== 'object' || value === null || !('action' in value)) return false;

  return typeof value.action === 'string' && actions.has(value.action);
}

export function onMessage(handler: (message: Messages) => void): () => void {
  const listener = (event: MessageEvent<unknown>) => {
    if (isMessage(event.data)) handler(event.data);
  };

  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

export async function sendMockOpen(): Promise<void> {
  if (!import.meta.env.DEV || inGame) return;

  const module = await import('./mock');
  if (location.hash !== '#popup') window.postMessage(module.openMessage, '*');
  module.startAlerts();
}
