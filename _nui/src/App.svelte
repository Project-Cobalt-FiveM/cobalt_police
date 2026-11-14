<script lang="ts">
  import { onMount } from 'svelte';
  import IconContext from 'phosphor-svelte/lib/IconContext';
  import { onMessage, sendMockOpen } from './lib/nui';
  import { mdt } from './lib/store.svelte';
  import { rise } from './lib/motion';
  import Sidebar from './components/Sidebar.svelte';
  import CallPopup from './components/CallPopup.svelte';
  import Toast from './components/Toast.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Dispatch from './pages/Dispatch.svelte';
  import Citizens from './pages/Citizens.svelte';
  import CitizenProfile from './pages/CitizenProfile.svelte';
  import Vehicles from './pages/Vehicles.svelte';
  import Weapons from './pages/Weapons.svelte';
  import Properties from './pages/Properties.svelte';
  import Incidents from './pages/Incidents.svelte';
  import IncidentEditor from './pages/IncidentEditor.svelte';
  import Warrants from './pages/Warrants.svelte';
  import Bolos from './pages/Bolos.svelte';
  import EvidencePage from './pages/Evidence.svelte';
  import PenalCode from './pages/PenalCode.svelte';
  import Roster from './pages/Roster.svelte';
  import Management from './pages/management/Management.svelte';
  import { isTyping } from './lib/dom';

  function onkeydown(event: KeyboardEvent) {
    if (!mdt.visible) return;

    if (event.key === 'Escape') {
      event.preventDefault();
      mdt.escape();
      return;
    }

    if (event.key === '/' && !isTyping(event.target)) {
      event.preventDefault();
      document.getElementById('global-search')?.focus();
    }
  }

  onMount(() => {
    const stop = onMessage((message) => mdt.handle(message));
    void mdt.boot().then(sendMockOpen);
    return stop;
  });
</script>

<svelte:window {onkeydown} />

<IconContext values={{ weight: 'fill' }}>
  {#if mdt.visible && mdt.officer}
    <div class="fixed inset-0 flex items-center justify-center">
      <div class="relative flex h-[57.5rem] w-[102.5rem] overflow-hidden rounded-lg border border-border bg-card" transition:rise={{ duration: 300 }}>
        <Sidebar />
        <main class="relative flex min-w-0 flex-1 flex-col">
          {#key mdt.route.page}
            {#if mdt.route.page === 'dashboard'}
              <Dashboard />
            {:else if mdt.route.page === 'dispatch'}
              <Dispatch />
            {:else if mdt.route.page === 'citizens'}
              {#if mdt.route.citizenid}
                {#key mdt.route.citizenid}<CitizenProfile citizenid={mdt.route.citizenid} />{/key}
              {:else}
                <Citizens />
              {/if}
            {:else if mdt.route.page === 'vehicles'}
              {#key mdt.route.plate}<Vehicles initial={mdt.route.plate} />{/key}
            {:else if mdt.route.page === 'weapons'}
              {#key mdt.route.serial}<Weapons initial={mdt.route.serial} />{/key}
            {:else if mdt.route.page === 'properties'}
              <Properties />
            {:else if mdt.route.page === 'incidents'}
              {#if mdt.route.editor}
                {#key mdt.route.editor}<IncidentEditor editor={mdt.route.editor} />{/key}
              {:else}
                <Incidents />
              {/if}
            {:else if mdt.route.page === 'warrants'}
              <Warrants />
            {:else if mdt.route.page === 'bolos'}
              <Bolos />
            {:else if mdt.route.page === 'evidence'}
              <EvidencePage />
            {:else if mdt.route.page === 'penalcode'}
              <PenalCode />
            {:else if mdt.route.page === 'roster'}
              <Roster />
            {:else if mdt.route.page === 'management'}
              <Management />
            {/if}
          {/key}
        </main>
        <Toast />
      </div>
    </div>
  {:else}
    <CallPopup />
  {/if}
</IconContext>
