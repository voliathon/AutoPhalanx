_addon.name = 'AutoPhalanx'
_addon.author = 'Voliathon'
_addon.version = '1.0.6 Fixed'
_addon.commands = {'ap', 'autophalanx'}

local packets = require('packets')
local res = require('resources')

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local phalanx_command = 'gs equip sets.Phalanx'
local debug_mode = true -- Set to false once you are happy it works

-- ============================================================================
-- VALID IDS
-- ============================================================================
local ids = {
    ACCESSIO = 218,    -- Accession JA
    PHALANX_1 = 106,   -- Standard Phalanx I
    PHALANX_2 = 107,   -- Standard Phalanx II
    PHALANX_X = 24931  -- The Mystery ID you discovered
}

local accession_users = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
local function log(msg)
    if debug_mode then
        windower.add_to_chat(207, '[AP-Debug] ' .. msg)
    end
end

local function get_distance_to_entity(target_id)
    local target = windower.ffxi.get_mob_by_id(target_id)
    if target then
        return math.sqrt(target.distance)
    end
    return 999
end

-- ============================================================================
-- MAIN EVENT LOOP
-- ============================================================================
windower.register_event('incoming chunk', function(id, data)
    if id == 0x28 then
        local packet = packets.parse('incoming', data)
        local actor_id = packet['Actor']
        local category = packet['Category']
        local param = packet['Param']
        local player = windower.ffxi.get_player()

        -- 1. DETECT ACCESSION
        if category == 6 and param == ids.ACCESSIO then
            log('Accession used by Actor '..actor_id)
            accession_users[actor_id] = os.time() + 60
        end

        -- 2. DETECT PHALANX (Standard IDs OR The Mystery ID)
        if category == 8 and (param == ids.PHALANX_1 or param == ids.PHALANX_2 or param == ids.PHALANX_X) then
            
            log('Phalanx Cast Detected! ID: ' .. tostring(param))

            -- Ignore self-cast
            if actor_id == player.id then return end

            local target_id = packet['Target 1 ID']
            
            -- CASE A: DIRECT CAST ON ME
            if target_id == player.id then
                windower.add_to_chat(207, '[AutoPhalanx] Incoming Phalanx! Swapping gear.')
                windower.send_command(phalanx_command)
                return
            end

            -- CASE B: ACCESSION (AOE) LOGIC
            if accession_users[actor_id] and os.time() < accession_users[actor_id] then
                local dist = get_distance_to_entity(target_id)
                log('AoE Logic: Dist to target is ' .. tostring(dist))
                
                if dist < 10 then
                    windower.add_to_chat(207, '[AutoPhalanx] AoE Phalanx Incoming! Swapping gear.')
                    windower.send_command(phalanx_command)
                    accession_users[actor_id] = nil
                end
            end
        end
    end
end)