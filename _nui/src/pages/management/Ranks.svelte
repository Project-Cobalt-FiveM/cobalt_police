<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '../../components/ui/Button.svelte';
  import Toggle from '../../components/ui/Toggle.svelte';
  import { fetchNui } from '../../lib/nui';
  import { mdt } from '../../lib/store.svelte';
  import { plural } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import type { Permission, Permissions, Rank } from '../../lib/types';

  type Group = 'records' | 'operations' | 'department';

  const groups: { key: Group; items: Permission[] }[] = [
    { key: 'records', items: ['createIncident', 'editIncident', 'deleteIncident', 'editProfile'] },
    { key: 'operations', items: ['manageWarrants', 'manageBolos', 'postBulletins'] },
    { key: 'department', items: ['managePenalCode', 'manageTags', 'manageRanks', 'manageCertificates', 'manageTemplates', 'deleteEvidence', 'administrator'] },
  ];

  const total = groups.reduce((sum, group) => sum + group.items.length, 0);

  let ranks = $state<Rank[]>([]);
  let selectedKey = $state<string | null>(null);
  let permissions = $state<Permissions | null>(null);

  const key = (rank: Rank) => `${rank.department}:${rank.grade}`;
  const departments = $derived([...new Map(ranks.map((rank): [string, string] => [rank.department, rank.departmentLabel]))]);
  const selected = $derived(ranks.find((rank) => key(rank) === selectedKey) ?? null);
  const granted = (value: Permissions) => Object.values(value).filter(Boolean).length;

  async function load() {
    const reply = await fetchNui('getRanks');
    ranks = (Array.isArray(reply) ? reply : []).sort((a, b) => b.grade - a.grade);
    const fresh = ranks.find((rank) => key(rank) === selectedKey);
    const first = ranks.find((rank) => !rank.permissions.administrator) ?? ranks[0];
    if (fresh) pick(fresh);
    else if (first) pick(first);
  }

  onMount(load);

  function pick(rank: Rank) {
    selectedKey = key(rank);
    permissions = { ...rank.permissions };
  }

  async function save() {
    if (!selected || !permissions) return;

    if (mdt.report(await fetchNui('saveRank', { department: selected.department, grade: selected.grade, permissions: $state.snapshot(permissions) }), t('ui.common.saved', selected.name))) {
      await load();
    }
  }
</script>

<section class="flex w-[16.25rem] shrink-0 flex-col gap-5 overflow-y-auto border-r border-border p-5">
  {#each departments as [department, label] (department)}
    <div class="flex flex-col gap-2">
      <h2 class="text-sm font-semibold">{t('ui.ranks.department', label)}</h2>
      {#each ranks.filter((rank) => rank.department === department) as rank (key(rank))}
        {@const active = key(rank) === selectedKey}
        <button
          type="button"
          class="flex h-9 items-center gap-2 rounded-md border px-3 text-left text-sm font-medium transition-colors {active ? 'border-primary bg-primary' : 'border-border hover:bg-muted'}"
          onclick={() => pick(rank)}
        >
          <span class="flex-1 truncate">{rank.name}</span>
          <span class="text-xs tabular-nums {active ? '' : 'text-muted-foreground'}">{rank.permissions.administrator ? t('ui.ranks.all_access') : t('ui.common.x_of_y', granted(rank.permissions), total)}</span>
        </button>
      {/each}
    </div>
  {/each}
</section>

<section class="flex min-w-0 flex-1 flex-col gap-5 overflow-y-auto p-6">
  {#if selected && permissions}
    {@const current = permissions}
    <div class="flex items-start gap-4">
      <div class="flex flex-1 flex-col gap-0.5">
        <h2 class="text-xl font-semibold">{selected.name}</h2>
        <p class="text-13 text-muted-foreground">{plural(selected.holders, selected.isBoss ? 'ui.plural.rank_holders_boss' : 'ui.plural.rank_holders')}</p>
      </div>
      <Button variant="primary" onclick={save}>{t('ui.ranks.save')}</Button>
    </div>
    <div class="grid grid-cols-2 items-start gap-6">
      {#each [groups.slice(0, 2), groups.slice(2)] as column, index (index)}
        <div class="flex flex-col gap-5">
          {#each column as group (group.key)}
            <div class="flex flex-col gap-2">
              <h3 class="text-13 font-medium text-muted-foreground">{t(`ui.ranks.group.${group.key}`)}</h3>
              <div class="flex flex-col overflow-hidden rounded-lg border border-border">
                {#each group.items as item (item)}
                  {@const label = t(`ui.ranks.permission.${item}`)}
                  <div class="flex min-h-11 items-center gap-3 border-b border-border px-4 py-2 last:border-b-0">
                    <div class="flex flex-1 flex-col gap-0.5">
                      <span class="text-sm font-medium {current.administrator && item !== 'administrator' ? 'text-muted-foreground' : ''}">{label}</span>
                      {#if item === 'administrator'}<span class="text-xs text-muted-foreground">{t('ui.ranks.administrator_note')}</span>{/if}
                    </div>
                    <Toggle {label} bind:checked={current[item]} disabled={current.administrator && item !== 'administrator'} />
                  </div>
                {/each}
              </div>
            </div>
          {/each}
        </div>
      {/each}
    </div>
  {/if}
</section>
