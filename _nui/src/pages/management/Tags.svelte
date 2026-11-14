<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '../../components/ui/Button.svelte';
  import Field from '../../components/ui/Field.svelte';
  import TagBadge from '../../components/TagBadge.svelte';
  import { t } from '../../lib/locale.svelte';
  import { fetchNui } from '../../lib/nui';
  import { mdt } from '../../lib/store.svelte';
  import type { Tag } from '../../lib/types';

  type Row = Tag & { holders: number };

  const palette = ['#DC2626', '#D97706', '#EAB308', '#16A34A', '#0891B2', '#9333EA', '#A3A3A3'];

  let tags = $state<Row[]>([]);
  let editingId = $state<number | null>(null);
  let name = $state('');
  let color = $state(palette[0] ?? '#A3A3A3');

  async function load() {
    tags = await fetchNui('getTags');
  }

  onMount(load);

  function edit(tag: Row) {
    editingId = tag.id;
    name = tag.name;
    color = tag.color;
  }

  function reset() {
    editingId = null;
    name = '';
    color = palette[0] ?? '#A3A3A3';
  }

  async function save() {
    if (!name.trim()) return;

    if (mdt.report(await fetchNui('saveTag', { id: editingId, name: name.trim(), color }), editingId === null ? t('ui.tags.added') : t('ui.tags.saved'))) {
      reset();
      await load();
    }
  }

  async function remove(tag: Row) {
    if (mdt.report(await fetchNui('deleteTag', { id: tag.id }), t('ui.common.deleted', tag.name))) {
      if (editingId === tag.id) reset();
      await load();
    }
  }
</script>

<section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
  <div class="flex flex-col gap-0.5">
    <h2 class="text-xl font-semibold">{t('ui.tags.title')}</h2>
    <p class="text-13 text-muted-foreground">{t('ui.tags.description')}</p>
  </div>
  <div class="overflow-hidden rounded-lg border border-border">
    <div class="grid grid-cols-[1fr_9rem_5rem_9rem] gap-3 border-b border-border px-4 py-2.5 text-xs text-muted-foreground">
      <span>{t('ui.tags.tag')}</span><span>{t('ui.tags.colour')}</span><span class="text-right">{t('ui.page.citizens')}</span><span></span>
    </div>
    {#each tags as tag (tag.id)}
      <div class="grid grid-cols-[1fr_9rem_5rem_9rem] items-center gap-3 border-b border-border px-4 py-2.5 text-13 last:border-b-0 {tag.id === editingId ? 'bg-muted' : ''}">
        <span><TagBadge {tag} /></span>
        <span class="flex items-center gap-2 text-muted-foreground tabular-nums"><span class="size-3 rounded-sm" style:background-color={tag.color}></span>{tag.color.toUpperCase()}</span>
        <span class="text-right font-medium tabular-nums">{tag.holders}</span>
        <span class="flex justify-end gap-2">
          <Button size="xs" onclick={() => edit(tag)}>{t('ui.common.edit')}</Button>
          <Button variant="destructive" size="xs" onclick={() => remove(tag)}>{t('ui.common.delete')}</Button>
        </span>
      </div>
    {:else}
      <p class="px-4 py-6 text-center text-sm text-muted-foreground">{t('ui.tags.empty')}</p>
    {/each}
  </div>
</section>

<aside class="flex w-[20rem] shrink-0 flex-col gap-5 border-l border-border p-6">
  <h2 class="text-base font-semibold">{editingId === null ? t('ui.tags.new') : t('ui.tags.edit')}</h2>
  <Field label={t('ui.common.name')}><input class="field" bind:value={name} maxlength="30" placeholder={t('ui.tags.name_example')} /></Field>
  <div class="flex flex-col gap-2">
    <span class="text-sm font-medium">{t('ui.tags.colour')}</span>
    <div class="flex gap-2">
      {#each palette as swatch (swatch)}
        <button
          type="button"
          class="size-7 rounded-md border-2 transition-colors {swatch === color ? 'border-foreground' : 'border-transparent'}"
          style:background-color={swatch}
          aria-label={t('ui.tags.colour_swatch', swatch)}
          aria-pressed={swatch === color}
          onclick={() => (color = swatch)}
        ></button>
      {/each}
    </div>
  </div>
  <div class="flex flex-col gap-2">
    <span class="text-sm font-medium">{t('ui.tags.preview')}</span>
    <span><TagBadge tag={{ name: name || t('ui.tags.preview_name'), color }} /></span>
  </div>
  <div class="mt-auto flex gap-2">
    {#if editingId !== null}<Button onclick={reset}>{t('ui.common.cancel')}</Button>{/if}
    <Button variant="primary" class="flex-1" disabled={!name.trim()} onclick={save}>{editingId === null ? t('ui.tags.add') : t('ui.tags.save')}</Button>
  </div>
</aside>
