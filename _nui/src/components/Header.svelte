<script lang="ts">
  import type { Snippet } from 'svelte';
  import GlobalSearch from './GlobalSearch.svelte';
  import Kbd from './ui/Kbd.svelte';
  import { t } from '../lib/locale.svelte';
  import { mdt } from '../lib/store.svelte';

  let { title, subtitle, action }: { title: string; subtitle: string; action?: Snippet } = $props();
</script>

<header class="flex h-18 shrink-0 items-center gap-4 border-b border-border px-6">
  <div class="flex min-w-0 flex-1 flex-col gap-0.5">
    <h1 class="truncate text-xl font-semibold tracking-[-0.01em]">{title}</h1>
    <p class="truncate text-13 text-muted-foreground">{subtitle}</p>
  </div>
  {#if !mdt.officer?.isEms}<GlobalSearch />{/if}
  {#if action}{@render action()}{/if}
  <button type="button" class="flex shrink-0 items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground" onclick={() => mdt.close()}>
    <Kbd>Esc</Kbd>{t('ui.common.close')}
  </button>
</header>
