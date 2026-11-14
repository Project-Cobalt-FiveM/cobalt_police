<script lang="ts">
  import { onMount } from 'svelte';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import MapPin from 'phosphor-svelte/lib/MapPin';
  import WarningOctagon from 'phosphor-svelte/lib/WarningOctagon';
  import Header from '../components/Header.svelte';
  import BoloDialog from '../components/dialogs/BoloDialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Plate from '../components/ui/Plate.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { age, boloTypeLabel } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Bolo } from '../lib/types';

  type Filter = 'active' | 'vehicle' | 'person' | 'cancelled';

  let bolos = $state<Bolo[]>([]);
  let filter = $state<Filter>('active');
  let creating = $state(false);

  const active = $derived(bolos.filter((bolo) => bolo.status === 'active'));
  const list = $derived(filter === 'cancelled' ? bolos.filter((bolo) => bolo.status === 'cancelled') : filter === 'active' ? active : active.filter((bolo) => bolo.type === filter));
  const departments = $derived([...new Set(active.map((bolo) => bolo.department))].join(` ${t('ui.common.and')} `));

  async function load() {
    bolos = await fetchNui('getBolos', { status: 'all' });
    mdt.counts.bolos = bolos.filter((bolo) => bolo.status === 'active').length;
  }

  onMount(load);

  async function cancel(bolo: Bolo) {
    if (mdt.report(await fetchNui('setBoloStatus', { id: bolo.id, status: 'cancelled' }), t('ui.bolos.cancelled_toast'))) await load();
  }
</script>

<Header title={t('ui.page.bolos')} subtitle={departments ? t('ui.bolos.shared_with', departments) : t('ui.bolos.subtitle')}>
  {#snippet action()}
    {#if mdt.can('manageBolos')}<Button variant="primary" onclick={() => (creating = true)}><PlusSquare size="1rem" />{t('ui.bolo_dialog.title')}</Button>{/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-6" in:crossfade>
  <Tabs
    bind:value={filter}
    tabs={[
      { value: 'active', label: t('ui.common.active'), count: active.length },
      { value: 'vehicle', label: t('ui.page.vehicles'), count: active.filter((bolo) => bolo.type === 'vehicle').length },
      { value: 'person', label: t('ui.bolos.people'), count: active.filter((bolo) => bolo.type === 'person').length },
      { value: 'cancelled', label: t('ui.common.cancelled') },
    ]}
  />

  {#if list.length}
    <div class="grid grid-cols-3 items-start gap-3">
      {#each list as bolo (bolo.id)}
        <article class="group flex flex-col gap-3 rounded-lg border border-border p-4">
          <div class="flex items-center gap-2">
            <Badge>{boloTypeLabel(bolo.type)}</Badge>
            <span class="flex-1 text-13 text-muted-foreground tabular-nums">{bolo.department} #{bolo.id}</span>
            <span class="text-13 text-muted-foreground tabular-nums">{age(bolo.createdAt, mdt.now)}</span>
          </div>
          <h2 class="text-base font-semibold">{bolo.title}</h2>
          {#if bolo.plate}
            {@const plate = bolo.plate}
            <button type="button" class="self-start" aria-label={t('ui.common.look_up_plate', plate)} onclick={() => mdt.navigate({ page: 'vehicles', plate })}><Plate {plate} /></button>
          {/if}
          {#if bolo.description}<p class="text-13 leading-[1.1875rem] text-muted-foreground">{bolo.description}</p>{/if}
          <div class="flex items-center gap-2">
            <span class="flex flex-1 items-center gap-1.5 text-13 font-medium"><MapPin size="0.75rem" class="text-muted-foreground" />{bolo.lastSeen}</span>
            {#if bolo.citizenid}
              {@const citizenid = bolo.citizenid}
              <Button variant="link" onclick={() => mdt.openCitizen(citizenid)}>{t('ui.bolos.profile')}</Button>
            {/if}
            {#if bolo.status === 'active' && mdt.can('manageBolos')}
              <span class="hidden group-focus-within:block group-hover:block"><Button size="xs" onclick={() => cancel(bolo)}>{t('ui.bolos.cancel')}</Button></span>
            {/if}
          </div>
        </article>
      {/each}
    </div>
  {:else}
    <Empty icon={WarningOctagon} title={t('ui.bolos.empty_title')} body={filter === 'cancelled' ? t('ui.bolos.empty_cancelled') : t('ui.bolos.empty_active')} />
  {/if}
</div>

{#if creating}
  <BoloDialog onclose={() => (creating = false)} oncreated={load} />
{/if}
