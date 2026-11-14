<script lang="ts">
  let { class: className = 'bg-muted-foreground', size = 'size-2' }: { class?: string; size?: string } = $props();
</script>

<span class="inline-block shrink-0 rounded-full {size} {className}"></span>
