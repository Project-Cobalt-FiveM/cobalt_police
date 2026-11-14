<script lang="ts">
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import { fetchNui } from '../lib/nui';
  import { t } from '../lib/locale.svelte';
  import { mdt } from '../lib/store.svelte';
  import { rise } from '../lib/motion';
  import type { SearchResults } from '../lib/types';
  import Kbd from './ui/Kbd.svelte';
  import Plate from './ui/Plate.svelte';

  let query = $state('');
  let focused = $state(false);
  let results = $state<SearchResults | null>(null);
  let input = $state<HTMLInputElement>();
  let request = 0;

  const total = $derived(results ? results.citizens.length + results.vehicles.length + results.weapons.length + results.incidents.length : 0);
  const open = $derived(focused && query.trim().length > 1 && results !== null);

  $effect(() => {
    const text = query.trim();
    const current = ++request;
    if (text.length < 2) {
      results = null;
      return;
    }

    const timer = setTimeout(async () => {
      const found = await fetchNui('search', { query: text });
      if (current === request) results = found;
    }, 200);

    return () => clearTimeout(timer);
  });

  $effect(() => {
    if (!open) return;
    return mdt.pushLayer(() => input?.blur());
  });

  function pick(go: () => void) {
    go();
    query = '';
    input?.blur();
  }
</script>

<div class="relative w-[23.75rem] shrink-0">
  <div class="flex h-9 items-center gap-2 rounded-md border border-input px-3 transition-colors focus-within:border-primary">
    <MagnifyingGlass size="0.875rem" class="text-muted-foreground" />
    <input
      id="global-search"
      bind:this={input}
      bind:value={query}
      onfocus={() => (focused = true)}
      onblur={() => (focused = false)}
      placeholder={t('ui.search.placeholder')}
      aria-label={t('ui.search.label')}
      autocomplete="off"
      class="h-full min-w-0 flex-1 bg-transparent text-sm outline-none"
    />
    <Kbd>/</Kbd>
  </div>

  {#if open && results}
    <div
      class="absolute top-full right-0 left-0 z-40 mt-1 flex max-h-[28rem] flex-col overflow-y-auto rounded-lg border border-border bg-popover p-1 shadow-lg"
      role="presentation"
      onmousedown={(event) => event.preventDefault()}
      transition:rise
    >
      {#if total === 0}
        <p class="px-2 py-3 text-13 text-muted-foreground">{t('ui.search.nothing', query.trim())}</p>
      {/if}
      {#if results.citizens.length}
        <p class="px-2 pt-2 pb-1 text-xs text-muted-foreground">{t('ui.page.citizens')}</p>
        {#each results.citizens as person (person.citizenid)}
          <button type="button" class="flex flex-col rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => pick(() => mdt.openCitizen(person.citizenid))}>
            <span class="text-sm font-medium">{person.name}</span>
            <span class="text-xs text-muted-foreground tabular-nums">{person.citizenid}, {person.phone}</span>
          </button>
        {/each}
      {/if}
      {#if results.vehicles.length}
        <p class="px-2 pt-2 pb-1 text-xs text-muted-foreground">{t('ui.page.vehicles')}</p>
        {#each results.vehicles as vehicle (vehicle.plate)}
          <button type="button" class="flex items-center gap-3 rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => pick(() => mdt.navigate({ page: 'vehicles', plate: vehicle.plate }))}>
            <Plate plate={vehicle.plate} width={64} />
            <span class="flex flex-col">
              <span class="text-sm font-medium">{vehicle.label}</span>
              <span class="text-xs text-muted-foreground">{t('ui.vehicles.owner', vehicle.owner)}</span>
            </span>
          </button>
        {/each}
      {/if}
      {#if results.weapons.length}
        <p class="px-2 pt-2 pb-1 text-xs text-muted-foreground">{t('ui.page.weapons')}</p>
        {#each results.weapons as weapon (weapon.serial)}
          <button type="button" class="flex flex-col rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => pick(() => mdt.navigate({ page: 'weapons', serial: weapon.serial }))}>
            <span class="text-sm font-medium tabular-nums">{weapon.serial}</span>
            <span class="text-xs text-muted-foreground">{weapon.label}, {weapon.owner ?? t('ui.search.no_owner')}</span>
          </button>
        {/each}
      {/if}
      {#if results.incidents.length}
        <p class="px-2 pt-2 pb-1 text-xs text-muted-foreground">{t('ui.page.incidents')}</p>
        {#each results.incidents as incident (incident.id)}
          <button type="button" class="flex flex-col rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => pick(() => mdt.openIncident(incident.id))}>
            <span class="text-sm font-medium">{incident.title}</span>
            <span class="text-xs text-muted-foreground tabular-nums">#{incident.id}, {incident.author}</span>
          </button>
        {/each}
      {/if}
    </div>
  {/if}
</div>
