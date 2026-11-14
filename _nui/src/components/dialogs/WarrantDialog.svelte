<script lang="ts">
  import { untrack } from 'svelte';
  import Button from '../ui/Button.svelte';
  import Dialog from '../ui/Dialog.svelte';
  import Field from '../ui/Field.svelte';
  import Select from '../ui/Select.svelte';
  import Picker from '../ui/Picker.svelte';
  import { warrantTypeLabel } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import { fetchNui } from '../../lib/nui';
  import { searchPeople } from '../../lib/people';
  import { mdt } from '../../lib/store.svelte';
  import type { Person, WarrantType } from '../../lib/types';

  let { subject: initial, onclose, onissued }: { subject: Person | null; onclose: () => void; onissued?: () => void } = $props();

  let subject = $state<Person | null>(untrack(() => initial));
  let type = $state<WarrantType>('arrest');
  let title = $state('');
  let description = $state('');
  let days = $state(3);

  const types = (['arrest', 'search', 'bench'] as const).map((value) => ({ value, label: warrantTypeLabel(value) }));

  const ready = $derived(subject?.citizenid != null && title.trim().length > 0 && days > 0);

  async function issue() {
    const citizenid = subject?.citizenid;
    if (!citizenid || !ready) return;

    const result = await fetchNui('createWarrant', { citizenid, type, title: title.trim(), description: description.trim(), expiresInDays: days });
    if (!mdt.report(result, t('ui.warrant_dialog.issued'))) return;

    void mdt.refreshCounts();
    onissued?.();
    onclose();
  }
</script>

<Dialog title={t('ui.warrant_dialog.title')} description={t('ui.warrant_dialog.description')} {onclose} width="w-[32rem]">
  <Field as="div" label={t('ui.warrant_dialog.subject')}>
    <div class="flex items-center gap-2">
      <span class="field flex items-center font-medium {subject ? '' : 'text-muted-foreground'}">{subject?.name ?? t('ui.warrant_dialog.nobody')}</span>
      <Picker label={subject ? t('ui.common.change') : t('ui.common.pick')} placeholder={t('ui.common.search_citizens')} search={searchPeople} onpick={(person) => (subject = person)} />
    </div>
  </Field>
  <div class="grid grid-cols-[1fr_8rem] gap-3">
    <Field label={t('ui.common.type')}><Select label={t('ui.common.warrant_type')} options={types} bind:value={type} /></Field>
    <Field label={t('ui.warrant_dialog.days')}><input class="field tabular-nums" type="number" min="1" max="60" bind:value={days} /></Field>
  </div>
  <Field label={t('ui.common.reason')}><input class="field" bind:value={title} maxlength="120" placeholder={t('ui.warrant_dialog.reason_example')} /></Field>
  <Field label={t('ui.warrant_dialog.details')}><textarea class="field h-24 resize-none py-2" bind:value={description} maxlength="1000"></textarea></Field>
  {#snippet actions()}
    <Button onclick={onclose}>{t('ui.common.cancel')}</Button>
    <Button variant="primary" disabled={!ready} onclick={issue}>{t('ui.warrant_dialog.issue')}</Button>
  {/snippet}
</Dialog>
