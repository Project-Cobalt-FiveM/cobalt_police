<script lang="ts">
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import Scales from 'phosphor-svelte/lib/Scales';
  import Header from '../components/Header.svelte';
  import WarrantDialog from '../components/dialogs/WarrantDialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Select from '../components/ui/Select.svelte';
  import Row from '../components/ui/Row.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Field from '../components/ui/Field.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { dateTime, remaining, shortDate, warrantStatusLabel, warrantTypeLabel } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Warrant, WarrantCounts, WarrantType } from '../lib/types';

  type Status = Warrant['status'];

  let warrants = $state<Warrant[]>([]);
  let counts = $state<WarrantCounts>({ active: 0, served: 0, expired: 0, cancelled: 0, ending: 0 });
  let shown = $state<Status | null>(null);
  let status = $state<Status>('active');
  let type = $state<WarrantType | 'all'>('all');
  let selectedId = $state<number | null>(null);
  let issuing = $state(false);
  let extending = $state(false);
  let days = $state(2);

  const warnHours = $derived(mdt.settings?.records.warrantWarnHours ?? 48);
  const warn = $derived(warnHours * 3600);
  const list = $derived(shown === status ? warrants.filter((entry) => type === 'all' || entry.type === type) : []);
  const selected = $derived(list.find((entry) => entry.id === selectedId) ?? list[0] ?? null);
  const manage = $derived(mdt.can('manageWarrants'));

  async function load(requested: Status = status) {
    const reply = await fetchNui('getWarrants', { status: requested });
    if (!reply || !('warrants' in reply) || requested !== status) return;

    warrants = reply.warrants;
    counts = reply.counts;
    shown = requested;
    mdt.counts.warrants = reply.counts.active;
  }

  $effect(() => {
    void load(status);
  });

  function endsSoon(entry: Warrant): boolean {
    return entry.status === 'active' && entry.expiresAt != null && entry.expiresAt - mdt.now < warn;
  }

  async function setStatus(entry: Warrant, next: Status) {
    if (mdt.report(await fetchNui('setWarrantStatus', { id: entry.id, status: next }), t(`ui.warrants.status_toast.${next}`))) await load();
  }

  async function extend(entry: Warrant) {
    if (mdt.report(await fetchNui('extendWarrant', { id: entry.id, days }), t('ui.warrants.extended', days))) {
      extending = false;
      await load();
    }
  }
</script>

<Header title={t('ui.page.warrants')} subtitle={t('ui.warrants.subtitle', counts.active, counts.ending, warnHours)}>
  {#snippet action()}
    {#if manage}<Button variant="primary" onclick={() => (issuing = true)}><PlusSquare size="1rem" />{t('ui.warrant_dialog.title')}</Button>{/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <div class="flex items-center gap-4">
      <div class="flex-1">
        <Tabs
          bind:value={status}
          tabs={[
            { value: 'active', label: warrantStatusLabel('active'), count: counts.active },
            { value: 'served', label: warrantStatusLabel('served'), count: counts.served },
            { value: 'expired', label: warrantStatusLabel('expired'), count: counts.expired },
            { value: 'cancelled', label: warrantStatusLabel('cancelled'), count: counts.cancelled },
          ]}
        />
      </div>
      <Select
        class="w-40 [&_.field]:h-8"
        prefix={t('ui.common.type')}
        label={t('ui.common.warrant_type')}
        bind:value={type}
        options={[
          { value: 'all', label: t('ui.common.all') },
          { value: 'arrest', label: warrantTypeLabel('arrest') },
          { value: 'search', label: warrantTypeLabel('search') },
          { value: 'bench', label: warrantTypeLabel('bench') },
        ]}
      />
    </div>

    <div class="overflow-hidden rounded-lg border border-border">
      <div class="grid grid-cols-[4.5rem_1fr_6rem_9rem_4rem] gap-3 border-b border-border px-4 py-2.5 text-xs text-muted-foreground">
        <span>{t('ui.warrants.id')}</span><span>{t('ui.warrants.subject_reason')}</span><span>{t('ui.common.type')}</span><span>{t('ui.warrants.issued_by')}</span><span class="text-right">{t('ui.warrants.ends')}</span>
      </div>
      {#each list as entry (entry.id)}
        {@const isActive = entry.id === selected?.id}
        <button
          type="button"
          class="grid w-full grid-cols-[4.5rem_1fr_6rem_9rem_4rem] items-center gap-3 border-b border-border px-4 py-3 text-left transition-colors last:border-b-0 {isActive ? 'bg-primary' : 'hover:bg-muted'}"
          onclick={() => (selectedId = entry.id)}
        >
          <span class="text-13 tabular-nums {isActive ? 'font-semibold' : 'text-muted-foreground'}">W-{entry.id}</span>
          <span class="flex min-w-0 flex-col gap-0.5">
            <span class="truncate text-sm font-medium">{entry.name}</span>
            <span class="truncate text-xs {isActive ? '' : 'text-muted-foreground'}">{entry.title}</span>
          </span>
          <span class="text-13 font-medium">{warrantTypeLabel(entry.type)}</span>
          <span class="truncate text-13 font-medium">{entry.issuedBy}</span>
          <span class="text-right text-13 font-medium tabular-nums {endsSoon(entry) && !isActive ? 'text-warning' : isActive ? '' : 'text-muted-foreground'}">
            {entry.expiresAt == null ? t('ui.warrants.no_end') : entry.status === 'active' ? remaining(entry.expiresAt, mdt.now) : shortDate(entry.expiresAt)}
          </span>
        </button>
      {:else}
        {#if shown === status}<p class="px-4 py-8 text-center text-sm text-muted-foreground">{t(`ui.warrants.empty.${status}`)}</p>{/if}
      {/each}
    </div>
  </section>

  <aside class="flex w-[26.25rem] shrink-0 flex-col border-l border-border">
    {#if selected}
      {#key selected.id}
        <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto p-6" in:crossfade>
          <div class="flex flex-col gap-1">
            <span class="text-13 text-muted-foreground tabular-nums">{t('ui.warrants.heading', warrantTypeLabel(selected.type), selected.id)}</span>
            <button type="button" class="text-left text-xl font-semibold tracking-[-0.01em] hover:text-cobalt-foreground" onclick={() => selected && mdt.openCitizen(selected.citizenid)}>{selected.name}</button>
          </div>
          <p class="text-sm leading-[1.375rem]">{selected.description || selected.title}</p>
          <div class="flex flex-col">
            <Row label={t('ui.warrants.issued')}>{shortDate(selected.createdAt)}, {selected.issuedBy}</Row>
            <Row label={t('ui.common.status')}>{warrantStatusLabel(selected.status)}</Row>
            {#if selected.expiresAt != null}
              <Row label={t('ui.warrants.ends')} tone={endsSoon(selected) ? 'warning' : 'default'}>
                {selected.status === 'active' ? t('ui.warrants.ends_in', dateTime(selected.expiresAt), remaining(selected.expiresAt, mdt.now)) : dateTime(selected.expiresAt)}
              </Row>
            {/if}
            {#if selected.incidentId != null}
              {@const incidentId = selected.incidentId}
              <div class="flex items-center justify-between border-b border-border py-2.5 text-13">
                <span class="text-muted-foreground">{t('ui.warrants.linked_case')}</span>
                <button type="button" class="font-medium text-cobalt-foreground tabular-nums hover:text-foreground" onclick={() => mdt.openIncident(incidentId)}>#{incidentId}</button>
              </div>
            {/if}
          </div>
        </div>
        {#if manage && selected.status === 'active'}
          <div class="grid grid-cols-2 gap-2 px-6 pb-6">
            <Button variant="primary" class="col-span-2" onclick={() => selected && setStatus(selected, 'served')}>{t('ui.warrants.mark_served')}</Button>
            {#if selected.expiresAt != null}
              <Button onclick={() => (extending = true)}>{t('ui.warrants.extend')}</Button>
            {/if}
            <Button class={selected.expiresAt == null ? 'col-span-2' : ''} onclick={() => selected && setStatus(selected, 'cancelled')}>{t('ui.warrants.cancel')}</Button>
          </div>
        {/if}
      {/key}
    {:else}
      <Empty icon={Scales} title={t('ui.warrants.none_selected')} body={t('ui.warrants.none_selected_body')} />
    {/if}
  </aside>
</div>

{#if issuing}
  <WarrantDialog subject={null} onclose={() => (issuing = false)} onissued={load} />
{/if}

{#if extending && selected}
  {@const target = selected}
  <Dialog title={t('ui.warrants.extend_title', target.id)} description={t('ui.warrants.extend_description', target.name)} onclose={() => (extending = false)}>
    <Field label={t('ui.warrants.extra_days')}><input class="field tabular-nums" type="number" min="1" max="30" bind:value={days} /></Field>
    {#snippet actions()}
      <Button onclick={() => (extending = false)}>{t('ui.common.cancel')}</Button>
      <Button variant="primary" disabled={days < 1} onclick={() => extend(target)}>{t('ui.warrants.extend_warrant')}</Button>
    {/snippet}
  </Dialog>
{/if}
