-- LocalScript: วางใน StarterPlayer > StarterPlayerScripts
-- รวม: DeployUI + Answer Reader + Noclip + WalkSpeed + JumpPower

local Players           = game:GetService("Players")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TeleportService   = game:GetService("TeleportService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

---------------------------------------------------------------- helpers
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
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

---------------------------------------------------------------- open jump
local openJumpOn = false
local JUMP_POWER = 50
local JUMP_HEIGHT = 7.2
local jumpRequested = false
local customWalkSpeed = 16
local walkSpeedOn = false
local origJumpPower  = nil  -- เก็บค่าเดิมก่อนเปิด
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
		-- บันทึกค่าเดิมก่อนเปิด
		if hum then
			origJumpPower  = hum.JumpPower
			origJumpHeight = hum.JumpHeight
		end
		restoreJump(hum)
	else
		-- คืนค่าเดิมตอนปิด
		if hum then
			if origJumpPower  then hum.JumpPower  = origJumpPower  end
			if origJumpHeight then hum.JumpHeight = origJumpHeight end
		end
		origJumpPower  = nil
		origJumpHeight = nil
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
		origWalkSpeed = hum.WalkSpeed  -- บันทึกค่าเดิม
		hum.WalkSpeed = customWalkSpeed
	else
		hum.WalkSpeed = origWalkSpeed or 16  -- คืนค่าเดิม
		origWalkSpeed = nil
	end
end

-- re-apply walkspeed on character respawn
track(player.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	if walkSpeedOn then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = customWalkSpeed end
	end
end))

---------------------------------------------------------------- noclip
local noclipOn  = false
local noclipConn = nil

local function setNoclip(state)
	noclipOn = state
	if state then
		noclipConn = RunService.Stepped:Connect(function()
			local char = player.Character
			if not char then return end
			for _, v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide then
					v.CanCollide = false
				end
			end
		end)
	else
		if noclipConn then noclipConn:Disconnect() noclipConn = nil end
		local char = player.Character
		if char then
			for _, v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then v.CanCollide = true end
			end
		end
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
	if spectateConn then spectateConn:Disconnect() spectateConn=nil end
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
	if spectateConn then spectateConn:Disconnect() spectateConn=nil end
	spectateTarget = nil
	setCameraSubject(getOwnHumanoid())
end

local function teleportTo(targetPlayer)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tRoot  = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (myRoot and tRoot) then return end
	myRoot.CFrame = tRoot.CFrame * CFrame.new(0,0,3)
end

---------------------------------------------------------------- answer reader overlay
local TIME_PER_Q = 15
local LETTERS    = {"ก","ข","ค","ง"}
local allQ       = {}

task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("QuizShared", 10)
	if not shared then return end
	local mod = shared:WaitForChild("Questions", 10)
	if not mod or not mod:IsA("ModuleScript") then return end
	local ok, data = pcall(require, mod)
	if ok and type(data) == "table" then
		allQ = data
		print("[AnswerReader] loaded", #allQ, "questions")
	end
end)

local answerGui = Instance.new("ScreenGui")
answerGui.Name          = "AnswerOverlay"
answerGui.ResetOnSpawn  = false
answerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
answerGui.Parent        = playerGui

local answerBadge = Instance.new("TextLabel")
answerBadge.AnchorPoint      = Vector2.new(1, 1)
answerBadge.Position         = UDim2.new(1, -20, 1, -80)
answerBadge.Size             = UDim2.fromOffset(220, 48)
answerBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
answerBadge.TextColor3       = Color3.fromRGB(255, 230, 60)
answerBadge.Font             = Enum.Font.GothamBlack
answerBadge.TextScaled       = true
answerBadge.Text             = "รอคำถาม..."
answerBadge.ZIndex           = 25
answerBadge.Parent           = answerGui
corner(answerBadge, 12)
local badgeStroke = Instance.new("UIStroke", answerBadge)
badgeStroke.Thickness = 2
badgeStroke.Color = Color3.fromRGB(214, 48, 62)

local timerBar = Instance.new("Frame")
timerBar.Size             = UDim2.new(1,0,0,4)
timerBar.Position         = UDim2.new(0,0,1,-4)
timerBar.BackgroundColor3 = Color3.fromRGB(214, 48, 62)
timerBar.BorderSizePixel  = 0
timerBar.Parent           = answerBadge

local function resetBadge()
	answerBadge.Text             = "รอคำถาม..."
	answerBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	answerBadge.TextColor3       = Color3.fromRGB(255, 230, 60)
	badgeStroke.Color            = Color3.fromRGB(214, 48, 62)
	timerBar.Size                = UDim2.fromScale(0,1)
end

local function showAnswer(letter, text, color)
	answerBadge.Text             = letter .. "  " .. text
	answerBadge.BackgroundColor3 = color or Color3.fromRGB(30,140,70)
	answerBadge.TextColor3       = Color3.fromRGB(255,255,255)
	badgeStroke.Color            = Color3.fromRGB(255,255,255)
	timerBar.Size                = UDim2.fromScale(1,1)
	TweenService:Create(timerBar,
		TweenInfo.new(TIME_PER_Q, Enum.EasingStyle.Linear),
		{Size = UDim2.fromScale(0,1)}):Play()
	task.delay(TIME_PER_Q + 1, resetBadge)
end

local function dumpArgs(label2, ...)
	local parts = {label2}
	for i, v in ipairs({...}) do
		if type(v) == "table" then
			local s = "{"
			for k2,v2 in pairs(v) do s = s..tostring(k2).."="..tostring(v2).."," end
			parts[#parts+1] = s.."}"
		else
			parts[#parts+1] = "["..i.."]="..tostring(v)
		end
	end
	print(table.concat(parts," "))
end

local function handlePayload(args, color)
	if type(args[1]) == "table" then
		local t = args[1]
		local answerText = t.answer or t.a or t.correct or t.correctAnswer or t.ans
		local answerIdx  = t.correctIndex or t.correctIdx or t.index
		if answerIdx and type(answerIdx) == "number" then
			local choices = t.choices or t.options or {}
			local text = choices[answerIdx] or tostring(answerIdx)
			showAnswer(LETTERS[answerIdx] or "?", text, color)
			return
		end
		if answerText then
			local choices = t.choices or t.options or {}
			for i, opt in ipairs(choices) do
				if opt == answerText then
					showAnswer(LETTERS[i] or "?", answerText, color)
					return
				end
			end
			showAnswer("→", tostring(answerText), color)
			return
		end
	end
	if #args >= 5 and type(args[#args]) == "number" then
		local idx = args[#args]
		local text = args[1+idx] or tostring(idx)
		showAnswer(LETTERS[idx] or "?", tostring(text), color)
		return
	end
	if type(args[1]) == "number" then
		local idx  = args[1]
		local text = type(args[2]) == "string" and args[2] or tostring(idx)
		showAnswer(LETTERS[idx] or "?", text, color)
		return
	end
	if type(args[1]) == "string" then
		showAnswer("✓", args[1], color)
		return
	end
	resetBadge()
end

task.spawn(function()
	local shared   = ReplicatedStorage:WaitForChild("QuizShared", 15)
	if not shared then return end

	local quizEvent  = shared:WaitForChild("QuizEvent",  15)
	local quizAnswer = shared:WaitForChild("QuizAnswer", 15)

	if quizEvent then
		track(quizEvent.OnClientEvent:Connect(function(...)
			dumpArgs("[QuizEvent]", ...)
			handlePayload({...}, Color3.fromRGB(214,48,62))
		end))
	end

	if quizAnswer then
		track(quizAnswer.OnClientEvent:Connect(function(...)
			dumpArgs("[QuizAnswer]", ...)
			handlePayload({...}, Color3.fromRGB(46,170,90))
		end))
	end
end)

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
main.Parent = gui
corner(main, 12)
stroke(main, COLORS.Accent, 2)

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.fromOffset(10, 10)
sidebar.Size = UDim2.new(0, 110, 1, -20)
sidebar.BackgroundColor3 = COLORS.Sidebar
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
	b.Text = "  "..text
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
funcPanel.Parent = main
corner(funcPanel, 10)
stroke(funcPanel, COLORS.Accent, 1)

local pageTitle = label(funcPanel, "MAIN", 13, {
	Position=UDim2.fromOffset(10,8), Size=UDim2.new(1,-20,0,20),
})

-- pages
local pageMain   = Instance.new("Frame")
pageMain.Size = UDim2.new(1,0,1,0); pageMain.BackgroundTransparency=1; pageMain.Parent=funcPanel

local pageESP    = Instance.new("Frame")
pageESP.Size = UDim2.new(1,0,1,0); pageESP.BackgroundTransparency=1; pageESP.Visible=false; pageESP.Parent=funcPanel

local pageMisc   = Instance.new("Frame")
pageMisc.Size = UDim2.new(1,0,1,0); pageMisc.BackgroundTransparency=1; pageMisc.Visible=false; pageMisc.Parent=funcPanel

local pageConfig = Instance.new("Frame")
pageConfig.Size = UDim2.new(1,0,1,0); pageConfig.BackgroundTransparency=1; pageConfig.Visible=false; pageConfig.Parent=funcPanel

local function showPage(name)
	pageMain.Visible   = name == "Main"
	pageESP.Visible    = name == "ESP"
	pageMisc.Visible   = name == "Misc"
	pageConfig.Visible = name == "Config"
	pageTitle.Text = string.upper(name)
end

navItem("Main",   function() showPage("Main")   end)
navItem("ESP",    function() showPage("ESP")     end)
navItem("Misc",   function() showPage("Misc")    end)
navItem("Config", function() showPage("Config")  end)

---------------------------------------------------------------- PAGE: MAIN (Fly only)
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
flyBtn.Size = UDim2.fromOffset(90,22)
flyBtn.Position = UDim2.new(1,-90,0,0)
flyBtn.BackgroundColor3 = COLORS.Accent
flyBtn.Font = Enum.Font.GothamBold; flyBtn.TextSize=11
flyBtn.TextColor3 = COLORS.Text; flyBtn.Text = "Click"
flyBtn.AutoButtonColor = false; flyBtn.Parent = flyRow
corner(flyBtn, 6)
flyBtnRef = flyBtn
track(flyBtn.MouseButton1Click:Connect(toggleFlyPanel))

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

-- Fullbright
local fbRow = miscRow(pageMisc, 40, "Fullbright", "ทำให้แมพสว่างขึ้น (เฉพาะคุณที่เห็น)")
local fbToggle = makeToggle(fbRow, "", false, function(state) setFullbright(state) end)
fbToggle.Size = UDim2.new(1,0,0,28); fbToggle.Position = UDim2.fromOffset(0,0)

-- Take Item 1 Click
local takeRow = miscRow(pageMisc, 100, "Take Item 1 Click", "เก็บของกดครั้งเดียวทันที (เฉพาะคุณที่เห็น)")
local takeToggle = makeToggle(takeRow, "", false, function(state) setInstantPickup(state) end)
takeToggle.Size = UDim2.new(1,0,0,28); takeToggle.Position = UDim2.fromOffset(0,0)

-- helper: input box + apply button
local function makeInputRow(parent, yOffset, titleText, descText, defaultVal, placeholder, onApply)
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(10, yOffset)
	row.Size = UDim2.new(1, -20, 0, 70)
	row.BackgroundTransparency = 1
	row.Parent = parent
	label(row, titleText, 12)
	label(row, descText, 10, {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -50, 0, 14),
		TextColor3 = COLORS.Dim, Font = Enum.Font.Gotham,
	})
	-- input box
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -100, 0, 24)
	box.Position = UDim2.fromOffset(0, 42)
	box.BackgroundColor3 = COLORS.Button
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.TextColor3 = COLORS.Text
	box.PlaceholderText = placeholder
	box.Text = tostring(defaultVal)
	box.ClearTextOnFocus = false
	box.Parent = row
	corner(box, 6)
	Instance.new("UIStroke", box).Color = COLORS.Accent

	-- apply button
	local applyBtn = Instance.new("TextButton")
	applyBtn.Size = UDim2.fromOffset(80, 24)
	applyBtn.Position = UDim2.new(1, -80, 0, 42)
	applyBtn.BackgroundColor3 = COLORS.Accent
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.TextSize = 11
	applyBtn.TextColor3 = COLORS.Text
	applyBtn.Text = "Apply"
	applyBtn.AutoButtonColor = false
	applyBtn.Parent = row
	corner(applyBtn, 6)

	applyBtn.MouseButton1Click:Connect(function()
		local num = tonumber(box.Text)
		if num then
			onApply(num)
			applyBtn.Text = "✓"
			task.delay(1, function() applyBtn.Text = "Apply" end)
		else
			applyBtn.Text = "!"
			task.delay(1, function() applyBtn.Text = "Apply" end)
		end
	end)

	return row, box
end

-- Open Jump (toggle + jump power input)
local jumpContainerY = 160
local jumpContainer = Instance.new("Frame")
jumpContainer.Position = UDim2.fromOffset(10, jumpContainerY)
jumpContainer.Size = UDim2.new(1, -20, 0, 100)
jumpContainer.BackgroundTransparency = 1
jumpContainer.Parent = pageMisc

label(jumpContainer, "Open Jump", 12)
label(jumpContainer, "ถ้าแมพไหนกระโดดไม่ได้ให้กดเปิด (เฉพาะคุณที่เห็น)", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim, Font = Enum.Font.Gotham,
})
local jumpToggle = makeToggle(jumpContainer, "", false, function(state) setOpenJump(state) end)
jumpToggle.Size = UDim2.new(1,0,0,28); jumpToggle.Position = UDim2.fromOffset(0,0)

-- jump power input row inside container
local jpBox = Instance.new("TextBox")
jpBox.Size = UDim2.new(1, -100, 0, 24)
jpBox.Position = UDim2.fromOffset(0, 68)
jpBox.BackgroundColor3 = COLORS.Button
jpBox.Font = Enum.Font.Gotham; jpBox.TextSize = 12
jpBox.TextColor3 = COLORS.Text
jpBox.PlaceholderText = "Jump Power (default 50)"
jpBox.Text = "50"
jpBox.ClearTextOnFocus = false
jpBox.Parent = jumpContainer
corner(jpBox, 6)
Instance.new("UIStroke", jpBox).Color = COLORS.Accent

local jpApply = Instance.new("TextButton")
jpApply.Size = UDim2.fromOffset(80, 24)
jpApply.Position = UDim2.new(1, -80, 0, 68)
jpApply.BackgroundColor3 = COLORS.Accent
jpApply.Font = Enum.Font.GothamBold; jpApply.TextSize = 11
jpApply.TextColor3 = COLORS.Text; jpApply.Text = "Apply"
jpApply.AutoButtonColor = false; jpApply.Parent = jumpContainer
corner(jpApply, 6)

jpApply.MouseButton1Click:Connect(function()
	local num = tonumber(jpBox.Text)
	if num and num > 0 then
		JUMP_POWER  = num
		JUMP_HEIGHT = num * 0.144  -- approximate height from power
		local hum = getHum()
		if hum then
			if hum.UseJumpPower then hum.JumpPower = JUMP_POWER
			else hum.JumpHeight = JUMP_HEIGHT end
		end
		jpApply.Text = "✓"
		task.delay(1, function() jpApply.Text = "Apply" end)
	else
		jpApply.Text = "!"
		task.delay(1, function() jpApply.Text = "Apply" end)
	end
end)

-- WalkSpeed (toggle + speed input)
local wsContainerY = jumpContainerY + 110
local wsContainer = Instance.new("Frame")
wsContainer.Position = UDim2.fromOffset(10, wsContainerY)
wsContainer.Size = UDim2.new(1, -20, 0, 100)
wsContainer.BackgroundTransparency = 1
wsContainer.Parent = pageMisc

label(wsContainer, "Walk Speed", 12)
label(wsContainer, "ปรับความเร็ววิ่ง (ค่าปกติ 16)", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim, Font = Enum.Font.Gotham,
})
local wsToggle = makeToggle(wsContainer, "", false, function(state) setWalkSpeed(state) end)
wsToggle.Size = UDim2.new(1,0,0,28); wsToggle.Position = UDim2.fromOffset(0,0)

local wsBox = Instance.new("TextBox")
wsBox.Size = UDim2.new(1, -100, 0, 24)
wsBox.Position = UDim2.fromOffset(0, 68)
wsBox.BackgroundColor3 = COLORS.Button
wsBox.Font = Enum.Font.Gotham; wsBox.TextSize = 12
wsBox.TextColor3 = COLORS.Text
wsBox.PlaceholderText = "ความเร็ว (default 16)"
wsBox.Text = "16"
wsBox.ClearTextOnFocus = false
wsBox.Parent = wsContainer
corner(wsBox, 6)
Instance.new("UIStroke", wsBox).Color = COLORS.Accent

local wsApply = Instance.new("TextButton")
wsApply.Size = UDim2.fromOffset(80, 24)
wsApply.Position = UDim2.new(1, -80, 0, 68)
wsApply.BackgroundColor3 = COLORS.Accent
wsApply.Font = Enum.Font.GothamBold; wsApply.TextSize = 11
wsApply.TextColor3 = COLORS.Text; wsApply.Text = "Apply"
wsApply.AutoButtonColor = false; wsApply.Parent = wsContainer
corner(wsApply, 6)

wsApply.MouseButton1Click:Connect(function()
	local num = tonumber(wsBox.Text)
	if num and num > 0 then
		applyWalkSpeed(num)
		wsApply.Text = "✓"
		task.delay(1, function() wsApply.Text = "Apply" end)
	else
		wsApply.Text = "!"
		task.delay(1, function() wsApply.Text = "Apply" end)
	end
end)

-- Noclip
local noclipRow = miscRow(pageMisc, wsContainerY + 110, "Noclip", "เดินทะลุกำแพงและพื้น (เฉพาะคุณที่เห็น)")
local noclipToggle = makeToggle(noclipRow, "", false, function(state) setNoclip(state) end)
noclipToggle.Size = UDim2.new(1,0,0,28); noclipToggle.Position = UDim2.fromOffset(0,0)

---------------------------------------------------------------- PAGE: ESP
local countLabel = label(pageESP, "Players in server: 0", 12, {
	Position=UDim2.fromOffset(10,40), Size=UDim2.new(1,-230,0,18),
})

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size=UDim2.fromOffset(90,22); refreshBtn.Position=UDim2.new(1,-100,0,38)
refreshBtn.BackgroundColor3=COLORS.Accent; refreshBtn.Font=Enum.Font.GothamBold
refreshBtn.TextSize=11; refreshBtn.TextColor3=COLORS.Text; refreshBtn.Text="Refresh"
refreshBtn.AutoButtonColor=false; refreshBtn.Parent=pageESP
corner(refreshBtn, 6)

local stopBtn = Instance.new("TextButton")
stopBtn.Size=UDim2.fromOffset(100,22); stopBtn.Position=UDim2.new(1,-210,0,38)
stopBtn.BackgroundColor3=COLORS.Accent; stopBtn.Font=Enum.Font.GothamBold
stopBtn.TextSize=11; stopBtn.TextColor3=COLORS.Text; stopBtn.Text="Stop Spectate"
stopBtn.AutoButtonColor=false; stopBtn.Parent=pageESP
corner(stopBtn, 6)
track(stopBtn.MouseButton1Click:Connect(stopSpectate))

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position=UDim2.fromOffset(10,68); listFrame.Size=UDim2.new(1,-20,1,-78)
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
			local specBtn = Instance.new("TextButton")
			specBtn.Size=UDim2.fromOffset(56,20); specBtn.Position=UDim2.new(1,-120,0.5,-10)
			specBtn.BackgroundColor3=COLORS.Accent; specBtn.Font=Enum.Font.GothamBold
			specBtn.TextSize=10; specBtn.TextColor3=COLORS.Text; specBtn.Text="Spectate"
			specBtn.AutoButtonColor=false; specBtn.Parent=row
			corner(specBtn, 5)
			track(specBtn.MouseButton1Click:Connect(function() spectate(p) end))
			local tpBtn = Instance.new("TextButton")
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
track(Players.PlayerRemoving:Connect(function() task.wait() refreshPlayers() end))
refreshPlayers()

---------------------------------------------------------------- PAGE: CONFIG
local toggleKey = Enum.KeyCode.RightShift
local FREE_MOUSE_KEY = Enum.KeyCode.RightAlt
local waitingToggleKey, waitingFreeKey = false, false

local keyRow = Instance.new("Frame")
keyRow.Position=UDim2.fromOffset(10,40); keyRow.Size=UDim2.new(1,-20,0,50)
keyRow.BackgroundTransparency=1; keyRow.Parent=pageConfig
label(keyRow, "Toggle UI Key", 12)
label(keyRow, "กดปุ่มด้านขวา แล้วกดคีย์ที่ต้องการใช้ซ่อน/แสดง UI", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local keyBtn = Instance.new("TextButton")
keyBtn.Size=UDim2.fromOffset(90,22); keyBtn.Position=UDim2.new(1,-90,0,0)
keyBtn.BackgroundColor3=COLORS.Button; keyBtn.Font=Enum.Font.GothamBold
keyBtn.TextSize=11; keyBtn.TextColor3=COLORS.Text; keyBtn.Text=toggleKey.Name
keyBtn.AutoButtonColor=false; keyBtn.Parent=keyRow
corner(keyBtn, 6)
track(keyBtn.MouseButton1Click:Connect(function()
	waitingToggleKey=true; keyBtn.Text="กดปุ่ม..."
end))

local freeMouseRow = Instance.new("Frame")
freeMouseRow.Position=UDim2.fromOffset(10,100); freeMouseRow.Size=UDim2.new(1,-20,0,50)
freeMouseRow.BackgroundTransparency=1; freeMouseRow.Parent=pageConfig
label(freeMouseRow, "Free Mouse", 13)
label(freeMouseRow, "สำหรับแมพที่ล็อกเมาส์ กด Right Alt เพื่อสลับ", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local freeKeyBtn = Instance.new("TextButton")
freeKeyBtn.Size=UDim2.fromOffset(90,22); freeKeyBtn.Position=UDim2.new(1,-90,0,0)
freeKeyBtn.BackgroundColor3=COLORS.Button; freeKeyBtn.Font=Enum.Font.GothamBold
freeKeyBtn.TextSize=11; freeKeyBtn.TextColor3=COLORS.Text; freeKeyBtn.Text=FREE_MOUSE_KEY.Name
freeKeyBtn.AutoButtonColor=false; freeKeyBtn.Parent=freeMouseRow
corner(freeKeyBtn, 6)
track(freeKeyBtn.MouseButton1Click:Connect(function()
	waitingFreeKey=true; freeKeyBtn.Text="กดปุ่ม..."
end))

local rejoinRow = Instance.new("Frame")
rejoinRow.Position=UDim2.fromOffset(10,160); rejoinRow.Size=UDim2.new(1,-20,0,50)
rejoinRow.BackgroundTransparency=1; rejoinRow.Parent=pageConfig
label(rejoinRow, "Rejoin", 12)
label(rejoinRow, "กลับเข้าเซิร์ฟเวอร์เดิมทันที", 10, {
	Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,-50,0,14),
	TextColor3=COLORS.Dim, Font=Enum.Font.Gotham,
})
local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size=UDim2.fromOffset(90,22); rejoinBtn.Position=UDim2.new(1,-90,0,0)
rejoinBtn.BackgroundColor3=COLORS.Accent; rejoinBtn.Font=Enum.Font.GothamBold
rejoinBtn.TextSize=11; rejoinBtn.TextColor3=COLORS.Text; rejoinBtn.Text="Rejoin"
rejoinBtn.AutoButtonColor=false; rejoinBtn.Parent=rejoinRow
corner(rejoinBtn, 6)
track(rejoinBtn.MouseButton1Click:Connect(function()
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end)
	if not ok then warn("Rejoin ไม่สำเร็จ: "..tostring(err)) end
end))

---------------------------------------------------------------- close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name="CloseButton"; closeBtn.Size=UDim2.fromOffset(28,28)
closeBtn.Position=UDim2.new(1,-35,0,5); closeBtn.BackgroundColor3=COLORS.Accent
closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=14
closeBtn.TextColor3=COLORS.Text; closeBtn.Text="X"
closeBtn.ZIndex=100; closeBtn.Active=true; closeBtn.AutoButtonColor=true
closeBtn.Parent=main
corner(closeBtn, 11)

---------------------------------------------------------------- free mouse
local freeMouseOn = false
local savedBehavior, savedIcon

RunService:BindToRenderStep("FreeMouse", Enum.RenderPriority.Last.Value, function()
	if freeMouseOn and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

local function setFreeMouse(on)
	if on == freeMouseOn then return end
	freeMouseOn = on
	if on then
		savedBehavior = UserInputService.MouseBehavior
		savedIcon = UserInputService.MouseIconEnabled
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = savedBehavior or Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = savedIcon ~= false
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
	if flyTeardown then pcall(flyTeardown); flyTeardown=nil; flyPanel=nil; flyRunning=false end
	pcall(stopSpectate)
	pcall(forceUnfly)
	pcall(function() RunService:UnbindFromRenderStep("FreeMouse") end)
	for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
	connections = {}
	if gui and gui.Parent then gui:Destroy() end
	if answerGui and answerGui.Parent then answerGui:Destroy() end
	script:Destroy()
end

track(closeBtn.Activated:Connect(unload))

---------------------------------------------------------------- input
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if waitingToggleKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			toggleKey = input.KeyCode; keyBtn.Text = toggleKey.Name
			waitingToggleKey = false; return
		end
	end
	if waitingFreeKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			FREE_MOUSE_KEY = input.KeyCode; freeKeyBtn.Text = FREE_MOUSE_KEY.Name
			waitingFreeKey = false; return
		end
	end
	if gameProcessed then return end
	if input.KeyCode == toggleKey then gui.Enabled = not gui.Enabled
	elseif input.KeyCode == FREE_MOUSE_KEY then setFreeMouse(not freeMouseOn)
	end
end))

---------------------------------------------------------------- drag
local dragging, dragStart, startPos2 = false, nil, nil
track(main.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging=true; dragStart=input.Position; startPos2=main.Position
		track(input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging=false end
		end))
	end
end))
track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos2.X.Scale, startPos2.X.Offset+delta.X,
			startPos2.Y.Scale, startPos2.Y.Offset+delta.Y)
	end
end))
