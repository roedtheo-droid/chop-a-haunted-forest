--!strict
-- Turns every model tagged Spinner (the sawmills' saws and water wheels) around and around.
-- The server builds them standing still; turning them here on each player's own computer
-- is smooth and sends nothing over the network. They're only for looks.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

type Spinner = {
	Model: Model,
	Start: CFrame, -- where it was when it appeared; it turns around this CFrame's X axis
	Speed: number, -- radians per second
}

local SpinnerController = {}

local spinners: { [Instance]: Spinner } = {}

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local speed = instance:GetAttribute("SpinSpeed")
	spinners[instance] = {
		Model = instance,
		Start = instance:GetPivot(),
		Speed = if typeof(speed) == "number" then speed else 1,
	}
end

function SpinnerController.init() end

function SpinnerController.start()
	for _, instance in CollectionService:GetTagged(Tags.Spinner) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Spinner):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.Spinner):Connect(function(instance: Instance)
		spinners[instance] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local now = os.clock()
		for _, spinner in spinners do
			-- Far away you can't see them turning, so don't bother.
			if (spinner.Start.Position - cameraPosition).Magnitude <= Config.Sawmill.SpinDistance then
				spinner.Model:PivotTo(spinner.Start * CFrame.Angles(now * spinner.Speed, 0, 0))
			end
		end
	end)
end

return SpinnerController
