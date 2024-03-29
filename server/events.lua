-- Event Handler

AddEventHandler('chatMessage', function(_, _, message)
    if string.sub(message, 1, 1) == '/' then
        CancelEvent()
        return
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local ped = GetPlayerPed(src)
    local armor = GetPedArmour(ped)
    if not QBCore.Players[src] then return end
    local Player = QBCore.Players[src]
    TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Dropped', 'red', '**' .. GetPlayerName(src) .. '** (' .. Player.PlayerData.license .. ') left..' ..'\n **Reason:** ' .. reason)
    Player.Functions.SetMetaData('armor', armor)
    Player.Functions.Save()
    QBCore.Player_Buckets[Player.PlayerData.license] = nil
    QBCore.Players[src] = nil
end)

-- Player Connecting

local function onPlayerConnecting(name, _, deferrals)
    local src = source
    deferrals.defer()

    if QBCore.Config.Server.Closed and not IsPlayerAceAllowed(src, 'qbadmin.join') then
        return deferrals.done(QBCore.Config.Server.ClosedReason)
    end

    if QBCore.Config.Server.Whitelist then
        Wait(0)
        deferrals.update(string.format(Lang:t('info.checking_whitelisted'), name))
        if not QBCore.Functions.IsWhitelisted(src) then
            return deferrals.done(Lang:t('error.not_whitelisted'))
        end
    end

    if QBConfig.AdaptiveCard.Enabled then
        local toEnd = false
        local count = 0
        while not toEnd do 
            deferrals.presentCard('{"type": "AdaptiveCard","$schema": "http://adaptivecards.io/schemas/adaptive-card.json","version": "1.3","body": [{"type": "Image","url": "' ..QBConfig.AdaptiveCard.Banner.. '","horizontalAlignment": "center"},{"type": "Container","items": [{"type": "TextBlock","text": "👋 Welcome '.. name ..' to '.. QBConfig.AdaptiveCard.Server_Name ..'! 👋","wrap": true,"fontType": "Default","size": "extralarge","weight": "bolder","color": "Light","horizontalAlignment": "center"},{"type": "TextBlock","text": "' ..QBConfig.AdaptiveCard.Heading.. '","wrap": true,"size": "Large","weight": "bolder","color": "Light","horizontalAlignment": "center"},{"type": "ColumnSet","height": "stretch","minHeight": "50px","bleed": true,"horizontalAlignment": "center","columns": [ { "type": "Column", "width": "stretch", "items": [ { "type": "ActionSet", "actions": [ { "type": "Action.OpenUrl", "title": "' .. QBConfig.AdaptiveCard.Button_1 .. '", "iconUrl": "' .. QBConfig.AdaptiveCard.Icon_1 .. '", "url": "' .. QBConfig.AdaptiveCard.Link_1 .. '", "style": "positive" } ], "horizontalAlignment": "center" } ], "height": "stretch" }, { "type": "Column", "width": "stretch", "items": [ { "type": "ActionSet", "actions": [ { "type": "Action.OpenUrl", "title": "' .. QBConfig.AdaptiveCard.Button_2 .. '", "style": "positive", "iconUrl": "' .. QBConfig.AdaptiveCard.Icon_2 .. '", "url": "' .. QBConfig.AdaptiveCard.Link_2 .. '" } ], "horizontalAlignment": "center" } ] } ] }, { "type": "ActionSet", "actions": [ { "type": "Action.OpenUrl", "title": "' .. QBConfig.AdaptiveCard.Button_3 .. '", "style": "destructive", "iconUrl": "' .. QBConfig.AdaptiveCard.Icon_3 .. '", "url": "' .. QBConfig.AdaptiveCard.Link_3 .. '" } ], "horizontalAlignment": "center" } ], "style": "default", "bleed": true, "height": "stretch" }, { "type": "Image", "url": "' .. QBConfig.AdaptiveCard.Icon_4 .. '", "selectAction": { "type": "Action.OpenUrl", "url": "' .. QBConfig.AdaptiveCard.Link_4 .. '" }, "horizontalAlignment": "center" } ] }',
            function(data, rawData)
            end)
            Wait((1000))
            count = count + 1;
            if count == QBConfig.AdaptiveCard.Wait then 
                toEnd = true;
            end
        end
    end

    Wait(0)
    deferrals.update(string.format('Hello %s. Your license is being checked', name))
    local license = QBCore.Functions.GetIdentifier(src, 'license')

    if not license then
        return deferrals.done(Lang:t('error.no_valid_license'))
    elseif QBCore.Config.Server.CheckDuplicateLicense and QBCore.Functions.IsLicenseInUse(license) then
        return deferrals.done(Lang:t('error.duplicate_license'))
    end

    Wait(0)
    deferrals.update(string.format(Lang:t('info.checking_ban'), name))

    local success, isBanned, reason = pcall(QBCore.Functions.IsPlayerBanned, src)
    if not success then return deferrals.done(Lang:t('error.connecting_database_error')) end
    if isBanned then return deferrals.done(reason) end

    Wait(0)
    deferrals.update(string.format(Lang:t('info.join_server'), name))
    deferrals.done()

    TriggerClientEvent('QBCore:Client:SharedUpdate', src, QBCore.Shared)
end

AddEventHandler('playerConnecting', onPlayerConnecting)

-- Open & Close Server (prevents players from joining)

RegisterNetEvent('QBCore:Server:CloseServer', function(reason)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') then
        reason = reason or 'No reason specified'
        QBCore.Config.Server.Closed = true
        QBCore.Config.Server.ClosedReason = reason
        for k in pairs(QBCore.Players) do
            if not QBCore.Functions.HasPermission(k, QBCore.Config.Server.WhitelistPermission) then
                QBCore.Functions.Kick(k, reason, nil, nil)
            end
        end
    else
        QBCore.Functions.Kick(src, Lang:t('error.no_permission'), nil, nil)
    end
end)

RegisterNetEvent('QBCore:Server:OpenServer', function()
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') then
        QBCore.Config.Server.Closed = false
    else
        QBCore.Functions.Kick(src, Lang:t('error.no_permission'), nil, nil)
    end
end)

-- Callback Events --

-- Client Callback
RegisterNetEvent('QBCore:Server:TriggerClientCallback', function(name, ...)
    if QBCore.ClientCallbacks[name] then
        QBCore.ClientCallbacks[name](...)
        QBCore.ClientCallbacks[name] = nil
    end
end)

-- Server Callback
RegisterNetEvent('QBCore:Server:TriggerCallback', function(name, ...)
    local src = source
    QBCore.Functions.TriggerCallback(name, src, function(...)
        TriggerClientEvent('QBCore:Client:TriggerCallback', src, name, ...)
    end, ...)
end)

-- Player

RegisterNetEvent('QBCore:UpdatePlayer', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local newHunger = Player.PlayerData.metadata['hunger'] - QBCore.Config.Player.HungerRate
    local newThirst = Player.PlayerData.metadata['thirst'] - QBCore.Config.Player.ThirstRate
    if newHunger <= 0 then
        newHunger = 0
    end
    if newThirst <= 0 then
        newThirst = 0
    end
    Player.Functions.SetMetaData('thirst', newThirst)
    Player.Functions.SetMetaData('hunger', newHunger)
    TriggerClientEvent('hud:client:UpdateNeeds', src, newHunger, newThirst)
    Player.Functions.Save()
end)

RegisterNetEvent('QBCore:ToggleDuty', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.onduty then
        Player.Functions.SetJobDuty(false)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.off_duty'))
    else
        Player.Functions.SetJobDuty(true)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.on_duty'))
    end

    TriggerEvent('QBCore:Server:SetDuty', src, Player.PlayerData.job.onduty)
    TriggerClientEvent('QBCore:Client:SetDuty', src, Player.PlayerData.job.onduty)
end)

-- BaseEvents

-- Vehicles
RegisterServerEvent('baseevents:enteringVehicle', function(veh, seat, modelName)
    local src = source
    local data = {
        vehicle = veh,
        seat = seat,
        name = modelName,
        event = 'Entering'
    }
    TriggerClientEvent('QBCore:Client:VehicleInfo', src, data)
end)

RegisterServerEvent('baseevents:enteredVehicle', function(veh, seat, modelName)
    local src = source
    local data = {
        vehicle = veh,
        seat = seat,
        name = modelName,
        event = 'Entered'
    }
    TriggerClientEvent('QBCore:Client:VehicleInfo', src, data)
end)

RegisterServerEvent('baseevents:enteringAborted', function()
    local src = source
    TriggerClientEvent('QBCore:Client:AbortVehicleEntering', src)
end)

RegisterServerEvent('baseevents:leftVehicle', function(veh, seat, modelName)
    local src = source
    local data = {
        vehicle = veh,
        seat = seat,
        name = modelName,
        event = 'Left'
    }
    TriggerClientEvent('QBCore:Client:VehicleInfo', src, data)
end)

-- Items

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon.
RegisterNetEvent('QBCore:Server:UseItem', function(item)
    print(string.format('%s triggered QBCore:Server:UseItem by ID %s with the following data. This event is deprecated due to exploitation, and will be removed soon. Check qb-inventory for the right use on this event.', GetInvokingResource(), source))
    QBCore.Debug(item)
end)

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon. function(itemName, amount, slot)
RegisterNetEvent('QBCore:Server:RemoveItem', function(itemName, amount)
    local src = source
    print(string.format('%s triggered QBCore:Server:RemoveItem by ID %s for %s %s. This event is deprecated due to exploitation, and will be removed soon. Adjust your events accordingly to do this server side with player functions.', GetInvokingResource(), src, amount, itemName))
end)

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon. function(itemName, amount, slot, info)
RegisterNetEvent('QBCore:Server:AddItem', function(itemName, amount)
    local src = source
    print(string.format('%s triggered QBCore:Server:AddItem by ID %s for %s %s. This event is deprecated due to exploitation, and will be removed soon. Adjust your events accordingly to do this server side with player functions.', GetInvokingResource(), src, amount, itemName))
end)

-- Non-Chat Command Calling (ex: qb-adminmenu)

RegisterNetEvent('QBCore:CallCommand', function(command, args)
    local src = source
    if not QBCore.Commands.List[command] then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local hasPerm = QBCore.Functions.HasPermission(src, 'command.' .. QBCore.Commands.List[command].name)
    if hasPerm then
        if QBCore.Commands.List[command].argsrequired and #QBCore.Commands.List[command].arguments ~= 0 and not args[#QBCore.Commands.List[command].arguments] then
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.missing_args2'), 'error')
        else
            QBCore.Commands.List[command].callback(src, args)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_access'), 'error')
    end
end)

-- Use this for player vehicle spawning
-- Vehicle server-side spawning callback (netId)
-- use the netid on the client with the NetworkGetEntityFromNetworkId native
-- convert it to a vehicle via the NetToVeh native
QBCore.Functions.CreateCallback('QBCore:Server:SpawnVehicle', function(source, cb, model, coords, warp)
    local veh = QBCore.Functions.SpawnVehicle(source, model, coords, warp)
    cb(NetworkGetNetworkIdFromEntity(veh))
end)

-- Use this for long distance vehicle spawning
-- vehicle server-side spawning callback (netId)
-- use the netid on the client with the NetworkGetEntityFromNetworkId native
-- convert it to a vehicle via the NetToVeh native
QBCore.Functions.CreateCallback('QBCore:Server:CreateVehicle', function(source, cb, model, coords, warp)
    local veh = QBCore.Functions.CreateAutomobile(source, model, coords, warp)
    cb(NetworkGetNetworkIdFromEntity(veh))
end)

--QBCore.Functions.CreateCallback('QBCore:HasItem', function(source, cb, items, amount)
-- https://github.com/qbcore-framework/qb-inventory/blob/e4ef156d93dd1727234d388c3f25110c350b3bcf/server/main.lua#L2066
--end)

RegisterNetEvent('qb-core:server:SaveCar', function(mods, vehicle, _, plate)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        local Player = QBCore.Functions.GetPlayer(src)
        local result = MySQL.query.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
        if result[1] == nil then
            MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                Player.PlayerData.license,
                Player.PlayerData.citizenid,
                vehicle.model,
                vehicle.hash,
                json.encode(mods),
                plate,
                0
            })
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.success_vehicle_owner'), 'success', 5000)
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.failed_vehicle_owner'), 'error', 3000)
        end
    else
        BanPlayer(src)
    end
end)

local playerCoords = {}

RegisterNetEvent('qb-admin:server:bring', function(player)
    local src = source
    if IsPlayerAceAllowed(src, 'command') then
        local admin = GetPlayerPed(src)
        local coords = GetEntityCoords(admin)
        local target = GetPlayerPed(player.id)
        SetEntityCoords(target, coords)
        playerCoords[player.id] = coords
    else
        BanPlayer(src)
    end
end)

RegisterNetEvent('qb-core:server:SendReport', function(name, targetSrc, msg)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        if QBCore.Functions.IsOptin(src) then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 0, 0 },
                multiline = true,
                args = { Lang:t('info.admin_report') .. name .. ' (' .. targetSrc .. ')', msg }
            })
        end
    end
end)