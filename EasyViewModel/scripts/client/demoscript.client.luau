local EVM: EasyViewModel = require(world.Hidden.EasyViewModel)

local ViewModel: Instance = world.Hidden.TemplateViewModel
EVM.SetViewModel(ViewModel)

local Config: EVMConfig = {
	InvisibleInThirdPerson = true,
	InvisibleSpeed = -1,
	Bounciness = -1,
	LerpSpeed = -1,
} :: EVMConfig

EVM.SetConfig(Config)

EVM.StartViewModelRuntime()
