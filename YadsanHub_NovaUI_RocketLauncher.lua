-- ============================================================
--  YADSAN HUB | Life Together RP  -  NovaUI edition
--  The original Yadsan Hub menu (same options, same callbacks) now
--  runs on NovaUI. The old "Toggle Flames" button is gone.
--  RightShift hides / shows the menu.
-- ============================================================

local SharedNovaUI = (function()
--[[
    Celestial Godverse uv1.0
    Yadsan UI library for Roblox (Luau) - mobile + PC, executor friendly.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HapticService = game:GetService("HapticService")
local LocalPlayer = Players.LocalPlayer

local NovaUI = { Version = "1.0.0", Flags = {} }

-- ========== VIBRATION HELPER (throttled, can be switched off in Settings) ==========
NovaUI.Haptics = true
local lastVib = 0
local function vibrate()
	local now = os.clock()
	if now - lastVib < 0.12 then
		return
	end
	lastVib = now
	if NovaUI.Sound then
		NovaUI.Sound("click", 0.22)
	end
	if not NovaUI.Haptics or not UserInputService.TouchEnabled then
		return
	end
	pcall(function()
		for _, it in ipairs({ Enum.UserInputType.Touch, Enum.UserInputType.Gamepad1 }) do
			if HapticService:IsMotorSupported(it, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(it, Enum.VibrationMotor.Small, 1)
				task.delay(0.08, function()
					pcall(HapticService.SetMotor, HapticService, it, Enum.VibrationMotor.Small, 0)
				end)
				return
			end
		end
	end)
end

------------------------------------------------------------------------
-- Themes
------------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local THEMES = {
	Midnight = { Accent = rgb(92, 124, 255), Panel = rgb(26, 30, 48), Card = rgb(11, 13, 24), Raised = rgb(42, 47, 76), Sub = rgb(150, 158, 192) },
	Crimson = { Accent = rgb(255, 64, 84), Panel = rgb(36, 22, 28), Card = rgb(18, 9, 13), Raised = rgb(58, 34, 43), Sub = rgb(196, 150, 158) },
	Ocean = { Accent = rgb(28, 200, 235), Panel = rgb(18, 32, 46), Card = rgb(7, 16, 26), Raised = rgb(30, 55, 74), Sub = rgb(140, 178, 196) },
	Violet = { Accent = rgb(170, 90, 255), Panel = rgb(31, 22, 48), Card = rgb(14, 8, 27), Raised = rgb(52, 37, 80), Sub = rgb(170, 148, 198) },
	Emerald = { Accent = rgb(36, 214, 130), Panel = rgb(18, 35, 31), Card = rgb(7, 18, 15), Raised = rgb(30, 58, 49), Sub = rgb(140, 190, 172) },
	Mono = { Accent = rgb(236, 236, 242), Panel = rgb(31, 31, 36), Card = rgb(10, 10, 12), Raised = rgb(52, 52, 58), Sub = rgb(162, 162, 170), OnAccent = rgb(14, 14, 18) },
	Sun = { Accent = rgb(255, 175, 36), Panel = rgb(22, 11, 4), Card = rgb(12, 5, 2), Raised = rgb(48, 24, 10), Sub = rgb(215, 172, 120), Text = rgb(255, 244, 220), Stroke = rgb(255, 150, 45), OnAccent = rgb(28, 12, 0) },
}
local THEME_ORDER = { "Sun", "Midnight", "Crimson", "Ocean", "Violet", "Emerald", "Mono" }

for _, t in pairs(THEMES) do
	t.Text = t.Text or rgb(244, 246, 255)
	t.Stroke = t.Stroke or rgb(255, 255, 255)
	t.OnAccent = t.OnAccent or rgb(255, 255, 255)
	t.AccentHover = t.Accent:Lerp(rgb(255, 255, 255), 0.18)
end

local State = { Theme = "Sun", PanelAlpha = 0.16 }
local Theme = THEMES.Sun

NovaUI.Themes = THEMES

NovaUI.Icons = {
	home = "🏠", user = "👤", users = "👥", settings = "⚙️", grid = "▦", chat = "✉",
	bolt = "⚡", eye = "👁️", shield = "🛡️", star = "⭐", wifi = "🛜", clock = "🕘",
	check = "✔️", chevron = "▶️", search = "🔍", plus = "➕", minus = "➖", close = "❌",
	palette = "🌌", cube = "🧊", server = "🌍", game = "🎮", refresh = "🔃", sun = "☀️",
	feature = "🔮", dot = "⚫",
}

------------------------------------------------------------------------
-- Core helpers
------------------------------------------------------------------------
local Binds, Conns = {}, {}
local GuiRoot = nil

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Conns, c)
	return c
end

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function apply(inst, props, instant)
	if instant then
		for k, v in pairs(props) do
			inst[k] = v
		end
	else
		tween(inst, 0.25, props)
	end
end

local function bind(inst, fn)
	table.insert(Binds, { inst = inst, fn = fn })
	fn(true)
end

local function refresh(instant)
	for i = #Binds, 1, -1 do
		local b = Binds[i]
		if GuiRoot and b.inst:IsDescendantOf(GuiRoot) then
			b.fn(instant)
		else
			table.remove(Binds, i)
		end
	end
end

local function paint(inst, prop, key)
	bind(inst, function(instant)
		apply(inst, { [prop] = Theme[key] }, instant)
	end)
end

local function panelPaint(inst)
	bind(inst, function(instant)
		apply(inst, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = State.PanelAlpha }, instant)
	end)
end

local BOXES = { Frame = true, TextButton = true, TextLabel = true, TextBox = true, ScrollingFrame = true, ImageLabel = true, ImageButton = true }

local function new(class, props, parent)
	local o = Instance.new(class)
	if BOXES[class] then
		o.BorderSizePixel = 0
	end
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function pad(p, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
	}, p)
end

local function list(p, gap, dir, ha, va)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
		VerticalAlignment = va or Enum.VerticalAlignment.Top,
	}, p)
end

local function stroke(p, alpha, key)
	local s = new("UIStroke", { Thickness = 1, Transparency = alpha or 0.88, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	paint(s, "Color", key or "Stroke")
	return s
end

local BOLD = Enum.Font.GothamBold
local MED = Enum.Font.GothamMedium
local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local AX, AY = Enum.AutomaticSize.X, Enum.AutomaticSize.Y

local function label(parent, props, colorKey)
	local p = {
		BackgroundTransparency = 1, Font = MED, TextSize = 14,
		TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center, Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	local l = new("TextLabel", p, parent)
	if colorKey ~= false then
		paint(l, "TextColor3", colorKey or "Text")
	end
	return l
end

------------------------------------------------------------------------
-- Image assets (icons + blackhole parts). Written to the executor workspace once,
-- then loaded with getcustomasset. Falls back to glyphs / plain shapes if unsupported.
------------------------------------------------------------------------
local ICON_ALIAS = { feature = "sliders", dot = "record", exploits = "flame", commands = "terminal" }
local ASSET_VER = "v5"
local assetCache = {}
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64map

local function b64decode(s)
	for _, f in ipairs({
		function() return crypt and crypt.base64decode end,
		function() return crypt and crypt.base64 and crypt.base64.decode end,
		function() return base64_decode end,
		function() return base64 and base64.decode end,
		function() return syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.decode end,
	}) do
		local okf, fn = pcall(f)
		if okf and type(fn) == "function" then
			local ok, r = pcall(fn, s)
			if ok and type(r) == "string" and #r > 16 then
				return r
			end
		end
	end
	if not b64map then
		b64map = {}
		for i = 1, 64 do
			b64map[B64:byte(i)] = i - 1
		end
	end
	local out, n = {}, 0
	local buf, bits = 0, 0
	for i = 1, #s do
		local v = b64map[s:byte(i)]
		if v then
			buf = buf * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local div = 2 ^ bits
				local byte = math.floor(buf / div)
				buf = buf - byte * div
				n = n + 1
				out[n] = string.char(byte)
			end
		end
	end
	return table.concat(out)
end

function NovaUI.Asset(name)
	local c = assetCache[name]
	if c ~= nil then
		return c or nil
	end
	local url = false
	local data = YADSAN_ASSETS and YADSAN_ASSETS[name]
	if data and writefile and getcustomasset then
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			pcall(makefolder, "YADSAN_HUB/assets")
			local path = "YADSAN_HUB/assets/" .. name .. "_" .. ASSET_VER .. ".png"
			if not (isfile and isfile(path)) then
				local bin = b64decode(data)
				if not bin or #bin < 16 then
					return
				end
				writefile(path, bin)
			end
			local u = getcustomasset(path)
			if type(u) == "string" and u ~= "" then
				url = u
			end
		end)
	end
	assetCache[name] = url
	return url or nil
end

local function icon(parent, name, size, colorKey, props)
	local key = ICON_ALIAS[name] or name
	local asset = (type(name) == "string" and (name:find("rbxasset") or name:find("http"))) and name or NovaUI.Asset(key)
	local o
	if asset then
		o = new("ImageLabel", { BackgroundTransparency = 1, Image = asset, Size = UDim2.fromOffset(size + 3, size + 3) }, parent)
		if colorKey then
			paint(o, "ImageColor3", colorKey)
		end
	else
		local v = NovaUI.Icons[name] or NovaUI.Icons[key] or "●"
		o = label(parent, {
			Text = tostring(v), TextSize = size, Font = BOLD, TextXAlignment = CENTER,
			Size = UDim2.fromOffset(size + 4, size + 4),
		}, colorKey)
	end
	for k, val in pairs(props or {}) do
		o[k] = val
	end
	return o
end

NovaUI.Sounds = true
local sndCache = {}
function NovaUI.Sound(name, vol, life, force)
	if not NovaUI.Sounds and not force then
		return
	end
	local url = sndCache[name]
	if url == nil then
		url = false
		local data = YADSAN_SOUNDS and YADSAN_SOUNDS[name]
		if data and writefile and getcustomasset then
			pcall(function()
				pcall(makefolder, "YADSAN_HUB")
				pcall(makefolder, "YADSAN_HUB/assets")
				local path = "YADSAN_HUB/assets/snd_" .. name .. "_" .. ASSET_VER .. ".wav"
				if not (isfile and isfile(path)) then
					local bin = b64decode(data)
					if not bin then
						return
					end
					writefile(path, bin)
				end
				local u = getcustomasset(path)
				if type(u) == "string" and u ~= "" then
					url = u
				end
			end)
		end
		sndCache[name] = url
	end
	if not url then
		return
	end
	local snd
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = url
		s.Volume = vol or 0.5
		s.Parent = game:GetService("SoundService")
		s:Play()
		snd = s
		task.delay(life or 4, function()
			s:Destroy()
		end)
	end)
	return snd
end

function NovaUI.MakeBlackhole(parent, size, cfg)
	cfg = cfg or {}
	local half = Vector2.new(0.5, 0.5)
	local holder = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = cfg.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = cfg.ZIndex or 1,
	}, parent)
	local outerGlow = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 140, 20), BackgroundTransparency = 0.78,
		AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 1.48, size * 1.48), ZIndex = 1,
	}, holder)
	corner(outerGlow, size)
	local midGlow = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 195, 45), BackgroundTransparency = 0.58,
		AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 1.15, size * 1.15), ZIndex = 2,
	}, holder)
	corner(midGlow, size)
	local disk = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 1.45, size * 0.68), Rotation = -16, ZIndex = 3,
	}, holder)
	local front = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 4,
	}, disk)
	corner(front, size)
	local st = new("UIStroke", { Thickness = 3.5, Color = Color3.fromRGB(255, 190, 50), Transparency = 0.1 }, front)
	local stGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 150)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 25)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 75, 15)),
		}),
	}, st)
	local core = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 220, 80), AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.74, size * 0.74), ZIndex = 3,
	}, holder)
	corner(core, size)
	local sunGrad = new("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 210)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 185, 35)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 95, 15)),
		}),
	}, core)
	local ring = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.86, size * 0.86), ZIndex = 4,
	}, holder)
	corner(ring, size)
	local ringStroke = new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 240, 145), Transparency = 0.12 }, ring)
	local ringGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 200)),
		}),
	}, ringStroke)
	local bits = {}
	if cfg.Particles ~= false then
		local rnd = Random.new()
		for i = 1, cfg.ParticleCount or 14 do
			local d = Instance.new("Frame")
			local sz = rnd:NextInteger(2, 5)
			d.Size = UDim2.fromOffset(sz, sz)
			d.AnchorPoint = half
			d.BorderSizePixel = 0
			d.BackgroundColor3 = (i % 3 == 0) and Color3.fromRGB(255, 245, 140) or ((i % 3 == 1) and Color3.fromRGB(255, 165, 35) or Color3.fromRGB(255, 95, 25))
			d.BackgroundTransparency = 0.1
			d.ZIndex = 2
			d.Parent = disk
			Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
			bits[i] = { f = d, a = rnd:NextNumber() * math.pi * 2, r = 0.55 + rnd:NextNumber() * 0.5, front = false }
		end
	end
	local wTarget, wb = cfg.White and 1 or 0, cfg.White and 1 or 0
	local boost = 0
	local t0 = math.random() * 10
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() + t0
		wb = wb + (wTarget - wb) * math.min(1, dt * 4.5)
		boost = boost * math.max(0, 1 - dt * 2.2)
		core.BackgroundColor3 = Color3.fromRGB(255, 185, 40):Lerp(Color3.fromRGB(255, 242, 140), wb)
		sunGrad.Rotation = (t * 35) % 360
		ring.Rotation = (ring.Rotation + dt * (36 + boost * 220)) % 360
		ringGrad.Rotation = (t * 90) % 360
		stGrad.Rotation = (-t * 75) % 360
		disk.Rotation = -16 + math.sin(t * 0.8) * 4
		local pulse = 1 + 0.05 * math.sin(t * 2.4) + boost * 0.08
		outerGlow.Size = UDim2.fromOffset(size * 1.48 * pulse, size * 1.48 * pulse)
		outerGlow.BackgroundTransparency = 0.76 + 0.08 * math.sin(t * 1.8)
		midGlow.BackgroundTransparency = 0.54 + 0.08 * math.sin(t * 2.2)
		for _, p in ipairs(bits) do
			p.a = p.a + dt * (1.2 + boost * 3) / (p.r ^ 1.5)
			if wb > 0.5 then
				p.r = p.r + dt * 0.22
				if p.r > 1.45 then p.r = 0.45 end
			else
				p.r = p.r - dt * 0.1
				if p.r < 0.45 then p.r = 1.35 end
			end
			local sn = math.sin(p.a)
			p.f.Position = UDim2.fromScale(0.5 + math.cos(p.a) * 0.46 * p.r, 0.5 + sn * 0.205 * p.r)
			local fr = sn > 0
			if fr ~= p.front then
				p.front = fr
				p.f.ZIndex = fr and 5 or 1
			end
		end
	end)
	local api = { Glow = outerGlow, Disk = disk, Core = core, Ring = ring }
	function api.SetWhite(on, instant)
		wTarget = on and 1 or 0
		if instant then
			wb = wTarget
		end
	end
	function api.Boost(v)
		boost = v or 1
	end
	function api.IsWhite()
		return wTarget == 1
	end
	return holder, api
end

local function fire(cb, ...)
	vibrate()
	if type(cb) ~= "function" then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(cb, table.unpack(args, 1, args.n))
		if not ok then
			warn("[NovaUI] callback error: " .. tostring(err))
		end
	end)
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType.Touch
end

local function btnStyle(btn, base, hov)
	paint(btn, "BackgroundColor3", base)
	btn.MouseEnter:Connect(function()
		tween(btn, 0.15, { BackgroundColor3 = Theme[hov] })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.15, { BackgroundColor3 = Theme[base] })
	end)
end

local function draggable(area, scroller, update)
	local dragging = false
	area.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			if scroller then
				scroller.ScrollingEnabled = false
			end
			update(i.Position)
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and isMove(i) then
			update(i.Position)
		end
	end)
	connect(UserInputService.InputEnded, function(i)
		if dragging and isPress(i) then
			dragging = false
			if scroller then
				scroller.ScrollingEnabled = true
			end
		end
	end)
end

local ThumbCache = {}
local function loadThumb(userId, img)
	if ThumbCache[userId] then
		img.Image = ThumbCache[userId]
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and url then
			ThumbCache[userId] = url
			if img.Parent then
				img.Image = url
			end
		end
	end)
end

local function getHumanoid()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getPing()
	local ok, v = pcall(function()
		return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and math.floor(v) or 0
end

local function formatTime(sec)
	sec = math.floor(sec)
	local h, m, s = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm %02ds", m, s)
end

local function encode(v)
	local t = typeof(v)
	if t == "Color3" then
		return { __t = "Color3", r = v.R, g = v.G, b = v.B }
	elseif t == "EnumItem" then
		return { __t = "Enum", name = v.Name }
	end
	return v
end

local function decode(v)
	if type(v) == "table" and v.__t == "Color3" then
		return Color3.new(v.r, v.g, v.b)
	elseif type(v) == "table" and v.__t == "Enum" then
		return v.name
	end
	return v
end

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

function Section:_next()
	self._order = self._order + 1
	return self._order
end

function Section:_row(h, clickable)
	local r = new(clickable and "TextButton" or "Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = self:_next(),
	}, self.Body)
	if clickable then
		r.Text = ""
		r.AutoButtonColor = false
	end
	return r
end

function Section:_flag(flag, obj, value)
	if not flag then
		return
	end
	NovaUI.Flags[flag] = value
	self.Window._setters[flag] = function(v)
		obj:Set(v)
	end
end

function Section:Label(text)
	local l = label(self.Body, {
		Text = text or "", TextSize = 13, TextWrapped = true, AutomaticSize = AY,
		Size = UDim2.new(1, 0, 0, 0), LayoutOrder = self:_next(),
	}, "Sub")
	return { Set = function(_, t) l.Text = t end }
end

function Section:Paragraph(cfg)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	list(f, 2)
	label(f, { Text = cfg.Title or "", Font = BOLD, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
	label(f, { Text = cfg.Content or "", TextSize = 13, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, "Sub")
end

function Section:Divider()
	local d = new("Frame", { Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self:_next(), BackgroundTransparency = 0.9 }, self.Body)
	paint(d, "BackgroundColor3", "Stroke")
end

function Section:Toggle(cfg)
	local state = cfg.Default == true
	local desc = cfg.Description
	local r = self:_row(desc and 50 or 40, true)
	local x = 0
	if cfg.Icon then
		icon(r, cfg.Icon, 20, "Sub", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
		x = 38
	end
	label(r, {
		Text = cfg.Title or "Toggle", Font = BOLD, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, desc and -9 or 0),
		Size = UDim2.new(1, -x - 64, 0, 20),
	})
	if desc then
		label(r, {
			Text = desc, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 11),
			Size = UDim2.new(1, -x - 64, 0, 16),
		}, "Sub")
	end
	local sw = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(52, 30) }, r)
	corner(sw, 15)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = rgb(255, 255, 255),
	}, sw)
	corner(knob, 12)

	local function render(instant)
		apply(sw, { BackgroundColor3 = state and Theme.Accent or Theme.Raised }, instant)
		local pos = UDim2.new(0, state and 25 or 3, 0.5, 0)
		if instant then
			knob.Position = pos
		else
			tween(knob, 0.2, { Position = pos }, Enum.EasingStyle.Quad)
		end
	end
	bind(sw, render)

	local obj = {}
	function obj:Set(v, silent)
		state = v == true
		render(false)
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = state
		end
		if not silent then
			fire(cfg.Callback, state)
		end
	end
	function obj:Get()
		return state
	end
	r.MouseButton1Click:Connect(function()
		obj:Set(not state)
	end)
	self:_flag(cfg.Flag, obj, state)
	if state then
		task.defer(fire, cfg.Callback, state)
	end
	return obj
end

function Section:Button(cfg)
	local primary = cfg.Style == "Primary"
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 44), LayoutOrder = self:_next(), Text = cfg.Title or "Button",
		Font = BOLD, TextSize = 15, AutoButtonColor = false,
	}, self.Body)
	corner(b, 12)
	btnStyle(b, primary and "Accent" or "Card", primary and "AccentHover" or "Raised")
	paint(b, "TextColor3", primary and "OnAccent" or "Text")
	b.MouseButton1Click:Connect(function()
		fire(cfg.Callback)
	end)
	return { SetText = function(_, t) b.Text = t end }
end

function Section:Input(cfg)
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 44), LayoutOrder = self:_next(), Text = cfg.Default or "",
		PlaceholderText = cfg.Placeholder or cfg.Title or "Type here", ClearTextOnFocus = false,
		Font = BOLD, TextSize = 14, TextXAlignment = CENTER,
	}, self.Body)
	corner(box, 12)
	paint(box, "BackgroundColor3", "Card")
	paint(box, "TextColor3", "Text")
	paint(box, "PlaceholderColor3", "Sub")
	stroke(box, 0.93)
	local obj = {}
	function obj:Set(v, silent)
		box.Text = tostring(v)
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = box.Text
		end
		if not silent then
			fire(cfg.Callback, box.Text)
		end
	end
	function obj:Get()
		return box.Text
	end
	box.FocusLost:Connect(function(enter)
		if enter or cfg.OnBlur ~= false then
			obj:Set(box.Text)
		end
	end)
	self:_flag(cfg.Flag, obj, box.Text)
	return obj
end

function Tab:Section(cfg)
	cfg = cfg or {}
	local side = (cfg.Side == "Right") and self.Right or self.Left
	self._n = self._n + 1
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self._n }, side)
	corner(card, 18)
	panelPaint(card)
	stroke(card, 0.9)
	pad(card, 14, 12, 14, 14)
	list(card, 8)
	local s = setmetatable({ Window = self.Window, Tab = self, Body = card, Scroller = side, _order = 0 }, Section)
	if cfg.Title then
		local head = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0 }, card)
		local x = 0
		if cfg.Icon then
			icon(head, cfg.Icon, 17, "Sub", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
			x = 28
		end
		label(head, { Text = cfg.Title, Font = BOLD, TextSize = 16, Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(1, -x, 1, 0) })
	end
	return s
end

function Window:SetTheme(name)
	if not THEMES[name] then
		return
	end
	State.Theme = name
	Theme = THEMES[name]
	NovaUI.Flags.Theme = name
	refresh(false)
end

function Window:SetVisible(v, instant)
	local main, sc = self._main, self._mainScale
	self.Visible = v
	self._animSeq = (self._animSeq or 0) + 1
	local seq = self._animSeq
	if self._onVis then
		pcall(self._onVis, v, instant)
	end
	if instant or not NovaUI.Animations or not self._orb or not sc then
		main.AnchorPoint, main.Position = Vector2.new(0, 0), UDim2.new()
		if sc then
			sc.Scale = 1
		end
		main.Visible = v
		return
	end
	local orb, root = self._orb, self._root
	if root.AbsoluteSize.X > 0 then
		local c = orb.AbsolutePosition + orb.AbsoluteSize / 2
		local fx = (c.X - root.AbsolutePosition.X) / root.AbsoluteSize.X
		local fy = (c.Y - root.AbsolutePosition.Y) / root.AbsoluteSize.Y
		main.AnchorPoint = Vector2.new(fx, fy)
		main.Position = UDim2.fromScale(fx, fy)
	end
	if v then
		sc.Scale = 0.01
		main.Visible = true
		tween(sc, 0.75, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.delay(0.8, function()
			if self._animSeq == seq then
				main.AnchorPoint, main.Position = Vector2.new(0, 0), UDim2.new()
			end
		end)
	else
		tween(sc, 0.6, { Scale = 0.01 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.62, function()
			if self._animSeq == seq then
				main.Visible = false
			end
		end)
	end
end

function Window:Toggle()
	if NovaUI.HoldOpen then
		return
	end
	self:SetVisible(not self.Visible)
end

function Window:Reveal()
	NovaUI.HoldOpen = false
	if self._orb then
		self._orb.Visible = true
	end
	self:SetVisible(true)
end

function Window:Notify(cfg)
	cfg = cfg or {}
	local dur = cfg.Duration or 4
	self._toastId = self._toastId + 1
	local wrap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self._toastId }, self._toasts)
	local toast = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, Position = UDim2.new(1, 60, 0, 0) }, wrap)
	corner(toast, 16)
	panelPaint(toast)
	toast.BackgroundTransparency = 0.05
	stroke(toast, 0.85)
	pad(toast, 16, 12, 14, 12)
	list(toast, 3)
	label(toast, { Text = cfg.Title or "Notification", Font = BOLD, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
	if cfg.Content then
		label(toast, { Text = cfg.Content, TextSize = 13, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, "Sub")
	end
	tween(toast, 0.35, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
	task.delay(dur, function()
		if toast.Parent then
			tween(toast, 0.3, { Position = UDim2.new(1, 60, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.wait(0.35)
			wrap:Destroy()
		end
	end)
end

function Window:CreateTab(cfg)
	cfg = cfg or {}
	local tab = setmetatable({ Window = self, Name = cfg.Name or "Tab", _n = 0, _active = false }, Tab)
	local btn = new("TextButton", { Size = UDim2.new(0, 0, 0, 44), AutomaticSize = AX, Text = "", AutoButtonColor = false, LayoutOrder = #self.Tabs + 1 }, self._dock)
	corner(btn, 22)
	list(btn, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pad(btn, 13, 0, 13, 0)
	local ic = icon(btn, cfg.Icon or "star", 18, false)
	ic.LayoutOrder = 1
	local nm = label(btn, { Text = tab.Name, Font = BOLD, TextSize = 15, AutomaticSize = AX, Size = UDim2.new(0, 0, 1, 0), Visible = false, LayoutOrder = 2 }, "Text")
	local prop = ic:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
	local function render(instant)
		local on = tab._active
		apply(btn, { BackgroundColor3 = on and Theme.Accent or Theme.Raised, BackgroundTransparency = on and 0.3 or 0.55 }, instant)
		apply(ic, { [prop] = on and Theme.Text or Theme.Sub }, instant)
		nm.Visible = on
	end
	bind(btn, render)
	tab._render = render

	tab.Page = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, self._main)
	local function column(anchorX, posX)
		local s = new("ScrollingFrame", {
			BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY,
			ClipsDescendants = true, AnchorPoint = Vector2.new(anchorX, 0),
			Position = UDim2.new(anchorX, posX, 0, 150), Size = UDim2.new(0.27, 0, 1, -244),
		}, tab.Page)
		new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(440, 99999) }, s)
		list(s, 12)
		pad(s, 0, 0, 0, 10)
		return s
	end
	tab.Left = column(0, 16)
	tab.Right = column(1, -16)
	btn.MouseButton1Click:Connect(function()
		vibrate()
		self:_select(tab)
	end)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:_select(tab, true)
	end
	return tab
end

function Window:_select(tab, instant)
	for _, t in ipairs(self.Tabs) do
		local on = t == tab
		t._active = on
		t.Page.Visible = on
		t._render(instant == true)
	end
end

function Window:Destroy()
	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end
	Conns = {}
	Binds = {}
	if self.Gui then
		self.Gui:Destroy()
	end
	GuiRoot = nil
end

function NovaUI:CreateWindow(cfg)
	cfg = cfg or {}
	Binds = {}
	if cfg.Theme and THEMES[cfg.Theme] then
		State.Theme = cfg.Theme
		Theme = THEMES[cfg.Theme]
	end
	NovaUI.Flags = { Theme = State.Theme }

	local win = setmetatable({
		Tabs = {}, Name = cfg.Name or "NOVA", Folder = cfg.Folder or "NovaUI",
		ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift, Visible = true,
		_setters = {}, _tickers = {}, _themeListeners = {}, _log = {}, _unread = 0, _toastId = 0,
	}, Window)

	local gui = new("ScreenGui", { Name = "NovaUI_" .. HttpService:GenerateGUID(false):sub(1, 6), ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
	local parent = LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = parent
	GuiRoot = gui
	win.Gui = gui

	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local main = new("Frame", { Name = "Main", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	win._main = main
	win._root = root
	win._mainScale = new("UIScale", {}, main)

	local dock = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(0, 60), AutomaticSize = AX }, main)
	corner(dock, 30)
	panelPaint(dock)
	stroke(dock, 0.88)
	list(dock, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pad(dock, 8, 0, 8, 0)
	win._dock = dock

	local toasts = new("Frame", { Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 80), Size = UDim2.fromOffset(300, 0), AutomaticSize = AY, ZIndex = 50 }, root)
	list(toasts, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right)
	win._toasts = toasts

	local orb = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 222), Size = UDim2.fromOffset(150, 150),
		Text = "", AutoButtonColor = false, ZIndex = 60, BackgroundTransparency = 1,
	}, root)
	local _, bhApi = NovaUI.MakeBlackhole(orb, 118, { Bind = true, ZIndex = 1, White = true })
	win._orb, win._bh = orb, bhApi
	orb.MouseButton1Click:Connect(function()
		win:Toggle()
	end)

	connect(UserInputService.InputBegan, function(i, gp)
		if not gp and win.ToggleKey and i.KeyCode == win.ToggleKey then
			win:Toggle()
		end
	end)

	return win
end

return NovaUI
end)()

local function RunFlamesHub()
	local g = getgenv and getgenv() or _G
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local LocalPlayer = Players.LocalPlayer

	g.RocketLauncher_Target = g.RocketLauncher_Target or nil
	g.RocketLauncher_Enabled = g.RocketLauncher_Enabled or false
	g.RocketLauncher_Conn = g.RocketLauncher_Conn or nil

	g.findplr = g.findplr or function(query)
		if not query or tostring(query) == "" then return nil end
		local q = tostring(query):lower()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Name:lower():find(q, 1, true) or plr.DisplayName:lower():find(q, 1, true) then
				return plr
			end
		end
		return nil
	end

	local function getRocketTool()
		local char = LocalPlayer and LocalPlayer.Character
		local backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack")
		for _, container in ipairs({ char, backpack }) do
			if container then
				for _, item in ipairs(container:GetChildren()) do
					if item:IsA("Tool") and (item.Name:lower():find("rocket") or item.Name:lower():find("launcher") or item.Name:lower():find("rpg")) then
						return item
					end
				end
			end
		end
		return nil
	end

	local function fireAtTarget(targetPlr)
		local myChar = LocalPlayer and LocalPlayer.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local tChar = targetPlr and targetPlr.Character
		local tRoot = tChar and (tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Head"))
		if not (myRoot and tRoot) then return end

		local aimPos = tRoot.Position
		myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(aimPos.X, myRoot.Position.Y, aimPos.Z))

		local tool = getRocketTool()
		if tool then
			local hum = myChar:FindFirstChildOfClass("Humanoid")
			if hum and tool.Parent ~= myChar then
				pcall(function() hum:EquipTool(tool) end)
			end
			pcall(function()
				if tool.Activate then
					tool:Activate()
				end
			end)
		end

		if g.Send and typeof(g.Send) == "function" then
			pcall(function()
				g.Send("fire_rocket", aimPos, tRoot)
			end)
		end
	end

	g.set_rocket_launcher_target = g.set_rocket_launcher_target or function(query)
		local target = g.findplr(query)
		if not target then
			if g.notify then g.notify("Error", "Target not found.", 5) end
			g.RocketLauncher_Target = nil
			return nil
		end
		g.RocketLauncher_Target = target
		if g.notify then g.notify("Success", "Rocket Launcher target set to: " .. target.DisplayName .. " (@" .. target.Name .. ")", 4) end
		return target
	end

	g.toggle_rocket_launcher = g.toggle_rocket_launcher or function(state, query)
		if query and tostring(query) ~= "" then
			g.set_rocket_launcher_target(query)
		end

		if state == false then
			g.RocketLauncher_Enabled = false
			if g.RocketLauncher_Conn then
				g.RocketLauncher_Conn:Disconnect()
				g.RocketLauncher_Conn = nil
			end
			if g.notify then g.notify("Info", "Rocket Launcher auto-target disabled.", 3) end
			return
		end

		if not g.RocketLauncher_Target or not g.RocketLauncher_Target.Parent then
			if g.notify then g.notify("Error", "Target not found.", 5) end
			g.RocketLauncher_Enabled = false
			return
		end

		g.RocketLauncher_Enabled = true
		if g.RocketLauncher_Conn then
			g.RocketLauncher_Conn:Disconnect()
			g.RocketLauncher_Conn = nil
		end

		local lastShot = 0
		g.RocketLauncher_Conn = RunService.Heartbeat:Connect(function()
			if not g.RocketLauncher_Enabled then return end
			local target = g.RocketLauncher_Target
			if not target or not target.Parent or target == LocalPlayer then
				g.toggle_rocket_launcher(false)
				return
			end
			if os.clock() - lastShot >= 0.35 then
				lastShot = os.clock()
				pcall(fireAtTarget, target)
			end
		end)
	end

	local win = SharedNovaUI:CreateWindow({ Name = "Yadsan Hub", Theme = "Sun", Folder = "YADSAN_HUB" })
	local playersTab = win:CreateTab({ Name = "Players", Icon = "users" })
	local Players_Section = playersTab:Section({
		Title = "Rocket Launcher",
		Icon = "bolt",
		Side = "Right",
	})

	local rocketTargetQuery = ""

	Players_Section:Input({
		Placeholder = "user or display...",
		Flag = "Rocket_Launcher_Target_Input",
		Callback = function(text)
			rocketTargetQuery = text
			if text and text ~= "" then
				g.set_rocket_launcher_target(text)
			end
		end,
	})

	Players_Section:Toggle({
		Title = "Rocket Launcher",
		Description = "Target: user or display...",
		Default = false,
		Flag = "Rocket_Launcher_Input_UI",
		Callback = function(state)
			local target = g.findplr(rocketTargetQuery)
			if state and not target then
				if g.notify then g.notify("Error", "Target not found.", 5) end
				return
			end
			g.toggle_rocket_launcher(state, rocketTargetQuery)
		end,
	})
end

RunFlamesHub()
