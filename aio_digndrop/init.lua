-- Preserve the original node drop handling function
local original_handle_node_drops = core.handle_node_drops
local enable_pickup = core.settings:get_bool("aio_digndrop_enable_enable_pickup") or true
local enable_drop = core.settings:get_bool("aio_digndrop_enable_drop") or true

if enable_drop then
    -- Custom function for handling node drops
    core.handle_node_drops = function(position, drops, digger)
        -- Iterate through each drop item
        for _, drop_item in ipairs(drops) do
            local item_stack = ItemStack(drop_item)
            -- Calculate the drop position
            local drop_position = vector.add(position, {x = 0, y = 0.5, z = 0})
            -- Add the item to the world
            local spawned_item = core.add_item(drop_position, item_stack)
            if spawned_item then
                -- Assign random velocity to the spawned item
                local velocity = {
                    x = math.random(-1, 1),
                    y = math.random(0.5, 1),
                    z = math.random(-1, 1),
                }
                spawned_item:set_velocity(velocity)
            end
        end

        -- If the digger is a player, stop further processing
        if digger and digger:is_player() then
            return
        end

        -- Call the original node drop function if it exists
        if original_handle_node_drops then
            original_handle_node_drops(position, drops, digger)
        end
    end
end
-- Settings for item pickup behavior
local pickup_radius = tonumber(core.settings:get("aio_digndrop_pickup_radius")) or 1 -- The radius in which items are affected
local item_pickup_speed =  tonumber(core.settings:get("aio_digndrop_atrraction_speed")) or 20 -- Speed of item movement towards the player
local minimum_pickup_distance = 0.35 -- Distance at which items are picked up
local active_pickup_sounds = {} -- Table for managing active pickup sounds

-- Function to play a sound for item pickup
local function play_pickup_sound(player_name)
    if not active_pickup_sounds[player_name] then
        local sound_duration = 0.3 -- Duration before sound can be replayed
        active_pickup_sounds[player_name] = {time_remaining = sound_duration}
        core.sound_play({
            name = "aio_digndrop_pickup_sound",
            gain = 0.5,
            pitch = math.random(80, 120) / 100,
            to_player = player_name,
        })
    end
end

-- Globalstep callback for managing item pickup and sound playback
core.register_globalstep(function(delta_time)
    -- Get the list of connected players
    local players = core.get_connected_players()
    if players then
        for _, player in ipairs(players) do
            -- Update the time remaining for active sounds
            for player_name, sound_data in pairs(active_pickup_sounds) do
                sound_data.time_remaining = sound_data.time_remaining - delta_time
                if sound_data.time_remaining <= 0 then
                    active_pickup_sounds[player_name] = nil
                end
            end

            -- Get the player's position and name
            local player_position = player:get_pos()
            local player_name = player:get_player_name()

            -- Process nearby objects within the pickup radius
            for object in core.objects_inside_radius(player_position, pickup_radius) do
                if object and not object:is_player() and object:get_luaentity() and object:get_luaentity().name == "__builtin:item" then
                    -- Get the item from the object
                    local item_stack = ItemStack(object:get_luaentity().itemstring)
                    local object_position = object:get_pos()

                    -- Calculate the direction and distance to the player
                    local direction = vector.subtract(player_position, object_position)
                    local distance = vector.length(direction)

                    if distance > minimum_pickup_distance and enable_pickup then
                        -- Move the object towards the player if not within pickup distance
                        direction = vector.normalize(direction)
                        local velocity = vector.multiply(direction, item_pickup_speed)
                        object:set_velocity(velocity)
                    else
                        -- Add the item to the player's inventory and remove the object
                        player:get_inventory():add_item("main", item_stack)
                        object:remove()
                        -- Play the pickup sound for the player
                        play_pickup_sound(player_name)
                    end
                end
            end
        end
    end
end)
