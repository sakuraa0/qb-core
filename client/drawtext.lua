local function hideText()
    if QBConfig.TextMenu == "okok" then
        exports['okokTextUI']:Close()
    elseif QBConfig.TextMenu == "qb" then
        SendNUIMessage({
            action = 'HIDE_TEXT',
        })
    elseif QBConfig.TextMenu == "ox" then
        lib.hideTextUI()
    end
end

local function drawText(text, position)
    if QBConfig.TextMenu == "okok" then
        if type(position) ~= 'string' then position = 'left' end
        local color = 'darkblue' -- textui color
        local playSound = true -- playsound on/off
        exports['okokTextUI']:Open(text, color, position, playSound)
    elseif QBConfig.TextMenu == "qb" then 
        if type(position) ~= 'string' then position = 'left' end
        SendNUIMessage({
            action = 'DRAW_TEXT',
            data = {
                text = text,
                position = position
            }
        })
    elseif QBConfig.TextMenu == "ox" then
        local options = {
            position = "left-center",
        }
        lib.showTextUI(text, options)
    end
end

local function changeText(text, position)
    if type(position) ~= 'string' then position = 'left' end

    SendNUIMessage({
        action = 'CHANGE_TEXT',
        data = {
            text = text,
            position = position
        }
    })
end

local function keyPressed()
    CreateThread(function() -- Not sure if a thread is needed but why not eh?
        SendNUIMessage({
            action = 'KEY_PRESSED',
        })
        Wait(500)
        hideText()
    end)
end

RegisterNetEvent('qb-core:client:DrawText', function(text, position)
    drawText(text, position)
end)

RegisterNetEvent('qb-core:client:ChangeText', function(text, position)
    changeText(text, position)
end)

RegisterNetEvent('qb-core:client:HideText', function()
    hideText()
end)

RegisterNetEvent('qb-core:client:KeyPressed', function()
    keyPressed()
end)

exports('DrawText', drawText)
exports('ChangeText', changeText)
exports('HideText', hideText)
exports('KeyPressed', keyPressed)
