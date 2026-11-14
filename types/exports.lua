---@meta

---@alias PoliceCuffType 'cuffs'|'zipties'
---@alias PoliceChargeClass 'felony'|'misdemeanor'|'infraction'
---@alias PoliceDispatchJob 'leo'|'ems'
---@alias PoliceWarrantType 'arrest'|'search'|'bench'
---@alias PoliceBlip 'default'|'panic'|'robbery'|'shooting'|'vehicle'|'medical'|'call'|'explosion'
---@alias PoliceMdtPage 'dashboard'|'dispatch'|'citizens'|'vehicles'|'weapons'|'properties'|'incidents'|'warrants'|'bolos'|'evidence'|'penalcode'|'roster'|'management'

---@class PoliceCuffState
---@field type PoliceCuffType
---@field by string citizenid of whoever applied them, or a label such as 'admin'

---@class PoliceConviction
---@field id integer
---@field title string
---@field code string
---@field class PoliceChargeClass
---@field counts integer
---@field months integer
---@field fine integer
---@field points integer
---@field incidentId? integer
---@field createdAt integer epoch seconds

---@class PoliceRecordEntry
---@field title string
---@field code? string
---@field class? PoliceChargeClass
---@field counts? integer
---@field months? integer
---@field fine? integer
---@field points? integer
---@field chargeId? integer penal code id
---@field incidentId? integer

---@class PoliceWarrant
---@field id integer
---@field citizenid string
---@field name string
---@field type PoliceWarrantType
---@field title string
---@field description string
---@field status 'active'|'served'|'cancelled'|'expired'
---@field issuedBy string
---@field expiresAt? integer epoch seconds
---@field incidentId? integer the MDT incident the warrant comes from
---@field createdAt integer epoch seconds

---@class PoliceBolo
---@field id integer
---@field type 'person'|'vehicle'
---@field department string
---@field title string
---@field description string
---@field citizenid? string
---@field plate? string
---@field personName string
---@field lastSeen string
---@field status 'active'|'cancelled'
---@field issuedBy string
---@field createdAt integer epoch seconds

---@class PoliceDispatchInput
---@field title string
---@field code? string defaults to '10-80'
---@field description? string
---@field location? string street and area; clients fill it from coords when empty
---@field coords? vector3
---@field priority? 1|2|3 1 is the most urgent, defaults to 2
---@field jobs? PoliceDispatchJob[] defaults to { 'leo' }
---@field blip? PoliceBlip
---@field caller? { name: string, number: string }
---@field raisedBy? string

---@class PoliceCallResponder
---@field citizenid string
---@field name string
---@field callsign string

---@class PoliceCall
---@field id integer
---@field code string
---@field title string
---@field description string
---@field location string
---@field plate? string
---@field coords? vector3
---@field priority 1|2|3
---@field jobs PoliceDispatchJob[]
---@field blip string
---@field caller? { name: string, number: string }
---@field raisedBy? string
---@field responders PoliceCallResponder[]
---@field notes { author: string, text: string, time: integer }[]
---@field status 'open'|'closed'
---@field createdAt integer epoch seconds

---@class CobaltPoliceExports
local CobaltPoliceExports = {}

---**Server.** True when the player is cuffed or zip-tied.
---@param source integer
---@return boolean
function CobaltPoliceExports:IsCuffed(source) end

---**Server.** Restrains a player with no item, range or job check. False when they are already restrained.
---@param target integer
---@param cuffType? PoliceCuffType defaults to 'cuffs'
---@param by? string recorded as whoever applied them
---@return boolean
function CobaltPoliceExports:Cuff(target, cuffType, by) end

---**Server.** Removes restraints with no checks and no item returned. False when the player wasn't restrained.
---@param target integer
---@return boolean
function CobaltPoliceExports:Uncuff(target) end

---**Server.** Sends a call to on-duty police or EMS and returns its id. Fires `cobalt_police:dispatchSent`.
---@param data PoliceDispatchInput
---@return integer?
function CobaltPoliceExports:SendDispatch(data) end

---**Server.** Calls the player can see: police calls for officers, EMS calls for EMS, newest first, open and closed.
---@param source integer
---@return PoliceCall[]
function CobaltPoliceExports:GetCalls(source) end

---**Server.** One call by id, open or closed.
---@param id integer
---@return PoliceCall?
function CobaltPoliceExports:GetCall(id) end

---**Server.** Adds the player to an open call's responders. Fires `cobalt_police:callResponded`.
---@param source integer
---@param id integer
---@return boolean
function CobaltPoliceExports:RespondToCall(source, id) end

---**Server.** Adds responders to an open call, skipping ones already on it.
---@param id integer
---@param members PoliceCallResponder[]
---@return boolean
function CobaltPoliceExports:AssignToCall(id, members) end

---**Server.** Takes the player off a call's responders.
---@param source integer
---@param id integer
---@return boolean
function CobaltPoliceExports:LeaveCall(source, id) end

---**Server.** Adds a note to a call, signed with the player's name. Pass `typed` for a note the player wrote, so the note cooldown applies; system notes leave it out.
---@param source integer
---@param id integer
---@param text string
---@param typed? boolean
---@return boolean
function CobaltPoliceExports:AddCallNote(source, id, text, typed) end

---**Server.** Closes a call. False when it is already closed.
---@param id integer
---@return boolean
function CobaltPoliceExports:CloseCall(id) end

---**Server.** The `mdt_tablet` item's server export. On `usedItem` it opens the police MDT, or cobalt_ambulancejob's for EMS without police access.
---@param event 'usingItem' | 'usedItem'
---@param item table
---@param inventory { id: string, source: integer }
function CobaltPoliceExports:UseMdt(event, item, inventory) end

---**Server.** The `tape_kit` item's server export. On `usedItem` it starts placing police tape when the player may.
---@param event 'usingItem' | 'usedItem'
---@param item table
---@param inventory { id: string, source: integer }
function CobaltPoliceExports:UseTape(event, item, inventory) end

---**Server.** Opens the MDT for a player with access, optionally on a page or citizen profile.
---@param source integer
---@param page? PoliceMdtPage
---@param citizenid? string
function CobaltPoliceExports:OpenMdt(source, page, citizenid) end

exports.cobalt_police = CobaltPoliceExports
