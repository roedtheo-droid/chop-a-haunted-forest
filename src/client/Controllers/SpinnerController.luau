--!strict
-- Turns every model tagged Spinner (the sawmills' saws and water wheels, and the floating tools in
-- the Tool Shed) around and around. A model with a Bob attribute also moves along the same axis, that
-- many studs each way (in the shed that axis points up, so the tools and the ghost float).
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
	Bob: number, -- studs
	Phase: number, -- so they don't all bob together
}

local SpinnerController = {}

local spinners: { [Instance]: Spinner } = {}

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	-- With StreamingEnabled the model can arrive before its parts. Its pivot is only right once
	-- its main part is here (the server streams each spinner in whole: ModelStreamingMode
	-- Atomic), so wait for that; otherwise it would be turned around the middle of the map.
	if not instance.PrimaryPart then
		local connection: RBXScriptConnection
		connection = instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			if instance.PrimaryPart then
				connection:Disconnect()
				add(instance)
			end
		end)
		return
	end
	local speed = instance:GetAttribute("SpinSpeed")
	local bob = instance:GetAttribute("Bob")
	local start = instance:GetPivot()
	spinners[instance] = {
		Model = instance,
		Start = start,
		Speed = if typeof(speed) == "number" then speed else 1,
		Bob = if typeof(bob) == "number" then bob else 0,
		Phase = start.Position.X + start.Position.Z,
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
				local lift = spinner.Bob * math.sin(now * Config.Shop.BobSpeed + spinner.Phase)
				spinner.Model:PivotTo(spinner.Start * CFrame.new(lift, 0, 0) * CFrame.Angles(now * spinner.Speed, 0, 0))
			end
		end
	end)
end

return SpinnerController
