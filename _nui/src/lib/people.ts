import type { PickOption } from '../components/ui/types';
import { t } from './locale.svelte';
import { fetchNui } from './nui';
import type { Person } from './types';

export async function searchPeople(query: string): Promise<PickOption<Person>[]> {
  if (query.trim().length < 2) return [];

  const people = await fetchNui('searchCitizens', { query });
  return people.map((person) => ({
    key: person.citizenid,
    label: person.name,
    detail: t('ui.people.detail', person.citizenid, person.dob),
    value: { citizenid: person.citizenid, name: person.name },
  }));
}
