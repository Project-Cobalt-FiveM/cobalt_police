<script lang="ts" generics="T">
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import { t } from '../../lib/locale.svelte';
  import { rise } from '../../lib/motion';
  import { mdt } from '../../lib/store.svelte';

  import type { PickOption } from './types';

  type Props = {
    label: string;
    placeholder: string;
    search: (query: string) => Promise<PickOption<T>[]>;
    free?: (query: string) => PickOption<T> | null;
    onpick: (value: T) => void;
  };

  let { label, placeholder, search, free, onpick }: Props = $props();

  let open = $state(false);
  let query = $state('');
  let results = $state<PickOption<T>[]>([]);
  let request = 0;

  const extra = $derived(free && query.trim() ? free(query.trim()) : null);

  $effect(() => {
    if (!open) return;

    const current = ++request;
    const text = query;
    const timer = setTimeout(async () => {
      const found = await search(text);
      if (current === request) results = found;
    }, 250);

    return () => clearTimeout(timer);
  });

  $effect(() => {
    if (!open) return;
    return mdt.pushLayer(close);
  });

  function close() {
    open = false;
    query = '';
  }

  function choose(value: T) {
    onpick(value);
    close();
  }

  function focus(node: HTMLInputElement) {
    node.focus();
  }
</script>

<div class="relative">
  <button
    type="button"
    class="flex h-7 items-center rounded-md border border-border px-2 text-13 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
    onclick={() => (open = !open)}
  >
    {label}
  </button>
  {#if open}
    <button type="button" class="fixed inset-0 z-30 cursor-default" aria-label={t('ui.common.close')} tabindex="-1" onclick={close}></button>
    <div class="absolute top-full left-0 z-40 mt-1 flex w-80 flex-col gap-1 rounded-lg border border-border bg-popover p-1 shadow-lg" transition:rise>
      <div class="flex h-9 items-center gap-2 border-b border-border px-2">
        <MagnifyingGlass size="0.875rem" class="text-muted-foreground" />
        <input use:focus bind:value={query} {placeholder} aria-label={placeholder} class="h-full flex-1 bg-transparent text-sm outline-none" />
      </div>
      <ul class="max-h-64 overflow-y-auto">
        {#each results as result (result.key)}
          <li>
            <button type="button" class="flex w-full flex-col rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => choose(result.value)}>
              <span class="text-sm font-medium">{result.label}</span>
              {#if result.detail}<span class="text-xs text-muted-foreground">{result.detail}</span>{/if}
            </button>
          </li>
        {/each}
        {#if extra}
          <li>
            <button type="button" class="flex w-full flex-col rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => choose(extra.value)}>
              <span class="text-sm font-medium">{extra.label}</span>
              {#if extra.detail}<span class="text-xs text-muted-foreground">{extra.detail}</span>{/if}
            </button>
          </li>
        {/if}
        {#if results.length === 0 && !extra}
          <li class="px-2 py-3 text-13 text-muted-foreground">{t('ui.common.no_matches')}</li>
        {/if}
      </ul>
    </div>
  {/if}
</div>
