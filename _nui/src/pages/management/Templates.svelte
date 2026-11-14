<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '../../components/ui/Button.svelte';
  import Tabs from '../../components/ui/Tabs.svelte';
  import Field from '../../components/ui/Field.svelte';
  import { fetchNui } from '../../lib/nui';
  import { mdt } from '../../lib/store.svelte';
  import { kindLabel } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import type { IncidentKind, Template } from '../../lib/types';

  type Draft = { id: number | null; kind: IncidentKind; name: string; content: string };

  let templates = $state<Template[]>([]);
  let draft = $state<Draft | null>(null);

  const valid = $derived(draft !== null && draft.name.trim() !== '' && draft.content.trim() !== '');

  async function load() {
    templates = await fetchNui('getTemplates');
    if (!draft && templates[0]) pick(templates[0]);
  }

  onMount(load);

  function pick(template: Template) {
    draft = { id: template.id, kind: template.kind, name: template.name, content: template.content };
  }

  async function save() {
    if (!draft || !valid) return;

    const payload = { ...draft, name: draft.name.trim() };
    if (mdt.report(await fetchNui('saveTemplate', payload), draft.id === null ? t('ui.templates.added') : t('ui.templates.saved'))) {
      draft = null;
      await load();
      const saved = templates.find((entry) => entry.name === payload.name);
      if (saved) pick(saved);
    }
  }

  async function remove() {
    if (!draft || draft.id === null) return;

    if (mdt.report(await fetchNui('deleteTemplate', { id: draft.id }), t('ui.common.deleted', draft.name))) {
      draft = null;
      await load();
    }
  }
</script>

<section class="flex w-[18.75rem] shrink-0 flex-col gap-2 overflow-y-auto border-r border-border p-5">
  <div class="flex items-center">
    <h2 class="flex-1 text-sm font-semibold">{t('ui.templates.title')}</h2>
    <Button variant="link" onclick={() => (draft = { id: null, kind: 'incident', name: '', content: '' })}>{t('ui.templates.new')}</Button>
  </div>
  {#each templates as template (template.id)}
    {@const active = template.id === draft?.id}
    <button
      type="button"
      class="flex flex-col gap-0.5 rounded-lg border px-3 py-2.5 text-left transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
      onclick={() => pick(template)}
    >
      <span class="text-sm font-medium">{template.name}</span>
      <span class="text-xs {active ? '' : 'text-muted-foreground'}">{kindLabel(template.kind)}</span>
    </button>
  {/each}
</section>

<section class="flex min-w-0 flex-1 flex-col gap-4 p-6">
  {#if draft}
    <div class="grid grid-cols-[1fr_12.5rem] gap-3">
      <Field label={t('ui.common.name')}><input class="field" bind:value={draft.name} maxlength="40" /></Field>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium">{t('ui.templates.used_for')}</span>
        <div class="rounded-md border border-border p-1 [&>div]:grid [&>div]:grid-cols-2">
          <Tabs
            bind:value={draft.kind}
            tabs={[
              { value: 'incident', label: kindLabel('incident') },
              { value: 'report', label: kindLabel('report') },
            ]}
          />
        </div>
      </div>
    </div>
    <label class="flex min-h-0 flex-1 flex-col gap-2">
      <span class="text-sm font-medium">{t('ui.common.narrative')}</span>
      <textarea class="field min-h-0 flex-1 resize-none py-3 leading-6" bind:value={draft.content} maxlength="8000"></textarea>
      <span class="text-xs text-muted-foreground">{t('ui.templates.hint')}</span>
    </label>
    <div class="flex gap-2">
      {#if draft.id !== null}<Button variant="destructive" onclick={remove}>{t('ui.common.delete')}</Button>{/if}
      <span class="flex-1"></span>
      <Button variant="primary" disabled={!valid} onclick={save}>{draft.id === null ? t('ui.templates.add') : t('ui.templates.save')}</Button>
    </div>
  {:else}
    <p class="text-sm text-muted-foreground">{t('ui.templates.empty')}</p>
  {/if}
</section>
