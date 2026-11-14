<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { Tag } from '../lib/types';

  let { tag, children }: { tag: Pick<Tag, 'name' | 'color'>; children?: Snippet } = $props();
</script>

<span class="inline-flex shrink-0 items-center gap-1.5 rounded-sm bg-secondary px-2 py-0.5 text-xs font-medium whitespace-nowrap">
  <span class="size-1.5 shrink-0 rounded-full" style:background-color={tag.color}></span>
  {tag.name}
  {#if children}{@render children()}{/if}
</span>
