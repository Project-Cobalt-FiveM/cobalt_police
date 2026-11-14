<script lang="ts">
  import { mdt } from '../lib/store.svelte';
  import { initials, statusDots, statusLabel, unitStatuses } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { UnitStatus } from '../lib/types';
  import Select from './ui/Select.svelte';

  const options = unitStatuses.map((value) => ({ value, label: statusLabel(value), dot: statusDots[value] }));

  let status = $state<UnitStatus>(mdt.myUnit?.status ?? mdt.officer?.status ?? 'available');

  $effect(() => {
    status = mdt.myUnit?.status ?? mdt.officer?.status ?? 'available';
  });
</script>

{#if mdt.officer}
  <div class="flex flex-col gap-2.5 rounded-lg border border-border bg-muted p-3">
    <div class="flex items-center gap-2.5">
      <div class="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold">{initials(mdt.officer.name)}</div>
      <div class="flex min-w-0 flex-1 flex-col gap-0.5">
        <span class="truncate text-sm font-medium">{mdt.officer.name}</span>
        <span class="truncate text-xs text-muted-foreground tabular-nums">{mdt.officer.callsign}, {mdt.officer.gradeName}</span>
      </div>
    </div>
    <Select class="[&_.field]:h-8 [&_.field]:bg-secondary [&_.field]:text-13" label={t('ui.officer.status')} {options} bind:value={status} onchange={(next) => mdt.setStatus(next)} />
  </div>
{/if}
