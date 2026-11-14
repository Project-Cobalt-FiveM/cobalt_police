<script lang="ts">
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import UserCircle from 'phosphor-svelte/lib/UserCircle';
  import Warning from 'phosphor-svelte/lib/Warning';
  import UsersThree from 'phosphor-svelte/lib/UsersThree';
  import Header from '../components/Header.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import TagBadge from '../components/TagBadge.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Row from '../components/ui/Row.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { initials, plural, remaining } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Citizen, CitizenSummary } from '../lib/types';

  type Filter = 'all' | 'wanted' | 'tagged' | 'clean';

  let query = $state('');
  let filter = $state<Filter>('all');
  let results = $state<CitizenSummary[]>([]);
  let selectedId = $state<string | null>(null);
  let preview = $state<Citizen | null>(null);
  let request = 0;

  const filtered = $derived(
    results.filter((person) => {
      if (filter === 'wanted') return person.wanted;
      if (filter === 'tagged') return person.tags.length > 0;
      if (filter === 'clean') return person.convictions === 0;
      return true;
    }),
  );

  $effect(() => {
    const text = query.trim();
    const current = ++request;
    const timer = setTimeout(async () => {
      const found = text.length < 2 ? [] : await fetchNui('searchCitizens', { query: text });
      if (current !== request) return;

      results = found;
      selectedId = found[0]?.citizenid ?? null;
    }, 200);

    return () => clearTimeout(timer);
  });

  $effect(() => {
    const id = selectedId;
    preview = null;
    if (!id) return;

    void fetchNui('getCitizen', { citizenid: id }).then((citizen) => {
      if (selectedId === id) preview = citizen || null;
    });
  });

  function yearsOld(dob: string): string {
    const born = Date.parse(dob);
    if (Number.isNaN(born)) return dob;

    const years = Math.floor((Date.now() - born) / (365.25 * 86400000));
    return t('ui.citizens.years_old', years);
  }

  function licenceSummary(citizen: Citizen): string {
    const held = citizen.licences.filter((licence) => licence.status !== 'none');
    if (!held.length) return t('ui.common.none');

    return held.map((licence) => (licence.status === 'valid' ? licence.label : t(`ui.citizens.licence_${licence.status}`, licence.label))).join(', ');
  }

  function cases(citizen: Citizen): string {
    const charges = citizen.record.convictions.reduce((sum, conviction) => sum + conviction.counts, 0);
    const incidents = new Set(citizen.record.convictions.map((conviction) => conviction.incidentId)).size;
    return charges ? t('ui.citizens.charges_in_cases', plural(charges, 'ui.plural.charges'), plural(incidents, 'ui.plural.cases')) : t('ui.common.none');
  }
</script>

<Header title={t('ui.page.citizens')} subtitle={t('ui.citizens.subtitle')}>
  {#snippet action()}
    {#if mdt.can('createIncident')}
      <Button variant="primary" onclick={() => mdt.newIncident()}><PlusSquare size="1rem" />{t('ui.common.new_incident')}</Button>
    {/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <SearchBox bind:value={query} icon={MagnifyingGlass} placeholder={t('ui.citizens.placeholder')} autofocus count={query.trim().length > 1 ? plural(results.length, 'ui.plural.results') : undefined} />

    {#if results.length}
      <Tabs
        bind:value={filter}
        tabs={[
          { value: 'all', label: t('ui.common.all'), count: results.length },
          { value: 'wanted', label: t('ui.citizens.wanted'), count: results.filter((person) => person.wanted).length },
          { value: 'tagged', label: t('ui.citizens.tagged'), count: results.filter((person) => person.tags.length).length },
          { value: 'clean', label: t('ui.citizens.no_record'), count: results.filter((person) => person.convictions === 0).length },
        ]}
      />

      <div class="flex flex-col gap-1.5">
        <div class="grid grid-cols-[1fr_8rem_8rem_15rem] gap-4 px-4 pl-17 text-xs text-muted-foreground">
          <span>{t('ui.common.name')}</span><span>{t('ui.citizens.citizen_id')}</span><span>{t('ui.common.phone')}</span><span>{t('ui.citizens.flags')}</span>
        </div>
        {#each filtered as person (person.citizenid)}
          {@const active = person.citizenid === selectedId}
          <button
            type="button"
            class="grid grid-cols-[2.25rem_1fr_8rem_8rem_15rem] items-center gap-4 rounded-lg border px-4 py-3 text-left transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
            onclick={() => (selectedId = person.citizenid)}
            ondblclick={() => mdt.openCitizen(person.citizenid)}
          >
            <span class="flex size-9 items-center justify-center rounded-full text-xs font-semibold {active ? 'bg-cobalt-hover' : 'bg-secondary'}">{initials(person.name)}</span>
            <span class="flex min-w-0 flex-col gap-0.5">
              <span class="truncate text-sm font-medium">{person.name}</span>
              <span class="truncate text-xs {active ? '' : 'text-muted-foreground'}">{t('ui.citizens.born', person.dob)}</span>
            </span>
            <span class="text-13 font-medium tabular-nums">{person.citizenid}</span>
            <span class="text-13 font-medium tabular-nums">{person.phone}</span>
            <span class="flex gap-1 overflow-hidden">
              {#if person.wanted}<Badge tone="danger">{t('ui.common.warrant')}</Badge>{/if}
              {#each person.tags.slice(0, 2) as tag (tag.id)}<TagBadge {tag} />{/each}
              {#if !person.wanted && !person.tags.length}<span class="text-xs {active ? '' : 'text-muted-foreground'}">{person.convictions ? plural(person.convictions, 'ui.plural.convictions') : t('ui.citizens.no_record')}</span>{/if}
            </span>
          </button>
        {/each}
      </div>
    {:else}
      <Empty icon={UsersThree} title={query.trim().length > 1 ? t('ui.citizens.empty_title') : t('ui.citizens.start_title')} body={query.trim().length > 1 ? t('ui.citizens.empty_body') : t('ui.citizens.start_body')} />
    {/if}
  </section>

  <aside class="flex w-[25rem] shrink-0 flex-col gap-5 border-l border-border p-6">
    {#if preview}
      {#key preview.citizenid}
        <div class="flex flex-1 flex-col gap-5" in:crossfade>
          <div class="flex items-center gap-4">
            <div class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-secondary">
              {#if preview.image}<img src={preview.image} alt="" class="size-full object-cover" />{:else}<UserCircle size="1.75rem" class="text-muted-foreground" />{/if}
            </div>
            <div class="flex min-w-0 flex-col gap-0.5">
              <h2 class="truncate text-xl font-semibold">{preview.name}</h2>
              <span class="text-13 text-muted-foreground tabular-nums">{preview.citizenid}, {yearsOld(preview.dob)}</span>
            </div>
          </div>

          {#each preview.warrants.slice(0, 1) as warrant (warrant.id)}
            <div class="flex gap-3 rounded-lg border border-border p-4">
              <Warning size="1rem" class="mt-0.5 shrink-0 text-destructive" />
              <div class="flex flex-col gap-0.5">
                <span class="text-sm font-medium">{t(`ui.citizens.active_warrant.${warrant.type}`)}</span>
                <span class="text-13 text-muted-foreground">{warrant.expiresAt != null ? t('ui.citizens.warrant_ends', warrant.title, remaining(warrant.expiresAt, mdt.now)) : t('ui.citizens.warrant_open', warrant.title)}</span>
              </div>
            </div>
          {/each}

          <div class="flex flex-col">
            <Row label={t('ui.common.fingerprint')}>{preview.fingerprint}</Row>
            <Row label={t('ui.common.job')}>{preview.job}</Row>
            <Row label={t('ui.common.licences')}>{licenceSummary(preview)}</Row>
            <Row label={t('ui.citizens.convictions')}>{cases(preview)}</Row>
            <Row label={t('ui.citizens.registered_vehicles')}>{preview.vehicles.length}</Row>
          </div>

          <div class="mt-auto flex gap-2">
            <Button variant="primary" class="flex-1" onclick={() => preview && mdt.openCitizen(preview.citizenid)}>{t('ui.common.open_profile')}</Button>
            {#if mdt.can('createIncident')}
              <Button onclick={() => preview && mdt.newIncident('incident', [{ citizenid: preview.citizenid, name: preview.name }])}>{t('ui.citizens.add_to_incident')}</Button>
            {/if}
          </div>
        </div>
      {/key}
    {:else}
      <p class="text-sm text-muted-foreground">{t('ui.citizens.pick_prompt')}</p>
    {/if}
  </aside>
</div>
