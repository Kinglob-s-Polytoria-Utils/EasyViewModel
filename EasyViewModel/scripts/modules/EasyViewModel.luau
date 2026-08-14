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
		following the player's camera.

		Default = 0
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
	SetViewModel: (Model: Instance) -> boolean?;

	--[[
		Sets the config. Must follow the EVMConfig type.
		Returns false or nil if it fails.
		Persists after ending the viewmodel runtime.

		Has no default value.
	--]]
	SetConfig: (Config: EVMConfig) -> boolean?;

	--[[
		Begins the viewmodel runtime.
		Follows the configuration set by SetConfig.
		Uses the viewmodel set by SetViewModel.

		The config and viewmodel can be updated
		during the runtime.
	--]] 	
	StartViewModelRuntime: () -> nil;

	--[[
		Pauses and unpauses the viewmodel runtime, and does not
		disconnect any events that the runtime uses.
		
		Setting HideViewModel makes the viewmodel hidden
		if the runtime is paused.
	--]]
	ToggleViewModelRuntime: (HideViewModel: boolean?) -> nil;

	--[[
		Completely ends the viewmodel runtime, disconnecting events
		and functions. Clears config and the set viewmodel aswell.
	--]]
	EndViewModelRuntime: () -> nil;

	--[[
		Returns the currently used viewmodel in the runtime.
		This can be used for modifying the viewmodel (Such as
		equpping a gun and placing it in the client's viewmodel),
		or playing an animation on the viewmodel.
	--]]
	GetViewModel: () -> Instance;
}

local EVM: EasyViewModel = {} :: EasyViewModel

return EVM 
