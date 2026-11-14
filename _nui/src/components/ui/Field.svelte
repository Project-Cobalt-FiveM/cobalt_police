<script lang="ts">
  import type { Snippet } from 'svelte';

  let { label, hint, as = 'label', class: className = '', children }: { label: string; hint?: string; as?: 'label' | 'div'; class?: string; children: Snippet } = $props();
</script>

<svelte:element this={as} class="flex min-w-0 flex-col gap-2 {className}">
  <span class="text-sm font-medium">{label}</span>
  {@render children()}
  {#if hint}<span class="text-xs text-muted-foreground">{hint}</span>{/if}
</svelte:element>
