local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local cfg = {
	enabled = true,
	teamcheck = true,
	wallcheck = true,
	target = "Head",
	smoothness = 0.25,
	fov = 120,
	circlevis = true,
	circlex = 0.5,
	circley = 0.5,
	circlesize = 120,
	circlecolor = Color3.fromRGB(255, 60, 60),
	circlethick = 1.5,
	predic = false,
	predicamt = 0.08,
	highlight = false,
	highlightcolor = Color3.fromRGB(255, 50, 50),
	highlightfill = Color3.fromRGB(255, 50, 50),
	highlightfilltr = 0.7,
	esp = false,
	espcolor = Color3.fromRGB(255, 255, 255),
	triggerbot = false,
	triggerdist = 8,
	notifs = true,
}

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Filled = false
fovCircle.Color = cfg.circlecolor
fovCircle.Thickness = cfg.circlethick
fovCircle.NumSides = 512
fovCircle.Radius = cfg.circlesize

local espObjects = {}
local currentTarget = nil

local function getChar(p)
	return p and p.Character
end

local function getPart(char, part)
	if not char then return nil end
	if part == "Head" then return char:FindFirstChild("Head") end
	if part == "HumanoidRootPart" then return char:FindFirstChild("HumanoidRootPart") end
	if part == "Torso" then
		return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	end
	return char:FindFirstChild(part) or char:FindFirstChild("HumanoidRootPart")
end

local function isAlive(p)
	local c = getChar(p)
	if not c then return false end
	local h = c:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0
end

local function sameTeam(p)
	if not cfg.teamcheck then return false end
	return p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team
end

local function canSee(part)
	if not cfg.wallcheck then return true end
	local rc = RaycastParams.new()
	rc.FilterDescendantsInstances = {LocalPlayer.Character}
	rc.FilterType = Enum.RaycastFilterType.Exclude
	local origin = Camera.CFrame.Position
	local dir = part.Position - origin
	local res = workspace:Raycast(origin, dir, rc)
	if res then
		local hit = res.Instance
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				local c = getChar(p)
				if c and hit:IsDescendantOf(c) then return true end
			end
		end
		return false
	end
	return true
end

local function getCenter()
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X * cfg.circlex, vp.Y * cfg.circley)
end

local function toScreen(part)
	if not part then return nil, false end
	local p, vis = Camera:WorldToViewportPoint(part.Position)
	return Vector2.new(p.X, p.Y), vis and p.Z > 0
end

local function getClosestInFOV()
	local best = nil
	local bestDist = math.huge
	local center = getCenter()

	for _, p in ipairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		if not isAlive(p) then continue end
		if sameTeam(p) then continue end

		local char = getChar(p)
		if not char then continue end

		local part = getPart(char, cfg.target)
		if not part then continue end

		local sp, vis = toScreen(part)
		if not vis then continue end

		local dist = (sp - center).Magnitude
		if dist > cfg.circlesize then continue end

		if cfg.wallcheck and not canSee(part) then continue end

		if dist < bestDist then
			bestDist = dist
			best = p
		end
	end

	return best
end

local function aimAt(target)
	if not target then return end
	local char = getChar(target)
	if not char then return end
	local part = getPart(char, cfg.target)
	if not part then return end

	local pos = part.Position
	if cfg.predic then
		local root = getPart(char, "HumanoidRootPart")
		if root then
			pos = pos + root.AssemblyLinearVelocity * cfg.predicamt
		end
	end

	local camCF = Camera.CFrame
	local targetCF = CFrame.new(camCF.Position, pos)
	Camera.CFrame = camCF:Lerp(targetCF, cfg.smoothness)
end

local function buildESP(p)
	if espObjects[p] then return end
	local box = Drawing.new("Square")
	box.Visible = false
	box.Color = cfg.espcolor
	box.Thickness = 1.5
	box.Filled = false

	local label = Drawing.new("Text")
	label.Visible = false
	label.Color = cfg.espcolor
	label.Size = 13
	label.Center = true
	label.Outline = true

	espObjects[p] = {box = box, label = label}
end

local function removeESP(p)
	if espObjects[p] then
		espObjects[p].box:Remove()
		espObjects[p].label:Remove()
		espObjects[p] = nil
	end
end

local function updateESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		if not espObjects[p] then buildESP(p) end
		local obj = espObjects[p]

		if not cfg.esp or not isAlive(p) then
			obj.box.Visible = false
			obj.label.Visible = false
			continue
		end

		local char = getChar(p)
		if not char then obj.box.Visible = false obj.label.Visible = false continue end

		local root = getPart(char, "HumanoidRootPart")
		local head = getPart(char, "Head")
		if not root or not head then obj.box.Visible = false obj.label.Visible = false continue end

		local rsp, rvis = toScreen(root)
		local hsp, hvis = toScreen(head)
		if not rvis or not hvis then obj.box.Visible = false obj.label.Visible = false continue end

		local h = math.abs(hsp.Y - rsp.Y) * 2.2
		local w = h * 0.55
		obj.box.Size = Vector2.new(w, h)
		obj.box.Position = Vector2.new(rsp.X - w / 2, rsp.Y - h / 2)
		obj.box.Color = cfg.espcolor
		obj.box.Visible = true

		local hum = char:FindFirstChildOfClass("Humanoid")
		obj.label.Text = p.DisplayName .. " [" .. math.floor(hum and hum.Health or 0) .. "]"
		obj.label.Position = Vector2.new(rsp.X, rsp.Y - h / 2 - 14)
		obj.label.Color = cfg.espcolor
		obj.label.Visible = true
	end
end

local function updateHighlight()
	for _, p in ipairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		local char = getChar(p)
		if not char then continue end
		if cfg.highlight and isAlive(p) then
			if not char:FindFirstChild("_HL") then
				local hl = Instance.new("Highlight")
				hl.Name = "_HL"
				hl.FillColor = cfg.highlightfill
				hl.OutlineColor = cfg.highlightcolor
				hl.FillTransparency = cfg.highlightfilltr
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = char
			end
		else
			local hl = char:FindFirstChild("_HL")
			if hl then hl:Destroy() end
		end
	end
end

Players.PlayerAdded:Connect(function(p) buildESP(p) end)
Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

RunService.RenderStepped:Connect(function()
	local center = getCenter()

	fovCircle.Position = center
	fovCircle.Radius = cfg.circlesize
	fovCircle.Color = cfg.circlecolor
	fovCircle.Thickness = cfg.circlethick
	fovCircle.Visible = cfg.circlevis

	updateESP()
	updateHighlight()

	if not cfg.enabled then
		currentTarget = nil
		return
	end

	local t = getClosestInFOV()

	if t and isAlive(t) then
		currentTarget = t
	else
		currentTarget = nil
	end

	if currentTarget then
		aimAt(currentTarget)

		if cfg.triggerbot then
			local char = getChar(currentTarget)
			if char then
				local part = getPart(char, cfg.target)
				if part then
					local sp, vis = toScreen(part)
					if vis and (sp - center).Magnitude < cfg.triggerdist then
						mouse1click()
					end
				end
			end
		end
	end
end)

local Window = Rayfield:CreateWindow({
	Name = "avci universal aimbot",
	LoadingTitle = "loading...",
	LoadingSubtitle = "stay lowkey",
	ConfigurationSaving = { Enabled = true, FileName = "avciaimbot" },
	KeySystem = false,
})

local AimTab = Window:CreateTab("Aimbot", 4483362458)
local VisTab = Window:CreateTab("Visuals", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

AimTab:CreateToggle({
	Name = "Aimbot",
	CurrentValue = cfg.enabled,
	Flag = "AimEnabled",
	Callback = function(v) cfg.enabled = v end
})

AimTab:CreateDropdown({
	Name = "Aim Part",
	Options = {"Head", "HumanoidRootPart", "Torso"},
	CurrentOption = {cfg.target},
	Flag = "AimPart",
	Callback = function(v) cfg.target = v[1] end
})

AimTab:CreateSlider({
	Name = "Smoothness",
	Range = {0.01, 1},
	Increment = 0.01,
	CurrentValue = cfg.smoothness,
	Flag = "Smoothness",
	Callback = function(v) cfg.smoothness = v end
})

AimTab:CreateToggle({
	Name = "Team Check",
	CurrentValue = cfg.teamcheck,
	Flag = "TeamCheck",
	Callback = function(v) cfg.teamcheck = v end
})

AimTab:CreateToggle({
	Name = "Wall Check",
	CurrentValue = cfg.wallcheck,
	Flag = "WallCheck",
	Callback = function(v) cfg.wallcheck = v end
})

AimTab:CreateToggle({
	Name = "Prediction",
	CurrentValue = cfg.predic,
	Flag = "Prediction",
	Callback = function(v) cfg.predic = v end
})

AimTab:CreateSlider({
	Name = "Prediction Amount",
	Range = {0.01, 0.5},
	Increment = 0.01,
	CurrentValue = cfg.predicamt,
	Flag = "PredAmt",
	Callback = function(v) cfg.predicamt = v end
})

AimTab:CreateToggle({
	Name = "Triggerbot",
	CurrentValue = cfg.triggerbot,
	Flag = "Triggerbot",
	Callback = function(v) cfg.triggerbot = v end
})

AimTab:CreateSlider({
	Name = "Trigger Distance",
	Range = {1, 30},
	Increment = 0.5,
	CurrentValue = cfg.triggerdist,
	Flag = "TriggerDist",
	Callback = function(v) cfg.triggerdist = v end
})

VisTab:CreateToggle({
	Name = "FOV Circle",
	CurrentValue = cfg.circlevis,
	Flag = "FovVis",
	Callback = function(v) cfg.circlevis = v end
})

VisTab:CreateSlider({
	Name = "Circle Size",
	Range = {10, 500},
	Increment = 1,
	CurrentValue = cfg.circlesize,
	Flag = "CircleSize",
	Callback = function(v) cfg.circlesize = v cfg.fov = v end
})

VisTab:CreateSlider({
	Name = "Circle X Position",
	Range = {0, 1},
	Increment = 0.01,
	CurrentValue = cfg.circlex,
	Flag = "CircleX",
	Callback = function(v) cfg.circlex = v end
})

VisTab:CreateSlider({
	Name = "Circle Y Position",
	Range = {0, 1},
	Increment = 0.01,
	CurrentValue = cfg.circley,
	Flag = "CircleY",
	Callback = function(v) cfg.circley = v end
})

VisTab:CreateSlider({
	Name = "Circle Thickness",
	Range = {0.5, 5},
	Increment = 0.5,
	CurrentValue = cfg.circlethick,
	Flag = "CircleThick",
	Callback = function(v) cfg.circlethick = v end
})

VisTab:CreateToggle({
	Name = "ESP Boxes",
	CurrentValue = cfg.esp,
	Flag = "ESP",
	Callback = function(v)
		cfg.esp = v
		if not v then
			for _, p in ipairs(Players:GetPlayers()) do
				if espObjects[p] then
					espObjects[p].box.Visible = false
					espObjects[p].label.Visible = false
				end
			end
		end
	end
})

VisTab:CreateColorPicker({
	Name = "ESP Color",
	Color = cfg.espcolor,
	Flag = "EspColor",
	Callback = function(v) cfg.espcolor = v end
})

VisTab:CreateToggle({
	Name = "Player Highlight",
	CurrentValue = cfg.highlight,
	Flag = "Highlight",
	Callback = function(v) cfg.highlight = v end
})

VisTab:CreateColorPicker({
	Name = "Highlight Color",
	Color = cfg.highlightcolor,
	Flag = "HLColor",
	Callback = function(v) cfg.highlightcolor = v end
})

VisTab:CreateSlider({
	Name = "Highlight Fill Transparency",
	Range = {0, 1},
	Increment = 0.05,
	CurrentValue = cfg.highlightfilltr,
	Flag = "HLFill",
	Callback = function(v) cfg.highlightfilltr = v end
})

MiscTab:CreateToggle({
	Name = "Notifications",
	CurrentValue = cfg.notifs,
	Flag = "Notifs",
	Callback = function(v) cfg.notifs = v end
})

MiscTab:CreateButton({
	Name = "Unload",
	Callback = function()
		cfg.enabled = false
		fovCircle.Visible = false
		fovCircle:Remove()
		for _, p in ipairs(Players:GetPlayers()) do removeESP(p) end
		for _, p in ipairs(Players:GetPlayers()) do
			local char = getChar(p)
			if char then
				local hl = char:FindFirstChild("_HL")
				if hl then hl:Destroy() end
			end
		end
		Rayfield:Destroy()
	end
})

if cfg.notifs then
	Rayfield:Notify({
		Title = "avci universal aimbot",
		Content = "loaded — anyone inside the circle gets locked, nearest first",
		Duration = 5,
		Image = 4483362458,
	})
end
