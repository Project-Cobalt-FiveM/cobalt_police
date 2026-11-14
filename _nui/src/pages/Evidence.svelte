<script lang="ts">
  import type { Component } from 'svelte';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import Fingerprint from 'phosphor-svelte/lib/Fingerprint';
  import Camera from 'phosphor-svelte/lib/Camera';
  import Package from 'phosphor-svelte/lib/Package';
  import CheckCircle from 'phosphor-svelte/lib/CheckCircle';
  import Header from '../components/Header.svelte';
  import EvidenceDialog from '../components/dialogs/EvidenceDialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Row from '../components/ui/Row.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { dateTime, filedAt } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Citizen, Evidence, EvidenceType } from '../lib/types';

  type Filter = 'all' | 'physical' | 'forensic';

  let items = $state<Evidence[]>([]);
  let filter = $state<Filter>('all');
  let query = $state('');
  let selectedId = $state<number | null>(null);
  let match = $state<Citizen | null>(null);
  let adding = $state(false);
  let deleting = $state(false);
  let loaded = false;

  const icons: Record<EvidenceType, Component<{ size?: string; class?: string }>> = { forensic: Fingerprint, photo: Camera, item: Package };

  const inFilter = (item: Evidence, value: Filter) => value === 'all' || (value === 'forensic' ? item.type === 'forensic' : item.type !== 'forensic');
  const list = $derived(items.filter((item) => inFilter(item, filter)));
  const selected = $derived(list.find((item) => item.id === selectedId) ?? list[0] ?? null);
  const linkedId = $derived(selected?.citizenid ?? null);

  async function load() {
    items = await fetchNui('getEvidence', { type: 'all', query: query.trim() });
  }

  $effect(() => {
    void query;
    const timer = setTimeout(load, loaded ? 250 : 0);
    loaded = true;
    return () => clearTimeout(timer);
  });

  $effect(() => {
    const citizenid = linkedId;
    match = null;
    if (!citizenid) return;

    void fetchNui('getCitizen', { citizenid }).then((citizen) => {
      if (linkedId === citizenid) match = citizen || null;
    });
  });

  function subtitle(item: Evidence): string {
    const parts = [item.citizenName ? (item.type === 'forensic' ? t('ui.evidence.matches', item.citizenName) : item.citizenName) : item.location];
    if (item.incidentId != null) parts.push(t('ui.evidence.case_ref', item.incidentId));
    return parts.join(', ');
  }

  async function remove(item: Evidence) {
    if (mdt.report(await fetchNui('deleteEvidence', { id: item.id }), t('ui.common.deleted', item.code))) {
      deleting = false;
      selectedId = null;
      await load();
    }
  }
</script>

<Header title={t('ui.page.evidence')} subtitle={t('ui.evidence.subtitle')}>
  {#snippet action()}
    <Button variant="primary" onclick={() => (adding = true)}><PlusSquare size="1rem" />{t('ui.evidence_dialog.title')}</Button>
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <div class="flex items-center gap-4">
      <div class="flex-1">
        <Tabs
          bind:value={filter}
          tabs={[
            { value: 'all', label: t('ui.common.all'), count: items.length },
            { value: 'physical', label: t('ui.evidence.physical'), count: items.filter((item) => inFilter(item, 'physical')).length },
            { value: 'forensic', label: t('ui.evidence.forensic'), count: items.filter((item) => inFilter(item, 'forensic')).length },
          ]}
        />
      </div>
      <label class="flex h-8 w-[16.25rem] items-center gap-2 rounded-md border border-input px-3 focus-within:border-primary">
        <MagnifyingGlass size="0.75rem" class="text-muted-foreground" />
        <input bind:value={query} placeholder={t('ui.evidence.filter_placeholder')} aria-label={t('ui.evidence.filter_label')} class="h-full min-w-0 flex-1 bg-transparent text-13 outline-none" />
      </label>
    </div>

    <div class="flex flex-col gap-2">
      {#each list as item (item.id)}
        {@const active = item.id === selected?.id}
        {@const Icon = icons[item.type]}
        <button
          type="button"
          class="flex items-center gap-4 rounded-lg border px-3 py-2.5 text-left transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
          onclick={() => (selectedId = item.id)}
        >
          <span class="flex size-9 shrink-0 items-center justify-center rounded-md {active ? 'bg-cobalt-hover' : 'bg-secondary'}">
            <Icon size="1rem" class={active ? 'text-primary-foreground' : 'text-muted-foreground'} />
          </span>
          <span class="w-17 shrink-0 text-13 tabular-nums {active ? 'font-semibold' : 'text-muted-foreground'}">{item.code}</span>
          <span class="flex min-w-0 flex-1 flex-col gap-0.5">
            <span class="truncate text-sm font-medium">{item.title}</span>
            <span class="truncate text-xs {active ? '' : 'text-muted-foreground'}">{subtitle(item)}</span>
          </span>
          <span class="text-13 tabular-nums {active ? '' : 'text-muted-foreground'}">{filedAt(item.createdAt, mdt.now)}</span>
        </button>
      {:else}
        <p class="py-8 text-center text-sm text-muted-foreground">{t('ui.evidence.no_matches')}</p>
      {/each}
    </div>
  </section>

  <aside class="flex w-[26.25rem] shrink-0 flex-col border-l border-border">
    {#if selected}
      {#key selected.id}
        <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto p-6" in:crossfade>
          <div class="flex flex-col gap-1">
            <span class="text-13 text-muted-foreground tabular-nums">{t('ui.evidence.heading', t(`ui.evidence_type.${selected.type}`), selected.code)}</span>
            <h2 class="text-xl font-semibold tracking-[-0.01em]">{selected.title}</h2>
          </div>
          {#if selected.image}<img src={selected.image} alt={selected.title} class="max-h-56 rounded-lg border border-border object-cover" />{/if}
          {#if selected.citizenName}
            <div class="flex gap-3 rounded-lg border border-border p-4">
              <CheckCircle size="1rem" class="mt-0.5 shrink-0 text-success" />
              <div class="flex flex-col gap-0.5">
                <span class="text-sm font-medium">{selected.type === 'forensic' ? t('ui.evidence.match', selected.citizenName) : t('ui.evidence.linked_to', selected.citizenName)}</span>
                {#if match}<span class="text-13 text-muted-foreground tabular-nums">{t('ui.evidence.fingerprint_on_file', match.fingerprint)}</span>{/if}
              </div>
            </div>
          {/if}
          {#if selected.description}<p class="text-sm text-muted-foreground">{selected.description}</p>{/if}
          <div class="flex flex-col">
            <Row label={t('ui.evidence.collected')}>{dateTime(selected.createdAt)}, {selected.collectedBy}</Row>
            <Row label={t('ui.common.location')}>{selected.location || t('ui.evidence.not_recorded')}</Row>
            {#if match}
              <Row label={t('ui.evidence.name_on_match')}>{match.name}, {t(`ui.sex.${match.sex}`)}</Row>
              <Row label={t('ui.common.born')}>{match.dob}</Row>
              <Row label={t('ui.common.phone')}>{match.phone}</Row>
            {/if}
            {#if selected.incidentId != null}
              {@const incidentId = selected.incidentId}
              <div class="flex items-center justify-between border-b border-border py-2.5 text-13">
                <span class="text-muted-foreground">{t('ui.common.case')}</span>
                <button type="button" class="font-medium text-cobalt-foreground tabular-nums hover:text-foreground" onclick={() => mdt.openIncident(incidentId)}>#{incidentId}</button>
              </div>
            {/if}
          </div>
        </div>
        <div class="flex gap-2 px-6 pb-6">
          {#if selected.citizenid}
            {@const citizenid = selected.citizenid}
            <Button variant="primary" class="flex-1" onclick={() => mdt.openCitizen(citizenid)}>{t('ui.common.open_profile')}</Button>
          {/if}
          {#if mdt.can('deleteEvidence')}
            <Button variant="destructive" class={selected.citizenid ? '' : 'flex-1'} onclick={() => (deleting = true)}>{t(`ui.evidence.delete_button.${selected.type}`)}</Button>
          {/if}
        </div>
      {/key}
    {:else}
      <Empty icon={Fingerprint} title={t('ui.common.nothing_selected')} body={t('ui.evidence.none_selected_body')} />
    {/if}
  </aside>
</div>

{#if adding}
  <EvidenceDialog onclose={() => (adding = false)} onadded={load} />
{/if}

{#if deleting && selected}
  {@const target = selected}
  <Dialog title={t('ui.evidence.delete_title', target.code)} description={t('ui.evidence.delete_description', target.title)} onclose={() => (deleting = false)}>
    {#snippet actions()}
      <Button onclick={() => (deleting = false)}>{t('ui.common.cancel')}</Button>
      <Button variant="destructive" onclick={() => remove(target)}>{t('ui.evidence.delete')}</Button>
    {/snippet}
  </Dialog>
{/if}
