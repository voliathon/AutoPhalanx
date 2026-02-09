--[[
    Copyright (c) 2025 Voliathon
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
       this list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.
]]

_addon.name = 'AutoPhalanx'
_addon.author = 'Voliathon'
_addon.version = '1.2.0'
_addon.commands = {'ap', 'autophalanx'}

local packets = require('packets')
local res = require('resources')

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- The command to execute when you are about to be hit by Phalanx.
-- Ensure the capitalization matches your GearSwap file (e.g., sets.Phalanx)
local phalanx_command = 'gs equip sets.Phalanx'

-- Command to reset gear after the spell lands (Triggered via GS self_command)
local return_command  = 'gs c update' 
local cast_delay      = 4             -- Seconds to wait before resetting gear
local debug_mode      = true          -- Set to false to disable chat logs

-- ============================================================================
-- VALID IDS
-- ============================================================================
local ids = {
    ACCESSIO = 218,
    PHALANX_1 = 106,
    PHALANX_2 = 107,
    PHALANX_X = 24931
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
    if target then return math.sqrt(target.distance) end
    return 999
end

-- FUNCTION TO RESET GEAR
local function reset_gear()
    log('Spell should have landed. Resetting gear...')
    windower.send_command(return_command)
end

-- ============================================================================
-- MAIN EVENT LOOP
-- ============================================================================
windower.register_event('incoming chunk', function(id, data)
    if id == 0x28 then
        
        -- OPTIMIZATION: Party Check
        -- If we are Solo (Count <= 1), do not run any logic.
        local party = windower.ffxi.get_party()
        if not party or party.party1_count <= 1 then
            return
        end

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

        -- 2. DETECT PHALANX
        if category == 8 and (param == ids.PHALANX_1 or param == ids.PHALANX_2 or param == ids.PHALANX_X) then
            
            -- Ignore self-cast (GearSwap handles this)
            if actor_id == player.id then return end

            local target_id = packet['Target 1 ID']
            local should_swap = false

            -- CASE A: DIRECT CAST ON ME
            if target_id == player.id then
                log('Direct cast on me!')
                should_swap = true
            end

            -- CASE B: ACCESSION (AOE) LOGIC
            if not should_swap and accession_users[actor_id] and os.time() < accession_users[actor_id] then
                local dist = get_distance_to_entity(target_id)
                if dist < 10 then
                    log('AoE Logic: In range ('..dist..')')
                    should_swap = true
                    accession_users[actor_id] = nil
                end
            end

            -- EXECUTE SWAP AND QUEUE RESET
            if should_swap then
                windower.add_to_chat(207, '[AutoPhalanx] Incoming Phalanx! Equipping set.')
                windower.send_command(phalanx_command)
                
                -- SCHEDULE THE RESET
                coroutine.schedule(reset_gear, cast_delay)
            end
        end
    end
end)