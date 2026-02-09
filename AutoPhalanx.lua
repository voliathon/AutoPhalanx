_addon.name = 'AutoPhalanx'
_addon.author = 'Voliathon'
_addon.version = '1.0.1'
_addon.commands = {'ap', 'autophalanx'}

require('packets')
local res = require('resources')

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- The command to execute when you are about to be hit by AoE Phalanx.
-- Adjust this to match your GearSwap set or in-game macro.
local phalanx_command = 'gs equip sets.Phalanx'
-- local phalanx_command = 'input /equipset 10' 

-- ============================================================================
-- VARIABLES & SETUP
-- ============================================================================
local accession_users = {}
local accession_id = res.job_abilities:with('english', 'Accession').id
local phalanx_id = res.spells:with('english', 'Phalanx').id

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
-- Returns the distance between the player and the entity with the given ID
local function get_distance_to_entity(target_id)
    local target = windower.ffxi.get_mob_by_id(target_id)
    if target then
        return math.sqrt(target.distance)
    end
    return 999 -- Return a huge number if target not found
end

-- ============================================================================
-- MAIN EVENT LOOP
-- ============================================================================
windower.register_event('incoming chunk', function(id, data)
    -- 0x28 is the Action packet (includes "Use Ability" and "Starts Casting")
    if id == 0x28 then
        local packet = packets.parse('incoming', data)
        local actor_id = packet['Actor']
        local player = windower.ffxi.get_player()

        -- --------------------------------------------------------------------
        -- LOGIC 1: Detect Accession Usage
        -- --------------------------------------------------------------------
        -- Category 6 = Job Ability
        if packet.Category == 6 and packet.Param == accession_id then
            -- Mark this actor as having Accession active for 60 seconds
            accession_users[actor_id] = os.time() + 60
        end

        -- --------------------------------------------------------------------
        -- LOGIC 2: Detect Phalanx Casting
        -- --------------------------------------------------------------------
        -- Category 8 = Starts Casting
        if packet.Category == 8 and packet.Param == phalanx_id then
            
            -- SAFETY CHECK: Ignore if I am casting on myself.
            -- GearSwap handles self-buffs automatically via midcast.
            if actor_id == player.id then
                return
            end

            -- Check if this specific actor has used Accession recently
            if accession_users[actor_id] and os.time() < accession_users[actor_id] then
                
                -- The target of the spell (usually the Scholar themselves)
                local spell_target_id = packet['Target 1 ID']
                
                -- Calculate distance: Am I close enough to the spell's target?
                -- Accession creates an AoE of 10 yalms around the target.
                local dist = get_distance_to_entity(spell_target_id)
                
                if dist < 10 then
                     windower.add_to_chat(207, '[AutoPhalanx] AoE Phalanx incoming! Swapping gear.')
                     windower.send_command(phalanx_command)
                     
                     -- Clear the flag so we don't trigger multiple times for the same cast
                     accession_users[actor_id] = nil
                end
            end
        end
    end
end)