-- LocalScript: StarterPlayer > StarterPlayerScripts
-- DeployUI + Godmode + ESP + Noclip(fixed) + WalkSpeed + JumpPower + Aimlock (ZWare) + Hitbox Expander
-- UI FIXED: UIStroke border mode, Trigger Key row layout, Aim Part text overflow

local Players           = game:GetService("Players")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TeleportService   = game:GetService("TeleportService")
local StarterGui        = game:GetService("StarterGui")
local Area              = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
	Bg      = Color3.fromRGB(35, 20, 25),
	Sidebar = Color3.fromRGB(42, 22, 28),
	Panel   = Color3.fromRGB(28, 16, 20),
	Accent  = Color3.fromRGB(190, 35, 45),
	Text    = Color3.fromRGB(240, 230, 230),
	Dim     = Color3.fromRGB(150, 115, 120),
	Button  = Color3.fromRGB(62, 36, 44),
}

local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

-- FIX: ApplyStrokeMode = Border (ไม่ใช่ขอบตัวอักษร)
local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or COLORS.Accent
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function label(parent, text, size, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextSize = size or 14
	l.TextColor3 = COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.new(1, 0, 0, 20)
	l.Parent = parent
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local function makeToggle(parent, text, default, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 28)
	row.BackgroundTransparency = 1
	row.Parent = parent
	label(row, text, 12, { Size = UDim2.new(1, -50, 1, 0), TextWrapped = true })

	local track_btn = Instance.new("TextButton")
	track_btn.Size = UDim2.fromOffset(38, 20)
	track_btn.Position = UDim2.new(1, -38, 0.5, -10)
	track_btn.Text = ""
	track_btn.AutoButtonColor = false
	track_btn.BackgroundColor3 = default and COLORS.Accent or COLORS.Button
	track_btn.Parent = row
	corner(track_btn, 10)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	knob.BackgroundColor3 = COLORS.Text
	knob.Parent = track_btn
	corner(knob, 8)

	local state = default
	local function setState(newState, silent)
		if newState == state then return end
		state = newState
		TweenService:Create(track_btn, TweenInfo.new(0.15), {
			BackgroundColor3 = state and COLORS.Accent or COLORS.Button
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.15), {
			Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		}):Play()
		if callback and not silent then callback(state) end
	end

	track(track_btn.MouseButton1Click:Connect(function() setState(not state) end))
	return row, setState
end

---------------------------------------------------------------- fullbright
local FULLBRIGHT = {
	Brightness = 1, ClockTime = 12, FogEnd = 786543,
	GlobalShadows = false, Ambient = Color3.fromRGB(178, 178, 178),
}
local fullbrightOn = false
local originals = {}

local function setFullbright(state)
	if state == fullbrightOn then return end
	fullbrightOn = state
	if state then
		for prop in pairs(FULLBRIGHT) do originals[prop] = Lighting[prop] end
		for prop, value in pairs(FULLBRIGHT) do Lighting[prop] = value end
	else
		for prop, value in pairs(originals) do Lighting[prop] = value end
	end
end

for prop in pairs(FULLBRIGHT) do
	track(Lighting:GetPropertyChangedSignal(prop):Connect(function()
		if fullbrightOn and Lighting[prop] ~= FULLBRIGHT[prop] then
			Lighting[prop] = FULLBRIGHT[prop]
		end
	end))
end

---------------------------------------------------------------- instant pickup
local instantOn = false
local promptOriginals = {}

local function setInstantPrompt(prompt)
	if promptOriginals[prompt] == nil then
		promptOriginals[prompt] = prompt.HoldDuration
	end
	prompt.HoldDuration = 0
end

local function setInstantPickup(state)
	if state == instantOn then return end
	instantOn = state
	if state then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then setInstantPrompt(obj) end
		end
	else
		for prompt, value in pairs(promptOriginals) do
			if prompt.Parent then prompt.HoldDuration = value end
		end
		promptOriginals = {}
	end
end

track(workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") then
		if instantOn then setInstantPrompt(obj) end
		track(obj:GetPropertyChangedSignal("HoldDuration"):Connect(function()
			if instantOn and obj.HoldDuration ~= 0 then obj.HoldDuration = 0 end
		end))
	end
end))

---------------------------------------------------------------- open jump / walkspeed
local openJumpOn = false
local JUMP_POWER = 50
local JUMP_HEIGHT = 7.2
local jumpRequested = false
local customWalkSpeed = 16
local walkSpeedOn = false
local origJumpPower  = nil
local origJumpHeight = nil
local origWalkSpeed  = nil

local function getHum()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function restoreJump(hum)
	if not hum then return end
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	if hum.UseJumpPower then
		if hum.JumpPower < 1 then hum.JumpPower = JUMP_POWER end
	else
		if hum.JumpHeight < 1 then hum.JumpHeight = JUMP_HEIGHT end
	end
end

track(UserInputService.JumpRequest:Connect(function()
	if openJumpOn then jumpRequested = true end
end))

track(RunService.Heartbeat:Connect(function()
	if not openJumpOn then jumpRequested = false return end
	local hum = getHum()
	if not hum or hum.Health <= 0 then jumpRequested = false return end
	restoreJump(hum)
	if jumpRequested then
		jumpRequested = false
		if hum.FloorMaterial ~= Enum.Material.Air then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end))

track(player.CharacterAdded:Connect(function()
	task.wait(0.5)
	if openJumpOn then restoreJump(getHum()) end
end))

local function setOpenJump(state)
	openJumpOn = state
	local hum = getHum()
	if state then
		if hum then origJumpPower = hum.JumpPower; origJumpHeight = hum.JumpHeight end
		restoreJump(hum)
	else
		if hum then
			if origJumpPower  then hum.JumpPower  = origJumpPower  end
			if origJumpHeight then hum.JumpHeight = origJumpHeight end
		end
		origJumpPower = nil; origJumpHeight = nil
	end
end

local function applyWalkSpeed(speed)
	customWalkSpeed = speed
	local hum = getHum()
	if hum then hum.WalkSpeed = speed end
end

local function setWalkSpeed(state)
	walkSpeedOn = state
	local hum = getHum()
	if not hum then return end
	if state then
		origWalkSpeed = hum.WalkSpeed
		hum.WalkSpeed = customWalkSpeed
	else
		hum.WalkSpeed = origWalkSpeed or 16
		origWalkSpeed = nil
	end
end

track(player.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	if walkSpeedOn then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = customWalkSpeed end
	end
end))

---------------------------------------------------------------- godmode
local godmodeOn = false

local function setGodmode(state)
	godmodeOn = state
	local hum = getHum()
	if hum then
		hum.MaxHealth = state and math.huge or 100
		hum.Health    = state and math.huge or 100
	end
end

track(player.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	if godmodeOn then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.MaxHealth = math.huge; hum.Health = math.huge end
	end
end))

---------------------------------------------------------------- noclip
local noclipOn   = false
local noclipConn = nil

local function setNoclip(state)
	noclipOn = state
	if state then
		if noclipConn then return end
		noclipConn = RunService.Stepped:Connect(function()
			local char = player.Character
			if not char then return end
			for _, v in ipairs(char:GetChildren()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
		end)
	else
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	end
end

---------------------------------------------------------------- force unfly
local function forceUnfly()
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BodyGyro") or d:IsA("BodyVelocity") or d:IsA("BodyPosition") then
			d:Destroy()
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		for _, st in ipairs({
			Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Flying,   Enum.HumanoidStateType.Freefall,
			Enum.HumanoidStateType.GettingUp,Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.Landed,   Enum.HumanoidStateType.Physics,
			Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Running,  Enum.HumanoidStateType.RunningNoPhysics,
			Enum.HumanoidStateType.Seated,   Enum.HumanoidStateType.StrafingNoPhysics,
			Enum.HumanoidStateType.Swimming,
		}) do hum:SetStateEnabled(st, true) end
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	local animate = char:FindFirstChild("Animate")
	if animate then animate.Disabled = false end
end

---------------------------------------------------------------- fly panel
local flyPanel, flyBtnRef, flyRunning, flyTeardown = nil, nil, false, nil

local function buildFlyPanel()
	local flyConns = {}
	local speeds = 1
	local nowe = false
	local tpwalking = false
	local tis, dis

	local fgui = Instance.new("ScreenGui")
	fgui.Name = "FlyGuiV3"
	fgui.ResetOnSpawn = false
	fgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fgui.Parent = playerGui

	local Frame = Instance.new("Frame")
	Frame.Parent = fgui
	Frame.BackgroundColor3 = Color3.fromRGB(163, 255, 137)
	Frame.Position = UDim2.new(0.1, 0, 0.38, 0)
	Frame.Size = UDim2.new(0, 190, 0, 57)
	Frame.Active = true
	Frame.Draggable = true

	local function mkBtn(name, text, color, size, pos, textSize)
		local b = Instance.new("TextButton")
		b.Name = name; b.Parent = Frame
		b.BackgroundColor3 = color; b.Size = size; b.Position = pos
		b.Font = Enum.Font.SourceSans; b.Text = text
		b.TextColor3 = Color3.fromRGB(0,0,0); b.TextSize = textSize or 14
		return b
	end

	local up    = mkBtn("up",   "UP",   Color3.fromRGB(79,255,152),  UDim2.new(0,44,0,28), UDim2.new(0,0,0,0))
	local down  = mkBtn("down", "DOWN", Color3.fromRGB(215,255,121), UDim2.new(0,44,0,28), UDim2.new(0,0,0.491,0))
	local onof  = mkBtn("onof", "fly",  Color3.fromRGB(255,249,74),  UDim2.new(0,56,0,28), UDim2.new(0.703,0,0.491,0))
	local plus  = mkBtn("plus", "+",    Color3.fromRGB(133,145,255), UDim2.new(0,45,0,28), UDim2.new(0.232,0,0,0))
	local mine  = mkBtn("mine", "-",    Color3.fromRGB(123,255,247), UDim2.new(0,45,0,29), UDim2.new(0.232,0,0.491,0))
	local closebtn = mkBtn("Close","X", Color3.fromRGB(225,25,0),    UDim2.new(0,45,0,28), UDim2.new(0,0,-1,27), 30)
	local mini  = mkBtn("minimize","-", Color3.fromRGB(192,150,230), UDim2.new(0,45,0,28), UDim2.new(0,44,-1,27), 40)
	local mini2 = mkBtn("minimize2","+",Color3.fromRGB(192,150,230), UDim2.new(0,45,0,28), UDim2.new(0,44,-1,57), 40)
	mini2.Visible = false

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Parent = Frame; titleLbl.BackgroundColor3 = Color3.fromRGB(242,60,255)
	titleLbl.Position = UDim2.new(0.469,0,0,0); titleLbl.Size = UDim2.new(0,100,0,28)
	titleLbl.Font = Enum.Font.SourceSans; titleLbl.Text = "FLY GUI V3"
	titleLbl.TextColor3 = Color3.fromRGB(0,0,0); titleLbl.TextScaled = true; titleLbl.TextWrapped = true

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Name = "speed"; speedLbl.Parent = Frame
	speedLbl.BackgroundColor3 = Color3.fromRGB(255,85,0)
	speedLbl.Position = UDim2.new(0.468,0,0.491,0); speedLbl.Size = UDim2.new(0,44,0,28)
	speedLbl.Font = Enum.Font.SourceSans; speedLbl.Text = "1"
	speedLbl.TextColor3 = Color3.fromRGB(0,0,0); speedLbl.TextScaled = true; speedLbl.TextWrapped = true

	local function setHumanoidStates(hum, enabled)
		for _, st in ipairs({
			Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Flying,   Enum.HumanoidStateType.Freefall,
			Enum.HumanoidStateType.GettingUp,Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.Landed,   Enum.HumanoidStateType.Physics,
			Enum.HumanoidStateType.PlatformStanding,Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Running,  Enum.HumanoidStateType.RunningNoPhysics,
			Enum.HumanoidStateType.Seated,   Enum.HumanoidStateType.StrafingNoPhysics,
			Enum.HumanoidStateType.Swimming,
		}) do hum:SetStateEnabled(st, enabled) end
	end

	local function startWalkLoops()
		tpwalking = false
		for _ = 1, speeds do
			task.spawn(function()
				tpwalking = true
				local chr = player.Character
				local hum = chr and chr:FindFirstChildWhichIsA("Humanoid")
				while tpwalking and RunService.Heartbeat:Wait() and chr and hum and hum.Parent do
					if hum.MoveDirection.Magnitude > 0 then
						chr:TranslateBy(hum.MoveDirection)
					end
				end
			end)
		end
	end

	local function stopFly()
		if not nowe then return end
		nowe = false; tpwalking = false
		for _, c in ipairs(flyConns) do c:Disconnect() end
		flyConns = {}
		forceUnfly()
	end

	local function startFly()
		if nowe then return end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (char and hum) then return end
		nowe = true
		startWalkLoops()
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = true end
		setHumanoidStates(hum, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		hum:ChangeState(Enum.HumanoidStateType.Swimming)

		local rigTorso = (hum.RigType == Enum.HumanoidRigType.R6)
			and char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if not rigTorso then stopFly() return end

		local bg = Instance.new("BodyGyro")
		bg.P = 9e4; bg.MaxTorque = Vector3.new(9e9,9e9,9e9)
		bg.CFrame = rigTorso.CFrame; bg.Parent = rigTorso

		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.new(0,0.1,0); bv.MaxForce = Vector3.new(9e9,9e9,9e9)
		bv.Parent = rigTorso
		hum.PlatformStand = true

		local ctrl = {f=0,b=0,l=0,r=0}
		local lastctrl = {f=0,b=0,l=0,r=0}
		local maxspeed = 50; local speed = 0
		local cam = workspace.CurrentCamera

		local conn = RunService.RenderStepped:Connect(function()
			if not nowe then return end
			local curHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not curHum or curHum.Health <= 0 then stopFly() return end
			local moveDir = curHum.MoveDirection
			ctrl.f = -moveDir:Dot(cam.CFrame.LookVector)
			ctrl.b = 0; ctrl.l = -moveDir:Dot(cam.CFrame.RightVector); ctrl.r = 0
			if ctrl.l+ctrl.r ~= 0 or ctrl.f+ctrl.b ~= 0 then
				speed = math.min(speed+0.5+(speed/maxspeed), maxspeed)
				lastctrl = {f=ctrl.f,b=ctrl.b,l=ctrl.l,r=ctrl.r}
			elseif speed ~= 0 then
				speed = math.max(speed-1, 0)
			end
			local c = (ctrl.l+ctrl.r ~= 0 or ctrl.f+ctrl.b ~= 0) and ctrl or lastctrl
			if (c.l+c.r) ~= 0 or (c.f+c.b) ~= 0 then
				bv.Velocity = ((cam.CFrame.LookVector*(c.f+c.b))
					+((cam.CFrame*CFrame.new(c.l+c.r,(c.f+c.b)*0.2,0).Position)-cam.CFrame.Position))*speed
			else
				bv.Velocity = Vector3.new(0,0,0)
			end
			bg.CFrame = cam.CFrame * CFrame.Angles(-math.rad((c.f+c.b)*50*speed/maxspeed),0,0)
		end)
		table.insert(flyConns, conn)
	end

	local function toggleFly()
		if nowe then stopFly() else startFly() end
		onof.Text = nowe and "stop" or "fly"
	end

	local function applySpeed(delta)
		speeds = math.max(1, speeds+delta)
		speedLbl.Text = tostring(speeds)
		if nowe then startWalkLoops() end
	end

	onof.MouseButton1Click:Connect(toggleFly)
	plus.MouseButton1Click:Connect(function() applySpeed(1) end)
	mine.MouseButton1Click:Connect(function() applySpeed(-1) end)

	up.MouseButton1Down:Connect(function()
		tis = up.MouseEnter:Connect(function()
			while tis do
				task.wait()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then root.CFrame = root.CFrame * CFrame.new(0,1,0) end
			end
		end)
	end)
	up.MouseLeave:Connect(function() if tis then tis:Disconnect() tis = nil end end)

	down.MouseButton1Down:Connect(function()
		dis = down.MouseEnter:Connect(function()
			while dis do
				task.wait()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then root.CFrame = root.CFrame * CFrame.new(0,-1,0) end
			end
		end)
	end)
	down.MouseLeave:Connect(function() if dis then dis:Disconnect() dis = nil end end)

	mini.MouseButton1Click:Connect(function()
		up.Visible=false; down.Visible=false; onof.Visible=false
		plus.Visible=false; speedLbl.Visible=false; mine.Visible=false
		mini.Visible=false; mini2.Visible=true
		Frame.BackgroundTransparency=1
		closebtn.Position=UDim2.new(0,0,-1,57)
	end)
	mini2.MouseButton1Click:Connect(function()
		up.Visible=true; down.Visible=true; onof.Visible=true
		plus.Visible=true; speedLbl.Visible=true; mine.Visible=true
		mini.Visible=true; mini2.Visible=false
		Frame.BackgroundTransparency=0
		closebtn.Position=UDim2.new(0,0,-1,27)
	end)

	local function teardown()
		stopFly()
		if tis then tis:Disconnect() tis=nil end
		if dis then dis:Disconnect() dis=nil end
		if fgui.Parent then fgui:Destroy() end
	end

	closebtn.MouseButton1Click:Connect(function()
		teardown(); flyRunning=false; flyTeardown=nil; flyPanel=nil
		if flyBtnRef then flyBtnRef.Text = "Click" end
	end)

	return fgui, teardown
end

local function toggleFlyPanel()
	if flyRunning then
		if flyTeardown then flyTeardown() end
		flyRunning=false; flyTeardown=nil; flyPanel=nil
		if flyBtnRef then flyBtnRef.Text = "Click" end
	else
		local g, td = buildFlyPanel()
		flyPanel=g; flyTeardown=td; flyRunning=true
		if flyBtnRef then flyBtnRef.Text = "Close" end
		StarterGui:SetCore("SendNotification",{Title="FLY GUI V3",Text="BY XNEO",Duration=5})
	end
end

---------------------------------------------------------------- ESP
local espOn   = false
local espConns = {}

local function clearEspConns()
	for _, c in ipairs(espConns) do pcall(function() c:Disconnect() end) end
	espConns = {}
end

local function applyHighlight(char, p)
	if not char or not espOn then return end
	local old = char:FindFirstChild("_ESP_HL")
	if old then old:Destroy() end
	local hl = Instance.new("Highlight")
	hl.Name = "_ESP_HL"
	hl.Adornee = char
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	local sameTeam = p.TeamColor == player.TeamColor
	hl.FillColor        = sameTeam and Color3.fromRGB(0,100,255) or Color3.fromRGB(255,50,50)
	hl.OutlineColor     = Color3.fromRGB(255,255,255)
	hl.FillTransparency = 0.5
	hl.Parent = char
end

local function removeHighlight(p)
	if p.Character then
		local hl = p.Character:FindFirstChild("_ESP_HL")
		if hl then hl:Destroy() end
	end
end

local function setupPlayerESP(p)
	if p == player then return end
	if p.Character then applyHighlight(p.Character, p) end
	table.insert(espConns, p.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		applyHighlight(char, p)
	end))
	table.insert(espConns, p.CharacterRemoving:Connect(function(char)
		if char then
			local hl = char:FindFirstChild("_ESP_HL")
			if hl then hl:Destroy() end
		end
	end))
end

local function setESP(state)
	espOn = state
	clearEspConns()
	if state then
		for _, p in ipairs(Players:GetPlayers()) do setupPlayerESP(p) end
		table.insert(espConns, Players.PlayerAdded:Connect(function(p)
			if espOn then setupPlayerESP(p) end
		end))
	else
		for _, p in ipairs(Players:GetPlayers()) do removeHighlight(p) end
	end
end

---------------------------------------------------------------- spectate / teleport
local spectateTarget, spectateConn = nil, nil

local function getOwnHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function setCameraSubject(subject)
	local cam = workspace.CurrentCamera
	if not cam or not subject then return end
	cam.CameraType = Enum.CameraType.Custom
	cam.CameraSubject = subject
end

local function spectate(targetPlayer)
	if spectateConn then spectateConn:Disconnect(); spectateConn = nil end
	spectateTarget = targetPlayer
	local function apply(char)
		if spectateTarget ~= targetPlayer then return end
		local hum = char and char:WaitForChild("Humanoid", 5)
		if hum then setCameraSubject(hum) end
	end
	apply(targetPlayer.Character)
	spectateConn = targetPlayer.CharacterAdded:Connect(apply)
end

local function stopSpectate()
	if spectateConn then spectateConn:Disconnect(); spectateConn = nil end
	spectateTarget = nil
	setCameraSubject(getOwnHumanoid())
end

local function teleportTo(targetPlayer)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tRoot  = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (myRoot and tRoot) then return end
	myRoot.CFrame = tRoot.CFrame * CFrame.new(0,0,3)
end

---------------------------------------------------------------- AIMLOCK (ZWare)
local aimlockOn   = false
local HoldingM2   = false
local aimlockActive = false
local aimlockLock = false

local aimlockKeyIsKeyboard  = false
local aimlockMouseBtn       = Enum.UserInputType.MouseButton2
local aimlockKeyCode        = Enum.KeyCode.E
local aimlockWaitingRebind  = false

local Epitaph    = 0.190
local HeadOffset = Vector3.new(0, 0.1, 0)
_G.AimPart = "Head"

_G.CircleSides        = 30
_G.CircleColor        = Color3.fromRGB(255, 0, 130)
_G.CircleTransparency = 0.35
_G.CircleRadius       = 65
_G.CircleFilled       = false
_G.CircleVisible      = false
_G.CircleThickness    = 1

local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius       = _G.CircleRadius
FOVCircle.Filled       = _G.CircleFilled
FOVCircle.Color        = _G.CircleColor
FOVCircle.Visible      = _G.CircleVisible
FOVCircle.Transparency = _G.CircleTransparency
FOVCircle.NumSides     = _G.CircleSides
FOVCircle.Thickness    = _G.CircleThickness

track(RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	FOVCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
end))

local aimlockKeyDisplayRef = nil
local aimlockRebindBtnRef  = nil

local function FindNearestPlayer()
	local mouse = player:GetMouse()
	local cam   = workspace.CurrentCamera
	local dist  = math.huge
	local Target = nil
	for _, v in pairs(Players:GetPlayers()) do
		if v ~= player and v.Character then
			local hum  = v.Character:FindFirstChild("Humanoid")
			local part = v.Character:FindFirstChild(_G.AimPart)
			local root = v.Character:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and root and part then
				local sp, vis = cam:WorldToViewportPoint(part.Position)
				if vis then
					local d = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(sp.X, sp.Y)).Magnitude
					if d < dist and d < FOVCircle.Radius then
						dist = d; Target = v.Character
					end
				end
			end
		end
	end
	return Target
end

local function CursorLock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end
local function UnLockCursor()
	HoldingM2 = false; aimlockActive = false; aimlockLock = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if aimlockWaitingRebind then
		local keyName = nil
		if input.UserInputType == Enum.UserInputType.Keyboard then
			aimlockKeyIsKeyboard = true
			aimlockKeyCode = input.KeyCode
			keyName = input.KeyCode.Name
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			aimlockKeyIsKeyboard = false
			aimlockMouseBtn = Enum.UserInputType.MouseButton1
			keyName = "LMB"
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimlockKeyIsKeyboard = false
			aimlockMouseBtn = Enum.UserInputType.MouseButton2
			keyName = "RMB"
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			aimlockKeyIsKeyboard = false
			aimlockMouseBtn = Enum.UserInputType.MouseButton3
			keyName = "MMB"
		end
		if keyName then
			aimlockWaitingRebind = false
			if aimlockKeyDisplayRef then aimlockKeyDisplayRef.Text = keyName end
			if aimlockRebindBtnRef  then aimlockRebindBtnRef.Text  = "Rebind" end
		end
		return
	end

	if gameProcessed then return end

	if not aimlockOn then return end
	local match = aimlockKeyIsKeyboard
		and (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == aimlockKeyCode)
		or  (not aimlockKeyIsKeyboard and input.UserInputType == aimlockMouseBtn)
	if not match then return end

	HoldingM2 = true; aimlockActive = true; aimlockLock = true
	local enemy = FindNearestPlayer()
	task.spawn(function()
		while HoldingM2 do
			task.wait(0.000001)
			if aimlockLock and enemy ~= nil then
				local cam = workspace.CurrentCamera
				local root = enemy:FindFirstChild("HumanoidRootPart")
				local hum  = enemy:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local future = root.CFrame + (root.Velocity * Epitaph + HeadOffset)
					cam.CFrame = CFrame.lookAt(cam.CFrame.Position, future.Position)
					CursorLock()
				else
					break
				end
			end
		end
		UnLockCursor()
	end)
end))

track(UserInputService.InputEnded:Connect(function(input)
	if not aimlockOn then return end
	local match = aimlockKeyIsKeyboard
		and (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == aimlockKeyCode)
		or  (not aimlockKeyIsKeyboard and input.UserInputType == aimlockMouseBtn)
	if match then UnLockCursor() end
end))

local function setAimlock(state)
	aimlockOn = state
	FOVCircle.Visible = state and _G.CircleVisible or false
	if not state then UnLockCursor() end
end

---------------------------------------------------------------- HITBOX EXPANDER
local hitboxOn          = false
local hitboxShowOn      = false
local hitboxSize        = 50
local hitboxTransparency = 0.7
local hitboxConnections = {}
local hitboxParts       = {}

local function clearHitboxConnections()
	for _, c in ipairs(hitboxConnections) do pcall(function() c:Disconnect() end) end
	hitboxConnections = {}
end

local function expandCharHitbox(char)
	if not char or not hitboxOn then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if hitboxParts[root] == nil then
		hitboxParts[root] = root.Size
	end
	root.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
	root.Transparency = hitboxShowOn and hitboxTransparency or 1
	root.CanCollide = false
end

local function restoreCharHitbox(char)
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and hitboxParts[root] then
		root.Size = hitboxParts[root]
		root.Transparency = 1
		hitboxParts[root] = nil
	end
end

local function setupPlayerHitbox(p)
	if p == player then return end
	if p.Character then expandCharHitbox(p.Character) end
	table.insert(hitboxConnections, p.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		expandCharHitbox(char)
	end))
	table.insert(hitboxConnections, p.CharacterRemoving:Connect(function(char)
		restoreCharHitbox(char)
	end))
end

local function setHitbox(state)
	hitboxOn = state
	clearHitboxConnections()
	hitboxParts = {}
	if state then
		for _, p in ipairs(Players:GetPlayers()) do setupPlayerHitbox(p) end
		table.insert(hitboxConnections, Players.PlayerAdded:Connect(function(p)
			if hitboxOn then setupPlayerHitbox(p) end
		end))
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character then restoreCharHitbox(p.Character) end
		end
	end
end

local function refreshHitboxVisual()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart")
			if root and hitboxOn then
				root.Transparency = hitboxShowOn and hitboxTransparency or 1
			end
		end
	end
end

local function refreshHitboxSize()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart")
			if root and hitboxOn then
				root.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
			end
		end
	end
end

---------------------------------------------------------------- build main UI
local gui = Instance.new("ScreenGui")
gui.Name = "DeployUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.Size = UDim2.fromOffset(520, 490)
main.BackgroundColor3 = COLORS.Bg
main.Active = true
main.Parent = gui
corner(main, 12)
stroke(main, COLORS.Accent, 2)

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.fromOffset(10, 10)
sidebar.Size = UDim2.new(0, 110, 1, -20)
sidebar.BackgroundColor3 = COLORS.Sidebar
sidebar.Active = true
sidebar.Parent = main
corner(sidebar, 10)

local sideList = Instance.new("Frame")
sideList.Position = UDim2.fromOffset(5, 8)
sideList.Size = UDim2.new(1, -10, 1, -70)
sideList.BackgroundTransparency = 1
sideList.Parent = sidebar

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 2)
sideLayout.Parent = sideList

local navButtons = {}
local function navItem(text, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 22)
	b.BackgroundColor3 = COLORS.Accent
	b.BackgroundTransparency = 1
	b.Text = "  " .. text
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.TextColor3 = COLORS.Dim
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.AutoButtonColor = false
	b.Parent = sideList
	corner(b, 6)
	b.MouseButton1Click:Connect(function()
		for _, other in ipairs(navButtons) do
			other.BackgroundTransparency = 1
			other.TextColor3 = COLORS.Dim
		end
		b.BackgroundTransparency = 0
		b.TextColor3 = COLORS.Text
		if onClick then onClick() end
	end)
	table.insert(navButtons, b)
	return b
end

local profile = Instance.new("Frame")
profile.Size = UDim2.new(1,-10,0,44)
profile.Position = UDim2.new(0,5,1,-50)
profile.BackgroundColor3 = COLORS.Button
profile.Parent = sidebar
corner(profile, 8)

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.fromOffset(32,32)
avatar.Position = UDim2.fromOffset(6,6)
avatar.BackgroundColor3 = COLORS.Panel
avatar.Parent = profile
corner(avatar, 16)
task.spawn(function()
	pcall(function()
		avatar.Image = Players:GetUserThumbnailAsync(
			player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
end)
label(profile, player.DisplayName, 11, {Position=UDim2.fromOffset(44,7), Size=UDim2.new(1,-50,0,16)})
label(profile, "@"..player.Name, 9, {
	Position=UDim2.fromOffset(44,23), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})

local funcPanel = Instance.new("Frame")
funcPanel.Position = UDim2.fromOffset(130, 10)
funcPanel.Size = UDim2.new(1, -140, 1, -20)
funcPanel.BackgroundColor3 = COLORS.Panel
funcPanel.Active = true
funcPanel.Parent = main
corner(funcPanel, 10)
stroke(funcPanel, COLORS.Accent, 1)

local pageTitle = label(funcPanel, "MAIN", 13, {
	Position=UDim2.fromOffset(10,8), Size=UDim2.new(1,-20,0,20),
})

local function newPage()
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1,0,1,0)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = funcPanel
	return f
end

local pageMain    = newPage(); pageMain.Visible = true
local pageESP     = newPage()
local pageMisc    = newPage()
local pageAimlock = newPage()
local pageHitbox  = newPage()
local pageConfig  = newPage()

local function showPage(name)
	pageMain.Visible    = name == "Main"
	pageESP.Visible     = name == "ESP"
	pageMisc.Visible    = name == "Misc"
	pageAimlock.Visible = name == "Aimlock"
	pageHitbox.Visible  = name == "Hitbox"
	pageConfig.Visible  = name == "Config"
	pageTitle.Text = string.upper(name)
end

navItem("Main",    function() showPage("Main")    end)
navItem("ESP",     function() showPage("ESP")     end)
navItem("Misc",    function() showPage("Misc")    end)
navItem("Aimlock", function() showPage("Aimlock") end)
navItem("Hitbox",  function() showPage("Hitbox")  end)
navItem("Config",  function() showPage("Config")  end)

---------------------------------------------------------------- PAGE: MAIN
-- Fly
local flyRow = Instance.new("Frame")
flyRow.Position = UDim2.fromOffset(10, 40)
flyRow.Size = UDim2.new(1,-20,0,50)
flyRow.BackgroundTransparency = 1
flyRow.Parent = pageMain

label(flyRow, "Fly", 12)
label(flyRow, "กดครั้งเดียวเพื่อเปิด/ปิดแผงบิน", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local flyBtn = Instance.new("TextButton")
flyBtn.Size=UDim2.fromOffset(90,22); flyBtn.Position=UDim2.new(1,-90,0,0)
flyBtn.BackgroundColor3=COLORS.Accent; flyBtn.Font=Enum.Font.GothamBold; flyBtn.TextSize=11
flyBtn.TextColor3=COLORS.Text; flyBtn.Text="Click"
flyBtn.AutoButtonColor=false; flyBtn.Parent=flyRow
corner(flyBtn, 6)
flyBtnRef = flyBtn
track(flyBtn.MouseButton1Click:Connect(toggleFlyPanel))

-- God Mode (ย้ายมาอยู่ Main)
local godMainRow = Instance.new("Frame")
godMainRow.Position = UDim2.fromOffset(10, 100)
godMainRow.Size = UDim2.new(1,-20,0,50)
godMainRow.BackgroundTransparency = 1
godMainRow.Parent = pageMain

label(godMainRow, "God Mode", 12)
label(godMainRow, "ทำให้ HP ไม่มีวันหมด — MaxHealth = ∞", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local godMainToggle = makeToggle(godMainRow, "", false, function(state) setGodmode(state) end)
godMainToggle.Size=UDim2.new(1,0,0,28); godMainToggle.Position=UDim2.fromOffset(0,0)

---------------------------------------------------------------- PAGE: ESP
local espToggleContainer = Instance.new("Frame")
espToggleContainer.Position = UDim2.fromOffset(10,40)
espToggleContainer.Size = UDim2.new(1,-20,0,50)
espToggleContainer.BackgroundTransparency = 1
espToggleContainer.Parent = pageESP

label(espToggleContainer, "ESP Highlight", 12)
label(espToggleContainer, "แสดงตัวผู้เล่น", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local espToggleRow = makeToggle(espToggleContainer, "", false, function(state)
	setESP(state)
end)
espToggleRow.Size = UDim2.new(1,0,0,28)
espToggleRow.Position = UDim2.fromOffset(0,0)

local countLabel = label(pageESP, "Players in server: 0", 12, {
	Position=UDim2.fromOffset(10,100), Size=UDim2.new(1,-230,0,18),
})

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size=UDim2.fromOffset(90,22); refreshBtn.Position=UDim2.new(1,-100,0,97)
refreshBtn.BackgroundColor3=COLORS.Accent; refreshBtn.Font=Enum.Font.GothamBold
refreshBtn.TextSize=11; refreshBtn.TextColor3=COLORS.Text; refreshBtn.Text="Refresh"
refreshBtn.AutoButtonColor=false; refreshBtn.Parent=pageESP
corner(refreshBtn, 6)

local stopBtn = Instance.new("TextButton")
stopBtn.Size=UDim2.fromOffset(100,22); stopBtn.Position=UDim2.new(1,-210,0,97)
stopBtn.BackgroundColor3=COLORS.Accent; stopBtn.Font=Enum.Font.GothamBold
stopBtn.TextSize=11; stopBtn.TextColor3=COLORS.Text; stopBtn.Text="Stop Spectate"
stopBtn.AutoButtonColor=false; stopBtn.Parent=pageESP
corner(stopBtn, 6)
track(stopBtn.MouseButton1Click:Connect(stopSpectate))

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position=UDim2.fromOffset(10,128); listFrame.Size=UDim2.new(1,-20,1,-138)
listFrame.BackgroundTransparency=1; listFrame.BorderSizePixel=0
listFrame.ScrollBarThickness=3; listFrame.CanvasSize=UDim2.new()
listFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y; listFrame.Parent=pageESP

local listLayout = Instance.new("UIListLayout")
listLayout.Padding=UDim.new(0,4); listLayout.SortOrder=Enum.SortOrder.Name
listLayout.Parent=listFrame

local function refreshPlayers()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local all = Players:GetPlayers()
	countLabel.Text = "Players in server: "..#all
	for _, p in ipairs(all) do
		if p ~= player then
			local row = Instance.new("Frame")
			row.Size=UDim2.new(1,-6,0,26); row.BackgroundColor3=COLORS.Button; row.Parent=listFrame
			corner(row, 6)
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size=UDim2.new(1,-130,1,0); nameLbl.Position=UDim2.fromOffset(6,0)
			nameLbl.BackgroundTransparency=1; nameLbl.Font=Enum.Font.Gotham; nameLbl.TextSize=12
			nameLbl.TextColor3=COLORS.Text; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
			nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
			nameLbl.Text=p.DisplayName.." (@"..p.Name..")"
			nameLbl.Parent=row
			local specBtn=Instance.new("TextButton")
			specBtn.Size=UDim2.fromOffset(56,20); specBtn.Position=UDim2.new(1,-120,0.5,-10)
			specBtn.BackgroundColor3=COLORS.Accent; specBtn.Font=Enum.Font.GothamBold
			specBtn.TextSize=10; specBtn.TextColor3=COLORS.Text; specBtn.Text="Spectate"
			specBtn.AutoButtonColor=false; specBtn.Parent=row
			corner(specBtn, 5)
			track(specBtn.MouseButton1Click:Connect(function() spectate(p) end))
			local tpBtn=Instance.new("TextButton")
			tpBtn.Size=UDim2.fromOffset(52,20); tpBtn.Position=UDim2.new(1,-58,0.5,-10)
			tpBtn.BackgroundColor3=COLORS.Accent; tpBtn.Font=Enum.Font.GothamBold
			tpBtn.TextSize=10; tpBtn.TextColor3=COLORS.Text; tpBtn.Text="TP"
			tpBtn.AutoButtonColor=false; tpBtn.Parent=row
			corner(tpBtn, 5)
			track(tpBtn.MouseButton1Click:Connect(function() teleportTo(p) end))
		end
	end
end

track(refreshBtn.MouseButton1Click:Connect(refreshPlayers))
track(Players.PlayerAdded:Connect(refreshPlayers))
track(Players.PlayerRemoving:Connect(function() task.wait(); refreshPlayers() end))
refreshPlayers()

---------------------------------------------------------------- PAGE: MISC
local function miscRow(parent, yOffset, titleText, descText)
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(10, yOffset)
	row.Size = UDim2.new(1,-20,0,50)
	row.BackgroundTransparency = 1
	row.Parent = parent
	label(row, titleText, 12)
	label(row, descText, 10, {
		Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
		TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
	})
	return row
end

local fbRow = miscRow(pageMisc, 40, "Fullbright", "ทำให้แมพสว่างขึ้น (เฉพาะคุณที่เห็น)")
local fbToggle = makeToggle(fbRow, "", false, function(state) setFullbright(state) end)
fbToggle.Size=UDim2.new(1,0,0,28); fbToggle.Position=UDim2.fromOffset(0,0)

local takeRow = miscRow(pageMisc, 100, "Take Item 1 Click", "เก็บของกดครั้งเดียวทันที (เฉพาะคุณที่เห็น)")
local takeToggle = makeToggle(takeRow, "", false, function(state) setInstantPickup(state) end)
takeToggle.Size=UDim2.new(1,0,0,28); takeToggle.Position=UDim2.fromOffset(0,0)

-- Noclip (ย้ายมาอยู่ Misc)
local noclipMiscRow = Instance.new("Frame")
noclipMiscRow.Position = UDim2.fromOffset(10, 160)
noclipMiscRow.Size = UDim2.new(1,-20,0,50)
noclipMiscRow.BackgroundTransparency = 1
noclipMiscRow.Parent = pageMisc

label(noclipMiscRow, "Noclip", 12)
label(noclipMiscRow, "เดินทะลุกำแพงและพื้น", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local noclipMiscToggle = makeToggle(noclipMiscRow, "", false, function(state)
	setNoclip(state)
end)
noclipMiscToggle.Size=UDim2.new(1,0,0,28); noclipMiscToggle.Position=UDim2.fromOffset(0,0)

local jumpContainerY = 220
local jumpContainer = Instance.new("Frame")
jumpContainer.Position=UDim2.fromOffset(10,jumpContainerY)
jumpContainer.Size=UDim2.new(1,-20,0,100)
jumpContainer.BackgroundTransparency=1; jumpContainer.Parent=pageMisc

label(jumpContainer, "Open Jump", 12)
label(jumpContainer, "ถ้าแมพไหนกระโดดไม่ได้ให้กดเปิด (เฉพาะคุณที่เห็น)", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local jumpToggle=makeToggle(jumpContainer,"",false,function(state) setOpenJump(state) end)
jumpToggle.Size=UDim2.new(1,0,0,28); jumpToggle.Position=UDim2.fromOffset(0,0)

local wsContainerY=jumpContainerY+60
local wsContainer=Instance.new("Frame")
wsContainer.Position=UDim2.fromOffset(10,wsContainerY)
wsContainer.Size=UDim2.new(1,-20,0,100)
wsContainer.BackgroundTransparency=1; wsContainer.Parent=pageMisc

label(wsContainer,"Walk Speed",12)
label(wsContainer,"ปรับความเร็ววิ่ง (ค่าปกติ 16)",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local wsToggle=makeToggle(wsContainer,"",false,function(state) setWalkSpeed(state) end)
wsToggle.Size=UDim2.new(1,0,0,28); wsToggle.Position=UDim2.fromOffset(0,0)

local wsContainerY=jumpContainerY+60
do
	local WS_MAX = 100
	local wsContainer=Instance.new("Frame")
	wsContainer.Position=UDim2.fromOffset(10,wsContainerY)
	wsContainer.Size=UDim2.new(1,-20,0,70)
	wsContainer.BackgroundTransparency=1; wsContainer.Parent=pageMisc

	label(wsContainer,"Walk Speed",12)
	label(wsContainer,"ปรับความเร็ววิ่ง (ค่าปกติ 16, max 100)",10,{
		Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
		TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
	})
	local wsToggle=makeToggle(wsContainer,"",false,function(state) setWalkSpeed(state) end)
	wsToggle.Size=UDim2.new(1,0,0,28); wsToggle.Position=UDim2.fromOffset(0,0)

	local wsTrack=Instance.new("Frame")
	wsTrack.Size=UDim2.new(1,0,0,6)
	wsTrack.Position=UDim2.fromOffset(0,40)
	wsTrack.BackgroundColor3=COLORS.Button
	wsTrack.Parent=wsContainer
	corner(wsTrack,3); stroke(wsTrack,COLORS.Accent,1)

	local wsFill=Instance.new("Frame")
	wsFill.Size=UDim2.new(customWalkSpeed/WS_MAX,0,1,0)
	wsFill.BackgroundColor3=COLORS.Accent
	wsFill.Parent=wsTrack
	corner(wsFill,3)

	local wsLabel=Instance.new("TextLabel")
	wsLabel.Size=UDim2.fromOffset(60,16)
	wsLabel.Position=UDim2.new(0.5,-30,0,50)
	wsLabel.BackgroundTransparency=1
	wsLabel.Font=Enum.Font.GothamBold; wsLabel.TextSize=11
	wsLabel.TextColor3=COLORS.Text
	wsLabel.Text=customWalkSpeed.."/"..WS_MAX
	wsLabel.Parent=wsContainer

	local wsDragging=false
	local function updateWsSlider(absX)
		local relX=math.clamp(absX - wsTrack.AbsolutePosition.X, 0, wsTrack.AbsoluteSize.X)
		local frac=relX/wsTrack.AbsoluteSize.X
		local value=math.max(1, math.floor(frac*WS_MAX+0.5))
		customWalkSpeed=value
		wsFill.Size=UDim2.new(value/WS_MAX,0,1,0)
		wsLabel.Text=value.."/"..WS_MAX
		if walkSpeedOn then
			local hum=getHum()
			if hum then hum.WalkSpeed=value end
		end
	end

	track(wsTrack.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1
			or input.UserInputType==Enum.UserInputType.Touch then
			wsDragging=true
			updateWsSlider(input.Position.X)
		end
	end))
	track(wsTrack.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1
			or input.UserInputType==Enum.UserInputType.Touch then
			wsDragging=false
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if wsDragging and (input.UserInputType==Enum.UserInputType.MouseMovement
			or input.UserInputType==Enum.UserInputType.Touch) then
			updateWsSlider(input.Position.X)
		end
	end))
end

---------------------------------------------------------------- PAGE: AIMLOCK
-- Enable toggle
local alEnableFrame=Instance.new("Frame")
alEnableFrame.Position=UDim2.fromOffset(10,40)
alEnableFrame.Size=UDim2.new(1,-20,0,50)
alEnableFrame.BackgroundTransparency=1; alEnableFrame.Parent=pageAimlock

label(alEnableFrame,"Aimlock",12)
label(alEnableFrame,"กดค้างปุ่ม trigger เพื่อล็อกกล้องไปศัตรูที่ใกล้ใน FOV",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local alToggle=makeToggle(alEnableFrame,"",false,function(state)
	setAimlock(state)
end)
alToggle.Size=UDim2.new(1,0,0,28); alToggle.Position=UDim2.fromOffset(0,0)

-- FOV circle toggle
local alFovCircleFrame=Instance.new("Frame")
alFovCircleFrame.Position=UDim2.fromOffset(10,100)
alFovCircleFrame.Size=UDim2.new(1,-20,0,40)
alFovCircleFrame.BackgroundTransparency=1; alFovCircleFrame.Parent=pageAimlock

label(alFovCircleFrame,"Show FOV Circle",12)
label(alFovCircleFrame,"แสดงวงกลม FOV บนหน้าจอ",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local alFovCircleToggle=makeToggle(alFovCircleFrame,"",false,function(state)
	_G.CircleVisible = state
	FOVCircle.Visible = state and aimlockOn
end)
alFovCircleToggle.Size=UDim2.new(1,0,0,28); alFovCircleToggle.Position=UDim2.fromOffset(0,0)

-- Trigger key rebind (FIXED: ปุ่มอยู่ขวา ไม่ทับข้อความอธิบาย)
local alKeyFrame=Instance.new("Frame")
alKeyFrame.Position=UDim2.fromOffset(10,150)
alKeyFrame.Size=UDim2.new(1,-20,0,50)
alKeyFrame.BackgroundTransparency=1; alKeyFrame.Parent=pageAimlock

label(alKeyFrame,"Trigger Key",12)
label(alKeyFrame,"กด Rebind แล้วกดคีย์/เมาส์",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-190,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})

local alKeyDisplay=Instance.new("TextLabel")
alKeyDisplay.Size=UDim2.fromOffset(70,24)
alKeyDisplay.Position=UDim2.new(1,-170,0,0)
alKeyDisplay.BackgroundColor3=COLORS.Button
alKeyDisplay.Font=Enum.Font.GothamBold; alKeyDisplay.TextSize=12
alKeyDisplay.TextColor3=COLORS.Text; alKeyDisplay.Text="RMB"
alKeyDisplay.TextTruncate=Enum.TextTruncate.AtEnd
alKeyDisplay.Parent=alKeyFrame
corner(alKeyDisplay,6); stroke(alKeyDisplay,COLORS.Accent,1)
aimlockKeyDisplayRef = alKeyDisplay

local alRebindBtn=Instance.new("TextButton")
alRebindBtn.Size=UDim2.fromOffset(90,24)
alRebindBtn.Position=UDim2.new(1,-90,0,0)
alRebindBtn.BackgroundColor3=COLORS.Accent
alRebindBtn.Font=Enum.Font.GothamBold; alRebindBtn.TextSize=11
alRebindBtn.TextColor3=COLORS.Text; alRebindBtn.Text="Rebind"
alRebindBtn.AutoButtonColor=false; alRebindBtn.Parent=alKeyFrame
corner(alRebindBtn,6)
aimlockRebindBtnRef = alRebindBtn

track(alRebindBtn.MouseButton1Click:Connect(function()
	aimlockWaitingRebind=true
	alRebindBtn.Text="กดปุ่ม..."
	task.delay(5,function()
		if aimlockWaitingRebind then
			aimlockWaitingRebind=false
			alRebindBtn.Text="Rebind"
		end
	end)
end))

-- FOV radius + AimPart side-by-side row
local alBottomRow=Instance.new("Frame")
alBottomRow.Position=UDim2.fromOffset(10,218)
alBottomRow.Size=UDim2.new(1,-20,0,80)
alBottomRow.BackgroundTransparency=1; alBottomRow.Parent=pageAimlock

-- FOV radius (left half)
local alFovSub=Instance.new("Frame")
alFovSub.Size=UDim2.new(0.5,-6,1,0)
alFovSub.Position=UDim2.fromOffset(0,0)
alFovSub.BackgroundTransparency=1; alFovSub.Parent=alBottomRow

label(alFovSub,"FOV Radius",12)
label(alFovSub,"radius (px) สำหรับล็อกเป้า",10,{
	Position=UDim2.fromOffset(0,18),Size=UDim2.new(1,0,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local alFovBox=Instance.new("TextBox")
alFovBox.Size=UDim2.new(1,-52,0,24); alFovBox.Position=UDim2.fromOffset(0,44)
alFovBox.BackgroundColor3=COLORS.Button; alFovBox.Font=Enum.Font.Gotham; alFovBox.TextSize=12
alFovBox.TextColor3=COLORS.Text; alFovBox.PlaceholderText="65"
alFovBox.Text="65"; alFovBox.ClearTextOnFocus=false; alFovBox.Parent=alFovSub
corner(alFovBox,6); stroke(alFovBox,COLORS.Accent,1)

local alFovApply=Instance.new("TextButton")
alFovApply.Size=UDim2.fromOffset(44,24); alFovApply.Position=UDim2.new(1,-44,0,44)
alFovApply.BackgroundColor3=COLORS.Accent; alFovApply.Font=Enum.Font.GothamBold
alFovApply.TextSize=11; alFovApply.TextColor3=COLORS.Text; alFovApply.Text="Set"
alFovApply.AutoButtonColor=false; alFovApply.Parent=alFovSub
corner(alFovApply,6)
alFovApply.MouseButton1Click:Connect(function()
	local num=tonumber(alFovBox.Text)
	if num and num>0 then
		_G.CircleRadius=num; FOVCircle.Radius=num
		alFovApply.Text="✓"; task.delay(1,function() alFovApply.Text="Set" end)
	else
		alFovApply.Text="!"; task.delay(1,function() alFovApply.Text="Set" end)
	end
end)

-- AimPart selector (right half)
local alPartSub=Instance.new("Frame")
alPartSub.Size=UDim2.new(0.5,-6,1,0)
alPartSub.Position=UDim2.new(0.5,6,0,0)
alPartSub.BackgroundTransparency=1; alPartSub.Parent=alBottomRow

label(alPartSub,"Aim Part",12)
label(alPartSub,"ส่วนที่จะล็อก",10,{
	Position=UDim2.fromOffset(0,18),Size=UDim2.new(1,0,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})

local aimParts = {"Head","HumanoidRootPart","UpperTorso","Torso"}
local aimPartIdx = 1

-- FIXED: ข้อความไม่ล้นกล่อง + มีพื้นหลัง/กรอบถูกต้อง
local aimPartLabel=Instance.new("TextLabel")
aimPartLabel.Size=UDim2.new(1,-52,0,24); aimPartLabel.Position=UDim2.fromOffset(0,44)
aimPartLabel.BackgroundColor3=COLORS.Button; aimPartLabel.Font=Enum.Font.GothamBold
aimPartLabel.TextSize=10; aimPartLabel.TextColor3=COLORS.Text; aimPartLabel.Text=_G.AimPart
aimPartLabel.TextTruncate=Enum.TextTruncate.AtEnd
aimPartLabel.Parent=alPartSub
corner(aimPartLabel,6); stroke(aimPartLabel,COLORS.Accent,1)

local aimPartBtn=Instance.new("TextButton")
aimPartBtn.Size=UDim2.fromOffset(44,24); aimPartBtn.Position=UDim2.new(1,-44,0,44)
aimPartBtn.BackgroundColor3=COLORS.Accent; aimPartBtn.Font=Enum.Font.GothamBold
aimPartBtn.TextSize=12; aimPartBtn.TextColor3=COLORS.Text; aimPartBtn.Text=">"
aimPartBtn.AutoButtonColor=false; aimPartBtn.Parent=alPartSub
corner(aimPartBtn,6)
aimPartBtn.MouseButton1Click:Connect(function()
	aimPartIdx = (aimPartIdx % #aimParts) + 1
	_G.AimPart = aimParts[aimPartIdx]
	aimPartLabel.Text = _G.AimPart
end)

---------------------------------------------------------------- PAGE: HITBOX
local hbEnableFrame=Instance.new("Frame")
hbEnableFrame.Position=UDim2.fromOffset(10,40)
hbEnableFrame.Size=UDim2.new(1,-20,0,50)
hbEnableFrame.BackgroundTransparency=1; hbEnableFrame.Parent=pageHitbox

label(hbEnableFrame,"Hitbox Expander",12)
label(hbEnableFrame,"ขยาย HumanoidRootPart ของศัตรูให้ยิงง่ายขึ้น",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
makeToggle(hbEnableFrame,"",false,function(state)
	setHitbox(state)
end)

local hbShowFrame=Instance.new("Frame")
hbShowFrame.Position=UDim2.fromOffset(10,100)
hbShowFrame.Size=UDim2.new(1,-20,0,40)
hbShowFrame.BackgroundTransparency=1; hbShowFrame.Parent=pageHitbox

label(hbShowFrame,"Show Hitbox",12)
label(hbShowFrame,"แสดง hitbox ให้มองเห็นได้ (semi-transparent)",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
makeToggle(hbShowFrame,"",false,function(state)
	hitboxShowOn = state
	refreshHitboxVisual()
end)

local hbSizeFrame=Instance.new("Frame")
hbSizeFrame.Position=UDim2.fromOffset(10,150)
hbSizeFrame.Size=UDim2.new(1,-20,0,60)
hbSizeFrame.BackgroundTransparency=1; hbSizeFrame.Parent=pageHitbox

label(hbSizeFrame,"Hitbox Size",12)
label(hbSizeFrame,"ขนาด hitbox เป็น studs (default 50, max 100)",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})

local hbSliderTrack=Instance.new("Frame")
hbSliderTrack.Size=UDim2.new(1,-0,0,6)
hbSliderTrack.Position=UDim2.fromOffset(0,40)
hbSliderTrack.BackgroundColor3=COLORS.Button
hbSliderTrack.Parent=hbSizeFrame
corner(hbSliderTrack,3)
stroke(hbSliderTrack,COLORS.Accent,1)

local hbSliderFill=Instance.new("Frame")
hbSliderFill.Size=UDim2.new(0.5,0,1,0)
hbSliderFill.BackgroundColor3=COLORS.Accent
hbSliderFill.Parent=hbSliderTrack
corner(hbSliderFill,3)

local hbSizeLabel=Instance.new("TextLabel")
hbSizeLabel.Size=UDim2.fromOffset(60,16)
hbSizeLabel.Position=UDim2.new(0.5,-30,0,50)
hbSizeLabel.BackgroundTransparency=1
hbSizeLabel.Font=Enum.Font.GothamBold; hbSizeLabel.TextSize=11
hbSizeLabel.TextColor3=COLORS.Text; hbSizeLabel.Text="50/100"
hbSizeLabel.Parent=hbSizeFrame

local hbSliderDragging=false
local function updateHbSlider(absX)
	local track=hbSliderTrack
	local relX=math.clamp(absX - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
	local frac=relX/track.AbsoluteSize.X
	hitboxSize=math.floor(frac*100+0.5)
	hitboxSize=math.max(1,hitboxSize)
	hbSliderFill.Size=UDim2.new(frac,0,1,0)
	hbSizeLabel.Text=hitboxSize.."/100"
	if hitboxOn then refreshHitboxSize() end
end
hbSliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then
		hbSliderDragging=true
		updateHbSlider(input.Position.X)
	end
end)
hbSliderTrack.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then hbSliderDragging=false end
end)
track(UserInputService.InputChanged:Connect(function(input)
	if hbSliderDragging and input.UserInputType==Enum.UserInputType.MouseMovement then
		updateHbSlider(input.Position.X)
	end
end))

local hbTransFrame=Instance.new("Frame")
hbTransFrame.Position=UDim2.fromOffset(10,230)
hbTransFrame.Size=UDim2.new(1,-20,0,60)
hbTransFrame.BackgroundTransparency=1; hbTransFrame.Parent=pageHitbox

label(hbTransFrame,"Hitbox Transparency",12)
label(hbTransFrame,"ความโปร่งใสของ hitbox ที่มองเห็น (0=ทึบ 1=ใส)",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})

local hbTransTrack=Instance.new("Frame")
hbTransTrack.Size=UDim2.new(1,-0,0,6)
hbTransTrack.Position=UDim2.fromOffset(0,40)
hbTransTrack.BackgroundColor3=COLORS.Button
hbTransTrack.Parent=hbTransFrame
corner(hbTransTrack,3); stroke(hbTransTrack,COLORS.Accent,1)

local hbTransFill=Instance.new("Frame")
hbTransFill.Size=UDim2.new(0.7,0,1,0)
hbTransFill.BackgroundColor3=COLORS.Accent
hbTransFill.Parent=hbTransTrack
corner(hbTransFill,3)

local hbTransLabel=Instance.new("TextLabel")
hbTransLabel.Size=UDim2.fromOffset(60,16)
hbTransLabel.Position=UDim2.new(0.5,-30,0,50)
hbTransLabel.BackgroundTransparency=1
hbTransLabel.Font=Enum.Font.GothamBold; hbTransLabel.TextSize=11
hbTransLabel.TextColor3=COLORS.Text; hbTransLabel.Text="0.7/1"
hbTransLabel.Parent=hbTransFrame

local hbTransDragging=false
local function updateHbTrans(absX)
	local track=hbTransTrack
	local relX=math.clamp(absX - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
	local frac=relX/track.AbsoluteSize.X
	hitboxTransparency=math.floor(frac*10+0.5)/10
	hitboxTransparency=math.clamp(hitboxTransparency,0,1)
	hbTransFill.Size=UDim2.new(frac,0,1,0)
	hbTransLabel.Text=string.format("%.1f/1",hitboxTransparency)
	if hitboxOn and hitboxShowOn then refreshHitboxVisual() end
end
hbTransTrack.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then
		hbTransDragging=true
		updateHbTrans(input.Position.X)
	end
end)
hbTransTrack.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then hbTransDragging=false end
end)
track(UserInputService.InputChanged:Connect(function(input)
	if hbTransDragging and input.UserInputType==Enum.UserInputType.MouseMovement then
		updateHbTrans(input.Position.X)
	end
end))

---------------------------------------------------------------- PAGE: CONFIG
local toggleKey=Enum.KeyCode.RightShift
local FREE_MOUSE_KEY=Enum.KeyCode.RightAlt
local waitingToggleKey,waitingFreeKey=false,false

local keyRow=Instance.new("Frame")
keyRow.Position=UDim2.fromOffset(10,40); keyRow.Size=UDim2.new(1,-20,0,50)
keyRow.BackgroundTransparency=1; keyRow.Parent=pageConfig
label(keyRow,"Toggle UI Key",12)
label(keyRow,"กดปุ่มด้านขวา แล้วกดคีย์ที่ต้องการใช้ซ่อน/แสดง UI",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local keyBtn=Instance.new("TextButton")
keyBtn.Size=UDim2.fromOffset(90,22); keyBtn.Position=UDim2.new(1,-90,0,0)
keyBtn.BackgroundColor3=COLORS.Button; keyBtn.Font=Enum.Font.GothamBold
keyBtn.TextSize=11; keyBtn.TextColor3=COLORS.Text; keyBtn.Text=toggleKey.Name
keyBtn.AutoButtonColor=false; keyBtn.Parent=keyRow
corner(keyBtn,6)
track(keyBtn.MouseButton1Click:Connect(function()
	waitingToggleKey=true; keyBtn.Text="กดปุ่ม..."
end))

local freeMouseRow=Instance.new("Frame")
freeMouseRow.Position=UDim2.fromOffset(10,100); freeMouseRow.Size=UDim2.new(1,-20,0,50)
freeMouseRow.BackgroundTransparency=1; freeMouseRow.Parent=pageConfig
label(freeMouseRow,"Free Mouse",13)
label(freeMouseRow,"สำหรับแมพที่ล็อกเมาส์ กด Right Alt เพื่อสลับ",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local freeKeyBtn=Instance.new("TextButton")
freeKeyBtn.Size=UDim2.fromOffset(90,22); freeKeyBtn.Position=UDim2.new(1,-90,0,0)
freeKeyBtn.BackgroundColor3=COLORS.Button; freeKeyBtn.Font=Enum.Font.GothamBold
freeKeyBtn.TextSize=11; freeKeyBtn.TextColor3=COLORS.Text; freeKeyBtn.Text=FREE_MOUSE_KEY.Name
freeKeyBtn.AutoButtonColor=false; freeKeyBtn.Parent=freeMouseRow
corner(freeKeyBtn,6)
track(freeKeyBtn.MouseButton1Click:Connect(function()
	waitingFreeKey=true; freeKeyBtn.Text="กดปุ่ม..."
end))

local rejoinRow=Instance.new("Frame")
rejoinRow.Position=UDim2.fromOffset(10,160); rejoinRow.Size=UDim2.new(1,-20,0,50)
rejoinRow.BackgroundTransparency=1; rejoinRow.Parent=pageConfig
label(rejoinRow,"Rejoin",12)
label(rejoinRow,"กลับเข้าเซิร์ฟเวอร์เดิมทันที",10,{
	Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim,Font=Enum.Font.Gotham,
})
local rejoinBtn=Instance.new("TextButton")
rejoinBtn.Size=UDim2.fromOffset(90,22); rejoinBtn.Position=UDim2.new(1,-90,0,0)
rejoinBtn.BackgroundColor3=COLORS.Accent; rejoinBtn.Font=Enum.Font.GothamBold
rejoinBtn.TextSize=11; rejoinBtn.TextColor3=COLORS.Text; rejoinBtn.Text="Rejoin"
rejoinBtn.AutoButtonColor=false; rejoinBtn.Parent=rejoinRow
corner(rejoinBtn,6)
track(rejoinBtn.MouseButton1Click:Connect(function()
	local ok,err=pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end)
	if not ok then warn("Rejoin ไม่สำเร็จ: "..tostring(err)) end
end))

---------------------------------------------------------------- close button
local closeBtn=Instance.new("TextButton")
closeBtn.Name="CloseButton"; closeBtn.Size=UDim2.fromOffset(28,28)
closeBtn.Position=UDim2.new(1,-35,0,5); closeBtn.BackgroundColor3=COLORS.Accent
closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=14
closeBtn.TextColor3=COLORS.Text; closeBtn.Text="X"
closeBtn.ZIndex=100; closeBtn.Active=true; closeBtn.AutoButtonColor=true
closeBtn.Parent=main
corner(closeBtn,11)

---------------------------------------------------------------- free mouse
local freeMouseOn=false
local savedBehavior,savedIcon

RunService:BindToRenderStep("FreeMouse",Enum.RenderPriority.Last.Value,function()
	if freeMouseOn and UserInputService.MouseBehavior~=Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior=Enum.MouseBehavior.Default
	end
end)

local function setFreeMouse(on)
	if on==freeMouseOn then return end
	freeMouseOn=on
	if on then
		savedBehavior=UserInputService.MouseBehavior
		savedIcon=UserInputService.MouseIconEnabled
		UserInputService.MouseBehavior=Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled=true
	else
		UserInputService.MouseBehavior=savedBehavior or Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled=savedIcon~=false
	end
end

---------------------------------------------------------------- unload
local function unload()
	pcall(function() setFullbright(false) end)
	pcall(function() setInstantPickup(false) end)
	pcall(function() setFreeMouse(false) end)
	pcall(function() setOpenJump(false) end)
	pcall(function() setNoclip(false) end)
	pcall(function() setWalkSpeed(false) end)
	pcall(function() setGodmode(false) end)
	pcall(function() setESP(false) end)
	pcall(function() setHitbox(false) end)
	pcall(function() UnLockCursor() end)
	pcall(function() FOVCircle:Remove() end)
	if flyTeardown then pcall(flyTeardown); flyTeardown=nil; flyPanel=nil; flyRunning=false end
	pcall(stopSpectate)
	pcall(forceUnfly)
	pcall(function() RunService:UnbindFromRenderStep("FreeMouse") end)
	for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
	connections={}
	if gui and gui.Parent then gui:Destroy() end
	script:Destroy()
end

track(closeBtn.Activated:Connect(unload))

---------------------------------------------------------------- input (toggle key + free mouse)
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if waitingToggleKey then
		if input.UserInputType==Enum.UserInputType.Keyboard then
			toggleKey=input.KeyCode; keyBtn.Text=toggleKey.Name
			waitingToggleKey=false; return
		end
	end
	if waitingFreeKey then
		if input.UserInputType==Enum.UserInputType.Keyboard then
			FREE_MOUSE_KEY=input.KeyCode; freeKeyBtn.Text=FREE_MOUSE_KEY.Name
			waitingFreeKey=false; return
		end
	end
	if gameProcessed then return end
	if input.KeyCode==toggleKey then
		gui.Enabled=not gui.Enabled
	elseif input.KeyCode==FREE_MOUSE_KEY then
		setFreeMouse(not freeMouseOn)
	end
end))

---------------------------------------------------------------- drag (เฉพาะแถบบน)
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, -45, 0, 8)
dragBar.Position = UDim2.fromOffset(0, 0)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.ZIndex = 50
dragBar.Parent = main

local dragging,dragStart,startPos2=false,nil,nil
track(dragBar.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1
		or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true; dragStart=input.Position; startPos2=main.Position
		track(input.Changed:Connect(function()
			if input.UserInputState==Enum.UserInputState.End then dragging=false end
		end))
	end
end))
track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement
		or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		main.Position=UDim2.new(
			startPos2.X.Scale,startPos2.X.Offset+delta.X,
			startPos2.Y.Scale,startPos2.Y.Offset+delta.Y)
	end
end))
