<script lang="ts">
  import House from 'phosphor-svelte/lib/House';
  import Header from '../components/Header.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import Button from '../components/ui/Button.svelte';
  import Row from '../components/ui/Row.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Property } from '../lib/types';

  let query = $state('');
  let results = $state<Property[]>([]);
  let selectedId = $state<number | null>(null);

  const selected = $derived(results.find((entry) => entry.id === selectedId) ?? null);

  $effect(() => {
    const text = query.trim();
    const timer = setTimeout(async () => {
      results = text.length < 2 ? [] : await fetchNui('searchProperties', { query: text });
      if (!results.some((entry) => entry.id === selectedId)) selectedId = results[0]?.id ?? null;
    }, 200);

    return () => clearTimeout(timer);
  });

  function describe(property: Property): string {
    return property.owner ? t('ui.properties.owned_by', property.type, property.owner) : t('ui.properties.no_owner', property.type);
  }

  async function waypoint(property: Property) {
    mdt.report(await fetchNui('waypointProperty', { id: property.id }), t('ui.common.waypoint_set'));
  }
</script>

<Header title={t('ui.page.properties')} subtitle={t('ui.properties.subtitle')} />

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex w-[28.75rem] shrink-0 flex-col gap-3 overflow-y-auto border-r border-border p-5">
    <SearchBox bind:value={query} icon={House} placeholder={t('ui.properties.placeholder')} autofocus count={query.trim().length > 1 ? plural(results.length, 'ui.plural.matches') : undefined} />
    {#each results as property (property.id)}
      {@const active = property.id === selectedId}
      <button
        type="button"
        class="flex flex-col gap-0.5 rounded-lg border px-3 py-3 text-left transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
        onclick={() => (selectedId = property.id)}
      >
        <span class="text-sm font-medium">{property.label}</span>
        <span class="text-xs {active ? '' : 'text-muted-foreground'}">{describe(property)}</span>
      </button>
    {/each}
  </section>

  <section class="flex min-w-0 flex-1 flex-col">
    {#if selected}
      {#key selected.id}
        <div class="flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto p-6" in:crossfade>
          <div class="flex flex-col gap-1">
            <span class="text-13 text-muted-foreground">{selected.type}</span>
            <h2 class="text-28 font-semibold tracking-[-0.02em]">{selected.label}</h2>
          </div>
          <div class="flex flex-col">
            {#if selected.owner && selected.citizenid}
              {@const citizenid = selected.citizenid}
              <div class="grid grid-cols-[10rem_1fr] items-center gap-4 border-b border-border py-2.5 text-13">
                <span class="text-muted-foreground">{t('ui.properties.owner')}</span>
                <button type="button" class="justify-self-start font-medium text-cobalt-foreground hover:text-foreground" onclick={() => mdt.openCitizen(citizenid)}>{selected.owner}, {citizenid}</button>
              </div>
            {:else}
              <Row columns label={t('ui.properties.owner')}>{t('ui.properties.for_sale')}</Row>
            {/if}
            <Row columns label={t('ui.common.address')}>{selected.address}</Row>
          </div>
        </div>
        <div class="flex gap-2 px-6 pb-6">
          <Button variant="primary" onclick={() => waypoint(selected)}>{t('ui.common.set_waypoint')}</Button>
          {#if selected.citizenid}
            {@const citizenid = selected.citizenid}
            <Button onclick={() => mdt.openCitizen(citizenid)}>{t('ui.common.open_owner')}</Button>
          {/if}
        </div>
      {/key}
    {:else}
      <Empty icon={House} title={query.trim().length > 1 ? t('ui.properties.empty_title') : t('ui.properties.start_title')} body={t('ui.properties.start_body')} />
    {/if}
  </section>
</div>
