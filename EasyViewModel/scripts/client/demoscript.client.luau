local EVM: EasyViewModel = require(world.Hidden.EasyViewModel)

local ViewModel = Environment:FindChild("TemplateViewModel")
EVM.SetViewModel(ViewModel)

local Config: EVMConfig = {
	InvisibleInThirdPerson = false,
	InvisibleSpeed = 10,
	MaxDistance = 1,
	LerpSpeed = 25
} :: EVMConfig

EVM.SetConfig(Config)

EVM.StartViewModelRuntime(2)
