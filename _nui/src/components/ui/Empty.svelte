<script lang="ts">
  import type { Component, Snippet } from 'svelte';

  let { icon: Icon, title, body, children }: { icon: Component<{ size?: string; class?: string }>; title: string; body?: string; children?: Snippet } = $props();
</script>

<div class="flex flex-1 flex-col items-center justify-center gap-2 px-6 py-12 text-center">
  <div class="mb-2 flex size-14 items-center justify-center rounded-lg border border-border bg-muted">
    <Icon size="1.5rem" class="text-muted-foreground" />
  </div>
  <p class="text-base font-semibold">{title}</p>
  {#if body}<p class="max-w-sm text-sm text-muted-foreground">{body}</p>{/if}
  {#if children}<div class="mt-4 flex gap-2">{@render children()}</div>{/if}
</div>
