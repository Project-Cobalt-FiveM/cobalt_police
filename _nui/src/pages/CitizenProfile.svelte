<script lang="ts">
  import { onMount } from 'svelte';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import UserCircle from 'phosphor-svelte/lib/UserCircle';
  import X from 'phosphor-svelte/lib/X';
  import LockKey from 'phosphor-svelte/lib/LockKey';
  import Header from '../components/Header.svelte';
  import TagBadge from '../components/TagBadge.svelte';
  import WarrantDialog from '../components/dialogs/WarrantDialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Badge from '../components/ui/Badge.svelte';
  import Tabs from '../components/ui/Tabs.svelte';
  import Row from '../components/ui/Row.svelte';
  import Dot from '../components/ui/Dot.svelte';
  import Plate from '../components/ui/Plate.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Field from '../components/ui/Field.svelte';
  import Select from '../components/ui/Select.svelte';
  import Picker from '../components/ui/Picker.svelte';
  import { fetchNui } from '../lib/nui';
  import { mdt } from '../lib/store.svelte';
  import { classDots, classLabel, licenceStatusLabel, longDate, money, remaining, shortDate, vehicleStateLabel } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { crossfade } from '../lib/motion';
  import type { Citizen, Licence, Tag } from '../lib/types';

  type TabKey = 'record' | 'incidents' | 'vehicles' | 'weapons' | 'properties' | 'evidence';

  let { citizenid }: { citizenid: string } = $props();

  let citizen = $state<Citizen | null>(null);
  let missing = $state(false);
  let tab = $state<TabKey>('record');
  let notes = $state('');
  let tags = $state<Tag[]>([]);
  let revoking = $state<Licence | null>(null);
  let reason = $state('');
  let warranting = $state(false);
  let editingPhoto = $state(false);
  let photo = $state('');

  const editable = $derived(mdt.can('editProfile'));
  const pointsLicence = $derived(citizen?.licences.find((licence) => licence.pointsLimit != null) ?? null);

  const reasons = $derived.by(() => {
    const options = [t('ui.profile.reason_conviction'), t('ui.profile.reason_court'), t('ui.profile.reason_medical'), t('ui.profile.reason_discretion')];
    if (revoking?.pointsLimit != null) options.unshift(t('ui.profile.reason_points', revoking.points, revoking.pointsLimit));
    return options.map((value) => ({ value, label: value }));
  });

  async function load() {
    const result = await fetchNui('getCitizen', { citizenid });
    citizen = result || null;
    missing = !result;
    notes = citizen?.notes ?? '';
    photo = citizen?.image ?? '';
  }

  onMount(() => {
    void load();
    void fetchNui('getTags').then((all) => (tags = all));
  });

  async function saveProfile() {
    if (!citizen || (notes === citizen.notes && photo === citizen.image)) return;

    if (mdt.report(await fetchNui('saveCitizen', { citizenid, notes, image: photo }), t('ui.profile.saved'))) {
      citizen.notes = notes;
      citizen.image = photo;
    } else {
      photo = citizen.image;
    }
  }

  async function addTag(tag: Tag) {
    if (mdt.report(await fetchNui('addCitizenTag', { citizenid, tagId: tag.id })) && citizen) {
      citizen.tags = [...citizen.tags, { id: tag.id, name: tag.name, color: tag.color }];
    }
  }

  async function removeTag(tag: Tag) {
    if (mdt.report(await fetchNui('removeCitizenTag', { citizenid, tagId: tag.id })) && citizen) {
      citizen.tags = citizen.tags.filter((entry) => entry.id !== tag.id);
    }
  }

  function startRevoke(licence: Licence) {
    revoking = licence;
    reason = reasons[0]?.value ?? '';
  }

  async function grant(licence: Licence) {
    if (mdt.report(await fetchNui('grantLicence', { citizenid, key: licence.key }), t('ui.profile.licence_granted', licence.label))) await load();
  }

  async function revoke() {
    if (!revoking) return;

    if (mdt.report(await fetchNui('revokeLicence', { citizenid, key: revoking.key, reason }), t('ui.profile.licence_revoked', revoking.label))) {
      revoking = null;
      await load();
    }
  }

  async function searchTags(query: string) {
    const held = new Set(citizen?.tags.map((tag) => tag.id));
    return tags
      .filter((tag) => !held.has(tag.id) && tag.name.toLowerCase().includes(query.toLowerCase()))
      .map((tag) => ({ key: String(tag.id), label: tag.name, value: tag }));
  }

  function firstName(name: string): string {
    return name.split(' ')[0] ?? name;
  }

  function licenceState(licence: Licence): string {
    if (licence.status === 'valid' && licence.pointsLimit != null) return t('ui.profile.points_of', licence.points, licence.pointsLimit);
    return licenceStatusLabel(licence.status);
  }

  const licenceDots: Record<Licence['status'], string> = {
    valid: 'bg-success',
    revoked: 'bg-destructive',
    suspended: 'bg-warning',
    none: 'bg-muted-foreground',
  };
</script>

<Header title={citizen?.name ?? (missing ? t('ui.profile.not_found') : t('ui.common.loading'))} subtitle={t('ui.profile.subtitle', citizenid)}>
  {#snippet action()}
    {#if mdt.can('createIncident') && citizen}
      <Button variant="primary" onclick={() => citizen && mdt.newIncident('incident', [{ citizenid: citizen.citizenid, name: citizen.name }])}>
        <PlusSquare size="1rem" />{t('ui.common.new_incident')}
      </Button>
    {/if}
  {/snippet}
</Header>

{#if citizen}
  <div class="flex min-h-0 flex-1" in:crossfade>
    <aside class="flex w-[21.25rem] shrink-0 flex-col gap-5 overflow-y-auto border-r border-border p-6">
      <button
        type="button"
        class="flex h-35 w-30 items-center justify-center overflow-hidden rounded-lg bg-secondary {editable ? 'hover:bg-secondary-hover' : 'cursor-default'}"
        aria-label={editable ? t('ui.profile.change_photo') : t('ui.profile.photo')}
        disabled={!editable}
        onclick={() => (editingPhoto = true)}
      >
        {#if citizen.image}<img src={citizen.image} alt="" class="size-full object-cover" />{:else}<UserCircle size="2.5rem" class="text-muted-foreground" />{/if}
      </button>

      <div class="flex flex-wrap items-center gap-1.5">
        {#if citizen.wanted}<Badge tone="danger">{t('ui.common.warrant')}</Badge>{/if}
        {#each citizen.tags as tag (tag.id)}
          <TagBadge {tag}>
            {#if editable}
              <button type="button" class="-mr-1 rounded-sm text-muted-foreground hover:text-foreground" aria-label={t('ui.profile.remove_tag', tag.name)} onclick={() => removeTag(tag)}><X size="0.625rem" /></button>
            {/if}
          </TagBadge>
        {/each}
        {#if editable}<Picker label={t('ui.profile.add_tag')} placeholder={t('ui.profile.search_tags')} search={searchTags} onpick={addTag} />{/if}
      </div>

      {#if citizen.jailed}
        <div class="flex items-center gap-3 rounded-lg border border-border p-3 text-13">
          <LockKey size="1rem" class="shrink-0 text-warning" />
          <span>{t('ui.profile.jailed', citizen.jailed.months, remaining(citizen.jailed.releaseAt, mdt.now))}</span>
        </div>
      {/if}

      <div class="flex flex-col">
        <Row label={t('ui.common.born')}>{citizen.dob}</Row>
        <Row label={t('ui.profile.sex')}>{t(`ui.sex.${citizen.sex}`)}</Row>
        <Row label={t('ui.common.phone')}>{citizen.phone}</Row>
        <Row label={t('ui.common.fingerprint')}>{citizen.fingerprint}</Row>
        <Row label={t('ui.profile.blood_type')}>{citizen.bloodType}</Row>
        <Row label={t('ui.common.job')}>{citizen.job}</Row>
        <Row label={t('ui.common.address')}>{citizen.address}</Row>
      </div>

      <div class="flex flex-col gap-2">
        <h2 class="text-sm font-semibold">{t('ui.common.licences')}</h2>
        {#each citizen.licences as licence (licence.key)}
          <div class="flex h-9 items-center gap-2.5 rounded-md border border-border px-3 text-13">
            <Dot class={licenceDots[licence.status]} size="size-1.5" />
            <span class="flex-1 font-medium {licence.status === 'none' ? 'text-muted-foreground' : ''}">{licence.label}</span>
            {#if licence.status === 'valid' && mdt.officer?.canManageLicences}
              <span class="text-xs text-muted-foreground tabular-nums">{licence.pointsLimit != null ? `${licence.points}/${licence.pointsLimit}` : ''}</span>
              <button type="button" class="text-xs text-muted-foreground hover:text-destructive" onclick={() => startRevoke(licence)}>{t('ui.profile.revoke')}</button>
            {:else if mdt.officer?.canManageLicences}
              <span class="text-xs text-muted-foreground tabular-nums">{licenceState(licence)}</span>
              <button type="button" class="text-xs text-muted-foreground hover:text-cobalt-foreground" onclick={() => grant(licence)}>{t('ui.profile.grant')}</button>
            {:else}
              <span class="text-xs text-muted-foreground tabular-nums">{licenceState(licence)}</span>
            {/if}
          </div>
        {/each}
      </div>
    </aside>

    <section class="flex min-w-0 flex-1 flex-col gap-6 overflow-y-auto p-6">
      <div class="flex items-center gap-3 border-b border-border pb-4">
        <div class="flex-1">
          <Tabs
            bind:value={tab}
            tabs={[
              { value: 'record', label: t('ui.profile.record'), count: citizen.record.convictions.length },
              { value: 'incidents', label: t('ui.page.incidents'), count: citizen.incidents.length },
              { value: 'vehicles', label: t('ui.page.vehicles'), count: citizen.vehicles.length },
              { value: 'weapons', label: t('ui.page.weapons'), count: citizen.weapons.length },
              { value: 'properties', label: t('ui.page.properties'), count: citizen.properties.length },
              { value: 'evidence', label: t('ui.page.evidence'), count: citizen.evidence.length },
            ]}
          />
        </div>
        {#if mdt.can('manageWarrants')}<Button size="sm" onclick={() => (warranting = true)}>{t('ui.warrant_dialog.title')}</Button>{/if}
      </div>

      {#key tab}
        <div class="flex flex-col gap-6" in:crossfade>
          {#if tab === 'record'}
            <div class="flex gap-8">
              <div class="flex flex-col gap-1"><span class="text-xs text-muted-foreground">{t('ui.profile.total_jail')}</span><span class="text-xl font-semibold tabular-nums">{t('ui.common.months', citizen.record.totalMonths)}</span></div>
              <div class="flex flex-col gap-1"><span class="text-xs text-muted-foreground">{t('ui.profile.total_fines')}</span><span class="text-xl font-semibold tabular-nums">{money(citizen.record.totalFine)}</span></div>
              <div class="flex flex-col gap-1">
                <span class="text-xs text-muted-foreground">{t('ui.common.licence_points')}</span>
                <span class="text-xl font-semibold tabular-nums">{pointsLicence?.pointsLimit != null ? t('ui.common.x_of_y', citizen.record.points, pointsLicence.pointsLimit) : citizen.record.points}</span>
              </div>
            </div>

            <div class="overflow-hidden rounded-lg border border-border">
              <div class="grid grid-cols-[1fr_7.5rem_4.5rem_6rem_7rem] gap-3 border-b border-border px-4 py-2.5 text-xs text-muted-foreground">
                <span>{t('ui.common.charge')}</span><span>{t('ui.common.class')}</span><span>{t('ui.profile.counts')}</span><span>{t('ui.common.case')}</span><span class="text-right">{t('ui.profile.date')}</span>
              </div>
              {#each citizen.record.convictions as conviction (conviction.id)}
                <div class="grid grid-cols-[1fr_7.5rem_4.5rem_6rem_7rem] items-center gap-3 border-b border-border px-4 py-3 last:border-b-0">
                  <span class="flex min-w-0 flex-col gap-0.5">
                    <span class="truncate text-sm font-medium">{conviction.title}</span>
                    <span class="text-xs text-muted-foreground tabular-nums">{conviction.code}</span>
                  </span>
                  <span class="flex items-center gap-1.5 text-13 font-medium"><Dot class={classDots[conviction.class]} size="size-1.5" />{classLabel(conviction.class)}</span>
                  <span class="text-13 font-medium tabular-nums">{conviction.counts}</span>
                  {#if conviction.incidentId != null}
                    {@const incidentId = conviction.incidentId}
                    <button type="button" class="text-left text-13 text-cobalt-foreground tabular-nums hover:text-foreground" onclick={() => mdt.openIncident(incidentId)}>#{incidentId}</button>
                  {:else}
                    <span class="text-13 text-muted-foreground">{t('ui.common.none')}</span>
                  {/if}
                  <span class="text-right text-13 text-muted-foreground tabular-nums">{longDate(conviction.createdAt)}</span>
                </div>
              {:else}
                <p class="px-4 py-6 text-center text-sm text-muted-foreground">{t('ui.profile.no_convictions')}</p>
              {/each}
            </div>

            <div class="flex flex-col gap-2.5">
              <h2 class="text-sm font-semibold">{t('ui.profile.notes')}</h2>
              {#if editable}
                <textarea class="field min-h-12 resize-none py-3 text-13" rows="3" bind:value={notes} onblur={saveProfile} placeholder={t('ui.profile.notes_placeholder')} maxlength="2000"></textarea>
              {:else}
                <p class="rounded-md border border-border px-3 py-3 text-13">{citizen.notes || t('ui.profile.no_notes')}</p>
              {/if}
            </div>
          {:else if tab === 'incidents'}
            <div class="flex flex-col">
              {#each citizen.incidents as incident (incident.id)}
                <button type="button" class="flex items-center gap-3 border-b border-border py-3 text-left hover:bg-muted" onclick={() => mdt.openIncident(incident.id)}>
                  <span class="w-16 text-13 text-muted-foreground tabular-nums">#{incident.id}</span>
                  <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span class="truncate text-sm font-medium">{incident.title}</span>
                    <span class="text-xs text-muted-foreground">{incident.author}, {t(`ui.profile.incident_status.${incident.status}`)}</span>
                  </span>
                  <span class="text-13 text-muted-foreground tabular-nums">{shortDate(incident.occurredAt)}</span>
                </button>
              {:else}
                <p class="py-6 text-sm text-muted-foreground">{t('ui.profile.no_incidents')}</p>
              {/each}
            </div>
          {:else if tab === 'vehicles'}
            <div class="grid grid-cols-2 gap-2">
              {#each citizen.vehicles as vehicle (vehicle.plate)}
                <button type="button" class="flex items-center gap-3 rounded-lg border border-border p-3 text-left hover:bg-muted" onclick={() => mdt.navigate({ page: 'vehicles', plate: vehicle.plate })}>
                  <Plate plate={vehicle.plate} />
                  <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span class="truncate text-sm font-medium">{vehicle.label}</span>
                    <span class="text-xs text-muted-foreground">{vehicleStateLabel(vehicle.state)}</span>
                  </span>
                  {#if vehicle.stolen}<Badge>{t('ui.common.stolen')}</Badge>{/if}
                </button>
              {:else}
                <p class="py-6 text-sm text-muted-foreground">{t('ui.profile.no_vehicles')}</p>
              {/each}
            </div>
          {:else if tab === 'weapons'}
            <div class="flex flex-col">
              {#each citizen.weapons as weapon (weapon.serial)}
                <div class="flex items-center gap-3 border-b border-border py-3">
                  <span class="w-24 text-sm font-medium tabular-nums">{weapon.serial}</span>
                  <span class="flex-1 text-sm">{weapon.label}</span>
                  {#if weapon.stolen}<Badge tone="danger">{t('ui.common.stolen')}</Badge>{/if}
                </div>
              {:else}
                <p class="py-6 text-sm text-muted-foreground">{t('ui.profile.no_weapons')}</p>
              {/each}
            </div>
          {:else if tab === 'properties'}
            <div class="flex flex-col">
              {#each citizen.properties as property (property.id)}
                <button type="button" class="flex items-center gap-3 border-b border-border py-3 text-left hover:bg-muted" onclick={() => mdt.go('properties')}>
                  <span class="flex flex-1 flex-col gap-0.5">
                    <span class="text-sm font-medium">{property.label}</span>
                    <span class="text-xs text-muted-foreground">{property.type}</span>
                  </span>
                </button>
              {:else}
                <p class="py-6 text-sm text-muted-foreground">{t('ui.profile.no_properties')}</p>
              {/each}
            </div>
          {:else if tab === 'evidence'}
            <div class="flex flex-col">
              {#each citizen.evidence as item (item.id)}
                <button type="button" class="flex items-center gap-3 border-b border-border py-3 text-left hover:bg-muted" onclick={() => mdt.go('evidence')}>
                  <span class="w-20 text-13 text-muted-foreground tabular-nums">{item.code}</span>
                  <span class="flex-1 text-sm font-medium">{item.title}</span>
                  <span class="text-13 text-muted-foreground tabular-nums">{shortDate(item.createdAt)}</span>
                </button>
              {:else}
                <p class="py-6 text-sm text-muted-foreground">{t('ui.profile.no_evidence')}</p>
              {/each}
            </div>
          {/if}
        </div>
      {/key}
    </section>
  </div>
{:else if missing}
  <p class="p-6 text-sm text-muted-foreground">{t('ui.profile.missing', citizenid)}</p>
{/if}

{#if revoking && citizen}
  <Dialog
    title={t('ui.profile.revoke_title', citizen.name, revoking.label.toLowerCase())}
    description={t('ui.profile.revoke_description', firstName(citizen.name))}
    onclose={() => (revoking = null)}
  >
    <Field label={t('ui.common.reason')}><Select label={t('ui.common.reason')} options={reasons} bind:value={reason} /></Field>
    {#snippet actions()}
      <Button onclick={() => (revoking = null)}>{t('ui.common.cancel')}</Button>
      <Button variant="destructive" onclick={revoke}>{t('ui.profile.revoke_licence')}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if warranting && citizen}
  <WarrantDialog subject={{ citizenid: citizen.citizenid, name: citizen.name }} onclose={() => (warranting = false)} onissued={load} />
{/if}

{#if editingPhoto && citizen}
  <Dialog title={t('ui.profile.change_photo')} description={t('ui.profile.photo_description')} onclose={() => ((photo = citizen?.image ?? ''), (editingPhoto = false))}>
    <Field label={t('ui.common.image_link')}><input class="field" bind:value={photo} placeholder="https://" /></Field>
    {#snippet actions()}
      <Button onclick={() => ((photo = citizen?.image ?? ''), (editingPhoto = false))}>{t('ui.common.cancel')}</Button>
      <Button variant="primary" onclick={() => (saveProfile(), (editingPhoto = false))}>{t('ui.profile.save_photo')}</Button>
    {/snippet}
  </Dialog>
{/if}
