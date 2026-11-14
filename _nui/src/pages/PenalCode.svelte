<script lang="ts">
  import { onMount } from 'svelte';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import Header from '../components/Header.svelte';
  import Button from '../components/ui/Button.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Toggle from '../components/ui/Toggle.svelte';
  import Row from '../components/ui/Row.svelte';
  import Dot from '../components/ui/Dot.svelte';
  import Field from '../components/ui/Field.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { classDots, classLabel, money, plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Charge, ChargeClass } from '../lib/types';

  type Draft = Omit<Charge, 'id'> & { id: number | null };

  let charges = $state<Charge[]>([]);
  let category = $state('all');
  let draft = $state<Draft | null>(null);

  const manage = $derived(mdt.can('managePenalCode'));
  const categories = $derived([...new Set(charges.map((charge) => charge.category))]);
  const list = $derived(category === 'all' ? charges : charges.filter((charge) => charge.category === category));
  const classes: ChargeClass[] = ['felony', 'misdemeanor', 'infraction'];
  const valid = $derived(draft !== null && draft.code.trim() !== '' && draft.title.trim() !== '' && draft.category.trim() !== '' && draft.months >= 0 && draft.fine >= 0 && draft.points >= 0);

  async function load() {
    charges = await fetchNui('getCharges');
    if (!draft && charges[0]) select(charges[0]);
  }

  onMount(load);

  function select(charge: Charge) {
    draft = { ...charge };
  }

  function blank() {
    draft = { id: null, category: category === 'all' ? (categories[0] ?? '') : category, code: '', title: '', description: '', class: 'misdemeanor', months: 0, fine: 0, points: 0, stackable: true };
  }

  async function save() {
    if (!draft || !valid) return;

    const payload = { ...draft, code: draft.code.trim(), title: draft.title.trim(), category: draft.category.trim(), description: draft.description.trim() };
    if (mdt.report(await fetchNui('saveCharge', payload), draft.id === null ? t('ui.penal.added') : t('ui.penal.saved'))) {
      const code = payload.code;
      draft = null;
      await load();
      const saved = charges.find((charge) => charge.code === code);
      if (saved) select(saved);
    }
  }

  async function remove() {
    if (!draft || draft.id === null) return;

    if (mdt.report(await fetchNui('deleteCharge', { id: draft.id }), t('ui.penal.deleted'))) {
      draft = null;
      await load();
    }
  }
</script>

<Header title={t('ui.page.penalcode')} subtitle={t('ui.penal.subtitle', plural(charges.length, 'ui.plural.charges'), plural(categories.length, 'ui.plural.categories'))}>
  {#snippet action()}
    {#if manage}<Button variant="primary" onclick={blank}><PlusSquare size="1rem" />{t('ui.penal.new')}</Button>{/if}
  {/snippet}
</Header>

<div class="flex min-h-0 flex-1" in:crossfade>
  <section class="flex min-w-0 flex-1 flex-col gap-4 overflow-y-auto p-6">
    <Tabs
      bind:value={category}
      tabs={[{ value: 'all', label: t('ui.common.all'), count: charges.length }, ...categories.map((name) => ({ value: name, label: name, count: charges.filter((charge) => charge.category === name).length }))]}
    />
    <div class="overflow-hidden rounded-lg border border-border">
      <div class="grid grid-cols-[7rem_1fr_8.5rem_4.5rem_5.5rem_3.5rem] gap-3 border-b border-border px-4 py-2.5 text-xs text-muted-foreground">
        <span>{t('ui.penal.code')}</span><span>{t('ui.common.charge')}</span><span>{t('ui.common.class')}</span><span class="text-right">{t('ui.common.jail')}</span><span class="text-right">{t('ui.common.fine')}</span><span class="text-right">{t('ui.penal.points')}</span>
      </div>
      {#each list as charge (charge.id)}
        {@const active = charge.id === draft?.id}
        <button
          type="button"
          class="grid w-full grid-cols-[7rem_1fr_8.5rem_4.5rem_5.5rem_3.5rem] items-center gap-3 border-b border-border px-4 py-3 text-left text-13 transition-colors last:border-b-0 {active ? 'bg-primary' : 'hover:bg-muted'}"
          onclick={() => select(charge)}
        >
          <span class="tabular-nums {active ? '' : 'text-muted-foreground'}">{charge.code}</span>
          <span class="truncate text-sm font-medium">{charge.title}</span>
          <span class="flex items-center gap-1.5 font-medium"><Dot class={active ? 'bg-primary-foreground' : classDots[charge.class]} size="size-1.5" />{classLabel(charge.class)}</span>
          <span class="text-right font-medium tabular-nums">{t('ui.penal.months_short', charge.months)}</span>
          <span class="text-right font-medium tabular-nums">{money(charge.fine)}</span>
          <span class="text-right tabular-nums {active ? '' : 'text-muted-foreground'}">{charge.points}</span>
        </button>
      {/each}
    </div>
  </section>

  <aside class="flex w-[25rem] shrink-0 flex-col border-l border-border">
    {#if draft}
      {#if manage}
        <div class="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
          <h2 class="text-base font-semibold">{draft.id === null ? t('ui.penal.new') : t('ui.penal.edit')}</h2>
          <div class="grid grid-cols-[7.5rem_1fr] gap-3">
            <Field label={t('ui.penal.code')}><input class="field tabular-nums" bind:value={draft.code} maxlength="20" /></Field>
            <Field label={t('ui.common.name')}><input class="field" bind:value={draft.title} maxlength="80" /></Field>
          </div>
          <Field label={t('ui.penal.category')}><input class="field" bind:value={draft.category} maxlength="30" list="charge-categories" /></Field>
          <datalist id="charge-categories">{#each categories as name (name)}<option value={name}></option>{/each}</datalist>
          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium">{t('ui.common.class')}</span>
            <div class="grid grid-cols-3 gap-1 rounded-md border border-border p-1">
              {#each classes as value (value)}
                <button
                  type="button"
                  class="h-7 rounded-sm text-13 font-medium transition-colors {draft.class === value ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted hover:text-foreground'}"
                  onclick={() => draft && (draft.class = value)}
                >
                  {classLabel(value)}
                </button>
              {/each}
            </div>
          </div>
          <div class="grid grid-cols-[1fr_1fr_4.5rem] gap-3">
            <Field label={t('ui.penal.jail_months')}><input class="field tabular-nums" type="number" min="0" bind:value={draft.months} /></Field>
            <Field label={t('ui.common.fine')}>
              <span class="field flex items-center gap-1 focus-within:border-primary">
                <span class="text-muted-foreground">$</span>
                <input class="h-full min-w-0 flex-1 bg-transparent tabular-nums outline-none" type="number" min="0" step="50" aria-label={t('ui.common.fine')} bind:value={draft.fine} />
              </span>
            </Field>
            <Field label={t('ui.penal.points')}><input class="field tabular-nums" type="number" min="0" bind:value={draft.points} /></Field>
          </div>
          <Field label={t('ui.common.description')}><textarea class="field h-22 resize-none py-2" bind:value={draft.description} maxlength="400"></textarea></Field>
          <div class="flex items-start gap-3">
            <Toggle label={t('ui.penal.stackable')} bind:checked={draft.stackable} />
            <div class="flex flex-col gap-0.5">
              <span class="text-sm font-medium">{t('ui.penal.stackable')}</span>
              <span class="text-xs text-muted-foreground">{t('ui.penal.stackable_hint')}</span>
            </div>
          </div>
        </div>
        <div class="flex gap-2 px-6 pb-6">
          {#if draft.id !== null}<Button variant="destructive" onclick={remove}>{t('ui.common.delete')}</Button>{/if}
          <span class="flex-1"></span>
          <Button variant="primary" disabled={!valid} onclick={save}>{draft.id === null ? t('ui.penal.add') : t('ui.penal.save')}</Button>
        </div>
      {:else}
        <div class="flex flex-col gap-5 p-6" in:crossfade>
          <div class="flex flex-col gap-1">
            <span class="text-13 text-muted-foreground tabular-nums">{draft.code}</span>
            <h2 class="text-xl font-semibold">{draft.title}</h2>
          </div>
          <p class="text-sm text-muted-foreground">{draft.description}</p>
          <div class="flex flex-col">
            <Row label={t('ui.common.class')}>{classLabel(draft.class)}</Row>
            <Row label={t('ui.common.jail')}>{t('ui.common.months', draft.months)}</Row>
            <Row label={t('ui.common.fine')}>{money(draft.fine)}</Row>
            <Row label={t('ui.common.licence_points')}>{draft.points}</Row>
            <Row label={t('ui.penal.multiple_counts')}>{draft.stackable ? t('ui.penal.allowed') : t('ui.common.no')}</Row>
          </div>
        </div>
      {/if}
    {/if}
  </aside>
</div>
