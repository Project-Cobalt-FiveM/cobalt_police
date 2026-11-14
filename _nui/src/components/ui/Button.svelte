<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { HTMLButtonAttributes } from 'svelte/elements';

  type Variant = 'primary' | 'secondary' | 'destructive' | 'link';
  type Size = 'default' | 'sm' | 'xs';

  type Props = HTMLButtonAttributes & { variant?: Variant; size?: Size; children: Snippet };

  let { variant = 'secondary', size = 'default', class: className = '', type = 'button', children, ...rest }: Props = $props();

  const variants: Record<Variant, string> = {
    primary: 'bg-primary text-primary-foreground hover:bg-cobalt-hover',
    secondary: 'bg-secondary border border-input text-foreground hover:bg-secondary-hover',
    destructive: 'bg-destructive-solid text-foreground hover:bg-destructive-hover',
    link: 'text-cobalt-foreground hover:text-foreground',
  };

  const sizes: Record<Size, string> = {
    default: 'h-9 px-4 text-sm',
    sm: 'h-8 px-3 text-13',
    xs: 'h-7 px-2.5 text-13',
  };
</script>

<button
  {type}
  class="inline-flex shrink-0 items-center justify-center gap-2 rounded-md font-medium whitespace-nowrap transition-colors disabled:pointer-events-none disabled:bg-muted disabled:text-muted-foreground {variants[variant]} {variant === 'link' ? 'text-13' : sizes[size]} {className}"
  {...rest}
>
  {@render children()}
</button>
