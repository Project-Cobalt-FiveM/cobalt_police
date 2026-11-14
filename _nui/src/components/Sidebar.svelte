<script lang="ts">
  import type { Component } from 'svelte';
  import ShieldStar from 'phosphor-svelte/lib/ShieldStar';
  import SquaresFour from 'phosphor-svelte/lib/SquaresFour';
  import Broadcast from 'phosphor-svelte/lib/Broadcast';
  import UsersThree from 'phosphor-svelte/lib/UsersThree';
  import Car from 'phosphor-svelte/lib/Car';
  import Crosshair from 'phosphor-svelte/lib/Crosshair';
  import House from 'phosphor-svelte/lib/House';
  import FileText from 'phosphor-svelte/lib/FileText';
  import Scales from 'phosphor-svelte/lib/Scales';
  import WarningOctagon from 'phosphor-svelte/lib/WarningOctagon';
  import Fingerprint from 'phosphor-svelte/lib/Fingerprint';
  import Gavel from 'phosphor-svelte/lib/Gavel';
  import IdentificationBadge from 'phosphor-svelte/lib/IdentificationBadge';
  import GearSix from 'phosphor-svelte/lib/GearSix';
  import { t } from '../lib/locale.svelte';
  import { mdt } from '../lib/store.svelte';
  import type { Page } from '../lib/types';
  import OfficerCard from './OfficerCard.svelte';

  type Item = { page: Page; icon: Component<{ size?: string; class?: string }>; badge?: () => { count: number; urgent: boolean } };

  const groups: Item[][] = [
    [
      { page: 'dashboard', icon: SquaresFour },
      { page: 'dispatch', icon: Broadcast, badge: () => ({ count: mdt.openCalls.length, urgent: true }) },
    ],
    [
      { page: 'citizens', icon: UsersThree },
      { page: 'vehicles', icon: Car },
      { page: 'weapons', icon: Crosshair },
      { page: 'properties', icon: House },
    ],
    [
      { page: 'incidents', icon: FileText },
      { page: 'warrants', icon: Scales, badge: () => ({ count: mdt.counts.warrants, urgent: false }) },
      { page: 'bolos', icon: WarningOctagon, badge: () => ({ count: mdt.counts.bolos, urgent: false }) },
      { page: 'evidence', icon: Fingerprint },
    ],
    [
      { page: 'penalcode', icon: Gavel },
      { page: 'roster', icon: IdentificationBadge },
      { page: 'management', icon: GearSix },
    ],
  ];

  const visible = $derived(groups.map((group) => group.filter((item) => mdt.has(item.page))).filter((group) => group.length > 0));
</script>

<aside class="flex w-60 shrink-0 flex-col gap-4 border-r border-border bg-card px-3 pb-4">
  <div class="-mx-3 flex h-18 shrink-0 items-center gap-3 border-b border-border px-5">
    <div class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
      <ShieldStar size="1.25rem" class="text-foreground" />
    </div>
    <div class="flex min-w-0 flex-col gap-0.5">
      <span class="truncate text-15 font-semibold">{mdt.officer?.department.label}</span>
      <span class="truncate text-xs text-muted-foreground">{mdt.officer?.department.subtitle}</span>
    </div>
  </div>

  <nav class="flex flex-1 flex-col gap-0.5 overflow-y-auto">
    {#each visible as group, index (index)}
      {#if index > 0}<div class="px-2.5 py-1.5"><div class="h-px bg-border"></div></div>{/if}
      {#each group as item (item.page)}
        {@const active = mdt.route.page === item.page}
        {@const badge = item.badge?.()}
        <button
          type="button"
          aria-current={active ? 'page' : undefined}
          class="flex h-9 shrink-0 items-center gap-2.5 rounded-md px-2.5 text-left text-sm font-medium transition-colors {active ? 'bg-primary text-primary-foreground' : 'hover:bg-muted'}"
          onclick={() => mdt.go(item.page)}
        >
          <item.icon size="1rem" class={active ? 'text-primary-foreground' : 'text-muted-foreground'} />
          <span class="flex-1">{t(`ui.page.${item.page}`)}</span>
          {#if badge && badge.count > 0}
            <span class="rounded-sm px-1.5 py-px text-xs font-semibold tabular-nums {badge.urgent ? 'bg-destructive-solid' : active ? 'bg-cobalt-hover' : 'bg-secondary'}">{badge.count}</span>
          {/if}
        </button>
      {/each}
    {/each}
  </nav>

  <OfficerCard />
</aside>
