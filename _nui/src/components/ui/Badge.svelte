<script lang="ts">
  import type { Snippet } from 'svelte';

  type Tone = 'neutral' | 'primary' | 'onPrimary' | 'danger';

  let { tone = 'neutral', strong = false, class: className = '', children }: { tone?: Tone; strong?: boolean; class?: string; children: Snippet } = $props();

  const tones: Record<Tone, string> = {
    neutral: 'bg-secondary text-foreground',
    primary: 'bg-primary text-primary-foreground',
    onPrimary: 'bg-cobalt-hover text-primary-foreground',
    danger: 'bg-destructive-solid text-foreground',
  };
</script>

<span class="inline-flex shrink-0 items-center gap-1.5 rounded-sm px-2 py-0.5 text-xs whitespace-nowrap tabular-nums {strong ? 'font-semibold' : 'font-medium'} {tones[tone]} {className}">
  {@render children()}
</span>
