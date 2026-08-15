local EVM: EasyViewModel = require(world.Hidden.EasyViewModel)

local ViewModel = Environment:FindChild("TemplateViewModel")
EVM.SetViewModel(ViewModel)

local Config: EVMConfig = {
	InvisibleInThirdPerson = false,
	InvisibleSpeed = -1,
	Bounciness = -1,
	LerpSpeed = 50,
} :: EVMConfig

EVM.SetConfig(Config)

EVM.StartViewModelRuntime(1)
