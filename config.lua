return {
    -- Police departments: job names set to true; any job of type leo also counts as police.
    -- Each one's MDT name and subtitle are departments.<job name>.label and .subtitle in locales/en.json
    departments = {
        police = true,
        sheriff = true,
    },

    -- Jobs that get the EMS view of the MDT, and the pages they can open
    emsJobs = { ambulance = true }, -- job names that open the MDT in its EMS view
    emsPages = { 'dashboard', 'dispatch', 'citizens', 'roster' }, -- MDT pages the EMS view shows

    -- MDT tablet
    mdt = {
        command = 'mdt', -- chat command that opens it
        imageHosts = { 'cdn.fivemesh.io' }, -- https hosts that mugshot and evidence photo links may use, lowercase and matched exactly; cdn.fivemesh.io holds cobalt_core's phone uploads; empty turns image links off
        tablet = { -- animation and prop while it is open
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', -- animation dictionary
            clip = 'base', -- animation clip
            flag = 49, -- animation flag; 49 loops on the upper body so the player can walk
            prop = {
                model = `prop_cs_tablet`, -- prop model
                bone = 60309, -- ped bone id the prop attaches to
                offset = vec3(0.03, 0.002, -0.0), -- attach offset in meters
                rotation = vec3(10.0, 160.0, 0.0), -- attach rotation in degrees
            },
        },
    },

    -- Restraints: item used, prop on the wrists, whether the item is used up, skill checks to break out,
    -- and how others free the player (a lockpick item with its skill check, or a cutter item)
    cuffTypes = {
        cuffs = {
            item = 'handcuffs', -- cobalt_inventory item that applies this restraint
            prop = `p_cs_cuffs_02_s`, -- prop attached to the wrists
            consume = false, -- true uses up the item on each restraint; false keeps it with the officer, who only needs to carry one
            breakout = { 'medium', 'hard', 'hard' }, -- skill check stages a resisting player must pass to break free
            escapeChance = 0.5, -- 0 to 1: chance the server lets a passed breakout or resist skill check free the player
            lockpick = { item = 'advancedlockpick', difficulty = { 'hard', 'hard', 'hard' }, chance = 0.65 }, -- lets non-police pick them: item used up on success, its skill check stages, and the 0 to 1 chance a passed check opens the lock
        },
        zipties = {
            item = 'zipties',
            prop = `prop_cs_ziptie_01`,
            consume = true,
            breakout = { 'easy', 'medium', 'medium' },
            escapeChance = 0.75,
            cutter = 'ziptie_cutter', -- item that lets anyone cut them off; whoever tied them can always remove them
        },
    },

    cuffRange = 3.0, -- meters from the target to cuff, uncuff, search or escort
    breakoutCooldown = 30, -- seconds between breakout attempts

    -- Animations for cuffing, being cuffed and walking cuffed
    anims = {
        cuffer = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_left' }, -- the officer while cuffing
        uncuff = { dict = 'mp_arresting', clip = 'a_uncuff' }, -- the officer while removing restraints
        cuffed = { dict = 'mp_arresting', clip = 'idle' }, -- the cuffed player standing still
        walk = { dict = 'anim@move_m@prisoner_cuffed', clip = 'walk' }, -- the cuffed player walking while escorted
        run = { dict = 'anim@move_m@prisoner_cuffed_rc', clip = 'run' }, -- the cuffed player when the escort runs
        handsUp = { dict = 'random@mugging3', clip = 'handsup_standing_base' }, -- a player with hands raised by the hands up key
        paired = { -- the player being cuffed, held against the officer
            duration = 3500, -- milliseconds
            dict = 'mp_arrest_paired', -- animation dictionary
            clip = 'crook_p2_back_left', -- animation clip
            bone = 11816, -- officer bone the player is held against
            offset = vec3(-0.1, 0.45, 0.0), -- offset from that bone in meters
            rotation = vec3(0.0, 0.0, 20.0), -- rotation in degrees
        },
        prop = { -- where the restraint prop sits on the wrists
            bone = 0x49D9, -- ped bone id
            offset = vec3(0.0, 0.07, 0.03), -- offset in meters
            rotation = vec3(10.0, 115.0, -65.0), -- rotation in degrees
        },
    },

    -- Escorting a cuffed player
    escort = {
        bone = 11816, -- officer bone the escorted player is attached to
        offset = vec3(0.38, 0.4, 0.0), -- offset from that bone in meters
        maxDistance = 10.0, -- meters apart before the escort breaks
        vehicleRange = 6.0, -- meters from a vehicle to put the escorted player in it
    },

    -- GTA control ids blocked while cuffed (attack, aim, enter vehicle, weapon wheel and more)
    disabledControls = { 24, 25, 26, 37, 47, 69, 73, 75, 92, 114, 140, 141, 142, 257, 263, 264 },

    -- Armory restocks, keyed by a stash id from cobalt_inventory data/stashes.lua, which sets where the armory is,
    -- its size and the grades that open it; opening the armory tops each item back up to its amount
    armories = {
        lspd_mission_row_armory = {
            refillCooldown = 1800, -- seconds between restocks
            items = { -- items kept in stock: item name and the amount it refills to
                { name = 'weapon_pistol', amount = 1 },
                { name = 'pistol_ammo', amount = 60 },
                { name = 'handcuffs', amount = 2 },
                { name = 'radio', amount = 1 },
                { name = 'armor', amount = 1 },
                { name = 'bandage', amount = 5 },
            },
        },
    },

    -- Stations: blip, wardrobe point, boss menu and vehicle garage; lockers and armories are stashes in cobalt_inventory data/stashes.lua
    stations = {
        {
            id = 'mission_row', -- unique station id; the blip name is station.blip.<id> in locales/en.json
            blip = { sprite = 60, colour = 29, scale = 1.0 }, -- map blip sprite, colour and size
            coords = vec3(425.13, -979.55, 30.71), -- blip position
            wardrobe = vec3(461.74, -998.86, 30.69), -- where officers change into uniform
            bossMenu = vec3(447.53, -974.07, 30.47), -- where the boss opens the department menu; leave out for none
            garage = {
                coords = vec3(454.63, -1017.36, 28.43), -- where officers open the garage
                spawn = vec4(438.35, -1018.29, 27.69, 90.0), -- where the vehicle appears, with heading
                vehicles = { 'police', 'police2', 'police3', 'policet' }, -- model names on offer; each menu label is station.vehicle.<model> in locales/en.json
            },
        },
    },

    -- Wheel clamps
    clamp = {
        item = 'clamp_kit', -- item used to place a clamp
        placeMs = 3000, -- milliseconds to place
        removeMs = 2000, -- milliseconds to remove
        range = 4.0, -- meters from the wheel
        refund = true, -- give the clamp kit back on removal when the officer has room
        prop = {
            model = `prop_clamp`, -- prop model
            bone = 'wheel_lf', -- vehicle bone the clamp attaches to
            offset = vec3(-0.10, 0.15, -0.30), -- attach offset in meters
            rotation = vec3(180.0, 200.0, 90.0), -- attach rotation in degrees
        },
    },

    -- Scene tape
    tape = {
        item = 'tape_kit', -- item used to lay tape
        segmentLength = 0.423, -- meters per tape prop
        maxLength = 21.0, -- longest single run, in meters
        range = 25.0, -- meters from the officer each end can be placed
        maxActive = 30, -- most tapes up across the map at once; officers can't place more until one comes down
        lifetime = 60, -- minutes a tape stays up before it comes down on its own; a restart clears every tape
        drawDistance = 100.0, -- meters from a tape's middle at which players see it
        types = { -- styles to pick from and the prop each one uses; each name is tape.type.<style> in locales/en.json
            police = `p_clothtarp_s`,
            fire = `prop_fire_tape`,
            cordon = `prop_cordon_tape`,
        },
    },

    -- Bolingbroke jail
    jail = {
        secondsPerMonth = 60, -- real seconds served per sentenced month
        spawn = vec4(1661.05, 2524.68, 45.56, 260.0), -- where inmates are placed
        release = vec4(1848.13, 2586.05, 45.67, 270.0), -- where they walk out
        zone = { coords = vec3(1690.0, 2550.0, 45.6), radius = 175.0 }, -- leaving this circle sends the inmate back
        confiscate = true, -- take the inmate's pockets on entry and return them on release
        jobs = { -- prison jobs: id (its name is jail.task.<id> in locales/en.json), where inmates do it and the seconds it takes
            { id = 'electrics', coords = vec3(1761.46, 2540.41, 45.56), seconds = 30 },
            { id = 'yard', coords = vec3(1718.54, 2527.80, 45.56), seconds = 30 },
            { id = 'block', coords = vec3(1700.12, 2474.82, 45.56), seconds = 30 },
        },
        jobReduction = 30, -- seconds taken off the sentence per finished job
    },

    -- Licences on the MDT
    licences = {
        grantGrade = 2, -- lowest grade (or any boss) that can grant and revoke licences
        pointsKey = 'driver', -- licence that carries points; matches cobalt_core config/shared.lua licenses
    },

    -- Dispatch
    dispatch = {
        maxCalls = 50, -- calls kept before the oldest drop
        maxNotes = 30, -- notes kept on a call before the oldest drop
        noteCooldown = 2, -- seconds between notes a responder types in the MDT; system notes skip it
        respondKey = 'E', -- default key to respond to the latest call
        panicKey = 'O', -- default key for the officer panic button
        offsetRadius = 120, -- meters an auto alert's blip can land from the real spot
        blipMinutes = 2, -- minutes a call blip stays on the map
        silentWeapons = { -- weapons that never raise a shooting alert
            `WEAPON_GRENADE`, `WEAPON_BZGAS`, `WEAPON_MOLOTOV`, `WEAPON_STICKYBOMB`, `WEAPON_PROXMINE`,
            `WEAPON_SNOWBALL`, `WEAPON_PIPEBOMB`, `WEAPON_BALL`, `WEAPON_SMOKEGRENADE`, `WEAPON_FLARE`,
            `WEAPON_PETROLCAN`, `WEAPON_FIREEXTINGUISHER`, `WEAPON_HAZARDCAN`, `WEAPON_STUNGUN`,
        },
        huntingZones = { -- shooting inside these raises a hunting call instead of shots fired
            { coords = vec3(-938.61, 4823.99, 313.92), radius = 650.0 },
        },
        quietZones = { -- shooting inside these raises nothing (the Ammu-Nation ranges)
            { coords = vec3(13.53, -1097.92, 29.8), radius = 8.0 },
            { coords = vec3(821.96, -2163.09, 29.62), radius = 8.0 },
        },
        blips = { -- blip style per call type: sprite, colour, scale, optional radius in meters, flash, offset, and a frontend sound
            default = { -- used by call types without their own entry
                sprite = 161, -- blip sprite id
                colour = 1, -- blip colour id
                scale = 1.2, -- blip size
                sound = 'Lose_1st', -- frontend sound played when the call arrives
                soundSet = 'GTAO_FM_Events_Soundset', -- sound set the sound belongs to
            },
            panic = {
                sprite = 526,
                colour = 1,
                scale = 1.5,
                radius = 15.0, -- meters of the radius circle drawn around the call
                flash = true, -- the blip flashes
                sound = 'TIMER_STOP',
                soundSet = 'HUD_MINI_GAME_SOUNDSET',
            },
            robbery = {
                sprite = 500,
                colour = 5,
                scale = 1.4,
                sound = 'ROBBERY_MONEY_TOTAL',
                soundSet = 'HUD_FRONTEND_CUSTOM_SOUNDSET',
            },
            shooting = {
                sprite = 110,
                colour = 1,
                scale = 1.4,
                sound = 'Lose_1st',
                soundSet = 'GTAO_FM_Events_Soundset',
            },
            vehicle = {
                sprite = 595,
                colour = 60,
                scale = 1.3,
                sound = 'Lose_1st',
                soundSet = 'GTAO_FM_Events_Soundset',
            },
            medical = {
                sprite = 126,
                colour = 3,
                scale = 1.3,
                sound = 'SELECT',
                soundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
            },
            call = { sprite = 480, colour = 1, scale = 1.3, sound = 'Lose_1st', soundSet = 'GTAO_FM_Events_Soundset' },
            explosion = {
                sprite = 436,
                colour = 1,
                scale = 1.4,
                radius = 75.0,
                offset = true,
                sound = 'Lose_1st',
                soundSet = 'GTAO_FM_Events_Soundset',
            },
        },
    },

    -- Defaults for the settings bosses change on the MDT (saved settings override these)
    defaultSettings = {
        dispatch = {
            onDutyOnly = true, -- only on-duty officers get calls
            phoneRequired = true, -- 911 and 311 calls need a phone in the caller's inventory
            popupSeconds = 8, -- seconds a call popup stays on screen
            autoAlerts = { -- automatic alerts raised by what witnesses see
                shooting = true,
                vehicleTheft = true,
                fight = true,
                playerDown = true,
                explosion = true,
                speeding = false,
            },
        },
        records = {
            warrantWarnHours = 48, -- hours before a warrant expires that it is flagged
            bulletinMinGrade = 0, -- lowest grade that can post bulletins
            emsAccess = true, -- EMS can read citizen records
        },
    },
}
