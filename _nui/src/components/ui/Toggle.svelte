<script lang="ts">
  let { checked = $bindable(), disabled = false, label, onchange }: { checked: boolean; disabled?: boolean; label: string; onchange?: (checked: boolean) => void } = $props();

  function toggle() {
    checked = !checked;
    onchange?.(checked);
  }
</script>

<button
  type="button"
  role="switch"
  aria-checked={checked}
  aria-label={label}
  {disabled}
  class="relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors disabled:cursor-default {checked ? 'bg-primary' : 'bg-secondary'}"
  onclick={toggle}
>
  <span class="absolute left-0.5 size-4 rounded-full transition-transform {checked ? 'translate-x-4 bg-foreground' : 'bg-muted-foreground'}"></span>
</button>
