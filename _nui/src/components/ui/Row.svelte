<script lang="ts">
  import type { Snippet } from 'svelte';

  type Props = { label: string; tone?: 'default' | 'warning'; columns?: boolean; children: Snippet };

  let { label, tone = 'default', columns = false, children }: Props = $props();

  const tones = { default: 'text-foreground', warning: 'text-warning' };
</script>

{#if columns}
  <div class="grid grid-cols-[10rem_1fr] gap-4 border-b border-border py-2.5 text-13">
    <span class="text-muted-foreground">{label}</span>
    <span class="min-w-0 font-medium tabular-nums {tones[tone]}">{@render children()}</span>
  </div>
{:else}
  <div class="flex items-start justify-between gap-4 border-b border-border py-2.5 text-13">
    <span class="shrink-0 text-muted-foreground">{label}</span>
    <span class="min-w-0 text-right font-medium tabular-nums {tones[tone]}">{@render children()}</span>
  </div>
{/if}
