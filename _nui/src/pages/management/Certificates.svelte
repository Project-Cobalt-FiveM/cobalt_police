<script lang="ts">
  import { onMount } from 'svelte';
  import Certificate from 'phosphor-svelte/lib/Certificate';
  import Button from '../../components/ui/Button.svelte';
  import Select from '../../components/ui/Select.svelte';
  import { fetchNui } from '../../lib/nui';
  import { mdt } from '../../lib/store.svelte';
  import { plural } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import type { Certificate as CertificateRow } from '../../lib/types';

  let certificates = $state<CertificateRow[]>([]);
  let name = $state('');
  let department = $state(mdt.officer?.department.name ?? '');

  const options = $derived.by(() => {
    const labels = new Map<string, string>();
    if (mdt.officer) labels.set(mdt.officer.department.name, mdt.officer.department.label);

    for (const entry of certificates) {
      if (!labels.has(entry.department)) labels.set(entry.department, entry.departmentLabel);
    }

    return [...labels].map(([value, label]) => ({ value, label }));
  });

  async function load() {
    certificates = await fetchNui('getCertificates');
  }

  onMount(load);

  async function add() {
    const value = name.trim();
    if (!value) return;

    if (mdt.report(await fetchNui('saveCertificate', { id: null, name: value, department }), t('ui.common.added', value))) {
      name = '';
      await load();
    }
  }

  async function remove(entry: CertificateRow) {
    if (mdt.report(await fetchNui('deleteCertificate', { id: entry.id }), t('ui.common.deleted', entry.name))) await load();
  }
</script>

<section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
  <div class="flex flex-col gap-0.5">
    <h2 class="text-xl font-semibold">{t('ui.common.certificates')}</h2>
    <p class="text-13 text-muted-foreground">{t('ui.certificates.description')}</p>
  </div>
  <div class="flex flex-col gap-2">
    {#each certificates as entry (entry.id)}
      <div class="flex items-center gap-4 rounded-lg border border-border px-4 py-3">
        <span class="flex size-8 items-center justify-center rounded-md bg-secondary"><Certificate size="1rem" class="text-muted-foreground" /></span>
        <span class="flex-1 text-sm font-medium">{entry.name}</span>
        <span class="w-24 text-13 text-muted-foreground tabular-nums">{plural(entry.holders, 'ui.plural.officers')}</span>
        <span class="w-16 text-13 font-medium">{entry.departmentLabel}</span>
        <Button variant="destructive" size="xs" onclick={() => remove(entry)}>{t('ui.common.delete')}</Button>
      </div>
    {/each}
  </div>
  <form class="flex gap-2" onsubmit={(event) => (event.preventDefault(), add())}>
    <input class="field flex-1" bind:value={name} placeholder={t('ui.certificates.placeholder')} aria-label={t('ui.certificates.name_label')} maxlength="40" />
    <Select class="w-30" label={t('ui.certificates.department')} {options} bind:value={department} />
    <Button variant="primary" type="submit" disabled={!name.trim()}>{t('ui.certificates.add')}</Button>
  </form>
</section>
