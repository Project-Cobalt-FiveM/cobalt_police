<script lang="ts">
  import { untrack } from 'svelte';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import Car from 'phosphor-svelte/lib/Car';
  import WarningCircle from 'phosphor-svelte/lib/WarningCircle';
  import Warning from 'phosphor-svelte/lib/Warning';
  import Header from '../components/Header.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import BoloDialog from '../components/dialogs/BoloDialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Row from '../components/ui/Row.svelte';
  import Plate from '../components/ui/Plate.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { plural, vehicleStateLabel } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Vehicle, VehicleSummary } from '../lib/types';

  let { initial }: { initial: string | null } = $props();

  let query = $state(untrack(() => initial ?? ''));
  let results = $state<VehicleSummary[]>([]);
  let selectedPlate = $state<string | null>(untrack(() => initial));
  let vehicle = $state<Vehicle | null>(null);
  let creatingBolo = $state(false);

  $effect(() => {
    const text = query.trim();
    const timer = setTimeout(async () => {
      results = text.length < 2 ? [] : await fetchNui('searchVehicles', { query: text });
      if (!results.some((entry) => entry.plate === selectedPlate)) selectedPlate = results[0]?.plate ?? null;
    }, 200);

    return () => clearTimeout(timer);
  });

  async function load(plate: string) {
    const found = await fetchNui('getVehicle', { plate });
    if (selectedPlate === plate) vehicle = found;
  }

  $effect(() => {
    vehicle = null;
    if (selectedPlate) void load(selectedPlate);
  });

  async function toggleStolen(current: Vehicle) {
    const stolen = !current.stolen;
    if (!mdt.report(await fetchNui('setVehicleStolen', { plate: current.plate, stolen }), stolen ? t('ui.vehicles.marked_stolen') : t('ui.vehicles.stolen_cleared'))) return;

    current.stolen = stolen;
    results = results.map((entry) => (entry.plate === current.plate ? { ...entry, stolen } : entry));
  }
</script>

<Header title={t('ui.page.vehicles')} subtitle={t('ui.vehicles.subtitle')}>
  {#snippet action()}
    {#if mdt.can('createIncident')}
      <Button variant="primary" onclick={() => mdt.newIncident()}><PlusSquare size="1rem" />{t('ui.common.new_incident')}</Button>
    {/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex w-[28.75rem] shrink-0 flex-col gap-3 overflow-y-auto border-r border-border p-5">
    <SearchBox bind:value={query} icon={Car} placeholder={t('ui.vehicles.placeholder')} autofocus count={query.trim().length > 1 ? plural(results.length, 'ui.plural.matches') : undefined} />
    {#each results as entry (entry.plate)}
      {@const active = entry.plate === selectedPlate}
      <button
        type="button"
        class="flex items-center gap-3 rounded-lg border p-3 text-left transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
        onclick={() => (selectedPlate = entry.plate)}
      >
        <Plate plate={entry.plate} />
        <span class="flex min-w-0 flex-1 flex-col gap-0.5">
          <span class="truncate text-sm font-medium">{entry.label}</span>
          <span class="truncate text-xs {active ? '' : 'text-muted-foreground'}">{t('ui.vehicles.owner', entry.owner)}</span>
        </span>
        {#if entry.flagged}
          <Badge tone="danger">{t('ui.vehicles.bolo')}</Badge>
        {:else if entry.stolen}
          <Badge tone={active ? 'onPrimary' : 'neutral'}>{t('ui.common.stolen')}</Badge>
        {:else}
          <span class="text-xs {active ? '' : 'text-muted-foreground'}">{t('ui.vehicles.clear')}</span>
        {/if}
      </button>
    {/each}
  </section>

  <section class="flex min-w-0 flex-1 flex-col">
    {#if vehicle}
      {#key vehicle.plate}
        <div class="flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto p-6" in:crossfade>
          <div class="flex items-start gap-6">
            <div class="flex min-w-0 flex-1 flex-col gap-1">
              <span class="text-13 text-muted-foreground">{vehicle.model}, {t(`ui.vehicles.state_phrase.${vehicle.state}`)}</span>
              <h2 class="text-28 font-semibold tracking-[-0.02em]">{vehicle.label}</h2>
            </div>
            <Plate plate={vehicle.plate} width={240} />
          </div>

          {#each vehicle.bolos as bolo (bolo.id)}
            <div class="flex gap-3 rounded-lg border border-border p-4">
              <WarningCircle size="1rem" class="mt-0.5 shrink-0 text-destructive" />
              <div class="flex flex-1 flex-col gap-0.5">
                <span class="text-sm font-medium">{t('ui.vehicles.active_bolo', bolo.id)}</span>
                <span class="text-13 text-muted-foreground">{t('ui.vehicles.bolo_detail', bolo.description, bolo.lastSeen)}</span>
              </div>
              <Button variant="link" onclick={() => mdt.go('bolos')}>{t('ui.vehicles.view_bolo')}</Button>
            </div>
          {/each}
          {#each vehicle.warrants as warrant (warrant.id)}
            <div class="flex gap-3 rounded-lg border border-border p-4">
              <Warning size="1rem" class="mt-0.5 shrink-0 text-warning" />
              <div class="flex flex-col gap-0.5">
                <span class="text-sm font-medium">{t('ui.vehicles.owner_wanted')}</span>
                <span class="text-13 text-muted-foreground">{t(`ui.vehicles.owner_warrant.${warrant.type}`, warrant.name, warrant.title.toLowerCase())}</span>
              </div>
            </div>
          {/each}

          <div class="flex flex-col">
            <div class="grid grid-cols-[10rem_1fr] items-center gap-4 border-b border-border py-2.5 text-13">
              <span class="text-muted-foreground">{t('ui.vehicles.registered_owner')}</span>
              <button type="button" class="justify-self-start font-medium text-cobalt-foreground hover:text-foreground" onclick={() => vehicle && mdt.openCitizen(vehicle.citizenid)}>{vehicle.owner}, {vehicle.citizenid}</button>
            </div>
            <Row columns label={t('ui.common.status')}>{vehicleStateLabel(vehicle.state)}</Row>
            <Row columns label={t('ui.vehicles.stolen_report')}>{vehicle.stolen ? t('ui.vehicles.reported_stolen') : t('ui.common.none')}</Row>
            <Row columns label={t('ui.vehicles.wheel_clamp')}>{vehicle.clamped ? t('ui.vehicles.clamped') : t('ui.common.none')}</Row>
            <div class="grid grid-cols-[10rem_1fr] items-center gap-4 border-b border-border py-2.5 text-13">
              <span class="text-muted-foreground">{t('ui.vehicles.linked_incidents')}</span>
              <span class="flex gap-2">
                {#each vehicle.incidents as incident (incident.id)}
                  <button type="button" class="font-medium text-cobalt-foreground tabular-nums hover:text-foreground" onclick={() => mdt.openIncident(incident.id)}>#{incident.id}</button>
                {:else}
                  <span class="font-medium">{t('ui.common.none')}</span>
                {/each}
              </span>
            </div>
          </div>
        </div>

        <div class="flex gap-2 px-6 pb-6">
          <Button variant="primary" onclick={() => vehicle && mdt.openCitizen(vehicle.citizenid)}>{t('ui.common.open_owner')}</Button>
          <Button onclick={() => vehicle && toggleStolen(vehicle)}>{vehicle.stolen ? t('ui.vehicles.clear_stolen') : t('ui.vehicles.mark_stolen')}</Button>
          {#if mdt.can('manageBolos')}<Button onclick={() => (creatingBolo = true)}>{t('ui.bolo_dialog.create')}</Button>{/if}
        </div>
      {/key}
    {:else}
      <Empty icon={Car} title={query.trim().length > 1 && !results.length ? t('ui.vehicles.empty_title') : t('ui.vehicles.start_title')} body={query.trim().length > 1 && !results.length ? t('ui.vehicles.empty_body') : t('ui.vehicles.start_body')} />
    {/if}
  </section>
</div>

{#if creatingBolo && vehicle}
  <BoloDialog preset={{ type: 'vehicle', plate: vehicle.plate, title: vehicle.label, citizenid: vehicle.citizenid }} onclose={() => (creatingBolo = false)} oncreated={() => vehicle && load(vehicle.plate)} />
{/if}
