<script lang="ts">
  import { onMount } from 'svelte';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import Megaphone from 'phosphor-svelte/lib/Megaphone';
  import PushPin from 'phosphor-svelte/lib/PushPin';
  import PushPinSlash from 'phosphor-svelte/lib/PushPinSlash';
  import Trash from 'phosphor-svelte/lib/Trash';
  import Header from '../components/Header.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Plate from '../components/ui/Plate.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Field from '../components/ui/Field.svelte';
  import Checkbox from '../components/ui/Checkbox.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { age, ago, boloTypeLabel, plural, remaining, shiftLabel, warrantTypeLabel } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Bulletin, Call, Dashboard } from '../lib/types';

  let data = $state<Dashboard | null>(null);
  let posting = $state(false);
  let draft = $state({ title: '', body: '', pinned: false });

  const calls = $derived(mdt.openCalls.slice(0, 3));
  const warnHours = $derived(mdt.settings?.records.warrantWarnHours ?? 48);
  const warnSeconds = $derived(warnHours * 3600);

  async function load() {
    const reply = await fetchNui('getDashboard');
    if (!reply || !('stats' in reply)) return;

    data = reply;
    mdt.counts = { warrants: reply.stats.warrants, bolos: reply.stats.bolos };
  }

  onMount(load);

  function units(call: Call): string {
    const [first, ...rest] = call.responders;
    if (!first) return t('ui.dashboard.unassigned');
    return rest.length ? `${first.callsign} +${rest.length}` : first.callsign;
  }

  async function post() {
    if (!draft.title.trim() || !draft.body.trim()) return;

    if (mdt.report(await fetchNui('postBulletin', { title: draft.title.trim(), body: draft.body.trim(), pinned: draft.pinned }), t('ui.dashboard.bulletin_posted'))) {
      posting = false;
      draft = { title: '', body: '', pinned: false };
      await load();
    }
  }

  async function pin(bulletin: Bulletin) {
    if (mdt.report(await fetchNui('pinBulletin', { id: bulletin.id, pinned: !bulletin.pinned }))) await load();
  }

  async function remove(bulletin: Bulletin) {
    if (mdt.report(await fetchNui('deleteBulletin', { id: bulletin.id }), t('ui.dashboard.bulletin_deleted'))) await load();
  }
</script>

<Header title={t('ui.page.dashboard')} subtitle={shiftLabel(mdt.now)}>
  {#snippet action()}
    {#if mdt.can('createIncident')}
      <Button variant="primary" onclick={() => mdt.newIncident()}><PlusSquare size="1rem" />{t('ui.common.new_incident')}</Button>
    {/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-6 overflow-y-auto p-6">
    <div class="grid grid-cols-4 gap-3">
      {#each [
        { label: t('ui.dashboard.active_warrants'), value: data?.stats.warrants, note: data ? t('ui.dashboard.warrants_expiring', data.stats.warrantsExpiring, warnHours) : '', warn: (data?.stats.warrantsExpiring ?? 0) > 0, page: 'warrants' as const },
        { label: t('ui.dashboard.active_bolos'), value: data?.stats.bolos, note: data ? t('ui.dashboard.bolo_split', plural(data.stats.bolosVehicles, 'ui.plural.vehicles'), plural(data.stats.bolosPeople, 'ui.plural.people')) : '', warn: false, page: 'bolos' as const },
        { label: t('ui.dashboard.incidents_week'), value: data?.stats.incidentsWeek, note: data ? t('ui.dashboard.reports_filed', plural(data.stats.reportsWeek, 'ui.plural.reports')) : '', warn: false, page: 'incidents' as const },
        { label: t('ui.dashboard.units_on_duty'), value: data?.stats.unitsOnDuty, note: data ? t('ui.dashboard.units_split', data.stats.unitsAvailable, data.stats.unitsOnCalls) : '', warn: false, page: 'dispatch' as const },
      ] as stat (stat.page)}
        <button type="button" class="flex flex-col gap-2 rounded-lg border border-border p-4 text-left transition-colors hover:bg-muted" onclick={() => mdt.go(stat.page)}>
          <span class="text-13 text-muted-foreground">{stat.label}</span>
          <span class="text-28 font-semibold tracking-[-0.02em] tabular-nums">{stat.value ?? ''}</span>
          <span class="text-xs {stat.warn ? 'text-warning' : 'text-muted-foreground'}">{stat.note}</span>
        </button>
      {/each}
    </div>

    <div class="flex flex-col gap-3">
      <div class="flex items-center gap-2">
        <span class="size-2 rounded-full bg-primary"></span>
        <h2 class="flex-1 text-base font-semibold">{t('ui.dashboard.live_calls')}</h2>
        {#if mdt.has('dispatch')}<Button variant="link" onclick={() => mdt.go('dispatch')}>{t('ui.dashboard.open_dispatch')}</Button>{/if}
      </div>
      <div class="flex flex-col overflow-hidden rounded-lg border border-border">
        {#each calls as call (call.id)}
          <button type="button" class="flex items-center gap-4 border-b border-border px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-muted" onclick={() => mdt.go('dispatch')}>
            <span class="flex w-16 shrink-0"><Badge tone={call.priority === 1 ? 'danger' : 'neutral'} strong>{call.code}</Badge></span>
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="truncate text-sm font-medium">{call.title}</span>
              <span class="truncate text-xs text-muted-foreground">{call.caller ? t('ui.dashboard.call_with_caller', call.location, call.caller.number) : call.location}</span>
            </span>
            {#if call.plate}<Plate plate={call.plate} width={64} />{/if}
            <span class="w-37.5 shrink-0 text-13 tabular-nums {call.responders.length ? '' : 'text-muted-foreground'}">{units(call)}</span>
            <span class="w-16 shrink-0 text-right text-13 text-muted-foreground tabular-nums">{ago(call.createdAt, mdt.now)}</span>
          </button>
        {:else}
          <p class="px-4 py-6 text-center text-sm text-muted-foreground">{t('ui.dispatch.empty_open')}</p>
        {/each}
      </div>
    </div>

    <div class="flex min-h-0 gap-6">
      <div class="flex min-w-0 flex-1 flex-col gap-3">
        <h2 class="text-base font-semibold">{t('ui.dashboard.recent_incidents')}</h2>
        <div class="flex flex-col">
          {#each data?.incidents ?? [] as incident (incident.id)}
            <button type="button" class="flex items-center gap-3 border-b border-border py-2.5 text-left hover:bg-muted" onclick={() => mdt.openIncident(incident.id)}>
              <span class="w-14 shrink-0 text-13 text-muted-foreground tabular-nums">#{incident.id}</span>
              <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="truncate text-sm font-medium">{incident.title}</span>
                <span class="truncate text-xs text-muted-foreground">{incident.author}, {plural(incident.suspects, 'ui.plural.suspects')}</span>
              </span>
              <span class="w-14 shrink-0 text-right text-13 text-muted-foreground tabular-nums">{age(incident.occurredAt, mdt.now)}</span>
            </button>
          {/each}
        </div>
      </div>
      <div class="flex min-w-0 flex-1 flex-col gap-3">
        <h2 class="text-base font-semibold">{t('ui.dashboard.warrants_and_bolos')}</h2>
        <div class="flex flex-col">
          {#each data?.warrants ?? [] as warrant (warrant.id)}
            {@const ending = warrant.expiresAt != null && warrant.expiresAt - mdt.now < warnSeconds}
            <button type="button" class="flex items-center gap-3 border-b border-border py-2.5 text-left hover:bg-muted" onclick={() => mdt.go('warrants')}>
              <span class="flex w-18 shrink-0"><Badge>{warrantTypeLabel(warrant.type)}</Badge></span>
              <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="truncate text-sm font-medium">{warrant.name}</span>
                <span class="truncate text-xs text-muted-foreground">{warrant.title}</span>
              </span>
              <span class="w-18 shrink-0 text-right text-13 tabular-nums {ending ? 'text-warning' : 'text-muted-foreground'}">
                {warrant.expiresAt == null ? t('ui.warrants.no_end') : t('ui.dashboard.ends', remaining(warrant.expiresAt, mdt.now))}
              </span>
            </button>
          {/each}
          {#each data?.bolos ?? [] as bolo (bolo.id)}
            <button type="button" class="flex items-center gap-3 border-b border-border py-2.5 text-left hover:bg-muted" onclick={() => mdt.go('bolos')}>
              <span class="flex w-18 shrink-0"><Badge>{boloTypeLabel(bolo.type)}</Badge></span>
              <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="truncate text-sm font-medium">{bolo.title}</span>
                <span class="truncate text-xs text-muted-foreground">{t('ui.bolos.last_seen', bolo.lastSeen)}</span>
              </span>
              {#if bolo.plate}<Plate plate={bolo.plate} width={64} />{/if}
              <span class="w-18 shrink-0 text-right text-13 text-muted-foreground tabular-nums">{age(bolo.createdAt, mdt.now)}</span>
            </button>
          {/each}
        </div>
      </div>
    </div>
  </section>

  <aside class="flex w-[23.75rem] shrink-0 flex-col gap-4 overflow-y-auto border-l border-border p-6">
    <div class="flex items-center gap-2">
      <h2 class="flex-1 text-base font-semibold">{t('ui.dashboard.bulletin_board')}</h2>
      {#if mdt.can('postBulletins')}
        <Button size="sm" onclick={() => (posting = true)}><Megaphone size="0.875rem" />{t('ui.dashboard.post')}</Button>
      {/if}
    </div>
    <div class="flex flex-col gap-2">
      {#each data?.bulletins ?? [] as bulletin (bulletin.id)}
        <article class="group flex flex-col gap-1.5 rounded-lg border border-border p-3.5 {bulletin.pinned ? 'bg-muted' : ''}">
          {#if bulletin.pinned}
            <span class="flex items-center gap-1.5 text-xs font-medium text-cobalt-foreground"><PushPin size="0.75rem" />{t('ui.dashboard.pinned')}</span>
          {/if}
          <div class="flex items-start gap-2">
            <h3 class="flex-1 text-sm font-semibold">{bulletin.title}</h3>
            {#if mdt.can('postBulletins')}
              <div class="hidden gap-0.5 group-focus-within:flex group-hover:flex">
                <button type="button" class="rounded-md p-1 text-muted-foreground hover:bg-secondary hover:text-foreground" aria-label={bulletin.pinned ? t('ui.dashboard.unpin') : t('ui.dashboard.pin')} onclick={() => pin(bulletin)}>
                  {#if bulletin.pinned}<PushPinSlash size="0.875rem" />{:else}<PushPin size="0.875rem" />{/if}
                </button>
                <button type="button" class="rounded-md p-1 text-muted-foreground hover:bg-secondary hover:text-destructive" aria-label={t('ui.dashboard.delete_bulletin')} onclick={() => remove(bulletin)}>
                  <Trash size="0.875rem" />
                </button>
              </div>
            {/if}
          </div>
          <p class="text-13 leading-[1.1875rem] text-muted-foreground">{bulletin.body}</p>
          <p class="text-xs text-muted-foreground">{bulletin.author}, {ago(bulletin.createdAt, mdt.now)}</p>
        </article>
      {:else}
        <p class="text-sm text-muted-foreground">{t('ui.dashboard.no_bulletins')}</p>
      {/each}
    </div>
  </aside>
</div>

{#if posting}
  <Dialog title={t('ui.dashboard.post_title')} description={t('ui.dashboard.post_description')} onclose={() => (posting = false)}>
    <Field label={t('ui.common.title')}><input class="field" bind:value={draft.title} maxlength="80" /></Field>
    <Field label={t('ui.dashboard.message')}><textarea class="field h-28 resize-none py-2" bind:value={draft.body} maxlength="600"></textarea></Field>
    <div class="flex items-center gap-2 text-sm">
      <Checkbox label={t('ui.dashboard.pin_top')} checked={draft.pinned} onchange={(checked) => (draft.pinned = checked)} />
      {t('ui.dashboard.pin_top')}
    </div>
    {#snippet actions()}
      <Button onclick={() => (posting = false)}>{t('ui.common.cancel')}</Button>
      <Button variant="primary" disabled={!draft.title.trim() || !draft.body.trim()} onclick={post}>{t('ui.dashboard.post_bulletin')}</Button>
    {/snippet}
  </Dialog>
{/if}
