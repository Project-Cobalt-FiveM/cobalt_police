<script lang="ts">
  import { onMount } from 'svelte';
  import Header from '../components/Header.svelte';
  import Button from '../components/ui/Button.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Select from '../components/ui/Select.svelte';
  import Checkbox from '../components/ui/Checkbox.svelte';
  import Dot from '../components/ui/Dot.svelte';
  import Row from '../components/ui/Row.svelte';
  import Field from '../components/ui/Field.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { plural, statusDots, statusLabel } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Certificate, Rank, RosterEntry } from '../lib/types';

  let roster = $state<RosterEntry[]>([]);
  let ranks = $state<Rank[]>([]);
  let certificates = $state<Certificate[]>([]);
  let filter = $state('all');
  let selectedId = $state<string | null>(null);
  let callsign = $state('');
  let grade = $state(0);
  let held = $state<number[]>([]);
  let saving = $state(false);

  const departments = $derived([...new Map(roster.map((entry): [string, string] => [entry.department, entry.departmentLabel]))]);
  const onDuty = $derived(roster.filter((entry) => entry.status !== 'offduty'));
  const list = $derived(filter === 'all' ? roster : filter === 'onduty' ? onDuty : roster.filter((entry) => entry.department === filter));
  const selected = $derived(roster.find((entry) => entry.citizenid === selectedId) ?? null);
  const certificateNames = $derived(new Map(certificates.map((certificate) => [certificate.id, certificate.name])));
  const rankOptions = $derived(ranks.filter((rank) => rank.department === selected?.department).map((rank) => ({ value: rank.grade, label: rank.name })));
  const manageRanks = $derived(mdt.can('manageRanks'));
  const manageCertificates = $derived(mdt.can('manageCertificates'));
  const dirty = $derived(
    selected !== null &&
      (callsign !== selected.callsign || grade !== selected.grade || held.length !== selected.certificates.length || held.some((id) => !selected.certificates.includes(id))),
  );

  async function load() {
    roster = await fetchNui('getRoster');
    if (!selectedId && roster[0]) pick(roster[0]);
  }

  onMount(() => {
    void load();
    if (mdt.can('manageRanks')) void fetchNui('getRanks').then((all) => (ranks = Array.isArray(all) ? all : []));
    void fetchNui('getCertificates').then((all) => (certificates = all));
  });

  function pick(entry: RosterEntry) {
    selectedId = entry.citizenid;
    callsign = entry.callsign;
    grade = entry.grade;
    held = [...entry.certificates];
  }

  function certificateList(entry: RosterEntry): string {
    return entry.certificates.map((id) => certificateNames.get(id)).filter(Boolean).join(', ') || t('ui.common.none');
  }

  function toggle(id: number, checked: boolean) {
    held = checked ? [...held, id] : held.filter((entry) => entry !== id);
  }

  async function save() {
    if (!selected || saving) return;
    saving = true;

    const citizenid = selected.citizenid;
    const results = [];

    if (callsign.trim() !== selected.callsign || grade !== selected.grade) {
      results.push(await fetchNui('saveOfficer', { citizenid, callsign: callsign.trim(), grade }));
    }

    for (const id of held.filter((entry) => !selected.certificates.includes(entry))) {
      results.push(await fetchNui('grantCertificate', { citizenid, certificateId: id }));
    }

    for (const id of selected.certificates.filter((entry) => !held.includes(entry))) {
      results.push(await fetchNui('revokeCertificate', { citizenid, certificateId: id }));
    }

    saving = false;
    const failed = results.find((result) => !result.ok);
    mdt.report(failed ?? { ok: true }, t('ui.common.saved', selected.name));

    await load();
    const fresh = roster.find((entry) => entry.citizenid === citizenid);
    if (fresh) pick(fresh);
  }
</script>

<Header title={t('ui.page.roster')} subtitle={t('ui.roster.subtitle', plural(roster.length, 'ui.plural.officers'), onDuty.length)} />

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <Tabs
      bind:value={filter}
      tabs={[
        { value: 'all', label: t('ui.common.all'), count: roster.length },
        { value: 'onduty', label: t('ui.roster.on_duty'), count: onDuty.length },
        ...departments.map(([name, label]) => ({ value: name, label, count: roster.filter((entry) => entry.department === name).length })),
      ]}
    />
    <div class="overflow-hidden rounded-lg border border-border">
      <div class="grid grid-cols-[1fr_7.5rem_7.5rem_13rem_6.5rem] gap-3 border-b border-border px-4 py-2.5 text-xs text-muted-foreground">
        <span>{t('ui.roster.officer')}</span><span>{t('ui.common.callsign')}</span><span>{t('ui.common.rank')}</span><span>{t('ui.common.certificates')}</span><span>{t('ui.common.status')}</span>
      </div>
      {#each list as entry (entry.citizenid)}
        {@const active = entry.citizenid === selectedId}
        <button
          type="button"
          class="grid w-full grid-cols-[1fr_7.5rem_7.5rem_13rem_6.5rem] items-center gap-3 border-b border-border px-4 py-3 text-left text-13 transition-colors last:border-b-0 {active ? 'bg-primary' : 'hover:bg-muted'}"
          onclick={() => pick(entry)}
        >
          <span class="flex min-w-0 flex-col gap-0.5">
            <span class="truncate text-sm font-medium">{entry.name}</span>
            <span class="truncate text-xs {active ? '' : 'text-muted-foreground'}">{entry.unit ? t('ui.roster.in_unit', entry.departmentLabel, entry.unit) : entry.departmentLabel}</span>
          </span>
          <span class="font-medium tabular-nums">{entry.callsign}</span>
          <span class="font-medium">{entry.gradeName}</span>
          <span class="truncate {active ? '' : 'text-muted-foreground'}">{certificateList(entry)}</span>
          <span class="flex items-center gap-1.5 font-medium {entry.status === 'offduty' && !active ? 'text-muted-foreground' : ''}">
            <Dot class={entry.status === 'offduty' ? 'bg-muted-foreground' : active ? 'bg-primary-foreground' : statusDots[entry.status]} size="size-1.5" />
            {statusLabel(entry.status)}
          </span>
        </button>
      {/each}
    </div>
  </section>

  <aside class="flex w-[22.5rem] shrink-0 flex-col border-l border-border">
    {#if selected}
      {#key selected.citizenid}
        <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto p-6" in:crossfade>
          <div class="flex flex-col gap-1">
            <span class="text-13 text-muted-foreground">{t(selected.online ? 'ui.roster.online' : 'ui.roster.offline', selected.departmentLabel)}</span>
            <h2 class="text-xl font-semibold">{selected.name}</h2>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <Field label={t('ui.common.callsign')}><input class="field tabular-nums" bind:value={callsign} maxlength="16" disabled={!manageRanks} /></Field>
            {#if manageRanks}
              <Field label={t('ui.common.rank')}><Select label={t('ui.common.rank')} options={rankOptions} bind:value={grade} /></Field>
            {:else}
              <Field label={t('ui.common.rank')}><input class="field" value={selected.gradeName} disabled /></Field>
            {/if}
          </div>
          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium">{t('ui.common.certificates')}</span>
            <div class="flex flex-col overflow-hidden rounded-lg border border-border">
              {#each certificates.filter((certificate) => certificate.department === selected.department) as certificate (certificate.id)}
                <div class="flex h-9 items-center gap-3 border-b border-border px-3 text-13 font-medium last:border-b-0">
                  <Checkbox label={certificate.name} checked={held.includes(certificate.id)} disabled={!manageCertificates} onchange={(checked) => toggle(certificate.id, checked)} />
                  {certificate.name}
                </div>
              {:else}
                <p class="px-3 py-3 text-13 text-muted-foreground">{t('ui.roster.no_certificates', selected.departmentLabel)}</p>
              {/each}
            </div>
          </div>
          <div class="flex flex-col">
            <Row label={t('ui.roster.unit')}>{selected.unit ?? t('ui.common.none')}</Row>
            <Row label={t('ui.common.status')}>{statusLabel(selected.status)}</Row>
          </div>
        </div>
        {#if manageRanks || manageCertificates}
          <div class="px-6 pb-6">
            <Button variant="primary" class="w-full" disabled={!dirty || saving || !callsign.trim()} onclick={save}>{t('ui.roster.save')}</Button>
          </div>
        {/if}
      {/key}
    {/if}
  </aside>
</div>
