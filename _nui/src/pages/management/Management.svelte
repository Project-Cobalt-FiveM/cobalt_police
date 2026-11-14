<script lang="ts">
  import Header from '../../components/Header.svelte';
  import { t } from '../../lib/locale.svelte';
  import { mdt } from '../../lib/store.svelte';
  import { crossfade } from '../../lib/motion';
  import type { Permission } from '../../lib/types';
  import Ranks from './Ranks.svelte';
  import Tags from './Tags.svelte';
  import Certificates from './Certificates.svelte';
  import Templates from './Templates.svelte';
  import SettingsPanel from './SettingsPanel.svelte';

  type Section = 'ranks' | 'tags' | 'certificates' | 'templates' | 'settings';

  const sections: { value: Section; permission: Permission }[] = [
    { value: 'ranks', permission: 'manageRanks' },
    { value: 'tags', permission: 'manageTags' },
    { value: 'certificates', permission: 'manageCertificates' },
    { value: 'templates', permission: 'manageTemplates' },
    { value: 'settings', permission: 'administrator' },
  ];

  const allowed = $derived(sections.filter((section) => mdt.can(section.permission)));

  let section = $state<Section | null>(null);

  const current = $derived(allowed.find((entry) => entry.value === section) ?? allowed[0] ?? null);
</script>

<Header title={t('ui.page.management')} subtitle={current && current.value !== 'ranks' ? t(`ui.management.section.${current.value}`) : t('ui.management.subtitle')} />

<div class="flex min-h-0 flex-1">
  <nav class="flex w-[13.75rem] shrink-0 flex-col gap-1 border-r border-border p-3">
    {#each allowed as entry (entry.value)}
      {@const active = entry.value === current?.value}
      <button
        type="button"
        aria-current={active ? 'page' : undefined}
        class="flex h-9 items-center rounded-md px-2.5 text-left text-sm font-medium transition-colors {active ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted hover:text-foreground'}"
        onclick={() => (section = entry.value)}
      >
        {t(`ui.management.section.${entry.value}`)}
      </button>
    {/each}
  </nav>

  {#if current}
    {#key current.value}
      <div class="flex min-w-0 flex-1" in:crossfade>
        {#if current.value === 'ranks'}
          <Ranks />
        {:else if current.value === 'tags'}
          <Tags />
        {:else if current.value === 'certificates'}
          <Certificates />
        {:else if current.value === 'templates'}
          <Templates />
        {:else}
          <SettingsPanel />
        {/if}
      </div>
    {/key}
  {:else}
    <p class="p-6 text-sm text-muted-foreground">{t('ui.management.denied')}</p>
  {/if}
</div>
