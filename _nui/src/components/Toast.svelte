<script lang="ts">
  import CheckCircle from 'phosphor-svelte/lib/CheckCircle';
  import WarningCircle from 'phosphor-svelte/lib/WarningCircle';
  import { mdt } from '../lib/store.svelte';
  import { rise } from '../lib/motion';
</script>

{#if mdt.toast}
  {#key mdt.toast.key}
    <div
      class="absolute right-6 bottom-6 z-50 flex w-80 items-start gap-3 rounded-lg border border-border bg-popover p-4 shadow-lg"
      role="status"
      onmouseenter={() => mdt.pauseToast()}
      onmouseleave={() => mdt.resumeToast()}
      transition:rise
    >
      {#if mdt.toast.tone === 'error'}
        <WarningCircle size="1rem" class="mt-0.5 shrink-0 text-destructive" />
      {:else}
        <CheckCircle size="1rem" class="mt-0.5 shrink-0 text-success" />
      {/if}
      <p class="text-sm">{mdt.toast.text}</p>
    </div>
  {/key}
{/if}
