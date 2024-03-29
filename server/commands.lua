QBCore.Commands = {}
QBCore.Commands.List = {}
QBCore.Commands.IgnoreList = { -- Ignore old perm levels while keeping backwards compatibility
    ['god'] = true,            -- We don't need to create an ace because god is allowed all commands
    ['user'] = true            -- We don't need to create an ace because builtin.everyone
}

CreateThread(function() -- Add ace to node for perm checking
    local permissions = QBCore.Config.Server.Permissions
    for i = 1, #permissions do
        local permission = permissions[i]
        ExecuteCommand(('add_ace qbcore.%s %s allow'):format(permission, permission))
    end
end)

-- Register & Refresh Commands

function QBCore.Commands.Add(name, help, arguments, argsrequired, callback, permission, ...)
    local restricted = true                                  -- Default to restricted for all commands
    if not permission then permission = 'user' end           -- some commands don't pass permission level
    if permission == 'user' then restricted = false end      -- allow all users to use command

    RegisterCommand(name, function(source, args, rawCommand) -- Register command within fivem
        if argsrequired and #args < #arguments then
            return TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                multiline = true,
                args = { 'System', Lang:t('error.missing_args2') }
            })
        end
        callback(source, args, rawCommand)
    end, restricted)

    local extraPerms = ... and table.pack(...) or nil
    if extraPerms then
        extraPerms[extraPerms.n + 1] = permission -- The `n` field is the number of arguments in the packed table
        extraPerms.n += 1
        permission = extraPerms
        for i = 1, permission.n do
            if not QBCore.Commands.IgnoreList[permission[i]] then -- only create aces for extra perm levels
                ExecuteCommand(('add_ace qbcore.%s command.%s allow'):format(permission[i], name))
            end
        end
        permission.n = nil
    else
        permission = tostring(permission:lower())
        if not QBCore.Commands.IgnoreList[permission] then -- only create aces for extra perm levels
            ExecuteCommand(('add_ace qbcore.%s command.%s allow'):format(permission, name))
        end
    end

    QBCore.Commands.List[name:lower()] = {
        name = name:lower(),
        permission = permission,
        help = help,
        arguments = arguments,
        argsrequired = argsrequired,
        callback = callback
    }
end

function QBCore.Commands.Refresh(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local suggestions = {}
    if Player then
        for command, info in pairs(QBCore.Commands.List) do
            local hasPerm = IsPlayerAceAllowed(tostring(src), 'command.' .. command)
            if hasPerm then
                suggestions[#suggestions + 1] = {
                    name = '/' .. command,
                    help = info.help,
                    params = info.arguments
                }
            else
                TriggerClientEvent('chat:removeSuggestion', src, '/' .. command)
            end
        end
        TriggerClientEvent('chat:addSuggestions', src, suggestions)
    end
end

-- Teleport
QBCore.Commands.Add('tp', Lang:t('command.tp.help'), { { name = Lang:t('command.tp.params.x.name'), help = Lang:t('command.tp.params.x.help') }, { name = Lang:t('command.tp.params.y.name'), help = Lang:t('command.tp.params.y.help') }, { name = Lang:t('command.tp.params.z.name'), help = Lang:t('command.tp.params.z.help') } }, false, function(source, args)
    if args[1] and not args[2] and not args[3] then
        if tonumber(args[1]) then
            local target = GetPlayerPed(tonumber(args[1]))
            if target ~= 0 then
                local coords = GetEntityCoords(target)
                TriggerClientEvent('QBCore:Command:TeleportToPlayer', source, coords)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
            end
        else
            local location = QBShared.Locations[args[1]]
            if location then
                TriggerClientEvent('QBCore:Command:TeleportToCoords', source, location.x, location.y, location.z, location.w)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t('error.location_not_exist'), 'error')
            end
        end
    else
        if args[1] and args[2] and args[3] then
            local x = tonumber((args[1]:gsub(',', ''))) + .0
            local y = tonumber((args[2]:gsub(',', ''))) + .0
            local z = tonumber((args[3]:gsub(',', ''))) + .0
            if x ~= 0 and y ~= 0 and z ~= 0 then
                TriggerClientEvent('QBCore:Command:TeleportToCoords', source, x, y, z)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t('error.wrong_format'), 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t('error.missing_args'), 'error')
        end
    end
end, 'admin')

QBCore.Commands.Add('tpm', Lang:t('command.tpm.help'), {}, false, function(source)
    TriggerClientEvent('QBCore:Command:GoToMarker', source)
end, 'admin')

QBCore.Commands.Add('togglepvp', Lang:t('command.togglepvp.help'), {}, false, function()
    QBCore.Config.Server.PVP = not QBCore.Config.Server.PVP
    TriggerClientEvent('QBCore:Client:PvpHasToggled', -1, QBCore.Config.Server.PVP)
end, 'admin')

-- Permissions

QBCore.Commands.Add('addpermission', Lang:t('command.addpermission.help'), { { name = Lang:t('command.addpermission.params.id.name'), help = Lang:t('command.addpermission.params.id.help') }, { name = Lang:t('command.addpermission.params.permission.name'), help = Lang:t('command.addpermission.params.permission.help') } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local permission = tostring(args[2]):lower()
    if Player then
        QBCore.Functions.AddPermission(Player.PlayerData.source, permission)
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'god')

QBCore.Commands.Add('removepermission', Lang:t('command.removepermission.help'), { { name = Lang:t('command.removepermission.params.id.name'), help = Lang:t('command.removepermission.params.id.help') }, { name = Lang:t('command.removepermission.params.permission.name'), help = Lang:t('command.removepermission.params.permission.help') } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local permission = tostring(args[2]):lower()
    if Player then
        QBCore.Functions.RemovePermission(Player.PlayerData.source, permission)
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'god')

-- Open & Close Server

QBCore.Commands.Add('openserver', Lang:t('command.openserver.help'), {}, false, function(source)
    if not QBCore.Config.Server.Closed then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.server_already_open'), 'error')
        return
    end
    if QBCore.Functions.HasPermission(source, 'admin') then
        QBCore.Config.Server.Closed = false
        TriggerClientEvent('QBCore:Notify', source, Lang:t('success.server_opened'), 'success')
    else
        QBCore.Functions.Kick(source, Lang:t('error.no_permission'), nil, nil)
    end
end, 'admin')

QBCore.Commands.Add('closeserver', Lang:t('command.closeserver.help'), { { name = Lang:t('command.closeserver.params.reason.name'), help = Lang:t('command.closeserver.params.reason.help') } }, false, function(source, args)
    if QBCore.Config.Server.Closed then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.server_already_closed'), 'error')
        return
    end
    if QBCore.Functions.HasPermission(source, 'admin') then
        local reason = args[1] or 'No reason specified'
        QBCore.Config.Server.Closed = true
        QBCore.Config.Server.ClosedReason = reason
        for k in pairs(QBCore.Players) do
            if not QBCore.Functions.HasPermission(k, QBCore.Config.Server.WhitelistPermission) then
                QBCore.Functions.Kick(k, reason, nil, nil)
            end
        end
        TriggerClientEvent('QBCore:Notify', source, Lang:t('success.server_closed'), 'success')
    else
        QBCore.Functions.Kick(source, Lang:t('error.no_permission'), nil, nil)
    end
end, 'admin')

-- Vehicle

QBCore.Commands.Add('car', Lang:t('command.car.help'), { { name = Lang:t('command.car.params.model.name'), help = Lang:t('command.car.params.model.help') } }, true, function(source, args)
    TriggerClientEvent('QBCore:Command:SpawnVehicle', source, args[1])
end, 'admin')

QBCore.Commands.Add('dv', Lang:t('command.dv.help'), {}, false, function(source)
    TriggerClientEvent('QBCore:Command:DeleteVehicle', source)
end, 'admin')

QBCore.Commands.Add('dvall', Lang:t('command.dvall.help'), {}, false, function()
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        DeleteEntity(vehicle)
    end
end, 'admin')

-- Peds

QBCore.Commands.Add('dvp', Lang:t('command.dvp.help'), {}, false, function()
    local peds = GetAllPeds()
    for _, ped in ipairs(peds) do
        DeleteEntity(ped)
    end
end, 'admin')

-- Objects

QBCore.Commands.Add('dvo', Lang:t('command.dvo.help'), {}, false, function()
    local objects = GetAllObjects()
    for _, object in ipairs(objects) do
        DeleteEntity(object)
    end
end, 'admin')

-- Money

QBCore.Commands.Add('givemoney', Lang:t('command.givemoney.help'), { { name = Lang:t('command.givemoney.params.id.name'), help = Lang:t('command.givemoney.params.id.help') }, { name = Lang:t('command.givemoney.params.moneytype.name'), help = Lang:t('command.givemoney.params.moneytype.help') }, { name = Lang:t('command.givemoney.params.amount.name'), help = Lang:t('command.givemoney.params.amount.help') } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if Player then
        Player.Functions.AddMoney(tostring(args[2]), tonumber(args[3]), 'Admin give money')
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('setmoney', Lang:t('command.setmoney.help'), { { name = Lang:t('command.setmoney.params.id.name'), help = Lang:t('command.setmoney.params.id.help') }, { name = Lang:t('command.setmoney.params.moneytype.name'), help = Lang:t('command.setmoney.params.moneytype.help') }, { name = Lang:t('command.setmoney.params.amount.name'), help = Lang:t('command.setmoney.params.amount.help') } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if Player then
        Player.Functions.SetMoney(tostring(args[2]), tonumber(args[3]))
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'admin')

-- Job

QBCore.Commands.Add('job', Lang:t('command.job.help'), {}, false, function(source)
    local PlayerJob = QBCore.Functions.GetPlayer(source).PlayerData.job
    TriggerClientEvent('QBCore:Notify', source, Lang:t('info.job_info', { value = PlayerJob.label, value2 = PlayerJob.grade.name, value3 = PlayerJob.onduty }))
end, 'user')

QBCore.Commands.Add('setjob', Lang:t('command.setjob.help'), { { name = Lang:t('command.setjob.params.id.name'), help = Lang:t('command.setjob.params.id.help') }, { name = Lang:t('command.setjob.params.job.name'), help = Lang:t('command.setjob.params.job.help') }, { name = Lang:t('command.setjob.params.grade.name'), help = Lang:t('command.setjob.params.grade.help') } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if Player then
        Player.Functions.SetJob(tostring(args[2]), tonumber(args[3]))
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'admin')

-- Gang

QBCore.Commands.Add('gang', Lang:t('command.gang.help'), {}, false, function(source)
    local PlayerGang = QBCore.Functions.GetPlayer(source).PlayerData.gang
    TriggerClientEvent('QBCore:Notify', source, Lang:t('info.gang_info', { value = PlayerGang.label, value2 = PlayerGang.grade.name }))
end, 'user')

QBCore.Commands.Add('setgang', Lang:t('command.setgang.help'), { { name = Lang:t('command.setgang.params.id.name'), help = Lang:t('command.setgang.params.id.help') }, { name = Lang:t('command.setgang.params.gang.name'), help = Lang:t('command.setgang.params.gang.help') }, { name = Lang:t('command.setgang.params.grade.name'), help = Lang:t('command.setgang.params.grade.help') } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if Player then
        Player.Functions.SetGang(tostring(args[2]), tonumber(args[3]))
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_online'), 'error')
    end
end, 'admin')

-- Out of Character Chat
QBCore.Commands.Add('ooc', Lang:t('command.ooc.help'), {}, false, function(source, args)
    local message = table.concat(args, ' ')
    local Players = QBCore.Functions.GetPlayers()
    local Player = QBCore.Functions.GetPlayer(source)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    for _, v in pairs(Players) do
        if v == source then
            TriggerClientEvent('chat:addMessage', v, {
                color = QBCore.Config.Commands.OOCColor,
                multiline = true,
                args = { 'OOC | ' .. GetPlayerName(source), message }
            })
        elseif #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 20.0 then
            TriggerClientEvent('chat:addMessage', v, {
                color = QBCore.Config.Commands.OOCColor,
                multiline = true,
                args = { 'OOC | ' .. GetPlayerName(source), message }
            })
        elseif QBCore.Functions.HasPermission(v, 'admin') then
            if QBCore.Functions.IsOptin(v) then
                TriggerClientEvent('chat:addMessage', v, {
                    color = QBCore.Config.Commands.OOCColor,
                    multiline = true,
                    args = { 'Proximity OOC | ' .. GetPlayerName(source), message }
                })
                TriggerEvent('qb-log:server:CreateLog', 'ooc', 'OOC', 'white', '**' .. GetPlayerName(source) .. '** (CitizenID: ' .. Player.PlayerData.citizenid .. ' | ID: ' .. source .. ') **Message:** ' .. message, false)
            end
        end
    end
end, 'user')

-- Me command

QBCore.Commands.Add('me', Lang:t('command.me.help'), { { name = Lang:t('command.me.params.message.name'), help = Lang:t('command.me.params.message.help') } }, false, function(source, args)
    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.missing_args2'), 'error')
        return
    end
    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    local Players = QBCore.Functions.GetPlayers()
    for i = 1, #Players do
        local Player = Players[i]
        local target = GetPlayerPed(Player)
        local tCoords = GetEntityCoords(target)
        if target == ped or #(pCoords - tCoords) < 20 then
            TriggerClientEvent('QBCore:Command:ShowMe3D', Player, source, msg)
        end
    end
end, 'user')

-- Commands added

QBCore.Commands.Add('csn', 'ver CSN', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenId = Player.PlayerData.citizenid
    TriggerClientEvent('chatMessage', source, "Sistema", "info", "Passaporte: " .. citizenId)
end)

QBCore.Commands.Add('reviver', 'Revive all players in a range', {{ name = 'Range', help = 'Radius to revive'}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    local range = tonumber(args[1] or 100.0)
    local players = QBCore.Functions.GetQBPlayers()
    for id, ply in pairs(players) do
      local coords = GetEntityCoords(GetPlayerPed(source))
      local target = GetEntityCoords(GetPlayerPed(id))
      if #(coords - target) <= range then
        TriggerClientEvent('hospital:client:Revive', id)
        -- add any notifies or logging here
      end
    end
    QBCore.Functions.Notify(source, 'You\'ve successfully revived everyone within ' .. range .. ' meters.', 'success', 5000)
end, 'admin')

QBCore.Commands.Add('noclip', Lang:t('commands.toogle_noclip'), {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-core:client:ToggleNoClip', src)
end, 'admin')

QBCore.Commands.Add('setammo', Lang:t('commands.ammo_amount_set'), { { name = 'amount', help = 'Amount of bullets, for example: 20' } }, false, function(source, args)
    local src = source
    local ped = GetPlayerPed(src)
    local amount = tonumber(args[1])
    local weapon = GetSelectedPedWeapon(ped)
    if weapon and amount then
        SetPedAmmo(ped, weapon, amount)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.ammoforthe', { value = amount, weapon = QBCore.Shared.Weapons[weapon]['label'] }), 'success')
    end
end, 'admin')

QBCore.Commands.Add('vector2', 'Copy vector2 to clipboard (Admin only)', {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-core:client:copyToClipboard', src, 'coords2')
end, 'admin')

QBCore.Commands.Add('vector3', 'Copy vector3 to clipboard (Admin only)', {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-core:client:copyToClipboard', src, 'coords3')
end, 'admin')

QBCore.Commands.Add('vector4', 'Copy vector4 to clipboard (Admin only)', {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-core:client:copyToClipboard', src, 'coords4')
end, 'admin')

QBCore.Commands.Add('heading', 'Copy heading to clipboard (Admin only)', {}, false, function(source)
    local src = source
    TriggerClientEvent('qb-core:client:copyToClipboard', src, 'heading')
end, 'admin')

QBCore.Commands.Add('admincar', Lang:t('commands.save_vehicle_garage'), {}, false, function(source, _)
    TriggerClientEvent('qb-core:client:SaveCar', source)
end, 'admin')

QBCore.Commands.Add('bring', Lang:t('command.bring'), {{name = 'playerId', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local targetPlayerId = tonumber(args[1])

    if not targetPlayerId then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bring_invalid'), 'error')
        return
    end

    local adminCoords = GetEntityCoords(GetPlayerPed(src))
    local targetPlayer = GetPlayerPed(targetPlayerId)

    if not targetPlayer or not DoesEntityExist(targetPlayer) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bring_notfound'), 'error')
        return
    end

    if IsPlayerAceAllowed(src, 'command') then
        SetEntityCoords(targetPlayer, adminCoords)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bring_sucess'), 'success')
    else
        BanPlayer(src)
    end
end, 'admin')


QBCore.Commands.Add('bringback', Lang:t('command.bringback'), {{name = 'playerId', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local targetPlayerId = tonumber(args[1])
    local playerCoords = {}
    
    if not targetPlayerId then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bring_invalid'), 'error')
        return
    end

    local targetPlayer = GetPlayerPed(targetPlayerId)

    if not targetPlayer or not DoesEntityExist(targetPlayer) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bring_notfound'), 'error')
        return
    end

    if playerCoords[targetPlayerId] then
        local coords = playerCoords[targetPlayerId]
        SetEntityCoords(targetPlayer, coords)
        playerCoords[targetPlayerId] = nil -- Removendo as coordenadas temporárias
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bringback_success'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.bringback_noloc'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('goto', Lang:t('command.goto1'), {{name = 'playerId', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local targetPlayerId = tonumber(args[1])

    if not targetPlayerId then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.goto_invalid'), 'error')
        return
    end

    local targetPlayer = GetPlayerPed(targetPlayerId)

    if not targetPlayer or not DoesEntityExist(targetPlayer) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.goto_notfound'), 'error')
        return
    end

    if IsPlayerAceAllowed(src, 'command') then
        local adminCoords = GetEntityCoords(targetPlayer)
        local adminPed = GetPlayerPed(src)
        SetEntityCoords(adminPed, adminCoords)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('command.goto_success'), 'success')
    else
        BanPlayer(src)
    end
end, 'admin')

QBCore.Commands.Add('spec', 'Spectate a player', {{name = 'playerId', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local targetPlayerId = tonumber(args[1])
    
    if not targetPlayerId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID.', 'error')
        return
    end

    local targetPlayer = GetPlayerPed(targetPlayerId)

    if not targetPlayer or not DoesEntityExist(targetPlayer) then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found.', 'error')
        return
    end

    if IsPlayerAceAllowed(src, 'command') then
        local coords = GetEntityCoords(targetPlayer)
        TriggerClientEvent('qb-core:client:spectate', src, targetPlayerId, coords)
    else
        BanPlayer(src)
    end
end, 'admin')

QBCore.Commands.Add('ban', 'Ban a player', {{name = 'playerId', help = 'Player ID'}, {name = 'time', help = 'Ban time in seconds or "perma"'}, {name = 'reason', help = 'Ban reason'}}, true, function(source, args)
    local src = source
    local targetPlayerId = tonumber(args[1])
    local banTime = args[2]
    local reason = table.concat(args, " ", 3)

    if not targetPlayerId or not banTime or not reason then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Invalid arguments.' } })
        return
    end

    if banTime ~= "perma" then
        banTime = tonumber(banTime)
    else
        banTime = 2147483647
    end

    if IsPlayerAceAllowed(src, 'command') then
        local targetPlayer = GetPlayerPed(targetPlayerId)
        
        if not targetPlayer or not DoesEntityExist(targetPlayer) then
            TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Player not found.' } })
            return
        end

        local banExpires = banTime ~= 2147483647 and os.date('%d/%m/%Y %H:%M', os.time() + banTime) or 'Permanent'

        MySQL.Async.execute('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (@name, @license, @discord, @ip, @reason, @expire, @bannedby)', {
            ['@name'] = GetPlayerName(targetPlayerId),
            ['@license'] = QBCore.Functions.GetIdentifier(targetPlayerId, 'license'),
            ['@discord'] = QBCore.Functions.GetIdentifier(targetPlayerId, 'discord'),
            ['@ip'] = QBCore.Functions.GetIdentifier(targetPlayerId, 'ip'),
            ['@reason'] = reason,
            ['@expire'] = banTime,
            ['@bannedby'] = GetPlayerName(src)
        }, function(rowsChanged)
            TriggerClientEvent('chat:addMessage', -1, {
                template = "<div class=chat-message server'><strong>ANNOUNCEMENT | {0} has been banned:</strong> {1}</div>",
                args = { GetPlayerName(targetPlayerId), reason }
            })
            TriggerEvent('qb-log:server:CreateLog', 'bans', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(targetPlayerId), GetPlayerName(src), reason), true)
            
            if banTime == 2147483647 then
                DropPlayer(targetPlayerId, Lang:t('info.banned') .. '\n' .. reason .. Lang:t('info.ban_perm') .. QBCore.Config.Server.Discord)
            else
                DropPlayer(targetPlayerId, Lang:t('info.banned') .. '\n' .. reason .. Lang:t('info.ban_expires') .. banExpires .. '\n🔸 Check our Discord for more information: ' .. QBCore.Config.Server.Discord)
            end
        end)
    else
        BanPlayer(src)
    end
end, 'admin')

QBCore.Commands.Add('report', Lang:t('info.admin_report'), { { name = 'message', help = 'Message' } }, true, function(source, args)
    local src = source
    local msg = table.concat(args, ' ')
    local Player = QBCore.Functions.GetPlayer(source)
    TriggerClientEvent('qb-core:client:SendReport', -1, GetPlayerName(src), src, msg)
    TriggerClientEvent('QBCore:Notify', src, 'Report Send it.', 'info')
    TriggerEvent('qb-log:server:CreateLog', 'report', 'Report', 'green', '**' .. GetPlayerName(source) .. '** (CitizenID: ' .. Player.PlayerData.citizenid .. ' | ID: ' .. source .. ') **Report:** ' .. msg, false)
end)

QBCore.Commands.Add('reporttoggle', Lang:t('commands.report_toggle'), {}, false, function(source, _)
    local src = source
    QBCore.Functions.ToggleOptin(src)
    if QBCore.Functions.IsOptin(src) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.receive_reports'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_receive_report'), 'error')
    end
end, 'admin')

QBCore.Commands.Add('reportr', Lang:t('commands.reply_to_report'), { { name = 'id', help = 'Player' }, { name = 'message', help = 'Message to respond with' } }, false, function(source, args)
    local src = source
    local playerId = tonumber(args[1])
    table.remove(args, 1)
    local msg = table.concat(args, ' ')
    local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
    if msg == '' then return end
    if not OtherPlayer then return TriggerClientEvent('QBCore:Notify', src, 'Player is not online', 'error') end
    if not QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') ~= 1 then return end
    TriggerClientEvent('chat:addMessage', playerId, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'Admin Response', msg }
    })
    TriggerClientEvent('chat:addMessage', src, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'Report Response (' .. playerId .. ')', msg }
    })
    TriggerClientEvent('QBCore:Notify', src, 'Reply Sent')
    TriggerEvent('qb-log:server:CreateLog', 'report', 'Report Reply', 'red', '**' .. GetPlayerName(src) .. '** replied on: **' .. OtherPlayer.PlayerData.name .. ' **(ID: ' .. OtherPlayer.PlayerData.source .. ') **Message:** ' .. msg, false)
end, 'admin')

