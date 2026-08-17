# EasyViewModel
Viewmodels made easy!!!

## What is EasyViewModel
EasyViewModel *(EVM)* is a single-module viewmodel service meant to make
handling viewmodels easy.

## How to install EasyViewModel
Install the .ptmd file in releases, and drag it into your world.
Place the `EasyViewModel.luau` into Hidden, then follow the
guide on how to use it below.

### How to Use EasyViewModel
1. Set the viewmodel instance & configuration
```lua
local EVM: EasyViewModel = require(world.Hidden.EasyViewModel)

-- Set the viewmodel runtime config...
local ViewmodelConfig: EVMConfig = {
    InvisibleInThirdPerson = true,
    InvisibleSpeed = 16,
    IsUIViewport = true
}

EVM.SetConfig(ViewmodelConfig)

--- Set the viewmodel's instance...
local Viewmodel: Instance = world.path.to.your.viewmodel
EVM.SetViewModel(Viewmodel)
```

2. Start the runtime!
```lua
local Offset: number = 2
EVM.StartViewModelRuntime(function(LocalPos: Vector3, LocalQuat: Quaternion)
	return Vector3.Forward * 3, LocalQuat
end)

-- You can also pause & end it!
EVM.ToggleViewModelRuntime(true) -- set the first (and only) arg to true to hide it when paused
EVM.EndViewModelRuntime() -- this fully ends the runtime, clearing config and the set viewmode instance
```

### More information
More information can be seen in the `EasyViewModel.luau`'s built-in documentation!
