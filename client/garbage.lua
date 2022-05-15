--Devyn Sanitation https://github.com/devin-monro/devyn-sanitation

local QBCore = exports["qb-core"]:GetCoreObject()
local DoingGarbageRoute = false
local HasBag = false
local BagObject = nil
local pickupLocation = vector3(0.0, 0.0, 0.0)
local Truck = nil


RegisterNetEvent("garbage:attemptStart", function()
    if exports["ps-playergroups"]:IsGroupLeader() then 
        if exports["ps-playergroups"]:GetJobStage() == "WAITING" then
            local groupID = exports["ps-playergroups"]:GetGroupID()
            
            local model = GetHashKey("trash")
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(0)
            end

            TriggerServerEvent("garbage:createGroupJob", groupID)
        else 
            QBCore.Functions.Notify("Your group is already doing something!", "error")
        end
    else 
        QBCore.Functions.Notify("You are not the group leader!", "error")
    end
end)

RegisterNetEvent("garbage:attemptStop", function()
    if exports["ps-playergroups"]:IsGroupLeader() then 
        if exports["ps-playergroups"]:GetJobStage() == "GARBAGE RUN" then
            local groupID = exports["ps-playergroups"]:GetGroupID()
            TriggerServerEvent("garbage:stopGroupJob", groupID)
        else 
            QBCore.Functions.Notify("Your group isn't doing a run!", "error")
        end
    else 
        QBCore.Functions.Notify("You are not the group leader!", "error")
    end
end)

RegisterNetEvent("garbage:startRoute", function(truckID)
    Truck = NetworkGetEntityFromNetworkId(truckID)
    exports['qb-target']:AddGlobalVehicle({
        options = { 
        {

            icon = 'fas fa-trash-alt',
            label = 'Toss Trash',
            action = function(entity) 
                TossTrash()
            end,   
            canInteract = function(entity, distance, data)
                if entity == Truck and HasBag then return true end 
                return false
            end,
            }
        },
        distance = 2.5,
    })

    RouteGarbageLoop()
end)

RegisterNetEvent("garbage:endRoute", function()
   -- exports['qb-target']:RemoveGlobalVehicle("Toss Trash")
    DoingGarbageRoute = false
    HasBag = false
    BagObject = nil
    Truck = nil
    pickupLocation = vector3(0.0, 0.0, 0.0)
    DetachEntity(BagObject, 1, false)
    DeleteObject(BagObject)
    BagObject = nil
end)

RegisterNetEvent("garage:pickupClean", function()
    DetachEntity(BagObject, 1, false)
    DeleteObject(BagObject)
    BagObject = nil
end)

RegisterNetEvent("garbage:updatePickup", function(coords)
    pickupLocation = coords
end)

function RouteGarbageLoop()
    DoingGarbageRoute = true
    local sleep = 2000
    CreateThread(function()
        while DoingGarbageRoute do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local Distance = #(pos - vector3(pickupLocation.x, pickupLocation.y, pickupLocation.z))
            local DisplayText = false
            if Distance < 15 then 
                sleep = 0
                LoadAnimation('missfbi4prepp1')
               -- DrawMarker(27, pickupLocation.x, pickupLocation.y, pickupLocation.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 100, 245, 195, 255, false, false, false, false, false, false, false)
                if Distance < 1.5 then
                    if not DisplayText and not HasBag then
                        DisplayText = true
                        exports['qb-core']:DrawText("[E] Grab Trash", "left")
                    end
                    if IsControlJustPressed(0, 51) then
                        HasBag = true
                        exports['qb-core']:HideText()
                        TakeBagAnim()
                    end
                elseif Distance > 1.5 then
                    if DisplayText then
                        DisplayText = false
                        exports['qb-core']:HideText()
                    end
                end
            else 
                sleep = 2000
            end

            Wait(sleep)
        end
    end)
end


function LoadAnimation(dict)
    RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do Wait(10) end
end

function AnimBagCheck()
    CreateThread(function()
        while HasBag do
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 3) then
                ClearPedTasksImmediately(ped)
                LoadAnimation('missfbi4prepp1')
                TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
            end
            Wait(200)
        end
    end)
end

function TakeBagAnim()
    local ped = PlayerPedId()
    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
    BagObject = CreateObject(`prop_cs_rub_binbag_01`, 0, 0, 0, true, true, true)
    AttachEntityToEntity(BagObject, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
    AnimBagCheck()
end

function DeliverBagCheck()
    local ped = PlayerPedId()
    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
    FreezeEntityPosition(ped, true)
    SetTimeout(1250, function()
        DetachEntity(BagObject, 1, false)
        DeleteObject(BagObject)
        TaskPlayAnim(ped, 'missfbi4prepp1', 'exit', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
        FreezeEntityPosition(ped, false)
        BagObject = nil
    end)
end

function TossTrash()
    QBCore.Functions.Progressbar("deliverbag", "Tossing Trash", 2000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        HasBag = false
        DeliverBagCheck()
        Wait(1500)
        TriggerServerEvent("garbage:updateBags", exports["ps-playergroups"]:GetGroupID())
    end, function() -- Cancel
       
    end)
end


CreateThread(function()
    local garbageBlip = AddBlipForCoord(Garbage.Blip)
    SetBlipSprite(garbageBlip, 318)
    SetBlipDisplay(garbageBlip, 4)
    SetBlipScale(garbageBlip, 0.7)
    SetBlipAsShortRange(garbageBlip, true)
    SetBlipColour(garbageBlip, 2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Sanitation")
    EndTextCommandSetBlipName(garbageBlip)
end)

CreateThread(function()
    Creategarbagepeds()
end)

CreateThread(function()
    exports['qb-target']:AddBoxZone("startGarbagejob", Garbage.PedList[1].coords, 1, 1, {
        name="startGarbagejob",
        heading=Garbage.PedList[1].heading,
        debugPoly=false,
        minZ=Garbage.PedList[1].minZ,
        maxZ=Garbage.PedList[1].maxZ,
    }, {
        options = {
            {
                type = "client",
                event = "garbage:attemptStart",
                label = 'Start Garbage Run',
                icon = 'fa-solid fa-circle',
                canInteract = function()
                    if DoingGarbageRoute then return false end
                    return true
                end,
            },
            {
                type = "client",
                event = "garbage:attemptStop",
                label = 'Complete Garbage Run',
                icon = 'fa-solid fa-circle',
                canInteract = function()
                    if DoingGarbageRoute then return true end
                    return false
                end,
            },
          },
          distance = 1.5,
    })
end)

local garbagepeds = {}
local shopgarbagepeds = {}

function Creategarbagepeds()
    while true do
        Citizen.Wait(500)
        for k = 1, #Garbage.PedList, 1 do
            v = Garbage.PedList[k]
            local playerCoords = GetEntityCoords(PlayerPedId())
            local dist = #(playerCoords - v.coords)
            if dist < GarbageConfig.Distance and not garbagepeds[k] then
                local ped = nearPed(v.model, v.coords, v.heading, v.gender, v.animDict, v.animName, v.scenario)
                garbagepeds[k] = {ped = ped}
            end
            if dist >= GarbageConfig.Distance and garbagepeds[k] then
                if GarbageConfig.Fade then
                    for i = 255, 0, -51 do
                        Citizen.Wait(50)
                        SetEntityAlpha(garbagepeds[k].ped, i, false)
                    end
                end
                DeletePed(garbagepeds[k].ped)
                garbagepeds[k] = nil
            end
        end
    end
end

function nearPed(model, coords, heading, gender, animDict, animName, scenario)
	RequestModel(GetHashKey(model))
	while not HasModelLoaded(GetHashKey(model)) do
		Citizen.Wait(1)
	end
	if gender == 'male' then
		genderNum = 4
	elseif gender == 'female' then 
		genderNum = 5
	else
		print("No gender provided! Check your configuration!")
	end
	if GarbageConfig.MinusOne then 
		local x, y, z = table.unpack(coords)
		ped = CreatePed(genderNum, GetHashKey(model), x, y, z - 1, heading, false, true)
		table.insert(shopgarbagepeds, ped)
	else
		ped = CreatePed(genderNum, GetHashKey(v.model), coords, heading, false, true)
		table.insert(shopgarbagepeds, ped)
	end
	SetEntityAlpha(ped, 0, false)
	if GarbageConfig.Frozen then
		FreezeEntityPosition(ped, true)
	end
	if GarbageConfig.Invincible then
		SetEntityInvincible(ped, true)
	end
	if GarbageConfig.Stoic then
		SetBlockingOfNonTemporaryEvents(ped, true)
	end
	if animDict and animName then
		RequestAnimDict(animDict)
		while not HasAnimDictLoaded(animDict) do
			Citizen.Wait(1)
		end
		TaskPlayAnim(ped, animDict, animName, 8.0, 0, -1, 1, 0, 0, 0)
	end
	if scenario then
		TaskStartScenarioInPlace(ped, scenario, 0, true)
	end
	if GarbageConfig.Fade then
		for i = 0, 255, 51 do
			Citizen.Wait(50)
			SetEntityAlpha(ped, i, false)
		end
	end
	return ped
end --End of the Jimathy stuff