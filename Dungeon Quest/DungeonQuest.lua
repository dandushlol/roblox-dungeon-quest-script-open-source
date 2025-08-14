-- Rayfield --
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Dungeon Quest Hub",
   Icon = 0,
   LoadingTitle = "Rayfield Interface Suite",
   LoadingSubtitle = "by Sirius",
   Theme = "Default",
   ToggleUIKeybind = "G",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "Dungeon Quest Hub",
      FileName = "Dungeon_Quest"
   },
})
-- Services -- 
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local vim = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
-- Local Player --
local player = players.LocalPlayer
-- Remotes --
local dataRemote = replicatedStorage.dataRemoteEvent
local changeStartValueRemote = replicatedStorage.remotes.changeStartValue
-- Debug --
local abilityDebug = nil
-- Flags --
local toggleKey = Enum.KeyCode.K
local shouldClick = true
local WaitingToTp = false
local auto_farm = true
local roomIndex = 1
local roomIterations = 0
local maxIterations = 400
local dungeonFinished = false
local normalOffset = 30
local bossOffset = 30
local autoRejoin = true
local wantedDungeon = "The Canals"
local wantedDifficulty = "Insane"
local webhookURL = ""
local webhookToggle = false
local notifier = 0
local clicking = false
local bossPassed = 0
local bossFound = false
local bossFoundTime
local maxBoss = 250
local greggPassed = 0
local greggFound = false
local greggFoundTime
-- Handle Auto Farm Logic (auto rejoin) before using infinite yields that will never happen in lobby
if workspace:FindFirstChild("LOD") then
    warn("Found LOD")
    if workspace.LOD:FindFirstChild("High") then
        warn("Found High")
        if workspace.LOD.High:FindFirstChild("BlacksmithSword") then
            warn("Found BlacksmithSword, confirmed lobby!")
            local args1 = {
                [1] = {
                    [1] = {
                        [1] = "\1"
                          },
                    [2] = "5"
                      }
                         }
            local args2 = {
                [1] = {
                    [1] = {
                        [1] = "\1",
                        [2] = {
                            ["\3"] = "select",
                            ["characterIndex"] = 1
                        }
                    },
                    [2] = "M"
                }
            }
            repeat 
            game:GetService("ReplicatedStorage").dataRemoteEvent:FireServer(unpack(args1))
            task.wait(2)
            if player.leaderstats.Level and player.leaderstats.Level.Value >= 100 then
                game:GetService("ReplicatedStorage").dataRemoteEvent:FireServer(unpack(args2))
            end
            until player.Character
            task.wait(1)
            Rayfield:Notify({
                Title = "Found Character, joining selected autofarm dungeon",
                Content = "Please Wait...",
                Duration = 5,
                Image = 0
            })
        end
    end
end
-- Local Player Parts --
local character = player.character or player.characterAdded:Wait()
local HRP = character:WaitForChild("HumanoidRootPart")
-- Modules --
local WeaponModule = require(player.PlayerGui.UIS.Weapon)

local function getGameState() -- currently returns g or d based on if youre in a lobby or dungeon
    if workspace:FindFirstChild("LOD") then
        warn("Found LOD")
        if workspace.LOD:FindFirstChild("High") then
            warn("Found High")
            if workspace.LOD.High:FindFirstChild("BlacksmithSword") then
                warn("Found BlacksmithSword, confirmed lobby!")
                return "G"
            end
        end
    end

   if workspace:FindFirstChild("dungeonProgress") and workspace:FindFirstChild("dungeonName") and workspace.dungeonProgress.Value and workspace.dungeonName.Value then return "d" end
    warn("Didnt Get Game State")
end

player.CharacterAdded:Connect(function()
    character = player.character or player.characterAdded:Wait()
    HRP = character:WaitForChild("HumanoidRootPart")
end)

local function getAbility(keybind)
    if not character then
        warn("waiting for player")
        player.CharacterAdded:Wait()
        task.wait(0.1)
    end

    for _,item in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
        if item:FindFirstChild("abilitySlot") then
            if item.abilitySlot.Value == keybind then
                return item
            end
        end
    end
    return nil
end

local function Teleport(CFrameToTP,mob : boolean)
    if not HRP then return end
    if WaitingToTp == true then return end
    local bodyPosition = HRP:FindFirstChildOfClass("BodyPosition")
    local bodyGyro = HRP:FindFirstChildOfClass("BodyGyro")
    local offset = 6
    if mob then
        offset = normalOffset
    else
        offset = bossOffset
    end

    if not bodyGyro then
        bodyGyro = Instance.new("BodyGyro") 
        bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
        bodyGyro.CFrame = HRP.CFrame
        bodyGyro.D = 500
        bodyGyro.Parent = HRP
    end

    if not bodyPosition then
        bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(400000, 400000, 400000)
        bodyPosition.Position = CFrameToTP.Position
        bodyPosition.D = 300
        bodyPosition.Parent = HRP
        HRP.Velocity = Vector3.zero
    end

    local oldTime = tick()
    WaitingToTp = true
    HRP.Anchored = false

    repeat task.wait()
            if character:FindFirstChild("HumanoidRootPart") and bodyPosition ~= nil and bodyGyro ~= nil then
                character:PivotTo(CFrame.new(CFrameToTP.Position + Vector3.new(0,offset , 0)) * CFrame.Angles(math.rad(-90), 0, 0))
                bodyPosition.Position = CFrameToTP.Position + Vector3.new(0, offset, 0)
                bodyGyro.CFrame = CFrame.new(character:GetPivot().Position, CFrameToTP.Position) * CFrame.Angles(math.rad(-90), 0, 0)
            end 
    until tick() - oldTime >= 2 or not character:FindFirstChild("HumanoidRootPart")

    WaitingToTp = false

    if character:FindFirstChild("HumanoidRootPart") then
        HRP.Anchored = true
        bodyPosition:Destroy()
    end
end

local function getPlayerGear()
    local gear = {}
    gear["Helmet"] = nil
    gear["Chestplate"] = nil
    gear["Weapon"] = character.GearCache:GetChildren()[1]
    gear["Q"] = getAbility("q")
    gear["E"] = getAbility("e")
    return gear
end

local function fireAbility(keybind : string)
    --[[if keybind == "e" then
    vim:SendKeyEvent(true,Enum.KeyCode.E,false,nil)
    task.wait(0.1)
    vim:SendKeyEvent(false,Enum.KeyCode.E,false,nil)
    elseif keybind == "q" then
        vim:SendKeyEvent(true,Enum.KeyCode.Q,false,nil)
        task.wait(0.1)
        vim:SendKeyEvent(false,Enum.KeyCode.Q,false,nil)
    else
        warn("unknown keybind")
    end]]
    local abilityObject = getAbility(keybind)
    if not abilityObject then return end
    abilityObject.spellEvent:FireServer()

end

local function isDungeonStarted()
    if getGameState() == "d" then
        local start = workspace:WaitForChild("start")
        return start:WaitForChild("countdownFinished").Value
    end
    return nil
end

local tab = Window:CreateTab("Testing", "rewind")
tab:CreateSection("Abilities")
local abilityDropdown = tab:CreateDropdown({
        Name = "Choose Ability",
        Options = {getAbility("e").Name,getAbility("q").Name},
        CurrentOption = {"None Selected"},
        MultipleOptions = false,
        Flag = "PlantToRemove", 
        Callback = function(Option)
            abilityDebug = Option[1]
        end,
})



tab:CreateButton({
    Name = "Refresh Ability Selection",
    Callback = function()
        abilityDropdown:Refresh({getAbility("e").Name,getAbility("q").Name})
    end,
})

tab:CreateButton({
    Name = "Fire Ability",
    Callback = function()
        if abilityDebug then
            fireAbility(player:WaitForChild("Backpack"):FindFirstChild(abilityDebug).abilitySlot.Value)
        else
            Rayfield:Notify({
                Title = "No ability selected!",
                Content = "Please select an ability",
                Duration = 5,
                Image = 0
            })
        end
    end,
})
tab:CreateSection("Testing")
tab:CreateButton({
    Name = "Get Game State",
    Callback = function()
        Rayfield:Notify({
            Title = "Got Game State!",
            Content = "Game State: "..getGameState(),
            Duration = 5,
            Image = 0
        })
    end,
})
tab:CreateSection("Auto Farm")
local autoFarmToggle = tab:CreateToggle({
    Name = "Auto Farm Toggle",
    CurrentValue = auto_farm,
    Callback = function(state)
        warn("Toggle Farm Set To: "..tostring(state))
        auto_farm = state
        if not state then
            warn("Stopping Auto Farm")
            HRP.Anchored = false
            local bodyPosition = HRP:FindFirstChildOfClass("BodyPosition")
            local bodyGyro = HRP:FindFirstChildOfClass("BodyGyro")
            if bodyGyro and bodyPosition then
                bodyGyro:Destroy()
                bodyPosition:Destroy()
            end
        end
    end,
})

tab:CreateKeybind({
   Name = "Auto Attack Toggle Keybind: ",
   CurrentKeybind = "K",
   HoldToInteract = false,
   Flag = "Keybind1",
   Callback = function(Keybind)
        warn("Toggled shouldClick to: "..tostring(not shouldClick))
        shouldClick = not shouldClick
        
   end,
})

tab:CreateKeybind({
    Name = "Keybind for debugging kicks: ",
    CurrentKeybind = "N",
    HoldToInteract = false,
    Flag = "KickKeybind",
    Callback = function(Keybind)
            Rayfield:Notify({
            Title = "Player Kicked 2",
            Content = "Reason: Pressed "..tostring(Keybind),
            Duration = 10,
            Image = 0
        })
        game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
    end,
})

local autoRejoinToggle = tab:CreateToggle({
    Name = "Auto Rejoin",
    CurrentValue = autoRejoin,
    Callback = function(state)
        autoRejoin = state
    end,
})

local function isGregg()
local dungeon = workspace:FindFirstChild("dungeon")
    if not dungeon then return {} end
    for _,child in pairs(dungeon:GetChildren()) do
        if child:FindFirstChild("enemyFolder") then
            if child.enemyFolder:FindFirstChild("Gregg")  then
                for _,child2 in pairs(child.enemyFolder:GetChildren()) do
                    if child2.Name == "Gregg" and child2:IsA("Model") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function getGregg()
    if greggFound and greggFoundTime and isGregg() then
        greggPassed = tick() - greggFoundTime
        if greggPassed > 100 then
                Rayfield:Notify({
                Title = "Player Kicked 3",
                Content = "Reason: Gregg passed for more than 100 seconds",
                Duration = 10,
                Image = 0
            })
            game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
        end
    end
    local dungeon = workspace:FindFirstChild("dungeon")
    if not dungeon then return {} end
    for _,child in pairs(dungeon:GetChildren()) do
        if child:FindFirstChild("enemyFolder") then
            if child.enemyFolder:FindFirstChild("Gregg")  then
                for _,child2 in pairs(child.enemyFolder:GetChildren()) do
                    if child2.Name == "Gregg" and child2:IsA("Model") then
                        if not greggFound then
                            greggFoundTime = tick()
                            greggFound = true
                        end
                        return child2
                    end
                end
            end
        end
    end
    return nil
end

local function getBoss()
    if workspace:FindFirstChild("Azrallik's Heart") then
        warn("Found The Heart, Returning It!")
        return workspace:FindFirstChild("Azrallik's Heart")
    end
    if bossFound then
        bossPassed = tick() - bossFoundTime
        if bossPassed > maxBoss then
                Rayfield:Notify({
                Title = "Player Kicked 4",
                Content = "Reason: Boss Passed For More Than 100 Seconds",
                Duration = 10,
                Image = 0
            })
            game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
        end
    end
    local dungeon = workspace:FindFirstChild("dungeon")
    if not dungeon then return {} end
    for _,child in pairs(dungeon:GetChildren()) do
        if child.Name == "bossRoom" then
            if child:FindFirstChild("enemyFolder") then
                for _,child in pairs(child.enemyFolder:GetChildren()) do
                    if child:IsA("Model") then 
                        if not bossFound then
                            bossFoundTime = tick()
                            bossFound = true
                        end
                        child.AncestryChanged:Connect(function(child,parent)
                            if not parent then
                                task.wait()
                                bossFound = false
                                bossPassed = 0
                                Rayfield:Notify({
                                    Title = "Boss Killed",
                                    Content = "Boss Killed",
                                    Duration = 5,
                                    Image = 0

                                })

                            end
                        end)
                        return child 
                    end
                end
            end
        end
    end
    return nil
end

local function getEnemies()
    if getBoss() then return {} end
    if getGregg() then return {} end
    local dungeon = workspace:FindFirstChild("dungeon")
    if not dungeon then return {} end

    local roomPath = dungeon:FindFirstChild("room" .. roomIndex)
    roomIterations += 1
    if roomIterations % 10 == 0 then
        warn("Iterations: "..roomIterations)
    end
    if roomIterations % 100 == 0 then
        Rayfield:Notify({
            Title = "Passed 100 Room Iterations",
            Content = "Debugging Purposes",
            Duration = 5,
            Image = 0
        })
    end
    if roomIterations > maxIterations then
            Rayfield:Notify({
            Title = "Player Kicked 5",
            Content = "Reason: Max Room Iterations Hit",
            Duration = 10,
            Image = 0
        })
        game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
    end
    if not roomPath then
        dungeonFinished = true
        notifier +=1
        if notifier > 250 then
            Rayfield:Notify({
                Title = "Max Iterations",
                Content = "Iteration: "..notifier,
                Duration = 5,
                Image = 0
            })
            game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
        end
        Rayfield:Notify({
            Title = "Dungeon Finished",
            Content = "Retrying!",
            Duration = 5,
            Image = 0,
        })
        dataRemote:FireServer(
    {
        {
            ["\3"] = "vote",
            vote = true
        },
        "/"
    }
    )
        return {}
    end
    local enemiesFolder = roomPath:FindFirstChild("enemyFolder")
    local enemies = {}
    if enemiesFolder then
        for _, enemy in pairs(enemiesFolder:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") then
                table.insert(enemies, enemy)
            end
        end
    end
    if #enemies > 0 then
        return enemies
    else
        task.wait(3)
        if roomIndex < 15 then
            roomIndex += 1
            roomIterations = 0
            if webhookToggle then
                local data = {
                    embeds = {
                        {
                            title = "Dungeon Quest Auto Farm Log",
                            description = "Room Completed Successfully!",
                            color = 65280,
                            fields = {
                                {
                                    name = "Current Room",
                                    value = tostring(roomIndex),
                                    inline = true
                                }
                            },
                            footer = {
                                text = "Auto farm tracker"
                            }
                        }
                    }
                }
                local jsonData = game:GetService("HttpService"):JSONEncode(data)
                local success,err = pcall(function()
                    game:GetService("HttpService"):PostAsync(webhookURL, jsonData, Enum.HttpContentType.ApplicationJson)
                end)
                if not success then
                    warn("Error: "..err)
                end
            end
            return getEnemies()
        else
            if webhookToggle then
                local data = {
                    embeds = {
                    {
                        title = "ERROR",
                        description = "Returning To Lobby To Restart",
                        color = 16711680,
                        fields = {
                            {
                                name = "At Error, Room Index Was:",
                                value = tostring(roomIndex),
                                inline = true
                            }
                        },
                        footer = {
                            text = "Auto farm tracker"
                        }
                    }
                    }
                }
                local jsonData = game:GetService("HttpService"):JSONEncode(data)
                local success,err = pcall(function()
                    game:GetService("HttpService"):PostAsync(webhookURL, jsonData, Enum.HttpContentType.ApplicationJson)
                end)
                if not success then
                    warn("Error: "..err)
                end
            end 
            Rayfield:Notify({
                Title = "Player Kicked 6",
                Content = "Reason: Reached Dungeon End",
                Duration = 10,
                Image = 0
            })
            game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
            return {}
        end
    end
end


local function getMiddlePositionFromList(list)
    local count = 0
    local averageVector = Vector3.zero
    for _,child in pairs(list) do
        if child:IsA("Model") then
            if child:FindFirstChild("HumanoidRootPart") then
                count += 1
                averageVector += child.HumanoidRootPart.Position
            end
        end
    end
    if count == 0 then return Vector3.zero end
    return averageVector / count
end

local function getClosestEnemy(list,position)
    local closest = nil
    local closestDistance = math.huge
    for _,child in pairs(list) do
        if child:IsA("Model") then
            if child:FindFirstChild("HumanoidRootPart") then
                if (child.HumanoidRootPart.Position - position).Magnitude < closestDistance then
                    closestDistance = (child.HumanoidRootPart.Position - position).Magnitude
                    closest = child
                end
            end
        end
    end
    return closest
end

local function fireWeapon()
    if WeaponModule.Init then
        WeaponModule.Init()
    end
    WeaponModule.Attack()
end

local function click() 
    if shouldClick and not clicking then
        clicking = true
        vim:SendMouseButtonEvent(0,0, 0, true, game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(0,0, 0, false, game, 0)
        clicking = false
        return
    end
    return
end

        tab:CreateSlider({
           Name = "Regular Mob HumanoidRootPart Offset",
           Range = {2, 50},
           Increment = 1,
           Suffix = "studs",
           CurrentValue = 30,
           Flag = "RegularOffset",
           Callback = function(Value)
           normalOffset = Value
           end,
    })

tab:CreateSlider({
    Name = "Boss HumanoidRootPart Offset",
    Range = {2, 50},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 30,
    Flag = "BossOffset",
    Callback = function(Value)
        bossOffset = Value
    end,
})

tab:CreateSection("Discord Webhook")
local Input = tab:CreateInput({
   Name = "Discord Webhook, paste URL here: ",
   CurrentValue = "",
   PlaceholderText = "<Webhook URL>",
   RemoveTextAfterFocusLost = false,
   Flag = "DiscordWebhook",
   Callback = function(Text)
   webhookURL = Text
   end,
})

tab:CreateButton({
    Name = "Test Webhook Print",
    Callback = function()
        local data = {
            content = "Hello, this is a test message from Roblox!"
        }
        local jsonData = game:GetService("HttpService"):JSONEncode(data)
        local success,err = pcall(function()
            game:GetService("HttpService"):PostAsync(webhookURL, jsonData, Enum.HttpContentType.ApplicationJson)
        end)
        if not success then
            Rayfield:Notify({
                Title = "Webhook Error",
                Content = "Error: "..err,
                Duration = 5,
                Image = 0
            })
        end
    end,

})

tab:CreateToggle({
    Name = "Webhook Toggle",
    CurrentValue = webhookToggle,
    Flag = "Webhook_Toggle",
    Callback = function(state)
        webhookToggle = state
    end,
})

local function enterDungeon(Name,Difficulty)
    local args = {
        {
            {
                "\1",
                {
                    ["\3"] = "PlaySolo",
                    partyData = {
                        difficulty = Difficulty, -- Example: "Easy"
                        mode = "Normal",
                        dungeonName = Name, -- Example: "Desert Temple"
                        tier = 1
                    }
                }
            },
            "d"
        }
    }

    dataRemote:FireServer(unpack(args))

end

local function startDungeon()
    changeStartValueRemote:FireServer()
end

-- AUTO FARM --
spawn(function()
    while true do
        task.wait(0.1)
        if auto_farm then
            if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
                vim:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, nil)
                task.wait(0.1)
                vim:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, nil)
            end
            if not character then continue end
            if getGameState() == "G" then
                if autoRejoin then
                    enterDungeon(wantedDungeon, wantedDifficulty)
                end
            end
            if not isDungeonStarted() then
                startDungeon()
                task.wait(10)
            end
            local boss = getBoss()
            local Gregg = getGregg()
            if Gregg then
                task.spawn(function()
                    local GreggHRP = Gregg:FindFirstChild("HumanoidRootPart")
                    if GreggHRP then
                        Teleport(Gregg:WaitForChild("HumanoidRootPart").CFrame,false)
                        warn("Teleporting Gregg")
                    end
                end)
                fireWeapon()
                task.spawn(fireAbility, "e")
                task.spawn(fireAbility, "q")
            elseif boss then
                task.spawn(function()
                    local bossHRP = boss:FindFirstChild("HumanoidRootPart")
                    if bossHRP then
                        warn("Teleporting Boss HRP")
                        Teleport(boss:FindFirstChild("HumanoidRootPart").CFrame,false)
                    else
                        warn("Teleporting Boss Pivot")
                        Teleport(boss:GetPivot(),false)
                    end
                end)
                fireWeapon()
                task.spawn(fireAbility, "e")
                task.spawn(fireAbility, "q")
            else
                local enemies = getEnemies()
                if #enemies == 0 then warn("No Enemies Found!, Room Index Is: "..roomIndex);continue end
                local midPos = getMiddlePositionFromList(enemies)
                if midPos and midPos == Vector3.zero then warn("No Mid Position Found, no enemies?"); continue end
                local closestEnemy = getClosestEnemy(enemies,midPos)
                if not closestEnemy then warn("Couldnt find closest enemy"); continue end
                task.spawn(function()
                    Teleport(closestEnemy:WaitForChild("HumanoidRootPart").CFrame,true)
                    warn("Teleporting Enemy")
                end)
                fireWeapon()
                task.spawn(fireAbility, "e")
                task.spawn(fireAbility, "q")
            end
        else
            task.wait(1)
        end

    end
end)

-- anti kick
game:GetService("LogService").MessageOut:Connect(function(msg,msgtype)
    if msgtype == Enum.MessageType.MessageError and msg == "" then
        game:GetService("TeleportService"):Teleport(2414851778,game:GetService("Players").LocalPlayer)
    end
end)

Rayfield:LoadConfiguration()
--[[notes
1: there is localplayer.teleporting , might need to set it to true to bypass teleport anti cheat
2: weapon is in character.weapongear(still dont have armor to test if the armor is there too)]] 