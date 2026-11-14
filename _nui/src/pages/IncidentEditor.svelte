<script lang="ts">
  import { onMount, untrack } from 'svelte';
  import MapPin from 'phosphor-svelte/lib/MapPin';
  import Clock from 'phosphor-svelte/lib/Clock';
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import Minus from 'phosphor-svelte/lib/Minus';
  import Plus from 'phosphor-svelte/lib/Plus';
  import X from 'phosphor-svelte/lib/X';
  import Header from '../components/Header.svelte';
  import Button from '../components/ui/Button.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Select from '../components/ui/Select.svelte';
  import Picker from '../components/ui/Picker.svelte';
  import Dot from '../components/ui/Dot.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt, type Editor } from '../lib/store.svelte';
  import { classDots, clockTime, dateTime, kindLabel, money, nowSeconds, plural, shortDate } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { searchPeople } from '../lib/people';
  import { fromLocalInput, pointsOutcome, toLocalInput, totals } from '../lib/sentence';
  import { crossfade } from '../lib/motion';
  import type { PickOption } from '../components/ui/types';
  import type { Charge, Incident, IncidentKind, Licence, Person, SentenceResult, Template } from '../lib/types';

  let { editor }: { editor: Editor } = $props();

  const seed = untrack(() => editor);

  let incident = $state<Incident>({
    id: seed.id,
    kind: seed.kind,
    status: 'draft',
    title: '',
    location: '',
    coords: null,
    occurredAt: nowSeconds(),
    narrative: '',
    officers: mdt.officer ? [{ citizenid: mdt.officer.citizenid, name: mdt.officer.name }] : [],
    suspects: seed.suspects.map((person) => ({ ...person, charges: [] })),
    witnesses: [],
    evidence: [],
    author: mdt.officer?.name ?? '',
    authorCid: mdt.officer?.citizenid ?? null,
    updatedAt: 0,
  });

  let loading = $state(seed.id !== null);
  let charges = $state<Charge[]>([]);
  let templates = $state<Template[]>([]);
  let template = $state(0);
  let selected = $state(0);
  let chargeQuery = $state('');
  let licences = $state<Record<string, Licence[]>>({});
  let busy = $state(false);
  let sentences = $state<SentenceResult[] | null>(null);
  let timeInput = $state<HTMLInputElement>();

  const chargeMap = $derived(new Map(charges.map((charge) => [charge.id, charge])));
  const suspect = $derived(incident.kind === 'incident' ? incident.suspects[selected] : undefined);
  const suspectTotals = $derived(suspect ? totals(suspect.charges, chargeMap) : null);
  const outcome = $derived(suspect?.citizenid && suspectTotals ? pointsOutcome(licences[suspect.citizenid] ?? [], suspectTotals.points) : null);
  const isAuthor = $derived(mdt.officer != null && incident.authorCid === mdt.officer.citizenid);
  const editable = $derived(incident.status === 'draft' && (incident.id === null ? mdt.can('createIncident') : mdt.can('editIncident') || isAuthor));
  const templateOptions = $derived([{ value: 0, label: t('ui.common.none') }, ...templates.filter((entry) => entry.kind === incident.kind).map((entry) => ({ value: entry.id, label: entry.name }))]);
  const chargeResults = $derived.by(() => {
    const text = chargeQuery.trim().toLowerCase();
    if (!text) return [];

    return charges.filter((charge) => charge.title.toLowerCase().includes(text) || charge.code.toLowerCase().includes(text)).slice(0, 6);
  });

  const title = $derived(incident.id === null ? t(`ui.editor.new.${incident.kind}`) : t('ui.editor.title', kindLabel(incident.kind), incident.id));
  const subtitle = $derived.by(() => {
    if (loading) return t('ui.common.loading');
    if (incident.id === null) return t('ui.editor.not_saved');
    if (incident.status === 'filed') return t('ui.editor.filed_by', dateTime(incident.updatedAt), incident.author);
    return t('ui.editor.draft_saved', incident.id, clockTime(incident.updatedAt));
  });

  async function loadLicences(citizenids: (string | null)[]) {
    const wanted = [...new Set(citizenids.filter((id): id is string => id !== null && !licences[id]))];
    if (!wanted.length) return;

    const found = await fetchNui('getLicences', { citizenids: wanted });
    const byId: Record<string, Licence[]> = found && !('ok' in found) ? found : {};

    for (const id of wanted) licences[id] = byId[id] ?? [];
  }

  onMount(async () => {
    void fetchNui('getCharges').then((all) => (charges = all));
    void fetchNui('getTemplates').then((all) => (templates = all));

    if (seed.id !== null) {
      const found = await fetchNui('getIncident', { id: seed.id });
      if (found) incident = found;
      loading = false;
    }

    void loadLicences(incident.suspects.map((entry) => entry.citizenid));
  });

  function applyTemplate(id: number) {
    const found = templates.find((entry) => entry.id === id);
    if (found) incident.narrative = found.content;
  }

  function setKind(kind: IncidentKind) {
    incident.kind = kind;
    template = 0;

    if (kind === 'report') {
      incident.suspects = [];
      selected = 0;
    }
  }

  async function useLocation() {
    const here = await fetchNui('getLocation');
    incident.location = here.location;
    incident.coords = here.coords;
  }

  function addCharge(charge: Charge) {
    if (!suspect) return;

    const existing = suspect.charges.find((item) => item.chargeId === charge.id);
    if (existing) {
      if (charge.stackable) existing.counts += 1;
    } else {
      suspect.charges.push({ chargeId: charge.id, counts: 1 });
    }

    chargeQuery = '';
  }

  function step(chargeId: number, delta: number) {
    if (!suspect) return;

    const item = suspect.charges.find((entry) => entry.chargeId === chargeId);
    if (!item) return;

    const charge = chargeMap.get(chargeId);
    const max = charge?.stackable ? 99 : 1;
    item.counts = Math.min(max, item.counts + delta);
    if (item.counts <= 0) suspect.charges = suspect.charges.filter((entry) => entry.chargeId !== chargeId);
  }

  function hasPerson(list: Person[], person: Person): boolean {
    return list.some((entry) => (person.citizenid ? entry.citizenid === person.citizenid : entry.name === person.name));
  }

  function addSuspect(person: Person) {
    if (hasPerson(incident.suspects, person)) return;

    incident.suspects.push({ ...person, charges: [] });
    selected = incident.suspects.length - 1;
    void loadLicences([person.citizenid]);
  }

  function removeSuspect(index: number) {
    incident.suspects.splice(index, 1);
    selected = Math.max(0, Math.min(selected, incident.suspects.length - 1));
  }

  function unknownPerson(query: string): PickOption<Person> {
    return { key: `unknown-${query}`, label: t('ui.editor.unknown_person', query), detail: t('ui.editor.unknown_person_detail'), value: { citizenid: null, name: query } };
  }

  let roster: Person[] | null = null;

  async function searchOfficers(query: string) {
    roster ??= (await fetchNui('getRoster')).map((entry) => ({ citizenid: entry.citizenid, name: entry.name }));
    const text = query.trim().toLowerCase();
    return roster
      .filter((entry) => !hasPerson(incident.officers, entry) && entry.name.toLowerCase().includes(text))
      .map((entry) => ({ key: entry.citizenid ?? entry.name, label: entry.name, value: { citizenid: entry.citizenid, name: entry.name } }));
  }

  async function searchEvidence(query: string) {
    const items = await fetchNui('getEvidence', { type: 'all', query: query.trim() });
    return items
      .filter((item) => item.incidentId == null || item.incidentId === incident.id)
      .filter((item) => !incident.evidence.some((entry) => entry.id === item.id))
      .slice(0, 8)
      .map((item) => ({ key: String(item.id), label: `${item.code} ${item.title}`, detail: item.citizenName ?? item.location, value: { id: item.id, code: item.code, title: item.title } }));
  }

  function snapshot(): Incident {
    return $state.snapshot(incident);
  }

  async function saveDraft() {
    if (busy) return;
    busy = true;

    const result = await fetchNui('saveIncident', snapshot());
    busy = false;
    if (!mdt.report(result, t('ui.editor.draft_saved_toast')) || !result.ok) return;

    incident.id = result.id;
    incident.updatedAt = nowSeconds();
  }

  async function file() {
    if (busy) return;
    busy = true;

    const result = await fetchNui('fileIncident', snapshot());
    busy = false;
    if (!mdt.report(result) || !result.ok) return;

    incident.id = result.id;
    incident.status = 'filed';
    incident.updatedAt = nowSeconds();
    sentences = result.sentences;
    void mdt.refreshCounts();
  }

  const ready = $derived(incident.title.trim().length > 0 && incident.location.trim().length > 0 && incident.narrative.trim().length > 0);

  $effect(() => {
    if (!chargeResults.length) return;
    return mdt.pushLayer(() => (chargeQuery = ''));
  });
</script>

{#snippet chip(label: string, remove: (() => void) | null, active = false, onselect: (() => void) | null = null)}
  <span class="group inline-flex h-7 items-center gap-1 rounded-md pr-1 pl-2 text-13 font-medium {active ? 'bg-primary text-primary-foreground' : 'bg-secondary'}">
    {#if onselect}
      <button type="button" class="truncate" onclick={onselect}>{label}</button>
    {:else}
      <span class="truncate">{label}</span>
    {/if}
    {#if remove && editable}
      <button type="button" class="rounded-sm p-0.5 {active ? 'hover:bg-cobalt-hover' : 'text-muted-foreground hover:bg-secondary-hover hover:text-foreground'}" aria-label={t('ui.common.remove', label)} onclick={remove}>
        <X size="0.625rem" />
      </button>
    {/if}
  </span>
{/snippet}

<Header {title} {subtitle} />

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
    <div class="flex items-center gap-3">
      <div class="flex-1"><div class="inline-flex rounded-md border border-border p-1">
        <Tabs
          value={incident.kind}
          tabs={[
            { value: 'incident', label: kindLabel('incident') },
            { value: 'report', label: kindLabel('report') },
          ]}
          onchange={setKind}
          disabled={!editable || incident.id !== null}
        />
      </div></div>
      {#if editable}
        <Select class="w-[12.625rem]" prefix={t('ui.editor.template')} label={t('ui.editor.template_label')} options={templateOptions} bind:value={template} onchange={applyTemplate} />
      {/if}
    </div>

    <label class="flex flex-col gap-2">
      <span class="text-sm font-medium">{t('ui.common.title')}</span>
      <input class="field" bind:value={incident.title} disabled={!editable} maxlength="120" placeholder={t('ui.editor.title_example')} />
    </label>

    <div class="grid grid-cols-[1fr_12.5rem] gap-3">
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium">{t('ui.common.location')}</span>
        <div class="field flex items-center gap-2 focus-within:border-primary">
          <MapPin size="0.875rem" class="shrink-0 text-muted-foreground" />
          <input class="h-full min-w-0 flex-1 bg-transparent outline-none" aria-label={t('ui.common.location')} bind:value={incident.location} disabled={!editable} maxlength="120" />
          {#if editable}<button type="button" class="shrink-0 text-xs font-medium text-cobalt-foreground hover:text-foreground" onclick={useLocation}>{t('ui.common.use_my_location')}</button>{/if}
        </div>
      </div>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium">{t('ui.editor.time')}</span>
        <div class="relative">
          <button type="button" class="field flex items-center gap-2 text-left focus:border-primary" disabled={!editable} onclick={() => timeInput?.showPicker()}>
            <Clock size="0.875rem" class="shrink-0 text-muted-foreground" />
            <span class="font-medium tabular-nums">{shortDate(incident.occurredAt)}, {clockTime(incident.occurredAt)}</span>
          </button>
          <input
            bind:this={timeInput}
            type="datetime-local"
            aria-label={t('ui.editor.time')}
            tabindex="-1"
            class="sr-only"
            value={toLocalInput(incident.occurredAt)}
            onchange={(event) => (incident.occurredAt = fromLocalInput(event.currentTarget.value) ?? incident.occurredAt)}
          />
        </div>
      </div>
    </div>

    <label class="flex flex-col gap-2">
      <span class="text-sm font-medium">{t('ui.common.narrative')}</span>
      <textarea class="field h-37.5 resize-none py-3 leading-[1.375rem]" bind:value={incident.narrative} disabled={!editable} maxlength="8000" placeholder={t('ui.editor.narrative_placeholder')}></textarea>
    </label>

    <div class="flex flex-col rounded-lg border border-border">
      <div class="flex min-h-12 items-center gap-4 border-b border-border px-4 py-2.5">
        <span class="w-24 shrink-0 text-13 text-muted-foreground">{t('ui.common.officers')}</span>
        <div class="flex flex-wrap items-center gap-1.5">
          {#each incident.officers as officer, index (officer.citizenid ?? officer.name)}
            {@render chip(officer.name, incident.officers.length > 1 ? () => incident.officers.splice(index, 1) : null)}
          {/each}
          {#if editable}<Picker label={t('ui.editor.add_officer')} placeholder={t('ui.editor.search_roster')} search={searchOfficers} onpick={(person) => incident.officers.push(person)} />{/if}
        </div>
      </div>
      {#if incident.kind === 'incident'}
        <div class="flex min-h-12 items-center gap-4 border-b border-border px-4 py-2.5">
          <span class="w-24 shrink-0 text-13 text-muted-foreground">{t('ui.common.suspects')}</span>
          <div class="flex flex-wrap items-center gap-1.5">
            {#each incident.suspects as entry, index (entry.citizenid ?? entry.name)}
              {@render chip(
                `${entry.name}, ${entry.charges.length ? plural(entry.charges.length, 'ui.plural.charges') : t('ui.editor.no_charges')}`,
                () => removeSuspect(index),
                index === selected,
                () => (selected = index),
              )}
            {/each}
            {#if editable}<Picker label={t('ui.editor.add_suspect')} placeholder={t('ui.common.search_citizens')} search={searchPeople} free={unknownPerson} onpick={addSuspect} />{/if}
          </div>
        </div>
      {/if}
      <div class="flex min-h-12 items-center gap-4 border-b border-border px-4 py-2.5">
        <span class="w-24 shrink-0 text-13 text-muted-foreground">{t('ui.common.witnesses')}</span>
        <div class="flex flex-wrap items-center gap-1.5">
          {#each incident.witnesses as witness, index (witness.citizenid ?? witness.name)}
            {@render chip(witness.name, () => incident.witnesses.splice(index, 1))}
          {/each}
          {#if editable}
            <Picker label={t('ui.editor.add_witness')} placeholder={t('ui.common.search_citizens')} search={searchPeople} free={unknownPerson} onpick={(person) => hasPerson(incident.witnesses, person) || incident.witnesses.push(person)} />
          {/if}
        </div>
      </div>
      <div class="flex min-h-12 items-center gap-4 px-4 py-2.5">
        <span class="w-24 shrink-0 text-13 text-muted-foreground">{t('ui.page.evidence')}</span>
        <div class="flex flex-wrap items-center gap-1.5">
          {#each incident.evidence as item, index (item.id)}
            {@render chip(`${item.code} ${item.title}`, () => incident.evidence.splice(index, 1))}
          {/each}
          {#if editable}<Picker label={t('ui.editor.attach_evidence')} placeholder={t('ui.editor.search_evidence')} search={searchEvidence} onpick={(item) => incident.evidence.push(item)} />{/if}
        </div>
      </div>
    </div>
  </section>

  <aside class="flex w-[26.25rem] shrink-0 flex-col gap-4 border-l border-border p-6">
    {#if incident.kind === 'incident' && suspect}
      <div class="flex flex-col gap-1">
        <h2 class="text-base font-semibold">{t('ui.editor.charges_for', suspect.name)}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.editor.charges_hint')}</p>
      </div>

      {#if editable}
        <div class="relative">
          {#if chargeResults.length}
            <button type="button" class="fixed inset-0 z-30 cursor-default" aria-label={t('ui.common.close')} tabindex="-1" onclick={() => (chargeQuery = '')}></button>
          {/if}
          <label class="flex h-9 items-center gap-2 rounded-md border border-input px-3 focus-within:border-primary {chargeResults.length ? 'relative z-40' : ''}">
            <MagnifyingGlass size="0.875rem" class="text-muted-foreground" />
            <input bind:value={chargeQuery} placeholder={t('ui.editor.search_charges_placeholder')} aria-label={t('ui.editor.search_charges')} class="h-full min-w-0 flex-1 bg-transparent text-sm outline-none" />
          </label>
          {#if chargeResults.length}
            <ul class="absolute top-full right-0 left-0 z-40 mt-1 rounded-lg border border-border bg-popover p-1 shadow-lg">
              {#each chargeResults as charge (charge.id)}
                <li>
                  <button type="button" class="flex w-full flex-col rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => addCharge(charge)}>
                    <span class="flex items-center gap-1.5 text-sm font-medium"><Dot class={classDots[charge.class]} size="size-1.5" />{charge.title}</span>
                    <span class="text-xs text-muted-foreground tabular-nums">{charge.code}, {t('ui.common.months', charge.months)}, {money(charge.fine)}{charge.points ? `, ${plural(charge.points, 'ui.plural.points')}` : ''}</span>
                  </button>
                </li>
              {/each}
            </ul>
          {/if}
        </div>
      {/if}

      <div class="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto">
        {#each suspect.charges as item (item.chargeId)}
          {@const charge = chargeMap.get(item.chargeId)}
          {#if charge}
            <div class="flex items-center gap-3 rounded-lg border border-border px-3 py-2.5">
              <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="flex items-center gap-1.5 truncate text-sm font-medium"><Dot class={classDots[charge.class]} size="size-1.5" />{charge.title}</span>
                <span class="truncate text-xs text-muted-foreground tabular-nums">
                  {charge.code}{charge.months ? `, ${t('ui.common.months', charge.months)}` : ''}, {charge.stackable && item.counts > 1 ? t('ui.editor.per_count', money(charge.fine)) : money(charge.fine)}{charge.points ? `, ${plural(charge.points, 'ui.plural.points')}` : ''}
                </span>
              </div>
              <div class="flex h-7 items-center rounded-md border border-border">
                <button type="button" class="flex h-full w-6 items-center justify-center text-muted-foreground hover:text-foreground disabled:text-input" aria-label={t('ui.editor.remove_count')} disabled={!editable} onclick={() => step(item.chargeId, -1)}><Minus size="0.625rem" /></button>
                <span class="w-6 text-center text-sm font-semibold tabular-nums">{item.counts}</span>
                <button type="button" class="flex h-full w-6 items-center justify-center text-muted-foreground hover:text-foreground disabled:text-input" aria-label={t('ui.editor.add_count')} disabled={!editable || !charge.stackable} onclick={() => step(item.chargeId, 1)}><Plus size="0.625rem" /></button>
              </div>
            </div>
          {/if}
        {:else}
          <p class="py-4 text-13 text-muted-foreground">{t('ui.editor.no_charges_yet')}</p>
        {/each}
      </div>

      {#if suspectTotals}
        <div class="flex flex-col gap-2 rounded-lg border border-border bg-muted p-4 text-13">
          <div class="flex justify-between"><span class="text-muted-foreground">{t('ui.common.jail')}</span><span class="font-semibold tabular-nums">{t('ui.common.months', suspectTotals.months)}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">{t('ui.common.fine')}</span><span class="font-semibold tabular-nums">{money(suspectTotals.fine)}</span></div>
          <div class="flex justify-between">
            <span class="text-muted-foreground">{t('ui.common.licence_points')}</span>
            <span class="font-semibold tabular-nums">{outcome ? t('ui.editor.points_reach', suspectTotals.points, outcome.reaches, outcome.limit) : t('ui.editor.points_added', suspectTotals.points)}</span>
          </div>
          {#if outcome?.suspends}
            <p class="text-xs text-warning">{t('ui.editor.suspends', outcome.licence.label.toLowerCase())}</p>
          {/if}
        </div>
      {/if}
    {:else if incident.kind === 'incident'}
      <div class="flex flex-1 flex-col gap-1">
        <h2 class="text-base font-semibold">{t('ui.editor.charges')}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.editor.charges_empty')}</p>
      </div>
    {:else}
      <div class="flex flex-1 flex-col gap-1">
        <h2 class="text-base font-semibold">{kindLabel('report')}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.editor.report_hint')}</p>
      </div>
    {/if}

    {#if editable}
      <div class="mt-auto flex gap-2">
        <Button disabled={busy} onclick={saveDraft}>{t('ui.editor.save_draft')}</Button>
        <Button variant="primary" class="flex-1" disabled={busy || !ready} onclick={file}>{t(`ui.editor.file.${incident.kind}`)}</Button>
      </div>
    {:else if incident.status === 'filed'}
      <p class="mt-auto text-13 text-muted-foreground">{t(`ui.editor.locked.${incident.kind}`)}</p>
    {/if}
  </aside>
</div>

{#if sentences}
  <Dialog title={t('ui.editor.filed_title', kindLabel(incident.kind), incident.id ?? '')} description={sentences.length ? t('ui.editor.filed_description') : t('ui.editor.filed_nobody')} width="w-[32rem]" onclose={() => mdt.go('incidents')}>
    {#if sentences.length}
      <div class="flex flex-col">
        {#each sentences as result, index (index)}
          <div class="flex flex-col gap-0.5 border-b border-border py-2.5 text-13 last:border-b-0">
            <span class="font-medium">{result.name}</span>
            <span class="text-muted-foreground tabular-nums">
              {result.jailed ? t('ui.editor.months_jail', result.months) : t('ui.editor.no_jail')}, {t('ui.editor.fine_amount', money(result.fine))}{result.points ? `, ${plural(result.points, 'ui.plural.points')}` : ''}{result.citizenid ? '' : `, ${t('ui.editor.not_on_record')}`}
            </span>
            {#if result.suspended.length}<span class="text-warning">{t('ui.editor.licence_suspended', result.suspended.join(', '))}</span>{/if}
          </div>
        {/each}
      </div>
    {/if}
    {#snippet actions()}
      <Button variant="primary" onclick={() => mdt.go('incidents')}>{t('ui.editor.back')}</Button>
    {/snippet}
  </Dialog>
{/if}
