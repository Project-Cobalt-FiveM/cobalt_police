<script lang="ts">
  import MapPin from 'phosphor-svelte/lib/MapPin';
  import UserCircle from 'phosphor-svelte/lib/UserCircle';
  import { mdt } from '../lib/store.svelte';
  import { age, distance, plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { rise } from '../lib/motion';
  import type { Call } from '../lib/types';
  import Kbd from './ui/Kbd.svelte';

  const shown = $derived(mdt.alerts.slice(0, 4));

  function since(call: Call): string {
    return mdt.now - call.createdAt < 60 ? t('ui.alert.now') : age(call.createdAt, mdt.now);
  }

  function source(call: Call): string | null {
    if (call.raisedBy) return call.raisedBy;
    if (call.caller) return `${call.caller.name}, ${call.caller.number}`;
    return null;
  }
</script>

<div class="absolute top-6 right-6 flex w-[23.75rem] flex-col gap-2" aria-live="polite">
  {#each shown as alert, index (alert.key)}
    {@const call = alert.call}
    {@const raisedBy = source(call)}
    <div transition:rise>
      {#if index === 0}
        <div class="flex flex-col gap-3 rounded-lg border border-border bg-popover p-4 shadow-lg">
          <div class="flex items-center gap-2">
            <span class="rounded-sm px-2 py-0.5 text-xs font-semibold tabular-nums {call.priority === 1 ? 'bg-destructive-solid' : 'bg-secondary'}">{call.code}</span>
            <span class="flex-1 truncate text-15 font-semibold">{call.title}</span>
            <span class="text-xs text-muted-foreground tabular-nums">{since(call)}</span>
          </div>
          <div class="flex flex-col gap-1.5 text-13">
            <span class="flex items-center gap-2"><MapPin size="0.875rem" class="shrink-0 text-muted-foreground" />{call.location}, {distance(alert.distance)}</span>
            {#if raisedBy}
              <span class="flex items-center gap-2"><UserCircle size="0.875rem" class="shrink-0 text-muted-foreground" />{raisedBy}</span>
            {/if}
          </div>
          <div class="flex items-center gap-1.5 border-t border-border pt-3 text-xs text-muted-foreground">
            <span class="flex-1">{call.responders.length ? t('ui.alert.responding', plural(call.responders.length, 'ui.plural.units')) : t('ui.dispatch.no_units_yet')}</span>
            <Kbd>{alert.respondKey}</Kbd>{t('ui.dispatch.respond')}
          </div>
          <div class="h-0.75 overflow-hidden rounded-full bg-secondary">
            <div class="countdown h-full origin-left rounded-full bg-primary" style:animation-duration="{alert.seconds}s"></div>
          </div>
        </div>
      {:else}
        <div class="flex items-center gap-2.5 rounded-lg border border-border bg-popover px-3.5 py-3">
          <span class="rounded-sm px-2 py-0.5 text-xs font-semibold tabular-nums {call.priority === 1 ? 'bg-destructive-solid' : 'bg-secondary'}">{call.code}</span>
          <span class="flex min-w-0 flex-1 flex-col gap-0.5">
            <span class="truncate text-sm font-medium">{call.title}</span>
            <span class="truncate text-xs text-muted-foreground">{call.location}, {distance(alert.distance)}</span>
          </span>
          <span class="text-xs text-muted-foreground tabular-nums">{age(call.createdAt, mdt.now)}</span>
        </div>
      {/if}
    </div>
  {/each}
</div>

<style>
  .countdown {
    animation-name: drain;
    animation-timing-function: linear;
    animation-fill-mode: forwards;
  }

  @keyframes drain {
    from {
      transform: scaleX(1);
    }
    to {
      transform: scaleX(0);
    }
  }
</style>
