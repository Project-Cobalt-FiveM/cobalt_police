<script lang="ts">
  import { t } from '../../lib/locale.svelte';

  let { plate, width = 96 }: { plate: string; width?: 64 | 96 | 240 | 480 } = $props();

  const scale = $derived(width / 480);
  const screws = $derived(width >= 96);
  const stickerText = $derived(width >= 240);
</script>

<div
  class="relative shrink-0 overflow-hidden bg-[#F4F4F2]"
  style:width="{width / 16}rem"
  style:height="{width / 32}rem"
  style:border-radius="{Math.max(2, 14 * scale) / 16}rem"
  style:border="{Math.max(1, 2 * scale) / 16}rem solid #C9CBCF"
  role="img"
  aria-label={t('ui.plate.label', plate)}
>
  <div class="absolute top-0 left-0 h-[15rem] w-[30rem] origin-top-left" style:transform="scale({scale})">
    <div class="absolute top-[1.1875rem] left-[1.1875rem] flex h-[2.25rem] w-[4.125rem] items-center justify-center bg-[#ECEDDB]">
      {#if stickerText}<span class="font-sans text-[1.5625rem] leading-[1.75rem] font-bold tracking-[-0.03em] text-[#1866EA]">MAY</span>{/if}
    </div>
    <div class="absolute top-2 left-[6rem] w-[18rem] text-center font-sans text-[2.75rem] leading-[3.5rem] text-[#D20F0F]">San Andreas</div>
    <div class="absolute top-[1.1875rem] left-[24.6875rem] flex h-[2.25rem] w-[4.125rem] flex-col justify-between bg-[#EE4A0A] px-[0.3125rem] py-[0.1875rem] text-[#111111]">
      {#if stickerText}
        <span class="font-sans text-[0.5rem] leading-[0.5rem] font-bold">SA</span>
        <span class="font-sans text-[0.5625rem] leading-[0.5625rem] tabular-nums">L 6324478</span>
      {/if}
    </div>
    {#if screws}
      {#each [[101, 62], [367, 62], [101, 212], [367, 212]] as [left, top] (`${left}-${top}`)}
        <span class="absolute h-[0.5rem] w-[0.75rem] rounded-full bg-[#8E9096]" style:left="{(left ?? 0) / 16}rem" style:top="{(top ?? 0) / 16}rem"></span>
      {/each}
    {/if}
    <div
      class="absolute top-[4.75rem] left-0 w-[29.75rem] text-center font-sans text-[6.625rem] leading-[8.5rem] font-semibold tracking-[0.02em] text-[#0F2352] tabular-nums"
      class:shadow={screws}
    >
      {plate}
    </div>
  </div>
</div>

<style>
  .shadow {
    text-shadow: 0 0.125rem 0 #b9becb;
  }
</style>
