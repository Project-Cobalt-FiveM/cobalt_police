import type { MockHandlers } from './nui';
import type {
  Bolo,
  Call,
  Certificate,
  Charge,
  Citizen,
  CitizenSummary,
  Evidence,
  Incident,
  IncidentSummary,
  Messages,
  Officer,
  Permissions,
  Property,
  Rank,
  RosterEntry,
  Settings,
  Tag,
  Template,
  Unit,
  Vehicle,
  VehicleSummary,
  Warrant,
  Weapon,
} from './types';

const now = Math.floor(Date.now() / 1000);
const minutes = (count: number) => now - count * 60;
const hours = (count: number) => now - count * 3600;
const days = (count: number) => now - count * 86400;

const ok = { ok: true } as const;

function permissions(granted: (keyof Permissions)[]): Permissions {
  const all: Permissions = {
    createIncident: false,
    editIncident: false,
    deleteIncident: false,
    editProfile: false,
    manageWarrants: false,
    manageBolos: false,
    postBulletins: false,
    managePenalCode: false,
    manageTags: false,
    manageRanks: false,
    manageCertificates: false,
    manageTemplates: false,
    deleteEvidence: false,
    administrator: false,
  };

  for (const key of granted) all[key] = true;
  return all;
}

const officer: Officer = {
  citizenid: 'MRY41270',
  name: 'Ofc. Maya Reyes',
  callsign: '1-ADAM-12',
  gradeName: 'Officer II',
  department: { name: 'police', label: 'LSPD', subtitle: 'City Of Los Santos' },
  isEms: false,
  status: 'available',
  permissions: permissions(['administrator']),
  canManageLicences: true,
  pages: [
    'dashboard',
    'dispatch',
    'citizens',
    'vehicles',
    'weapons',
    'properties',
    'incidents',
    'warrants',
    'bolos',
    'evidence',
    'penalcode',
    'roster',
    'management',
  ],
};

const settings: Settings = {
  dispatch: {
    onDutyOnly: true,
    phoneRequired: true,
    popupSeconds: 8,
    autoAlerts: { shooting: true, vehicleTheft: true, fight: true, playerDown: true, explosion: true, speeding: false },
  },
  records: { warrantWarnHours: 48, bulletinMinGrade: 3, emsAccess: true },
};

const tags: (Tag & { holders: number })[] = [
  { id: 1, name: 'Armed and dangerous', color: '#DC2626', holders: 12 },
  { id: 2, name: 'Ballas', color: '#9333EA', holders: 27 },
  { id: 3, name: 'Families', color: '#16A34A', holders: 31 },
  { id: 4, name: 'Witness', color: '#A3A3A3', holders: 54 },
  { id: 5, name: 'Informant', color: '#D97706', holders: 4 },
];

function tag(id: number): Tag {
  const found = tags.find((entry) => entry.id === id);
  if (!found) throw new Error(`Unknown tag ${id}`);
  return { id: found.id, name: found.name, color: found.color };
}

let charges: Charge[] = [
  {
    id: 1,
    category: 'Violent',
    code: 'PC 187',
    title: 'Murder',
    description: 'Unlawful killing of a person with malice aforethought.',
    class: 'felony',
    months: 120,
    fine: 25000,
    points: 0,
    stackable: false,
  },
  {
    id: 2,
    category: 'Violent',
    code: 'PC 192(a)',
    title: 'Voluntary manslaughter',
    description: 'Killing in the heat of passion without malice.',
    class: 'felony',
    months: 60,
    fine: 12500,
    points: 0,
    stackable: false,
  },
  {
    id: 3,
    category: 'Violent',
    code: 'PC 211',
    title: 'Armed robbery',
    description: 'Taking property from a person or business by force or threat while armed.',
    class: 'felony',
    months: 30,
    fine: 5000,
    points: 0,
    stackable: true,
  },
  {
    id: 4,
    category: 'Violent',
    code: 'PC 245(a)(1)',
    title: 'Assault with a deadly weapon',
    description: 'Assault with a weapon or force likely to cause great bodily injury.',
    class: 'felony',
    months: 25,
    fine: 4000,
    points: 0,
    stackable: true,
  },
  {
    id: 5,
    category: 'Violent',
    code: 'PC 242',
    title: 'Battery',
    description: 'Wilful and unlawful use of force against another person.',
    class: 'misdemeanor',
    months: 8,
    fine: 1000,
    points: 0,
    stackable: true,
  },
  {
    id: 6,
    category: 'Violent',
    code: 'PC 422',
    title: 'Criminal threats',
    description: 'Threatening to kill or seriously injure another person.',
    class: 'misdemeanor',
    months: 6,
    fine: 750,
    points: 0,
    stackable: true,
  },
  {
    id: 7,
    category: 'Property',
    code: 'PC 487',
    title: 'Grand theft',
    description: 'Theft of property worth more than $950.',
    class: 'felony',
    months: 15,
    fine: 2500,
    points: 0,
    stackable: true,
  },
  {
    id: 8,
    category: 'Property',
    code: 'VC 10851',
    title: 'Grand theft auto',
    description: "Taking a vehicle without the owner's consent.",
    class: 'felony',
    months: 18,
    fine: 3000,
    points: 0,
    stackable: true,
  },
  {
    id: 9,
    category: 'Drugs',
    code: 'HS 11350',
    title: 'Possession of a controlled substance',
    description: 'Possession without a valid prescription.',
    class: 'misdemeanor',
    months: 6,
    fine: 1000,
    points: 0,
    stackable: true,
  },
  {
    id: 10,
    category: 'Drugs',
    code: 'HS 11351',
    title: 'Possession for sale',
    description: 'Possession of a controlled substance with intent to sell.',
    class: 'felony',
    months: 24,
    fine: 6000,
    points: 0,
    stackable: true,
  },
  {
    id: 11,
    category: 'Weapons',
    code: 'PC 29800',
    title: 'Possession of a firearm by a felon',
    description: 'A person with a felony conviction owning or carrying a firearm.',
    class: 'felony',
    months: 15,
    fine: 2500,
    points: 0,
    stackable: false,
  },
  {
    id: 12,
    category: 'Weapons',
    code: 'PC 25850',
    title: 'Carrying a loaded firearm in public',
    description: 'Carrying a loaded firearm in a public place.',
    class: 'misdemeanor',
    months: 6,
    fine: 1500,
    points: 0,
    stackable: false,
  },
  {
    id: 13,
    category: 'Traffic',
    code: 'VC 2800.1',
    title: 'Evading a peace officer',
    description: 'Wilfully fleeing a pursuing police vehicle.',
    class: 'misdemeanor',
    months: 6,
    fine: 1000,
    points: 3,
    stackable: false,
  },
  {
    id: 14,
    category: 'Traffic',
    code: 'VC 23103',
    title: 'Reckless driving',
    description: 'Driving with wilful disregard for safety.',
    class: 'misdemeanor',
    months: 0,
    fine: 750,
    points: 2,
    stackable: true,
  },
  {
    id: 15,
    category: 'Traffic',
    code: 'VC 22350',
    title: 'Speeding',
    description: 'Driving faster than is safe for conditions.',
    class: 'infraction',
    months: 0,
    fine: 250,
    points: 1,
    stackable: true,
  },
  {
    id: 16,
    category: 'Public order',
    code: 'PC 415',
    title: 'Disturbing the peace',
    description: 'Fighting, loud noise or offensive words in public.',
    class: 'infraction',
    months: 0,
    fine: 400,
    points: 0,
    stackable: true,
  },
];

const darnellLicences: Citizen['licences'] = [
  { key: 'driver', label: 'Driver', status: 'valid', points: 9, pointsLimit: 12 },
  { key: 'weapon', label: 'Weapon', status: 'revoked', points: 0 },
];

let warrants: Warrant[] = [
  {
    id: 36,
    citizenid: 'HKW49120',
    name: 'Darnell Price',
    type: 'arrest',
    title: 'Assault with a deadly weapon',
    description:
      'Wanted for assault with a deadly weapon at the Davis Mega Mall car park on 21 October. Victim treated at Pillbox Medical. Suspect is known to carry a pistol.',
    status: 'active',
    issuedBy: 'Det. Aaron Foster',
    expiresAt: now + 31 * 3600,
    incidentId: 1987,
    createdAt: days(3),
  },
  {
    id: 41,
    citizenid: 'HKW49120',
    name: 'Forum Drive 14, Strawberry',
    type: 'search',
    title: 'Narcotics distribution, electronic devices',
    description: 'Search for narcotics packaging, scales and phones linked to street sales on Grove Street.',
    status: 'active',
    issuedBy: 'Sgt. Tom Adams',
    expiresAt: now + 44 * 3600,
    incidentId: 1904,
    createdAt: days(2),
  },
  {
    id: 39,
    citizenid: 'TKL22018',
    name: 'Trevor Kline',
    type: 'arrest',
    title: 'Grand theft auto, 3 counts',
    description: 'Three vehicles taken from the Legion Square garage in one night.',
    status: 'active',
    issuedBy: 'Ofc. Maya Reyes',
    expiresAt: now + 5 * 86400,
    incidentId: null,
    createdAt: days(4),
  },
  {
    id: 33,
    citizenid: 'SVG55102',
    name: 'Sofia Varga',
    type: 'bench',
    title: 'Failure to appear, traffic court',
    description: 'Missed two hearings for unpaid speeding fines.',
    status: 'active',
    issuedBy: 'Lt. Marco Rodriguez',
    expiresAt: now + 12 * 86400,
    incidentId: null,
    createdAt: days(9),
  },
  {
    id: 28,
    citizenid: 'RIB80211',
    name: 'Rafael Ibarra',
    type: 'arrest',
    title: 'Parole violation',
    description: 'Missed three parole check-ins.',
    status: 'served',
    issuedBy: 'Sgt. Chidi Okafor',
    expiresAt: null,
    incidentId: null,
    createdAt: days(20),
  },
  {
    id: 21,
    citizenid: 'LPR77310',
    name: 'Lena Price',
    type: 'bench',
    title: 'Failure to appear',
    description: 'Did not attend a witness hearing.',
    status: 'cancelled',
    issuedBy: 'Lt. Marco Rodriguez',
    expiresAt: null,
    incidentId: null,
    createdAt: days(40),
  },
];

let bolos: Bolo[] = [
  {
    id: 318,
    type: 'vehicle',
    title: 'Black Gallivanter Baller',
    description: 'Getaway vehicle from the Fleeca robbery. Tinted windows, damaged rear bumper.',
    citizenid: 'HKW49120',
    plate: '82HJK019',
    personName: '',
    lastSeen: 'Route 68, Harmony',
    status: 'active',
    department: 'LSPD',
    issuedBy: 'Det. Aaron Foster',
    createdAt: hours(1),
  },
  {
    id: 315,
    type: 'person',
    title: 'Missing: Edith Moreno, 74',
    description: 'Grey cardigan, walks with a cane. May be confused. Call family on 555-0198.',
    citizenid: null,
    plate: null,
    personName: 'Edith Moreno',
    lastSeen: 'Paleto Bay, near the pier',
    status: 'active',
    department: 'BCSO',
    issuedBy: 'Dep. Wade Harlan',
    createdAt: days(4),
  },
  {
    id: 312,
    type: 'vehicle',
    title: 'Grey Karin Sultan RS',
    description: 'Reported stolen by owner Maya Chen. Aftermarket spoiler, blue rims.',
    citizenid: null,
    plate: '82HQA551',
    personName: '',
    lastSeen: 'Alta Street, Pillbox Hill',
    status: 'active',
    department: 'LSPD',
    issuedBy: 'Ofc. Luis Ortega',
    createdAt: days(5),
  },
  {
    id: 309,
    type: 'person',
    title: 'Unknown male, red hoodie',
    description: 'Second suspect in the Fleeca robbery. About 1.85 m, neck tattoo.',
    citizenid: null,
    plate: null,
    personName: 'Unknown male',
    lastSeen: 'Chumash, heading east',
    status: 'active',
    department: 'LSPD',
    issuedBy: 'Det. Aaron Foster',
    createdAt: days(6),
  },
  {
    id: 305,
    type: 'vehicle',
    title: 'Red Pegassi Faggio',
    description: 'Scooter seen leaving two convenience store robberies in Vespucci.',
    citizenid: null,
    plate: '41MPD207',
    personName: '',
    lastSeen: 'Vespucci Canals',
    status: 'active',
    department: 'LSPD',
    issuedBy: 'Sgt. Chidi Okafor',
    createdAt: days(11),
  },
  {
    id: 301,
    type: 'person',
    title: 'Rafael Ibarra, 29',
    description: 'Skipped parole. Drives a gold Emperor, may be armed.',
    citizenid: 'RIB80211',
    plate: null,
    personName: 'Rafael Ibarra',
    lastSeen: 'Rancho, Jamestown Street',
    status: 'active',
    department: 'BCSO',
    issuedBy: 'Dep. Wade Harlan',
    createdAt: days(13),
  },
  {
    id: 307,
    type: 'vehicle',
    title: 'White Bison, no plate',
    description: 'Used in a string of break-ins around Sandy Shores. Ladder rack on the bed.',
    citizenid: null,
    plate: null,
    personName: '',
    lastSeen: 'Sandy Shores airfield',
    status: 'active',
    department: 'BCSO',
    issuedBy: 'Dep. Wade Harlan',
    createdAt: days(9),
  },
  {
    id: 290,
    type: 'person',
    title: 'Runaway teen, Mirror Park',
    description: "Found safe at a friend's house.",
    citizenid: null,
    plate: null,
    personName: 'Ana Ruiz',
    lastSeen: 'Mirror Park',
    status: 'cancelled',
    department: 'LSPD',
    issuedBy: 'Ofc. Maya Reyes',
    createdAt: days(21),
  },
];

let evidence: Evidence[] = [
  {
    id: 412,
    code: 'FS-0412',
    type: 'forensic',
    title: 'Fingerprint on vault door',
    description: 'Partial print lifted from the vault door handle.',
    image: '',
    location: 'Fleeca, Great Ocean Highway',
    citizenid: 'HKW49120',
    citizenName: 'Darnell Price',
    incidentId: 2041,
    collectedBy: 'Det. A. Foster',
    createdAt: minutes(25),
  },
  {
    id: 411,
    code: 'FS-0411',
    type: 'forensic',
    title: '9mm casing, 3 rounds',
    description: 'Casings recovered at Grove Street. Serial 4471-KD.',
    image: '',
    location: 'Grove Street, Davis',
    citizenid: null,
    citizenName: null,
    incidentId: null,
    collectedBy: 'Ofc. L. Ortega',
    createdAt: minutes(47),
  },
  {
    id: 409,
    code: 'FS-0409',
    type: 'forensic',
    title: 'Blood sample, type O negative',
    description: 'Swab from the stairwell rail.',
    image: '',
    location: 'Davis Mega Mall',
    citizenid: null,
    citizenName: null,
    incidentId: null,
    collectedBy: 'Det. A. Foster',
    createdAt: days(1),
  },
  {
    id: 882,
    code: 'EV-0882',
    type: 'photo',
    title: 'Bodycam photo, suspect vehicle',
    description: 'Still from 1-ADAM-12 bodycam during the stop.',
    image: '',
    location: 'Route 68',
    citizenid: 'HKW49120',
    citizenName: 'Darnell Price',
    incidentId: 2041,
    collectedBy: 'Ofc. M. Reyes',
    createdAt: days(1),
  },
  {
    id: 881,
    code: 'EV-0881',
    type: 'item',
    title: 'Pistol, SN 4471-KD',
    description: 'Seized from Darnell Price, locker B-12.',
    image: '',
    location: 'Route 68',
    citizenid: 'HKW49120',
    citizenName: 'Darnell Price',
    incidentId: 2041,
    collectedBy: 'Ofc. M. Reyes',
    createdAt: days(1),
  },
];

let incidents: Incident[] = [
  {
    id: 2042,
    kind: 'incident',
    status: 'draft',
    title: 'Armed robbery, Fleeca Great Ocean Highway',
    location: 'Great Ocean Highway, Chumash',
    coords: null,
    occurredAt: minutes(80),
    narrative:
      'At 13:52 units responded to a silent alarm at Fleeca Great Ocean Highway. Two masked suspects left in a black Baller, plate 82HJK019, heading north. 1-ADAM-12 stopped the vehicle at Route 68 after a short pursuit. Darnell Price was detained at the scene with a pistol and $42,300 in marked bills.',
    officers: [
      { citizenid: 'MRY41270', name: 'Ofc. Maya Reyes' },
      { citizenid: 'LOR33021', name: 'Ofc. Luis Ortega' },
    ],
    suspects: [
      {
        citizenid: 'HKW49120',
        name: 'Darnell Price',
        charges: [
          { chargeId: 3, counts: 1 },
          { chargeId: 11, counts: 1 },
          { chargeId: 13, counts: 1 },
          { chargeId: 14, counts: 2 },
        ],
      },
      { citizenid: null, name: 'Unknown male', charges: [] },
    ],
    witnesses: [{ citizenid: 'LPR77310', name: 'Lena Price' }],
    evidence: [
      { id: 881, code: 'EV-0881', title: 'Pistol, SN 4471-KD' },
      { id: 882, code: 'EV-0882', title: 'Bodycam photo' },
    ],
    author: 'Ofc. Maya Reyes',
    authorCid: 'MRY41270',
    updatedAt: minutes(12),
  },
  {
    id: 2041,
    kind: 'incident',
    status: 'filed',
    title: 'Bank alarm, Fleeca Great Ocean Highway',
    location: 'Great Ocean Highway, Chumash',
    coords: null,
    occurredAt: hours(1),
    narrative:
      'Silent alarm at 13:52. Two masked suspects left in a black Baller and were stopped on Route 68. One fled on foot toward Chumash.',
    officers: [
      { citizenid: 'AFS22080', name: 'Det. Aaron Foster' },
      { citizenid: 'MRY41270', name: 'Ofc. Maya Reyes' },
      { citizenid: 'LOR33021', name: 'Ofc. Luis Ortega' },
    ],
    suspects: [
      { citizenid: 'HKW49120', name: 'Darnell Price', charges: [{ chargeId: 3, counts: 1 }] },
      { citizenid: null, name: 'Unknown male', charges: [] },
    ],
    witnesses: [{ citizenid: 'LPR77310', name: 'Lena Price' }],
    evidence: [
      { id: 412, code: 'FS-0412', title: 'Fingerprint on vault door' },
      { id: 881, code: 'EV-0881', title: 'Pistol, SN 4471-KD' },
      { id: 882, code: 'EV-0882', title: 'Bodycam photo' },
    ],
    author: 'Det. Aaron Foster',
    authorCid: 'AFS22080',
    updatedAt: hours(1),
  },
  {
    id: 2040,
    kind: 'incident',
    status: 'filed',
    title: 'Traffic stop, possession',
    location: 'Strawberry Avenue',
    coords: null,
    occurredAt: hours(3),
    narrative: 'Stopped a Karin Futo for running a red light. Driver had a small bag of cocaine in the centre console.',
    officers: [{ citizenid: 'MRY41270', name: 'Ofc. Maya Reyes' }],
    suspects: [{ citizenid: 'MPW20584', name: 'Marcus Pricewell', charges: [{ chargeId: 9, counts: 1 }] }],
    witnesses: [],
    evidence: [],
    author: 'Ofc. Maya Reyes',
    authorCid: 'MRY41270',
    updatedAt: hours(3),
  },
  {
    id: 512,
    kind: 'report',
    status: 'filed',
    title: 'Ballas activity on Grove Street',
    location: 'Grove Street, Davis',
    coords: null,
    occurredAt: days(1),
    narrative: 'Increased Ballas presence around the Grove Street cul-de-sac. Review on 10 Nov.',
    officers: [{ citizenid: 'COK33901', name: 'Sgt. Chidi Okafor' }],
    suspects: [],
    witnesses: [],
    evidence: [],
    author: 'Sgt. Chidi Okafor',
    authorCid: 'COK33901',
    updatedAt: days(1),
  },
  {
    id: 2038,
    kind: 'incident',
    status: 'filed',
    title: 'Domestic disturbance, Mirror Park',
    location: 'Mirror Park',
    coords: null,
    occurredAt: days(1),
    narrative: 'Neighbours reported shouting. Both parties calm on arrival. No arrest.',
    officers: [{ citizenid: 'TAD11021', name: 'Sgt. Tom Adams' }],
    suspects: [],
    witnesses: [],
    evidence: [],
    author: 'Sgt. Tom Adams',
    authorCid: 'TAD11021',
    updatedAt: days(1),
  },
  {
    id: 509,
    kind: 'report',
    status: 'filed',
    title: 'Noise complaints, Vinewood Hills party house',
    location: 'Vinewood Hills',
    coords: null,
    occurredAt: days(2),
    narrative: 'Third complaint this month. Owner warned.',
    officers: [{ citizenid: 'LOR33021', name: 'Ofc. Luis Ortega' }],
    suspects: [],
    witnesses: [],
    evidence: [],
    author: 'Ofc. Luis Ortega',
    authorCid: 'LOR33021',
    updatedAt: days(2),
  },
];

function summarise(incident: Incident): IncidentSummary {
  return {
    id: incident.id ?? 0,
    kind: incident.kind,
    status: incident.status,
    title: incident.title,
    location: incident.location,
    author: incident.author,
    authorCid: incident.authorCid,
    suspects: incident.suspects.length,
    occurredAt: incident.occurredAt,
  };
}

const citizenSummaries: CitizenSummary[] = [
  {
    citizenid: 'HKW49120',
    name: 'Darnell Price',
    dob: '14 Mar 1993',
    phone: '555-0187',
    tags: [tag(2), tag(1)],
    wanted: true,
    online: true,
    convictions: 6,
  },
  {
    citizenid: 'LPR77310',
    name: 'Lena Price',
    dob: '2 Aug 1996',
    phone: '555-0119',
    tags: [tag(4)],
    wanted: false,
    online: false,
    convictions: 0,
  },
  {
    citizenid: 'MPW20584',
    name: 'Marcus Pricewell',
    dob: '30 Nov 1988',
    phone: '555-0163',
    tags: [],
    wanted: false,
    online: true,
    convictions: 1,
  },
  {
    citizenid: 'VUC63021',
    name: 'Jasmine Price-Ortiz',
    dob: '19 Jun 2001',
    phone: '555-0104',
    tags: [],
    wanted: false,
    online: false,
    convictions: 0,
  },
  {
    citizenid: 'TKL22018',
    name: 'Trevor Kline',
    dob: '8 Jan 1990',
    phone: '555-0177',
    tags: [tag(3)],
    wanted: true,
    online: false,
    convictions: 4,
  },
  {
    citizenid: 'RDG10233',
    name: 'Rosa Delgado',
    dob: '22 Sep 1985',
    phone: '555-0131',
    tags: [],
    wanted: false,
    online: true,
    convictions: 0,
  },
];

const vehicles: VehicleSummary[] = [
  {
    plate: '82HJK019',
    model: 'baller',
    label: 'Gallivanter Baller',
    owner: 'Darnell Price',
    citizenid: 'HKW49120',
    state: 'out',
    flagged: true,
    stolen: false,
  },
  {
    plate: '82HQA551',
    model: 'sultanrs',
    label: 'Karin Sultan RS',
    owner: 'Maya Chen',
    citizenid: 'MCH55120',
    state: 'out',
    flagged: true,
    stolen: true,
  },
  {
    plate: '82HTE730',
    model: 'sandking',
    label: 'Vapid Sandking',
    owner: 'Rosa Delgado',
    citizenid: 'RDG10233',
    state: 'garaged',
    flagged: false,
    stolen: false,
  },
  {
    plate: '61ROM884',
    model: 'futo',
    label: 'Karin Futo',
    owner: 'Marcus Pricewell',
    citizenid: 'MPW20584',
    state: 'impounded',
    flagged: false,
    stolen: false,
  },
];

const weapons: Weapon[] = [
  {
    serial: '4471-KD',
    item: 'weapon_combatpistol',
    label: 'Combat pistol',
    owner: 'Darnell Price',
    citizenid: 'HKW49120',
    stolen: false,
  },
  {
    serial: '2290-MB',
    item: 'weapon_pumpshotgun',
    label: 'Pump shotgun',
    owner: 'Rosa Delgado',
    citizenid: 'RDG10233',
    stolen: false,
  },
  {
    serial: '0815-TR',
    item: 'weapon_heavypistol',
    label: 'Heavy pistol',
    owner: 'Luis Ortega',
    citizenid: 'LOR33021',
    stolen: false,
  },
  { serial: '9902-AX', item: 'weapon_pistol', label: 'Pistol', owner: null, citizenid: null, stolen: true },
];

const properties: Property[] = [
  {
    id: 14,
    label: 'Forum Drive 14, Strawberry',
    address: 'Forum Drive 14',
    type: 'Two-room apartment',
    owner: 'Darnell Price',
    citizenid: 'HKW49120',
  },
  {
    id: 9,
    label: 'Forum Drive 9, Strawberry',
    address: 'Forum Drive 9',
    type: 'House',
    owner: 'Keisha Monroe',
    citizenid: 'KMN10233',
  },
  {
    id: 31,
    label: 'Forum Drive garage unit 3',
    address: 'Forum Drive',
    type: 'Garage',
    owner: null,
    citizenid: null,
  },
];

function citizen(citizenid: string): Citizen | null {
  const summary = citizenSummaries.find((entry) => entry.citizenid === citizenid);
  if (!summary) return null;

  const isDarnell = citizenid === 'HKW49120';

  return {
    ...summary,
    sex:
      summary.name.startsWith('Lena') || summary.name.startsWith('Jasmine') || summary.name.startsWith('Rosa')
        ? 'female'
        : 'male',
    fingerprint: isDarnell ? 'FP-7Q3K-91LX' : `FP-${citizenid.slice(0, 4)}-${citizenid.slice(4)}`,
    bloodType: 'O-',
    job: isDarnell ? 'Unemployed' : 'Mechanic',
    address: isDarnell ? 'Forum Drive 14, Strawberry' : 'Alta Street, Pillbox Hill',
    image: '',
    notes: isDarnell
      ? 'Known to carry a pistol in the waistband. Frequents Grove Street and the Davis Mega Mall car park. Approach with backup.'
      : '',
    jailed: null,
    licences: isDarnell
      ? darnellLicences
      : [{ key: 'driver', label: 'Driver', status: 'valid', points: 0, pointsLimit: 12 }],
    record: isDarnell
      ? {
          totalMonths: 94,
          totalFine: 18750,
          points: 9,
          convictions: [
            {
              id: 1,
              title: 'Assault with a deadly weapon',
              code: 'PC 245(a)(1)',
              class: 'felony',
              counts: 1,
              months: 25,
              fine: 4000,
              points: 0,
              incidentId: 1987,
              createdAt: days(13),
            },
            {
              id: 2,
              title: 'Possession of a controlled substance',
              code: 'HS 11350',
              class: 'misdemeanor',
              counts: 3,
              months: 18,
              fine: 3000,
              points: 0,
              incidentId: 1904,
              createdAt: days(32),
            },
            {
              id: 3,
              title: 'Evading a peace officer',
              code: 'VC 2800.1',
              class: 'misdemeanor',
              counts: 1,
              months: 6,
              fine: 1000,
              points: 3,
              incidentId: 1904,
              createdAt: days(32),
            },
            {
              id: 4,
              title: 'Speeding, 25 over the limit',
              code: 'VC 22350',
              class: 'infraction',
              counts: 1,
              months: 0,
              fine: 250,
              points: 1,
              incidentId: 1702,
              createdAt: days(79),
            },
          ],
        }
      : { totalMonths: 0, totalFine: 0, points: 0, convictions: [] },
    incidents: incidents
      .filter((incident) => incident.suspects.some((suspect) => suspect.citizenid === citizenid))
      .map(summarise),
    vehicles: vehicles.filter((vehicle) => vehicle.citizenid === citizenid),
    weapons: weapons.filter((weapon) => weapon.citizenid === citizenid),
    properties: properties.filter((property) => property.citizenid === citizenid),
    evidence: evidence.filter((item) => item.citizenid === citizenid),
    warrants: warrants.filter((warrant) => warrant.citizenid === citizenid && warrant.status === 'active'),
  };
}

let calls: Call[] = [
  {
    id: 4471,
    code: '10-13',
    title: 'Officer down',
    description: 'Panic button pressed.',
    location: 'Strawberry Avenue and Davis Avenue, Strawberry',
    coords: { x: 120, y: -1300, z: 29 },
    plate: null,
    priority: 1,
    caller: null,
    raisedBy: 'Ofc. Luis Ortega, 1-LINCOLN-4, panic button',
    responders: [
      { citizenid: 'MRY41270', name: 'Reyes', callsign: '1-ADAM-12' },
      { citizenid: 'COK33901', name: 'Okafor', callsign: '2-MARY-7' },
      { citizenid: 'EBN44010', name: 'Bennett', callsign: 'EMS 3' },
    ],
    notes: [
      { author: 'Okafor', text: 'Suspect fled east on foot, red hoodie', time: minutes(0.5) },
      { author: 'Bennett', text: 'EMS two minutes out', time: minutes(0.4) },
    ],
    status: 'open',
    createdAt: now - 42,
  },
  {
    id: 4470,
    code: '10-71',
    title: 'Shots fired',
    description: 'Multiple shots heard near the cul-de-sac.',
    location: 'Grove Street, Davis',
    coords: { x: 100, y: -1900, z: 21 },
    plate: null,
    priority: 1,
    caller: { name: 'Anonymous', number: '555-0110' },
    raisedBy: null,
    responders: [
      { citizenid: 'MRY41270', name: 'Reyes', callsign: '1-ADAM-12' },
      { citizenid: 'LOR33021', name: 'Ortega', callsign: '1-LINCOLN-4' },
    ],
    notes: [],
    status: 'open',
    createdAt: minutes(2),
  },
  {
    id: 4468,
    code: '10-60',
    title: 'Vehicle theft in progress',
    description: 'Grey Karin Sultan, plate 61ROM884.',
    location: 'Alta Street, Pillbox Hill',
    coords: { x: 250, y: -800, z: 30 },
    plate: '61ROM884',
    priority: 2,
    caller: { name: 'Maya Chen', number: '555-0151' },
    raisedBy: null,
    responders: [],
    notes: [],
    status: 'open',
    createdAt: minutes(6),
  },
  {
    id: 4466,
    code: '911',
    title: 'Fight outside the bar',
    description: 'Caller reports a fight outside the bar.',
    location: 'Vespucci Boulevard, Del Perro',
    coords: { x: -1300, y: -900, z: 12 },
    plate: null,
    priority: 3,
    caller: { name: 'Bartender', number: '555-0142' },
    raisedBy: null,
    responders: [{ citizenid: 'COK33901', name: 'Okafor', callsign: '2-MARY-7' }],
    notes: [],
    status: 'open',
    createdAt: minutes(11),
  },
  {
    id: 4460,
    code: '10-50',
    title: 'Minor collision',
    description: 'Two cars, no injuries.',
    location: 'Legion Square',
    coords: null,
    plate: null,
    priority: 3,
    caller: { name: 'Driver', number: '555-0177' },
    raisedBy: null,
    responders: [],
    notes: [],
    status: 'closed',
    createdAt: minutes(48),
  },
];

let units: Unit[] = [
  {
    id: 1,
    callsign: '1-ADAM-12',
    department: 'police',
    status: 'enroute',
    members: [
      { citizenid: 'MRY41270', name: 'Reyes', callsign: '1-ADAM-12' },
      { citizenid: 'LOR33021', name: 'Ortega', callsign: '1-LINCOLN-4' },
    ],
  },
  {
    id: 2,
    callsign: '1-LINCOLN-4',
    department: 'police',
    status: 'busy',
    members: [{ citizenid: 'LOR33021', name: 'Ortega', callsign: '1-LINCOLN-4' }],
  },
  {
    id: 3,
    callsign: '2-MARY-7',
    department: 'police',
    status: 'onscene',
    members: [{ citizenid: 'COK33901', name: 'Okafor', callsign: '2-MARY-7' }],
  },
  {
    id: 4,
    callsign: '3-KING-2',
    department: 'police',
    status: 'available',
    members: [
      { citizenid: 'DCH10010', name: 'Chen', callsign: '3-KING-2' },
      { citizenid: 'WAL20020', name: 'Walsh', callsign: '3-KING-3' },
    ],
  },
  {
    id: 5,
    callsign: 'BCSO 4-DAVID-1',
    department: 'sheriff',
    status: 'available',
    members: [{ citizenid: 'WHR51020', name: 'Harlan', callsign: '4-DAVID-1' }],
  },
  {
    id: 6,
    callsign: 'EMS 3',
    department: 'ambulance',
    status: 'enroute',
    members: [{ citizenid: 'EBN44010', name: 'Bennett', callsign: 'EMS 3' }],
  },
];

const departmentLabels: Record<string, string> = { police: 'LSPD', sheriff: 'BCSO' };

let certificates: Certificate[] = [
  { id: 1, name: 'Field training officer', department: 'police', departmentLabel: 'LSPD', holders: 8 },
  { id: 2, name: 'Pursuit driving', department: 'police', departmentLabel: 'LSPD', holders: 19 },
  { id: 3, name: 'SWAT', department: 'police', departmentLabel: 'LSPD', holders: 6 },
  { id: 4, name: 'K9 handler', department: 'police', departmentLabel: 'LSPD', holders: 3 },
  { id: 5, name: 'Air unit', department: 'police', departmentLabel: 'LSPD', holders: 2 },
  { id: 6, name: 'Marine unit', department: 'sheriff', departmentLabel: 'BCSO', holders: 4 },
];

let roster: RosterEntry[] = [
  {
    citizenid: 'DCH10010',
    name: 'Diane Chen',
    callsign: '1-COMMAND',
    department: 'police',
    departmentLabel: 'LSPD',
    grade: 5,
    gradeName: 'Captain',
    unit: null,
    status: 'offduty',
    online: false,
    certificates: [1, 3, 4],
  },
  {
    citizenid: 'MRY41270',
    name: 'Maya Reyes',
    callsign: '1-ADAM-12',
    department: 'police',
    departmentLabel: 'LSPD',
    grade: 2,
    gradeName: 'Officer II',
    unit: '1-ADAM-12',
    status: 'available',
    online: true,
    certificates: [2],
  },
  {
    citizenid: 'AFS22080',
    name: 'Aaron Foster',
    callsign: 'D-4',
    department: 'police',
    departmentLabel: 'LSPD',
    grade: 3,
    gradeName: 'Detective',
    unit: null,
    status: 'busy',
    online: true,
    certificates: [],
  },
  {
    citizenid: 'COK33901',
    name: 'Chidi Okafor',
    callsign: '2-MARY-7',
    department: 'police',
    departmentLabel: 'LSPD',
    grade: 3,
    gradeName: 'Sergeant',
    unit: '2-MARY-7',
    status: 'onscene',
    online: true,
    certificates: [1, 5],
  },
  {
    citizenid: 'LOR33021',
    name: 'Luis Ortega',
    callsign: '1-LINCOLN-4',
    department: 'police',
    departmentLabel: 'LSPD',
    grade: 2,
    gradeName: 'Officer II',
    unit: '1-LINCOLN-4',
    status: 'busy',
    online: true,
    certificates: [2],
  },
  {
    citizenid: 'WHR51020',
    name: 'Wade Harlan',
    callsign: '4-DAVID-1',
    department: 'sheriff',
    departmentLabel: 'BCSO',
    grade: 1,
    gradeName: 'Deputy',
    unit: 'BCSO 4-DAVID-1',
    status: 'available',
    online: true,
    certificates: [],
  },
];

const rankPermissions: Record<number, (keyof Permissions)[]> = {
  6: ['administrator'],
  5: [
    'createIncident',
    'editIncident',
    'deleteIncident',
    'editProfile',
    'manageWarrants',
    'manageBolos',
    'postBulletins',
    'managePenalCode',
    'manageTags',
    'manageRanks',
    'manageCertificates',
    'manageTemplates',
    'deleteEvidence',
  ],
  4: [
    'createIncident',
    'editIncident',
    'deleteIncident',
    'editProfile',
    'manageWarrants',
    'manageBolos',
    'postBulletins',
    'managePenalCode',
    'manageTags',
    'manageTemplates',
  ],
  3: [
    'createIncident',
    'editIncident',
    'editProfile',
    'manageWarrants',
    'manageBolos',
    'postBulletins',
    'manageTags',
  ],
  2: ['createIncident', 'editIncident', 'editProfile', 'manageBolos', 'postBulletins'],
  1: ['createIncident', 'manageBolos'],
};

const rankNames: [number, string, number][] = [
  [6, 'Chief', 1],
  [5, 'Captain', 2],
  [4, 'Lieutenant', 4],
  [3, 'Sergeant', 7],
  [2, 'Officer II', 18],
  [1, 'Cadet', 10],
];

let ranks: Rank[] = rankNames.map(([grade, name, holders]) => ({
  department: 'police',
  departmentLabel: 'LSPD',
  grade,
  name,
  isBoss: grade >= 5,
  holders,
  permissions: permissions(rankPermissions[grade] ?? []),
}));

let templates: Template[] = [
  {
    id: 1,
    kind: 'incident',
    name: 'Armed robbery',
    content:
      'At [time] units responded to [alarm or 911 call] at [business], [street].\n\nSuspects: [number], described as [description].\nWeapons seen: [weapons].\nVehicle: [model, colour, plate], last seen heading [direction].\n\nStolen: [cash amount or items].\nInjuries: [none or details].\n\nActions taken: [pursuit, arrest, scene secured].',
  },
  {
    id: 2,
    kind: 'incident',
    name: 'Traffic stop',
    content:
      'Stopped [model, plate] on [street] for [reason].\n\nDriver: [name].\nOutcome: [warning, citation, arrest].',
  },
  {
    id: 3,
    kind: 'report',
    name: 'Use of force',
    content: 'Force used: [type].\nReason: [threat or resistance].\nInjuries: [none or details].',
  },
  {
    id: 4,
    kind: 'report',
    name: 'Gang intelligence',
    content: 'Group: [name].\nArea: [streets].\nObserved: [activity].\nMembers seen: [names].',
  },
];

let bulletins = [
  {
    id: 3,
    title: 'New patrol zones from Monday',
    body: 'Night shift now covers Sandy Shores until 06:00. Zone maps are in the briefing room.',
    pinned: true,
    author: 'Sgt. Sarah Mitchell',
    createdAt: hours(2),
  },
  {
    id: 2,
    title: 'Quarterly equipment check',
    body: 'Sign off your vest, radio and sidearm at the armoury before Friday.',
    pinned: false,
    author: 'Lt. Marco Rodriguez',
    createdAt: days(1),
  },
  {
    id: 1,
    title: 'Active shooter training moved',
    body: 'Now Thursday at 09:00, Mission Row range. Attendance is required.',
    pinned: false,
    author: 'Cpt. Diane Chen',
    createdAt: days(3),
  },
];

let nextId = 5000;

function matches(query: string, ...values: (string | null | undefined)[]): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle) return true;

  return values.some((value) => value?.toLowerCase().includes(needle));
}

function vehicle(plate: string): Vehicle | null {
  const summary = vehicles.find((entry) => entry.plate === plate);
  if (!summary) return null;

  return {
    ...summary,
    clamped: false,
    bolos: bolos.filter((bolo) => bolo.plate === plate && bolo.status === 'active'),
    warrants: warrants.filter(
      (warrant) => warrant.citizenid === summary.citizenid && warrant.status === 'active' && warrant.type === 'arrest',
    ),
    incidents: plate === '82HJK019' ? incidents.filter((incident) => incident.id === 2041).map(summarise) : [],
  };
}

export const handlers: MockHandlers = {
  boot: () => ({ locales: {} }),
  close: () => ok,
  setStatus: ({ status }) => {
    officer.status = status;
    return ok;
  },
  getCounts: () => ({
    warrants: warrants.filter((warrant) => warrant.status === 'active').length,
    bolos: bolos.filter((bolo) => bolo.status === 'active').length,
  }),
  getLocation: () => ({ location: 'Great Ocean Highway, Chumash', coords: { x: -3000, y: 450, z: 6 } }),
  getDashboard: () => {
    const active = warrants.filter((warrant) => warrant.status === 'active');
    const activeBolos = bolos.filter((bolo) => bolo.status === 'active');

    return {
      stats: {
        warrants: active.length,
        warrantsExpiring: active.filter(
          (warrant) => warrant.expiresAt != null && warrant.expiresAt - now < settings.records.warrantWarnHours * 3600,
        ).length,
        bolos: activeBolos.length,
        bolosVehicles: activeBolos.filter((bolo) => bolo.type === 'vehicle').length,
        bolosPeople: activeBolos.filter((bolo) => bolo.type === 'person').length,
        incidentsWeek: 12,
        reportsWeek: 7,
        unitsOnDuty: 9,
        unitsAvailable: 5,
        unitsOnCalls: 4,
      },
      calls: calls.filter((call) => call.status === 'open').slice(0, 3),
      incidents: incidents
        .filter((incident) => incident.status === 'filed')
        .slice(0, 3)
        .map(summarise),
      warrants: active.slice(0, 1),
      bolos: activeBolos.slice(0, 2),
      bulletins: [...bulletins].sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.createdAt - a.createdAt),
    };
  },
  search: ({ query }) => ({
    citizens: citizenSummaries.filter((entry) => matches(query, entry.name, entry.citizenid, entry.phone)).slice(0, 4),
    vehicles: vehicles.filter((entry) => matches(query, entry.plate, entry.label, entry.owner)).slice(0, 4),
    weapons: weapons.filter((entry) => matches(query, entry.serial, entry.label, entry.owner)).slice(0, 4),
    incidents: incidents
      .filter((entry) => matches(query, entry.title, String(entry.id)))
      .slice(0, 4)
      .map(summarise),
  }),

  postBulletin: ({ title, body, pinned }) => {
    bulletins = [
      { id: ++nextId, title, body, pinned, author: officer.name, createdAt: Math.floor(Date.now() / 1000) },
      ...bulletins,
    ];
    return ok;
  },
  pinBulletin: ({ id, pinned }) => {
    bulletins = bulletins.map((bulletin) => (bulletin.id === id ? { ...bulletin, pinned } : bulletin));
    return ok;
  },
  deleteBulletin: ({ id }) => {
    bulletins = bulletins.filter((bulletin) => bulletin.id !== id);
    return ok;
  },

  searchCitizens: ({ query }) =>
    citizenSummaries.filter((entry) => matches(query, entry.name, entry.citizenid, entry.phone)),
  getCitizen: ({ citizenid }) => citizen(citizenid),
  saveCitizen: () => ok,
  addCitizenTag: ({ citizenid, tagId }) => {
    const entry = citizenSummaries.find((summary) => summary.citizenid === citizenid);
    if (entry && !entry.tags.some((existing) => existing.id === tagId)) entry.tags.push(tag(tagId));
    return ok;
  },
  removeCitizenTag: ({ citizenid, tagId }) => {
    const entry = citizenSummaries.find((summary) => summary.citizenid === citizenid);
    if (entry) entry.tags = entry.tags.filter((existing) => existing.id !== tagId);
    return ok;
  },
  grantLicence: ({ key }) => {
    const licence = darnellLicences.find((entry) => entry.key === key);
    if (licence) licence.status = 'valid';
    return ok;
  },
  getLicences: ({ citizenids }) => Object.fromEntries(citizenids.map((id) => [id, citizen(id)?.licences ?? []])),
  revokeLicence: ({ key }) => {
    const licence = darnellLicences.find((entry) => entry.key === key);
    if (licence) licence.status = 'revoked';
    return ok;
  },

  searchVehicles: ({ query }) => vehicles.filter((entry) => matches(query, entry.plate, entry.label, entry.owner)),
  getVehicle: ({ plate }) => vehicle(plate),
  setVehicleStolen: ({ plate, stolen }) => {
    const entry = vehicles.find((summary) => summary.plate === plate);
    if (entry) entry.stolen = stolen;
    return ok;
  },
  searchWeapons: ({ query }) => (query.trim() ? weapons.filter((entry) => matches(query, entry.serial)) : []),
  searchProperties: ({ query }) => properties.filter((entry) => matches(query, entry.label, entry.owner)),
  waypointProperty: () => ok,

  getIncidents: ({ query, kind }) =>
    incidents
      .filter(
        (entry) =>
          (kind === 'all' || entry.kind === kind) && matches(query, entry.title, entry.author, String(entry.id)),
      )
      .map(summarise),
  getIncident: ({ id }) => incidents.find((entry) => entry.id === id) ?? null,
  saveIncident: (incident) => {
    const id = incident.id ?? ++nextId;
    const saved = { ...incident, id, status: 'draft' as const, updatedAt: Math.floor(Date.now() / 1000) };
    incidents = [saved, ...incidents.filter((entry) => entry.id !== id)];
    return { ok: true, id };
  },
  fileIncident: (incident) => {
    const id = incident.id ?? ++nextId;
    incidents = [
      { ...incident, id, status: 'filed', updatedAt: Math.floor(Date.now() / 1000) },
      ...incidents.filter((entry) => entry.id !== id),
    ];

    const sentences = incident.suspects.map((suspect) => {
      const totals = suspect.charges.reduce(
        (sum, item) => {
          const charge = charges.find((entry) => entry.id === item.chargeId);
          if (!charge) return sum;
          return {
            months: sum.months + charge.months * item.counts,
            fine: sum.fine + charge.fine * item.counts,
            points: sum.points + charge.points * item.counts,
          };
        },
        { months: 0, fine: 0, points: 0 },
      );
      const suspended = suspect.citizenid === 'HKW49120' && totals.points + 9 >= 12 ? ['driver'] : [];
      return { citizenid: suspect.citizenid, name: suspect.name, ...totals, jailed: totals.months > 0, suspended };
    });

    return { ok: true, id, sentences };
  },
  deleteIncident: ({ id }) => {
    incidents = incidents.filter((entry) => entry.id !== id);
    return ok;
  },

  getWarrants: ({ status }) => {
    const count = (value: Warrant['status']) => warrants.filter((warrant) => warrant.status === value).length;
    const warn = settings.records.warrantWarnHours * 3600;

    return {
      warrants: warrants.filter((warrant) => warrant.status === status),
      counts: {
        active: count('active'),
        served: count('served'),
        expired: count('expired'),
        cancelled: count('cancelled'),
        ending: warrants.filter((warrant) => warrant.status === 'active' && warrant.expiresAt != null && warrant.expiresAt - now < warn).length,
      },
    };
  },
  createWarrant: ({ citizenid, type, title, description, expiresInDays }) => {
    const subject = citizenSummaries.find((entry) => entry.citizenid === citizenid);
    warrants = [
      {
        id: ++nextId,
        citizenid,
        name: subject?.name ?? citizenid,
        type,
        title,
        description,
        status: 'active',
        issuedBy: officer.name,
        expiresAt: now + expiresInDays * 86400,
        incidentId: null,
        createdAt: now,
      },
      ...warrants,
    ];
    return ok;
  },
  setWarrantStatus: ({ id, status }) => {
    warrants = warrants.map((warrant) => (warrant.id === id ? { ...warrant, status } : warrant));
    return ok;
  },
  extendWarrant: ({ id, days: extra }) => {
    warrants = warrants.map((warrant) =>
      warrant.id === id ? { ...warrant, expiresAt: (warrant.expiresAt ?? now) + extra * 86400 } : warrant,
    );
    return ok;
  },

  getBolos: ({ status }) => bolos.filter((bolo) => status === 'all' || bolo.status === status),
  createBolo: (bolo) => {
    bolos = [
      {
        ...bolo,
        id: ++nextId,
        status: 'active',
        department: officer.department.label,
        issuedBy: officer.name,
        createdAt: Math.floor(Date.now() / 1000),
      },
      ...bolos,
    ];
    return ok;
  },
  setBoloStatus: ({ id, status }) => {
    bolos = bolos.map((bolo) => (bolo.id === id ? { ...bolo, status } : bolo));
    return ok;
  },

  getEvidence: ({ type, query }) =>
    evidence.filter(
      (item) =>
        (type === 'all' || item.type === type) &&
        matches(query, item.code, item.title, item.citizenName, item.incidentId ? String(item.incidentId) : null),
    ),
  addEvidence: (item) => {
    const id = ++nextId;
    const prefix = item.type === 'forensic' ? 'FS' : 'EV';
    evidence = [
      {
        ...item,
        id,
        code: `${prefix}-${String(id).padStart(4, '0')}`,
        citizenName: null,
        collectedBy: officer.name,
        createdAt: Math.floor(Date.now() / 1000),
      },
      ...evidence,
    ];
    return ok;
  },
  deleteEvidence: ({ id }) => {
    evidence = evidence.filter((item) => item.id !== id);
    return ok;
  },

  getCharges: () => charges,
  saveCharge: (charge) => {
    if (charge.id === null) {
      charges = [...charges, { ...charge, id: ++nextId }];
      return ok;
    }

    const id = charge.id;
    charges = charges.map((entry) => (entry.id === id ? { ...charge, id } : entry));
    return ok;
  },
  deleteCharge: ({ id }) => {
    charges = charges.filter((entry) => entry.id !== id);
    return ok;
  },

  getCalls: () => calls,
  respondCall: ({ id }) => {
    calls = calls.map((call) =>
      call.id === id
        ? {
            ...call,
            responders: [
              ...call.responders,
              { citizenid: officer.citizenid, name: 'Reyes', callsign: officer.callsign },
            ],
          }
        : call,
    );
    return ok;
  },
  leaveCall: ({ id }) => {
    calls = calls.map((call) =>
      call.id === id
        ? { ...call, responders: call.responders.filter((entry) => entry.citizenid !== officer.citizenid) }
        : call,
    );
    return ok;
  },
  waypointCall: () => ok,
  addCallNote: ({ id, text }) => {
    calls = calls.map((call) =>
      call.id === id
        ? { ...call, notes: [...call.notes, { author: 'Reyes', text, time: Math.floor(Date.now() / 1000) }] }
        : call,
    );
    return ok;
  },
  closeCall: ({ id }) => {
    calls = calls.map((call) => (call.id === id ? { ...call, status: 'closed' } : call));
    return ok;
  },
  assignCall: ({ id, unitId }) => {
    const unit = units.find((entry) => entry.id === unitId);
    if (!unit) return { ok: false, error: 'That unit no longer exists.' };

    calls = calls.map((call) =>
      call.id === id
        ? {
            ...call,
            responders: [
              ...call.responders,
              ...unit.members.filter(
                (member) => !call.responders.some((entry) => entry.citizenid === member.citizenid),
              ),
            ],
          }
        : call,
    );
    return ok;
  },

  getUnits: () => units,
  createUnit: ({ callsign }) => {
    units = [
      ...units.map((unit) => ({
        ...unit,
        members: unit.members.filter((member) => member.citizenid !== officer.citizenid),
      })),
      {
        id: ++nextId,
        callsign,
        department: officer.department.name,
        status: 'available',
        members: [{ citizenid: officer.citizenid, name: 'Reyes', callsign: officer.callsign }],
      },
    ];
    return ok;
  },
  joinUnit: ({ id }) => {
    units = units.map((unit) => {
      const members = unit.members.filter((member) => member.citizenid !== officer.citizenid);
      return unit.id === id
        ? {
            ...unit,
            members: [...members, { citizenid: officer.citizenid, name: 'Reyes', callsign: officer.callsign }],
          }
        : { ...unit, members };
    });
    return ok;
  },
  leaveUnit: () => {
    units = units.map((unit) => ({
      ...unit,
      members: unit.members.filter((member) => member.citizenid !== officer.citizenid),
    }));
    return ok;
  },
  deleteUnit: ({ id }) => {
    units = units.filter((unit) => unit.id !== id);
    return ok;
  },
  setUnitStatus: ({ id, status }) => {
    units = units.map((unit) => (unit.id === id ? { ...unit, status } : unit));
    return ok;
  },

  getRoster: () => roster,
  saveOfficer: ({ citizenid, callsign, grade }) => {
    const rank = ranks.find((entry) => entry.grade === grade);
    roster = roster.map((entry) =>
      entry.citizenid === citizenid ? { ...entry, callsign, grade, gradeName: rank?.name ?? entry.gradeName } : entry,
    );
    return ok;
  },
  grantCertificate: ({ citizenid, certificateId }) => {
    roster = roster.map((entry) =>
      entry.citizenid === citizenid ? { ...entry, certificates: [...entry.certificates, certificateId] } : entry,
    );
    return ok;
  },
  revokeCertificate: ({ citizenid, certificateId }) => {
    roster = roster.map((entry) =>
      entry.citizenid === citizenid
        ? { ...entry, certificates: entry.certificates.filter((id) => id !== certificateId) }
        : entry,
    );
    return ok;
  },

  getRanks: () => ranks,
  saveRank: ({ department, grade, permissions: granted }) => {
    ranks = ranks.map((rank) =>
      rank.department === department && rank.grade === grade ? { ...rank, permissions: granted } : rank,
    );
    return ok;
  },
  getTags: () => tags,
  saveTag: ({ id, name, color }) => {
    if (id === null) {
      tags.push({ id: ++nextId, name, color, holders: 0 });
      return ok;
    }

    const existing = tags.find((entry) => entry.id === id);
    if (existing) Object.assign(existing, { name, color });
    return ok;
  },
  deleteTag: ({ id }) => {
    const index = tags.findIndex((entry) => entry.id === id);
    if (index !== -1) tags.splice(index, 1);
    return ok;
  },
  getCertificates: () => certificates,
  saveCertificate: ({ id, name, department }) => {
    certificates =
      id === null
        ? [...certificates, { id: ++nextId, name, department, departmentLabel: departmentLabels[department] ?? department, holders: 0 }]
        : certificates.map((entry) =>
            entry.id === id ? { ...entry, name, department, departmentLabel: departmentLabels[department] ?? department } : entry,
          );
    return ok;
  },
  deleteCertificate: ({ id }) => {
    certificates = certificates.filter((entry) => entry.id !== id);
    return ok;
  },
  getTemplates: () => templates,
  saveTemplate: ({ id, kind, name, content }) => {
    templates =
      id === null
        ? [...templates, { id: ++nextId, kind, name, content }]
        : templates.map((entry) => (entry.id === id ? { ...entry, kind, name, content } : entry));
    return ok;
  },
  deleteTemplate: ({ id }) => {
    templates = templates.filter((entry) => entry.id !== id);
    return ok;
  },
  getSettings: () => settings,
  saveSettings: (next) => {
    Object.assign(settings, next);
    return ok;
  },
};

export const openMessage: Messages = {
  action: 'open',
  data: { officer, settings, keybinds: { respond: 'E', panic: 'O' }, page: 'dashboard', citizenid: null },
};

export function startAlerts(): void {
  const [first, second] = calls;
  if (!first || !second) return;

  const alerts: Messages[] = [
    { action: 'alert', data: { call: second, distance: 2800, seconds: 30, respondKey: 'E' } },
    { action: 'alert', data: { call: first, distance: 1200, seconds: 12, respondKey: 'E' } },
  ];

  for (const message of alerts) window.postMessage(message, '*');
}
