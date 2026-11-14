<script lang="ts">
  import type { Snippet } from 'svelte';
  import { mdt } from '../../lib/store.svelte';
  import { pop } from '../../lib/motion';

  type Props = { title: string; description?: string; width?: string; onclose: () => void; children?: Snippet; actions: Snippet };

  let { title, description, width = 'w-[28rem]', onclose, children, actions }: Props = $props();

  $effect(() => mdt.pushLayer(onclose));
</script>

<div class="absolute inset-0 z-40 flex items-center justify-center" role="presentation" onmousedown={(event) => event.target === event.currentTarget && onclose()}>
  <div class="flex {width} flex-col gap-4 rounded-lg border border-border bg-popover p-6 shadow-lg" role="dialog" aria-modal="true" aria-label={title} transition:pop>
    <div class="flex flex-col gap-1.5">
      <h2 class="text-lg font-semibold tracking-tight">{title}</h2>
      {#if description}<p class="text-sm text-muted-foreground">{description}</p>{/if}
    </div>
    {#if children}<div class="flex flex-col gap-4">{@render children()}</div>{/if}
    <div class="flex justify-end gap-2">{@render actions()}</div>
  </div>
</div>
