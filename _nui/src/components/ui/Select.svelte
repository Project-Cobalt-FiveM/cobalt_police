<script lang="ts" generics="T extends string | number">
  import { tick } from 'svelte';
  import CaretDown from 'phosphor-svelte/lib/CaretDown';
  import { rise } from '../../lib/motion';
  import { mdt } from '../../lib/store.svelte';
  import { portal } from '../../lib/portal';
  import Dot from './Dot.svelte';

  import type { Option } from './types';

  type Props = {
    options: Option<T>[];
    value: T;
    prefix?: string;
    label: string;
    disabled?: boolean;
    class?: string;
    onchange?: (value: T) => void;
  };

  type Placement = { left: number; width: number; top?: number; bottom?: number; maxHeight: number };

  const GAP = 4;
  const MAX_HEIGHT = 256;

  let { options, value = $bindable(), prefix, label, disabled = false, class: className = '', onchange }: Props = $props();

  let open = $state(false);
  let active = $state(0);
  let placement = $state<Placement>({ left: 0, width: 0, top: 0, maxHeight: MAX_HEIGHT });
  let trigger = $state<HTMLButtonElement>();
  let list = $state<HTMLUListElement>();

  const current = $derived(options.find((option) => option.value === value));
  const listId = `select-${Math.random().toString(36).slice(2)}`;

  function place() {
    if (!trigger) return;

    const rect = trigger.getBoundingClientRect();
    const below = window.innerHeight - rect.bottom - GAP * 2;
    const above = rect.top - GAP * 2;
    const width = Math.max(rect.width, 160);

    if (below >= Math.min(MAX_HEIGHT, list?.scrollHeight ?? MAX_HEIGHT) || below >= above) {
      placement = { left: rect.left, width, top: rect.bottom + GAP, maxHeight: Math.min(MAX_HEIGHT, below) };
      return;
    }

    placement = { left: rect.left, width, bottom: window.innerHeight - rect.top + GAP, maxHeight: Math.min(MAX_HEIGHT, above) };
  }

  async function show() {
    if (disabled) return;

    active = Math.max(
      options.findIndex((option) => option.value === value),
      0,
    );
    open = true;
    place();
    await tick();
    place();
    focusActive();
  }

  function hide(refocus = true) {
    open = false;
    if (refocus) trigger?.focus();
  }

  function choose(option: Option<T>) {
    value = option.value;
    hide();
    onchange?.(option.value);
  }

  function focusActive() {
    list?.querySelectorAll<HTMLButtonElement>('[role="option"]')[active]?.focus();
  }

  function move(index: number) {
    active = (index + options.length) % options.length;
    focusActive();
  }

  function onTriggerKey(event: KeyboardEvent) {
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;

    event.preventDefault();
    show();
  }

  function onListKey(event: KeyboardEvent) {
    const keys: Record<string, () => void> = {
      ArrowDown: () => move(active + 1),
      ArrowUp: () => move(active - 1),
      Home: () => move(0),
      End: () => move(options.length - 1),
      Tab: () => hide(false),
    };
    const handler = keys[event.key];

    if (!handler) return;

    if (event.key !== 'Tab') event.preventDefault();
    handler();
  }

  function onPointerDown(event: PointerEvent) {
    const target = event.target as Node;
    if (trigger?.contains(target) || list?.contains(target)) return;

    hide(false);
  }

  $effect(() => {
    if (!open) return;

    const releaseLayer = mdt.pushLayer(() => hide());
    window.addEventListener('pointerdown', onPointerDown, true);
    window.addEventListener('resize', place);
    window.addEventListener('scroll', place, true);

    return () => {
      releaseLayer();
      window.removeEventListener('pointerdown', onPointerDown, true);
      window.removeEventListener('resize', place);
      window.removeEventListener('scroll', place, true);
    };
  });
</script>

<div class="relative {className}">
  <button
    bind:this={trigger}
    type="button"
    aria-haspopup="listbox"
    aria-expanded={open}
    aria-controls={listId}
    aria-label={label}
    {disabled}
    class="field flex items-center gap-2 text-left disabled:text-muted-foreground"
    onclick={() => (open ? hide() : show())}
    onkeydown={onTriggerKey}
  >
    {#if current?.dot}<Dot class={current.dot} />{/if}
    {#if prefix}<span class="text-13 text-muted-foreground">{prefix}</span>{/if}
    <span class="min-w-0 flex-1 truncate font-medium">{current?.label ?? ''}</span>
    <CaretDown size="0.75rem" class="text-muted-foreground" />
  </button>
  {#if open}
    <ul
      bind:this={list}
      use:portal
      id={listId}
      role="listbox"
      aria-label={label}
      tabindex="-1"
      class="fixed z-[100] overflow-y-auto rounded-lg border border-border bg-popover p-1 shadow-lg"
      style:left="{placement.left}px"
      style:width="{placement.width}px"
      style:top={placement.top === undefined ? undefined : `${placement.top}px`}
      style:bottom={placement.bottom === undefined ? undefined : `${placement.bottom}px`}
      style:max-height="{placement.maxHeight}px"
      onkeydown={onListKey}
      transition:rise
    >
      {#each options as option, index (option.value)}
        {@const selected = option.value === value}
        <li>
          <button
            type="button"
            role="option"
            aria-selected={selected}
            tabindex={index === active ? 0 : -1}
            class="flex h-8 w-full items-center gap-2 rounded-md px-2 text-left text-sm outline-none {selected
              ? 'bg-primary text-white'
              : 'hover:bg-secondary focus-visible:bg-secondary'}"
            onfocus={() => (active = index)}
            onclick={() => choose(option)}
          >
            {#if option.dot}<Dot class={selected ? 'bg-white' : option.dot} />{/if}
            <span class="flex-1 truncate">{option.label}</span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>
