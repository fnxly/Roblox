-- LocalScript: วางใน StarterPlayer > StarterPlayerScripts
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
	Bg = Color3.fromRGB(35, 20, 25),
	Sidebar = Color3.fromRGB(42, 22, 28),
	Panel = Color3.fromRGB(28, 16, 20),
	Accent = Color3.fromRGB(190, 35, 45),
	Text = Color3.fromRGB(240, 230, 230),
	Dim = Color3.fromRGB(150, 115, 120),
	Button = Color3.fromRGB(62, 36, 44),
}

-- เก็บ connection ทั้งหมดไว้ เพื่อ disconnect ตอนปิด UI
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
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

-- คืนค่า row, setState (ใช้ตั้งสวิตช์จากภายนอกได้)
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

	track(track_btn.MouseButton1Click:Connect(function()
		setState(not state)
	end))

	return row, setState
end

---------------------------------------------------------------- fullbright logic
local FULLBRIGHT = {
	Brightness = 1,
	ClockTime = 12,
	FogEnd = 786543,
	GlobalShadows = false,
	Ambient = Color3.fromRGB(178, 178, 178),
}

local fullbrightOn = false
local originals = {}

local function setFullbright(state)
	if state == fullbrightOn then return end
	fullbrightOn = state

	if state then
		for prop in pairs(FULLBRIGHT) do
			originals[prop] = Lighting[prop]
		end
		for prop, value in pairs(FULLBRIGHT) do
			Lighting[prop] = value
		end
	else
		for prop, value in pairs(originals) do
			Lighting[prop] = value
		end
	end
end

for prop in pairs(FULLBRIGHT) do
	track(Lighting:GetPropertyChangedSignal(prop):Connect(function()
		if fullbrightOn and Lighting[prop] ~= FULLBRIGHT[prop] then
			Lighting[prop] = FULLBRIGHT[prop]
		end
	end))
end

---------------------------------------------------------------- instant pickup logic
local instantOn = false
local promptOriginals = {} -- [ProximityPrompt] = ค่า HoldDuration เดิม

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
			if obj:IsA("ProximityPrompt") then
				setInstantPrompt(obj)
			end
		end
	else
		for prompt, value in pairs(promptOriginals) do
			if prompt.Parent then
				prompt.HoldDuration = value
			end
		end
		promptOriginals = {}
	end
end

-- prompt ที่เกิดใหม่ตอนเปิดอยู่ ให้แก้ทันที และกันสคริปต์อื่นตั้งค่ากลับ
track(workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") then
		if instantOn then
			setInstantPrompt(obj)
		end
		track(obj:GetPropertyChangedSignal("HoldDuration"):Connect(function()
			if instantOn and obj.HoldDuration ~= 0 then
				obj.HoldDuration = 0
			end
		end))
	end
end))

---------------------------------------------------------------- spectate logic
local spectateTarget = nil
local originalSubject = nil
local originalCameraType = nil

local function getHumanoid(p)
	return p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function stopSpectate()
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = originalCameraType or Enum.CameraType.Custom
		cam.CameraSubject = originalSubject or getHumanoid(player)
	end
	spectateTarget = nil
end

local function spectate(p)
	local cam = workspace.CurrentCamera
	local hum = getHumanoid(p)
	if not cam or not hum then return end

	if not spectateTarget then
		originalSubject = cam.CameraSubject
		originalCameraType = cam.CameraType
	end
	spectateTarget = p
	cam.CameraType = Enum.CameraType.Custom
	cam.CameraSubject = hum
end

---------------------------------------------------------------- teleport logic
local function teleportTo(p)
	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot or not targetRoot then return end

	-- วางตัวเราห่างจากเป้าหมายเล็กน้อย กันทับกัน
	myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
end

---------------------------------------------------------------- main window
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

-- Sidebar
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

-- Profile ด้านล่าง
local profile = Instance.new("Frame")
profile.Size = UDim2.new(1, -10, 0, 44)
profile.Position = UDim2.new(0, 5, 1, -50)
profile.BackgroundColor3 = COLORS.Button
profile.Parent = sidebar
corner(profile, 8)

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.fromOffset(32, 32)
avatar.Position = UDim2.fromOffset(6, 6)
avatar.BackgroundColor3 = COLORS.Panel
avatar.Parent = profile
corner(avatar, 16)
task.spawn(function()
	pcall(function()
		avatar.Image = Players:GetUserThumbnailAsync(
			player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48
		)
	end)
end)

label(profile, player.DisplayName, 11, {
	Position = UDim2.fromOffset(44, 7),
	Size = UDim2.new(1, -50, 0, 16),
})
label(profile, "@" .. player.Name, 9, {
	Position = UDim2.fromOffset(44, 23),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

-- หน้าหลัก (panel ด้านขวา)
local funcPanel = Instance.new("Frame")
funcPanel.Position = UDim2.fromOffset(130, 10)
funcPanel.Size = UDim2.new(1, -140, 1, -20)
funcPanel.BackgroundColor3 = COLORS.Panel
funcPanel.Parent = main
corner(funcPanel, 10)
stroke(funcPanel, COLORS.Accent, 1)

local pageTitle = label(funcPanel, "MAIN", 13, {
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -20, 0, 20),
})

-- แต่ละหน้าอยู่ใน frame ของตัวเอง
local pageMain = Instance.new("Frame")
pageMain.Size = UDim2.new(1, 0, 1, 0)
pageMain.BackgroundTransparency = 1
pageMain.Parent = funcPanel

local pageESP = Instance.new("Frame")
pageESP.Size = UDim2.new(1, 0, 1, 0)
pageESP.BackgroundTransparency = 1
pageESP.Visible = false
pageESP.Parent = funcPanel

local pageConfig = Instance.new("Frame")
pageConfig.Size = UDim2.new(1, 0, 1, 0)
pageConfig.BackgroundTransparency = 1
pageConfig.Visible = false
pageConfig.Parent = funcPanel

local function showPage(name)
	pageMain.Visible = name == "Main"
	pageESP.Visible = name == "ESP"
	pageConfig.Visible = name == "Config"
	pageTitle.Text = string.upper(name)
end

navItem("Main", function() showPage("Main") end)
navItem("ESP", function() showPage("ESP") end)
navItem("Config", function() showPage("Config") end)

---------------------------------------------------------------- PAGE: MAIN
-- หัวข้อ Fullbright
local fullbrightRow = Instance.new("Frame")
fullbrightRow.Position = UDim2.fromOffset(10, 40)
fullbrightRow.Size = UDim2.new(1, -20, 0, 50)
fullbrightRow.BackgroundTransparency = 1
fullbrightRow.Parent = pageMain

label(fullbrightRow, "Fullbright", 13)
label(fullbrightRow, "ทำให้แมพสว่างขึ้น (เฉพาะคุณที่เห็น)", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

local fullbrightToggle = makeToggle(fullbrightRow, "", false, function(state)
	setFullbright(state)
end)
fullbrightToggle.Size = UDim2.new(1, 0, 0, 28)
fullbrightToggle.Position = UDim2.fromOffset(0, 0)

-- หัวข้อ TAKE ITEM 1 CLICK DONT HOLD TIME
local instantRow = Instance.new("Frame")
instantRow.Position = UDim2.fromOffset(10, 100)
instantRow.Size = UDim2.new(1, -20, 0, 50)
instantRow.BackgroundTransparency = 1
instantRow.Parent = pageMain

label(instantRow, "TAKE ITEM 1 CLICK DONT HOLD TIME", 12)
label(instantRow, "เก็บของกดครั้งเดียวทันที ไม่ต้องกดค้าง (เฉพาะคุณที่เห็น)", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

local instantToggle = makeToggle(instantRow, "", false, function(state)
	setInstantPickup(state)
end)
instantToggle.Size = UDim2.new(1, 0, 0, 28)
instantToggle.Position = UDim2.fromOffset(0, 0)

-- หัวข้อ Fly
local flyRow = Instance.new("Frame")
flyRow.Position = UDim2.fromOffset(10, 160)
flyRow.Size = UDim2.new(1, -20, 0, 50)
flyRow.BackgroundTransparency = 1
flyRow.Parent = pageMain

label(flyRow, "Fly", 12)
label(flyRow, "กดครั้งเดียวเพื่อเรียกใช้ฟังชั่น FLY", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

local flyBtn = Instance.new("TextButton")
flyBtn.Size = UDim2.fromOffset(90, 22)
flyBtn.Position = UDim2.new(1, -90, 0, 0)
flyBtn.BackgroundColor3 = COLORS.Accent
flyBtn.Font = Enum.Font.GothamBold
flyBtn.TextSize = 11
flyBtn.TextColor3 = COLORS.Text
flyBtn.Text = "Click"
flyBtn.AutoButtonColor = false
flyBtn.Parent = flyRow
corner(flyBtn, 6)

track(flyBtn.MouseButton1Click:Connect(function()
	-- ใส่โค้ดบินของคุณตรงนี้
end))

---------------------------------------------------------------- PAGE: ESP (Players + Spectate + TP)
local countLabel = label(pageESP, "Players in server: 0", 12, {
	Position = UDim2.fromOffset(10, 40),
	Size = UDim2.new(1, -230, 0, 18), -- แคบลงเพื่อเว้นที่ให้ปุ่ม Stop Spectate
})

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.fromOffset(90, 22)
refreshBtn.Position = UDim2.new(1, -100, 0, 38)
refreshBtn.BackgroundColor3 = COLORS.Accent
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 11
refreshBtn.TextColor3 = COLORS.Text
refreshBtn.Text = "Refresh"
refreshBtn.AutoButtonColor = false
refreshBtn.Parent = pageESP
corner(refreshBtn, 6)

-- ปุ่ม Stop Spectate อยู่ข้าง Refresh (สร้างครั้งเดียว)
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.fromOffset(100, 22)
stopBtn.Position = UDim2.new(1, -210, 0, 38)
stopBtn.BackgroundColor3 = COLORS.Accent
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 11
stopBtn.TextColor3 = COLORS.Text
stopBtn.Text = "Stop Spectate"
stopBtn.AutoButtonColor = false
stopBtn.Parent = pageESP
corner(stopBtn, 6)
track(stopBtn.MouseButton1Click:Connect(stopSpectate))

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position = UDim2.fromOffset(10, 68)
listFrame.Size = UDim2.new(1, -20, 1, -78)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 3
listFrame.CanvasSize = UDim2.new()
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = pageESP

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = listFrame

local function refreshPlayers()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
	end

	local all = Players:GetPlayers()
	countLabel.Text = "Players in server: " .. #all

	for _, p in ipairs(all) do
		if p ~= player then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -6, 0, 26)
			row.BackgroundColor3 = COLORS.Button
			row.Parent = listFrame
			corner(row, 6)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -130, 1, 0)
			nameLbl.Position = UDim2.fromOffset(6, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.Gotham
			nameLbl.TextSize = 12
			nameLbl.TextColor3 = COLORS.Text
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.Text = p.DisplayName .. " (@" .. p.Name .. ")"
			nameLbl.Parent = row

			local specBtn = Instance.new("TextButton")
			specBtn.Size = UDim2.fromOffset(56, 20)
			specBtn.Position = UDim2.new(1, -120, 0.5, -10)
			specBtn.BackgroundColor3 = COLORS.Accent
			specBtn.Font = Enum.Font.GothamBold
			specBtn.TextSize = 10
			specBtn.TextColor3 = COLORS.Text
			specBtn.Text = "Spectate"
			specBtn.AutoButtonColor = false
			specBtn.Parent = row
			corner(specBtn, 5)
			track(specBtn.MouseButton1Click:Connect(function()
				spectate(p)
			end))

			local tpBtn = Instance.new("TextButton")
			tpBtn.Size = UDim2.fromOffset(52, 20)
			tpBtn.Position = UDim2.new(1, -58, 0.5, -10)
			tpBtn.BackgroundColor3 = COLORS.Accent
			tpBtn.Font = Enum.Font.GothamBold
			tpBtn.TextSize = 10
			tpBtn.TextColor3 = COLORS.Text
			tpBtn.Text = "TP"
			tpBtn.AutoButtonColor = false
			tpBtn.Parent = row
			corner(tpBtn, 5)
			track(tpBtn.MouseButton1Click:Connect(function()
				teleportTo(p)
			end))
		end
	end
end

track(refreshBtn.MouseButton1Click:Connect(refreshPlayers))
track(Players.PlayerAdded:Connect(refreshPlayers))
track(Players.PlayerRemoving:Connect(function()
	task.wait()
	refreshPlayers()
end))
refreshPlayers()

---------------------------------------------------------------- PAGE: CONFIG
-- หัวข้อตั้งปุ่มซ่อน/แสดง UI (พิมพ์ชื่อปุ่มได้)
local toggleKey = Enum.KeyCode.RightShift

local keyRow = Instance.new("Frame")
keyRow.Position = UDim2.fromOffset(10, 40)
keyRow.Size = UDim2.new(1, -20, 0, 50)
keyRow.BackgroundTransparency = 1
keyRow.Parent = pageConfig

local waitingToggleKey = false

label(keyRow, "Toggle UI Key", 12)
label(keyRow, "กดปุ่มด้านขวา แล้วกดคีย์ที่ต้องการใช้ซ่อน/แสดง UI", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

local keyBtn = Instance.new("TextButton")
keyBtn.Size = UDim2.fromOffset(90, 22)
keyBtn.Position = UDim2.new(1, -90, 0, 0)
keyBtn.BackgroundColor3 = COLORS.Button
keyBtn.Font = Enum.Font.GothamBold
keyBtn.TextSize = 11
keyBtn.TextColor3 = COLORS.Text
keyBtn.Text = toggleKey.Name
keyBtn.AutoButtonColor = false
keyBtn.Parent = keyRow
corner(keyBtn, 6)

track(keyBtn.MouseButton1Click:Connect(function()
	waitingToggleKey = true
	keyBtn.Text = "กดปุ่ม..."
end))

-- หัวข้อ Free Mouse
local FREE_MOUSE_KEY = Enum.KeyCode.RightAlt
local waitingFreeKey = false

local freeMouseRow = Instance.new("Frame")
freeMouseRow.Position = UDim2.fromOffset(10, 100)
freeMouseRow.Size = UDim2.new(1, -20, 0, 50)
freeMouseRow.BackgroundTransparency = 1
freeMouseRow.Parent = pageConfig

label(freeMouseRow, "Free Mouse", 13)
label(freeMouseRow, "สำหรับแมพที่ล็อกเมาส์ กด Right Alt เพื่อสลับ", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

local freeKeyBtn = Instance.new("TextButton")
freeKeyBtn.Size = UDim2.fromOffset(90, 22)
freeKeyBtn.Position = UDim2.new(1, -90, 0, 0)
freeKeyBtn.BackgroundColor3 = COLORS.Button
freeKeyBtn.Font = Enum.Font.GothamBold
freeKeyBtn.TextSize = 11
freeKeyBtn.TextColor3 = COLORS.Text
freeKeyBtn.Text = FREE_MOUSE_KEY.Name
freeKeyBtn.AutoButtonColor = false
freeKeyBtn.Parent = freeMouseRow
corner(freeKeyBtn, 6)

track(freeKeyBtn.MouseButton1Click:Connect(function()
	waitingFreeKey = true
	freeKeyBtn.Text = "กดปุ่ม..."
end))

-- หัวข้อ Rejoin
local rejoinRow = Instance.new("Frame")
rejoinRow.Position = UDim2.fromOffset(10, 160)
rejoinRow.Size = UDim2.new(1, -20, 0, 50)
rejoinRow.BackgroundTransparency = 1
rejoinRow.Parent = pageConfig

label(rejoinRow, "Rejoin", 12)
label(rejoinRow, "กลับเข้าเซิร์ฟเวอร์เดิมทันที", 10, {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, -50, 0, 14),
	TextColor3 = COLORS.Dim,
	Font = Enum.Font.Gotham,
})

local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.fromOffset(90, 22)
rejoinBtn.Position = UDim2.new(1, -90, 0, 0)
rejoinBtn.BackgroundColor3 = COLORS.Accent
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 11
rejoinBtn.TextColor3 = COLORS.Text
rejoinBtn.Text = "Rejoin"
rejoinBtn.AutoButtonColor = false
rejoinBtn.Parent = rejoinRow
corner(rejoinBtn, 6)

track(rejoinBtn.MouseButton1Click:Connect(function()
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end)
	if not ok then
		warn("Rejoin ไม่สำเร็จ: " .. tostring(err))
	end
end))

-- ปุ่มปิด (X) ลบทุกอย่างของสคริปต์ออก
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(22, 22)
closeBtn.Position = UDim2.new(1, -28, 0, -10)
closeBtn.BackgroundColor3 = COLORS.Accent
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.TextColor3 = COLORS.Text
closeBtn.Text = "X"
closeBtn.Parent = main
corner(closeBtn, 11)

---------------------------------------------------------------- free mouse logic
local freeMouseOn = false
local savedBehavior, savedIcon

-- ทุกเฟรม บังคับให้เมาส์ไม่ล็อกกลางจอ (ทำงานหลังสคริปต์กล้องของเกม)
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

---------------------------------------------------------------- unload (ปุ่ม X)
local function unload()
	-- คืนค่าทุกอย่างที่เปลี่ยนไปก่อน
	setFullbright(false)
	setInstantPickup(false)
	setFreeMouse(false)
	stopSpectate()
	RunService:UnbindFromRenderStep("FreeMouse")

	-- ตัดการเชื่อมต่อ event ทั้งหมด
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}

	-- ลบ UI และตัวสคริปต์
	gui:Destroy()
	script:Destroy()
end

track(closeBtn.MouseButton1Click:Connect(unload))

---------------------------------------------------------------- input handling (keybinds)
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- รับปุ่มใหม่สำหรับ Toggle UI
	if waitingToggleKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			toggleKey = input.KeyCode
			keyBtn.Text = toggleKey.Name
			waitingToggleKey = false
			return
		end
	end

	-- รับปุ่มใหม่สำหรับ Free Mouse
	if waitingFreeKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			FREE_MOUSE_KEY = input.KeyCode
			freeKeyBtn.Text = FREE_MOUSE_KEY.Name
			waitingFreeKey = false
			return
		end
	end

	if gameProcessed then return end

	if input.KeyCode == toggleKey then
		gui.Enabled = not gui.Enabled
	elseif input.KeyCode == FREE_MOUSE_KEY then
		setFreeMouse(not freeMouseOn)
	end
end))

---------------------------------------------------------------- drag window
local dragging = false
local dragStart, startPos

track(main.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		track(input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end))
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end))