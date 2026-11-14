export type Permission =
  | 'createIncident'
  | 'editIncident'
  | 'deleteIncident'
  | 'editProfile'
  | 'manageWarrants'
  | 'manageBolos'
  | 'postBulletins'
  | 'managePenalCode'
  | 'manageTags'
  | 'manageRanks'
  | 'manageCertificates'
  | 'manageTemplates'
  | 'deleteEvidence'
  | 'administrator';

export type Permissions = Record<Permission, boolean>;

export type Page =
  | 'dashboard'
  | 'dispatch'
  | 'citizens'
  | 'vehicles'
  | 'weapons'
  | 'properties'
  | 'incidents'
  | 'warrants'
  | 'bolos'
  | 'evidence'
  | 'penalcode'
  | 'roster'
  | 'management';

export type UnitStatus = 'available' | 'busy' | 'enroute' | 'onscene';

export type Department = {
  name: string;
  label: string;
  subtitle: string;
};

export type Officer = {
  citizenid: string;
  name: string;
  callsign: string;
  gradeName: string;
  department: Department;
  isEms: boolean;
  status: UnitStatus;
  permissions: Permissions;
  canManageLicences: boolean;
  pages: Page[];
};

export type Settings = {
  dispatch: {
    onDutyOnly: boolean;
    phoneRequired: boolean;
    popupSeconds: number;
    autoAlerts: Record<'shooting' | 'vehicleTheft' | 'fight' | 'playerDown' | 'explosion' | 'speeding', boolean>;
  };
  records: {
    warrantWarnHours: number;
    bulletinMinGrade: number;
    emsAccess: boolean;
  };
};

export type Keybinds = {
  respond: string;
  panic: string;
};

export type Vec3 = { x: number; y: number; z: number };

export type Person = {
  citizenid: string | null;
  name: string;
};

export type Responder = {
  citizenid: string;
  name: string;
  callsign: string;
};

export type CallNote = {
  author: string;
  text: string;
  time: number;
};

export type Call = {
  id: number;
  code: string;
  title: string;
  description: string;
  location: string;
  coords: Vec3 | null;
  plate: string | null;
  priority: 1 | 2 | 3;
  caller: { name: string; number: string } | null;
  raisedBy: string | null;
  responders: Responder[];
  notes: CallNote[];
  status: 'open' | 'closed';
  createdAt: number;
};

export type CallChange = { id: number } & (
  | { change: 'responders'; responders: Responder[] }
  | { change: 'note'; note: CallNote; dropOldest: boolean }
  | { change: 'status'; status: Call['status'] }
);

export type Unit = {
  id: number;
  callsign: string;
  department: string;
  status: UnitStatus;
  members: Responder[];
};

export type Bulletin = {
  id: number;
  title: string;
  body: string;
  pinned: boolean;
  author: string;
  createdAt: number;
};

export type Tag = {
  id: number;
  name: string;
  color: string;
};

export type ChargeClass = 'felony' | 'misdemeanor' | 'infraction';

export type Charge = {
  id: number;
  category: string;
  code: string;
  title: string;
  description: string;
  class: ChargeClass;
  months: number;
  fine: number;
  points: number;
  stackable: boolean;
};

export type Conviction = {
  id: number;
  title: string;
  code: string;
  class: ChargeClass;
  counts: number;
  months: number;
  fine: number;
  points: number;
  incidentId?: number | null;
  createdAt: number;
};

export type LicenceStatus = 'valid' | 'revoked' | 'suspended' | 'none';

export type Licence = {
  key: string;
  label: string;
  status: LicenceStatus;
  points: number;
  pointsLimit?: number;
};

export type WarrantType = 'arrest' | 'search' | 'bench';

export type Warrant = {
  id: number;
  citizenid: string;
  name: string;
  type: WarrantType;
  title: string;
  description: string;
  status: 'active' | 'served' | 'cancelled' | 'expired';
  issuedBy: string;
  expiresAt?: number | null;
  incidentId?: number | null;
  createdAt: number;
};

export type WarrantCounts = Record<Warrant['status'], number> & { ending: number };

export type WarrantList = { warrants: Warrant[]; counts: WarrantCounts };

export type Bolo = {
  id: number;
  type: 'person' | 'vehicle';
  title: string;
  description: string;
  citizenid: string | null;
  plate: string | null;
  personName: string;
  lastSeen: string;
  status: 'active' | 'cancelled';
  department: string;
  issuedBy: string;
  createdAt: number;
};

export type EvidenceType = 'photo' | 'item' | 'forensic';

export type Evidence = {
  id: number;
  code: string;
  type: EvidenceType;
  title: string;
  description: string;
  image: string;
  location: string;
  citizenid?: string | null;
  citizenName?: string | null;
  incidentId?: number | null;
  collectedBy: string;
  createdAt: number;
};

export type VehicleState = 'out' | 'garaged' | 'impounded';

export type VehicleSummary = {
  plate: string;
  model: string;
  label: string;
  owner: string;
  citizenid: string;
  state: VehicleState;
  flagged: boolean;
  stolen: boolean;
};

export type Vehicle = VehicleSummary & {
  clamped: boolean;
  bolos: Bolo[];
  warrants: Warrant[];
  incidents: IncidentSummary[];
};

export type Weapon = {
  serial: string;
  item: string;
  label: string;
  owner: string | null;
  citizenid: string | null;
  stolen: boolean;
};

export type Property = {
  id: number;
  label: string;
  address: string;
  type: string;
  owner: string | null;
  citizenid: string | null;
};

export type CitizenSummary = {
  citizenid: string;
  name: string;
  dob: string;
  phone: string;
  tags: Tag[];
  wanted: boolean;
  online: boolean;
  convictions: number;
};

export type Citizen = CitizenSummary & {
  sex: 'male' | 'female';
  fingerprint: string;
  bloodType: string;
  job: string;
  address: string;
  image: string;
  notes: string;
  jailed: { releaseAt: number; months: number } | null;
  licences: Licence[];
  record: {
    totalMonths: number;
    totalFine: number;
    points: number;
    convictions: Conviction[];
  };
  incidents: IncidentSummary[];
  vehicles: VehicleSummary[];
  weapons: Weapon[];
  properties: Property[];
  evidence: Evidence[];
  warrants: Warrant[];
};

export type IncidentKind = 'incident' | 'report';

export type IncidentSummary = {
  id: number;
  kind: IncidentKind;
  status: 'draft' | 'filed';
  title: string;
  location: string;
  author: string;
  authorCid?: string | null;
  suspects: number;
  occurredAt: number;
};

export type SuspectCharge = {
  chargeId: number;
  counts: number;
};

export type Suspect = Person & {
  charges: SuspectCharge[];
};

export type Incident = {
  id: number | null;
  kind: IncidentKind;
  status: 'draft' | 'filed';
  title: string;
  location: string;
  coords: Vec3 | null;
  occurredAt: number;
  narrative: string;
  officers: Person[];
  suspects: Suspect[];
  witnesses: Person[];
  evidence: Pick<Evidence, 'id' | 'code' | 'title'>[];
  author: string;
  authorCid?: string | null;
  updatedAt: number;
};

export type SentenceResult = {
  citizenid: string | null;
  name: string;
  months: number;
  fine: number;
  points: number;
  jailed: boolean;
  suspended: string[];
};

export type RosterEntry = {
  citizenid: string;
  name: string;
  callsign: string;
  department: string;
  departmentLabel: string;
  grade: number;
  gradeName: string;
  unit: string | null;
  status: UnitStatus | 'offduty';
  online: boolean;
  certificates: number[];
};

export type Rank = {
  department: string;
  departmentLabel: string;
  grade: number;
  name: string;
  isBoss: boolean;
  holders: number;
  permissions: Permissions;
};

export type Certificate = {
  id: number;
  name: string;
  department: string;
  departmentLabel: string;
  holders: number;
};

export type Template = {
  id: number;
  kind: IncidentKind;
  name: string;
  content: string;
};

export type Dashboard = {
  stats: {
    warrants: number;
    warrantsExpiring: number;
    bolos: number;
    bolosVehicles: number;
    bolosPeople: number;
    incidentsWeek: number;
    reportsWeek: number;
    unitsOnDuty: number;
    unitsAvailable: number;
    unitsOnCalls: number;
  };
  calls: Call[];
  incidents: IncidentSummary[];
  warrants: Warrant[];
  bolos: Bolo[];
  bulletins: Bulletin[];
};

export type SearchResults = {
  citizens: CitizenSummary[];
  vehicles: VehicleSummary[];
  weapons: Weapon[];
  incidents: IncidentSummary[];
};

export type Counts = { warrants: number; bolos: number };

export type Failure = { ok: false; error: string };

export type Ok = { ok: true } | Failure;

export type Requests = {
  boot: [void, { locales: Record<string, string> }];
  close: [void, Ok];
  setStatus: [{ status: UnitStatus }, Ok];
  getLocation: [void, { location: string; coords: Vec3 }];
  getDashboard: [void, Dashboard | Failure | false];
  getCounts: [void, Counts | Failure | false];
  search: [{ query: string }, SearchResults];

  postBulletin: [{ title: string; body: string; pinned: boolean }, Ok];
  pinBulletin: [{ id: number; pinned: boolean }, Ok];
  deleteBulletin: [{ id: number }, Ok];

  searchCitizens: [{ query: string }, CitizenSummary[]];
  getCitizen: [{ citizenid: string }, Citizen | null | false];
  saveCitizen: [{ citizenid: string; notes: string; image: string }, Ok];
  addCitizenTag: [{ citizenid: string; tagId: number }, Ok];
  removeCitizenTag: [{ citizenid: string; tagId: number }, Ok];
  grantLicence: [{ citizenid: string; key: string }, Ok];
  revokeLicence: [{ citizenid: string; key: string; reason: string }, Ok];
  getLicences: [{ citizenids: string[] }, Record<string, Licence[]> | Failure | false];

  searchVehicles: [{ query: string }, VehicleSummary[]];
  getVehicle: [{ plate: string }, Vehicle | null];
  setVehicleStolen: [{ plate: string; stolen: boolean }, Ok];
  searchWeapons: [{ query: string }, Weapon[]];
  searchProperties: [{ query: string }, Property[]];
  waypointProperty: [{ id: number }, Ok];

  getIncidents: [{ query: string; kind: IncidentKind | 'all' }, IncidentSummary[]];
  getIncident: [{ id: number }, Incident | null];
  saveIncident: [Incident, { ok: true; id: number } | Failure];
  fileIncident: [Incident, { ok: true; id: number; sentences: SentenceResult[] } | Failure];
  deleteIncident: [{ id: number }, Ok];

  getWarrants: [{ status: Warrant['status'] }, WarrantList | Failure | false];
  createWarrant: [{ citizenid: string; type: WarrantType; title: string; description: string; expiresInDays: number }, Ok];
  setWarrantStatus: [{ id: number; status: Warrant['status'] }, Ok];
  extendWarrant: [{ id: number; days: number }, Ok];

  getBolos: [{ status: Bolo['status'] | 'all' }, Bolo[]];
  createBolo: [Omit<Bolo, 'id' | 'status' | 'department' | 'issuedBy' | 'createdAt'>, Ok];
  setBoloStatus: [{ id: number; status: Bolo['status'] }, Ok];

  getEvidence: [{ type: EvidenceType | 'all'; query: string }, Evidence[]];
  addEvidence: [Omit<Evidence, 'id' | 'code' | 'citizenName' | 'collectedBy' | 'createdAt'>, Ok];
  deleteEvidence: [{ id: number }, Ok];

  getCharges: [void, Charge[]];
  saveCharge: [Omit<Charge, 'id'> & { id: number | null }, Ok];
  deleteCharge: [{ id: number }, Ok];

  getCalls: [void, Call[] | Failure | false];
  respondCall: [{ id: number }, Ok];
  leaveCall: [{ id: number }, Ok];
  waypointCall: [{ id: number }, Ok];
  addCallNote: [{ id: number; text: string }, Ok];
  closeCall: [{ id: number }, Ok];
  assignCall: [{ id: number; unitId: number }, Ok];

  getUnits: [void, Unit[] | Failure | false];
  createUnit: [{ callsign: string }, Ok];
  joinUnit: [{ id: number }, Ok];
  leaveUnit: [void, Ok];
  deleteUnit: [{ id: number }, Ok];
  setUnitStatus: [{ id: number; status: UnitStatus }, Ok];

  getRoster: [void, RosterEntry[]];
  saveOfficer: [{ citizenid: string; callsign: string; grade: number }, Ok];
  grantCertificate: [{ citizenid: string; certificateId: number }, Ok];
  revokeCertificate: [{ citizenid: string; certificateId: number }, Ok];

  getRanks: [void, Rank[] | Failure | false];
  saveRank: [{ department: string; grade: number; permissions: Permissions }, Ok];
  getTags: [void, (Tag & { holders: number })[]];
  saveTag: [{ id: number | null; name: string; color: string }, Ok];
  deleteTag: [{ id: number }, Ok];
  getCertificates: [void, Certificate[]];
  saveCertificate: [{ id: number | null; name: string; department: string }, Ok];
  deleteCertificate: [{ id: number }, Ok];
  getTemplates: [void, Template[]];
  saveTemplate: [{ id: number | null; kind: IncidentKind; name: string; content: string }, Ok];
  deleteTemplate: [{ id: number }, Ok];
  getSettings: [void, Settings];
  saveSettings: [Settings, Ok];
};

export type Messages =
  | { action: 'open'; data: { officer: Officer; settings: Settings; keybinds: Keybinds; page: Page | null; citizenid: string | null } }
  | { action: 'close' }
  | { action: 'callAdded'; data: Call }
  | { action: 'callUpdated'; data: CallChange }
  | { action: 'callRemoved'; data: { id: number } }
  | { action: 'unitsUpdated'; data: Unit[] }
  | { action: 'alert'; data: { call: Call; distance: number; seconds: number; respondKey: string } }
  | { action: 'alertClear'; data: { id: number } };
