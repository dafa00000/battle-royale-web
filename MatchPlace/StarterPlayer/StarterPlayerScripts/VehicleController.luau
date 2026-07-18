--[[
	VehicleController - Client vehicle interaction, camera, HUD
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Util = require(Shared.Util)

local HUD = require(script.Parent.UI.HUD)

local VehicleController = {}

local LocalPlayer = Players.LocalPlayer
local character: Model?
local humanoid: Humanoid?

local currentVehicle: Model?
local currentSeat: VehicleSeat?
local vehicleCameraOffset = CFrame.new(0, 5, 12)
local isDriving = false

function VehicleController.Initialize(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")

	VehicleController.SetupInput()
	VehicleController.SetupReplication()

	print("[VehicleController] Initialized")
end

function VehicleController.SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Constants.DEFAULT_KEYBINDS.Interact then
			VehicleController.TryInteractVehicle()
		end
	end)
end

function VehicleController.SetupReplication()
	ReplicatedStorage.Remotes.MatchRemotes.VehicleUpdate.OnClientEvent:Connect(function(data)
		VehicleController.OnVehicleUpdate(data)
	end)

	ReplicatedStorage.Remotes.MatchRemotes.VehicleEnter.OnClientEvent:Connect(function(data)
		VehicleController.OnVehicleEnter(data)
	end)

	ReplicatedStorage.Remotes.MatchRemotes.VehicleExit.OnClientEvent:Connect(function(data)
		VehicleController.OnVehicleExit(data)
	end)
end

function VehicleController.TryInteractVehicle()
	if isDriving then
		VehicleController.ExitVehicle()
		return
	end

	-- Find nearest vehicle seat
	local nearestSeat: VehicleSeat?
	local nearestDist = 10

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("VehicleSeat") and not obj.Occupant then
			local dist = (obj.Position - character.HumanoidRootPart.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearestSeat = obj
			end
		end
	end

	if nearestSeat then
		local vehicle = nearestSeat:FindFirstAncestorOfClass("Model")
		if vehicle then
			VehicleController.EnterVehicle(vehicle, nearestSeat)
		end
	end
end

function VehicleController.EnterVehicle(vehicle: Model, seat: VehicleSeat)
	local vehicleId = vehicle:GetAttribute("VehicleId") or vehicle.Name

	local success = ReplicatedStorage.Remotes.MatchRemotes.VehicleEnterRequest:InvokeServer({
		VehicleId = vehicleId,
		SeatIndex = 0, -- Driver seat
	})

	if success then
		currentVehicle = vehicle
		currentSeat = seat
		isDriving = true
		VehicleController.SetupVehicleCamera()
		HUD.SetVehicleVisible(true)
	end
end

function VehicleController.ExitVehicle()
	if not currentVehicle then return end

	local vehicleId = currentVehicle:GetAttribute("VehicleId") or currentVehicle.Name

	local exitPosition = character.HumanoidRootPart.Position + Vector3.new(3, 0, 0)
	local success = ReplicatedStorage.Remotes.MatchRemotes.VehicleExitRequest:InvokeServer({
		VehicleId = vehicleId,
		ExitPosition = exitPosition,
	})

	if success then
		VehicleController.RestoreCamera()
		currentVehicle = nil
		currentSeat = nil
		isDriving = false
		HUD.SetVehicleVisible(false)
	end
end

function VehicleController.SetupVehicleCamera()
	-- Switch to vehicle chase camera
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	RunService:BindToRenderStep("VehicleCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if not currentVehicle or not currentVehicle.PrimaryPart then return end

		local vehicleCF = currentVehicle.PrimaryPart.CFrame
		local targetPos = vehicleCF * vehicleCameraOffset.Position
		local lookAt = vehicleCF.Position + vehicleCF.LookVector * 10

		camera.CFrame = CFrame.lookAt(targetPos, lookAt)
	end)
end

function VehicleController.RestoreCamera()
	RunService:UnbindFromRenderStep("VehicleCamera")
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
end

function VehicleController.OnVehicleUpdate(data)
	-- Update vehicle HUD: speed, fuel, health
	if data.vehicleId and currentVehicle and data.vehicleId == currentVehicle:GetAttribute("VehicleId") then
		HUD.UpdateVehicleHUD(data.speed or 0, data.fuel or 100, data.health or 100)
	end
end

function VehicleController.OnVehicleEnter(data)
	if data.player == LocalPlayer then
		-- Confirmed enter
		isDriving = true
	end
end

function VehicleController.OnVehicleExit(data)
	if data.player == LocalPlayer then
		isDriving = false
		currentVehicle = nil
		VehicleController.RestoreCamera()
	end
end

function VehicleController.GetVehicleInputs(): { throttle: number, steer: number, brake: number, handbrake: boolean }
	if not isDriving then return { throttle = 0, steer = 0, brake = 0, handbrake = false } end

	local throttle = 0
	local steer = 0
	local brake = 0
	local handbrake = false

	if UserInputService:IsKeyDown(Constants.DEFAULT_KEYBINDS.MoveForward) then
		throttle = 1
	elseif UserInputService:IsKeyDown(Constants.DEFAULT_KEYBINDS.MoveBackward) then
		brake = 1
	end

	if UserInputService:IsKeyDown(Constants.DEFAULT_KEYBINDS.MoveLeft) then
		steer = -1
	elseif UserInputService:IsKeyDown(Constants.DEFAULT_KEYBINDS.MoveRight) then
		steer = 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		handbrake = true
	end

	return { throttle = throttle, steer = steer, brake = brake, handbrake = handbrake }
end

function VehicleController.Cleanup()
	VehicleController.RestoreCamera()
end

return VehicleController
