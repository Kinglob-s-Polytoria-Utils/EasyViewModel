-- what do you even do?
--!native

export type EVMConfig = {
	--[[
		States whether or not the viewmodel should become
		invisible if the player is out of first person.

		Default = true
	--]]
	InvisibleInThirdPerson: boolean;

	--[[
		The speed at which the viewmodel becomes transparent
		when in third person. Ignored if DisappearInThirdPerson
		is set to false. When set to -1 or anything less than 0,
		the viewmodel is instantly made invisible.

		Default = 0
	--]]
	InvisibleSpeed: number;

	--[[
		Whether or not the viewmodel is contained in a UIViewport.
		Do note that this is much more different than a 3D viewmodel.

		Default = false
	--]]
	IsUIViewport: boolean;

	--[[
		Relative size of the viewport.
		Default = (1, 1)	
	--]]
	ViewportSize: Vector2;

	--[[
		Relative position of the viewport.
		Default = (0.5, 0.5)	
	--]]
	ViewportPosition: Vector2;
	
	--[[
		Rotation of the viewport.
		Default = 0
	--]]
	ViewportRotation: number;

	--[[
		Determines the viewport's camera FOV.
		Default = 75
	--]]
	ViewportFOV: Vector2;
};

export type EasyViewModel = {
	--[[
		Sets the viewmodel instance.
		Returns false or nil if it fails.

		Has no default value.
	--]]
	SetViewModel: (Model: Instance) -> boolean?,

	--[[
		Sets the config. Must follow the EVMConfig type.
		Returns false or nil if it fails.
		Persists after ending the viewmodel runtime.

		Has no default value.
	--]]
	SetConfig: (Config: EVMConfig) -> boolean?,

	--[[
		Begins the viewmodel runtime.
		Follows the configuration set by SetConfig.
		Uses the viewmodel set by SetViewModel.

		The config and viewmodel can be updated
		during the runtime.

		PredictateOrientation provides the LocalPosition and LocalQuaternion, and expects you to return
		a Vector3 and Quaternion, in that exact order.

		do note that PredictateOrientation is an optional callback.
	--]] 	
	StartViewModelRuntime: (PredictateOrientation: (LocalPosition: Vector3, LocalQuaternion: Quaternion) -> (Vector3, Quaternion)?) -> nil,

	--[[
		Pauses and unpauses the viewmodel runtime, and does not
		disconnect any events that the runtime uses.
		
		Setting HideViewModel makes the viewmodel hidden
		if the runtime is paused.
	--]]
	ToggleViewModelRuntime: (HideViewModel: boolean?) -> nil,

	--[[
		Completely ends the viewmodel runtime, disconnecting events
		and functions. Clears config and the set viewmodel aswell.
	--]]
	EndViewModelRuntime: () -> nil,

	--[[
		Returns the currently used viewmodel in the runtime.
		This can be used for modifying the viewmodel (Such as
		equpping a gun and placing it in the client's viewmodel),
		or playing an animation on the viewmodel.
	--]]
	GetViewModel: () -> Instance
}

local EVM: EasyViewModel = {} :: EasyViewModel

-- Variables
local UsedViewModel: Instance = nil
local Configuration: EVMConfig = {} :: EVMConfig
local RuntimePaused: boolean = false
local HideViewModelWhenPaused: boolean = false
local DefaultPartAlphas: {[string]: number} = nil
local EVMGUI: GUI = script.EVMGUI

-- Bindable Events
local EndRuntime: BindableEvent = script.EndRuntime

local function GetAlphas(Instances: {Instance}): {[string]: number}
	local alphas: {[string]: number} = table.create(#Instances)

	for _, instance: Instance in ipairs(Instances) do
		if not instance.Color then continue end
		local uniqueID: string = instance.NetworkedObjectID
		alphas[uniqueID] = instance.Color.A
	end

	return alphas
end

function EVM.SetViewModel(Model: Instance): boolean?
	if not Model then return false end
	if not Model:IsA("Instance") then return false end
	UsedViewModel = Model:Clone()
	UsedViewModel.Parent = if Configuration and Configuration.IsUIViewport then EVMGUI.EVMViewport.EVMCamera else world.Hidden
	UsedViewModel.Position = Vector3.Zero
	UsedViewModel.Quaternion = Quaternion.Identity
	DefaultPartAlphas = GetAlphas(UsedViewModel:GetDescendants())
	return true
end

function EVM.SetConfig(Config: EVMConfig): boolean?
	Configuration.IsUIViewport = if Config.IsUIViewport then Config.IsUIViewport else false

	if Configuration.IsUIViewport then
		if EVMGUI.Parent ~= world.PlayerGUI then
			EVMGUI.Parent = world.PlayerGUI
		end
	end
	
	if UsedViewModel and UsedViewModel:IsA("Instance") then
		if Configuration.IsUIViewport then
			UsedViewModel.Parent = EVMGUI.EVMViewport.EVMCamera
		else
			UsedViewModel.Parent = world.Environment.Camera
		end
	end

	Configuration.ViewportFOV = if Config.ViewportFOV then Config.ViewportFOV else 75
	Configuration.ViewportPosition = if Config.ViewportPosition then Config.ViewportPosition else Vector2.New(0.5, 0.5)
	Configuration.ViewportSize = if Config.ViewportSize then Config.ViewportSize else Vector2.New(1, 1)
	Configuration.ViewportRotation = if Config.ViewportRotation then Config.ViewportRotation else 0
	Configuration.InvisibleInThirdPerson = if Config.InvisibleInThirdPerson then Config.InvisibleInThirdPerson else true
	Configuration.InvisibleSpeed = if Config.InvisibleSpeed or Config.InvisibleSpeed < 0 then Config.InvisibleSpeed else 0
	return true
end

local function LerpAlphas(Instances: {Instance}, TargetAlpha: number, Rate: number): nil
	for _, instance: Instance in ipairs(Instances) do
		if not instance.Color then continue end
		local partalpha: number = instance.Color.A
		local lerped: number = math.lerp(partalpha, TargetAlpha, Rate)
		instance.Color = Color.New(instance.Color.R, instance.Color.G, instance.Color.B, lerped)
	end
end

local function CheckIfMatching(AlphaSet1: {[string]: number}, AlphaSet2: {[string]: number}): boolean
	for Key: string, Alpha: number in pairs(AlphaSet1) do
		if AlphaSet2[Key] == Alpha then continue end
		return false
	end
	return true
end

function EVM.StartViewModelRuntime(PredictateOrientation: (LocalPosition: Vector3, LocalQuaternion: Quaternion) -> (Vector3, Quaternion)?): nil
	local ClientCam: Camera = world.Environment.Camera
	if UsedViewModel.Parent == world.Hidden and not Configuration.IsUIViewport then UsedViewModel.Parent = ClientCam end
	local Descendants: {Instance} = UsedViewModel:GetDescendants()
	local NewPartAlphas: {[string]: number} = GetAlphas(Descendants)
	
	local ViewModelPosition: Vector3 = Vector3.Forward
	local ViewModelQuaternion: Quaternion = Quaternion.Identity

	local ClientCamPrevPos: Vector3 = ClientCam.Position
	local ClientCamPrevQuat: Quaternion = ClientCam.Quaternion

	local PreRenderedConnection: PTSignalConnection = Hooks.PreRendered:Connect(function(DeltaTime: number)
		DeltaTime = math.min(DeltaTime, 1/30)
		
		if ClientCamPrevPos == ClientCam.Position and ClientCamPrevQuat == ClientCam.Quaternion then return end
		ClientCamPrevPos = ClientCam.Position
		ClientCamPrevQuat = ClientCam.Quaternion
		
		if RuntimePaused then
			if HideViewModelWhenPaused then UsedViewModel.Parent = world.Hidden end
		elseif UsedViewModel.Parent == world.Hidden and not (Configuration.InvisibleInThirdPerson and not ClientCam.IsFirstPerson) then
			if Configuration.IsUIViewport then
				UsedViewModel.Parent = EVMGUI.EVMViewport.EVMCamera
			else
				UsedViewModel.Parent = ClientCam
			end
		end
		
		if Configuration.InvisibleInThirdPerson and not ClientCam.IsFirstPerson then
			if Configuration.InvisibleSpeed > 0 then
				local Alpha: number = 1 - math.exp(-Configuration.InvisibleSpeed * DeltaTime)
				LerpAlphas(Descendants, 0, Alpha)
				NewPartAlphas = GetAlphas(Descendants)
			else
				UsedViewModel.Parent = world.Hidden
			end
		elseif ClientCam.IsFirstPerson then
			if UsedViewModel.Parent == world.Hidden then
				if Configuration.IsUIViewport then
					UsedViewModel.Parent = EVMGUI.EVMViewport.EVMCamera
				else
					UsedViewModel.Parent = ClientCam
				end
			elseif Configuration.InvisibleSpeed > 0 and not CheckIfMatching(DefaultPartAlphas, NewPartAlphas) then
				local Alpha: number = 1 - math.exp(-Configuration.InvisibleSpeed * DeltaTime)
				for _, instance: Instance in ipairs(Descendants) do
					if not instance.Color then continue end
					local lerped: number = math.lerp(instance.Color.A, DefaultPartAlphas[instance.NetworkedObjectID], Alpha)
					instance.Color = Color.New(instance.Color.R, instance.Color.G, instance.Color.B, lerped)
				end
			end
		end

		if PredictateOrientation then ViewModelPosition, ViewModelQuaternion = PredictateOrientation(ViewModelPosition, ViewModelQuaternion) end
		
		UsedViewModel.LocalPosition = ViewModelPosition
		UsedViewModel.LocalQuaternion = ViewModelQuaternion
	end)

	local EndRuntimeConnection: PTSignalConnection
	EndRuntimeConnection = EndRuntime.Invoked:Connect(function()
		UsedViewModel:Destroy()
		UsedViewModel = nil

		Configuration = nil
		RuntimePaused = false
		HideViewModelWhenPaused = false

		PreRenderedConnection:Disconnect()
		EndRuntimeConnection:Disconnect()
	end)

end

function EVM.ToggleViewModelRuntime(HideViewModel: boolean?): nil
	RuntimePaused = not RuntimePaused
	if HideViewModel then
		HideViewModelWhenPaused = HideViewModel
	end
end

function EVM.EndViewModelRuntime(): nil
	EndRuntime.Invoke()
end

function EVM.GetViewModel(): Instance
	return UsedViewModel
end

return EVM 
