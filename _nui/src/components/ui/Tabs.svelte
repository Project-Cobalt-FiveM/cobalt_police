<script lang="ts" generics="T extends string">
  import type { Tab } from './types';

  type Props = { tabs: Tab<T>[]; value: T; disabled?: boolean; onchange?: (value: T) => void };

  let { tabs, value = $bindable(), disabled = false, onchange }: Props = $props();

  function select(next: T) {
    if (next === value) return;

    value = next;
    onchange?.(next);
  }
</script>

<div class="flex items-center gap-1" role="tablist">
  {#each tabs as tab (tab.value)}
    {@const active = tab.value === value}
    <button
      type="button"
      role="tab"
      aria-selected={active}
      disabled={disabled && !active}
      class="h-7 rounded-md px-2.5 text-13 font-medium whitespace-nowrap transition-colors {active
        ? 'bg-primary text-primary-foreground'
        : 'text-muted-foreground hover:bg-muted hover:text-foreground disabled:pointer-events-none'}"
      onclick={() => select(tab.value)}
    >
      {tab.label}{#if tab.count !== undefined}<span class="ml-1 tabular-nums">{tab.count}</span>{/if}
    </button>
  {/each}
</div>
