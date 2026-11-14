<script lang="ts">
  import Check from 'phosphor-svelte/lib/Check';

  let { checked, disabled = false, label, onchange }: { checked: boolean; disabled?: boolean; label: string; onchange: (checked: boolean) => void } = $props();
</script>

<button
  type="button"
  role="checkbox"
  aria-checked={checked}
  aria-label={label}
  {disabled}
  class="flex size-4 shrink-0 items-center justify-center rounded-sm border transition-colors {checked ? 'border-primary bg-primary' : 'border-input bg-muted'}"
  onclick={() => onchange(!checked)}
>
  {#if checked}<Check size="0.625rem" class="text-primary-foreground" />{/if}
</button>
