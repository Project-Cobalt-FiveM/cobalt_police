<script lang="ts">
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import FileText from 'phosphor-svelte/lib/FileText';
  import Header from '../components/Header.svelte';
  import Button from '../components/ui/Button.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Row from '../components/ui/Row.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { dateTime, filedAt, kindLabel, plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Incident, IncidentSummary } from '../lib/types';

  type Filter = 'all' | 'incident' | 'report' | 'mine' | 'draft';

  let all = $state<IncidentSummary[]>([]);
  let filter = $state<Filter>('all');
  let query = $state('');
  let selectedId = $state<number | null>(null);
  let detail = $state<Incident | null>(null);
  let deleting = $state(false);
  let loaded = false;

  const me = $derived(mdt.officer?.citizenid ?? '');

  const matchesFilter = (entry: IncidentSummary, value: Filter) => {
    if (value === 'incident' || value === 'report') return entry.kind === value;
    if (value === 'mine') return entry.authorCid === me;
    if (value === 'draft') return entry.status === 'draft';
    return true;
  };

  const list = $derived(all.filter((entry) => matchesFilter(entry, filter)));
  const count = (value: Filter) => all.filter((entry) => matchesFilter(entry, value)).length;

  async function load() {
    all = await fetchNui('getIncidents', { query: query.trim(), kind: 'all' });
    if (!all.some((entry) => entry.id === selectedId)) selectedId = all[0]?.id ?? null;
  }

  $effect(() => {
    void query;
    const timer = setTimeout(load, loaded ? 250 : 0);
    loaded = true;
    return () => clearTimeout(timer);
  });

  $effect(() => {
    const id = selectedId;
    detail = null;
    if (id === null) return;

    void fetchNui('getIncident', { id }).then((incident) => {
      if (selectedId === id) detail = incident;
    });
  });

  function caseNumber(entry: { id: number | null; kind: Incident['kind'] }): string {
    return entry.kind === 'report' ? `R-${entry.id}` : `#${entry.id}`;
  }

  function names(people: { name: string }[]): string {
    return people.map((person) => person.name).join(', ') || t('ui.common.none');
  }

  function sentence(incident: Incident): string {
    const charges = incident.suspects.reduce((sum, suspect) => sum + suspect.charges.length, 0);
    if (!charges) return t('ui.incidents.no_charges');
    return t(incident.status === 'filed' ? 'ui.incidents.charges_filed' : 'ui.incidents.charges_pending', plural(charges, 'ui.plural.charges'));
  }

  async function remove(incident: Incident) {
    if (incident.id === null) return;

    if (mdt.report(await fetchNui('deleteIncident', { id: incident.id }), t('ui.common.deleted', kindLabel(incident.kind)))) {
      deleting = false;
      selectedId = null;
      await load();
    }
  }
</script>

<Header title={t('ui.page.incidents')} subtitle={t('ui.incidents.subtitle')}>
  {#snippet action()}
    {#if mdt.can('createIncident')}
      <Button variant="primary" onclick={() => mdt.newIncident()}><PlusSquare size="1rem" />{t('ui.common.new_incident')}</Button>
    {/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <div class="flex items-center gap-4">
      <div class="flex-1">
        <Tabs
          bind:value={filter}
          tabs={[
            { value: 'all', label: t('ui.common.all'), count: all.length },
            { value: 'incident', label: t('ui.page.incidents'), count: count('incident') },
            { value: 'report', label: t('ui.incidents.reports'), count: count('report') },
            { value: 'mine', label: t('ui.common.mine'), count: count('mine') },
            { value: 'draft', label: t('ui.incidents.drafts'), count: count('draft') },
          ]}
        />
      </div>
      <label class="flex h-8 w-[16.25rem] items-center gap-2 rounded-md border border-input px-3 focus-within:border-primary">
        <MagnifyingGlass size="0.75rem" class="text-muted-foreground" />
        <input bind:value={query} placeholder={t('ui.incidents.filter_placeholder')} aria-label={t('ui.incidents.filter_label')} class="h-full min-w-0 flex-1 bg-transparent text-13 outline-none" />
      </label>
    </div>

    <div class="overflow-hidden rounded-lg border border-border">
      <div class="grid grid-cols-[4.75rem_1fr_6rem_9rem_5.5rem] gap-3 border-b border-border px-4 py-2.5 text-xs text-muted-foreground">
        <span>{t('ui.common.case')}</span><span>{t('ui.common.title')}</span><span>{t('ui.incidents.kind')}</span><span>{t('ui.incidents.lead_officer')}</span><span class="text-right">{t('ui.incidents.filed')}</span>
      </div>
      {#each list as entry (entry.id)}
        {@const active = entry.id === selectedId}
        <button
          type="button"
          class="grid w-full grid-cols-[4.75rem_1fr_6rem_9rem_5.5rem] items-center gap-3 border-b border-border px-4 py-3 text-left transition-colors last:border-b-0 {active ? 'bg-primary' : 'hover:bg-muted'}"
          onclick={() => (selectedId = entry.id)}
          ondblclick={() => mdt.openIncident(entry.id)}
        >
          <span class="text-13 tabular-nums {active ? 'font-semibold' : 'text-muted-foreground'}">{caseNumber(entry)}</span>
          <span class="flex min-w-0 flex-col gap-0.5">
            <span class="truncate text-sm font-medium">{entry.title}</span>
            <span class="truncate text-xs {entry.status === 'draft' && !active ? 'text-warning' : active ? '' : 'text-muted-foreground'}">
              {entry.status === 'draft' ? t('ui.incidents.draft_not_filed') : `${plural(entry.suspects, 'ui.plural.suspects')}, ${entry.location}`}
            </span>
          </span>
          <span class="text-13 font-medium">{kindLabel(entry.kind)}</span>
          <span class="truncate text-13 font-medium">{entry.author}</span>
          <span class="text-right text-13 tabular-nums {active ? '' : 'text-muted-foreground'}">{filedAt(entry.occurredAt, mdt.now)}</span>
        </button>
      {:else}
        <p class="px-4 py-8 text-center text-sm text-muted-foreground">{t('ui.incidents.empty')}</p>
      {/each}
    </div>
  </section>

  <aside class="flex w-[26.25rem] shrink-0 flex-col border-l border-border">
    {#if detail}
      {#key detail.id}
        <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto p-6" in:crossfade>
          <div class="flex flex-col gap-1">
            <span class="text-13 text-muted-foreground tabular-nums">{t('ui.incidents.heading', kindLabel(detail.kind), caseNumber(detail), dateTime(detail.occurredAt))}</span>
            <h2 class="text-xl font-semibold tracking-[-0.01em]">{detail.title}</h2>
          </div>
          <p class="text-sm leading-[1.375rem] whitespace-pre-line">{detail.narrative || t('ui.incidents.no_narrative')}</p>
          <div class="flex flex-col">
            <Row label={t('ui.common.location')}>{detail.location || t('ui.incidents.not_set')}</Row>
            <Row label={t('ui.common.officers')}>{names(detail.officers)}</Row>
            {#if detail.kind === 'incident'}
              <div class="flex items-start justify-between gap-4 border-b border-border py-2.5 text-13">
                <span class="shrink-0 text-muted-foreground">{t('ui.common.suspects')}</span>
                <span class="text-right font-medium">
                  {#each detail.suspects as suspect, index (index)}
                    {#if index > 0}, {/if}
                    {#if suspect.citizenid}
                      {@const citizenid = suspect.citizenid}
                      <button type="button" class="text-cobalt-foreground hover:text-foreground" onclick={() => mdt.openCitizen(citizenid)}>{suspect.name}</button>
                    {:else}{suspect.name}{/if}
                  {:else}{t('ui.common.none')}{/each}
                </span>
              </div>
            {/if}
            <Row label={t('ui.common.witnesses')}>{names(detail.witnesses)}</Row>
            <Row label={t('ui.page.evidence')}>{detail.evidence.map((item) => item.code).join(', ') || t('ui.common.none')}</Row>
            {#if detail.kind === 'incident'}<Row label={t('ui.incidents.sentence')}>{sentence(detail)}</Row>{/if}
          </div>
        </div>
        <div class="flex gap-2 px-6 pb-6">
          <Button variant="primary" class="flex-1" onclick={() => detail?.id != null && mdt.openIncident(detail.id)}>
            {detail.status === 'draft' ? t('ui.incidents.continue_draft') : t('ui.incidents.open')}
          </Button>
          {#if mdt.can('createIncident')}<Button onclick={() => mdt.newIncident('report')}>{t('ui.incidents.add_report')}</Button>{/if}
          {#if mdt.can('deleteIncident')}<Button variant="destructive" onclick={() => (deleting = true)}>{t('ui.common.delete')}</Button>{/if}
        </div>
      {/key}
    {:else}
      <Empty icon={FileText} title={t('ui.common.nothing_selected')} body={t('ui.incidents.none_selected_body')} />
    {/if}
  </aside>
</div>

{#if deleting && detail}
  {@const target = detail}
  <Dialog title={t(`ui.incidents.delete_title.${target.kind}`, caseNumber(target))} description={t('ui.incidents.delete_description')} onclose={() => (deleting = false)}>
    {#snippet actions()}
      <Button onclick={() => (deleting = false)}>{t('ui.common.cancel')}</Button>
      <Button variant="destructive" onclick={() => remove(target)}>{t(`ui.incidents.delete_button.${target.kind}`)}</Button>
    {/snippet}
  </Dialog>
{/if}
