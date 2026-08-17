local EVM: EasyViewModel = require(world.Hidden.EasyViewModel)

local ViewModel = Environment:FindChild("TemplateViewModel")
EVM.SetViewModel(ViewModel)

local Config: EVMConfig = {
	InvisibleInThirdPerson = true,
	InvisibleSpeed = 10,
	IsUIViewport = false,
} :: EVMConfig

EVM.SetConfig(Config)

EVM.StartViewModelRuntime(function(LocalPos: Vector3, LocalQuat: Quaternion)
	return Vector3.Forward * 3, LocalQuat
end)
