local config <const> = require 'config'
local officers <const> = require 'server.officers'
local access <const> = require 'server.access'
local records <const> = require 'server.records'
local licences <const> = require 'server.licences'
local warrants <const> = require 'server.warrants'
local cases <const> = require 'server.cases'
local jail <const> = require 'server.jail'
local dispatch <const> = require 'server.dispatch'
local units <const> = require 'server.units'
local clamps <const> = require 'server.clamps'
local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local STARTER_APARTMENTS <const> = require '@cobalt_core.config.shared'.starterApartment.locations

---@class MdtHandler
---@field fn fun(source: integer, data: table): any
---@field permission? PolicePermission
---@field ems? boolean

local OK <const> = { ok = true }

---@param message string
---@return { ok: false, error: string }
local function fail(message)
    return { ok = false, error = message }
end

local SEARCH_INTERVAL_MS <const> = 100

local SEARCH_MATCHES <const> = 8

---@type table<integer, integer>
local lastSearch <const> = {}

---@param source integer
---@return boolean
local function searchAllowed(source)
    local now <const> = GetGameTimer()

    if lastSearch[source] and now - lastSearch[source] < SEARCH_INTERVAL_MS then return false end

    lastSearch[source] = now

    return true
end

---@param value any
---@return string
local function escapeLike(value)
    return (tostring(value or ''):gsub('[\\%%_]', '\\%0'))
end

---@param value any
---@return string
local function likePattern(value)
    return ('%%%s%%'):format(escapeLike(value))
end

---@param value any
---@return string
local function prefixPattern(value)
    return escapeLike(value) .. '%'
end

---@param value any
---@return string?
local function text(value)
    return type(value) == 'string' and value or nil
end

local IMAGE_HOSTS <const> = config.mdt.imageHosts

local MAX_LICENCE_LOOKUPS <const> = 50

---@param value any
---@return string? url the link, or '' for no image; nil when the link isn't on an allowed host
local function imageUrl(value)
    local url <const> = text(value) or ''

    if url == '' then return '' end
    if #url > 512 then return end

    local host <const>, rest <const> = url:match('^https://([%w%.%-]+)(.*)$')

    if not host or (rest ~= '' and not rest:find('^[/?#]')) then return end

    if lib.table.contains(IMAGE_HOSTS, host:lower()) then
        return url
    end
end

---@return { ok: false, error: string }
local function imageRejected()
    if #IMAGE_HOSTS == 0 then
        return fail(locale('mdt.error.images_off'))
    end

    return fail(locale('mdt.error.image_host', table.concat(IMAGE_HOSTS, ', ')))
end

---@param name string
---@return string
local function departmentLabel(name)
    return officers.departmentText(name, 'label') or exports.cobalt_core:GetShared('Jobs', name)?.label or name
end

local VEHICLE_STATES <const> = { [0] = 'out', [1] = 'garaged', [2] = 'impounded' }

---@param row table
---@return table
local function vehicleSummary(row)
    local shared <const> = exports.cobalt_core:GetShared('Vehicles', row.vehicle)

    return {
        plate = row.plate,
        model = row.vehicle or '',
        label = shared and ('%s %s'):format(shared.brand or '', shared.name or ''):gsub('^%s+', '') or row.vehicle or '',
        owner = row.fullname or locale('mdt.unknown_person'),
        citizenid = row.citizenid,
        state = VEHICLE_STATES[row.state] or 'out',
        flagged = (row.flagged or 0) > 0,
        stolen = (row.stolen or 0) > 0,
    }
end

local VEHICLE_COLUMNS <const> = [[
    SELECT v.plate, v.vehicle, v.citizenid, v.state, p.fullname,
        (SELECT COUNT(*) FROM police_bolos b WHERE b.plate = v.plate AND b.status = 'active') AS flagged,
        (SELECT COUNT(*) FROM police_stolen_vehicles s WHERE s.plate = v.plate) AS stolen
]]
local VEHICLE_SELECT <const> = VEHICLE_COLUMNS .. ' FROM player_vehicles v LEFT JOIN players p ON p.citizenid = v.citizenid'
local VEHICLE_SEARCH <const> = VEHICLE_COLUMNS .. [[
    FROM (
        SELECT id FROM player_vehicles WHERE plate LIKE ?
        UNION SELECT id FROM player_vehicles WHERE vehicle LIKE ?
        UNION SELECT pv.id FROM players o JOIN player_vehicles pv ON pv.citizenid = o.citizenid
            WHERE o.fullname LIKE ? OR o.lastname LIKE ?
    ) m
    JOIN player_vehicles v ON v.id = m.id
    LEFT JOIN players p ON p.citizenid = v.citizenid
    ORDER BY v.plate LIMIT 30
]]
local VEHICLE_FLAGS <const> = [[
    SELECT plate, COUNT(CASE WHEN src = 'bolo' THEN 1 END) AS flagged,
        COUNT(CASE WHEN src = 'stolen' THEN 1 END) AS stolen
    FROM (
        SELECT plate, 'bolo' AS src FROM police_bolos WHERE status = 'active' AND plate IN (?)
        UNION ALL SELECT plate, 'stolen' FROM police_stolen_vehicles WHERE plate IN (?)
    ) f
    GROUP BY plate
]]

---@param a { plate: string }
---@param b { plate: string }
---@return boolean
local function byPlate(a, b)
    return a.plate < b.plate
end

---@param citizenid string
---@param owner string
---@return table[]
local function vehiclesOf(citizenid, owner)
    local rows <const> = exports.cobalt_core:GetVehiclesByCitizenId(citizenid, { 'plate', 'vehicle', 'state', 'citizenid' })
    local out <const> = {}

    if #rows == 0 then return out end

    local plates <const> = {}

    for i, row in ipairs(rows) do
        plates[i] = row.plate
    end

    local flags <const> = {}

    for _, flag in ipairs(MySQL.query.await(VEHICLE_FLAGS, { plates, plates }) or {}) do
        flags[flag.plate] = flag
    end

    table.sort(rows, byPlate)

    for i, row in ipairs(rows) do
        row.fullname = owner
        row.flagged = flags[row.plate]?.flagged
        row.stolen = flags[row.plate]?.stolen
        out[i] = vehicleSummary(row)
    end

    return out
end

---@param citizenids string[]
---@return table<string, table[]>
local function tagsFor(citizenids)
    local out <const> = {}

    if #citizenids == 0 then
        return out
    end

    local rows <const> = MySQL.query.await([[
        SELECT ct.citizenid, t.id, t.name, t.color FROM police_citizen_tags ct JOIN police_tags t ON t.id = ct.tag_id
        WHERE ct.citizenid IN (?) ORDER BY t.name
    ]], { citizenids }) or {}

    for _, row in ipairs(rows) do
        out[row.citizenid] = out[row.citizenid] or {}
        table.insert(out[row.citizenid], { id = row.id, name = row.name, color = row.color })
    end

    return out
end

---@param rows table[]
---@return table[]
local function citizenSummaries(rows)
    local ids <const> = {}

    for i, row in ipairs(rows) do
        ids[i] = row.citizenid
    end

    local tags <const> = tagsFor(ids)
    local wanted <const> = {}
    local convictions <const> = {}

    if #ids > 0 then
        local counts <const> = MySQL.query.await(
            'SELECT citizenid, COUNT(*) AS total FROM police_convictions WHERE citizenid IN (?) GROUP BY citizenid',
            { ids }
        ) or {}

        for _, row in ipairs(counts) do
            convictions[row.citizenid] = row.total
        end

        local active <const> = MySQL.query.await(
            "SELECT DISTINCT citizenid FROM police_warrants WHERE status = 'active' AND citizenid IN (?)",
            { ids }
        ) or {}

        for _, row in ipairs(active) do
            wanted[row.citizenid] = true
        end
    end

    local out <const> = {}

    for i, row in ipairs(rows) do
        local charinfo <const> = json.decode(row.charinfo or '{}') or {}

        out[i] = {
            citizenid = row.citizenid,
            name = row.fullname or locale('mdt.unknown_person'),
            dob = charinfo.birthdate or '',
            phone = row.phone_number or charinfo.phone or '',
            tags = tags[row.citizenid] or {},
            wanted = wanted[row.citizenid] == true,
            convictions = convictions[row.citizenid] or 0,
            online = officers.sourceOf(row.citizenid) ~= nil,
        }
    end

    return out
end

---@param query string
---@param limit integer
---@return table[]
local function findCitizenRows(query, limit)
    if type(query) ~= 'string' or #query < 2 then
        return {}
    end

    local pattern <const> = prefixPattern(query)

    return MySQL.query.await([[
        SELECT citizenid, charinfo, fullname, phone_number FROM players
        WHERE citizenid LIKE ? OR phone_number LIKE ? OR fullname LIKE ? OR lastname LIKE ?
        ORDER BY id DESC LIMIT ?
    ]], { pattern, pattern, pattern, pattern, limit }) or {}
end

---@param query string
---@param limit integer
---@return table[]
local function findCitizens(query, limit)
    return citizenSummaries(findCitizenRows(query, limit))
end

---@param query string
---@param limit? integer stop after this many matches; every match when nil
---@return table[]
local function findWeapons(query, limit)
    if type(query) ~= 'string' or #query < 2 then
        return {}
    end

    local out <const> = {}
    local holders <const> = {}

    for _, match in ipairs(exports.cobalt_inventory:FindItems('serial', query)) do
        if limit and #out >= limit then break end

        local item <const> = match.item
        local def <const> = exports.cobalt_inventory:GetItemDef(item.name)
        local holder = holders[match.source]

        if not holder then
            holder = { name = officers.name(match.source), citizenid = officers.citizenid(match.source) }
            holders[match.source] = holder
        end

        out[#out + 1] = {
            serial = item.metadata.serial,
            item = item.name,
            label = def?.label or item.name,
            owner = holder.name,
            citizenid = holder.citizenid,
            stolen = item.metadata.stolen == true,
        }
    end

    return out
end

local PROPERTY_MATCHES <const> = 10

---@param property { id: integer, name: string, shell?: string }
---@param citizenid? string
---@param owner? string
---@return table
local function propertyEntry(property, citizenid, owner)
    return {
        id = property.id,
        label = property.name,
        address = property.name,
        type = property.shell or '',
        owner = owner,
        citizenid = citizenid,
    }
end

---@param citizenid string
---@param owner string
---@return table[]
local function propertiesOf(citizenid, owner)
    local out <const> = {}

    for _, property in ipairs(exports.cobalt_housing:GetOwnedProperties(citizenid) or {}) do
        out[#out + 1] = propertyEntry(property, citizenid, owner)
    end

    return out
end

---@param query string
---@return table[]
local function findProperties(query)
    local out <const> = {}
    local seen <const> = {}

    ---@param entry table
    local function add(entry)
        if seen[entry.id] then return end

        seen[entry.id] = true
        out[#out + 1] = entry
    end

    for _, property in ipairs(exports.cobalt_housing:FindProperties(query, PROPERTY_MATCHES) or {}) do
        local owner <const> = property.owner

        add(propertyEntry(property, owner, owner and exports.cobalt_core:GetName(owner)))
    end

    for _, row in ipairs(findCitizenRows(query, PROPERTY_MATCHES)) do
        for _, property in ipairs(propertiesOf(row.citizenid, row.fullname or locale('mdt.unknown_person'))) do
            add(property)
        end
    end

    return out
end

---@param id? string metadata.starterApartment, a cobalt_core starter location id
---@return string?
local function starterLabel(id)
    for _, location in ipairs(STARTER_APARTMENTS) do
        if location.id == id then
            return location.label
        end
    end
end

---@param citizenid string
---@return table?
local function citizenProfile(citizenid)
    local row <const> = MySQL.single.await(
        'SELECT citizenid, charinfo, fullname, metadata, phone_number FROM players WHERE citizenid = ?',
        { citizenid }
    )

    if not row then return end

    local charinfo <const> = json.decode(row.charinfo or '{}') or {}
    local metadata = json.decode(row.metadata or '{}') or {}
    local source <const> = officers.sourceOf(citizenid)

    if source then
        metadata = officers.player(source).PlayerData.metadata
    end

    local profile <const> = citizenSummaries({ row })[1]
    local convictions <const> = records.convictions(citizenid)
    local licenceRecords <const> = exports.cobalt_core:GetLicenseRecords(citizenid) or {}
    local record <const> = {
        totalMonths = 0,
        totalFine = 0,
        points = licenceRecords[config.licences.pointsKey]?.points or 0,
        convictions = convictions,
    }

    for _, conviction in ipairs(convictions) do
        record.totalMonths += conviction.months
        record.totalFine += conviction.fine
    end

    local notes <const> = MySQL.single.await('SELECT notes, image FROM police_profiles WHERE citizenid = ?', { citizenid })
    local properties <const> = propertiesOf(citizenid, profile.name)
    local sentence <const> = jail.byCitizen(citizenid)
    local job <const> = exports.cobalt_management:GetAffiliations({ citizenid })[citizenid]?.job

    profile.sex = charinfo.gender == 1 and 'female' or 'male'
    profile.fingerprint = metadata.fingerprint or ''
    profile.bloodType = metadata.bloodtype or ''
    profile.job = job and ('%s, %s'):format(job.label or job.name, job.grade.name) or locale('mdt.unemployed')
    profile.address = properties[1]?.address or starterLabel(metadata.starterApartment) or ''
    profile.image = notes?.image or ''
    profile.notes = notes?.notes or ''
    profile.jailed = sentence and { releaseAt = sentence.releaseAt, months = sentence.months } or nil
    profile.licences = licences.list(citizenid, licenceRecords)
    profile.record = record
    profile.incidents = cases.forCitizen(citizenid)
    profile.vehicles = vehiclesOf(citizenid, profile.name)
    profile.weapons = {}
    profile.properties = properties
    profile.evidence = MySQL.query.await([[
        SELECT id, CONCAT(IF(type = 'forensic', 'FS-', 'EV-'), LPAD(id, 4, '0')) AS code, type, title, description, image, location,
            citizenid, incident_id AS incidentId, collected_by AS collectedBy, UNIX_TIMESTAMP(created_at) AS createdAt
        FROM police_evidence WHERE citizenid = ? ORDER BY created_at DESC LIMIT 50
    ]], { citizenid }) or {}
    profile.warrants = warrants.forCitizen(citizenid, true)

    if source then
        local own <const> = {}

        for _, item in pairs(exports.cobalt_inventory:GetPlayerItems(source) or {}) do
            if type(item.metadata?.serial) == 'string' then
                local def <const> = exports.cobalt_inventory:GetItemDef(item.name)

                own[#own + 1] = {
                    serial = item.metadata.serial,
                    item = item.name,
                    label = def?.label or item.name,
                    owner = profile.name,
                    citizenid = citizenid,
                    stolen = item.metadata.stolen == true,
                }
            end
        end

        profile.weapons = own
    end

    return profile
end

---@param source integer
---@return table
local function dashboard(source)
    local stats <const> = MySQL.single.await([[
        SELECT
            (SELECT COUNT(*) FROM police_warrants WHERE status = 'active') AS warrants,
            (SELECT COUNT(*) FROM police_warrants WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW() + INTERVAL ? HOUR) AS warrantsExpiring,
            (SELECT COUNT(*) FROM police_bolos WHERE status = 'active') AS bolos,
            (SELECT COUNT(*) FROM police_bolos WHERE status = 'active' AND type = 'vehicle') AS bolosVehicles,
            (SELECT COUNT(*) FROM police_bolos WHERE status = 'active' AND type = 'person') AS bolosPeople,
            (SELECT COUNT(*) FROM police_cases WHERE kind = 'incident' AND occurred_at >= NOW() - INTERVAL 7 DAY) AS incidentsWeek,
            (SELECT COUNT(*) FROM police_cases WHERE kind = 'report' AND occurred_at >= NOW() - INTERVAL 7 DAY) AS reportsWeek
    ]], { access.settings().records.warrantWarnHours })

    local onDuty <const> = officers.byJobTypes({ 'leo' }, true)
    local visible <const> = dispatch.visible(source)
    local onCalls <const> = {}

    for _, call in ipairs(visible) do
        if call.status == 'open' then
            for _, responder in ipairs(call.responders) do
                onCalls[responder.citizenid] = true
            end
        end
    end

    stats.unitsOnDuty = #onDuty
    stats.unitsOnCalls = 0

    for _ in pairs(onCalls) do
        stats.unitsOnCalls += 1
    end

    stats.unitsAvailable = math.max(stats.unitsOnDuty - stats.unitsOnCalls, 0)

    local department <const> = officers.job(source)?.name or 'police'
    local openCalls <const> = {}

    for _, call in ipairs(visible) do
        if call.status == 'open' and #openCalls < 5 then
            openCalls[#openCalls + 1] = call
        end
    end

    return {
        stats = stats,
        calls = openCalls,
        incidents = cases.recent(5),
        warrants = warrants.list('active'),
        bolos = warrants.bolos('active'),
        bulletins = MySQL.query.await([[
            SELECT id, title, body, pinned = 1 AS pinned, author, UNIX_TIMESTAMP(created_at) AS createdAt FROM police_bulletins
            WHERE department = ? ORDER BY pinned DESC, created_at DESC LIMIT 20
        ]], { department }) or {},
    }
end

---@param source integer
---@return boolean
local function canPostBulletin(source)
    local job <const> = officers.job(source)

    if not job or not access.can(source, 'postBulletins') then return false end

    return job.grade >= access.settings().records.bulletinMinGrade
end

---@param source integer
---@return string[]
local function rosterDepartments(source)
    if not officers.isLeo(source) then
        return { officers.job(source).name }
    end

    local names <const> = {}

    for name in pairs(config.departments) do
        names[#names + 1] = name
    end

    return names
end

---@param source integer
---@return table[]
local function roster(source)
    local employees <const> = {}

    for _, department in ipairs(rosterDepartments(source)) do
        local label <const> = departmentLabel(department)

        for _, employee in ipairs(exports.cobalt_management:GetEmployees(department, { summary = true })) do
            employee.department = department
            employee.departmentLabel = label
            employees[#employees + 1] = employee
        end
    end

    if #employees == 0 then
        return {}
    end

    local ids <const> = {}

    for i, employee in ipairs(employees) do
        ids[i] = employee.citizenid
    end

    local rows <const> = MySQL.query.await([[
        SELECT p.citizenid, JSON_VALUE(p.metadata, '$.callsign') AS callsign,
            (SELECT JSON_ARRAYAGG(oc.certificate_id) FROM police_officer_certificates oc WHERE oc.citizenid = p.citizenid) AS certificates
        FROM players p
        WHERE p.citizenid IN (?)
    ]], { ids }) or {}
    local extra <const> = {}

    for _, row in ipairs(rows) do
        extra[row.citizenid] = row
    end

    local out <const> = {}

    for _, employee in ipairs(employees) do
        local row <const> = extra[employee.citizenid] or {}
        local status <const> = employee.source and Player(employee.source).state.policeStatus
        local unit <const> = units.of(employee.citizenid)

        out[#out + 1] = {
            citizenid = employee.citizenid,
            name = employee.name,
            callsign = row.callsign ~= 'NO CALLSIGN' and row.callsign or '',
            department = employee.department,
            departmentLabel = employee.departmentLabel,
            grade = employee.grade,
            gradeName = employee.rank,
            unit = unit?.callsign,
            status = employee.onDuty and (unit?.status or status or 'available') or 'offduty',
            online = employee.online == true,
            certificates = row.certificates and json.decode(row.certificates) or {},
        }
    end

    table.sort(out, function(a, b)
        if a.grade ~= b.grade then
            return a.grade > b.grade
        end

        return a.name < b.name
    end)

    return out
end

---@return table[]
local function ranks()
    local out <const> = {}

    for name in pairs(config.departments) do
        local holders <const> = {}

        for _, employee in ipairs(exports.cobalt_management:GetEmployees(name, { summary = true })) do
            local level <const> = employee.grade
            holders[level] = (holders[level] or 0) + 1
        end

        local job <const> = exports.cobalt_core:GetShared('Jobs', name)
        local label <const> = departmentLabel(name)

        for level, grade in pairs(job?.grades or {}) do
            local gradeLevel <const> = tonumber(level) --[[@as integer]]

            out[#out + 1] = {
                department = name,
                departmentLabel = label,
                grade = gradeLevel,
                name = grade.name,
                isBoss = grade.isboss == true,
                holders = holders[gradeLevel] or 0,
                permissions = access.rankPermissions(name, gradeLevel),
            }
        end
    end

    table.sort(out, function(a, b)
        if a.department ~= b.department then
            return a.department < b.department
        end

        return a.grade > b.grade
    end)

    return out
end

---@param source integer
---@return table
local function officerUnitStatus(source)
    local unit <const> = units.of(officers.citizenid(source) or '')

    return unit?.status or Player(source).state.policeStatus or 'available'
end

---@param source integer
---@param id any the incident id the officer sent, nil for a new incident
---@return boolean
local function canEditIncident(source, id)
    if id == nil or access.can(source, 'editIncident') then return true end

    local author <const> = MySQL.scalar.await(
        "SELECT author_cid FROM police_cases WHERE id = ? AND status = 'draft'",
        { tonumber(id) }
    )

    return author ~= nil and author == officers.citizenid(source)
end

---@param source integer
---@param id any the call id the officer sent
---@return DispatchCall?
local function visibleCall(source, id)
    local call <const> = dispatch.get(tonumber(id) or 0)

    return call and dispatch.canSee(source, call) and call or nil
end

---@type table<string, MdtHandler>
local handlers <const> = {
    setStatus = {
        ems = true,
        fn = function(source, data)
            if not lib.table.contains({ 'available', 'busy', 'enroute', 'onscene' }, data.status) then
                return fail(locale('mdt.error.unknown_status'))
            end

            local unit <const> = units.of(officers.citizenid(source) or '')

            if unit then
                units.setStatus(unit.id, data.status)
            end

            Player(source).state:set('policeStatus', data.status, false)

            return OK
        end,
    },
    getDashboard = { ems = true, fn = dashboard },
    getCounts = {
        ems = true,
        fn = function()
            return MySQL.single.await([[
                SELECT
                    (SELECT COUNT(*) FROM police_warrants WHERE status = 'active') AS warrants,
                    (SELECT COUNT(*) FROM police_bolos WHERE status = 'active') AS bolos
            ]])
        end,
    },
    search = {
        fn = function(source, data)
            if not searchAllowed(source) then
                return { citizens = {}, vehicles = {}, weapons = {}, incidents = {} }
            end

            local query <const> = text(data.query) or ''
            local vehicles <const> = #query >= 2 and MySQL.query.await(
                VEHICLE_SELECT .. ' WHERE v.plate LIKE ? ORDER BY v.plate LIMIT ?',
                { prefixPattern(query), SEARCH_MATCHES }
            ) or {}
            local out <const> = {
                citizens = findCitizens(query, SEARCH_MATCHES),
                vehicles = {},
                weapons = findWeapons(query, SEARCH_MATCHES),
                incidents = cases.list(query, 'all', SEARCH_MATCHES),
            }

            for i, row in ipairs(vehicles) do
                out.vehicles[i] = vehicleSummary(row)
            end

            return out
        end,
    },

    postBulletin = {
        fn = function(source, data)
            if not canPostBulletin(source) then
                return fail(locale('mdt.error.cannot_post_bulletins'))
            end

            if not text(data.body) or data.body == '' then
                return fail(locale('mdt.error.bulletin_empty'))
            end

            MySQL.insert.await(
                'INSERT INTO police_bulletins (department, title, body, pinned, author) VALUES (?, ?, ?, ?, ?)',
                {
                    officers.job(source).name,
                    (text(data.title) or ''):sub(1, 255),
                    data.body:sub(1, 2000),
                    data.pinned == true,
                    officers.name(source),
                }
            )

            return OK
        end,
    },
    pinBulletin = {
        fn = function(source, data)
            if not canPostBulletin(source) then
                return fail(locale('mdt.error.cannot_pin_bulletins'))
            end

            local changed <const> = MySQL.update.await(
                'UPDATE police_bulletins SET pinned = ? WHERE id = ? AND department = ?',
                { data.pinned == true, tonumber(data.id), officers.job(source).name }
            )

            return changed == 1 and OK or fail(locale('mdt.error.bulletin_not_found'))
        end,
    },
    deleteBulletin = {
        fn = function(source, data)
            if not canPostBulletin(source) then
                return fail(locale('mdt.error.cannot_delete_bulletins'))
            end

            local deleted <const> = MySQL.update.await(
                'DELETE FROM police_bulletins WHERE id = ? AND department = ?',
                { tonumber(data.id), officers.job(source).name }
            )

            return deleted == 1 and OK or fail(locale('mdt.error.bulletin_not_found'))
        end,
    },

    searchCitizens = {
        ems = true,
        fn = function(source, data)
            if not searchAllowed(source) then return {} end

            return findCitizens(data.query, 30)
        end,
    },
    getCitizen = {
        ems = true,
        fn = function(_, data)
            return text(data.citizenid) and citizenProfile(data.citizenid)
        end,
    },
    saveCitizen = {
        permission = 'editProfile',
        fn = function(_, data)
            if not text(data.citizenid) then
                return fail(locale('mdt.error.unknown_citizen'))
            end

            local image <const> = imageUrl(data.image)

            if not image then
                return imageRejected()
            end

            MySQL.insert.await([[
                INSERT INTO police_profiles (citizenid, notes, image) SELECT citizenid, ?, ? FROM players WHERE citizenid = ?
                ON DUPLICATE KEY UPDATE notes = VALUES(notes), image = VALUES(image)
            ]], {
                (text(data.notes) or ''):sub(1, 4000),
                image,
                data.citizenid,
            })

            return OK
        end,
    },
    addCitizenTag = {
        permission = 'editProfile',
        fn = function(_, data)
            MySQL.insert.await(
                'INSERT IGNORE INTO police_citizen_tags (citizenid, tag_id) SELECT citizenid, ? FROM players WHERE citizenid = ?',
                { tonumber(data.tagId), text(data.citizenid) }
            )

            return OK
        end,
    },
    removeCitizenTag = {
        permission = 'editProfile',
        fn = function(_, data)
            MySQL.update.await(
                'DELETE FROM police_citizen_tags WHERE citizenid = ? AND tag_id = ?',
                { text(data.citizenid), tonumber(data.tagId) }
            )

            return OK
        end,
    },
    grantLicence = {
        fn = function(source, data)
            local citizenid <const>, key <const> = text(data.citizenid), text(data.key)

            if not citizenid or not key then
                return fail(locale('mdt.error.pick_licence'))
            end

            local ok <const>, reason <const> = licences.grant(source, citizenid, key)

            return ok and OK or fail(reason)
        end,
    },
    revokeLicence = {
        fn = function(source, data)
            local citizenid <const>, key <const> = text(data.citizenid), text(data.key)

            if not citizenid or not key then
                return fail(locale('mdt.error.pick_licence'))
            end

            local note <const> = (text(data.reason) or ''):sub(1, 255)
            local ok <const>, reason <const> = licences.revoke(source, citizenid, key, note)

            return ok and OK or fail(reason)
        end,
    },
    getLicences = {
        fn = function(_, data)
            local out <const> = {}

            for i, citizenid in ipairs(type(data.citizenids) == 'table' and data.citizenids or {}) do
                if i > MAX_LICENCE_LOOKUPS then break end

                if type(citizenid) == 'string' then
                    out[citizenid] = licences.list(citizenid)
                end
            end

            return out
        end,
    },

    searchVehicles = {
        fn = function(source, data)
            local query <const> = text(data.query) or ''

            if #query < 2 or not searchAllowed(source) then
                return {}
            end

            local pattern <const> = prefixPattern(query)
            local rows <const> = MySQL.query.await(VEHICLE_SEARCH, { pattern, pattern, pattern, pattern }) or {}

            local out <const> = {}

            for i, row in ipairs(rows) do
                out[i] = vehicleSummary(row)
            end

            return out
        end,
    },
    getVehicle = {
        fn = function(_, data)
            local row <const> = text(data.plate) and MySQL.single.await(VEHICLE_SELECT .. ' WHERE v.plate = ?', { data.plate })

            if not row then return end

            local vehicle <const> = vehicleSummary(row)

            vehicle.clamped = clamps.isClamped(row.plate)
            vehicle.bolos = warrants.activeBolos({ plate = row.plate })
            vehicle.incidents = cases.list(row.plate, 'all')
            vehicle.warrants = row.citizenid and warrants.forCitizen(row.citizenid, true) or {}

            return vehicle
        end,
    },
    setVehicleStolen = {
        permission = 'manageBolos',
        fn = function(source, data)
            local plate <const> = text(data.plate)

            if not plate or plate == '' then
                return fail(locale('mdt.error.unknown_plate'))
            end

            if data.stolen then
                MySQL.insert.await(
                    'INSERT IGNORE INTO police_stolen_vehicles (plate, reported_by) VALUES (?, ?)',
                    { plate:sub(1, 16), officers.name(source) }
                )
            else
                MySQL.update.await('DELETE FROM police_stolen_vehicles WHERE plate = ?', { plate })
            end

            return OK
        end,
    },
    waypointProperty = {
        fn = function(source, data)
            local property <const> = exports.cobalt_housing:GetProperty(tonumber(data.id) or 0)

            if not property then
                return fail(locale('mdt.error.property_not_found'))
            end

            TriggerClientEvent('cobalt_police:waypoint', source, property.door)

            return OK
        end,
    },
    searchWeapons = {
        fn = function(source, data)
            if not searchAllowed(source) then return {} end

            return findWeapons(data.query)
        end,
    },
    searchProperties = {
        fn = function(source, data)
            local query <const> = text(data.query)

            if not query or #query < 2 or not searchAllowed(source) then return {} end

            return findProperties(query)
        end,
    },

    getIncidents = {
        fn = function(source, data)
            if not searchAllowed(source) then return {} end

            local kind <const> = data.kind == 'report' and 'report' or data.kind == 'incident' and 'incident' or 'all'

            return cases.list(text(data.query) or '', kind)
        end,
    },
    getIncident = {
        fn = function(_, data)
            return tonumber(data.id) and cases.get(tonumber(data.id) --[[@as integer]])
        end,
    },
    saveIncident = {
        permission = 'createIncident',
        fn = function(source, data)
            if not canEditIncident(source, data.id) then
                return fail(locale('mdt.error.cannot_edit_incidents'))
            end

            local id <const>, err <const> = cases.save(source, data, 'draft')

            return id and { ok = true, id = id } or fail(err or locale('mdt.error.incident_not_saved'))
        end,
    },
    fileIncident = {
        permission = 'createIncident',
        fn = function(source, data)
            if not canEditIncident(source, data.id) then
                return fail(locale('mdt.error.cannot_edit_incidents'))
            end

            local id <const>, results <const> = cases.file(source, data)

            if not id then
                return fail(results --[[@as string]])
            end

            return { ok = true, id = id, sentences = results }
        end,
    },
    deleteIncident = {
        permission = 'deleteIncident',
        fn = function(_, data)
            return cases.delete(tonumber(data.id) or 0) and OK or fail(locale('mdt.error.incident_not_found'))
        end,
    },

    getWarrants = {
        fn = function(_, data)
            local status <const> = warrants.isStatus(data.status) and data.status or 'active'

            return {
                warrants = warrants.list(status),
                counts = warrants.counts(access.settings().records.warrantWarnHours),
            }
        end,
    },
    createWarrant = {
        permission = 'manageWarrants',
        fn = function(source, data)
            return warrants.create(data, officers.name(source)) and OK or fail(locale('mdt.error.warrant_incomplete'))
        end,
    },
    extendWarrant = {
        permission = 'manageWarrants',
        fn = function(_, data)
            if not warrants.extend(tonumber(data.id) or 0, data.days) then
                return fail(locale('mdt.error.warrant_not_extendable'))
            end

            return OK
        end,
    },
    setWarrantStatus = {
        permission = 'manageWarrants',
        fn = function(_, data)
            if not warrants.setStatus(tonumber(data.id) or 0, data.status) then
                return fail(locale('mdt.error.warrant_not_found'))
            end

            return OK
        end,
    },

    getBolos = {
        fn = function(_, data)
            return warrants.bolos(data.status or 'active')
        end,
    },
    createBolo = {
        permission = 'manageBolos',
        fn = function(source, data)
            local id <const> = warrants.createBolo(data, officers.name(source), officers.job(source).name)

            return id and OK or fail(locale('mdt.error.bolo_title'))
        end,
    },
    setBoloStatus = {
        permission = 'manageBolos',
        fn = function(_, data)
            if not warrants.setBoloStatus(tonumber(data.id) or 0, data.status) then
                return fail(locale('mdt.error.bolo_not_found'))
            end

            return OK
        end,
    },

    getEvidence = {
        fn = function(_, data)
            local evidenceType <const> = lib.table.contains({ 'photo', 'item', 'forensic' }, data.type) and data.type or 'all'
            local query <const> = text(data.query) or ''
            local pattern <const> = likePattern(query)
            local code <const> = tonumber(query:match('^%a%a%-?0*(%d+)$') or query) or 0

            return MySQL.query.await([[
                SELECT e.id, CONCAT(IF(e.type = 'forensic', 'FS-', 'EV-'), LPAD(e.id, 4, '0')) AS code, e.type, e.title, e.description,
                    e.image, e.location, e.citizenid,
                    p.fullname AS citizenName,
                    e.incident_id AS incidentId, e.collected_by AS collectedBy, UNIX_TIMESTAMP(e.created_at) AS createdAt
                FROM police_evidence e LEFT JOIN players p ON p.citizenid = e.citizenid
                WHERE (? = 'all' OR e.type = ?)
                    AND (e.title LIKE ? OR e.description LIKE ? OR e.citizenid LIKE ? OR p.fullname LIKE ? OR e.id = ? OR e.incident_id = ?)
                ORDER BY e.created_at DESC LIMIT 200
            ]], { evidenceType, evidenceType, pattern, pattern, pattern, pattern, code, tonumber(query) or 0 }) or {}
        end,
    },
    addEvidence = {
        fn = function(source, data)
            if not text(data.title) or data.title == '' then
                return fail(locale('mdt.error.evidence_title'))
            end

            local image <const> = imageUrl(data.image)

            if not image then
                return imageRejected()
            end

            MySQL.insert.await([[
                INSERT INTO police_evidence (type, title, description, image, location, citizenid, incident_id, collected_by)
                VALUES (?, ?, ?, ?, ?, (SELECT citizenid FROM players WHERE citizenid = ?), (SELECT id FROM police_cases WHERE id = ?), ?)
            ]], {
                lib.table.contains({ 'photo', 'item', 'forensic' }, data.type) and data.type or 'photo',
                data.title:sub(1, 255),
                text(data.description) or '',
                image,
                (text(data.location) or ''):sub(1, 255),
                text(data.citizenid),
                tonumber(data.incidentId),
                officers.name(source),
            })

            return OK
        end,
    },
    deleteEvidence = {
        permission = 'deleteEvidence',
        fn = function(_, data)
            local deleted <const> = MySQL.update.await('DELETE FROM police_evidence WHERE id = ?', { tonumber(data.id) }) == 1

            return deleted and OK or fail(locale('mdt.error.evidence_not_found'))
        end,
    },

    getCharges = { fn = records.charges },
    saveCharge = {
        permission = 'managePenalCode',
        fn = function(_, data)
            if not text(data.title) or data.title == '' then
                return fail(locale('mdt.error.charge_title'))
            end

            local class <const> = lib.table.contains({ 'felony', 'misdemeanor', 'infraction' }, data.class)
                and data.class
                or 'misdemeanor'
            local values <const> = {
                (text(data.category) or ''):sub(1, 100),
                (text(data.code) or ''):sub(1, 50),
                data.title:sub(1, 255),
                text(data.description) or '',
                class,
                math.max(0, math.floor(tonumber(data.months) or 0)),
                math.max(0, math.floor(tonumber(data.fine) or 0)),
                math.max(0, math.floor(tonumber(data.points) or 0)),
                data.stackable ~= false,
            }

            if tonumber(data.id) then
                values[#values + 1] = tonumber(data.id)

                MySQL.update.await([[
                    UPDATE police_charges
                    SET category = ?, code = ?, title = ?, description = ?, class = ?, months = ?, fine = ?, points = ?, stackable = ?
                    WHERE id = ?
                ]], values)
            else
                MySQL.insert.await([[
                    INSERT INTO police_charges (category, code, title, description, class, months, fine, points, stackable)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]], values)
            end

            return OK
        end,
    },
    deleteCharge = {
        permission = 'managePenalCode',
        fn = function(_, data)
            local deleted <const> = MySQL.update.await('DELETE FROM police_charges WHERE id = ?', { tonumber(data.id) }) == 1

            return deleted and OK or fail(locale('mdt.error.charge_not_found'))
        end,
    },

    getCalls = {
        ems = true,
        fn = function(source)
            return dispatch.visible(source)
        end,
    },
    respondCall = {
        ems = true,
        fn = function(source, data)
            local call <const> = visibleCall(source, data.id)

            if not call or not dispatch.respond(source, call.id) then
                return fail(locale('mdt.error.call_closed'))
            end

            local unit <const> = units.of(officers.citizenid(source) or '')

            if unit then
                units.setStatus(unit.id, 'enroute')
            end

            Player(source).state:set('policeStatus', 'enroute', false)

            if call.coords then
                TriggerClientEvent('cobalt_police:waypoint', source, call.coords)
            end

            return OK
        end,
    },
    leaveCall = {
        ems = true,
        fn = function(source, data)
            local call <const> = visibleCall(source, data.id)

            return call and dispatch.leave(source, call.id) and OK or fail(locale('mdt.error.not_on_call'))
        end,
    },
    waypointCall = {
        ems = true,
        fn = function(source, data)
            local coords <const> = visibleCall(source, data.id)?.coords

            if not coords then
                return fail(locale('mdt.error.call_no_location'))
            end

            TriggerClientEvent('cobalt_police:waypoint', source, coords)

            return OK
        end,
    },
    addCallNote = {
        ems = true,
        fn = function(source, data)
            if type(data.text) ~= 'string' or data.text == '' then
                return fail(locale('mdt.error.note_empty'))
            end

            local call <const> = visibleCall(source, data.id)
            local added <const> = call and dispatch.note(source, call.id, data.text, true)

            return added and OK or fail(locale('mdt.error.note_cooldown'))
        end,
    },
    assignCall = {
        fn = function(source, data)
            local call <const> = visibleCall(source, data.id)
            local unit <const> = call and units.get(tonumber(data.unitId) or 0)

            if not call or not unit or not dispatch.assign(call.id, unit.members) then
                return fail(locale('mdt.error.call_or_unit_gone'))
            end

            units.setStatus(unit.id, 'enroute')

            return OK
        end,
    },
    closeCall = {
        fn = function(source, data)
            local call <const> = visibleCall(source, data.id)

            return call and dispatch.close(call.id) and OK or fail(locale('mdt.error.call_already_closed'))
        end,
    },

    getUnits = { ems = true, fn = units.list },
    createUnit = {
        ems = true,
        fn = function(source, data)
            if not units.create(text(data.callsign) or '', officers.job(source).name, source) then
                return fail(locale('mdt.error.callsign_taken'))
            end

            return OK
        end,
    },
    joinUnit = {
        ems = true,
        fn = function(source, data)
            if not units.join(source, tonumber(data.id) or 0) then
                return fail(locale('mdt.error.unit_not_found'))
            end

            return OK
        end,
    },
    leaveUnit = {
        ems = true,
        fn = function(source)
            units.leave(source)

            return OK
        end,
    },
    deleteUnit = {
        fn = function(source, data)
            local unit <const> = units.get(tonumber(data.id) or 0)

            if not unit then
                return fail(locale('mdt.error.unit_not_found'))
            end

            local members <const> = unit.members

            if #members ~= 1 or members[1].citizenid ~= officers.citizenid(source) then
                return fail(locale('mdt.error.unit_has_members'))
            end

            units.leave(source)

            return OK
        end,
    },
    setUnitStatus = {
        ems = true,
        fn = function(source, data)
            local own <const> = units.of(officers.citizenid(source) or '')

            if not own or own.id ~= tonumber(data.id) then
                return fail(locale('mdt.error.not_your_unit'))
            end

            if not units.setStatus(own.id, data.status) then
                return fail(locale('mdt.error.unknown_status'))
            end

            return OK
        end,
    },

    getRoster = { ems = true, fn = roster },
    saveOfficer = {
        permission = 'manageRanks',
        fn = function(source, data)
            local citizenid <const> = text(data.citizenid)
            local callsign <const> = (text(data.callsign) or ''):upper()

            if not citizenid or #callsign > 16 then
                return fail(locale('mdt.error.callsign_length'))
            end

            local own <const> = officers.job(source) --[[@as PoliceJob]]
            local current <const> = exports.cobalt_management:GetAffiliations({ citizenid })[citizenid]?.job

            if not current or not config.departments[current.name] or current.name ~= own.name then
                return fail(locale('mdt.error.other_department'))
            end

            if citizenid ~= officers.citizenid(source) and not own.isBoss and current.grade.level >= own.grade then
                return fail(locale('mdt.error.officer_rank_too_high'))
            end

            local target <const> = officers.sourceOf(citizenid)
            local player <const> = target and officers.player(target) or Cobalt.Functions.GetOfflinePlayerByCitizenId(citizenid)

            if not player then
                return fail(locale('mdt.error.officer_not_found'))
            end

            player.Functions.SetMetaData('callsign', callsign)
            units.setCallsign(citizenid, callsign)

            if player.Offline then
                player.Functions.Save()
            end

            local grade <const> = math.floor(tonumber(data.grade) or -1)

            if grade < 0 or grade == current.grade.level then
                return OK
            end

            if not own.isBoss and grade >= own.grade then
                return fail(locale('mdt.error.grade_too_high'))
            end

            if not exports.cobalt_core:GetShared('Jobs', current.name)?.grades?[tostring(grade)] then
                return fail(locale('mdt.error.grade_missing'))
            end

            local moved <const>, err <const> = exports.cobalt_management:SetGrade(citizenid, current.name, grade)

            if not moved then
                return fail(err or locale('mdt.error.grade_failed'))
            end

            return OK
        end,
    },
    grantCertificate = {
        permission = 'manageCertificates',
        fn = function(_, data)
            MySQL.insert.await([[
                INSERT IGNORE INTO police_officer_certificates (citizenid, certificate_id)
                SELECT p.citizenid, c.id FROM players p JOIN police_certificates c ON c.id = ? WHERE p.citizenid = ?
            ]], { tonumber(data.certificateId), text(data.citizenid) })

            return OK
        end,
    },
    revokeCertificate = {
        permission = 'manageCertificates',
        fn = function(_, data)
            MySQL.update.await('DELETE FROM police_officer_certificates WHERE citizenid = ? AND certificate_id = ?', {
                text(data.citizenid),
                tonumber(data.certificateId),
            })

            return OK
        end,
    },

    getRanks = { permission = 'manageRanks', fn = ranks },
    saveRank = {
        permission = 'manageRanks',
        fn = function(source, data)
            local grade <const> = math.tointeger(tonumber(data.grade))

            if not config.departments[data.department] or not grade or type(data.permissions) ~= 'table' then
                return fail(locale('mdt.error.unknown_rank'))
            end

            local own <const> = officers.job(source) --[[@as PoliceJob]]

            if data.department ~= own.name or (not own.isBoss and grade >= own.grade) then
                return fail(locale('mdt.error.rank_out_of_reach'))
            end

            local held <const> = access.permissions(source)
            local permissions <const> = {}

            for _, key in ipairs(access.permissionKeys) do
                permissions[key] = data.permissions[key] == true and held[key] == true
            end

            access.saveRankPermissions(data.department, grade, permissions)

            return OK
        end,
    },
    getTags = {
        fn = function()
            return MySQL.query.await([[
                SELECT t.id, t.name, t.color, (SELECT COUNT(*) FROM police_citizen_tags ct WHERE ct.tag_id = t.id) AS holders
                FROM police_tags t ORDER BY t.name LIMIT 500
            ]]) or {}
        end,
    },
    saveTag = {
        permission = 'manageTags',
        fn = function(_, data)
            local name <const> = text(data.name)
            local color = text(data.color)

            if not name or name == '' then
                return fail(locale('mdt.error.tag_name'))
            end

            if not color or not color:match('^#%x%x%x%x%x%x$') then
                color = '#3F3F46'
            end

            if tonumber(data.id) then
                MySQL.update.await(
                    'UPDATE police_tags SET name = ?, color = ? WHERE id = ?',
                    { name:sub(1, 100), color, tonumber(data.id) }
                )
            else
                MySQL.insert.await(
                    'INSERT IGNORE INTO police_tags (name, color) VALUES (?, ?)',
                    { name:sub(1, 100), color }
                )
            end

            return OK
        end,
    },
    deleteTag = {
        permission = 'manageTags',
        fn = function(_, data)
            MySQL.update.await('DELETE FROM police_tags WHERE id = ?', { tonumber(data.id) })

            return OK
        end,
    },
    getCertificates = {
        ems = true,
        fn = function()
            local rows <const> = MySQL.query.await([[
                SELECT c.id, c.name, c.department,
                    (SELECT COUNT(*) FROM police_officer_certificates oc WHERE oc.certificate_id = c.id) AS holders
                FROM police_certificates c ORDER BY c.name LIMIT 500
            ]]) or {}

            for _, row in ipairs(rows) do
                row.departmentLabel = departmentLabel(row.department)
            end

            return rows
        end,
    },
    saveCertificate = {
        permission = 'manageCertificates',
        fn = function(source, data)
            local name <const> = text(data.name)

            if not name or name == '' then
                return fail(locale('mdt.error.certificate_name'))
            end

            local department <const> = config.departments[data.department] and data.department or officers.job(source).name

            if tonumber(data.id) then
                MySQL.update.await(
                    'UPDATE police_certificates SET name = ?, department = ? WHERE id = ?',
                    { name:sub(1, 100), department, tonumber(data.id) }
                )
            else
                MySQL.insert.await(
                    'INSERT IGNORE INTO police_certificates (name, department) VALUES (?, ?)',
                    { name:sub(1, 100), department }
                )
            end

            return OK
        end,
    },
    deleteCertificate = {
        permission = 'manageCertificates',
        fn = function(_, data)
            MySQL.update.await('DELETE FROM police_certificates WHERE id = ?', { tonumber(data.id) })

            return OK
        end,
    },
    getTemplates = {
        fn = function()
            return MySQL.query.await('SELECT id, kind, name, content FROM police_templates ORDER BY name LIMIT 500') or {}
        end,
    },
    saveTemplate = {
        permission = 'manageTemplates',
        fn = function(_, data)
            local name <const> = text(data.name)

            if not name or name == '' then
                return fail(locale('mdt.error.template_name'))
            end

            local kind <const> = data.kind == 'report' and 'report' or 'incident'

            if tonumber(data.id) then
                MySQL.update.await('UPDATE police_templates SET kind = ?, name = ?, content = ? WHERE id = ?', {
                    kind,
                    name:sub(1, 100),
                    text(data.content) or '',
                    tonumber(data.id),
                })
            else
                MySQL.insert.await(
                    'INSERT INTO police_templates (kind, name, content) VALUES (?, ?, ?)',
                    { kind, name:sub(1, 100), text(data.content) or '' }
                )
            end

            return OK
        end,
    },
    deleteTemplate = {
        permission = 'manageTemplates',
        fn = function(_, data)
            MySQL.update.await('DELETE FROM police_templates WHERE id = ?', { tonumber(data.id) })

            return OK
        end,
    },
    getSettings = { ems = true, fn = access.settings },
    saveSettings = {
        permission = 'administrator',
        fn = function(_, data)
            if type(data) ~= 'table' then
                return fail(locale('mdt.error.invalid_settings'))
            end

            access.saveSettings(data)

            return OK
        end,
    },
}

lib.callback.register('cobalt_police:mdt', function(source, name, data)
    local handler <const> = handlers[name]

    if not handler or not access.canOpen(source) then return end

    if not officers.isLeo(source) and not handler.ems then
        return fail(locale('mdt.error.ems_unavailable'))
    end

    if not officers.job(source)?.onDuty then
        return fail(locale('mdt.clock_in'))
    end

    if handler.permission and not access.can(source, handler.permission) then
        return fail(locale('mdt.error.rank_denied'))
    end

    return handler.fn(source, type(data) == 'table' and data or {})
end)

---@param source integer
---@return table?
local function session(source)
    if not access.canOpen(source) then return end

    local job <const> = officers.job(source) --[[@as PoliceJob]]

    if not job.onDuty then return end

    Player(source).state:set('mdtTablet', true, true)

    return {
        officer = {
            citizenid = officers.citizenid(source),
            name = officers.name(source),
            callsign = officers.callsign(source),
            gradeName = job.gradeName,
            department = {
                name = job.name,
                label = officers.departmentText(job.name, 'label') or job.label or job.name,
                subtitle = officers.departmentText(job.name, 'subtitle') or locale('mdt.default_subtitle'),
            },
            isEms = not officers.isLeo(source),
            status = officerUnitStatus(source),
            permissions = access.permissions(source),
            canManageLicences = licences.canManage(source),
            pages = access.pages(source),
        },
        settings = access.settings(),
        keybinds = { respond = config.dispatch.respondKey, panic = config.dispatch.panicKey },
    }
end

lib.callback.register('cobalt_police:openMdt', session)

exports('UseMdt', function(event, _, inventory)
    if event ~= 'usedItem' then return end

    local source <const> = inventory.source
    local emsOnly <const> = not officers.isLeo(source) and officers.isEms(source)

    if emsOnly and GetResourceState('cobalt_ambulancejob') == 'started' then
        return TriggerClientEvent('cobalt_ambulancejob:client:openMdt', source)
    end

    TriggerClientEvent('cobalt_police:openMdt', source)
end)

---@param source integer
local function putTabletAway(source)
    local state <const> = Player(source).state

    if state.mdtTablet then
        state:set('mdtTablet', nil, true)
    end
end

RegisterNetEvent('cobalt_police:mdtClosed', function()
    putTabletAway(source)
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', putTabletAway)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, playerId in ipairs(GetPlayers()) do
        putTabletAway(tonumber(playerId) --[[@as integer]])
    end
end)

AddEventHandler('playerDropped', function()
    lastSearch[source] = nil
end)
