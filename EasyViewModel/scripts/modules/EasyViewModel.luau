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
		The maximum distance the viewmodel can be from the client's
		camera. When set to -1 or anything less than 1, the max distance
		is set to 1.

		Default = 1.
	--]]
	MaxDistance: number;

	--[[
	  The speed at which the viewmodel follows
	  the player's camera. Setting this to -1
		or anything less than 0 will result in
		the ViewModel being instantaneously set
		to the camera's position.

		Default = 0
	--]]
	LerpSpeed: number;
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
	--]] 	
	StartViewModelRuntime: (Offset: Number) -> nil,

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
		Updates the offset that is applied to the viewmodel.
	--]]
	UpdateViewModelOffset: (Offset: number) -> nil,

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

-- Bindable Events
local EndRuntime: BindableEvent = script.EndRuntime
local UpdateOffset: BindableEvent = script.UpdateOffset

@native
local function SpringLerpVec3(Curr: Vector3, Target: Vector3, Velocity: Vector3, Stiffness: number, DeltaTime: number): (Vector3, Vector3)
	  local Displacement = Curr - Target
    local SpringAccel = -Stiffness * Displacement - 2 * math.sqrt(Stiffness) * Velocity
    Velocity += SpringAccel * DeltaTime
    Curr += Velocity * DeltaTime
    return Curr, Velocity
end

local function SetAlphas(Instances: {Instance}, Alpha: number): nil
	for _, instance: Instance in ipairs(Instances) do
		instance.Color.A = Alpha
	end
end

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
	UsedViewModel.Parent = world.Environment.Camera
	UsedViewModel.Position = Vector3.Zero
	UsedViewModel.Quaternion = Quaternion.Identity
	DefaultPartAlphas = GetAlphas(UsedViewModel:GetDescendants())
	return true
end

function EVM.SetConfig(Config: EVMConfig): boolean?
	Configuration.LerpSpeed = if Config.LerpSpeed or Config.LerpSpeed < 0 then Config.LerpSpeed else 0
	Configuration.MaxDistance = if Config.MaxDistance or Config.MaxDistance < 0 then Config.MaxDistance else 1
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

function EVM.StartViewModelRuntime(Offset: number): nil
	local ClientCam: Camera = world.Environment.Camera
	local Descendants: {Instance} = UsedViewModel:GetDescendants()
	local NewPartAlphas: {[string]: number} = GetAlphas(Descendants)
	
	local SwayOffset: Vector3 = Vector3.Zero
	local VelocityViewModel: Vector3 = Vector3.Zero
	local ViewModelPosition: Vector3 = Vector3.Forward * Offset
	local ViewModelQuaternion: Quaternion = Quaternion.Identity

	local PreRenderedConnection: PTSignalConnection = Hooks.PostRendered:Connect(function(DeltaTime: number)
		DeltaTime = math.min(DeltaTime, 1/30)
		
		if RuntimePaused then
			if HideViewModelWhenPaused then UsedViewModel.Parent = world.Hidden end
		elseif UsedViewModel.Parent == world.Hidden and not (Configuration.InvisibleInThirdPerson and not ClientCam.IsFirstPerson) then
			UsedViewModel.Parent = ClientCam
		end
		
		if Configuration.InvisibleInThirdPerson and not ClientCam.IsFirstPerson then
			if Configuration.InvisibleSpeed > 0 then
				print("making alpha transparent")
				local Alpha: number = math.exp(-Configuration.InvisibleSpeed * DeltaTime)
				LerpAlphas(Descendants, 0, Alpha)
				NewPartAlphas = GetAlphas(Descendants)
			else
				UsedViewModel.Parent = world.Hidden
			end
			return
		elseif ClientCam.IsFirstPerson then
			if UsedViewModel.Parent == world.Hidden then
				UsedViewModel.Parent = ClientCam
			elseif Configuration.InvisibleSpeed > 0 and not CheckIfMatching(DefaultPartAlphas, NewPartAlphas) then
				print("making alpha normal")
				local Alpha: number = 1 - math.exp(-Configuration.InvisibleSpeed * DeltaTime)
				for _, instance: Instance in ipairs(Descendants) do
					if not instance.Color then continue end
					local lerped: number = math.lerp(instance.Color.A, DefaultPartAlphas[instance.NetworkedObjectID], Alpha)
					instance.Color = Color.New(instance.Color.R, instance.Color.G, instance.Color.B, lerped)
				end
			end
		end
		
		if Configuration.LerpSpeed > 0 then
			local Alpha: number = 1 - math.exp(-Configuration.LerpSpeed * DeltaTime)

			local TargetPos: Vector3 = Vector3.Forward * Offset
			local TargetQuat: Quaternion = Quaternion.Identity

			ViewModelQuaternion = Quaternion.Slerp(
				UsedViewModel.LocalQuaternion,
				TargetQuat,
				Alpha
			)

			ViewModelPosition, VelocityViewModel = SpringLerpVec3(
				ViewModelPosition, 
				TargetPos, 
				VelocityViewModel, 
				Configuration.LerpSpeed,
				DeltaTime
			)

			local Direction: Vector3 = TargetPos - ViewModelPosition
			if Direction.Magnitude > Configuration.MaxDistance then
				Direction = Direction.Normalized * (Direction.Magnitude - Configuration.MaxDistance)
				ViewModelPosition += Direction
				VelocityViewModel = Vector3.Zero
			end

		end
		
		UsedViewModel.LocalPosition = ViewModelPosition
		UsedViewModel.LocalQuaternion = ViewModelQuaternion
	end)

	local UpdateOffsetConnection: PTSignalConnection = UpdateOffset.Invoked:Connect(function(NewOffset: number)
		Offset = NewOffset
	end)

	local EndRuntimeConnection: PTSignalConnection
	EndRuntimeConnection = EndRuntime.Invoked:Connect(function()
		UsedViewModel:Destroy()
		UsedViewModel = nil

		Configuration = nil
		RuntimePaused = false
		HideViewModelWhenPaused = false

		PreRenderedConnection:Disconnect()
		UpdateOffsetConnection:Disconnect()
		EndRuntimeConnection:Disconnect()
	end)

end

function EVM.ToggleViewModelRuntime(HideViewModel: boolean?): nil
	RuntimePaused = not RuntimePaused
	if HideViewModel then
		HideViewModelWhenPaused = HideViewModel
	end
end

function EVM.UpdateViewModelOffset(Offset: number): nil
	UpdateOffset.Invoke(Offset)
end

function EVM.EndViewModelRuntime(): nil
	EndRuntime.Invoke()
end

function EVM.GetViewModel(): Instance
	return UsedViewModel
end

return EVM 
