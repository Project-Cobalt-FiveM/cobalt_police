<script lang="ts">
  import { untrack } from 'svelte';
  import Button from '../ui/Button.svelte';
  import Dialog from '../ui/Dialog.svelte';
  import Field from '../ui/Field.svelte';
  import Tabs from '../ui/Tabs.svelte';
  import { boloTypeLabel } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import { fetchNui } from '../../lib/nui';
  import { mdt } from '../../lib/store.svelte';
  import type { Requests } from '../../lib/types';

  type Draft = Requests['createBolo'][0];

  let { preset, onclose, oncreated }: { preset?: Partial<Draft>; onclose: () => void; oncreated?: () => void } = $props();

  let draft = $state<Draft>({
    type: 'vehicle',
    title: '',
    description: '',
    citizenid: null,
    plate: null,
    personName: '',
    lastSeen: '',
    ...untrack(() => preset),
  });

  const ready = $derived(draft.title.trim().length > 0 && draft.lastSeen.trim().length > 0);

  async function create() {
    if (!ready) return;

    const payload: Draft = {
      ...draft,
      title: draft.title.trim(),
      description: draft.description.trim(),
      lastSeen: draft.lastSeen.trim(),
      plate: draft.type === 'vehicle' && draft.plate?.trim() ? draft.plate.trim().toUpperCase() : null,
      personName: draft.type === 'person' ? draft.personName.trim() : '',
    };

    if (!mdt.report(await fetchNui('createBolo', payload), t('ui.bolo_dialog.created'))) return;

    void mdt.refreshCounts();
    oncreated?.();
    onclose();
  }
</script>

<Dialog title={t('ui.bolo_dialog.title')} description={t('ui.bolo_dialog.description')} {onclose} width="w-[32rem]">
  <Tabs
    bind:value={draft.type}
    tabs={[
      { value: 'vehicle', label: boloTypeLabel('vehicle') },
      { value: 'person', label: boloTypeLabel('person') },
    ]}
  />
  <Field label={t('ui.common.title')}><input class="field" bind:value={draft.title} maxlength="80" placeholder={draft.type === 'vehicle' ? t('ui.bolo_dialog.vehicle_example') : t('ui.bolo_dialog.person_example')} /></Field>
  {#if draft.type === 'vehicle'}
    <Field label={t('ui.common.plate')} hint={t('ui.bolo_dialog.plate_hint')}><input class="field uppercase tabular-nums" value={draft.plate ?? ''} oninput={(event) => (draft.plate = event.currentTarget.value)} maxlength="8" /></Field>
  {:else}
    <Field label={t('ui.common.name')}><input class="field" bind:value={draft.personName} maxlength="60" /></Field>
  {/if}
  <Field label={t('ui.common.description')}><textarea class="field h-20 resize-none py-2" bind:value={draft.description} maxlength="600"></textarea></Field>
  <Field label={t('ui.bolo_dialog.last_seen')}><input class="field" bind:value={draft.lastSeen} maxlength="80" placeholder={t('ui.bolo_dialog.last_seen_example')} /></Field>
  {#snippet actions()}
    <Button onclick={onclose}>{t('ui.common.cancel')}</Button>
    <Button variant="primary" disabled={!ready} onclick={create}>{t('ui.bolo_dialog.create')}</Button>
  {/snippet}
</Dialog>
