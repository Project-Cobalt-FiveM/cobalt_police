<script lang="ts">
  import { untrack } from 'svelte';
  import Button from '../ui/Button.svelte';
  import Dialog from '../ui/Dialog.svelte';
  import Field from '../ui/Field.svelte';
  import Tabs from '../ui/Tabs.svelte';
  import Picker from '../ui/Picker.svelte';
  import { t } from '../../lib/locale.svelte';
  import { fetchNui } from '../../lib/nui';
  import { searchPeople } from '../../lib/people';
  import { mdt } from '../../lib/store.svelte';
  import type { Person, Requests } from '../../lib/types';

  type Draft = Requests['addEvidence'][0];

  let { preset, onclose, onadded }: { preset?: Partial<Draft>; onclose: () => void; onadded?: () => void } = $props();

  let draft = $state<Draft>({
    type: 'item',
    title: '',
    description: '',
    image: '',
    location: '',
    citizenid: null,
    incidentId: null,
    ...untrack(() => preset),
  });

  let person = $state<Person | null>(null);

  const ready = $derived(draft.title.trim().length > 0);

  async function add() {
    if (!ready) return;

    const payload: Draft = { ...draft, title: draft.title.trim(), description: draft.description.trim(), citizenid: person?.citizenid ?? draft.citizenid };
    if (!mdt.report(await fetchNui('addEvidence', payload), t('ui.evidence_dialog.added'))) return;

    onadded?.();
    onclose();
  }

  async function useLocation() {
    const here = await fetchNui('getLocation');
    draft.location = here.location;
  }
</script>

<Dialog title={t('ui.evidence_dialog.title')} description={t('ui.evidence_dialog.description')} {onclose} width="w-[32rem]">
  <Tabs
    bind:value={draft.type}
    tabs={[
      { value: 'item', label: t('ui.evidence_type.item') },
      { value: 'photo', label: t('ui.evidence_type.photo') },
      { value: 'forensic', label: t('ui.evidence_type.forensic') },
    ]}
  />
  <Field label={t('ui.common.title')}><input class="field" bind:value={draft.title} maxlength="80" /></Field>
  <Field label={t('ui.common.description')}><textarea class="field h-20 resize-none py-2" bind:value={draft.description} maxlength="600"></textarea></Field>
  {#if draft.type === 'photo'}
    <Field label={t('ui.common.image_link')}><input class="field" bind:value={draft.image} placeholder="https://" /></Field>
  {/if}
  <Field label={t('ui.common.location')}>
    <div class="flex items-center gap-2">
      <input class="field" bind:value={draft.location} maxlength="80" />
      <Button size="sm" onclick={useLocation}>{t('ui.common.use_my_location')}</Button>
    </div>
  </Field>
  <div class="grid grid-cols-[1fr_8rem] gap-3">
    <Field as="div" label={t('ui.evidence_dialog.linked_person')}>
      <div class="flex items-center gap-2">
        <span class="field flex items-center {person ? '' : 'text-muted-foreground'}">{person?.name ?? t('ui.common.none')}</span>
        <Picker label={t('ui.common.pick')} placeholder={t('ui.common.search_citizens')} search={searchPeople} onpick={(picked) => (person = picked)} />
      </div>
    </Field>
    <Field label={t('ui.evidence_dialog.case_number')}>
      <input class="field tabular-nums" type="number" min="1" value={draft.incidentId ?? ''} oninput={(event) => (draft.incidentId = event.currentTarget.value ? Number(event.currentTarget.value) : null)} />
    </Field>
  </div>
  {#snippet actions()}
    <Button onclick={onclose}>{t('ui.common.cancel')}</Button>
    <Button variant="primary" disabled={!ready} onclick={add}>{t('ui.evidence_dialog.add')}</Button>
  {/snippet}
</Dialog>
