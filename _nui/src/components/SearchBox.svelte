<script lang="ts">
  import type { Component } from 'svelte';

  type Props = {
    value: string;
    placeholder: string;
    icon: Component<{ size?: string; class?: string }>;
    count?: string;
    autofocus?: boolean;
    class?: string;
  };

  let { value = $bindable(), placeholder, icon: Icon, count, autofocus = false, class: className = '' }: Props = $props();

  function focus(node: HTMLInputElement) {
    if (autofocus) node.focus();
  }
</script>

<label class="flex h-10 shrink-0 items-center gap-3 rounded-md border border-input px-3 transition-colors focus-within:border-primary {className}">
  <Icon size="1rem" class="shrink-0 text-muted-foreground" />
  <input use:focus bind:value {placeholder} aria-label={placeholder} autocomplete="off" class="h-full min-w-0 flex-1 bg-transparent text-sm font-medium outline-none" />
  {#if count}<span class="shrink-0 text-xs text-muted-foreground tabular-nums">{count}</span>{/if}
</label>
