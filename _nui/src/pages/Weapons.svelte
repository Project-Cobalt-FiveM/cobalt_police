<script lang="ts">
  import { untrack } from 'svelte';
  import Crosshair from 'phosphor-svelte/lib/Crosshair';
  import Prohibit from 'phosphor-svelte/lib/Prohibit';
  import Header from '../components/Header.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import EvidenceDialog from '../components/dialogs/EvidenceDialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Weapon } from '../lib/types';

  let { initial }: { initial: string | null } = $props();

  let query = $state(untrack(() => initial ?? ''));
  let results = $state<Weapon[]>([]);
  let searched = $state('');
  let recent = $state<Weapon[]>([]);
  let logging = $state(false);

  $effect(() => {
    const text = query.trim();
    const timer = setTimeout(async () => {
      results = text.length < 2 ? [] : await fetchNui('searchWeapons', { query: text });
      searched = text;
      const found = results;
      recent = [...found, ...recent.filter((entry) => !found.some((match) => match.serial === entry.serial))].slice(0, 6);
    }, 300);

    return () => clearTimeout(timer);
  });

  function owner(weapon: Weapon): string {
    return weapon.owner ? t('ui.weapons.registered_to', weapon.owner) : t('ui.weapons.no_owner');
  }
</script>

<Header title={t('ui.page.weapons')} subtitle={t('ui.weapons.subtitle')} />

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <SearchBox bind:value={query} icon={Crosshair} placeholder={t('ui.weapons.placeholder')} autofocus count={searched.length > 1 ? plural(results.length, 'ui.plural.results') : undefined} />

    {#if results.length}
      <div class="flex flex-col gap-2">
        {#each results as weapon (weapon.serial)}
          <div class="flex items-center gap-4 rounded-lg border border-border p-4">
            <span class="w-24 text-base font-semibold tabular-nums">{weapon.serial}</span>
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="text-sm font-medium">{weapon.label}</span>
              <span class="text-xs text-muted-foreground">{owner(weapon)}</span>
            </span>
            {#if weapon.stolen}<Badge tone="danger">{t('ui.common.stolen')}</Badge>{/if}
            {#if weapon.citizenid}
              {@const citizenid = weapon.citizenid}
              <Button size="sm" onclick={() => mdt.openCitizen(citizenid)}>{t('ui.common.open_owner')}</Button>
            {/if}
          </div>
        {/each}
      </div>
    {:else if searched.length > 1}
      <Empty icon={Prohibit} title={t('ui.weapons.empty_title', searched)} body={t('ui.weapons.empty_body')}>
        <Button onclick={() => (query = '')}>{t('ui.weapons.clear_search')}</Button>
        <Button variant="primary" onclick={() => (logging = true)}>{t('ui.weapons.log_evidence')}</Button>
      </Empty>
    {:else}
      <Empty icon={Crosshair} title={t('ui.weapons.start_title')} body={t('ui.weapons.start_body')} />
    {/if}
  </section>

  <aside class="flex w-[21.25rem] shrink-0 flex-col gap-3 border-l border-border p-6">
    <h2 class="text-sm font-semibold">{t('ui.weapons.recent')}</h2>
    {#each recent as weapon (weapon.serial)}
      <button type="button" class="flex flex-col gap-0.5 border-b border-border pb-3 text-left" onclick={() => (query = weapon.serial)}>
        <span class="flex items-center justify-between gap-2">
          <span class="text-sm font-semibold tabular-nums">{weapon.serial}</span>
          <span class="text-xs text-muted-foreground">{weapon.label}</span>
        </span>
        <span class="text-xs text-muted-foreground">{owner(weapon)}</span>
      </button>
    {:else}
      <p class="text-13 text-muted-foreground">{t('ui.weapons.recent_empty')}</p>
    {/each}
  </aside>
</div>

{#if logging}
  <EvidenceDialog preset={{ type: 'item', title: t('ui.weapons.evidence_title', searched) }} onclose={() => (logging = false)} />
{/if}
