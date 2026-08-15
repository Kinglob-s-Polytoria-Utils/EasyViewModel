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

		Default = -1
	--]]
	InvisibleSpeed: number;
	
	--[[
		The amount of "bounce" the viewmodel has when
		following the player's camera. Anything less than
		zero will mean it instantly snaps towards the player's
		camera.

		Default = -1
	--]]
	Bounciness: number;

	--[[
	  The speed at which the viewmodel follows
	  the player's camera. Setting this to -1
		or anything less than 0 will result in
		the ViewModel being instantaneously set
		to the camera's position.

		Default = -1
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
	StartViewModelRuntime: () -> nil,

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

-- Bindable Events
local EndRuntime: BindableEvent = script.EndRuntime
local UpdateOffset: BindableEvent = script.UpdateOffset

function EVM.SetViewModel(Model: Instance): boolean?
	if not Model then return false end
	if not Model:IsA("Instance") then return false end
	UsedViewModel = Model:Clone()
	return true
end

function EVM.SetConfig(Config: EVMConfig): boolean?
	Configuration.Bounciness = if Config.Bounciness then Config.Bounciness else -1
	Configuration.LerpSpeed = if Config.LerpSpeed then Config.LerpSpeed else -1
	Configuration.InvisibleInThirdPerson = if Config.InvisibleInThirdPerson then Config.InvisibleInThirdPerson else true
	Configuration.InvisibleSpeed = if Config.InvisibleSpeed then Config.InvisibleSpeed else -1
	return true
end

function EVM.StartViewModelRuntime(Offset: number): nil
	local ClientCam: Camera = world.Environment.Camera

	local PreRenderedConnection: PTSignalConnection = Hooks.PreRendered:Connect(function(DeltaTime: number)
		local OffsetToApply: Vector3 = Offset * ClientCam.Forward
		local ViewModelQuaternion: Quaternion = ClientCam.Quaternion
		local ViewModelPosition: Vector3 = ClientCam.Position

		if RuntimePaused then
			if HideViewModelWhenPaused then UsedViewModel.Parent = world.Hidden end
		elseif UsedViewModel.Parent == world.Hidden and not (Configuration.InvisibleInThirdPerson and not ClientCam.IsFirstPerson) then
			UsedViewModel.Parent = world.Environment
		end

		if Configuration.InvisibleInThirdPerson and not ClientCam.IsFirstPerson then
			if Configuration.InvisibleSpeed > 0 then
				local Alpha: number = math.exp(-Configuration.InvisibleSpeed * DeltaTime)
				-- lerp all alpha values (store alpha values locally for the viewmodel to transition it to normal values later)
			else
				UsedViewModel.Parent = world.Hidden
			end
			return
		elseif ClientCam.IsFirstPerson and UsedViewModel.Parent == world.Hidden then
			UsedViewModel.Parent = world.Environment
		end
		
		if Configuration.LerpSpeed > 0 then
			local Alpha: number = math.clamp(Configuration.LerpSpeed * DeltaTime, 0, 1)
			ViewModelQuaternion = Quaternion.Slerp(
				UsedViewModel.Quaternion,
				ClientCam.Quaternion,
				Alpha
			)
			ViewModelPosition = Vector3.Lerp(
				UsedViewModel.Position,
				ClientCam.Position,
				Alpha
			)
		end
		
		UsedViewModel.Position = ViewModelPosition + OffsetToApply
		UsedViewModel.Quaternion = ViewModelQuaternion
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
