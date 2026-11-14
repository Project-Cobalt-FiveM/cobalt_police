<script lang="ts">
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import NavigationArrow from 'phosphor-svelte/lib/NavigationArrow';
  import Header from '../components/Header.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Dot from '../components/ui/Dot.svelte';
  import Row from '../components/ui/Row.svelte';
  import Plate from '../components/ui/Plate.svelte';
  import Select from '../components/ui/Select.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Field from '../components/ui/Field.svelte';
  import Empty from '../components/ui/Empty.svelte';
  import Broadcast from 'phosphor-svelte/lib/Broadcast';
  import { fetchNui } from '../lib/nui';
  import { isTyping } from '../lib/dom';
  import { mdt } from '../lib/store.svelte';
  import { clockTime, elapsed, plural, statusDots, statusLabel, unitStatuses } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade, rise } from '../lib/motion';
  import type { Call, Unit, UnitStatus } from '../lib/types';

  type Filter = 'open' | 'mine' | 'closed';

  let filter = $state<Filter>('open');
  let selectedId = $state<number | null>(null);
  let note = $state('');
  let assigning = $state(false);
  let creating = $state(false);
  let callsign = $state(mdt.officer?.callsign ?? '');

  const me = $derived(mdt.officer?.citizenid);
  const ems = $derived(mdt.officer?.isEms ?? false);
  const isMine = (call: Call) => call.responders.some((responder) => responder.citizenid === me);
  const mine = $derived(mdt.openCalls.filter(isMine));
  const closed = $derived(mdt.calls.filter((call) => call.status === 'closed'));
  const list = $derived(filter === 'open' ? mdt.openCalls : filter === 'mine' ? mine : closed);
  const selected = $derived(list.find((call) => call.id === selectedId) ?? list[0] ?? null);
  const responding = $derived(selected ? isMine(selected) : false);
  const assignable = $derived(mdt.units.filter((unit) => !unit.members.every((member) => selected?.responders.some((responder) => responder.citizenid === member.citizenid))));

  const statusOptions = unitStatuses.map((value) => ({ value, label: statusLabel(value) }));

  async function respond(call: Call) {
    const leaving = responding;
    const result = leaving ? await fetchNui('leaveCall', { id: call.id }) : await fetchNui('respondCall', { id: call.id });
    if (!mdt.report(result, leaving ? t('ui.dispatch.left_call') : t('ui.dispatch.responding'))) return;

    if (!leaving && mdt.officer) mdt.officer.status = 'enroute';
  }

  async function waypoint(call: Call) {
    mdt.report(await fetchNui('waypointCall', { id: call.id }), t('ui.common.waypoint_set'));
  }

  async function closeCall(call: Call) {
    mdt.report(await fetchNui('closeCall', { id: call.id }), t('ui.dispatch.call_closed'));
  }

  async function addNote(call: Call) {
    const text = note.trim();
    if (!text) return;

    if (mdt.report(await fetchNui('addCallNote', { id: call.id, text }))) note = '';
  }

  async function assign(call: Call, unit: Unit) {
    assigning = false;
    mdt.report(await fetchNui('assignCall', { id: call.id, unitId: unit.id }), t('ui.dispatch.assigned', unit.callsign));
  }

  async function join(unit: Unit) {
    mdt.report(await fetchNui('joinUnit', { id: unit.id }), t('ui.dispatch.joined', unit.callsign));
  }

  async function leaveUnit() {
    mdt.report(await fetchNui('leaveUnit'), t('ui.dispatch.left_unit'));
  }

  async function disband(unit: Unit) {
    mdt.report(await fetchNui('deleteUnit', { id: unit.id }), t('ui.dispatch.disbanded', unit.callsign));
  }

  async function setUnitStatus(unit: Unit, status: UnitStatus) {
    mdt.report(await fetchNui('setUnitStatus', { id: unit.id, status }));
  }

  async function createUnit() {
    const value = callsign.trim();
    if (!value) return;

    if (mdt.report(await fetchNui('createUnit', { callsign: value }), t('ui.dispatch.unit_created', value))) creating = false;
  }

  function memberNames(unit: Unit): string {
    return unit.members.map((member) => member.name).join(', ') || t('ui.dispatch.no_members');
  }

  $effect(() => {
    if (!assigning) return;
    return mdt.pushLayer(() => (assigning = false));
  });
</script>

<Header title={t('ui.page.dispatch')} subtitle={t('ui.dispatch.subtitle', plural(mdt.openCalls.length, 'ui.plural.open_calls'), plural(mdt.units.reduce((sum, unit) => sum + unit.members.length, 0), 'ui.plural.officers'))}>
  {#snippet action()}
    {#if mdt.can('createIncident')}
      <Button variant="primary" onclick={() => mdt.newIncident()}><PlusSquare size="1rem" />{t('ui.common.new_incident')}</Button>
    {/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex w-[25rem] shrink-0 flex-col gap-3 overflow-y-auto border-r border-border p-5">
    <Tabs
      bind:value={filter}
      tabs={[
        { value: 'open', label: t('ui.dispatch.open'), count: mdt.openCalls.length },
        { value: 'mine', label: t('ui.common.mine'), count: mine.length },
        { value: 'closed', label: t('ui.dispatch.closed') },
      ]}
    />
    <div class="flex flex-col gap-2">
      {#each list as call (call.id)}
        {@const active = call.id === selected?.id}
        <button
          type="button"
          class="flex flex-col gap-1 rounded-lg border px-3 py-2.5 text-left transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
          onclick={() => (selectedId = call.id)}
        >
          <span class="flex items-center gap-2">
            <Badge tone={call.priority === 1 ? 'danger' : active ? 'onPrimary' : 'neutral'} strong>{call.code}</Badge>
            <span class="flex-1 truncate text-sm font-medium">{call.title}</span>
            <span class="text-xs tabular-nums {active ? '' : 'text-muted-foreground'}">{elapsed(call.createdAt, mdt.now)}</span>
          </span>
          <span class="truncate text-xs {active ? '' : 'text-muted-foreground'}">
            {t('ui.dispatch.call_line', call.location, call.responders.length ? plural(call.responders.length, 'ui.plural.units') : t('ui.dispatch.no_units_yet'))}
          </span>
        </button>
      {:else}
        <p class="px-1 py-6 text-sm text-muted-foreground">{filter === 'mine' ? t('ui.dispatch.empty_mine') : filter === 'closed' ? t('ui.dispatch.empty_closed') : t('ui.dispatch.empty_open')}</p>
      {/each}
    </div>
  </section>

  <section class="flex min-w-0 flex-1 flex-col">
    {#if selected}
      {#key selected.id}
        <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto p-6" in:crossfade>
          <div class="flex items-start gap-3">
            <div class="flex min-w-0 flex-1 flex-col gap-1">
              <span class="text-13 text-muted-foreground tabular-nums">{t('ui.dispatch.call_heading', selected.code, selected.id, clockTime(selected.createdAt))}</span>
              <h2 class="text-28 font-semibold tracking-[-0.02em]">{selected.title}</h2>
            </div>
            {#if selected.status === 'open'}
              {#if selected.coords}
                <Button onclick={() => waypoint(selected)}><NavigationArrow size="0.875rem" />{t('ui.common.set_waypoint')}</Button>
              {/if}
              <Button variant={responding ? 'secondary' : 'primary'} onclick={() => respond(selected)}>
                {responding ? t('ui.dispatch.leave_call') : t('ui.dispatch.respond')}
                {#if !responding}<span class="rounded-sm bg-cobalt-hover px-1.5 text-xs">{mdt.keybinds.respond}</span>{/if}
              </Button>
            {/if}
          </div>

          <div class="flex flex-col">
            <Row columns label={t('ui.common.location')}>{selected.location}</Row>
            {#if selected.raisedBy}<Row columns label={t('ui.dispatch.raised_by')}>{selected.raisedBy}</Row>{/if}
            {#if selected.caller}<Row columns label={t('ui.dispatch.caller')}>{selected.caller.name}, {selected.caller.number}</Row>{/if}
            {#if selected.description}<Row columns label={t('ui.dispatch.details')}>{selected.description}</Row>{/if}
            {#if selected.plate}
              <div class="grid grid-cols-[10rem_1fr] items-center gap-4 border-b border-border py-2 text-13">
                <span class="text-muted-foreground">{t('ui.common.plate')}</span>
                <button type="button" class="justify-self-start" aria-label={t('ui.common.look_up_plate', selected.plate)} onclick={() => mdt.navigate({ page: 'vehicles', plate: selected.plate })}>
                  <Plate plate={selected.plate} width={64} />
                </button>
              </div>
            {/if}
          </div>

          <div class="flex flex-col gap-2.5">
            <h3 class="text-sm font-semibold">{t('ui.dispatch.responding')}</h3>
            <div class="flex flex-wrap items-center gap-1.5">
              {#each selected.responders as responder (responder.citizenid)}
                <span class="rounded-md bg-secondary px-2 py-1 text-13 font-medium tabular-nums">{responder.callsign} {responder.name}</span>
              {/each}
              {#if selected.status === 'open' && assignable.length && !ems}
                <div class="relative">
                  <button type="button" class="h-7 rounded-md border border-border px-2 text-13 text-muted-foreground hover:bg-muted hover:text-foreground" onclick={() => (assigning = !assigning)}>{t('ui.dispatch.assign_unit')}</button>
                  {#if assigning}
                    <button type="button" class="fixed inset-0 z-30 cursor-default" aria-label={t('ui.common.close')} tabindex="-1" onclick={() => (assigning = false)}></button>
                    <ul class="absolute top-full left-0 z-40 mt-1 w-60 rounded-lg border border-border bg-popover p-1 shadow-lg" transition:rise>
                      {#each assignable as unit (unit.id)}
                        <li>
                          <button type="button" class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left hover:bg-muted" onclick={() => assign(selected, unit)}>
                            <Dot class={statusDots[unit.status]} />
                            <span class="flex-1 text-sm font-medium tabular-nums">{unit.callsign}</span>
                            <span class="text-xs text-muted-foreground">{statusLabel(unit.status)}</span>
                          </button>
                        </li>
                      {/each}
                    </ul>
                  {/if}
                </div>
              {/if}
            </div>
          </div>

          <div class="flex flex-col gap-2.5">
            <h3 class="text-sm font-semibold">{t('ui.dispatch.notes')}</h3>
            {#each selected.notes as entry, index (index)}
              <p class="flex gap-4 text-13">
                <span class="text-muted-foreground tabular-nums">{clockTime(entry.time)}</span>
                <span><span class="font-semibold">{entry.author}</span> {entry.text}</span>
              </p>
            {:else}
              <p class="text-13 text-muted-foreground">{t('ui.dispatch.no_notes')}</p>
            {/each}
          </div>
        </div>

        <div class="flex items-center gap-3 px-6 pb-6">
          {#if selected.status === 'open'}
            <form class="flex h-9 flex-1 items-center gap-2 rounded-md border border-input pr-1 pl-3 focus-within:border-primary" onsubmit={(event) => (event.preventDefault(), addNote(selected))}>
              <input bind:value={note} placeholder={t('ui.dispatch.note_placeholder')} aria-label={t('ui.dispatch.note')} maxlength="200" class="h-full flex-1 bg-transparent text-sm outline-none" />
              <Button size="xs" type="submit" disabled={!note.trim()}>{t('ui.dispatch.add_note')}</Button>
            </form>
            {#if !ems}<Button onclick={() => closeCall(selected)}>{t('ui.dispatch.close_call')}</Button>{/if}
          {/if}
        </div>
      {/key}
    {:else}
      <Empty icon={Broadcast} title={t('ui.dispatch.none_selected')} body={t('ui.dispatch.none_selected_body')} />
    {/if}
  </section>

  <aside class="flex w-[20rem] shrink-0 flex-col gap-3 overflow-y-auto border-l border-border p-5">
    <div class="flex items-center">
      <h2 class="flex-1 text-base font-semibold">{t('ui.dispatch.units')}</h2>
      <Button variant="link" onclick={() => (creating = true)}>{t('ui.dispatch.new_unit')}</Button>
    </div>
    <div class="flex flex-col">
      {#each mdt.units as unit (unit.id)}
        {@const own = unit.id === mdt.myUnit?.id}
        <div class="group flex flex-col gap-2 border-b border-border py-2.5">
          <div class="flex items-center gap-2.5">
            <Dot class={statusDots[unit.status]} />
            <div class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="truncate text-sm font-semibold tabular-nums">{unit.callsign}</span>
              <span class="truncate text-xs text-muted-foreground">{memberNames(unit)}</span>
            </div>
            {#if own}
              <Badge tone="primary">{t('ui.dispatch.your_unit')}</Badge>
            {:else}
              <span class="text-13 font-medium group-focus-within:hidden group-hover:hidden">{statusLabel(unit.status)}</span>
              <span class="hidden group-focus-within:block group-hover:block"><Button size="xs" onclick={() => join(unit)}>{t('ui.dispatch.join')}</Button></span>
            {/if}
          </div>
          {#if own}
            <div class="flex items-center gap-2 pl-4.5">
              <Select class="flex-1 [&_.field]:h-8 [&_.field]:text-13" label={t('ui.dispatch.unit_status')} options={statusOptions} value={unit.status} onchange={(status) => setUnitStatus(unit, status)} />
              <Button size="sm" onclick={leaveUnit}>{t('ui.dispatch.leave')}</Button>
              {#if unit.members.length === 1 && !ems}<Button size="sm" variant="destructive" onclick={() => disband(unit)}>{t('ui.dispatch.disband')}</Button>{/if}
            </div>
          {/if}
        </div>
      {:else}
        <p class="py-4 text-sm text-muted-foreground">{t('ui.dispatch.no_units')}</p>
      {/each}
    </div>
  </aside>
</div>

{#if creating}
  <Dialog title={t('ui.dispatch.new_unit')} description={t('ui.dispatch.new_unit_description')} onclose={() => (creating = false)}>
    <Field label={t('ui.common.callsign')}><input class="field tabular-nums" bind:value={callsign} maxlength="20" /></Field>
    {#snippet actions()}
      <Button onclick={() => (creating = false)}>{t('ui.common.cancel')}</Button>
      <Button variant="primary" disabled={!callsign.trim()} onclick={createUnit}>{t('ui.dispatch.create_unit')}</Button>
    {/snippet}
  </Dialog>
{/if}

<svelte:window
  onkeydown={(event) => {
    if (event.key.toUpperCase() !== mdt.keybinds.respond.toUpperCase() || !selected || responding || selected.status !== 'open') return;
    if (isTyping(event.target)) return;
    void respond(selected);
  }}
/>
