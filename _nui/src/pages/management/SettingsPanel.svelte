<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '../../components/ui/Button.svelte';
  import Toggle from '../../components/ui/Toggle.svelte';
  import Select from '../../components/ui/Select.svelte';
  import Kbd from '../../components/ui/Kbd.svelte';
  import { t } from '../../lib/locale.svelte';
  import { fetchNui } from '../../lib/nui';
  import { mdt } from '../../lib/store.svelte';
  import type { Rank, Settings } from '../../lib/types';

  type AlertKey = keyof Settings['dispatch']['autoAlerts'];

  const knownAlerts: ReadonlySet<string> = new Set<AlertKey>(['shooting', 'vehicleTheft', 'fight', 'playerDown', 'explosion', 'speeding']);

  let settings = $state<Settings | null>(null);
  let ranks = $state<Rank[]>([]);

  const department = $derived(mdt.officer?.department.name ?? '');
  const ownRanks = $derived(ranks.filter((rank) => rank.department === department));
  const rankOptions = $derived((ownRanks.length ? ownRanks : ranks).map((rank) => ({ value: rank.grade, label: rank.name })));
  const departments = $derived([...new Set(ranks.map((rank) => rank.departmentLabel))].join(` ${t('ui.common.and')} `));

  onMount(async () => {
    settings = await fetchNui('getSettings');
    const reply = await fetchNui('getRanks');
    ranks = (Array.isArray(reply) ? reply : []).sort((a, b) => a.grade - b.grade);
  });

  async function save() {
    if (!settings) return;

    const next = $state.snapshot(settings);
    if (mdt.report(await fetchNui('saveSettings', next), t('ui.settings.saved'))) mdt.settings = next;
  }

  function alertKeys(value: Settings): AlertKey[] {
    return Object.keys(value.dispatch.autoAlerts).filter((key): key is AlertKey => knownAlerts.has(key));
  }
</script>

{#if settings}
  {@const current = settings}
  <section class="flex min-w-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
    <div class="flex items-start gap-4">
      <div class="flex flex-1 flex-col gap-0.5">
        <h2 class="text-xl font-semibold">{t('ui.management.section.settings')}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.settings.applies_to', departments || (mdt.officer?.department.label ?? ''))}</p>
      </div>
      <Button variant="primary" onclick={save}>{t('ui.settings.save')}</Button>
    </div>

    <div class="grid grid-cols-2 items-start gap-6">
      <div class="flex flex-col gap-5">
        <div class="flex flex-col gap-2">
          <h3 class="text-13 font-medium text-muted-foreground">{t('ui.page.dispatch')}</h3>
          <div class="flex flex-col overflow-hidden rounded-lg border border-border">
            <div class="flex min-h-14 items-center gap-3 border-b border-border px-4 py-2.5">
              <div class="flex flex-1 flex-col gap-0.5">
                <span class="text-sm font-medium">{t('ui.settings.on_duty_only')}</span>
                <span class="text-xs text-muted-foreground">{t('ui.settings.on_duty_only_hint')}</span>
              </div>
              <Toggle label={t('ui.settings.on_duty_only')} bind:checked={current.dispatch.onDutyOnly} />
            </div>
            <div class="flex min-h-14 items-center gap-3 border-b border-border px-4 py-2.5">
              <div class="flex flex-1 flex-col gap-0.5">
                <span class="text-sm font-medium">{t('ui.settings.phone_required')}</span>
                <span class="text-xs text-muted-foreground">{t('ui.settings.phone_required_hint')}</span>
              </div>
              <Toggle label={t('ui.settings.phone_required')} bind:checked={current.dispatch.phoneRequired} />
            </div>
            <div class="flex min-h-12 items-center gap-3 border-b border-border px-4 py-2">
              <span class="flex-1 text-sm font-medium">{t('ui.settings.popup')}</span>
              <span class="field flex h-8 w-24 items-center gap-1 focus-within:border-primary">
                <input class="h-full min-w-0 flex-1 bg-transparent tabular-nums outline-none" type="number" min="3" max="60" aria-label={t('ui.settings.popup_seconds')} bind:value={current.dispatch.popupSeconds} />
                <span class="text-muted-foreground">{t('ui.settings.seconds_unit')}</span>
              </span>
            </div>
            <div class="flex min-h-12 items-center gap-3 border-b border-border px-4 py-2">
              <span class="flex-1 text-sm font-medium">{t('ui.settings.respond_key')}</span>
              <Kbd>{mdt.keybinds.respond}</Kbd>
            </div>
            <div class="flex min-h-12 items-center gap-3 px-4 py-2">
              <span class="flex-1 text-sm font-medium">{t('ui.settings.panic_key')}</span>
              <Kbd>{mdt.keybinds.panic}</Kbd>
            </div>
          </div>
          <p class="text-xs text-muted-foreground">{t('ui.settings.keys_hint')}</p>
        </div>

        <div class="flex flex-col gap-2">
          <h3 class="text-13 font-medium text-muted-foreground">{t('ui.settings.auto_alerts')}</h3>
          <div class="flex flex-wrap gap-1.5">
            {#each alertKeys(current) as key (key)}
              {@const on = current.dispatch.autoAlerts[key]}
              <button
                type="button"
                aria-pressed={on}
                class="h-7 rounded-md border px-2.5 text-13 font-medium transition-colors {on ? 'border-primary bg-primary text-primary-foreground hover:border-cobalt-hover hover:bg-cobalt-hover' : 'border-border text-muted-foreground hover:bg-muted'}"
                onclick={() => (current.dispatch.autoAlerts[key] = !on)}
              >
                {on ? t(`ui.settings.alert.${key}`) : t('ui.settings.alert_off', t(`ui.settings.alert.${key}`))}
              </button>
            {/each}
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <h3 class="text-13 font-medium text-muted-foreground">{t('ui.ranks.group.records')}</h3>
        <div class="flex flex-col overflow-hidden rounded-lg border border-border">
          <div class="flex min-h-14 items-center gap-3 border-b border-border px-4 py-2.5">
            <div class="flex flex-1 flex-col gap-0.5">
              <span class="text-sm font-medium">{t('ui.settings.warrant_warning')}</span>
              <span class="text-xs text-muted-foreground">{t('ui.settings.warrant_warning_hint')}</span>
            </div>
            <span class="field flex h-8 w-24 items-center gap-1 focus-within:border-primary">
              <input class="h-full min-w-0 flex-1 bg-transparent tabular-nums outline-none" type="number" min="1" max="168" aria-label={t('ui.settings.warning_hours')} bind:value={current.records.warrantWarnHours} />
              <span class="text-muted-foreground">{t('ui.settings.hours_unit')}</span>
            </span>
          </div>
          <div class="flex min-h-14 items-center gap-3 border-b border-border px-4 py-2.5">
            <span class="flex-1 text-sm font-medium">{t('ui.settings.bulletin_rank')}</span>
            <Select class="w-36 [&_.field]:h-8" label={t('ui.settings.bulletin_rank')} options={rankOptions} bind:value={current.records.bulletinMinGrade} />
          </div>
          <div class="flex min-h-14 items-center gap-3 px-4 py-2.5">
            <div class="flex flex-1 flex-col gap-0.5">
              <span class="text-sm font-medium">{t('ui.settings.ems_access')}</span>
              <span class="text-xs text-muted-foreground">{t('ui.settings.ems_access_hint')}</span>
            </div>
            <Toggle label={t('ui.settings.ems_access')} bind:checked={current.records.emsAccess} />
          </div>
        </div>
      </div>
    </div>
  </section>
{/if}
