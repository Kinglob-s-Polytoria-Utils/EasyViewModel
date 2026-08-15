local EVM: EasyViewModel = require(world.Hidden.EasyViewModel)

local ViewModel = Environment:FindChild("TemplateViewModel")
EVM.SetViewModel(ViewModel)

-- TODO: add maxdistance to the config
--			 should prevent the viewmodel from straying
--       further from the camera than the specified 
--       max distance
local Config: EVMConfig = {
	InvisibleInThirdPerson = false,
	InvisibleSpeed = -1,
	LerpSpeed = 700,
} :: EVMConfig

EVM.SetConfig(Config)

EVM.StartViewModelRuntime(1)
