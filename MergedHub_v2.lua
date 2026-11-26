-- ============================================================
--  MERGED HUB v2: Flames Hub Gold (Yadsan) + White Life Hub
--  * NovaUI is loaded once and shared.
--  * White Life Hub keeps its NovaUI interface.
--  * Flames Hub now gets a NovaUI window ("Flames Hub") that opens
--    its tools. Its original GUIs still work as before.
--  * Picker on launch. Set AUTO_RUN to "flames" or "white" to skip.
-- ============================================================
local AUTO_RUN = nil -- nil = show picker | "flames" | "white"

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

-- Animated Blazing Sun (solar core + corona halos + rotating solar flare rings + orbiting embers).
function NovaUI.MakeBlackhole(parent, size, cfg)
	cfg = cfg or {}
	local half = Vector2.new(0.5, 0.5)
	local holder = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = cfg.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = cfg.ZIndex or 1,
	}, parent)
	-- Outer multi-layer solar corona glow
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
	-- Tilted solar flare orbit ring
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
	-- Blazing circular Sun sphere (kept upright inside holder so it stays a true circle)
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
	-- Rotating solar corona ring around the Sun
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
	-- Orbiting solar embers
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
	local coreStroke = new("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(255, 250, 185), Transparency = 0.1 }, core)
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
	-- Trigger vibration on callback
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
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
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

------------------------------------------------------------------------
-- Config encode / decode
------------------------------------------------------------------------
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

------------------------------------------------------------------------
-- Classes
------------------------------------------------------------------------
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

------------------------------------------------------------------------
-- Section elements
------------------------------------------------------------------------
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

function Section:Actions(items, cols)
	cols = cols or 2
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / cols, -(8 * (cols - 1)) / cols, 0, 58),
		CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, c)
	local out = {}
	for idx, it in ipairs(items) do
		local state = it.Default == true
		local t = new("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = idx }, c)
		corner(t, 14)
		btnStyle(t, "Card", "Raised")
		stroke(t, 0.93)
		local x = 12
		if it.Icon then
			icon(t, it.Icon, 15, "Text", { Position = UDim2.new(0, 11, 0, 9) })
			x = 33
		end
		label(t, { Text = it.Title or "Action", Font = BOLD, TextSize = 13, Position = UDim2.new(0, x, 0, 8), Size = UDim2.new(1, -x - 6, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local d = label(t, { Text = it.Description or (it.Toggle and "Off" or ""), TextSize = 11, Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -18, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, false)
		local function render(instant)
			apply(d, { TextColor3 = (it.Toggle and state) and Theme.Accent or Theme.Sub }, instant)
		end
		bind(d, render)
		local obj = {}
		function obj:Set(v, silent)
			state = v == true
			if it.Toggle then
				d.Text = state and "On" or "Off"
			end
			render(false)
			if it.Flag then
				NovaUI.Flags[it.Flag] = state
			end
			if not silent then
				fire(it.Callback, state)
			end
		end
		function obj:Get()
			return state
		end
		t.MouseButton1Click:Connect(function()
			if it.Toggle then
				obj:Set(not state)
			else
				fire(it.Callback)
			end
		end)
		if it.Toggle then
			self:_flag(it.Flag, obj, state)
			d.Text = state and "On" or "Off"
			render(true)
		end
		out[it.Title or idx] = obj
	end
	return out
end

function Section:Slider(cfg)
	local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
	local value = math.clamp(cfg.Default or min, min, max)
	local suffix = cfg.Suffix or ""
	local dec = tostring(inc):match("%.(%d+)")
	dec = dec and #dec or 0
	local fmt = "%." .. dec .. "f"
	local r = self:_row(56)
	label(r, { Text = cfg.Title or "Slider", Font = BOLD, TextSize = 15, Size = UDim2.new(1, -100, 0, 20) })
	local vl = label(r, { Font = BOLD, TextSize = 14, TextXAlignment = RIGHT, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 20) }, "Sub")
	local track = new("Frame", { Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 8) }, r)
	corner(track, 4)
	paint(track, "BackgroundColor3", "Raised")
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0) }, track)
	corner(fill, 4)
	paint(fill, "BackgroundColor3", "Accent")
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = rgb(255, 255, 255) }, track)
	corner(knob, 9)
	local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.new(0, -8, 0, 26), Size = UDim2.new(1, 16, 0, 28) }, r)

	local function render()
		local a = (value - min) / math.max(max - min, 1e-9)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		vl.Text = fmt:format(value) .. suffix
	end
	local obj = {}
	function obj:Set(v, silent)
		v = min + math.floor((v - min) / inc + 0.5) * inc
		v = tonumber(fmt:format(math.clamp(v, min, max)))
		if v == value and not silent then
			return
		end
		value = v
		render()
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = value
		end
		if not silent then
			fire(cfg.Callback, value)
		end
	end
	function obj:Get()
		return value
	end
	draggable(hit, self.Scroller, function(pos)
		local a = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + a * (max - min))
	end)
	render()
	self:_flag(cfg.Flag, obj, value)
	return obj
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
		if cfg.Numeric then
			local n = tonumber(box.Text)
			if not n then
				box.Text = ""
				return
			end
		end
		if enter or cfg.OnBlur ~= false then
			obj:Set(box.Text)
		end
	end)
	self:_flag(cfg.Flag, obj, box.Text)
	return obj
end

function Section:Dropdown(cfg)
	local multi = cfg.Multi == true
	local options = cfg.Options or {}
	local selected
	if multi then
		selected = {}
		for _, v in ipairs(cfg.Default or {}) do
			selected[v] = true
		end
	else
		selected = cfg.Default
	end
	local open = false
	local styles = {}

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	list(holder, 6)
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = 1 }, holder)
	corner(head, 12)
	btnStyle(head, "Card", "Raised")
	stroke(head, 0.93)
	label(head, { Text = cfg.Title or "Dropdown", Font = BOLD, TextSize = 14, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.45, -14, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	local vl = label(head, { TextSize = 13, TextXAlignment = RIGHT, Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -34, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, "Sub")
	local chev = label(head, { Text = "›", Font = BOLD, TextSize = 22, TextXAlignment = CENTER, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(20, 24), Rotation = 90 }, "Sub")
	local box = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), Visible = false, BackgroundTransparency = 1, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, LayoutOrder = 2, ClipsDescendants = true,
	}, holder)
	list(box, 4)

	local function display()
		if multi then
			local t = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(t, tostring(o))
				end
			end
			return #t > 0 and table.concat(t, ", ") or "None"
		end
		return selected ~= nil and tostring(selected) or "None"
	end
	local function value()
		if multi then
			local t = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(t, o)
				end
			end
			return t
		end
		return selected
	end
	local function restyle()
		for _, f in ipairs(styles) do
			f(false)
		end
		vl.Text = display()
	end
	local obj = {}
	local function commit(silent)
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = value()
		end
		restyle()
		if not silent then
			fire(cfg.Callback, value())
		end
	end
	local function build()
		styles = {}
		for _, c in ipairs(box:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		box.Size = UDim2.new(1, 0, 0, math.min(#options * 40, 180))
		for i, o in ipairs(options) do
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), Text = "", AutoButtonColor = false, LayoutOrder = i }, box)
			corner(b, 10)
			local t = label(b, { Text = tostring(o), TextSize = 14, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -44, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, false)
			local ck = label(b, { Text = "✓", Font = BOLD, TextSize = 15, TextXAlignment = RIGHT, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0, 20, 1, 0) }, false)
			local function style(instant)
				local on
				if multi then
					on = selected[o] == true
				else
					on = selected == o
				end
				apply(b, { BackgroundColor3 = on and Theme.Accent or Theme.Card, BackgroundTransparency = on and 0.65 or 0.3 }, instant)
				apply(t, { TextColor3 = on and Theme.Text or Theme.Sub }, instant)
				apply(ck, { TextColor3 = Theme.Text }, instant)
				ck.Visible = on
			end
			table.insert(styles, style)
			bind(b, style)
			b.MouseButton1Click:Connect(function()
				if multi then
					selected[o] = not selected[o] or nil
				else
					selected = o
					open = false
					box.Visible = false
					tween(chev, 0.2, { Rotation = 90 })
				end
				commit(false)
			end)
		end
	end
	function obj:Set(v, silent)
		if multi then
			selected = {}
			for _, k in ipairs(type(v) == "table" and v or {}) do
				selected[k] = true
			end
		else
			selected = v
		end
		commit(silent)
	end
	function obj:Get()
		return value()
	end
	function obj:Refresh(newOptions)
		options = newOptions or {}
		build()
		restyle()
	end
	head.MouseButton1Click:Connect(function()
		open = not open
		box.Visible = open
		tween(chev, 0.2, { Rotation = open and 270 or 90 })
	end)
	build()
	restyle()
	self:_flag(cfg.Flag, obj, value())
	return obj
end

function Section:Keybind(cfg)
	local key = cfg.Default
	local listening = false
	local r = self:_row(40)
	label(r, { Text = cfg.Title or "Keybind", Font = BOLD, TextSize = 15, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -100, 0, 20) })
	local kb = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(90, 30), Text = "", AutoButtonColor = false }, r)
	corner(kb, 9)
	btnStyle(kb, "Card", "Raised")
	stroke(kb, 0.9)
	local txt = label(kb, { Font = BOLD, TextSize = 13, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1) })
	local function render()
		txt.Text = listening and "..." or (key and key.Name or "None")
	end
	local obj = {}
	function obj:Set(v, silent)
		if type(v) == "string" then
			local ok, e = pcall(function()
				return Enum.KeyCode[v]
			end)
			v = ok and e or nil
		end
		key = v
		listening = false
		render()
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = key
		end
		if not silent then
			fire(cfg.OnChange, key)
		end
	end
	function obj:Get()
		return key
	end
	kb.MouseButton1Click:Connect(function()
		listening = true
		render()
	end)
	connect(UserInputService.InputBegan, function(i, gp)
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then
					obj:Set(nil)
				else
					obj:Set(i.KeyCode)
				end
			end
			return
		end
		if key and not gp and i.KeyCode == key then
			fire(cfg.Callback, key)
		end
	end)
	render()
	self:_flag(cfg.Flag, obj, key)
	return obj
end

function Section:ColorPicker(cfg)
	local h, s, v = (cfg.Default or Color3.new(1, 1, 1)):ToHSV()
	local open = false
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	list(holder, 8)
	local head = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1 }, holder)
	label(head, { Text = cfg.Title or "Color", Font = BOLD, TextSize = 15, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -60, 0, 20) })
	local swatch = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(44, 26) }, head)
	corner(swatch, 8)
	stroke(swatch, 0.7)

	local panel = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 132), Visible = false, LayoutOrder = 2 }, holder)
	local sv = new("Frame", { Size = UDim2.new(1, 0, 0, 100) }, panel)
	corner(sv, 10)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 255, 255) }, sv)
	corner(white, 10)
	new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, white)
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(0, 0, 0) }, sv)
	corner(black, 10)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, black)
	local cur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = rgb(255, 255, 255), ZIndex = 3 }, sv)
	corner(cur, 7)
	new("UIStroke", { Thickness = 2, Color = rgb(0, 0, 0), Transparency = 0.3 }, cur)

	local hue = new("Frame", { Position = UDim2.new(0, 0, 0, 112), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = rgb(255, 255, 255) }, panel)
	corner(hue, 8)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, rgb(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, rgb(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, rgb(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, rgb(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, rgb(255, 0, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
		}),
	}, hue)
	local hcur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 22), BackgroundColor3 = rgb(255, 255, 255), ZIndex = 3 }, hue)
	corner(hcur, 3)
	new("UIStroke", { Thickness = 1.5, Color = rgb(0, 0, 0), Transparency = 0.3 }, hcur)

	local obj = {}
	local function render()
		local c = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		swatch.BackgroundColor3 = c
		cur.Position = UDim2.fromScale(s, 1 - v)
		hcur.Position = UDim2.fromScale(h, 0.5)
		return c
	end
	local function changed(silent)
		local c = render()
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = c
		end
		if not silent then
			fire(cfg.Callback, c)
		end
	end
	function obj:Set(c, silent)
		if typeof(c) == "Color3" then
			h, s, v = c:ToHSV()
			changed(silent)
		end
	end
	function obj:Get()
		return Color3.fromHSV(h, s, v)
	end
	draggable(sv, self.Scroller, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		changed(false)
	end)
	draggable(hue, self.Scroller, function(pos)
		h = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
		changed(false)
	end)
	head.MouseButton1Click:Connect(function()
		open = not open
		panel.Visible = open
	end)
	render()
	self:_flag(cfg.Flag, obj, Color3.fromHSV(h, s, v))
	return obj
end

function Section:Stats(items)
	local r = self:_row(54)
	local n = #items
	for i, it in ipairs(items) do
		local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1 / n, 0, 1, 0), Position = UDim2.new((i - 1) / n, 0, 0, 0) }, r)
		local val = label(c, { Text = "-", Font = BOLD, TextSize = 20, Size = UDim2.new(1, 0, 0, 26) })
		label(c, { Text = string.upper(it.Label or ""), Font = BOLD, TextSize = 11, Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 16) }, "Sub")
		local function tick()
			val.Text = tostring(it.Get())
		end
		pcall(tick)
		table.insert(self.Window._tickers, tick)
	end
end

function Section:ServerInfo()
	self:Stats({
		{ Label = "Players", Get = function() return #Players:GetPlayers() .. "/" .. Players.MaxPlayers end },
		{ Label = "Ping", Get = function() return getPing() .. "ms" end },
		{ Label = "Uptime", Get = function() return formatTime(workspace.DistributedGameTime) end },
	})
end

function Section:GameCard()
	local win = self.Window
	local MarketplaceService = game:GetService("MarketplaceService")
	local r = self:_row(176)
	local card = new("Frame", { Size = UDim2.fromScale(1, 1) }, r)
	corner(card, 14)
	paint(card, "BackgroundColor3", "Card")
	stroke(card, 0.9)
	local img = new("ImageLabel", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(92, 92), ScaleType = Enum.ScaleType.Crop }, card)
	corner(img, 12)
	paint(img, "BackgroundColor3", "Raised")
	pcall(function()
		img.Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"
	end)
	local nameL = label(card, { Text = "Loading...", Font = BOLD, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(112, 10), Size = UDim2.new(1, -122, 0, 38) })
	local byL = label(card, { Text = "Place " .. tostring(game.PlaceId), TextSize = 12, Position = UDim2.fromOffset(112, 50), Size = UDim2.new(1, -122, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, "Sub")
	local plL = label(card, { Text = "", Font = BOLD, TextSize = 13, Position = UDim2.fromOffset(112, 70), Size = UDim2.new(1, -122, 0, 16) }, "Accent")
	local pgL = label(card, { Text = "", TextSize = 12, Position = UDim2.fromOffset(112, 88), Size = UDim2.new(1, -122, 0, 16) }, "Sub")
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		if ok and info and card.Parent then
			nameL.Text = info.Name or "Unknown game"
			if info.Creator and info.Creator.Name then
				byL.Text = "by " .. info.Creator.Name
			end
		elseif card.Parent then
			nameL.Text = "Unknown game"
		end
	end)
	table.insert(win._tickers, function()
		plL.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players online"
		pgL.Text = getPing() .. " ms   |   " .. formatTime(workspace.DistributedGameTime)
	end)
	local function mini(text, x, w, cb)
		local b = new("TextButton", { Position = UDim2.new(x, x == 0 and 10 or 4, 0, 114), Size = UDim2.new(w, -14, 0, 52), Text = text, Font = BOLD, TextSize = 14, AutoButtonColor = false }, card)
		corner(b, 12)
		btnStyle(b, "Raised", "Card")
		paint(b, "TextColor3", "Text")
		b.MouseButton1Click:Connect(function()
			fire(cb)
		end)
	end
	mini("Copy Job ID", 0, 0.5, function()
		if setclipboard then
			setclipboard(game.JobId)
		end
		win:Notify({ Title = "Copied", Content = "Job ID copied." })
	end)
	mini("Rejoin", 0.5, 0.5, function()
		pcall(function()
			if #Players:GetPlayers() <= 1 then
				LocalPlayer:Kick("\nRejoining...")
				task.wait()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			else
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end
		end)
	end)
end

function Section:PlayerList(cfg)
	cfg = cfg or {}
	local selected = nil
	local height = cfg.Height or 300
	local frame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height + 52), LayoutOrder = self:_next() }, self.Body)
	local search = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 44), Text = "", PlaceholderText = "Search players", ClearTextOnFocus = false,
		Font = MED, TextSize = 15, TextXAlignment = LEFT,
	}, frame)
	corner(search, 12)
	pad(search, 14, 0, 14, 0)
	paint(search, "BackgroundColor3", "Card")
	paint(search, "TextColor3", "Text")
	paint(search, "PlaceholderColor3", "Sub")
	stroke(search, 0.93)
	local scroll = new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ClipsDescendants = true,
	}, frame)
	list(scroll, 8)

	local obj = {}
	local styles = {}
	local function restyle()
		for _, f in ipairs(styles) do
			f(false)
		end
	end
	local function rebuild()
		styles = {}
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local q = string.lower(search.Text)
		local plist = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if (cfg.IncludeSelf or p ~= LocalPlayer)
				and (q == "" or string.find(string.lower(p.Name), q, 1, true) or string.find(string.lower(p.DisplayName), q, 1, true)) then
				table.insert(plist, p)
			end
		end
		table.sort(plist, function(a, b)
			return string.lower(a.DisplayName) < string.lower(b.DisplayName)
		end)
		search.PlaceholderText = ("Search %d players"):format(#Players:GetPlayers() - (cfg.IncludeSelf and 0 or 1))
		for i, p in ipairs(plist) do
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 60), Text = "", AutoButtonColor = false, LayoutOrder = i }, scroll)
			corner(b, 14)
			local img = new("ImageLabel", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 10, 0.5, -22), BackgroundTransparency = 0 }, b)
			corner(img, 22)
			paint(img, "BackgroundColor3", "Raised")
			loadThumb(p.UserId, img)
			local n1 = label(b, { Text = p.DisplayName, Font = BOLD, TextSize = 15, Position = UDim2.new(0, 64, 0, 10), Size = UDim2.new(1, -100, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }, false)
			local n2 = label(b, { Text = "@" .. p.Name, TextSize = 12, Position = UDim2.new(0, 64, 0, 31), Size = UDim2.new(1, -100, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, false)
			local ch = label(b, { Text = "›", Font = BOLD, TextSize = 22, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(16, 24), TextXAlignment = CENTER }, false)
			local function style(instant)
				local on = selected == p
				apply(b, { BackgroundColor3 = on and Theme.Accent or Theme.Card, BackgroundTransparency = on and 0.15 or 0.2 }, instant)
				apply(n1, { TextColor3 = on and Theme.OnAccent or Theme.Text }, instant)
				apply(n2, { TextColor3 = on and Theme.OnAccent or Theme.Sub }, instant)
				apply(ch, { TextColor3 = on and Theme.OnAccent or Theme.Sub }, instant)
			end
			table.insert(styles, style)
			bind(b, style)
			b.MouseButton1Click:Connect(function()
				selected = p
				restyle()
				fire(cfg.Callback, p)
			end)
		end
	end
	function obj:Get()
		return selected
	end
	function obj:Refresh()
		rebuild()
	end
	search:GetPropertyChangedSignal("Text"):Connect(rebuild)
	connect(Players.PlayerAdded, function()
		task.defer(rebuild)
	end)
	connect(Players.PlayerRemoving, function(p)
		if selected == p then
			selected = nil
			fire(cfg.Callback, nil)
		end
		task.defer(rebuild)
	end)
	rebuild()
	return obj
end

function Section:PlayerInfo(cfg)
	cfg = cfg or {}
	local range = cfg.Range or 60
	local player = nil
	local f = self:_row(104)
	local img = new("ImageLabel", { Size = UDim2.fromOffset(100, 100) }, f)
	corner(img, 14)
	paint(img, "BackgroundColor3", "Raised")
	local name = label(f, { Text = "No player selected", Font = BOLD, TextSize = 18, Position = UDim2.new(0, 116, 0, 4), Size = UDim2.new(1, -116, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd })
	local user = label(f, { Text = "Pick someone from the list", TextSize = 12, Position = UDim2.new(0, 116, 0, 30), Size = UDim2.new(1, -116, 0, 16) }, "Sub")
	local age = label(f, { Text = "", TextSize = 12, Position = UDim2.new(0, 116, 0, 54), Size = UDim2.new(1, -116, 0, 16) }, "Sub")
	local rng = label(f, { Text = "", Font = BOLD, TextSize = 13, Position = UDim2.new(0, 116, 0, 74), Size = UDim2.new(1, -116, 0, 18) }, false)
	rng.TextColor3 = Theme.Accent

	local function tick()
		if not player or not player.Parent then
			return
		end
		local a = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local b = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if a and b and (a.Position - b.Position).Magnitude <= range then
			rng.Text = "In range"
			rng.TextColor3 = rgb(70, 220, 130)
		else
			rng.Text = "Not in range"
			rng.TextColor3 = Theme.Accent
		end
	end
	table.insert(self.Window._tickers, tick)

	local obj = {}
	function obj:Set(p)
		player = p
		if p then
			name.Text = p.DisplayName
			user.Text = "@" .. p.Name
			age.Text = ("Account age: %dy %dd"):format(math.floor(p.AccountAge / 365), p.AccountAge % 365)
			img.Image = ""
			loadThumb(p.UserId, img)
			tick()
		else
			name.Text = "No player selected"
			user.Text = "Pick someone from the list"
			age.Text, rng.Text, img.Image = "", "", ""
		end
	end
	function obj:Get()
		return player
	end
	return obj
end

function Section:ThemePicker()
	local win = self.Window
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 118), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, c)
	local checks = {}
	for i, name in ipairs(THEME_ORDER) do
		local th = THEMES[name]
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = th.Card, LayoutOrder = i }, c)
		corner(b, 14)
		local st = new("UIStroke", { Color = th.Accent, Thickness = 1, Transparency = 0.85, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local bar = new("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(54, 8), BackgroundColor3 = th.Text, BackgroundTransparency = 0.15 }, b)
		corner(bar, 4)
		local pill = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(30, 14), BackgroundColor3 = th.Accent }, b)
		corner(pill, 7)
		local big = new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(70, 16), BackgroundColor3 = th.Accent }, b)
		corner(big, 8)
		local tr = new("Frame", { Position = UDim2.new(0, 12, 0, 58), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = th.Raised }, b)
		corner(tr, 4)
		local fl = new("Frame", { Size = UDim2.new(0.4, 0, 1, 0), BackgroundColor3 = th.Accent }, tr)
		corner(fl, 4)
		label(b, { Text = name, Font = BOLD, TextSize = 14, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(1, -44, 0, 18) }, false).TextColor3 = th.Text
		local ck = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = th.Accent, Visible = false }, b)
		corner(ck, 11)
		label(ck, { Text = "✓", Font = BOLD, TextSize = 13, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1) }, false).TextColor3 = th.OnAccent
		checks[name] = { ck = ck, st = st }
		b.MouseButton1Click:Connect(function()
			win:SetTheme(name)
			vibrate()
		end)
	end
	local function render()
		for name, o in pairs(checks) do
			local on = State.Theme == name
			o.ck.Visible = on
			o.st.Thickness = on and 2 or 1
			o.st.Transparency = on and 0 or 0.85
		end
	end
	table.insert(win._themeListeners, render)
	win._setters.Theme = function(v)
		win:SetTheme(v)
	end
	NovaUI.Flags.Theme = State.Theme
	render()
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
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

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function Window:SetTheme(name)
	if not THEMES[name] then
		return
	end
	State.Theme = name
	Theme = THEMES[name]
	NovaUI.Flags.Theme = name
	refresh(false)
	for _, f in ipairs(self._themeListeners) do
		f()
	end
end

function Window:SetPanelAlpha(a)
	State.PanelAlpha = math.clamp(a, 0, 0.9)
	refresh(false)
end

NovaUI.Animations = true
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
	if self._orbFx then
		pcall(self._orbFx, v)
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
	table.insert(self._log, { Title = cfg.Title, Content = cfg.Content })
	if #self._log > 20 then
		table.remove(self._log, 1)
	end
	if not cfg._replay then
		self._unread = self._unread + 1
		self._badge.Visible = true
		self._badgeText.Text = self._unread > 9 and "9+" or tostring(self._unread)
	end
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
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 3), LayoutOrder = 3 }, toast)
	corner(bar, 2)
	paint(bar, "BackgroundColor3", "Accent")
	NovaUI.Sound("ping", 0.3)
	tween(toast, 0.35, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
	tween(bar, dur, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		if toast.Parent then
			tween(toast, 0.3, { Position = UDim2.new(1, 60, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.wait(0.35)
			wrap:Destroy()
		end
	end)
end

function Window:AddStepper(cfg)
	local min, max, step = cfg.Min or 0, cfg.Max or 100, cfg.Step or 1
	local value = math.clamp(cfg.Default or min, min, max)
	local dec = tostring(step):match("%.(%d+)")
	dec = dec and #dec or 0
	local fmt = "%." .. dec .. "f"
	local f = new("Frame", { Size = UDim2.fromOffset(176, 58), LayoutOrder = #self._steppers:GetChildren() }, self._steppers)
	corner(f, 29)
	panelPaint(f)
	stroke(f, 0.88)
	local obj = { Touched = false }
	local vl
	local function set(v, silent)
		v = tonumber(fmt:format(math.clamp(v, min, max)))
		value = v
		vl.Text = fmt:format(v)
		if not silent then
			obj.Touched = true
			fire(cfg.Callback, v)
		end
	end
	local function holdBtn(text, x, delta)
		local b = new("TextButton", {
			BackgroundTransparency = 1, Text = text, Font = BOLD, TextSize = 24, AutoButtonColor = false,
			Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0, 48, 1, 0), AnchorPoint = Vector2.new(x, 0),
		}, f)
		paint(b, "TextColor3", "Text")
		local token = 0
		b.InputBegan:Connect(function(i)
			if isPress(i) then
				token = token + 1
				vibrate()
				local my = token
				set(value + delta)
				task.delay(0.4, function()
					while token == my and b.Parent do
						set(value + delta)
						task.wait(0.06)
					end
				end)
				local c
				c = i:GetPropertyChangedSignal("UserInputState"):Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						token = token + 1
						c:Disconnect()
					end
				end)
			end
		end)
	end
	holdBtn("–", 0, -step)
	holdBtn("+", 1, step)
	label(f, { Text = string.upper(cfg.Name or "VALUE"), Font = BOLD, TextSize = 10, TextXAlignment = CENTER, Position = UDim2.new(0.5, -40, 0, 9), Size = UDim2.fromOffset(80, 14) }, "Sub")
	vl = label(f, { Font = BOLD, TextSize = 19, TextXAlignment = CENTER, Position = UDim2.new(0.5, -40, 0, 24), Size = UDim2.fromOffset(80, 24) })
	vl.Text = fmt:format(value)
	function obj:Set(v, silent)
		set(v, silent)
	end
	function obj:Get()
		return value
	end
	return obj
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

function Window:SelectTab(name)
	for _, t in ipairs(self.Tabs) do
		if t.Name == name then
			self:_select(t)
			return
		end
	end
end

function Window:_select(tab, instant)
	for _, t in ipairs(self.Tabs) do
		local on = t == tab
		t._active = on
		t.Page.Visible = on
		t._render(instant == true)
	end
	if not instant then
		tab.Left.Position = UDim2.new(0, -30, 0, 150)
		tab.Right.Position = UDim2.new(1, 30, 0, 150)
		tween(tab.Left, 0.35, { Position = UDim2.new(0, 16, 0, 150) }, Enum.EasingStyle.Quint)
		tween(tab.Right, 0.35, { Position = UDim2.new(1, -16, 0, 150) }, Enum.EasingStyle.Quint)
	end
end

function Window:SaveConfig(name)
	if not writefile then
		return false, "writefile not supported"
	end
	pcall(makefolder, self.Folder)
	local data = {}
	for k, v in pairs(NovaUI.Flags) do
		data[k] = encode(v)
	end
	local ok, err = pcall(writefile, self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
	return ok, err
end

function Window:LoadConfig(name)
	if not (readfile and isfile) then
		return false, "readfile not supported"
	end
	local path = self.Folder .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "config not found"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok then
		return false, "bad config file"
	end
	for flag, raw in pairs(data) do
		local setter = self._setters[flag]
		if setter then
			pcall(setter, decode(raw))
		end
	end
	return true
end

function Window:AutoLoad()
	if isfile and readfile then
		local p = self.Folder .. "/autoload.txt"
		if isfile(p) then
			local n = readfile(p)
			if n and n ~= "" then
				return self:LoadConfig(n)
			end
		end
	end
end

function Window:Destroy()
	for _, c in ipairs(Conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	Conns = {}
	Binds = {}
	if self.Gui then
		self.Gui:Destroy()
	end
	GuiRoot = nil
	if NovaUI._window == self then
		NovaUI._window = nil
	end
end

function Window:CreateSettingsTab(cfg)
	cfg = cfg or {}
	local win = self
	local tab = self:CreateTab({ Name = "Settings", Icon = "⚙️" })

	local themes = tab:Section({ Title = "Themes", Icon = "🎨", Side = "Left" })
	themes:ThemePicker()

	local ui = tab:Section({ Title = "Interface", Icon = "⚙️", Side = "Left" })
	ui:Slider({ Title = "Panel transparency", Min = 0, Max = 60, Default = math.floor(State.PanelAlpha * 100 + 0.5), Suffix = "%", Flag = "PanelAlpha", Callback = function(v) win:SetPanelAlpha(v / 100) end })
	ui:Keybind({ Title = "Toggle menu", Default = self.ToggleKey, Flag = "ToggleKey", OnChange = function(k) if k then win.ToggleKey = k end end })

	local cf = tab:Section({ Title = "Configs", Icon = "🌐", Side = "Left" })
	local cname = cf:Input({ Placeholder = "Config name", Default = "default" })
	cf:Actions({
		{ Title = "Save", Description = "Write config", Icon = "✔️", Callback = function()
			local ok, err = win:SaveConfig(cname:Get())
			win:Notify({ Title = ok and "Config saved" or "Save failed", Content = ok and cname:Get() or tostring(err) })
		end },
		{ Title = "Load", Description = "Apply config", Icon = "🔃", Callback = function()
			local ok, err = win:LoadConfig(cname:Get())
			win:Notify({ Title = ok and "Config loaded" or "Load failed", Content = ok and cname:Get() or tostring(err) })
		end },
	})
	cf:Toggle({ Title = "Auto-load this config", Description = "Runs on next execute", Callback = function(v)
		if writefile and v then
			pcall(makefolder, win.Folder)
			pcall(writefile, win.Folder .. "/autoload.txt", cname:Get())
		elseif writefile then
			pcall(writefile, win.Folder .. "/autoload.txt", "")
		end
	end })

	local launch = tab:Section({ Title = "Auto-launch", Icon = "bolt", Side = "Right" })
	launch:Toggle({ Title = "Auto relaunch", Description = "Re-run script after teleport", Flag = "AutoRelaunch", Callback = function(v)
		if v and queue_on_teleport and cfg.RelaunchScript then
			pcall(queue_on_teleport, cfg.RelaunchScript)
		end
	end })

	local util = tab:Section({ Title = "Utilities", Icon = "settings", Side = "Right" })
	local afkConn
	util:Toggle({ Title = "Anti-AFK", Description = "Stops the idle kick", Icon = "🛡️", Flag = "AntiAFK", Callback = function(v)
		if afkConn then
			afkConn:Disconnect()
			afkConn = nil
		end
		if v then
			local vu = game:GetService("VirtualUser")
			afkConn = LocalPlayer.Idled:Connect(function()
				pcall(function()
					vu:CaptureController()
					vu:ClickButton2(Vector2.new())
				end)
			end)
		end
	end })
	util:Toggle({ Title = "FPS counter", Description = "Shown in the top bar", Icon = "bolt", Default = true, Flag = "ShowFPS", Callback = function(v)
		if win._fpsItem then
			win._fpsItem.Visible = v
		end
	end })
	local rejoinConn
	util:Toggle({ Title = "Auto-rejoin", Description = "Rejoin after a kick or disconnect", Icon = "🔃", Flag = "AutoRejoin", Callback = function(v)
		if rejoinConn then
			rejoinConn:Disconnect()
			rejoinConn = nil
		end
		if v then
			pcall(function()
				local overlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5).promptOverlay
				rejoinConn = overlay.ChildAdded:Connect(function(c)
					if c.Name == "ErrorPrompt" then
						task.wait(2)
						TeleportService:Teleport(game.PlaceId, LocalPlayer)
					end
				end)
			end)
		end
	end })
	local saved
	util:Toggle({ Title = "Lower graphics", Description = "Less lag: no shadows or effects", Icon = "🧊", Flag = "LowGfx", Callback = function(v)
		pcall(function()
			if v then
				saved = { q = settings().Rendering.QualityLevel, s = Lighting.GlobalShadows, fx = {} }
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
				Lighting.GlobalShadows = false
				for _, e in ipairs(Lighting:GetChildren()) do
					if e:IsA("PostEffect") or e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
						table.insert(saved.fx, { e, e.Enabled })
						e.Enabled = false
					end
				end
			elseif saved then
				settings().Rendering.QualityLevel = saved.q
				Lighting.GlobalShadows = saved.s
				for _, p in ipairs(saved.fx) do
					p[1].Enabled = p[2]
				end
			end
		end)
	end })
	local oldVol
	util:Toggle({ Title = "Mute game audio", Description = "Silence the whole game", Icon = "👁️", Flag = "MuteAudio", Callback = function(v)
		pcall(function()
			local gs = UserSettings():GetService("UserGameSettings")
			if v then
				oldVol = gs.MasterVolume
				gs.MasterVolume = 0
			else
				gs.MasterVolume = oldVol or 1
			end
		end)
	end })

	local srv = tab:Section({ Title = "This server", Icon = "server", Side = "Right" })
	srv:ServerInfo()
	srv:Actions({
		{ Title = "Rejoin", Description = "Same server", Icon = "🔃", Callback = function()
			pcall(function()
				if #Players:GetPlayers() <= 1 then
					LocalPlayer:Kick("\nRejoining...")
					task.wait()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				else
					TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
				end
			end)
		end },
		{ Title = "Server hop", Description = "Find a new server", Icon = "🌏", Callback = function()
			win:Notify({ Title = "Server hop", Content = "Searching for a server..." })
			local ok, res = pcall(function()
				return HttpService:JSONDecode(game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)))
			end)
			if ok and res and res.data then
				for _, s in ipairs(res.data) do
					if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
						return
					end
				end
			end
			win:Notify({ Title = "Server hop failed", Content = "No free server found." })
		end },
	})

	local game_ = tab:Section({ Title = "Game", Icon = "🎮", Side = "Right" })
	if cfg.Discord then
		game_:Button({ Title = "Join Discord", Style = "Primary", Callback = function()
			if setclipboard then
				setclipboard(cfg.Discord)
			end
			win:Notify({ Title = "Discord", Content = "Invite link copied to clipboard." })
		end })
	end
	game_:Label("Place " .. tostring(game.PlaceId))
	game_:Actions({
		{ Title = "Copy link", Icon = "game", Callback = function()
			if setclipboard then
				setclipboard(("roblox://placeId=%d&gameInstanceId=%s"):format(game.PlaceId, game.JobId))
			end
			win:Notify({ Title = "Copied", Content = "Join link copied." })
		end },
		{ Title = "Job ID", Icon = "server", Callback = function()
			if setclipboard then
				setclipboard(game.JobId)
			end
			win:Notify({ Title = "Copied", Content = "Job ID copied." })
		end },
	})
	return tab
end

------------------------------------------------------------------------
-- CreateWindow
------------------------------------------------------------------------
function NovaUI:CreateWindow(cfg)
	cfg = cfg or {}
	if NovaUI._window then
		NovaUI._window:Destroy()
	end
	Binds = {}
	if cfg.Theme and THEMES[cfg.Theme] then
		State.Theme = cfg.Theme
		Theme = THEMES[cfg.Theme]
	end
	NovaUI.Flags = {}
	NovaUI.Flags.Theme = State.Theme

	local win = setmetatable({
		Tabs = {}, Name = cfg.Name or "NOVA", Folder = cfg.Folder or "NovaUI",
		ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift, Visible = true,
		_setters = {}, _tickers = {}, _themeListeners = {}, _log = {}, _unread = 0, _toastId = 0,
	}, Window)
	NovaUI._window = win

	local gui = new("ScreenGui", { Name = "NovaUI_" .. HttpService:GenerateGUID(false):sub(1, 6), ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	local parent
	local okHui, hui = pcall(function()
		return gethui and gethui()
	end)
	if okHui and hui then
		parent = hui
	else
		local okCore = pcall(function()
			gui.Parent = game:GetService("CoreGui")
		end)
		if okCore and gui.Parent then
			parent = game:GetService("CoreGui")
		else
			parent = LocalPlayer:WaitForChild("PlayerGui")
		end
	end
	gui.Parent = parent
	GuiRoot = gui
	win.Gui = gui

	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local uiScale = new("UIScale", {}, root)
	local function relayout()
		local sz = gui.AbsoluteSize
		local s
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			s = math.clamp(sz.Y / 660, 0.5, 1.6)
		else
			s = math.clamp(sz.Y / 820, 0.75, 1.2)
		end
		uiScale.Scale = s
		root.Size = UDim2.fromOffset(sz.X / s, sz.Y / s)
	end
	relayout()
	connect(gui:GetPropertyChangedSignal("AbsoluteSize"), relayout)

	local main = new("Frame", { Name = "Main", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	win._main = main
	win._root = root
	win._mainScale = new("UIScale", {}, main)
	-- ===== ambient blackholes in the corners / sides (decoration only: never takes touch input) =====
	-- lives in its own full-screen ScreenGui so the holes sit in the REAL screen corners (not the notch-safe area)
	pcall(function()
		local old = parent:FindFirstChild("NovaAmbient")
		if old then old:Destroy() end
	end)
	local ambGui = new("ScreenGui", { Name = "NovaAmbient", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, parent)
	pcall(function()
		ambGui.ScreenInsets = Enum.ScreenInsets.None
	end)
	local ambient = new("Frame", { Name = "Ambient", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0, Active = false }, ambGui)
	win._ambient, win._ambGui = ambient, ambGui
	do
		local spots = {
			{ 0, 0, 260, 0.5 }, { 1, 0, 260, 0.5 }, { 0, 1, 260, 0.5 }, { 1, 1, 260, 0.5 },
			{ 0, 0.5, 120, 0.5 }, { 1, 0.5, 120, 0.5 },
		}
		for _, sp in ipairs(spots) do
			local h = NovaUI.MakeBlackhole(ambient, sp[3], { Position = UDim2.fromScale(sp[1], sp[2]), ParticleCount = 6, ZIndex = 0, Bind = true })
			h.Active = false
		end
		-- energy lines running along the screen edges
		local function line(pos, size, rot)
			local f = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = pos, Size = size, ZIndex = 0, BackgroundTransparency = 0.35, Active = false }, ambient)
			local g = new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Color = ColorSequence.new(Theme.Accent, Color3.fromRGB(235, 215, 255)) }, f)
			task.spawn(function()
				local t = math.random() * 3
				while f.Parent do
					t = t + 0.03
					g.Offset = rot == 0 and Vector2.new((t * 0.35) % 2 - 1, 0) or Vector2.new(0, (t * 0.35) % 2 - 1)
					task.wait(0.03)
				end
			end)
		end
		line(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 2), 0)
		line(UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), 0)
		line(UDim2.new(0, 0, 0, 0), UDim2.new(0, 2, 1, 0), 90)
		line(UDim2.new(1, -2, 0, 0), UDim2.new(0, 2, 1, 0), 90)
	end


	local function pill(w, h, anchorX, posX, posY)
		local f = new("Frame", { AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, posX, 0, posY), Size = UDim2.fromOffset(w, h) }, main)
		corner(f, h / 2)
		panelPaint(f)
		stroke(f, 0.88)
		return f
	end

	local prof = pill(310, 56, 0, 16, 12)
	local av = new("ImageLabel", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40) }, prof)
	corner(av, 20)
	paint(av, "BackgroundColor3", "Raised")
	loadThumb(LocalPlayer.UserId, av)
	label(prof, { Text = "Welcome back, " .. LocalPlayer.DisplayName, Font = BOLD, TextSize = 14, Position = UDim2.fromOffset(58, 9), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local hour = tonumber(os.date("%H"))
	local greet = hour < 12 and "Morning light, make it a good one" or (hour < 18 and "Good afternoon, stay sharp" or "Good evening, enjoy the session")
	label(prof, { Text = cfg.Subtitle or greet, TextSize = 12, Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd }, "Sub")

	local chat = pill(56, 56, 0, 336, 12)
	local chatBtn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1) }, chat)
	icon(chatBtn, "chat", 22, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 6), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = rgb(255, 92, 110), Visible = false, ZIndex = 5 }, chat)
	corner(badge, 11)
	win._badge = badge
	win._badgeText = label(badge, { Font = BOLD, TextSize = 11, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, false)
	win._badgeText.TextColor3 = rgb(255, 255, 255)
	chatBtn.MouseButton1Click:Connect(function()
		vibrate()
		win._unread = 0
		badge.Visible = false
		local start = math.max(1, #win._log - 2)
		local copy = {}
		for i = start, #win._log do
			table.insert(copy, win._log[i])
		end
		for _, n in ipairs(copy) do
			win:Notify({ Title = n.Title, Content = n.Content, Duration = 3, _replay = true })
		end
		fire(cfg.OnChat)
	end)

	local grid = pill(56, 56, 0, 400, 12)
	local gridBtn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1) }, grid)
	icon(gridBtn, "grid", 22, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	gridBtn.MouseButton1Click:Connect(function()
		vibrate()
		win:Toggle()
	end)

	local stats = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(0, 56), AutomaticSize = AX }, main)
	corner(stats, 28)
	panelPaint(stats)
	stroke(stats, 0.88)
	list(stats, 20, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pad(stats, 22, 0, 22, 0)
	local function statItem(ic, order)
		local it = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, LayoutOrder = order }, stats)
		list(it, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		icon(it, ic, 15, "Accent")
		local t = label(it, { Font = BOLD, TextSize = 15, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, LayoutOrder = 2 })
		return it, t
	end
	local _, plT = statItem("users", 1)
	local _, pgT = statItem("wifi", 2)
	local fpsItem, fpsT = statItem("bolt", 3)
	win._fpsItem = fpsItem
	local frames, last = 0, os.clock()
	connect(RunService.Heartbeat, function()
		frames = frames + 1
		local n = os.clock()
		if n - last >= 0.5 then
			fpsT.Text = tostring(math.floor(frames / (n - last) + 0.5))
			frames, last = 0, n
		end
	end)
	table.insert(win._tickers, function()
		plT.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		pgT.Text = getPing() .. "ms"
	end)
	plT.Text, pgT.Text, fpsT.Text = "-/-", "0ms", "60"

	local clock = pill(128, 56, 1, -16, 12)
	icon(clock, "sun", 20, "Accent", { Position = UDim2.fromOffset(14, 16) })
	local timeL = label(clock, { Font = BOLD, TextSize = 17, Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -52, 0, 22) })
	local dateL = label(clock, { TextSize = 12, Position = UDim2.fromOffset(46, 29), Size = UDim2.new(1, -52, 0, 16) }, "Sub")
	table.insert(win._tickers, function()
		timeL.Text = os.date("%H:%M")
		dateL.Text = os.date("%a %d")
	end)
	timeL.Text, dateL.Text = os.date("%H:%M"), os.date("%a %d")

	local exec = pill(158, 56, 1, -154, 12)
	local dot = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(36, 36) }, exec)
	corner(dot, 18)
	paint(dot, "BackgroundColor3", "Accent")
	icon(dot, "settings", 18, "OnAccent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local exName = "Unknown"
	pcall(function()
		exName = identifyexecutor and (identifyexecutor()) or "Unknown"
	end)
	label(exec, { Text = tostring(exName), Font = BOLD, TextSize = 14, Position = UDim2.fromOffset(54, 9), Size = UDim2.new(1, -60, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	label(exec, { Text = "Executor", TextSize = 12, Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -60, 0, 16) }, "Sub")

	local st = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(0, 58), AutomaticSize = AX, BackgroundTransparency = 1 }, main)
	list(st, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	win._steppers = st

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

	-- ========== YADSAN ORB: whitehole while the hub is open, blackhole while it is minimised ==========
	local orb = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 222), Size = UDim2.fromOffset(150, 150),
		Text = "", AutoButtonColor = false, ZIndex = 60, BackgroundTransparency = 1,
	}, root)
	local bhHolder, bhApi = NovaUI.MakeBlackhole(orb, 118, { Bind = true, ZIndex = 1, White = true })
	win._orb, win._bh = orb, bhApi
	local bhScale = new("UIScale", {}, bhHolder)
	local hovering = false
	orb.MouseEnter:Connect(function()
		hovering = true
		tween(bhScale, 0.25, { Scale = 1.1 }, Enum.EasingStyle.Back)
	end)
	orb.MouseLeave:Connect(function()
		hovering = false
		tween(bhScale, 0.25, { Scale = 1 })
	end)
	orb.InputBegan:Connect(function(i)
		if isPress(i) then
			tween(bhScale, 0.1, { Scale = 0.88 })
		end
	end)
	orb.InputEnded:Connect(function(i)
		if isPress(i) then
			tween(bhScale, 0.35, { Scale = hovering and 1.1 or 1 }, Enum.EasingStyle.Back)
		end
	end)

	-- pulse rings (go outward when white, inward when black)
	local pulses = {}
	for k = 1, 2 do
		local r = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(118, 118), ZIndex = 1 }, orb)
		corner(r, 200)
		local st = new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 1 }, r)
		pulses[k] = { f = r, s = st }
	end

	-- YADSAN lettering, one label per letter so it can shimmer
	local letters = {}
	local letterRow = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(140, 22), ZIndex = 10 }, orb)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 0) }, letterRow)
	local word = string.upper(cfg.OrbText or "yadsan")
	local charW = math.clamp(math.floor(132 / math.max(#word, 1)), 7, 14)
	local charSz = math.clamp(charW + 2, 10, 15)
	for i = 1, #word do
		letters[i] = new("TextLabel", {
			BackgroundTransparency = 1, Text = word:sub(i, i), Font = Enum.Font.GothamBlack, TextSize = charSz, Size = UDim2.fromOffset(charW, 22),
			TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.35, TextStrokeColor3 = Color3.new(0, 0, 0), ZIndex = 10, LayoutOrder = i,
		}, letterRow)
	end
	local lastWhite = nil
	connect(RunService.Heartbeat, function()
		if not orb.Parent or not orb.Visible then
			return
		end
		local t = os.clock()
		local white = bhApi.IsWhite()
		bhHolder.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 1.6) * 3)
		for i, l in ipairs(letters) do
			local w = 0.5 + 0.5 * math.sin(t * 2.2 - i * 0.8)
			if white then
				l.TextColor3 = Color3.fromRGB(8, 4, 20):Lerp(Theme.Accent, w * 0.55)
				l.TextStrokeColor3 = Color3.new(1, 1, 1)
				l.TextStrokeTransparency = 0.5
			else
				l.TextColor3 = Color3.fromRGB(235, 220, 255):Lerp(Theme.Accent, w * 0.5)
				l.TextStrokeColor3 = Color3.new(0, 0, 0)
				l.TextStrokeTransparency = 0.25
			end
			l.Position = UDim2.fromOffset(0, math.sin(t * 2.2 - i * 0.8) * 1.2)
		end
		for k, p in ipairs(pulses) do
			local ph = (t * 0.55 + k * 0.5) % 1
			local sz = white and (118 * (0.85 + ph * 0.7)) or (118 * (1.55 - ph * 0.7))
			p.f.Size = UDim2.fromOffset(sz, sz)
			p.s.Color = white and Color3.new(1, 1, 1) or Theme.Accent
			p.s.Transparency = 0.25 + 0.75 * (white and ph or (1 - ph))
		end
	end)

	-- background blur while the hub is open (blurs the game world, never the GUI)
	NovaUI.Blur = true
	local blur = Instance.new("BlurEffect")
	blur.Name = "YadsanBlur"
	blur.Size = 0
	blur.Enabled = true
	pcall(function()
		blur.Parent = game:GetService("Lighting")
	end)
	local function blurTo(on)
		tween(blur, on and 0.6 or 0.4, { Size = (on and NovaUI.Blur) and 20 or 0 }, Enum.EasingStyle.Quad)
	end
	win._blurTo = blurTo
	gui.AncestryChanged:Connect(function()
		if not gui.Parent then
			pcall(function() blur:Destroy() end)
			pcall(function() win._ambGui:Destroy() end)
		end
	end)
	win._onVis = function(v)
		bhApi.SetWhite(v)
		bhApi.Boost(1)
		blurTo(v)
		if win._ambGui then
			win._ambGui.Enabled = v
		end
	end
	-- particles that get sucked into / burst out of the orb
	win._orbFx = function(opening)
		NovaUI.Sound(opening and "burst" or "suck", 0.55, 3)
		local sc = uiScale.Scale
		local oc = (orb.AbsolutePosition + orb.AbsoluteSize / 2 - root.AbsolutePosition) / sc
		local rnd = Random.new()
		for _ = 1, 26 do
			local ang = rnd:NextNumber() * math.pi * 2
			local dist = rnd:NextNumber(140, 420)
			local far = oc + Vector2.new(math.cos(ang), math.sin(ang)) * dist
			local a, b = opening and oc or far, opening and far or oc
			local sz = rnd:NextInteger(3, 7)
			local d = new("Frame", {
				BackgroundColor3 = (rnd:NextNumber() > 0.5) and Color3.new(1, 1, 1) or Theme.Accent, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(sz, sz), ZIndex = 58,
				BackgroundTransparency = opening and 0 or 0.6,
			}, root)
			corner(d, 8)
			local dur = rnd:NextNumber(0.45, 0.75)
			tween(d, dur, { Position = UDim2.fromOffset(b.X, b.Y), BackgroundTransparency = opening and 1 or 0 }, Enum.EasingStyle.Quint, opening and Enum.EasingDirection.Out or Enum.EasingDirection.In)
			task.delay(dur + 0.05, function()
				d:Destroy()
			end)
		end
		local ring = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(oc.X, oc.Y), Size = UDim2.fromOffset(opening and 80 or 520, opening and 80 or 520), ZIndex = 57 }, root)
		corner(ring, 600)
		local rs = new("UIStroke", { Thickness = 3, Color = opening and Color3.new(1, 1, 1) or Theme.Accent, Transparency = opening and 0.1 or 0.9 }, ring)
		tween(ring, 0.65, { Size = UDim2.fromOffset(opening and 560 or 60, opening and 560 or 60) }, Enum.EasingStyle.Quint, opening and Enum.EasingDirection.Out or Enum.EasingDirection.In)
		tween(rs, 0.65, { Transparency = opening and 1 or 0.1 })
		task.delay(0.7, function()
			ring:Destroy()
		end)
	end
	if NovaUI.HoldOpen then
		orb.Visible = false
		main.Visible = false
		win.Visible = false
		if win._ambGui then
			win._ambGui.Enabled = false
		end
	end

	local dragging, moved, startIn, startPos = false, false, nil, nil
	orb.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging, moved, startIn, startPos = true, false, i.Position, orb.Position
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and isMove(i) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then
				moved = true
			end
			if moved then
				orb.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / uiScale.Scale, startPos.Y.Scale, startPos.Y.Offset + d.Y / uiScale.Scale)
			end
		end
	end)
	connect(UserInputService.InputEnded, function(i)
		if dragging and isPress(i) then
			dragging = false
			if not moved then
				vibrate()
				win:Toggle()
			end
		end
	end)

	connect(UserInputService.InputBegan, function(i, gp)
		if not gp and win.ToggleKey and i.KeyCode == win.ToggleKey then
			win:Toggle()
		end
	end)

	task.spawn(function()
		while gui.Parent do
			for _, f in ipairs(win._tickers) do
				pcall(f)
			end
			task.wait(1)
		end
	end)

	if cfg.QuickControls ~= false then
		local hum = getHumanoid()
		local speed = win:AddStepper({ Name = "Speed", Min = 0, Max = 5000, Step = 2, Default = hum and hum.WalkSpeed or 16, Callback = function(v)
			local h = getHumanoid()
			if h then
				h.WalkSpeed = v
			end
		end })
		local usePower = hum == nil or hum.UseJumpPower
		local jump = win:AddStepper({ Name = "Jump", Min = 0, Max = 1000, Step = usePower and 5 or 1, Default = hum and (usePower and hum.JumpPower or hum.JumpHeight) or 50, Callback = function(v)
			local h = getHumanoid()
			if h then
				if h.UseJumpPower then
					h.JumpPower = v
				else
					h.JumpHeight = v
				end
			end
		end })
		local cam = workspace.CurrentCamera
		local fov = win:AddStepper({ Name = "FOV", Min = 30, Max = 120, Step = 1, Default = cam and cam.FieldOfView or 70, Callback = function(v)
			if workspace.CurrentCamera then
				workspace.CurrentCamera.FieldOfView = v
			end
		end })
		win.Speed, win.Jump, win.FOV = speed, jump, fov
		connect(LocalPlayer.CharacterAdded, function(c)
			local h = c:WaitForChild("Humanoid", 10)
			task.wait(0.5)
			if h then
				if speed.Touched then
					h.WalkSpeed = speed:Get()
				end
				if jump.Touched then
					if h.UseJumpPower then
						h.JumpPower = jump:Get()
					else
						h.JumpHeight = jump:Get()
					end
				end
			end
		end)
	end

	return win
end

return NovaUI
end)()


-- ================= NovaUI front-end for Flames Hub =================
local function BuildFlamesNovaUI()
    local g = getgenv()
    local Window = SharedNovaUI:CreateWindow({
        Name = "Flames Hub",
        Theme = "Sun",
        Folder = "FLAMES_HUB",
    })
    local function note(t, c) pcall(function() Window:Notify({ Title = t, Content = c }) end) end
    local function call(name, ...)
        local args = table.pack(...)
        return function()
            local fn = g[name]
            if type(fn) ~= "function" then
                note("Not available", name .. " isn't loaded yet.")
                return
            end
            local ok, err = pcall(fn, table.unpack(args, 1, args.n))
            if not ok then note("Error", tostring(err)) end
        end
    end

    local Tools = Window:CreateTab({ Name = "Tools", Icon = "🔥" })
    local guis = Tools:Section({ Title = "Flames windows", Icon = "grid", Side = "Left" })
    guis:Button({ Title = "Performance Stats", Callback = call("LoadPerformanceStatsGUI") })
    guis:Button({ Title = "Car Listing", Callback = call("car_listing_gui") })
    guis:Button({ Title = "Save Outfits", Callback = call("save_outfits_GUI") })
    guis:Button({ Title = "Workspace Editor", Callback = call("workspace_editor_script_GUI") })
    guis:Button({ Title = "Annoyance GUI", Callback = call("annoyance_GUI") })

    local cfg = Tools:Section({ Title = "Configuration Manager", Icon = "settings", Side = "Right" })
    cfg:Toggle({
        Title = "Show configuration manager",
        Default = false,
        Callback = function(v) call("toggle_config_manager", v == true)() end,
    })

    Window:CreateSettingsTab({})
    pcall(function() Window:Reveal() end)
    note("Flames Hub", "Loaded. Press RightShift to hide or show this window.")
end

local function RunFlamesHub()
if not game:IsLoaded() then
    local msg_instance = Instance.new("Message")
    local hint_instance = Instance.new("Hint")
    msg_instance.Text = "Yadsan Hub is waiting for the current experience to load fully."
    hint_instance.Text = "Yadsan Hub is currently waiting for the game to load."
    msg_instance.Parent = workspace
    hint_instance.Parent = workspace
    game.Loaded:Wait()
    task.wait(0.1)
    msg_instance:Destroy()
    hint_instance:Destroy()
end

-- [[     INITIALIZATION (Roblox Environment)     ]] --
local In_Studio = false
local g
if game:GetService("RunService"):IsStudio() then
    g = _G
    In_Studio = true
else
    g = getgenv()
end
wait(0.25)
if game:GetService("RunService"):IsServer() then warn("This script can only be run on the client."); return end
if game.PlaceId ~= 13967668166 and game.PlaceId ~= 99644611200703 and game.PlaceId ~= 99154507657228 then
    if g.notify and typeof(g.notify) == "function" then
        return g.notify("Error", "This game isn't allowed to run with this script (only: Life Together RP (main), Ski Resort, and Bora Bora).", 30)
    else
        return warn("This game isn't allowed to run with this script (only: Life Together RP (main), Ski Resort, and Bora Bora).")
    end
end
wait(0.1)
local blank_F = g.blank_function or g.blankfunction or function(...) return ... end
local cloneref = typeof(cloneref) == "function" and cloneref or function(instance) return instance end
-- [[ Should no longer break in Roblox Studio. 😈🚬 ]] --
local http_game
if In_Studio then
    http_game = blank_F
else
    http_game = (g["game"] or game)["HttpGet"]
    g.http_get = function(url) return http_game(game, url) end
end
wait(0.1)
local StarterGui = g.StarterGui or cloneref and cloneref(game:GetService("StarterGui")) or game:GetService("StarterGui")
local Raw_Version = "V9.4.2"
g.Script_Version = tostring(Raw_Version).."-LifeHub"
local Players = g.Players or cloneref and cloneref(game:GetService("Players")) or game:GetService("Players") -- up here to let everything load first.
local localPlayer = g.LocalPlayer or Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local speaker = localPlayer
if In_Studio and script.Parent ~= StarterGui then script.Parent = StarterGui end
g.Keybind_Input_Disabled_For_Mini_Game = g.Keybind_Input_Disabled_For_Mini_Game or false
g.SideGlitch_Enabled = g.SideGlitch_Enabled or true
g.SideGlitch_Speed = g.SideGlitch_Speed or 5
g.SideGlitch_Distance = g.SideGlitch_Distance or 5
g.SideGlitch_Smooth = g.SideGlitch_Smooth or 0.18
g.colors = g.colors or {
    Color3.fromRGB(255,255,255),
    Color3.fromRGB(128,128,128),
    Color3.fromRGB(0,0,0),
    Color3.fromRGB(0,0,255),
    Color3.fromRGB(0,255,0),
    Color3.fromRGB(0,255,255),
    Color3.fromRGB(255,165,0),
    Color3.fromRGB(139,69,19),
    Color3.fromRGB(255,255,0),
    Color3.fromRGB(50,205,50),
    Color3.fromRGB(255,0,0),
    Color3.fromRGB(255,155,172),
    Color3.fromRGB(128,0,128),
}
g.LocalPlayer = g.LocalPlayer or localPlayer
if not In_Studio then
    if not g.GlobalEnvironmentFramework_Initialized then
        loadstring(g.http_get("https://pastebin.com/raw/T25mDhBZ"))()
        wait(0.1)
        g.GlobalEnvironmentFramework_Initialized = true
    end
end
wait(0.25)
if not g.LifeTogether_Actual_Flames_Hub_Running_Functioning_Currently_On_Client then if g.notify and typeof(g.notify) == "function" then g.notify("Success", "Got LocalPlayer: "..tostring(g.LocalPlayer), 5) end end
-- [[     SERVICES / DEFINITIONS     ]] --
local has_gethui = (typeof(gethui) == "function") or (typeof(g.gethui) == "function")
local has_gethidden = (typeof(get_hidden_gui) == "function") or (typeof(g.get_hidden_gui) == "function")
local RunService = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local CoreGui = g.CoreGui or cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
local Workspace = g.Workspace or cloneref and cloneref(game:GetService("Workspace")) or game:GetService("Workspace")
local RobloxReplicatedStorage = g.RobloxReplicatedStorage or cloneref and cloneref(game:GetService("RobloxReplicatedStorage")) or game:GetService("RobloxReplicatedStorage")
local ReplicatedStorage = g.ReplicatedStorage or cloneref and cloneref(game:GetService("ReplicatedStorage")) or game:GetService("ReplicatedStorage")
local HttpService = g.HttpService or cloneref and cloneref(game:GetService("HttpService")) or game:GetService("HttpService")
local LocalPlayer = g.LocalPlayer or Players.LocalPlayer
local UserInputService = g.UserInputService or cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local TweenService = g.TweenService or cloneref and cloneref(game:GetService("TweenService")) or game:GetService("TweenService")
local Debris = g.Debris or cloneref and cloneref(game:GetService("Debris")) or game:GetService("Debris")
local Chat = g.Chat or cloneref and cloneref(game:GetService("Chat")) or game:GetService("Chat")
local me = LocalPlayer or speaker or g.LocalPlayer or Players.LocalPlayer
local plr = me
local TextChatService = g.TextChatService or cloneref and cloneref(game:GetService("TextChatService")) or game:GetService("TextChatService")
local Lighting = g.Lighting or cloneref and cloneref(game:GetService("Lighting")) or game:GetService("Lighting")
local lighting = Lighting
local work = Workspace
local player_gui = g.PlayerGui or LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
local uis = UserInputService
local UIS = uis
local ts  = TweenService
local rs  = RunService
local IsMobile = UserInputService.TouchEnabled
local http = HttpService
if not has_gethui and not has_gethidden and not g.roblox_hidden_gui_location then
    if In_Studio then
        g.roblox_hidden_gui_location = player_gui
    else
        for _, v in ipairs(CoreGui:GetChildren()) do
            if v:IsA("ScreenGui") and v.Name == "RobloxGui" then
                g.roblox_hidden_gui_location = v
                break
            end
        end
    end
    local function resolve_gui()
        if In_Studio then return player_gui end
        if g.roblox_hidden_gui_location and g.roblox_hidden_gui_location.Parent and g.roblox_hidden_gui_location:IsA("ScreenGui") then return g.roblox_hidden_gui_location end
        return CoreGui
    end
    g.get_hui = resolve_gui
    g.get_hidden_gui = resolve_gui
end

local verify_file = "is_verified_in_Flames_Hub.txt"
local Insert = table.insert
-- [[ for the Command Handler, because it can check if there is a number in a string (like a command you send). ]] -- 
g.Is_Integer_In_Str = g.Is_Integer_In_Str or function(str)
    if type(str) == "number" then return str % 1 == 0 end
    if type(str) == "string" then return str:match("^-?%d+$") ~= nil end
    return false
end

-- [[ NEW!: makes it way fucking easier to find attributes. ]] --
g._attr_cache = g._attr_cache or {}
g.attr_cached_fuzzy = g.attr_cached_fuzzy or function(obj, search)
    if not obj or not obj.Parent then return nil end
    local cache = g._attr_cache[obj]
    if cache then
        for name, value in pairs(cache) do
            if name:lower():find(search:lower(), 1, true) then
                return value
            end
        end
        return nil
    end

    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if not ok or not attrs then return nil end
    g._attr_cache[obj] = attrs
    for name, value in pairs(attrs) do
        if name:lower():find(search:lower(), 1, true) then
            return value
        end
    end

    return nil
end

g.attr_main_checker = g.attr_main_checker or function(obj, attr, expected)
    local ok, result = pcall(function() return obj:GetAttribute(attr) end)
    return ok and result == expected
end

g.isProperty = g.isProperty or function(inst, prop)
    local s, r = pcall(function() return inst[prop] end)
    if not s then return nil end
    return r
end

g.hasProp = g.hasProp or function(inst, prop)
    return inst and g.isProperty(inst, prop) ~= nil
end

g.setProperty = g.setProperty or function(inst, prop, v)
    local s, _ = pcall(function() inst[prop] = v end)
    return s
end

g.safeSet = g.safeSet or function(inst, prop, val)
    if inst and g.hasProp(inst, prop) then g.setProperty(inst, prop, val) end
end

local locale_ids = {
    "en-us", "en-gb", "en-au", "en-ca", "en-za", "en-nz", "en-ie",
    "pt-br", "pt-pt",
    "es-es", "es-mx", "es-ar", "es-co", "es-cl", "es-pe", "es-ve",
    "fr-fr", "fr-ca", "fr-be", "fr-ch",
    "de-de", "de-at", "de-ch",
    "it-it", "it-ch",
    "nl-nl", "nl-be",
    "pl-pl",
    "ru-ru",
    "tr-tr",
    "sv-se",
    "no-no",
    "da-dk",
    "fi-fi",
    "cs-cz",
    "sk-sk",
    "hu-hu",
    "ro-ro",
    "bg-bg",
    "hr-hr",
    "uk-ua",
    "el-gr",
    "ja-jp",
    "ko-kr",
    "zh-cn",
    "zh-tw",
    "id-id",
    "ms-my",
    "th-th",
    "vi-vn",
    "ar-sa",
}

local matrix_ids = {
    "1865-6-19-matrix",
    "1923-4-7-matrix",
    "1947-8-15-matrix",
    "1955-12-1-matrix",
    "1961-4-12-matrix",
    "1963-11-22-matrix",
    "1969-7-20-matrix",
    "1971-3-8-matrix",
    "1975-4-30-matrix",
    "1977-5-25-matrix",
    "1981-1-20-matrix",
    "1983-9-1-matrix",
    "1986-4-26-matrix",
    "1989-11-9-matrix",
    "1991-8-6-matrix",
    "1994-4-27-matrix",
    "1997-7-1-matrix",
    "1999-3-31-matrix",
    "2001-9-11-matrix",
    "2003-3-20-matrix",
    "2004-8-4-matrix",
    "2005-7-7-matrix",
    "2007-6-29-matrix",
    "2008-9-15-matrix",
    "2009-1-15-matrix",
    "2010-4-20-matrix",
    "2011-3-11-matrix",
    "2012-7-20-matrix",
    "2013-4-15-matrix",
    "2014-6-5-matrix",
    "2015-11-13-matrix",
    "2016-6-12-matrix",
    "2017-8-21-matrix",
    "2018-3-14-matrix",
    "2019-4-15-matrix",
    "2020-1-26-matrix",
    "2020-3-11-matrix",
    "2021-1-6-matrix",
    "2021-8-30-matrix",
    "2022-2-24-matrix",
    "2022-9-8-matrix",
    "2023-1-30-matrix",
    "2023-4-4-matrix",
    "2023-7-8-matrix",
    "2023-9-22-matrix",
    "2024-2-29-matrix",
    "2024-5-17-matrix",
    "2024-8-3-matrix",
    "2024-11-5-matrix",
    "2025-1-1-matrix",
}

local spoofed_platforms = {
    "Adopt Me!",
    "Brookhaven RP",
    "Blox Fruits",
    "Pet Simulator X",
    "Murder Mystery 2",
    "Royale High",
    "Tower of Hell",
    "Arsenal",
    "Jailbreak",
    "Piggy",
    "Natural Disaster Survival",
    "Work at a Pizza Place",
    "Flee the Facility",
    "Phantom Forces",
    "Shindo Life",
    "Anime Fighting Simulator",
    "Bedwars",
    "Doors",
    "Brookhaven",
    "Anime Dimensions",
    "Skywars",
    "Funky Friday",
    "Dragon Ball Z Final Stand",
    "Ro-Ghoul",
    "Islands",
    "Anime Battle Arena",
    "Build a Boat for Treasure",
    "The Mimic",
    "Livetopia",
    "Starving Artists",
    "A Universal Time",
    "Creatures of Sonaria",
    "My Hello Kitty Cafe",
    "Wacky Wizards",
    "Dress to Impress",
    "Frontlines",
    "Sword Burst 2",
    "Super Golf",
    "Mad City",
    "Theme Park Tycoon 2",
    "Car Dealership Tycoon",
    "MeepCity",
    "Ragdoll Engine",
    "Obby But Youre On A Bike",
    "Saber Simulator",
    "Dungeon Quest",
    "Epic Minigames",
    "Weight Lifting Simulator",
    "Scuba Diving at Quill Lake",
    "Survive the Killer",
}

local function isVerified()
    if not isfile then return false end
    if not isfile(verify_file) then return false end
    local content = readfile(verify_file)
    return type(content) == "string" and content:lower():find("true") ~= nil
end

local function setVerified()
    if In_Studio then return true end
    if typeof(writefile) ~= "function" or type(verify_file) ~= "string" then return false end
    local ok = pcall(writefile, verify_file, "true")
    return ok
end

local function waitForGuiGone()
    local container = CoreGui
    if In_Studio then
        container = player_gui or speaker:FindFirstChildOfClass("PlayerGui")
        if not container or not container:IsA("PlayerGui") then return end
    end
    wait(0.1)
    while true do
        local ok, found = pcall(function() return container:FindFirstChild("MemoryMinigameGUI") end)
        if not ok or not found then break end
        task.wait()
    end
end

g.disabled_global_value_correctly = g.disabled_global_value_correctly or function(input)
    local ok, result = pcall(function() return input end)
    if not ok then return true end
    return not result
end

g.LifeTogether_Actual_Flames_Hub_Running_Functioning_Currently_On_Client = true
local userid = localPlayer.UserId
local lib = g.FlamesLibrary
g.lib = g.FlamesLibrary -- necessary for some reason.
local lib_attempts = 0
local lib_max_attempts = 15
while (not lib or type(lib) ~= "table") and lib_attempts < lib_max_attempts do
    task.wait(0.5)
    lib_attempts = lib_attempts + 1
    lib = g.FlamesLibrary
end

if not lib or type(lib) ~= "table" then
    if g.notify and typeof(g.notify) == "function" then g.notify("Error", "FlamesLibrary failed to load, the system cannot continue without it.", 15) else warn("FlamesLibrary failed to load, the system cannot continue without it.") end
    return
end

local function mask_unique_id(id)
    if not id then return nil end
    local parts = string.split(id, "-")
    local out = {}
    for i = 1, #parts do
        if i <= 2 then
            out[i] = parts[i]
        else
            out[i] = string.rep("*", #parts[i])
        end
    end
    return table.concat(out, "-")
end

function create_flames_hub_unique_id(target_user_id)
    local file_name = "flames_hub_unique_ID.txt"
    if userid ~= target_user_id then return nil end
    if In_Studio then
        g.flames_hub_unique_id = g.flames_hub_unique_id or HttpService:GenerateGUID(false)
        return g.flames_hub_unique_id
    end

    if isfile and readfile and typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(file_name) then
        local ok, id = pcall(readfile, file_name)
        if ok and id and id ~= "" then return id end
    end

    local new_id = HttpService:GenerateGUID(false)
    if writefile and typeof(writefile) == "function" then pcall(writefile, file_name, new_id) end
    return new_id
end

function get_flames_hub_unique_id()
    local file_name = "flames_hub_unique_ID.txt"
    if isfile and isfile(file_name) then
        local id = readfile and readfile(file_name)
        if id and id ~= "" then return id end
    end
    return nil
end

function get_masked_flames_hub_unique_id()
    local raw = get_flames_hub_unique_id()
    return mask_unique_id(raw)
end

local FlamesLibrary = g.lib or g.FlamesLibrary
--local ws_connect = (syn and syn.websocket and syn.websocket.connect) or (WebSocket and WebSocket.connect) or (websocket and websocket.connect)
--local http_req = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
g.will_tag = function(text)
    local max_attempts = 5
    for attempt = 1, max_attempts do
        local ok, filtered = pcall(function() return Chat:FilterStringForBroadcast(text, g.LocalPlayer) end)
        if not ok then return true end
        if type(filtered) == "string" and not filtered:match("^#+$") then return filtered ~= text end
        task.wait(0.5)
    end

    return true
end

g.chat_shield_enabled = g.chat_shield_enabled or false
g.chat_shield_active = g.chat_shield_active or false
g.toggle_chat_shield = function(force)
    if force ~= nil then
        g.chat_shield_enabled = force
    else
        g.chat_shield_enabled = not g.chat_shield_enabled
    end

    if not g.chat_shield_enabled then
        g.chat_shield_active = false
        FlamesLibrary.disconnect("chat_shield_loop")
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
        g.notify("Success", "Yadsan Hub | HashTag Protection disabled.", 3)
        return
    end

    FlamesLibrary.spawn("chat_shield_loop", "defer", function()
        while g.chat_shield_enabled do
            local ok, filtered = pcall(function() return Chat:FilterStringForBroadcast("hello", speaker) end)
            local is_hashing = not ok or type(filtered) ~= "string" or filtered:match("^#+$")
            if is_hashing and not g.chat_shield_active then
                g.chat_shield_active = true
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
                g.notify("Warning", "HASHTAG PROTECTION HAS BEEN ENABLED! HASHTAGS (#) DETECTED IN YOUR FILTER (AUTOMATIC), THIS MEANS YOU'RE GETTING AUTOMATICALLY FILTERED (#) FOR NO REASON BY ROBLOX, WE'VE SAVED YOU.", 20)
            elseif not is_hashing and g.chat_shield_active then
                g.chat_shield_active = false
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
                g.notify("Success", "Yadsan Hub | Shield going idle. No hashtags have been detected in your filter.", 7)
            end
            task.wait(0.5)
        end
    end)
end

--if not g.chat_shield_enabled then g.toggle_chat_shield(true) end
create_flames_hub_unique_id(Players.LocalPlayer.UserId)
wait(0.3)
--local flames_unique_server_ID = get_flames_hub_unique_id()
local masked_flames_hub_server_ID = get_masked_flames_hub_unique_id()
local Lib = g.FlamesLibrary
g.masked_flames_hub_server_ID = masked_flames_hub_server_ID
wait(0.1)
if not isVerified() then
    if g.notify then g.notify("Warning", "Please complete this one time verification to boot into Yadsan Hub | Script Hub!", 30) end
    g.Memory_Mini_Game_GUI()
    waitForGuiGone()
    setVerified()
    if g.notify then
        g.notify("Success", "You have been verified in Yadsan Hub successfully.", 15)
        g.notify("Success", "Your special MonK Hub GUID: "..tostring(masked_flames_hub_server_ID), 11)
    end
else
    if g.notify then g.notify("Success", "We have verified you in our system | has already completed verification.", 20) end
    if g.notify then g.notify("Success", "Your special Yadsan Hub GUID: "..tostring(masked_flames_hub_server_ID), 10) end
end
wait(0.1)
g.safe_wrapper = g.safe_wrapper or function(service)
    if cloneref then
        return cloneref(game:GetService(service))
    else
        return game:GetService(service)
    end
end

--local replicate_sig_func = replicatesignal or replicate_signal or DeltaSignal
--local set_hid_func = sethiddenproperty or set_hidden_property or set_hidden_prop or sethiddenprop
g.originalIO = g.originalIO or {}
g.spectateConns = g.spectateConns or {}
local fw = lib.wait
--local name = "administrator_watcher_conn_Flames_Hub"
g.originalIO.ensureCam = function(spectate_target)
    if not spectate_target then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if g.isProperty(cam, "CameraSubject") == nil then return end
    if cam.CameraSubject ~= spectate_target then g.setProperty(cam, "CameraSubject", spectate_target) end
end

g.originalIO.hookCameraGuard = function(spectate_target)
    if not workspace then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if g.spectateConns.cam then
        g.spectateConns.cam:Disconnect()
        g.spectateConns.cam = nil
    end
    wait(0.25)
    if g.isProperty(cam, "CameraSubject") ~= nil then
        g.spectateConns.cam = g.FlamesLibrary.connect("spectate_cam", cam:GetPropertyChangedSignal("CameraSubject"):Connect(function()
            if not spectate_target then return end
            g.originalIO.ensureCam()
        end))
    end

    if not g.spectateConns.camW and g.isProperty(workspace, "CurrentCamera") ~= nil then
        g.spectateConns.camW = g.FlamesLibrary.connect("spectate_camW", workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if not spectate_target then return end
            g.originalIO.hookCameraGuard()
            g.originalIO.ensureCam()
        end))
    end
end

g.originalIO.captureIO = function(name)
    local fn
    if rawget and typeof(rawget) == "function" then fn = rawget(_G, name) end
    if type(fn) ~= "function" then fn = _G[name] end
    if type(fn) == "function" then g.originalIO[name] = fn end
end
wait(0.15)
if not g.originalIO.__captured then
    g.originalIO.__captured = true
    g.originalIO.captureIO('readfile')
    g.originalIO.captureIO('writefile')
    g.originalIO.captureIO('appendfile')
    g.originalIO.captureIO('listfiles')
    g.originalIO.captureIO('makefolder')
    g.originalIO.captureIO('delfile')
    g.originalIO.captureIO('delfolder')
    g.originalIO.captureIO('isfile')
    g.originalIO.captureIO('isfolder')
end

g.originalIO.pathVariants = function(path)
    if type(path) ~= "string" then return { path } end
    if path:match('^[%w_]+://') then return { path } end
    local variants, seen = {}, {}
    local function add(value)
        if type(value) == "string" and value ~= "" and not seen[value] then
            seen[value] = true
            Insert(variants, value)
        end
    end
    add(path)
    add((path:gsub('\\+', '\\')))
    add((path:gsub('//+', '/')))
    add((path:gsub('/', '\\')))
    add((path:gsub('\\', '/')))
    local trimmed = path:gsub('^%.[/\\]+', '')
    if trimmed ~= path then
        add(trimmed)
        add(trimmed:gsub('/', '\\'))
        add(trimmed:gsub('\\', '/'))
    end
    return variants
end

g.originalIO.resolveWithListfiles = function(target)
    local lf = g.originalIO.listfiles
    if type(lf) ~= "function" then
        return nil
    end
    local dir, filename = target:match('^(.*)[/\\]([^/\\]+)$')
    if not dir or filename == '' then
        return nil
    end
    local dirVariants = g.originalIO.pathVariants(dir)
    local results = {}
    local lowered = filename:lower()
    for _, candidateDir in ipairs(dirVariants) do
        local ok, entries = pcall(lf, candidateDir)
        if ok and type(entries) == "table" then
            for _, entry in ipairs(entries) do
                local name = entry:match('([^/\\]+)$')
                if name and name:lower() == lowered then
                    Insert(results, entry)
                end
            end
        end
    end
    if #results > 0 then
        return results
    end
    return nil
end

g.input_to_String = g.input_to_String or function(input_value) return typeof(input_value) == "string" and input_value or tostring(input_value) end
if g.notify and typeof(g.notify) == "function" then g.notify("Info", "Booting up Life Together RP Hub, please wait a few moments while we initialize everything...", 8) end
g.service_cache = g.service_cache or {}
g.Sound_ID_Windows = g.Sound_ID_Windows or "rbxassetid://8183296024"
g.Sound_ID_iPhone = g.Sound_ID_iPhone or "rbxassetid://73722479618078"
g.Sound_ID_Android = g.Sound_ID_Android or "rbxassetid://17582299860"
g.Sound_ID_Universal = g.Sound_ID_Universal or "rbxassetid://18595195017"
local aliases = {
    rs = "ReplicatedStorage",
    rf = "ReplicatedFirst",
    ws = "Workspace",
    works = "Workspace",
    player = "Players",
    plr = "Players",
    plrs = "Players",
    ts = "TweenService",
    uis = "UserInputService"
}

local virtuals = {
    lp = true,
    localplayer = true,
    localplr = true
}

local function resolve_service(input)
    if not input then return nil end
    local lowered = tostring(input):lower()
    if aliases[lowered] then return aliases[lowered] end
    local children = game:GetChildren()

    for _, svc in ipairs(children) do
        if svc.Name:lower() == lowered then
            return svc.Name
        end
    end

    for _, svc in ipairs(children) do
        if svc.Name:lower():find(lowered, 1, true) then
            return svc.Name
        end
    end

    local best_name
    local best_score = math.huge

    for _, svc in ipairs(children) do
        local score = g.levenshtein(lowered, svc.Name:lower())
        if score < best_score then
            best_score = score
            best_name = svc.Name
        end
    end

    if best_score <= 4 then
        return best_name
    end

    return nil
end

local function fetch_value(name)
    if not name then return nil end
    local lowered = tostring(name):lower()
    if virtuals[lowered] then
        local ok, speaker = pcall(function()
            local Players = g.service_cache["Players"] or (Players)
            return Players.LocalPlayer
        end)
        if not ok or not speaker then return nil end
        return lowered, speaker
    end

    local resolved = resolve_service(name)
    if not resolved then return nil end
    local ok, svc = pcall(function()
        local service = game:GetService(resolved)
        if cloneref and typeof(cloneref) == "function" then return cloneref(service) end
        return service
    end)
    if not ok or not svc then return nil end
    return resolved, svc
end

-- [[ Ultra proper checking my friends. ]] --
if setmetatable and getmetatable and rawget and rawset and typeof(setmetatable) == "function" and typeof(getmetatable) == "function" and typeof(rawget) == "function" and typeof(rawset) == "function" then
    if not getmetatable(g.service_cache) then
        setmetatable(g.service_cache, {
            __index = function(self, key)
                local existing = rawget(self, key)
                if existing then return existing end
                local resolved_key, value = fetch_value(key)
                if not value then return nil end
                rawset(self, key, value)
                if resolved_key and resolved_key ~= key then rawset(self, resolved_key, value) end
                return value
            end
        })
    end

    g.safe_wrapper = function(name)
        if not name then return nil end
        return g.service_cache[name]
    end
else
    g.safe_wrapper = function(name)
        if not name then return nil end
        if g.service_cache[name] then return g.service_cache[name] end
        local resolved_key, value = fetch_value(name)
        if not value then return nil end
        g.service_cache[name] = value
        if resolved_key and resolved_key ~= name then g.service_cache[resolved_key] = value end
        return value
    end
end
wait(0.2)
g.type = typeof or type
g.string_contains_plain = g.string_contains_plain or function(source, needle)
    if typeof(source) ~= "string" or typeof(needle) ~= "string" then return false end
    return source:lower():find(needle:lower(), 1, true) ~= nil
end

g.load_youtube_music_player_func = g.load_youtube_music_player_func or function()
    if g.You_Tube_Music_Player_Loaded then return g.notify("Warning", "YouTube Music Player is already loaded.", 5) end
    g.You_Tube_Music_Player_Loaded = true
    loadstring(g.http_get("https://raw.githubusercontent.com/Dan41/Roblox-Scripts/refs/heads/main/Youtube%20Music%20Player/YoutubeMusicPlayer.lua"))()
    local asset_id = "76673896881913"
    local target_image = "rbxassetid://" .. asset_id
    task.spawn(function()
        local screen_gui
        repeat
            task.wait(0.1)
            for _, v in ipairs(CoreGui:GetChildren()) do
                if v:IsA("ScreenGui") then
                    for _, child in ipairs(v:GetDescendants()) do
                        if child:IsA("ImageButton") and child.Image == target_image then
                            screen_gui = v
                            break
                        end
                    end
                end
                if screen_gui then break end
            end
        until screen_gui

        local target_button
        for _, child in ipairs(screen_gui:GetDescendants()) do
            if child:IsA("ImageButton") and child.Image == target_image then
                target_button = child
                break
            end
        end

        if not target_button then return end

        local target_frame
        for _, child in ipairs(screen_gui:GetDescendants()) do
            if child:IsA("Frame") then
                local size = child.AbsoluteSize
                if math.abs(size.X - 587) < 1 and math.abs(size.Y - 300) < 1 then
                    target_frame = child
                    break
                end
            end
        end

        if target_frame then
            target_frame.Draggable = true
        end
        return
    end)
    return
end

if g.notify then g.notify("Info", "One moment, we're initializing basic services...", 5) end
local executor_string = nil
local function executor_contains(substr)
    if type(executor_string) ~= "string" then
        return false
    end
    return string.find(string.lower(executor_string), string.lower(substr), 1, true) ~= nil
end

local function retrieve_executor()
    local name
    if identifyexecutor then
        name = identifyexecutor()
    end
    return { Name = name or "Unknown Executor" }
end

local function identify_executor()
    local executorinfo = retrieve_executor()
    return tostring(executorinfo.Name)
end

executor_string = identify_executor()
function low_level_executor()
    if executor_contains("solara") then return true end
    if executor_contains("jjsploit") then return true end
    if executor_contains("xeno") then return true end
    return false
end
wait(0.1)
local are_we_low_level = low_level_executor()
if are_we_low_level == true then g.notify("Error", "Your executor cannot run this script, it requires a better executor like: Potassium, Volt, Wave, Delta etc, we apologize!", 60); return end

g.randomString = g.randomString or function()
    local length = math.random(10,20)
    local array = {}
    for i = 1, length do array[i] = string.char(math.random(32, 126)) end
    return table.concat(array)
end

g.blankfunction = g.blankfunction or function(...) return ... end
if g.LifeTogether_RP_ScriptHub_Loaded then
    if g.notify then
        return g.notify("Warning", "Life Together RP Hub has already been loaded.", 8)
    else
        return 
    end
end

if g.LifeTogetherRP_Admin and g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub == false then
    if g.notify then
        return g.notify("Warning", "Life Together RP admin has already been loaded.", 6)
    else
        return 
    end
elseif g.LifeTogetherRP_Admin and g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub then
    return 
end

if g.notify and typeof(g.notify) == "function" then g.notify("Info", "Now checking for Yadsan Hub files...", 5) end
g.ConstantUpdate_Checker_Live = true
if isfile and not isfile("flames_hub_agreement_COPY.txt") then
    pcall(function()
        writefile("flames_hub_agreement_COPY.txt", "has not decided")
    end)
end

if isfile and typeof(isfile) == "function" and not isfile("LifeTogether_RP_Admin_Custom_Name.txt") then
    pcall(function()
        writefile("LifeTogether_RP_Admin_Custom_Name.txt", speaker.DisplayName)
    end)
end

wait(0.1)
if isfile and typeof(isfile) == "function" and not isfile("LifeTogether_RP_Admin_Custom_Bio.txt") then
    pcall(function()
        writefile("LifeTogether_RP_Admin_Custom_Bio.txt", " Yadsan Hub ")
    end)
end

if not g.dragify then
    do
        local active_frame     = nil
        local active_drag_start = nil
        local active_start_pos  = nil
        local last_input_pos    = nil
        local active_tween      = nil
        local GLOBAL_KEY = "dragify_global"
        local TWEEN_INFO = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
        local MIN_DELTA  = 2
        local function cancel_tween()
            if active_tween then
                pcall(function() active_tween:Cancel() end)
                active_tween = nil
            end
        end

        local function stop_drag()
            active_frame      = nil
            active_drag_start = nil
            active_start_pos  = nil
            last_input_pos    = nil
            cancel_tween()
        end

        local function frame_valid(f)
            local ok, res = pcall(function()
                return f and f.Parent and f:IsDescendantOf(game)
            end)
            return ok and res
        end

        g.FlamesLibrary.connect(GLOBAL_KEY .. "_heartbeat", rs.Heartbeat:Connect(function()
            if not active_frame or not last_input_pos then return end
            if not frame_valid(active_frame) then
                stop_drag()
                return
            end

            local delta = last_input_pos - active_drag_start
            if delta.Magnitude < MIN_DELTA then return end
            local sp  = active_start_pos
            local pos = UDim2.new(
                sp.X.Scale,
                sp.X.Offset + delta.X,
                sp.Y.Scale,
                sp.Y.Offset + delta.Y
            )

            cancel_tween()
            active_tween = ts:Create(active_frame, TWEEN_INFO, { Position = pos })
            active_tween:Play()
        end))

        g.FlamesLibrary.connect(GLOBAL_KEY .. "_changed", uis.InputChanged:Connect(function(input)
            if not active_frame then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
                last_input_pos = input.Position
            end
        end))

        g.FlamesLibrary.connect(GLOBAL_KEY .. "_ended", uis.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                stop_drag()
            end
        end))

        g.dragify = function(frame)
            if not frame then return end
            task.spawn(function()
                local waited = 0
                while not frame_valid(frame) do
                    task.wait(0.1)
                    waited = waited + 0.1
                    if waited >= 10 then return end
                end

                local frame_key = "dragify_" .. tostring(frame:GetDebugId())
                g.FlamesLibrary.connect(frame_key .. "_began", frame.InputBegan:Connect(function(input)
                    if not frame_valid(frame) then return end
                    if uis:GetFocusedTextBox() then return end
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if active_frame and active_frame ~= frame then
                            stop_drag()
                        end
                        active_frame      = frame
                        active_drag_start = input.Position
                        active_start_pos  = frame.Position
                        last_input_pos    = input.Position
                    end
                end))

                g.FlamesLibrary.connect(frame_key .. "_ancestry", frame.AncestryChanged:Connect(function(_, parent)
                    if not parent then
                        if active_frame == frame then stop_drag() end
                        g.FlamesLibrary.disconnect(frame_key .. "_began")
                        g.FlamesLibrary.disconnect(frame_key .. "_ancestry")
                    end
                end))
            end)
        end
    end
end

local http_requesting = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
g.http_requesting = g.http_requesting or http_requesting
local function normalize_response(res)
   local status = res.StatusCode or res.statusCode or res.status or res.Status
   local body = res.Body or res.body or res.Response or res.response or ""
   return status, body
end

g.try_load = g.try_load or function(urls)
    for i = 1, #urls do
        local url = urls[i]
        local ok, res = pcall(function()
            return http_requesting({ Url = url, Method = "GET" })
        end)

        if ok and res then
            local status, body = normalize_response(res)
            if status == 200 and body ~= "" and not tostring(body):find("404: Not Found") then
                local f, err = loadstring(body)
                if f then
                    local s_ok, s_res = pcall(f)
                    if s_ok then
                        return s_res
                    else
                        return { failed = true, status = "load-error", url = url, body = tostring(s_res) }
                    end
                else
                    return { failed = true, status = "compile-error", url = url, body = tostring(err) }
                end
            end
        end
    end
    return { failed = true, status = "no-response", url = urls[#urls] }
end

local GITHUB   = "https://raw.githubusercontent.com/EnterpriseExperience/Flames_Hub_Games/main/"
local GITLAB   = "https://gitlab.com/flames2431233/Starter/-/raw/main/"
local CODEBERG = "https://codeberg.org/talkinboutlol/FlamesHub/raw/branch/main/"
local function mirror(path, paste_a, paste_b)
    return {
        GITHUB   .. path,
        GITLAB   .. path .. "?ref_type=heads",
        CODEBERG .. path,
        paste_a,
        paste_b,
    }
end

-- [[ you can use these, or you can modify the source code from each one and upload it to your own GitHub. ]] --
local github_urls = {
    GlobalEnv_Framework = {
        "https://raw.githubusercontent.com/yadsanpapa/Yadsan-/refs/heads/main/Global_Environment.txt"
    },
    Functions_API_LifeTogether = {
        "https://gitlab.com/flames2431233/Starter/-/raw/main/Life_Together_Framework/Life_Together_Functions_API.lua?ref_type=heads"
    },
    Life_Together_Network = {
        "https://gitlab.com/flames2431233/Starter/-/raw/main/Life_Together_Framework/Life_Together_Network.lua?ref_type=heads"
    },
}

-- [[ you can use these, or you can change them into your own if you want, but if GitHub goes down, they'll work for you, unless somehow GitHub, Pastebin AND Pastefy are down. ]] --
local fallback_urls = {
    GlobalEnv_Framework = mirror(
        "Assets/Global_Environment.lua",
        "https://pastebin.com/raw/T25mDhBZ",
        "https://pastefy.app/MAylpl1S/raw"
    ),
    Functions_API_LifeTogether = mirror(
        "Life_Together_Framework/Life_Together_Functions_API.lua",
        "https://pastebin.com/raw/ksfZM2C4",
        "https://pastefy.app/kQzNQxn0/raw"
    ),
    Life_Together_Network = mirror(
        "Life_Together_Framework/Life_Together_Network.lua",
        "https://pastebin.com/raw/GiEmv8Qf",
        "https://pastefy.app/FT5eU1HK/raw"
    ),
    LifeTogether_Anti_Staff = mirror(
        "Life_Together_Framework/LifeTogether_Anti_Staff.lua",
        "https://pastebin.com/raw/UiQfWWwY",
        "https://pastefy.app/Se7QQ0KH/raw"
    ),
    Vehicle_Mapper = mirror(
        "Extra/Vehicle_Mapper.lua",
        "https://pastebin.com/raw/PqLNjqSs",
        "https://pastefy.app/BuZybou2/raw"
    ),
    LifeTogether_Framework_Base_1 = mirror(
        "Life_Together_Framework/LifeTogether_Framework_Base_1.lua",
        "https://pastebin.com/raw/Pq9cUCXi",
        "https://pastefy.app/UgnGF0pZ/raw"
    ),
    LifeTogether_Framework_Base_2 = mirror(
        "Life_Together_Framework/LifeTogether_Framework_Base_2.lua",
        "https://pastebin.com/raw/KR05npwT",
        "https://pastefy.app/sjjbUhBl/raw"
    ),
    Life_Together_Admin = mirror(
        "Life_Together_Framework/Life_Together_Admin.lua",
        "https://pastebin.com/raw/azPSzEjH",
        "https://pastefy.app/SiDMhe47/raw"
    ),
    grab_file_performance = mirror(
        "Assets/grab_file_performance.lua",
        "https://pastebin.com/raw/DuG2RmjF",
        "https://pastefy.app/nq0BT17K/raw"
    ),
    Configuration_API = mirror(
        "Assets/Configuration_API.lua",
        "https://pastebin.com/raw/9qkZEvjw",
        "https://pastefy.app/JPSCgeB4/raw"
    )
}

g.get_script_text = g.get_script_text or function(name)
    local gh = github_urls[name] or {}
    local fb = fallback_urls[name] or {}

    for i = 1, #gh do
        local res = http_requesting({ Url = gh[i], Method = "GET" })
        if res and res.StatusCode == 200 and res.Body ~= "" then
            return res.Body
        end
    end

    for i = 1, #fb do
        local res = http_requesting({ Url = fb[i], Method = "GET" })
        if res and res.StatusCode == 200 and res.Body ~= "" then
            return res.Body
        end
    end

    return ""
end

g.load_script = g.load_script or function(name)
    local github_list = github_urls[name] or {}
    local fallback_list = fallback_urls[name] or {}
    local result = g.try_load(github_list)
    if type(result) == "table" and result.failed then result = g.try_load(fallback_list) end
    return result
end

g.pick_script = g.pick_script or function(name)
    local gh = github_urls[name] or {}
    local fb = fallback_urls[name] or {}
    local r = g.try_load(gh)
    if type(r) == "table" and r.failed then r = g.try_load(fb) end
    if type(r) == "table" and r.failed then
        g[name] = nil
        return nil
    end
    g[name] = r
    return r
end

local allowed = {
    ["Yadsan_Godverse"] = true,
    ["AGKaBaap_YadsanAsuka"] = true,
    ["imjustbeter100"] = true,
    ["L0CKED_1N1"] = true,
    ["imbetter100062"] = true,
    ["jdot7580"] = true,
    ["ddosama136703"] = true,
    ["AuraWithClipFarmin"] = true,
    ["ActuallyMasterInIt"] = true
}
local title_allowed_list_tbl = {
    ["Yadsan_Godverse"] = "Owner",
    ["AGKaBaap_YadsanAsuka"] = "Owner",
    ["imjustbeter100"] = "Staff",
    ["L0CKED_1N1"] = "Owner",
    ["imbetter100062"] = "Staff",
    ["jdot7580"] = "Staff",
    ["ddosama136703"] = "Staff",
    ["AuraWithClipFarmin"] = "Owner",
    ["ActuallyMasterInIt"] = "Staff"
}
local GlobalEnv_Framework = g.load_script("GlobalEnv_Framework")
local Life_Together_Network = g.load_script("Life_Together_Network")
local Functions_API_LifeTogether = g.load_script("Functions_API_LifeTogether")
local TextChatService_MessageConnection = g.load_script("TextChatService_MessageConnection")
local LifeTogether_Anti_Staff = g.load_script("LifeTogether_Anti_Staff")
local TextChatService_Unsuspension_Framework = g.load_script("TextChatService_Unsuspension_Framework")
local Vehicle_Mapper = g.load_script("Vehicle_Mapper")
local LifeTogether_Framework_Base_1 = g.load_script("LifeTogether_Framework_Base_1")
local LifeTogether_Framework_Base_2 = g.load_script("LifeTogether_Framework_Base_2")
local Dex_Explorer_Checker = g.load_script("Dex_Explorer_Checker")
g.LifeTogetherRP_Admin = true
g.make_round = g.make_round or function(obj, radius)
    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, radius)
    uic.Parent = obj
end

if type(GlobalEnv_Framework) == "function" then GlobalEnv_Framework() end
if not g.notify then repeat task.wait() until g.notify end
if type(Life_Together_Network) == "function" then Life_Together_Network() end
if type(Functions_API_LifeTogether) == "function" then Functions_API_LifeTogether() end
if type(TextChatService_MessageConnection) == "function" then TextChatService_MessageConnection() end
if type(LifeTogether_Anti_Staff) == "function" then LifeTogether_Anti_Staff() end
if type(TextChatService_Unsuspension_Framework) == "function" then TextChatService_Unsuspension_Framework() end
if type(Vehicle_Mapper) == "function" then Vehicle_Mapper() end
if type(LifeTogether_Framework_Base_1) == "function" then LifeTogether_Framework_Base_1() end
if type(LifeTogether_Framework_Base_2) == "function" then LifeTogether_Framework_Base_2() end
if type(Dex_Explorer_Checker) == "function" then Dex_Explorer_Checker() end
if g.ConstantUpdate_Checker_Live then g.notify("Success", "Enabled/Re-Enabled LIVE update checker.", 5) end
g.all_saved_Life_Together_RP_Outfit_IDs = {}
g.get_all_current_outfits_and_their_IDs = function()
    local Data = require(ReplicatedStorage:FindFirstChild("Data", true))
    if typeof(Data) ~= "table" then return end
    local Outfits = Data.outfits
    if typeof(Outfits) ~= "table" then return end

    for i, outfit in pairs(Outfits) do
        if outfit.id then
            table.insert(g.all_saved_Life_Together_RP_Outfit_IDs, outfit.id)
        end
    end

    return g.all_saved_Life_Together_RP_Outfit_IDs
end

g.find_nba_props_map_folder = function()
    local cache = g.nba_props_kept_folder_inst
    if cache and cache:IsA("Folder") then return cache end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Folder") and v.Name:lower():find("map") and v.Name:lower():find("props") and v.Parent.Name:lower():find("nba") then
            g.nba_props_kept_folder_inst = v
            return v
        end
    end

    return nil
end

g.collect_all_nba_props = function()
    local char = g.Character or g.LocalPlayer.Character or g.get_char(LocalPlayer, 10) or g.Char and g.Char:get()
    if not char then return end
    local attr = g.LocalPlayer:GetAttribute("NBA_HUNT_PROGRESS")
    if not attr then return end
    local folder = g.nba_props_kept_folder_inst or g.find_nba_props_map_folder()
    if not folder then return end
    if char and attr == "PLAYING" then
        for _, v in ipairs(folder:GetChildren()) do
            if g.LocalPlayer:GetAttribute("NBA_HUNT_PROGRESS") ~= "PLAYING" then break end
            if v:IsA("Model") then
                char:PivotTo(v:GetPivot() + Vector3.new(0, 2.5, 0))
                task.wait(0.35)
            end
        end
    end
end

local parent_gui = (get_hidden_gui and get_hidden_gui()) or (gethui and gethui()) or g.CoreGui or g.PlayerGui
g.find_delta_icon_image_button = g.find_delta_icon_image_button or function()
    local cached = g.deltas_icon_image_button_descendant_flames_hub_value
    if cached and cached:IsA("ImageButton") and cached.Parent then return cached end
    for _, v in ipairs(parent_gui:GetDescendants()) do
        if v:IsA("ImageButton")
            and v.Size == UDim2.new(0,45,0,45)
            and v.ZIndex == 1
            and v.AutoButtonColor
            and v.Image ~= ""
            and v.ImageColor3 == Color3.fromRGB(255,255,255)
            and v.BackgroundColor3 == Color3.fromRGB(48,50,59)
            and v.BorderColor3 == Color3.fromRGB(27,42,53)
        then
            g.deltas_icon_image_button_descendant_flames_hub_value = v
            return v
        end
    end

    return nil
end

g.toggle_delta_image_button_flames_hub = g.toggle_delta_image_button_flames_hub or function(state)
    if typeof(state) ~= "boolean" then return end
    if not executor_contains("delta") then g.notify("Error", "You're not using Delta, this feature will not work for you.", 7); return end
    local btn = g.find_delta_icon_image_button()
    if btn and btn:IsA("ImageButton") then
        g.Is_Deltas_Icon_Currently_Toggled = state
        btn.Visible = state
    end
end

g.levenshtein = g.levenshtein or function(s, t)
    if s == t then return 0 end
    local len_s, len_t = #s, #t
    if len_s == 0 then return len_t end
    if len_t == 0 then return len_s end
    local d = {}
    for i = 0, len_s do d[i] = {[0] = i} end
    for j = 0, len_t do d[0][j] = j end
    for i = 1, len_s do
        for j = 1, len_t do
            local cost = (s:sub(i,i) == t:sub(j,j)) and 0 or 1
            d[i][j] = math.min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + cost)
        end
    end
    return d[len_s][len_t]
end

g.ToUserId = function(x)
    if typeof(x) == "number" then
        return x
    elseif typeof(x) == "string" then
        local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(x) end)
        return ok and uid or nil
    elseif typeof(x) == "Instance" and x:IsA("Player") then
        return x.UserId
    end
    return nil
end

g.GetUserId = g.GetUserId or function(target)
    if typeof(target) == "Instance" then
        if target:IsA("Player") then return target.UserId end
        local plr = Players:GetPlayerFromCharacter(target)
        if plr then return plr.UserId end
        return nil
    end

    if typeof(target) == "string" then
        local plr = Players:FindFirstChild(target)
        if plr and plr:IsA("Player") then return plr.UserId end
        return nil
    end

    if typeof(target) == "number" then return target end
    return nil
end

local function FindPlayer(query)
    if not query then
        if g.notify and typeof(g.notify) then g.notify("Error", "Something unexpected happened while trying to find: "..tostring(query), 6) end
        return nil
    end

    query = tostring(query):lower()
    local best_match = nil
    local best_score = math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        local username = plr.Name:lower()
        local display = plr.DisplayName:lower()
        local userid = tostring(plr.UserId)
        -----------------------------------------------------------
        -- [[ substring match (better score = lower position number). ]] --
        -----------------------------------------------------------
        local function substring_score(target)
            local i = target:find(query, 1, true)
            if i then -- is it good?
                return i
            end
            return nil
        end

        -----------------------------------------------------------
        -- fuzzy score (levenshtein >> (function) < distance). --
        -- lower is better, weighted worse than substring. --
        -----------------------------------------------------------
        local function fuzzy_score(target)
            return g.levenshtein(query, target) -- query the target.
        end
        -----------------------------------------------------------
        -- [[ perfect UserId match. ]] --
        -----------------------------------------------------------
        if query == userid then
            return plr
        end
        -----------------------------------------------------------
        -- [[ evaluate score layers. ]] --
        -----------------------------------------------------------
        local candidates = {
            username,
            display,
            userid
        }

        for _, target in ipairs(candidates) do
            -- substring match first. --
            local sub = substring_score(target)
            if sub and sub < best_score then
                best_score = sub
                best_match = plr
            else
                -- [[ aww man, we didn't match the substring, oh well. ]] --
                local fuzzy = fuzzy_score(target)
                if fuzzy < best_score then
                    best_score = fuzzy
                    best_match = plr
                end
            end
        end
    end

    return best_match
end

g.FindPlayer = g.FindPlayer or FindPlayer
-- [[ configuration GUI. ]] --
if not CoreGui:FindFirstChild("FlamesAdminGUI", true) then loadstring(g.http_get("https://pastebin.com/raw/9qkZEvjw"))() end
g._rgb_conns = g._rgb_conns or {}
g._rgb_global_conn = g._rgb_global_conn or nil
g.rgb_color_map = g.rgb_color_map or {
    red = Color3.fromRGB(255,0,0),
    darkred = Color3.fromRGB(139,0,0),
    green = Color3.fromRGB(0,255,0),
    darkgreen = Color3.fromRGB(0,100,0),
    lime = Color3.fromRGB(50,205,50),
    blue = Color3.fromRGB(0,0,255),
    darkblue = Color3.fromRGB(0,0,139),
    lightblue = Color3.fromRGB(173,216,230),
    skyblue = Color3.fromRGB(135,206,235),
    white = Color3.fromRGB(255,255,255),
    black = Color3.fromRGB(0,0,0),
    gray = Color3.fromRGB(128,128,128),
    lightgray = Color3.fromRGB(211,211,211),
    darkgray = Color3.fromRGB(64,64,64),
    yellow = Color3.fromRGB(255,255,0),
    gold = Color3.fromRGB(255,215,0),
    orange = Color3.fromRGB(255,165,0),
    darkorange = Color3.fromRGB(255,140,0),
    purple = Color3.fromRGB(128,0,128),
    violet = Color3.fromRGB(238,130,238),
    indigo = Color3.fromRGB(75,0,130),
    pink = Color3.fromRGB(255,105,180),
    hotpink = Color3.fromRGB(255,20,147),
    cyan = Color3.fromRGB(0,255,255),
    teal = Color3.fromRGB(0,128,128),
    brown = Color3.fromRGB(139,69,19),
    tan = Color3.fromRGB(210,180,140),
    magenta = Color3.fromRGB(255,0,255),
    coral = Color3.fromRGB(255,127,80),
    salmon = Color3.fromRGB(250,128,114)
}

g.rgb_color_index = {}
do
    local i = 1
    for name in pairs(g.rgb_color_map) do
        g.rgb_color_index[i] = name
        i = i + 1
    end
end

local function ensure_global_loop()
    if g._rgb_global_conn then return end
    local conn = rs.RenderStepped:Connect(function(dt)
        local conns = g._rgb_conns
        local any = false
        for _, data in pairs(conns) do
            if data and data.obj then
                any = true
                if not data.paused then
                    data.hue = (data.hue + (dt * data.speed)) % 1
                    data.obj.BackgroundColor3 = Color3.fromHSV(data.hue, 1, 1)
                end
            end
        end

        if not any then
            g._rgb_global_conn:Disconnect()
            g._rgb_global_conn = nil
        end
    end)

    g._rgb_global_conn = conn
end

g.flowrgb = g.flowrgb or function(name, speed, obj, toggle)
    local conns = g._rgb_conns
    if toggle == false then
        conns[name] = nil
        return
    end

    conns[name] = {
        obj = obj,
        speed = speed,
        hue = 0,
        paused = false
    }

    ensure_global_loop()
end

g.toggle_rgb = g.toggle_rgb or function(name, state) -- toggle a certain connection.
    local data = g._rgb_conns[name]
    if data then
        data.paused = state
    end
end

g.toggle_all_rgb = g.toggle_all_rgb or function(state) -- toggle all
    for _, data in pairs(g._rgb_conns) do
        if data then
            data.paused = state
        end
    end
end

g.set_rgb_color_smart = g.set_rgb_color_smart or function(name, input)
    local data = g._rgb_conns[name]
    if not data or not data.obj then return end

    local color

    if typeof(input) == "string" then
        color = g.rgb_color_map[input:lower()]
    elseif typeof(input) == "number" then
        local cname = g.rgb_color_index[input]
        if cname then color = g.rgb_color_map[cname] end
    elseif typeof(input) == "Color3" then
        color = input
    end

    if not color then
        local keys = {}
        for k in pairs(g.rgb_color_map) do keys[#keys+1] = k end
        color = g.rgb_color_map[keys[math.random(1, #keys)]]
    end

    data.obj.BackgroundColor3 = color
end

g.set_all_rgb_color_smart = g.set_all_rgb_color_smart or function(input)
    local color

    if typeof(input) == "string" then
        color = g.rgb_color_map[input:lower()]
    elseif typeof(input) == "number" then
        local cname = g.rgb_color_index[input]
        if cname then color = g.rgb_color_map[cname] end
    elseif typeof(input) == "Color3" then
        color = input
    end

    if not color then
        local keys = {}
        for k in pairs(g.rgb_color_map) do keys[#keys+1] = k end
        color = g.rgb_color_map[keys[math.random(1, #keys)]]
    end

    for _, data in pairs(g._rgb_conns) do
        if data and data.obj then
            data.obj.BackgroundColor3 = color
        end
    end
end

g.set_all_rgb_color = g.set_all_rgb_color or function(color)
    for _, data in pairs(g._rgb_conns) do
        if data and data.obj then
            data.obj.BackgroundColor3 = color
        end
    end
end

g.get_player_list = function()
    local players = Players:GetPlayers()
    local parts = {}
    for i, plr in ipairs(players) do table.insert(parts, "[" .. i .. ']: "' .. plr.Name .. '"') end
    return table.concat(parts, ", ")
end

g.is_server_full = g.is_server_full or function()
    local current = #Players:GetPlayers()
    local max = Players.MaxPlayers
    return current >= max
end

g.Device_Detector = g.Device_Detector or function()
    local platform = UserInputService:GetPlatform()
    local platform_map = {
        [Enum.Platform.Windows] = "Windows",
        [Enum.Platform.OSX] = "OSX",
        [Enum.Platform.IOS] = "iOS",
        [Enum.Platform.Android] = "Android",
        [Enum.Platform.XBoxOne] = "Xbox One (Console)",
        [Enum.Platform.PS4] = "PS4 (Console)",
        [Enum.Platform.XBox360] = "Xbox 360 (Console)",
        [Enum.Platform.WiiU] = "Wii-U (Console)",
        [Enum.Platform.NX] = "Cisco Nexus",
        [Enum.Platform.Ouya] = "Ouya (Android-Based)",
        [Enum.Platform.AndroidTV] = "Android TV",
        [Enum.Platform.Chromecast] = "Chromecast",
        [Enum.Platform.Linux] = "Linux (Desktop)",
        [Enum.Platform.SteamOS] = "Steam Client",
        [Enum.Platform.WebOS] = "Web-OS",
        [Enum.Platform.DOS] = "DOS",
        [Enum.Platform.BeOS] = "BeOS",
        [Enum.Platform.UWP] = "UWP (bruh)",
        [Enum.Platform.PS5] = "PS5 (Console)",
        [Enum.Platform.MetaOS] = "MetaOS",
        [Enum.Platform.None] = "Unknown Device"
    }
    return platform_map[platform] or "Unknown Device"
end

g.count_all_flames_hub_commands = g.count_all_flames_hub_commands or function()
    local cmds = g.cmdsString
    if type(cmds) ~= "string" then return 0 end
    local total = 0

    for line in cmds:gmatch("[^\r\n]+") do
        local cleaned = line:match("^%s*(.-)%s*$")
        if cleaned and cleaned ~= "" then
            if cleaned:find("{prefix}",1,true) then
                local valid = cleaned:match("{prefix}%S+")
                if valid then
                    total = total + 1
                end
            end
        end
    end

    return total
end

local holiday = g.getholiday() or ""
local Announcement_Message = "Added a hot-fix for Outfits Manager not properly loading all your saved outfits correctly upon closing it and re-opening it + fixed RateLimiter bypass notifying on every load."
g.displayTimeMax = 60
g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub = g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub or false
g.Script_Version_GlobalGenv = g.Script_Version -- also keep it like this so it can over-write new version properly.

if not g.Flames_Hub_Owner_Title_Animated_Initialized then
    g.Flames_Hub_Owner_Title_Animated_Initialized = true
    local title_name = "unique_title_billboard"
    local OWNER_KEY = "owner_title"
    g.activeowner_title_billboards = setmetatable({}, { __mode = "k" })
    local role_to_tag = {
        ["Owner"] = "Owner_Chat_Tag",
        ["Staff"] = "Staff_Chat_Tag",
        ["Wifey"] = "Wifey_Chat_Tag",
        ["Client"] = "Client_Chat_Tag"
    }

    local function resolve_title(player)
        local role = title_allowed_list_tbl[player.Name]
        if not role then return nil end
        local tag_key = role_to_tag[role]
        if not tag_key then return nil end
        local tags = g.Chat_UI_Table_Stuff or {}
        return tags[tag_key] or role
    end

    local function animate_label(label)
        local key = OWNER_KEY .. "_label_" .. tostring(label)
        lib.spawn(key, "spawn", function()
            local index = 1
            while label and label.Parent do
                local tween = g.TweenService:Create(
                    label,
                    TweenInfo.new(0.4, Enum.EasingStyle.Linear),
                    { TextColor3 = g.colors[index] }
                )
                tween:Play()
                tween.Completed:Wait()
                index = (index % #g.colors) + 1
            end
            lib.disconnect(key)
        end)
    end

    local function animate_float(billboard)
        local key = OWNER_KEY .. "_float_" .. tostring(billboard)
        local going_up = true
        lib.spawn(key, "spawn", function()
            while billboard and billboard.Parent do
                local goal = going_up and { StudsOffset = Vector3.new(0, 3, 0) } or { StudsOffset = Vector3.new(0, 2.5, 0) }
                local tween = g.TweenService:Create(
                    billboard,
                    TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    goal
                )
                tween:Play()
                tween.Completed:Wait()
                going_up = not going_up
            end
            lib.disconnect(key)
        end)
    end

    local function create_billboard(character, title_text)
        if not character then return end
        local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10)
        if not head then return end
        if head:FindFirstChild(title_name) then return end
        local billboard = Instance.new("BillboardGui")
        billboard.Name = title_name
        billboard.Size = UDim2.new(0, 220, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(255, 140, 0)
        stroke.Parent = frame

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -10, 1, -10)
        label.Position = UDim2.new(0, 5, 0, 5)
        label.Text = title_text
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextStrokeTransparency = 0
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Parent = frame

        animate_label(label)
        animate_float(billboard)
        g.activeowner_title_billboards[character] = billboard
    end

    local function cleanup_character(character)
        local billboard = g.activeowner_title_billboards[character]
        if billboard then
            lib.disconnect(OWNER_KEY .. "_float_" .. tostring(billboard))
            local label = billboard:FindFirstChildWhichIsA("TextLabel", true)
            if label then
                lib.disconnect(OWNER_KEY .. "_label_" .. tostring(label))
            end
            pcall(function() billboard:Destroy() end)
            g.activeowner_title_billboards[character] = nil
        end
    end

    local function watch_owners_character(player)
        local title_text = resolve_title(player)
        if not title_text then return end
        local char_key = OWNER_KEY .. "_charadded_" .. tostring(player.UserId)
        local prev_char = player.Character
        local function attach_to_head(char)
            local head = char:FindFirstChild("Head")
            if not head then return end
            if head:FindFirstChild(title_name) then return end
            create_billboard(char, title_text)
        end

        local function on_char(char)
            if prev_char then
                cleanup_character(prev_char)
            end
            prev_char = char

            lib.disconnect(char_key .. "_spawn")
            lib.spawn(char_key .. "_spawn", "spawn", function()
                if not char:IsDescendantOf(workspace) then
                    local conn
                    local done = false
                    conn = char.AncestryChanged:Connect(function()
                        done = true
                        conn:Disconnect()
                    end)
                    local timeout = 10
                    local elapsed = 0
                    while not done and elapsed < timeout do
                        task.wait(0.1)
                        elapsed += 0.1
                    end
                    if not done then return end
                end
                task.wait(0.1)
                attach_to_head(char)
            end)

            local head_watch_key = char_key .. "_headwatch"
            lib.connect(head_watch_key, char.ChildAdded:Connect(function(child)
                if child.Name == "Head" then
                    task.wait(0.1)
                    g.activeowner_title_billboards[char] = nil
                    attach_to_head(char)
                end
            end))
        end

        lib.connect(char_key, player.CharacterAdded:Connect(function(char)
            lib.disconnect(char_key .. "_headwatch")
            lib.disconnect(char_key .. "_spawn")
            on_char(char)
        end))
        if player.Character then on_char(player.Character) end
    end

    local function unwatch_player(player)
        if not title_allowed_list_tbl[player.Name] then return end
        local char_key = OWNER_KEY .. "_charadded_" .. tostring(player.UserId)
        lib.disconnect(char_key)
        lib.disconnect(char_key .. "_spawn")
        lib.disconnect(char_key .. "_headwatch")
        if player.Character then cleanup_character(player.Character) end
    end

    for _, player in ipairs(Players:GetPlayers()) do watch_owners_character(player) end
    if not g.Flames_Title_Owner_Added_And_Removing_Checks then
        g.Flames_Title_Owner_Added_And_Removing_Checks = true
        lib.connect(OWNER_KEY .. "_player_added", Players.PlayerAdded:Connect(function(player)
            lib.spawn(OWNER_KEY .. "_watch_" .. tostring(player.UserId), "spawn", function()
                watch_owners_character(player)
            end)
        end))

        lib.connect(OWNER_KEY .. "_player_removing", Players.PlayerRemoving:Connect(function(player)
            unwatch_player(player)
        end))
    end
end

--[[if not g.Flames_Hub_Client_Title_Initialized then
    g.Flames_Hub_Client_Title_Initialized = true
    local client_billboard_name = "unique_client_title_billboard"
    local CLIENT_KEY = "client_title"
    local client_whitelist = {
        ["Theoneandonlymymy75"] = true,
        ["YYY_Jayce"] = true,
        ["pay2pretty4"] = true,
        ["theyadoree_nunu07"] = true,
        ["Alexouulc"] = true,
        ["DIExBRE"] = true,
        ["D1ExBRE1"] = true,
        ["unemploymenttz"] = true,
        ["CBWxOWNERxJULIOOOO"] = true
    }

    g.active_client_title_billboards = setmetatable({}, { __mode = "k" })
    local function build_client_billboard(character)
        if not character then return end
        local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10)
        if not head then return end
        if head:FindFirstChild(client_billboard_name) then return end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = client_billboard_name
        billboard.Size = UDim2.new(0, 220, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Parent = frame

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -10, 1, -10)
        label.Position = UDim2.new(0, 5, 0, 5)
        label.Text = " Yadsan Hub | Client "
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextStrokeTransparency = 0
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Parent = frame

        g.active_client_title_billboards[character] = billboard
    end

    local function destroy_client_billboard(character)
        local billboard = g.active_client_title_billboards[character]
        if billboard then
            pcall(function() billboard:Destroy() end)
            g.active_client_title_billboards[character] = nil
        end
    end

    local function client_is_whitelisted(player) return client_whitelist[player.Name] == true end
    local function attach_client_billboard(char)
        local head = char:FindFirstChild("Head")
        if not head then return end
        if head:FindFirstChild(client_billboard_name) then return end
        build_client_billboard(char)
    end

    local function on_client_char_added(player, char, prev_char_ref)
        if prev_char_ref[1] then destroy_client_billboard(prev_char_ref[1]) end
        prev_char_ref[1] = char
        local char_key = CLIENT_KEY .. "_charadded_" .. tostring(player.UserId)
        lib.disconnect(char_key .. "_spawn")
        lib.spawn(char_key .. "_spawn", "spawn", function()
            if not char:IsDescendantOf(workspace) then
                local done = false
                local conn
                conn = char.AncestryChanged:Connect(function()
                    done = true
                    conn:Disconnect()
                end)
                local elapsed = 0
                while not done and elapsed < 10 do
                    task.wait(0.1)
                    elapsed += 0.1
                end
                if not done then return end
            end
            task.wait(0.1)
            attach_client_billboard(char)
        end)

        local head_watch_key = char_key .. "_headwatch"
        lib.connect(head_watch_key, char.ChildAdded:Connect(function(child)
            if child.Name == "Head" then
                task.wait(0.1)
                g.active_client_title_billboards[char] = nil
                attach_client_billboard(char)
            end
        end))
    end

    local function start_client_watcher(player)
        if not client_is_whitelisted(player) then return end
        local char_key = CLIENT_KEY .. "_charadded_" .. tostring(player.UserId)
        local prev_char_ref = { player.Character }
        lib.connect(char_key, player.CharacterAdded:Connect(function(char)
            lib.disconnect(char_key .. "_headwatch")
            lib.disconnect(char_key .. "_spawn")
            on_client_char_added(player, char, prev_char_ref)
        end))
        if player.Character then on_client_char_added(player, player.Character, prev_char_ref) end
    end

    local function stop_client_watcher(player)
        if not client_is_whitelisted(player) then return end
        local char_key = CLIENT_KEY .. "_charadded_" .. tostring(player.UserId)
        lib.disconnect(char_key)
        lib.disconnect(char_key .. "_spawn")
        lib.disconnect(char_key .. "_headwatch")
        if player.Character then destroy_client_billboard(player.Character) end
    end

    for _, player in ipairs(Players:GetPlayers()) do start_client_watcher(player) end
    if not g.Flames_Client_Title_Player_Checks then
        g.Flames_Client_Title_Player_Checks = true

        lib.connect(CLIENT_KEY .. "_player_added", Players.PlayerAdded:Connect(function(player)
            lib.spawn(CLIENT_KEY .. "_watch_" .. tostring(player.UserId), "spawn", function()
                start_client_watcher(player)
            end)
        end))

        lib.connect(CLIENT_KEY .. "_player_removing", Players.PlayerRemoving:Connect(function(player)
            stop_client_watcher(player)
        end))
    end
end--]]

-- [[ if someone has a bad outfit, like those fling outfits, this will detect it and destroy it. ]] --
local Local_Player = Players.LocalPlayer
g.Delete_Bad_Accessories = g.Delete_Bad_Accessories or function(Target_Char)
	for _, v in ipairs(Target_Char:GetDescendants()) do
		if v:IsA("Accessory") and v.AccessoryType == Enum.AccessoryType.Jacket and v.Name:lower():find("aura") then
			v:Destroy()
		end
	end
end

local function Setup_Player(Player)
	if Player == Local_Player then return end
	if Player.Character then
		g.Delete_Bad_Accessories(Player.Character)
	end
	Lib.connect("bad_accessories_" .. Player.UserId, Player.CharacterAdded:Connect(function(New_Char)
		if not New_Char or not New_Char.Parent then
			repeat task.wait() until New_Char and New_Char:FindFirstChild("Humanoid")
		end
		g.Delete_Bad_Accessories(New_Char)
	end))
end

for _, Player in ipairs(Players:GetPlayers()) do Setup_Player(Player) end
Lib.connect("bad_accessories_player_added", Players.PlayerAdded:Connect(Setup_Player))
Lib.connect("bad_accessories_player_removing", Players.PlayerRemoving:Connect(function(Player)
	Lib.disconnect("bad_accessories_" .. Player.UserId)
end))

g.is_streamed_in = g.is_streamed_in or function(plr)
    if not plr or not plr:IsA("Player") then return false end
    local char = plr.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return root:IsDescendantOf(workspace)
end

g.is_streamed_out_checker = g.is_streamed_out_checker or function(char)
    if not char or not char:IsA("Player") then return false end
    char = char or char.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 1)
    if not root then return false end
    if not root:IsDescendantOf(workspace) then return false end
    return true
end

g.LoadPerformanceStatsGUI = function()
    if g.performance_stats then
        g.notify("Info", "Performance Statistics GUI is already loaded.", 5)
        return
    end

    g.notify("Info", "Loading Performance Statistics GUI...", 5)

    local success, err = pcall(function()
        local src = g.get_script_text("grab_file_performance")
        if src == "" then
            g.notify("Error", "no valid source", 5)
        end
        loadstring(src)()
    end)

    if not success then
        g.notify("Error", "Failed to load Performance Statistics GUI: "..tostring(err), 8)
        return
    end

    local timeout = 10
    repeat
        task.wait(0.5)
        timeout = timeout - 0.5
    until g.performance_stats or timeout <= 0

    if g.performance_stats then
        g.notify("Success", "Loaded Performance Statistics GUI.", 5)
    else
        g.notify("Warning", "Failed to confirm Performance Statistics GUI load.", 8)
    end
end

g.fileName = "LifeTogether_Admin_Configuration.json"
g.make_stroke = g.make_stroke or function(obj, thickness, trans)
    local ui_stroke = Instance.new("UIStroke")
    ui_stroke.Thickness = tonumber(thickness) or 1
    ui_stroke.Transparency = tonumber(trans) or 0.3
    ui_stroke.Parent = obj
end

g.find_module_s = function(module_name)
    if not module_name then return nil end
    local base = g.Modules or g.ReplicatedStorage:FindFirstChild("Modules", true)
    local Modules = require(base)
    local Module_Found = Modules[module_name:lower()]
    return Module_Found or nil
end

g.NightVisionEnabled = g.NightVisionEnabled or false
g.ensureColorCorrection = function(name, props)
    local effect = g.Lighting:FindFirstChild(name)
    if not effect then
        effect = Instance.new("ColorCorrectionEffect")
        effect.Name = name
        effect.Parent = g.Lighting or cloneref and cloneref(game:GetService("Lighting")) or game:GetService("Lighting")
    end
    for prop, value in pairs(props) do
        effect[prop] = value
    end
    return effect
end

local ccEffects = {
    NightVisionColorCorrection = g.ensureColorCorrection("NightVisionColorCorrection", {
        Enabled = false,
        Brightness = 0,
        Contrast = -0.1,
        Saturation = -1,
        TintColor = Color3.new(0.6, 1, 0.815686)
    })
}

local vignetteGui = CoreGui:FindFirstChild("VignetteEffect") or g.PlayerGui:FindFirstChild("VignetteEffect")
if not vignetteGui then
    vignetteGui = Instance.new("ScreenGui")
    vignetteGui.Name = "VignetteEffect"
    vignetteGui.IgnoreGuiInset = true
    vignetteGui.Enabled = false
    vignetteGui.ResetOnSpawn = false
    vignetteGui.Parent = CoreGui
end

local vignetteImage = vignetteGui:FindFirstChildOfClass("ImageLabel")
if not vignetteImage then
    vignetteImage = Instance.new("ImageLabel")
    vignetteImage.Name = "ImageLabel"
    vignetteImage.Active = false
    vignetteImage.BackgroundColor3 = Color3.new(1, 1, 1)
    vignetteImage.BackgroundTransparency = 1
    vignetteImage.BorderColor3 = Color3.new(0, 0, 0)
    vignetteImage.BorderSizePixel = 0
    vignetteImage.Position = UDim2.new(0, 0, 0, 0)
    vignetteImage.Size = UDim2.new(1, 0, 1, 0)
    vignetteImage.Visible = true
    vignetteImage.Image = "rbxassetid://123500368394738"
    vignetteImage.ImageColor3 = Color3.new(1, 1, 1)
    vignetteImage.ImageTransparency = 0
    vignetteImage.ImageRectOffset = Vector2.new(0, 0)
    vignetteImage.ImageRectSize = Vector2.new(0, 0)
    vignetteImage.TileSize = UDim2.new(1, 0, 1, 0)
    vignetteImage.SliceScale = 1
    vignetteImage.SliceCenter = Rect.new(0, 0, 0, 0)
    vignetteImage.ScaleType = Enum.ScaleType.Stretch
    vignetteImage.Parent = vignetteGui
end

g.ToggleNightVision = function(state)
    g.NightVisionEnabled = state
    for _, effect in pairs(ccEffects) do
        effect.Enabled = state
    end
    vignetteGui.Enabled = state
end

g.night_vision = function(toggle)
    if toggle == true then
        if g.NightVisionEnabled then g.notify("Warning", "Night Vision is already enabled.", 5); return end
        g.ToggleNightVision(true)
        g.notify("Success", "Night Vision has been enabled.", 5)
    elseif toggle == false then
        if not g.NightVisionEnabled then g.notify("Warning", "Night Vision is already enabled.", 5); return end
        g.ToggleNightVision(false)
        g.notify("Success", "Night Vision has been disabled.", 5)
    else
        return 
    end
end

g.create_message_instance = function(inst_name, message, duration)
    message = tostring(message)
    inst_name = tostring(inst_name)
    if not duration or typeof(duration) ~= "number" then duration = 10 end
    local new_msg = Instance.new("Hint")
    new_msg.Name = inst_name
    new_msg.Text = message
    new_msg.Parent = workspace
    task.wait(duration)
    if new_msg and new_msg:IsA("Hint") and new_msg.Parent ~= nil then new_msg:Destroy() end
end

g.Net = g.Net or g.find_module_s("Net") or require(g.Core:FindFirstChild("Net"))
g.owner_joined = function(Name)
   local owner_text_content = "Yadsan Hub | Owner has joined this server ("..tostring(Name).."), this is my current and only account right now, so come to me if you need help/assistance."
   if g.notify and typeof(g.notify) == "function" then g.notify("Success", owner_text_content, 15) else print("Success: "..tostring(owner_text_content)) end
end

if g.Teleport_Checker_For_Script then
    pcall(function() g.Teleport_Checker_For_Script:Disconnect() end)
    g.Teleport_Checker_For_Script = nil
end
wait(0.25)
local TeleportCheck = false
g.Teleport_Checker_For_Script = g.LocalPlayer.OnTeleport:Connect(function(State)
	if not TeleportCheck and queueteleport and typeof(queueteleport) == "function" then
		TeleportCheck = true
	end
end)

g.LocalPlayer = g.LocalPlayer or g.safe_wrapper("LocalPlayer")
local some_vehicles = {
    "Monster Truck",
    "SVJ",
    "SF90",
    "Charger SRT",
    "Smart Car",
    "SWAT Van",
    "FireTruck",
    "Tank",
    "MiniCooper",
    "TrackHawk",
    "GClass",
    "Chiron",
    "Humvee",
    "Tesla",
    "Cayenne",
    "F150",
    "Police SUV",
}
fw(0.1)
if not g.Spawned_Vehicle_Checker then
    local Net = g.find_module_s("Net") or require(g.Core:FindFirstChild("Net"))
    g.notify("Success", "Spoofing Vehicle spawner...", 10)

    for _, car in ipairs(some_vehicles) do
        fw(0.2)
        Net.get("spawn_vehicle", tostring(car))
    end
end
fw(0.2)
g.find_placed_models_folder = function()
    local cached_folder = g.cached_placed_models_folder
    if cached_folder and cached_folder.Parent and cached_folder:IsDescendantOf(workspace) then return cached_folder end

    for _, v in ipairs(g.Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if v:IsA("Folder") and (n:find("placedmodels", 1, true) or n:find("modelsplaced", 1, true)) then
            g.cached_placed_models_folder = v
            return v
        end
    end

    return nil
end

if not g.cached_placed_models_folder then pcall(function() g.find_placed_models_folder() end) end
local Placed_Models = g.cached_placed_models_folder or Workspace:FindFirstChild("PlacedModels") or Workspace:WaitForChild("PlacedModels", 1) or g.find_placed_models_folder()
g.workspace_editor_script_GUI = function()
    if g.CoreGui:FindFirstChild("Workspace_Editor_GUI_Flames_Hub") and g.CoreGui:FindFirstChild("Workspace_Editor_GUI_Flames_Hub"):IsA("ScreenGui") then
        g.CoreGui:FindFirstChild("Workspace_Editor_GUI_Flames_Hub").Enabled = true
        return 
    end
    fw(0.1)
    loadstring(g.http_get('https://pastebin.com/raw/bdiufqqx'))()
end

g.is_in_private_server = function()
    local Remote = RobloxReplicatedStorage:FindFirstChild("GetServerType")
    if not Remote then return g.notify("Error", "RemoteFunction: GetServerType does not exist under: RobloxReplicatedStorage, probably patched.", 3) end
    local Result = Remote:InvokeServer()
    local IsPrivateServer = Result == "VIPServer" and true or false

    if IsPrivateServer then
        return true
    else
        g.notify("Info", "You are in a public server.", 3)
        return false
    end
end

g.has_server_admin = function()
    local is_priv_server = g.is_in_private_server()
    if not is_priv_server then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        local hrp = g.get_root(player, Players.RespawnTime + 0.5)
        if hrp and hrp.Parent and hrp:IsDescendantOf(game) then
            local billboard = hrp:FindFirstChild("CharacterBillboardGui")
            if billboard then
                local label = billboard:FindFirstChild("ServerAdmin")
                if label and label:IsA("TextLabel") and label.Visible then
                return true
                end
            end
        end
    end

    return false
end

g.get_server_admin_player = function()
    local function check_player(player)
        local hrp = g.get_root(player, Players.RespawnTime + 0.5)
        if not hrp then return false end
        local billboard = hrp:FindFirstChild("CharacterBillboardGui")
        if not billboard then return false end
        local label = billboard:FindFirstChild("ServerAdmin")
        return label and label:IsA("TextLabel") and label.Visible
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if check_player(player) then
            return player
        end
    end

    if check_player(g.LocalPlayer or Players.LocalPlayer) then return g.LocalPlayer or Players.LocalPlayer end
    return nil
end

g.is_localplayer_server_owner = function()
    if not g.has_server_admin() then return false end
    local admin_player = g.get_server_admin_player()
    local local_player = g.LocalPlayer
    return admin_player and local_player and admin_player == local_player
end

g.notify_priv_server_owner = function()
    local is_priv = g.is_in_private_server()
    if is_priv == nil then return end
    if not is_priv then g.notify("Info", "You're in a public server.", 3); return end
    if not g.has_server_admin() then g.notify("Info", "This is a private server but the owner is not present.", 10); return end
    if g.is_localplayer_server_owner() then g.notify("Info", "You are the private server owner.", 5); return end
    local admin_player = g.get_server_admin_player()
    if admin_player and admin_player:IsA("Player") then
        g.notify("Info", "This is a private server owned by: " .. tostring(admin_player.Name), 7)
    else
        g.notify("Info", "This is a private server owned by: " .. tostring(admin_player), 7)
    end
end

g.server_admin_tp = function(Player)
    local check_is_localplr_priv_server_owner = g.is_localplayer_server_owner()
    if not check_is_localplr_priv_server_owner then g.notify("Warning", "You do not own this Private Server!", 5); return end
    if typeof(Player) ~= "Instance" or not Player:IsA("Player") then g.notify("Error", "That player doesn't exist or is not a Player.", 5); return end
    g.Send("server_admin_teleport_to_player", Player.UserId)
end

g.disable_emote_func = function()
    local Humanoid = g.Humanoid or g.get_human(LocalPlayer, Players.RespawnTime + 1)
    if not Humanoid then g.notify("Error", "Humanoid not found, try resetting.", 5); return end
    pcall(function() for _, v in ipairs(Humanoid:GetPlayingAnimationTracks()) do v:Stop() end end)
    if g.Is_Currently_Emoting then g.Is_Currently_Emoting = false end
end

if not g.Spawned_Vehicle_Checker then
    local Net = g.Net or require(g.Core:FindFirstChild("Net"))
    local success, response = pcall(function()
        Net.get("spawn_vehicle", "Monster Truck")
        wait(3)
        return g.get_vehicle()
    end)

    if success and response then
        fw(0.1)
        if g.get_vehicle() and g.Humanoid.Sit or g.Humanoid.Sit == true then
            g.Humanoid:ChangeState(3)
            fw(0.2)
            Net.get("spawn_vehicle", g.get_vehicle().Name or "Monster Truck")
        elseif g.get_vehicle() and g.Humanoid.Sit == false then
            Net.get("spawn_vehicle", g.get_vehicle().Name or "Monster Truck")
        elseif not g.get_vehicle() then
            g.notify("Warning", "We did spawn the Vehicle it seems, but it seems like you despawned the Vehicle.", 10)
        elseif not g.get_vehicle() and g.Humanoid.Sit == true then
            pcall(function() g.Humanoid:ChangeState(3) end)
            g.notify("Warning", "We did not find your Vehicle, but it seems like it worked.", 5)
        end
    else
        if not success then
            g.LifeTogetherRP_Admin = false
            g.LifeTogether_Actual_Flames_Hub_Running_Functioning_Currently_On_Client = false
            return g.notify("Error", "You cannot run this script on this executor, we're sorry! (if you believe this was in error, re-run the script).", 12)
        end
    end

    g.Spawned_Vehicle_Checker = true
end

local Char = g.Char or require(ReplicatedStorage:FindFirstChild("Char", true))
g.get_current_character_life_together_rp = function() return Char.get() end
g.get_hrp_life_together_rp = function() return Char.get_hrp() end
g.get_human_life_together_rp = function() return Char.get_hum() end
if g.invisible_toggle_connections then
    for _, conn in pairs(g.invisible_toggle_connections) do pcall(function() conn:Disconnect() end) end
    fw(0.1)
    g.invisible_toggle_connections = nil
end

local player = g.LocalPlayer or Players.LocalPlayer
local character, humanoid, rootPart
g.is_invisible_script_toggled = false
g.invisible_body_parts = g.invisible_body_parts or {}
g.invis_main_FE_connections = g.invis_main_FE_connections or {}
g.setupCharacter = function()
    character = g.Character or player.Character or player.CharacterAdded:Wait()
    humanoid = g.Humanoid or character:WaitForChild("Humanoid", 5)
    rootPart = g.HumanoidRootPart or character:WaitForChild("HumanoidRootPart", 5)
    g.invisible_body_parts = {}
    for _, obj in pairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            g.invisible_body_parts[obj] = obj.Transparency
        end
    end
end

g.createUI = function()
    local gui = CoreGui:FindFirstChild("InvisibleUI")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "InvisibleUI"
        gui.ResetOnSpawn = false
        gui.Parent = CoreGui
    end

    gui.Enabled = false
    gui:ClearAllChildren()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 90)
    frame.Position = UDim2.new(0.5, -110, 0.15, 0)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    frame.BorderSizePixel = 2
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    frame.Visible = false

    local invisBtn = Instance.new("TextButton")
    invisBtn.Size = UDim2.new(0, 100, 0, 40)
    invisBtn.Position = UDim2.new(0, 10, 0, 25)
    invisBtn.Text = "Invisible"
    invisBtn.TextScaled = true
    invisBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    invisBtn.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 80, 0, 30)
    toggleBtn.Position = UDim2.new(0, 130, 0, 30)
    toggleBtn.Text = "Hide"
    toggleBtn.TextScaled = true
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 240)
    toggleBtn.Parent = frame

    invisBtn.MouseButton1Click:Connect(function()
        g.is_invisible_script_toggled = not g.is_invisible_script_toggled
        for part, original in pairs(g.invisible_body_parts) do
            if part and part.Parent then
                part.Transparency = g.is_invisible_script_toggled and 0.5 or original
            end
        end
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        if toggleBtn.Text == "Hide" then
            invisBtn.Visible = false
            toggleBtn.Text = "Show"
            frame.Size = UDim2.new(0, 100, 0, 40)
            toggleBtn.Size = UDim2.new(1, 0, 1, 0)
            toggleBtn.Position = UDim2.new(0, 0, 0, 0)
        else
            invisBtn.Visible = true
            toggleBtn.Text = "Hide"
            frame.Size = UDim2.new(0, 220, 0, 90)
            invisBtn.Size = UDim2.new(0, 100, 0, 40)
            invisBtn.Position = UDim2.new(0, 10, 0, 25)
            toggleBtn.Size = UDim2.new(0, 80, 0, 30)
            toggleBtn.Position = UDim2.new(0, 130, 0, 30)
        end
    end)
end

g.setupCharacter()
g.createUI()
if g.invis_main_FE_connections.Heartbeat then
    pcall(function() g.invis_main_FE_connections.Heartbeat:Disconnect() end)
    g.invis_main_FE_connections.Heartbeat = nil
end
wait(0.25)
g.invis_main_FE_connections.Heartbeat = RunService.Heartbeat:Connect(function()
    if g.is_invisible_script_toggled and rootPart and humanoid then
        local cf = rootPart.CFrame
        local camOffset = humanoid.CameraOffset
        local hidden = cf * CFrame.new(0, -200000, 0)
        rootPart.CFrame = hidden
        humanoid.CameraOffset = hidden:ToObjectSpace(CFrame.new(cf.Position)).Position
        RunService.RenderStepped:Wait()
        rootPart.CFrame = cf
        humanoid.CameraOffset = camOffset
    end
end)

if g.invis_main_FE_connections.CharacterAdded then
    pcall(function() g.invis_main_FE_connections.CharacterAdded:Disconnect() end)
    g.invis_main_FE_connections.CharacterAdded = nil
end
wait(0.25)
g.invis_main_FE_connections.CharacterAdded = player.CharacterAdded:Connect(function()
    g.is_invisible_script_toggled = false
    g.setupCharacter()
    g.createUI()
end)

g.invisible_toggle_connections = g.invis_main_FE_connections
g.set_invisible = g.set_invisible or function(state)
    g.is_invisible_script_toggled = state and true or false
    if g.is_invisible_script_toggled then
        g.notify("Info", "You can still use the chat, but people won't be able to see it directly above your head.", 10)
    end

    for part, original in pairs(g.invisible_body_parts) do
        if part and part.Parent then
            part.Transparency = g.is_invisible_script_toggled and 0.5 or original
        end
    end
end

g.AllCars = {
    "Magic Carpet", "EClass", "TowTruck", "Bicycle", "Fiat500", "Cayenne", "Jetski", "LuggageScooter",
    "MiniCooper", "GarbageTruck", "EScooter", "Monster Truck", "Yacht", "Stingray", "FireTruck", "VespaPizza",
    "VespaPolice", "F150", "Police SUV", "Chiron", "Humvee", "Wrangler", "Box Van", "Ambulance", "Urus", "Tesla",
    "Cybertruck", "RollsRoyce", "GClass", "SVJ", "MX5", "SF90", "Charger SRT", "Evoque", "IceCream Truck",
    "Vespa", "ATV", "Limo", "Tank", "Smart Car", "Beauford", "SchoolBus", "Sprinter", "GolfKart", "TrackHawk",
    "Helicopter", "SnowPlow", "Camper Van", "SWAT Van", "Magic Carpett"
}
local CarMap = {}

g.kick_plr = g.kick_plr or function(player)
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 5); return end
    local name
    if typeof(player) == "Instance" then name = player.Name else name = tostring(player) end
    if not allowed[player.Name] then
        local args = {
            "server_admin_kick_player",
            tostring(name)
        }

        g.Get(unpack(args))
    end
end

-- [[ Does not work anymore. ]] --
--[[g.load_chat_main_GUI = function()
    wait(0.15)
    local connector = (syn and syn.websocket and syn.websocket.connect) or (WebSocket and WebSocket.connect) or (websocket and websocket.connect)
    if not connector or typeof(connector) ~= "function" then g.notify("Error", "[Yadsan Hub - Chat]: No WebSocket support, unable to use Yadsan Hub | Custom Chat script.", 10); return end
    pcall(function() loadstring(g.http_get("https://pastefy.app/108vjy8A/raw"))() end)
end--]]

-- [[ I wish they would remove this pointless ass integration. ]] --
if Workspace:FindFirstChild("WildwoodIntegration") then
    local wild_wood = Workspace:FindFirstChild("WildwoodIntegration")
    for _, v in ipairs(wild_wood:GetDescendants()) do
        if v:IsA("TouchTransmitter") then
            pcall(function() v:Destroy() end)
        elseif v:IsA("Seat") then
            pcall(function()
                v.Disabled = true
                wait(0.15)
                v:Destroy()
            end)
        end
    end
end

g.server_lock_whitelist_gui = g.server_lock_whitelist_gui or function()
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 5); return end
    if g.ServerLockWhitelistManagerGUI then g.notify("Warning", "Server-Lock whitelist manager is already running!", 5); return end
    g.ServerLockWhitelistManagerGUI = true
    g.server_whitelist = g.server_whitelist or {}
    if not g.server_whitelist["Yadsan_Godverse"] then g.server_whitelist["Yadsan_Godverse"] = true end
    if not g.server_whitelist["L0CKED_1N1"] then g.server_whitelist["L0CKED_1N1"] = true end
    if not g.server_whitelist["AuraWithClipFarmin"] then g.server_whitelist["AuraWithClipFarmin"] = true end
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = tostring(g.randomString())
    ScreenGui.Parent = parent_gui

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 300, 0, 350)
    Main.Position = UDim2.new(0.5, -150, 0.5, -175)
    Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui

    if g.dragify and typeof(g.dragify) == "function" then g.dragify(Main) end
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Main

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    TitleBar.Parent = Main

    local UI_Corner = Instance.new("UICorner")
    UI_Corner.CornerRadius = UDim.new(0, 8)
    UI_Corner.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.970000029, -30, 1, 0)
    Title.Position = UDim2.new(0, 5, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Server-Lock Whitelist Manager"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextScaled = true
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 1, 0)
    CloseButton.Position = UDim2.new(1, -30, 0, 0)
    CloseButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 18
    CloseButton.Parent = TitleBar

    local UICorner_ = Instance.new("UICorner")
    UICorner_.CornerRadius = UDim.new(0, 8)
    UICorner_.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        g.TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 300, 0, 0), Transparency = 1}):Play()
        wait(0.25)
        g.ServerLockWhitelistManagerGUI = false
        ScreenGui:Destroy()
    end)

    local Input = Instance.new("TextBox")
    Input.PlaceholderText = "Enter username..."
    Input.Size = UDim2.new(1, -20, 0, 25)
    Input.Position = UDim2.new(0, 10, 0, 35)
    Input.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Input.TextColor3 = Color3.fromRGB(255, 255, 255)
    Input.Text = ""
    Input.Font = Enum.Font.Gotham
    Input.TextSize = 14
    Input.Parent = Main

    local UICorner_2 = Instance.new("UICorner")
    UICorner_2.CornerRadius = UDim.new(0, 8)
    UICorner_2.Parent = Input

    local AddButton = Instance.new("TextButton")
    AddButton.Size = UDim2.new(0.5, -15, 0, 25)
    AddButton.Position = UDim2.new(0, 10, 0, 68)
    AddButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    AddButton.Text = "Add to server-lock whitelist"
    AddButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AddButton.Font = Enum.Font.Gotham
    AddButton.TextSize = 14
    AddButton.TextScaled = true
    AddButton.Parent = Main

    local RemoveButton = Instance.new("TextButton")
    RemoveButton.Size = UDim2.new(0.5, -15, 0, 25)
    RemoveButton.Position = UDim2.new(0, 150, 0, 68)
    RemoveButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    RemoveButton.Text = "Remove from server-lock whitelist"
    RemoveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RemoveButton.Font = Enum.Font.Gotham
    RemoveButton.TextSize = 14
    RemoveButton.TextScaled = true
    RemoveButton.Parent = Main

    local UICorner_3 = Instance.new("UICorner")
    UICorner_3.CornerRadius = UDim.new(0, 8)
    UICorner_3.Parent = AddButton
    local UICorner_4 = Instance.new("UICorner")
    UICorner_4.CornerRadius = UDim.new(0, 8)
    UICorner_4.Parent = RemoveButton

    local PlayerList = Instance.new("ScrollingFrame")
    PlayerList.Size = UDim2.new(1, -20, 1, -110)
    PlayerList.Position = UDim2.new(0, 10, 0, 100)
    PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerList.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    PlayerList.ScrollBarThickness = 5
    PlayerList.Parent = Main

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 3)
    UIListLayout.Parent = PlayerList

    local function refresh_list()
        for _, child in ipairs(PlayerList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= g.LocalPlayer then
                if plr.Name ~= "Yadsan_Godverse" and plr.Name ~= "L0CKED_1N1" and plr.Name ~= "AuraWithClipFarmin" then
                    local frame = Instance.new("Frame")
                    frame.Size = UDim2.new(1, 0, 0, 30)
                    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    frame.Parent = PlayerList

                    local name_label = Instance.new("TextLabel")
                    name_label.Size = UDim2.new(1, -60, 1, 0)
                    name_label.Position = UDim2.new(0, 5, 0, 0)
                    name_label.BackgroundTransparency = 1
                    name_label.Text = plr.Name
                    name_label.TextScaled = true
                    name_label.TextColor3 = g.server_whitelist[plr.Name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                    name_label.Font = Enum.Font.Gotham
                    name_label.TextSize = 14
                    name_label.TextXAlignment = Enum.TextXAlignment.Left
                    name_label.Parent = frame

                    local button = Instance.new("TextButton")
                    button.Size = UDim2.new(0, 50, 1, -6)
                    button.Position = UDim2.new(1, -55, 0, 3)
                    button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                    button.Text = g.server_whitelist[plr.Name] and "Remove" or "Add"
                    button.TextScaled = true
                    button.TextColor3 = Color3.fromRGB(255, 255, 255)
                    button.Font = Enum.Font.Gotham
                    button.TextSize = 13
                    button.Parent = frame

                    local UICorner = Instance.new("UICorner")
                    UICorner.CornerRadius = UDim.new(0, 8)
                    UICorner.Parent = frame
                    local UICorner_5 = Instance.new("UICorner")
                    UICorner_5.CornerRadius = UDim.new(0, 8)
                    UICorner_5.Parent = name_label
                    local UICorner_6 = Instance.new("UICorner")
                    UICorner_6.CornerRadius = UDim.new(0, 8)
                    UICorner_6.Parent = button

                    button.MouseButton1Click:Connect(function()
                        if g.server_whitelist[plr.Name] then
                            g.server_whitelist[plr.Name] = nil
                        else
                            g.server_whitelist[plr.Name] = true
                        end
                        refresh_list()
                    end)
                end
            end
        end
        PlayerList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
    end

    AddButton.MouseButton1Click:Connect(function()
        local name = Input.Text
        if name ~= "" then
            if g.server_whitelist[name] then g.notify("Warning", tostring(name).." is already in the server-lock whitelist!", 5); return end
            g.server_whitelist[name] = true
            Input.Text = ""
            wait(0.3)
            if g.server_whitelist[name] then g.notify("Success", tostring(name).." was added to server-lock whitelist! (they won't get kicked by server-lock).", 15) end
            refresh_list()
        end
    end)

    RemoveButton.MouseButton1Click:Connect(function()
        local name = Input.Text
        if name ~= "" then
            if not g.server_whitelist[name] then g.notify("Warning", tostring(name).." is not in the server-lock whitelist!", 5); return end

            g.server_whitelist[name] = nil
            Input.Text = ""
            wait(0.3)
            if not g.server_whitelist[name] then g.notify("Success", tostring(name).." was removed from the server-lock whitelist! (they WILL get kicked by server-lock).", 15) end
            refresh_list()
        end
    end)

    if not g.Player_Added_Removed_Conn_Whitelist_Manager_Check then
        g.Player_Added_Removed_Conn_Whitelist_Manager_Check = true
        Players.PlayerAdded:Connect(function()
            task.wait(0.5)
            refresh_list()
        end)
        Players.PlayerRemoving:Connect(refresh_list)
    end
    refresh_list()
end

g.friend_user_async_function = g.friend_user_async_function or function(player)
    local target = player
    if not target then g.notify("Error", "Player does not exist or has left the game.", 5); return end
    if g.LocalPlayer:IsFriendsWith(target.UserId) then g.notify("Warning", "You're already friends with this person.", 5); return end
    local ok, response = pcall(function() g.LocalPlayer:RequestFriendship(target) end)
    if not ok then
        g.notify("Warning", "An unexpected error happened while friending: "..tostring(target), 10)
        g.notify("Error", "Error: "..tostring(response), 10)
        return 
    else
        g.notify("Success", "Sent friend request to: "..tostring(target).." successfully!", 5)
    end
end

g.unfriend_user_async = g.unfriend_user_async or function(player)
    local target = player
    if not target then g.notify("Error", "Player does not exist or has left the game.", 5); return end
    if not g.LocalPlayer:IsFriendsWith(target.UserId) then g.notify("Warning", "You're not friends with this person.", 5); return end
    local ok, response = pcall(function() g.LocalPlayer:RevokeFriendship(target) end)
    if not ok then
        g.notify("Warning", "An unexpected error happened while unadding: "..tostring(target), 10)
        g.notify("Error", "Error: "..tostring(response), 10)
        return
    else
        g.notify("Success", "Unfriended target player: "..tostring(target).." successfully.", 5)
    end
end

g.prompt_game_invite_func = g.prompt_game_invite_func or function(args)
    local options = Instance.new("ExperienceInviteOptions")
    options.InviteMessageId = tostring(args) or "join me bruh"
    local player = g.LocalPlayer or Players.LocalPlayer
    local SocialService = g.SocialService or cloneref and cloneref(game:GetService("SocialService")) or game:GetService("SocialService")
    local ok, response = pcall(function() SocialService:PromptGameInvite(player, options) end)
    if ok and response ~= nil then
        g.notify("Success", "Sent invite to person: "..tostring(player), 3)
    else
        g.notify("Warning", "Apparently something went wrong trying to invite: "..tostring(player)..", got response: "..tostring(response), 10)
    end
end

g.server_lock_toggle = g.server_lock_toggle or function(toggle)
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 5); return end
    g.server_whitelist = g.server_whitelist or {}
    if not g.server_whitelist["Yadsan_Godverse"] then g.server_whitelist["Yadsan_Godverse"] = true end
    local function should_kick(v)
        if v == g.LocalPlayer then return false end
        if g.server_whitelist[v.Name] then return false end
        return true
    end

    if toggle == true then
        if g.server_lock_enabled then g.notify("Warning", "Server-Lock is already enabled!", 5); return end
        if not workspace:FindFirstChildOfClass("Hint") then
            local hint_instance = Instance.new("Hint")
            hint_instance.Text = "Yadsan Hub - ServerLock V2 is now enabled."
            if typeof(workspace) == "Instance" and workspace:IsDescendantOf(game) then hint_instance.Parent = workspace end
        end

        g.server_lock_enabled = true
        for _, v in ipairs(g.Players:GetPlayers()) do
            if should_kick(v) then
                pcall(g.kick_plr, v)
            end
        end

        if not g.server_lock_playeradded_conn then
            g.server_lock_playeradded_conn = Players.PlayerAdded:Connect(function(v)
                if not g.server_lock_enabled then return end
                if should_kick(v) then
                    task.wait(0.5)
                    pcall(g.kick_plr, v)
                end
            end)
        end
    elseif toggle == false then
        if not g.server_lock_enabled then g.notify("Warning", "Server-Lock is not enabled!", 5); return end
        if workspace:FindFirstChildOfClass("Hint") then pcall(function() workspace:FindFirstChildOfClass("Hint"):Destroy() end) end
        g.server_lock_enabled = false
        if g.server_lock_playeradded_conn then
            g.server_lock_playeradded_conn:Disconnect()
            g.server_lock_playeradded_conn = nil
        end

        g.notify("Success", "Server-Lock is now disabled.", 5)
    end
end

g.stop_time_toggle = g.stop_time_toggle or function(toggle)
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 5); return end
    if toggle == true then
        g.Send("time_toggle", true)
        g.is_time_currently_stopped_priv_server = true
        g.notify("Success", "Time has been stopped.", 3)
    elseif toggle == false then
        g.Send("time_toggle", false)
        g.is_time_currently_stopped_priv_server = false
        g.notify("Success", "Time is now resumed.", 3)
    else
        return 
    end
end

g.change_time_num = g.change_time_num or function(number_input)
    if typeof(number_input) ~= "number" then g.notify("Error", "That is not a number!", 3); return end
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 3); return end
    local main_conv = tonumber(number_input) or number_input
    g.Send("change_time", main_conv)
end

g.flash_time_toggle = g.flash_time_toggle or function(toggled)
    if not g.is_localplayer_server_owner() then
        g.flashing_time_fe_toggle = false
        g.notify("Error", "You are not the private server owner!", 5)
        return
    end

    if toggled then
        if g.flashing_time_fe_toggle then g.notify("Warning", "Time Flasher is already enabled!", 5); return end
        if UserInputService.TouchEnabled then
            g.flashing_time_fe_toggle = true
            g.notify("Success", "Time Flasher is now enabled.", 5)
            g.Flashing_Time_FE_Toggle_Task = task.spawn(function()
                while g.flashing_time_fe_toggle == true do
                fw(0.1)
                    g.change_time_num(4.5)
                    fw(0)
                    g.change_time_num(12)
                    fw(.1)
                    g.change_time_num(23)
                end
            end)
        else
            g.flashing_time_fe_toggle = true
            g.notify("Success", "Time Flasher is now enabled.", 5)
            g.Flashing_Time_FE_Toggle_Task = task.spawn(function()
                while g.flashing_time_fe_toggle == true do
                fw(0)
                    g.change_time_num(4.5)
                    fw(0)
                    g.change_time_num(12)
                    fw(0)
                    g.change_time_num(23)
                end
            end)
        end
    else
        if not g.flashing_time_fe_toggle then g.notify("Warning", "Time Flasher is not enabled!", 3); return end
        g.flashing_time_fe_toggle = false
        if g.Flashing_Time_FE_Toggle_Task then
            task.cancel(g.Flashing_Time_FE_Toggle_Task)
            g.Flashing_Time_FE_Toggle_Task = nil
        end
        g.notify("Success", "Time Flasher has been disabled.", 5)
    end
end

g.pick_new_weather = g.pick_new_weather or function(weather_set)
    local weather_args
    if weather_set:lower():find("snow") then
        weather_args = {
            "change_weather",
            {
                humidity = 1,
                wind = 0.55,
                temperature = 0
            }
        }
    elseif weather_set:lower():find("sun") then
        weather_args = {
            "change_weather",
            {
                humidity = 0.5,
                wind = 0.3,
                temperature = 1
            }
        }
    elseif weather_set:lower():find("rain") then
        weather_args = {
            "change_weather",
            {
                humidity = 1,
                wind = 0.7,
                temperature = 0.6
            }
        }
    end
    return weather_args
end

g.set_new_weather = g.set_new_weather or function(new_weather_input)
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 5); return end
    local changed_weather = g.pick_new_weather(new_weather_input)
    if not changed_weather then g.notify("Error", "Invalid weather type: " .. tostring(new_weather_input), 5); return end
    g.Send(unpack(changed_weather))
end

g.weather_flasher_loop = g.weather_flasher_loop or function(toggle)
    if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 3); return end
    local fw = g.FlamesLibrary.wait

    if toggle == true then
        if g.changing_weather_on_repeat then g.notify("Warning", "Yadsan Hub - Weather Flasher is already enabled!", 5); return end
        g.changing_weather_on_repeat = true
        g.notify("Success", "Yadsan Hub - Weather Flasher is now enabled.", 5)
        g.FlamesLibrary.spawn("weather_loop_repeater", "spawn", function()
            while g.changing_weather_on_repeat == true do
            fw(0)
                g.set_new_weather("snow")
                fw(.1)
                g.set_new_weather("rain")
                fw(0)
                g.set_new_weather("sun")
            end
        end)
    elseif toggle == false then
        if not g.changing_weather_on_repeat then g.notify("Warning", "Yadsan Hub - Weather Flasher is not enabled!", 5); return end
        g.changing_weather_on_repeat = false
        g.FlamesLibrary.disconnect("weather_loop_repeater")
        g.notify("Success", "Yadsan Hub - Weather Flasher is now disabled.", 5)
    else
        return 
    end
end

for _, name in ipairs(g.AllCars) do CarMap[name:lower()] = name end
g.car_listing_gui = function()
    if g.CarListingGUIValue then return end
    g.CarListingGUIValue = true
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = tostring(g.randomString())
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent_gui

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = IsMobile and UDim2.new(0, 280, 0, 350) or UDim2.new(0, 350, 0, 450)
    MainFrame.Position = UDim2.new(0.5, -MainFrame.Size.X.Offset/2, 0.5, -MainFrame.Size.Y.Offset/2)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 15)
    UICorner.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -40, 0, 40)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Made by: "..tostring(g.Script_Creator)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -35, 0, 5)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.Text = "X"
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 16
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Parent = MainFrame

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        g.CarListingGUIValue = false
    end)

    local ScrollingFrame = Instance.new("ScrollingFrame")
    ScrollingFrame.Size = UDim2.new(1, -20, 1, -60)
    ScrollingFrame.Position = UDim2.new(0, 10, 0, 50)
    ScrollingFrame.BackgroundTransparency = 1
    ScrollingFrame.BorderSizePixel = 0
    ScrollingFrame.ScrollBarThickness = 6
    ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollingFrame.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = ScrollingFrame
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 5)

    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = ScrollingFrame
    UIPadding.PaddingLeft = UDim.new(0, 5)
    UIPadding.PaddingTop = UDim.new(0, 5)

    for _, name in ipairs(g.AllCars) do
        local CarButton = Instance.new("TextButton")
        CarButton.Size = UDim2.new(1, -10, 0, 30)
        CarButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        CarButton.Text = name
        CarButton.Font = Enum.Font.Gotham
        CarButton.TextSize = 16
        CarButton.TextColor3 = Color3.fromRGB(220, 220, 220)
        CarButton.Parent = ScrollingFrame

        local CarCorner = Instance.new("UICorner")
        CarCorner.CornerRadius = UDim.new(0, 10)
        CarCorner.Parent = CarButton

        CarButton.MouseButton1Click:Connect(function()
            if not g.Get then return end
            g.Get("spawn_vehicle", name)
        end)
    end

    if g.dragify and typeof(g.dragify) == "function" then g.dragify(MainFrame) end
end

g.stop_all_anims = g.stop_all_anims or function()
    local Hum = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
    if not Hum then return end
    for i,v in next, Hum:GetPlayingAnimationTracks() do v:Stop() end
end

g.isTrackPlaying = g.isTrackPlaying or function(humanoid)
    if not humanoid or not humanoid:IsDescendantOf(game) then g.notify("Error", "Humanoid does not exist / was not found.", 1); return false end
    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do if track.IsPlaying or (track.TimePosition > 0 and track.Length > 0) then return true end end
    return false
end
fw(0.2)
g.main_emote_ID = 72074295131591
g.play_anim_on_local_plr = function(anim_selector)
    if g.isTrackPlaying(g.Humanoid) then g.stop_all_anims() end
    wait(0.25)
    if anim_selector == "1" then
        local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://134313829527772"
        fw(0.1)
        local track = Humanoid:LoadAnimation(anim)
        track:Play(0, 1, 1)
        track.TimePosition = 3.2708375453948975
        track:AdjustSpeed(0)
        for _, v in pairs(Humanoid:GetPlayingAnimationTracks()) do v:AdjustSpeed(0) end
    elseif anim_selector == "2" then
        local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://124771204189379"
        fw(0.1)
        local track = Humanoid:LoadAnimation(anim)
        repeat task.wait() until track.Length > 0
        track:Play(0, 1, 1)
        repeat task.wait() until track.IsPlaying and track.Speed >= 0.5
        if not track.IsPlaying then return end
        for _, v in pairs(Humanoid:GetPlayingAnimationTracks()) do v:AdjustSpeed(0) end
    elseif anim_selector == "3" then
        local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://137126647656632"
        fw(0.1)
        local track = Humanoid:LoadAnimation(anim)
        track:Play(0, 1, 1)
        track:AdjustSpeed(0)
        for _, v in pairs(Humanoid:GetPlayingAnimationTracks()) do v:AdjustSpeed(0) end
    elseif anim_selector == "4" then
        local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://85233258054867"
        fw(0.1)
        local track = Humanoid:LoadAnimation(anim)
        track:Play(0, 1, 1)
        track:AdjustSpeed(0)
        for _, v in pairs(Humanoid:GetPlayingAnimationTracks()) do v:AdjustSpeed(0) end
    elseif anim_selector == "5" then
        local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://101847197011911"
        fw(0.1)
        local track = Humanoid:LoadAnimation(anim)
        track:Play(0, 1, 1)
        track:AdjustSpeed(2)
        for _, v in pairs(Humanoid:GetPlayingAnimationTracks()) do v:AdjustSpeed(2) end
    elseif anim_selector == "6" then
        local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://138990462417721"
        fw(0.1)
        local track = Humanoid:LoadAnimation(anim)
        track:Play(0, 1, 1)
        track:AdjustSpeed(0)
        track.TimePosition = 2.49
        fw(0.1)
        for _, v in pairs(Humanoid:GetPlayingAnimationTracks()) do v:AdjustSpeed(0) end
    else
        g.notify("Error", "Invalid Animation argument provided, pick between either 1 or 2.", 7)
        return 
    end
end

g.create_bindable = g.create_bindable or function()
    if g._localBindable then return g._localBindable end
    local b = Instance.new("BindableEvent")
    g._localBindable = b
    return b
end

g.is_me = g.is_me or function(input)
    if type(input) ~= "string" then return false end
    input = string.lower(input)
    local name = string.lower(LocalPlayer.Name)
    local display = string.lower(LocalPlayer.DisplayName)
    return name:sub(1, #input) == input or display:sub(1, #input) == input
end

local Bindable
if not allowed[LocalPlayer.Name] then Bindable = g.create_bindable() end
if allowed[LocalPlayer.Name] then g.notify("Success", "You're an Administrator/Staff in Yadsan Hub, you can do our PRIVATE commands by doing: ?flamescmds in the chat.", 15) end
g.current_worn_cached_clothing_items = g.current_worn_cached_clothing_items or {}
g.GetWornAssetId = g.GetWornAssetId or function(AssetType)
    local Humanoid = g.LocalPlayer.Character and g.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return nil end
    local Desc = Humanoid:FindFirstChildOfClass("HumanoidDescription")
    if not Desc then Desc = Humanoid:GetAppliedDescription() end
    if not Desc then return nil end
    if AssetType:lower() == "shirt" then
        return Desc.Shirt ~= 0 and Desc.Shirt or nil
    elseif AssetType:lower() == "pants" then
        return Desc.Pants ~= 0 and Desc.Pants or nil
    end
    return nil
end
wait(0.25)
g.LayeredTypes = {
    [Enum.AccessoryType.TShirt] = true,
    [Enum.AccessoryType.Shirt] = true,
    [Enum.AccessoryType.Pants] = true,
    [Enum.AccessoryType.Jacket] = true,
    [Enum.AccessoryType.Sweater] = true,
    [Enum.AccessoryType.Shorts] = true,
    [Enum.AccessoryType.LeftShoe] = true,
    [Enum.AccessoryType.RightShoe] = true,
    [Enum.AccessoryType.DressSkirt] = true,
}

g.CacheWornClothing = g.CacheWornClothing or function()
    g.current_worn_cached_clothing_items["shirt"] = g.GetWornAssetId("shirt")
    g.current_worn_cached_clothing_items["pants"] = g.GetWornAssetId("pants")
    g.current_worn_cached_clothing_items["layered"] = {}
    local Character = g.Character or g.LocalPlayer.Character or g.get_char(LocalPlayer, 3) or g.Char:get()
    if not Character then return end
    local hum = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("Humanoid") or g.get_human(LocalPlayer, 3) or g.Char:get_hum()
    if not hum then return end
    local desc = hum:GetAppliedDescription()
    for _, info in ipairs(desc:GetAccessories(true)) do
        if info.IsLayered then
            table.insert(g.current_worn_cached_clothing_items["layered"], {
                AssetId = info.AssetId,
                AccessoryType = info.AccessoryType.Name,
            })
        end
    end
end

g.GetCachedClothingId = g.GetCachedClothingId or function(AssetType) AssetType = AssetType:lower(); return g.current_worn_cached_clothing_items[AssetType] end
g.GetCachedLayered = g.GetCachedLayered or function() return g.current_worn_cached_clothing_items["layered"] or {} end
wait(0.15)
g.CacheWornClothing()
local function GetControlModule()
    local PlayerScripts = g.LocalPlayer:WaitForChild("PlayerScripts")
    local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
    return PlayerModule:GetControls()
end

local commands = {
    ["!anim"] = {
        display = "!anim [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.play_anim_on_local_plr("1")
        end
    },

    ["!reset"] = {
        display = "!reset [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.Humanoid then
                pcall(function() g.Humanoid.Health = 0 end)
            elseif not g.Humanoid or not g.Humanoid.Parent then
                repeat task.wait(10) until g.Character:FindFirstChildOfClass("Humanoid")
                wait(1)
                if g.Character:FindFirstChildOfClass("Humanoid") then
                g.Character:FindFirstChildOfClass("Humanoid").Health = 0
                end
            end
        end
    },

    ["!speed"] = {
        display = "!speed [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.Humanoid then pcall(function() g.Humanoid.WalkSpeed = 100 end) end
        end
    },

    ["!anim2"] = {
        display = "!anim2 [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.play_anim_on_local_plr("2")
        end
    },

    ["!anim3"] = {
        display = "!anim3 [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.play_anim_on_local_plr("3")
        end
    },

    ["!anim4"] = {
        display = "!anim4 [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.play_anim_on_local_plr("4")
        end
    },

    ["!anim5"] = {
        display = "!anim5 [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.play_anim_on_local_plr("5")
        end
    },

    ["!anim6"] = {
        display = "!anim6 [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.play_anim_on_local_plr("6")
        end
    },

    ["!jump"] = {
        display = "!jump [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.Humanoid and g.HumanoidRootPart then
                pcall(function()
                    g.HumanoidRootPart.Anchored = true
                    wait(0.3)
                    g.Humanoid:ChangeState(3)
                    wait(0.3)
                    g.HumanoidRootPart.Anchored = false
                end)
            end
        end
    },

    ["!freeze"] = {
        display = "!freeze [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.Humanoid then pcall(function() g.Humanoid.WalkSpeed = 0 end) end
            if g.HumanoidRootPart then pcall(function() g.HumanoidRootPart.Anchored = true end) end
            local Controls = GetControlModule()
            if Controls then Controls:Disable() end
        end
    },

    ["!unfreeze"] = {
        display = "!unfreeze [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.HumanoidRootPart then pcall(function() g.HumanoidRootPart.Anchored = false end) end
            if g.Humanoid then pcall(function() g.Humanoid.WalkSpeed = 16 end) end
            local Controls = GetControlModule()
            if Controls then Controls:Enable() end
        end
    },

    ["!kick"] = {
        display = "!kick [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            LocalPlayer:Kick("The owner of Yadsan Hub or an official Administrator/Staff of Yadsan Hub has kicked you.")
            wait(3)
            while true do end
        end
    },

    ["!bring"] = {
        display = "!bring [player]",
        run = function(args, sender)
            local target = args[2]
            if not g.is_me(target) then return end
            if not sender then return end
            local sender_char = sender.Character
            local sender_hrp = sender_char:WaitForChild("HumanoidRootPart")
            if sender_char and sender_char:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    if g.HumanoidRootPart and g.Character:FindFirstChild("HumanoidRootPart") then
                        g.HumanoidRootPart.CFrame = CFrame.new(sender_hrp.Position + Vector3.new(0, 3, 0))
                        g.Character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(sender_hrp.Position + Vector3.new(0, 3, 0))
                    else
                        g.Character:PivotTo(sender_char:GetPivot() + Vector3.new(0, 3, 0))
                    end
                end)
            end
        end
    },

    ["!unanim"] = {
        display = "!unanim [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.stop_all_anims()
        end
    },

    ["!unemote"] = {
        display = "!unemote [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.stop_all_anims()
        end
    },

    ["!stopanims"] = {
        display = "!stopanims [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            g.stop_all_anims()
        end
    },

    ["!vis"] = {
        display = "!vis [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.LocalPlayer:GetAttribute("is_verified") == false then return end
            if not g.InvisibleMode then return end
            if g.InvisibleMode.enabled.get() then
                g.InvisibleMode.enabled.set(false)
            end
        end
    },

    ["!visible"] = {
        display = "!visible [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.LocalPlayer:GetAttribute("is_verified") == false then return end
            if not g.InvisibleMode then return end
            if g.InvisibleMode.enabled.get() then
                g.InvisibleMode.enabled.set(false)
            end
        end
    },

    ["!invis"] = {
        display = "!invis [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.LocalPlayer:GetAttribute("is_verified") == false then return end
            if not g.InvisibleMode then return end
            if not g.InvisibleMode.enabled.get() then
                g.InvisibleMode.enabled.set(true)
            end
        end
    },

    ["!invisible"] = {
        display = "!invisible [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.LocalPlayer:GetAttribute("is_verified") == false then return end
            if not g.InvisibleMode then return end
            if not g.InvisibleMode.enabled.get() then
                g.InvisibleMode.enabled.set(true)
            end
        end
    },

    ["!remove"] = {
        display = "!remove [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            local blank_pants = 15885405395
            local blank_shirt = 15821796333
            local current_pants = g.GetWornAssetId("pants")
            local current_shirt = g.GetWornAssetId("shirt")
            if current_pants ~= blank_pants or current_shirt ~= blank_shirt then g.CacheWornClothing() end
            local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
            if Humanoid and Humanoid.Parent and Humanoid:IsDescendantOf(game) then
                local desc = Humanoid:GetAppliedDescription()
                for _, info in ipairs(desc:GetAccessories(true)) do
                    if info.IsLayered then
                        g.Get("wear", info.AssetId, info.AccessoryType.Name .. "Accessory")
                        task.wait(0.45)
                    end
                end
            end
            task.wait(0.25)
            if current_shirt and current_shirt ~= blank_shirt then g.Get("wear", current_shirt, "Shirt") end
            if current_pants and current_pants ~= blank_pants then g.Get("wear", current_pants, "Pants") end
            g.Get("wear", blank_shirt, "Shirt")
            g.Get("wear", blank_pants, "Pants")
        end
    },

    ["!erase"] = {
        display = "!erase [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            local blank_pants = 15885405395
            local blank_shirt = 15821796333
            local current_pants = g.GetWornAssetId("pants")
            local current_shirt = g.GetWornAssetId("shirt")
            if current_pants ~= blank_pants or current_shirt ~= blank_shirt then g.CacheWornClothing() end
            local Humanoid = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("AnimationController") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
            if Humanoid and Humanoid.Parent and Humanoid:IsDescendantOf(game) then
                local desc = Humanoid:GetAppliedDescription()
                for _, info in ipairs(desc:GetAccessories(true)) do
                    if info.IsLayered then
                        g.Get("wear", info.AssetId, info.AccessoryType.Name .. "Accessory")
                        task.wait(0.45)
                    end
                end
            end
            task.wait(0.25)
            if current_shirt and current_shirt ~= blank_shirt then
                g.Get("wear", current_shirt, "Shirt")
            end
            if current_pants and current_pants ~= blank_pants then
                g.Get("wear", current_pants, "Pants")
            end
            g.Get("wear", blank_shirt, "Shirt")
            g.Get("wear", blank_pants, "Pants")
        end
    },

    ["!restore"] = {
        display = "!restore [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            local blank_pants = 15885405395
            local blank_shirt = 15821796333
            local cached_pants = g.GetCachedClothingId("pants")
            local cached_shirt = g.GetCachedClothingId("shirt")
            local current_pants = g.GetWornAssetId("pants")
            local current_shirt = g.GetWornAssetId("shirt")
            if current_shirt == blank_shirt and cached_shirt then g.Get("wear", cached_shirt, "Shirt") end
            if current_pants == blank_pants and cached_pants then g.Get("wear", cached_pants, "Pants") end
            for _, item in ipairs(g.GetCachedLayered()) do
                g.Get("wear", item.AssetId, item.AccessoryType .. "Accessory")
                task.wait(0.45)
            end
        end
    },

    ["!fix"] = {
        display = "!fix [player]",
        run = function(args)
            local target = args[2]
            if not g.is_me(target) then return end
            if g.Fix_Camera_Head_Cooldown_Plr_Active then return end
            g.Fix_Camera_Head_Cooldown_Plr_Active = true
            local head = g.Head or g.Character and g.Character:FindFirstChild("Head") or g.get_head(LocalPlayer) or g.Char:get_head()
            if not head or not head.Parent then return end
            local hum = g.Humanoid or g.Character and g.Character:FindFirstChildWhichIsA("Humanoid") or g.get_human(LocalPlayer)
            if not hum or not hum.Parent or not hum:IsDescendantOf(game) then return end -- can still break if not checked with IsDescendantOf(game or workspace) (either one works)
            local root = g.HumanoidRootPart or g.Character and g.Character:FindFirstChild("HumanoidRootPart") or g.get_root(LocalPlayer)
            if not root or not root.Parent then return end
            workspace.CurrentCamera:remove()
            wait(.1)
            repeat wait() until LocalPlayer.Character ~= nil
            workspace.CurrentCamera.CameraSubject = g.Humanoid or g.Character and g.Character:FindFirstChildWhichIsA("Humanoid") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
            workspace.CurrentCamera.CameraType = "Custom"
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 99999
            LocalPlayer.CameraMode = "Classic"
            head.Anchored = false
            if hum and hum.Parent and hum:IsDescendantOf(game) then pcall(function() hum.WalkSpeed = 16 end) end
            if root and root.Parent then pcall(function() root.Anchored = false end) end
            task.delay(5, function() g.Fix_Camera_Head_Cooldown_Plr_Active = false end)
        end
    }
}

g.run_command = function(cmdName, args, sender)
    local data = commands[cmdName]
    if data then
        data.run(args, sender)
    end
end

g.commands_menu_for_administrators_and_staffs = g.commands_menu_for_administrators_and_staffs or function()
    if g.CommandsMenuGui and g.CommandsMenuGui:IsA("ScreenGui") then
        g.CoreGui:FindFirstChild("CommandsMenu").Enabled = true
        return 
    end

    local Commands_Menu_For_Administration_Listing = Instance.new("ScreenGui")
    Commands_Menu_For_Administration_Listing.Name = "CommandsMenu"
    Commands_Menu_For_Administration_Listing.ResetOnSpawn = false
    Commands_Menu_For_Administration_Listing.Parent = CoreGui or g.CoreGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 300, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Parent = Commands_Menu_For_Administration_Listing
    wait(0.45)
    if g.dragify and typeof(g.dragify) == "function" then g.dragify(MainFrame) end
    g.CommandsMenuGui = Commands_Menu_For_Administration_Listing

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, -10, 0, 20)
    Subtitle.Position = UDim2.new(0, 5, 0, 35)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Commands only work on other Yadsan Hub users."
    Subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    Subtitle.TextScaled = true
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextWrapped = true
    Subtitle.Parent = MainFrame

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -10, 0, 30)
    Title.Position = UDim2.new(0, 5, 0, 5)
    Title.BackgroundTransparency = 1
    Title.Text = "Commands Menu"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame

    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 25, 0, 25)
    CloseButton.Position = UDim2.new(1, -30, 0, 5)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextScaled = true
    CloseButton.Parent = MainFrame
    CloseButton.MouseButton1Click:Connect(function()
        Commands_Menu_For_Administration_Listing.Enabled = false
    end)
    wait(0.5)
    g.make_round(CloseButton)

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollFrame"
    ScrollFrame.Position = UDim2.new(0, 5, 0, 65)
    ScrollFrame.Size = UDim2.new(1, -10, 1, -75)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 5)
    UIListLayout.Parent = ScrollFrame

    for _, data in pairs(commands) do
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -10, 0, 30)
        Label.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.Text = data.display
        Label.Font = Enum.Font.Gotham
        Label.TextScaled = true
        Label.TextWrapped = true
        Label.Parent = ScrollFrame

        local LabelCorner = Instance.new("UICorner")
        LabelCorner.CornerRadius = UDim.new(0, 5)
        LabelCorner.Parent = Label
    end

    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 5)
    end)
end

if g.Message_Received_Conn_Owner_Commands_Setup then
    pcall(function() g.Message_Received_Conn_Owner_Commands_Setup:Disconnect() end)
    g.Message_Received_Conn_Owner_Commands_Setup = nil
end
wait(0.25)
g.Message_Received_Conn_Owner_Commands_Setup = TextChatService.MessageReceived:Connect(function(message)
    local source = message.TextSource
    if not source then return end
    local sender = Players:GetPlayerByUserId(source.UserId)
    if not sender or not allowed[sender.Name] then return end
    local text = message.Text
    if type(text) ~= "string" or text == "" then return end
    local args = text:split(" ")
    local cmdName = string.lower(args[1])
    local data = commands[cmdName]
    if data then
        data.run(args, sender)
    end
end)

if g.Administrator_Staff_Message_Received_Commands_Section then
    pcall(function() g.Administrator_Staff_Message_Received_Commands_Section:Disconnect() end)
    g.Administrator_Staff_Message_Received_Commands_Section = nil
end
wait(0.25)
g.Administrator_Staff_Message_Received_Commands_Section = TextChatService.MessageReceived:Connect(function(message)
    local source = message.TextSource
    if not source then return end

    local sender = Players:GetPlayerByUserId(source.UserId)
    if not sender then return end
    if sender ~= LocalPlayer then return end
    if not allowed[sender.Name] then return end
    local text = message.Text
    if type(text) ~= "string" or text == "" then return end
    if text == "?flamescmds" then
        g.commands_menu_for_administrators_and_staffs()
    end
end)

if Bindable and Bindable:IsA("BindableEvent") then
    if g.Bindable_Event_Run_Command_LocalPlayer_Connection then
        pcall(function() g.Bindable_Event_Run_Command_LocalPlayer_Connection:Disconnect() end)
        g.Bindable_Event_Run_Command_LocalPlayer_Connection = nil
    end
    wait(0.25)
    g.Bindable_Event_Run_Command_LocalPlayer_Connection = Bindable.Event:Connect(function(cmdName, args)
        if type(cmdName) ~= "string" or type(args) ~= "table" then return end
        g.run_command(cmdName, args, nil)
    end)
end

if g.get_enrolled_state == nil then
    g.notify("Info", "Waiting until 'get_enrolled_state' exists...", 5)
    local attempts = 0
    local max_attempts = 15
    repeat
        task.wait()
        attempts = attempts + 1
    until (g.get_enrolled_state and g.get_enrolled_state ~= nil) or attempts >= max_attempts
    if g.get_enrolled_state then
        g.notify("Success", "Found get_enrolled_state correctly.", 5)
    else
        g.notify("Error", "get_enrolled_state not found after "..tostring(max_attempts).." attempts.", 5)
    end
end

if CoreGui:FindFirstChild("FlamesAdminGUI", true) and CoreGui:FindFirstChild("FlamesAdminGUI", true):IsA("ScreenGui") then CoreGui:FindFirstChild("FlamesAdminGUI", true).Enabled = true end
g.get_other_vehicle = g.get_other_vehicle or function(Player)
    for _, v in pairs(g.Workspace:FindFirstChild("Vehicles"):GetChildren()) do
        local owner_object = v:FindFirstChild("owner") or v:FindFirstChild("owner", true)
        if owner_object and owner_object.Value == Player then return v end
    end

    return nil
end

local RGB_KEY = "rgb_phone_loop"
g.change_phone_color = g.change_phone_color or function(New_Color) g.Send("phone_color", New_Color) end
g.RGB_Phone = g.RGB_Phone or function(Boolean)
    local lib = g.FlamesLibrary

    if Boolean == true then
        if g.RGB_Rainbow_Phone then g.notify("Warning", "RGB/Rainbow Phone is already enabled.", 3); return end
        g.RGB_Rainbow_Phone = true
        g.notify("Success", "Started RGB/Rainbow Phone.", 3)
        lib.spawn(RGB_KEY, "spawn", function()
            while g.RGB_Rainbow_Phone == true do
                for _, color in ipairs(g.colors) do
                    if g.RGB_Rainbow_Phone ~= true then return end
                    g.change_phone_color(color)
                    fw(0)
                end
            end
        end)
    elseif Boolean == false then
        if not g.RGB_Rainbow_Phone then g.notify("Warning", "RGB/Rainbow Phone is not enabled.", 3); return end
        g.RGB_Rainbow_Phone = false
        lib.disconnect(RGB_KEY)
        g.notify("Success", "Stopped RGB/Rainbow Phone.", 3)
        fw(0.1)
        g.change_phone_color(Color3.fromRGB(255, 255, 255))
    end
end

g.Find_DAISE_Integration_Folder = function()
    local cache = g.DAISE_Integration_Folder_Main_WS
    if cache and cache:IsA("Folder") then return cache end

    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("Folder") and v.Name:lower():find("daise") then
            g.DAISE_Integration_Folder_Main_WS = v
            return v
        end
    end

    return nil
end
wait(0.1)
if not g.DAISE_Integration_Folder_Main_WS then pcall(function() g.Find_DAISE_Integration_Folder() end) end

g.Find_DAISE_Main_NPC_Model = function()
    local cache = g.DAISE_NPC_Model_Found
    if cache and cache.Parent and cache:IsA("Model") then return cache end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find("npc") and v.Parent.Name:lower():find("daise") then
            g.DAISE_NPC_Model_Found = v
            return v
        end
    end

    return nil
end
wait(0.1)
if not g.DAISE_NPC_Model_Found then pcall(function() g.Find_DAISE_Main_NPC_Model() end) end

g.Find_Persistent_Model_For_DAISE = function()
    local cache = g.DAISE_Persistent_Model_Found
    if cache and cache.Parent and cache:IsA("Model") then return cache end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find("persistent") and v.Parent.Name:lower():find("challenge") then
            g.DAISE_Persistent_Model_Found = v
            return v
        end
    end

    return nil
end
wait(0.1)
if not g.DAISE_Persistent_Model_Found then pcall(function() g.Find_Persistent_Model_For_DAISE() end) end

g.Hide_DAISE_Area = function(state)
    if g.DAISE_Area_Hidden == state then g.notify("Warning", state and "DAISE Area is already hidden." or "DAISE Area is already visible.", 3); return end
    local folder = g.DAISE_Integration_Folder_Main_WS or g.Find_DAISE_Integration_Folder()
    if not folder or not folder:IsA("Folder") then g.notify("Error", "DAISE Integration folder not found.", 3); return end
    local npc = g.DAISE_NPC_Model_Found or g.Find_DAISE_Main_NPC_Model()
    if not npc or not npc:IsA("Model") then g.notify("Error", "DAISE NPC Model not found.", 3); return end
    local persistent = g.DAISE_Persistent_Model_Found or g.Find_Persistent_Model_For_DAISE()
    if persistent then
        for _, v in ipairs(persistent:GetChildren()) do
            if v:IsA("Folder") and v.Name:lower():find("display") then
                v:Destroy()
            end
        end
    end
    for _, v in ipairs(npc:GetDescendants()) do
        if v.Name == "TouchPart" then
            v.Transparency = 1
            v.CanCollide = false
            for _, child in ipairs(v:GetChildren()) do
                if child:IsA("TouchTransmitter") then
                    child:Destroy()
                end
            end
        elseif v.Name == "HumanoidRootPart" then
            v.CanCollide = false
        end
    end
    for _, v in ipairs(folder:GetDescendants()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and v.Name ~= "TouchPart" and v.Name ~= "DAISESlogan" and v.Name ~= "DAISEBeautyArea" then
            local has_banner_decal = false
            for _, child in ipairs(v:GetChildren()) do
                if child:IsA("Decal") and child.Texture == "rbxassetid://133336087393319" then
                    has_banner_decal = true
                    break
                end
            end
            if has_banner_decal then
                v.Transparency = 1
                v.CanCollide = false
            else
                v.Transparency = state and 1 or 0
                v.CanCollide = not state
            end
        elseif v:IsA("Decal") then
            v.Transparency = state and 1 or 0
        elseif v:IsA("SurfaceGui") then
            v.Enabled = not state
        end
    end
    g.DAISE_Area_Hidden = state
    g.notify("Success", state and "DAISE Area Hidden" or "DAISE Area Shown", 3)
end

g.steal_car_functionality = function(target_plr)
    local selected_player = nil
    if typeof(target_plr) == "Instance" and target_plr:IsA("Player") then
        selected_player = target_plr
    elseif typeof(target_plr) == "string" then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr.Name == target_plr then
                selected_player = plr
                break
            end
        end
    end

    if not selected_player then return end
    for _, vehicle in pairs(Workspace:FindFirstChild("Vehicles"):GetChildren()) do
        local seat = vehicle:FindFirstChild("VehicleSeat") or vehicle:FindFirstChild("VehicleSeat", true)
        if not seat then g.notify("Error", "We could not find VehicleSeat in this Vehicle.", 3); return end
        local owner_object = vehicle:FindFirstChild("owner")
        if not owner_object or not owner_object:IsA("ObjectValue") then g.notify("Error", "ObjectValue: owner not found or does not exist.", 3); return end
        if owner_object.Value == selected_player then
            if seat.Occupant == nil and vehicle:GetAttribute("locked") == false then
                local ok, response = pcall(function() g.Get("sit", seat) end)
                if not ok and g.notify then g.notify("Error", tostring(response), 15) end
                break
            else
                g.notify("Error", "Someone is already in this Vehicle, try again when they are not sitting in it.", 8)
                break
            end
        end
    end
end

g.save_outfits_GUI = function()
    if parent_gui:FindFirstChild("OutfitManagerUI", true) and parent_gui:FindFirstChild("OutfitManagerUI", true):IsA("ScreenGui") then
        parent_gui:FindFirstChild("OutfitManagerUI", true).Enabled = true
        g.notify("Warning", "You're already running Outfits Manager!", 5)
        return
    end
    if g.LoadedOutfit_Manager_GUI then g.notify("Warning", "You're already running Outfits Manager!", 5);  end
    local cached_outfits = {}
    g.ui_refs = {}
    local Send, Get = g.Send, g.Get
    local FolderName = "lifetogether_admin_savedoutfits"
    local function save_outfit(name, outfit, callback)
        if not isfolder(FolderName) then makefolder(FolderName) end
        local filePath = FolderName .. "/" .. name .. ".json"
        if isfile(filePath) then
            cached_outfits[name] = outfit
            if callback then callback(true) end
            return
        end
        local ok = pcall(function() writefile(filePath, HttpService:JSONEncode(outfit)) end)
        cached_outfits[name] = outfit
        if callback then callback(ok) end
    end

    local function delete_outfit(name, callback)
        local ok = pcall(function() if isfile(FolderName .. "/" .. name .. ".json") then delfile(FolderName .. "/" .. name .. ".json") end end)
        cached_outfits[name] = nil
        if callback then callback(ok) end
    end

    local function rename_outfit(old_name, new_name, callback)
        if not cached_outfits[old_name] then
            if callback then callback(false, "Outfit not found") end
            return
        end
        if cached_outfits[new_name] then
            if callback then callback(false, "Name already taken") end
            return
        end
        local outfit = cached_outfits[old_name]
        if not isfolder(FolderName) then makefolder(FolderName) end
        local ok = pcall(function()
            writefile(FolderName .. "/" .. new_name .. ".json", HttpService:JSONEncode(outfit))
            if isfile(FolderName .. "/" .. old_name .. ".json") then
                delfile(FolderName .. "/" .. old_name .. ".json")
            end
        end)
        if ok then
            cached_outfits[new_name] = outfit
            cached_outfits[old_name] = nil
        end
        if callback then callback(ok) end
    end

    local function fetch_outfit_list(callback)
        cached_outfits = {}
        if not isfolder(FolderName) then
            if callback then callback(true) end
            return
        end
        for _, f in ipairs(listfiles(FolderName)) do
            if f:match("%.json$") then
                local name = f:match("([^/\\]+)%.json$")
                local ok, content = pcall(readfile, f)
                if ok and content and #content > 0 then
                    local success, data = pcall(function() return HttpService:JSONDecode(content) end)
                    if success and type(data) == "table" then cached_outfits[name] = data end
                end
            end
        end
        if callback then callback(true) end
    end

    local function buildBatchPayload(data)
        local accessories = {}
        local order = 1
        if data.Accessories then
            for _, acc in ipairs(data.Accessories) do
                local isLayered = acc.IsLayered == true
                table.insert(accessories, {
                    AssetId = acc.AssetId,
                    AccessoryType = acc.AccessoryType,
                    IsLayered = isLayered,
                    Rotation = "  ",
                    Position = "  ",
                    Scale = "1 1 1",
                    Order = isLayered and order or nil,
                    Puffiness = isLayered and 0 or nil
                })
                if isLayered then order = order + 1 end
            end
        end
        return {
            accessories = accessories,
            properties = {
                Head = data.Head or 0,
                Torso = data.Torso or 0,
                LeftArm = data.LeftArm or 0,
                RightArm = data.RightArm or 0,
                LeftLeg = data.LeftLeg or 0,
                RightLeg = data.RightLeg or 0,
                Face = data.Face or 0,
                Shirt = data.Shirt or 0,
                Pants = data.Pants or 0,
                GraphicTShirt = data.GraphicTShirt or 0,
                RunAnimation = data.RunAnimation or 0,
                WalkAnimation = data.WalkAnimation or 0,
                JumpAnimation = data.JumpAnimation or 0,
                FallAnimation = data.FallAnimation or 0,
                ClimbAnimation = data.ClimbAnimation or 0,
                IdleAnimation = data.IdleAnimation or 0,
                SwimAnimation = data.SwimAnimation or 0,
                HeightScale = data.HeightScale or 1,
                WidthScale = data.WidthScale or 1,
                DepthScale = 1,
                HeadScale = 1,
                BodyTypeScale = 0,
                ProportionScale = 0,
                HeadColor = ";<,#",
                TorsoColor = ";<,#",
                LeftArmColor = ";<,#",
                RightArmColor = ";<,#",
                LeftLegColor = ";<,#",
                RightLegColor = ";<,#",
            }
        }
    end

    local function promptOutfitName(callback)
        local popup = Instance.new("ScreenGui")
        popup.Name = "OutfitNamePrompt"
        popup.IgnoreGuiInset = true
        popup.ResetOnSpawn = false
        popup.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        popup.Parent = parent_gui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 250, 0, 130)
        frame.Position = UDim2.new(0.5, -125, 0.5, -65)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.Parent = popup
        Instance.new("UICorner", frame)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 0, 30)
        title.Position = UDim2.new(0, 5, 0, 5)
        title.BackgroundTransparency = 1
        title.Text = "Enter Outfit Name"
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.Parent = frame

        local txt = Instance.new("TextBox")
        txt.PlaceholderText = "Outfit Name"
        txt.Size = UDim2.new(1, -20, 0, 35)
        txt.Position = UDim2.new(0, 10, 0, 40)
        txt.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        txt.TextColor3 = Color3.new(1, 1, 1)
        txt.Font = Enum.Font.Gotham
        txt.TextScaled = true
        txt.ClearTextOnFocus = true
        txt.Text = ""
        txt.Parent = frame
        Instance.new("UICorner", txt)

        local save_btn = Instance.new("TextButton")
        save_btn.Size = UDim2.new(1, -20, 0, 35)
        save_btn.Position = UDim2.new(0, 10, 0, 85)
        save_btn.Text = "Save"
        save_btn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
        save_btn.TextColor3 = Color3.new(1, 1, 1)
        save_btn.Font = Enum.Font.GothamBold
        save_btn.TextScaled = true
        save_btn.Parent = frame
        Instance.new("UICorner", save_btn)

        save_btn.MouseButton1Click:Connect(function()
            local name = txt.Text:gsub("%s+", "")
            if name ~= "" then
                popup:Destroy()
                task.wait()
                callback(name)
            else
                g.notify("Error", "Enter a valid outfit name.", 5)
            end
        end)
    end

    local function fuzzy_match(name, query)
        local j = 1
        local qlen = #query
        for i = 1, #name do
            if name:sub(i, i) == query:sub(j, j) then
                j = j + 1
                if j > qlen then return true end
            end
        end
        return false
    end

    local function refreshOutfitList()
        local scroller = g.ui_refs.scroller
        if not scroller then g.notify("Warning", "Scroller missing from UI.", 3); return end
        local query = ""
        if g.ui_refs.searchbox then query = string.lower(g.ui_refs.searchbox.Text or "") end
        for _, child in ipairs(scroller:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        local visible_count = 0
        for name, outfitData in pairs(cached_outfits) do
            local lowered_name = string.lower(name)
            if query ~= "" then
                local exact_match = string.find(lowered_name, query, 1, true)
                local fuzzy_result = fuzzy_match(lowered_name, query)
                if not exact_match and not fuzzy_result then continue end
            end

            visible_count = visible_count + 1
            local entry = Instance.new("Frame")
            entry.Size = UDim2.new(1, -5, 0, 35)
            entry.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            entry.Parent = scroller
            Instance.new("UICorner", entry)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0.35, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = name
            label.TextColor3 = Color3.new(1, 1, 1)
            label.Font = Enum.Font.Gotham
            label.TextScaled = true
            label.Parent = entry

            local wearBtn = Instance.new("TextButton")
            wearBtn.Size = UDim2.new(0.25, -30, 1, -10)
            wearBtn.Position = UDim2.new(0.5, 40, 0, 7)
            wearBtn.Text = "Wear"
            wearBtn.BackgroundColor3 = Color3.fromRGB(249, 232, 0)
            wearBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
            wearBtn.Font = Enum.Font.Gotham
            wearBtn.TextScaled = true
            wearBtn.Parent = entry
            Instance.new("UICorner", wearBtn)

            local renameBtn = Instance.new("TextButton")
            renameBtn.Size = UDim2.new(0.25, -30, 1, -8)
            renameBtn.Position = UDim2.new(0, 180, 0, 7)
            renameBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
            renameBtn.TextColor3 = Color3.new(1, 1, 1)
            renameBtn.Font = Enum.Font.SourceSansBold
            renameBtn.TextScaled = true
            renameBtn.Text = "Rename"
            renameBtn.Parent = entry
            Instance.new("UICorner", renameBtn)

            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.new(0.25, -30, 1, -10)
            delBtn.Position = UDim2.new(0, 380, 0.2, 0)
            delBtn.Text = "Delete"
            delBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            delBtn.TextColor3 = Color3.new(1, 1, 1)
            delBtn.Font = Enum.Font.Gotham
            delBtn.TextScaled = true
            delBtn.Parent = entry
            Instance.new("UICorner", delBtn)

            wearBtn.MouseButton1Click:Connect(function()
                if g.is_busy_outfit_manager then g.notify("Warning", "Busy, wait!", 3); return end
                g.is_busy_outfit_manager = true
                local data = outfitData
                if not data or type(data) ~= "table" then
                    g.is_busy_outfit_manager = false
                    g.notify("Error", "Invalid outfit data!", 3)
                    return
                end

                g.clear_avatar()
                task.wait(1)
                local payload = buildBatchPayload(data)
                for i = 1, math.random(1, 6) do
                    Send("wear_outfit_from_desc", payload)
                    task.wait(0.1)
                end
                task.wait(0.2)
                if data.SkinTone then
                    pcall(function()
                        local c = Color3.new(data.SkinTone[1], data.SkinTone[2], data.SkinTone[3])
                        for i = 1, 3 do Send("skin_tone", c); task.wait(0.1) end
                    end)
                    task.wait(0.3)
                end

                if data.Age then
                    pcall(function()
                        Get("age", tostring(data.Age))
                        task.wait(0.3)
                        Get("age", tostring(data.Age))
                    end)
                    task.wait(0.3)
                end
                task.wait(0.1)
                if data.HeightScale then
                    pcall(function()
                        for i = 1, 3 do Send("body_scale", "HeightScale", data.HeightScale * 100); task.wait(0.15) end
                    end)
                end
                task.wait(0.1)
                if data.WidthScale then
                    pcall(function()
                        for i = 1, 3 do Send("body_scale", "WidthScale", data.WidthScale * 100); task.wait(0.15) end
                    end)
                end
                task.wait(0.2)
                g.is_busy_outfit_manager = false
                g.notify("Success", "Outfit applied successfully!", 5)
            end)

            renameBtn.MouseButton1Click:Connect(function()
                if g.is_busy_outfit_manager then g.notify("Warning", "Busy, wait!", 3); return end
                g.is_busy_outfit_manager = true
                promptOutfitName(function(newName)
                    if not newName or newName == "" then
                        g.is_busy_outfit_manager = false
                        g.notify("Error", "Invalid new name!", 3)
                        return
                    end
                    if cached_outfits[newName] then
                        g.is_busy_outfit_manager = false
                        g.notify("Error", "An outfit with that name already exists!", 3)
                        return 
                    end
                    rename_outfit(name, newName, function(success, reason)
                        g.is_busy_outfit_manager = false
                        if success then
                            g.notify("Success", "Outfit renamed to: "..tostring(newName), 3)
                            refreshOutfitList()
                        else
                            g.notify("Error", "Failed to rename: " .. (reason or "unknown error"), 3)
                        end
                    end)
                end)
            end)

            local delete_armed = false
            delBtn.MouseButton1Click:Connect(function()
                if not delete_armed then
                    delete_armed = true
                    g.notify("Warning", "Click again to confirm delete: " .. name, 5)
                    task.delay(5, function() delete_armed = false end)
                else
                    delete_outfit(name, function(success)
                        if success then
                            g.notify("Success", "Deleted outfit: " .. name, 5)
                            refreshOutfitList()
                        else
                            g.notify("Error", "Failed to delete outfit.", 4)
                        end
                    end)
                end
            end)
        end
        if g.ui_refs.noOutfitsLabel then g.ui_refs.noOutfitsLabel.Visible = visible_count == 0 end
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "OutfitManagerUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent_gui
    g.LoadedOutfit_Manager_GUI = true

    local OutfitManagerFrameMain = Instance.new("Frame")
    OutfitManagerFrameMain.Size = UDim2.new(0, 500, 0, 400)
    OutfitManagerFrameMain.Position = UDim2.new(0.5, -250, 0.5, -200)
    OutfitManagerFrameMain.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    OutfitManagerFrameMain.BorderSizePixel = 0
    OutfitManagerFrameMain.Parent = ScreenGui
    Instance.new("UICorner", OutfitManagerFrameMain)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundTransparency = 1
    Title.Text = "Outfits Manager V2"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.GothamBold
    Title.TextScaled = true
    Title.TextSize = 18
    Title.Parent = OutfitManagerFrameMain

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -35, 0, 5)
    CloseButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 0, 0)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextScaled = true
    CloseButton.Parent = OutfitManagerFrameMain
    Instance.new("UICorner", CloseButton)

    CloseButton.MouseButton1Click:Connect(function()
        g.is_busy_outfit_manager = false
        ScreenGui:Destroy()
        g.LoadedOutfit_Manager_GUI = false
    end)



    local SaveButton = Instance.new("TextButton")
    SaveButton.Size = UDim2.new(0.5, -5, 0, 35)
    SaveButton.Position = UDim2.new(0, 5, 0, 40)
    SaveButton.Text = "Save Outfit"
    SaveButton.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
    SaveButton.TextColor3 = Color3.new(1, 1, 1)
    SaveButton.Font = Enum.Font.Gotham
    SaveButton.TextScaled = true
    SaveButton.TextSize = 16
    SaveButton.Parent = OutfitManagerFrameMain
    Instance.new("UICorner", SaveButton)

    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(0.5, -5, 0, 35)
    RefreshButton.Position = UDim2.new(0.5, 0, 0, 40)
    RefreshButton.Text = "Refresh"
    RefreshButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    RefreshButton.TextColor3 = Color3.new(1, 1, 1)
    RefreshButton.Font = Enum.Font.Gotham
    RefreshButton.TextScaled = true
    RefreshButton.TextSize = 16
    RefreshButton.Parent = OutfitManagerFrameMain
    Instance.new("UICorner", RefreshButton)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -10, 0, 30)
    SearchBox.Position = UDim2.new(0, 5, 0, 75)
    SearchBox.PlaceholderText = "Search outfits..."
    SearchBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    SearchBox.TextColor3 = Color3.new(1, 1, 1)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextScaled = true
    SearchBox.ClearTextOnFocus = false
    SearchBox.Text = ""
    SearchBox.Parent = OutfitManagerFrameMain
    Instance.new("UICorner", SearchBox)

    g.ui_refs.searchbox = SearchBox
    g.ui_refs.frame = OutfitManagerFrameMain
    if g.dragify and typeof(g.dragify) == "function" then g.dragify(OutfitManagerFrameMain) end
    SearchBox:GetPropertyChangedSignal("Text"):Connect(refreshOutfitList)

    local scroller = Instance.new("ScrollingFrame")
    scroller.Position = UDim2.new(0, 5, 0, 110)
    scroller.Size = UDim2.new(1, -10, 1, -120)
    scroller.BackgroundTransparency = 1
    scroller.BorderSizePixel = 0
    scroller.ScrollBarThickness = 6
    scroller.ScrollingDirection = Enum.ScrollingDirection.Y
    scroller.Parent = OutfitManagerFrameMain

    g.ui_refs.scroller = scroller

    local noOutfitsLabel = Instance.new("TextLabel")
    noOutfitsLabel.Size = UDim2.new(1, 0, 0, 40)
    noOutfitsLabel.Position = UDim2.new(0, 0, 0, 10)
    noOutfitsLabel.BackgroundTransparency = 1
    noOutfitsLabel.Text = "No saved outfits."
    noOutfitsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    noOutfitsLabel.Font = Enum.Font.Gotham
    noOutfitsLabel.TextScaled = true
    noOutfitsLabel.Visible = false
    noOutfitsLabel.Parent = scroller

    g.ui_refs.noOutfitsLabel = noOutfitsLabel

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 6)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIListLayout.Parent = scroller
    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroller.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10) end)
    if g.ui_refs.noOutfitsLabel then
        local has_visible = false
        for _, child in ipairs(scroller:GetChildren()) do
            if child:IsA("Frame") then
                has_visible = true
                break
            end
        end
        noOutfitsLabel.Visible = not has_visible
    end

    SaveButton.MouseButton1Click:Connect(function()
        if g.is_busy_outfit_manager then g.notify("Warning", "Busy, wait!", 3); return end
        g.is_busy_outfit_manager = true
        promptOutfitName(function(name)
            local char = g.Character or g.LocalPlayer.Character or g.get_char(g.LocalPlayer or Players.LocalPlayer, 3) or g.Char:get()
            if not char or not char:FindFirstChildOfClass("Humanoid") then
                g.is_busy_outfit_manager = false
                g.notify("Error", "Character or Humanoid missing!", 3)
                return
            end

            local humanoid = char and char:FindFirstChildOfClass("Humanoid") or g.get_human(Players:GetPlayerFromCharacter(char), Players.RespawnTime + 1)
            local desc = humanoid and humanoid:GetAppliedDescription()
            if not desc then
                g.is_busy_outfit_manager = false
                g.notify("Error", "Failed to get HumanoidDescription!", 3)
                return
            end

            local outfit = {}
            outfit.Accessories = {}
            for _, info in ipairs(desc:GetAccessories(true)) do
                table.insert(outfit.Accessories, {
                    AssetId = info.AssetId,
                    AccessoryType = info.AccessoryType.Name,
                    IsLayered = info.IsLayered
                })
            end

            outfit.Shirt = desc.Shirt
            outfit.Pants = desc.Pants
            outfit.GraphicTShirt = desc.GraphicTShirt
            outfit.Face = desc.Face
            outfit.Head = desc.Head
            outfit.Torso = desc.Torso
            outfit.LeftArm = desc.LeftArm
            outfit.RightArm = desc.RightArm
            outfit.LeftLeg = desc.LeftLeg
            outfit.RightLeg = desc.RightLeg
            outfit.ClimbAnimation = desc.ClimbAnimation
            outfit.FallAnimation = desc.FallAnimation
            outfit.IdleAnimation = desc.IdleAnimation
            outfit.JumpAnimation = desc.JumpAnimation
            outfit.RunAnimation = desc.RunAnimation
            outfit.SwimAnimation = desc.SwimAnimation
            outfit.WalkAnimation = desc.WalkAnimation
            outfit.HeightScale = desc.HeightScale
            outfit.WidthScale = desc.WidthScale

            local hc = desc.HeadColor
            outfit.SkinTone = { hc.R, hc.G, hc.B }
            local age = LocalPlayer:GetAttribute("age")
            if age then outfit.Age = tostring(age) end
            save_outfit(name, outfit, function(success)
                g.is_busy_outfit_manager = false
                if success then
                    g.notify("Success", "Saved outfit: " .. name, 5)
                    refreshOutfitList()
                else
                    g.notify("Error", "Failed to save outfit.", 4)
                end
            end)
        end)
    end)

    RefreshButton.MouseButton1Click:Connect(function()
        fetch_outfit_list(function(success)
            if success then
                refreshOutfitList()
                g.notify("Success", "Outfits refreshed!", 3)
            else
                g.notify("Error", "Failed to fetch outfits.", 4)
            end
        end)
    end)

    fetch_outfit_list(function(success)
        if not success then
            g.notify("Error", "Could not load outfits.", 3)
            return
        end
        refreshOutfitList()
    end)
end

g.already_loaded_workaround_script_flames_hub = g.already_loaded_workaround_script_flames_hub or false
g.already_patched_discord_button = g.already_patched_discord_button or false
g.load_workaround_script = g.load_workaround_script or function()
	if g.already_loaded_workaround_script_flames_hub then g.notify("Warning", "Chat Workaround has already been loaded.", 5); return end
	local hidden_gui_main = gethui and gethui() or get_hidden_gui and get_hidden_gui() or g.CoreGui or g.PlayerGui
	g.already_loaded_workaround_script_flames_hub = true
	loadstring(g.http_get('https://raw.githubusercontent.com/EnterpriseExperience/MicUpSource/refs/heads/main/Deadly_Chat_Backup_Script.lua'))()
    local function patch_button(frame)
        if g.already_patched_discord_button then return end
        for _, desc in ipairs(frame:GetDescendants()) do
            if desc:IsA("ImageButton") and desc.Name == "Discord" and desc.Image == "rbxassetid://7552532178" then
                g.already_patched_discord_button = true
                lib.disconnect("discord_button_activated")
                lib.connect("discord_button_activated", desc.Activated:Connect(function()
                    if http_requesting and typeof(http_requesting) then
                        http_requesting({
                            Url = 'http://127.0.0.1:6463/rpc?v=1',
                            Method = 'POST',
                            Headers = {
                                ['Content-Type'] = 'application/json',
                                Origin = 'https://discord.com'
                            },
                            Body = HttpService:JSONEncode({
                                cmd = 'INVITE_BROWSER',
                                nonce = HttpService:GenerateGUID(false),
                                args = {code = 'MTYKxQfpNJ'}
                            })
                        })
                    else
                        if g.AllClipboards and typeof(g.AllClipboards) == "function" then g.AllClipboards("https://discord.gg/MTYKxQfpNJ") end
                        if g.notify and typeof(g.notify) == "function" then g.notify("Success", "Successfully copied Discord link to Clipboard.", 3) end
                    end
                end))
                break
            end
        end
    end

	local function find_chat_frame()
		for _, gui in ipairs(hidden_gui_main:GetChildren()) do
			if gui:IsA("ScreenGui") then
				local frame = gui:FindFirstChild("Chat System")
				if frame and frame:IsA("Frame") then
                    frame.Draggable = true
                    frame.Position = UDim2.new(0.00741000008, 498, 0.0585100017, -8)
                    if g.dragify and typeof(g.dragify) == "function" then g.dragify(frame) end
					return frame
				end
			end
		end
		return nil
	end

	local chat_frame = find_chat_frame()
	if chat_frame and chat_frame:IsA("Frame") then
		patch_button(chat_frame)
	else
		local conn
		conn = lib.connect(hidden_gui_main, "ChildAdded", function(child)
			if child and child:IsA("ScreenGui") then
				local frame = child:FindFirstChild("Chat System")
				if frame and frame:IsA("Frame") then
					lib.disconnect(conn)
					patch_button(frame)
					return
				end
				lib.connect(child, "ChildAdded", function(grandchild)
					if grandchild.Name == "Chat System" and grandchild:IsA("Frame") then
						lib.disconnect(conn)
						patch_button(grandchild)
					end
				end)
			end
		end)
	end
end

g.Get_WildWood_Mansion = function()
    local cache = g.WildWood_Integration_Mansion_Found
    if cache and cache:IsA("Folder") and cache.Parent then return cache end

    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Folder") and v.Name:lower():find("pittock") and v.Name:lower():find("mansion") then
            g.WildWood_Integration_Mansion_Found = v
            return v
        end
    end

    return nil
end
wait(0.1)
if not g.WildWood_Integration_Mansion_Found then pcall(function() g.Get_WildWood_Mansion() end) end

g.Get_Activation_WildWood_Portal = function()
    local cache = g.WildwoodPortal_Found_Main
    if cache and cache:IsA("Model") and cache.Parent then return cache end

    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find("wildwood") and v.Name:lower():find("portal") then
            local attr = v:GetAttribute("portal_color")
            if attr ~= nil and attr == Color3.fromRGB(151, 126, 91) then
                g.WildwoodPortal_Found_Main = v
                return v
            end
        end
    end

    return nil
end
wait(0.1)
if not g.WildwoodPortal_Found_Main then pcall(function() g.Get_Activation_WildWood_Portal() end) end

g.Find_Paper_To_Collect = function()
    local get_mansion = g.WildWood_Integration_Mansion_Found or g.Get_WildWood_Mansion()
    if not get_mansion or not get_mansion:IsA("Folder") then return end

    for _, v in ipairs(get_mansion:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find("pig") and v.Name:lower():find("paper") and v.Parent.Name:lower():find("paper") then
            return v
        end
    end

    return nil
end

g.Automatically_Complete_WildWood_Event = function()
    local hrp = g.HumanoidRootPart or g.get_root(speaker)
    if not hrp or not hrp.Parent or not hrp:IsDescendantOf(game) then g.notify("Error", "Your HumanoidRootPart is missing! (please reset).", 3); return end
    local get_current_zone = g.LocalPlayer:GetAttribute("current_quest_zone")
    if get_current_zone ~= nil and get_current_zone ~= "pittock_mansion_lobby" then
        pcall(function() hrp.CFrame = CFrame.new(-27.607975, 9.29240894, -37.3550339) end)
        wait(0.1)
        local wild_wood_start_convo = {
            "wildwood_track",
            "npc_convo_started",
            {
                quest_id = "none",
                npc_id = "prue",
                dialogue_variant = "default",
                first_time = false
            }
        }
        g.Send(unpack(wild_wood_start_convo))
        wait(0.15)
        g.Send("spoke_to_prue")
        wait(0.15)
        local convo_ended_main = {
            "wildwood_track",
            "npc_convo_ended",
            {
                completed = true,
                duration_s = 103.52,
                lines_shown = 1,
                npc_id = "prue",
                lines_total = 1
            }
        }
        g.Send(unpack(convo_ended_main))
        wait(0.1)
        g.Send("viewed_mac_abduction")
        wait(0.1)
        g.Send("teleport_to_quest", -1)
        pcall(function() hrp.CFrame = CFrame.new(-0.998277366, 8.96803665, -164.726166) end)
        wait(0.15)
        local portal = g.WildwoodPortal_Found_Main or g.Get_Activation_WildWood_Portal()
        if portal and portal:IsA("Model") and portal:IsDescendantOf(game) then pcall(function() g.Character:PivotTo(portal:GetPivot() + Vector3.new(0, 3, 0)) end) end
        g.notify("Error", "Please start the quest or go to the Pittock Mansion!")
    end
    g.Send("set_wildwood_faction", 3)
    wait(0.1)
    g.Send("start_quest", 1)
    wait(0.1)
    g.Send("teleport_to_quest", 1)
    wait(0.1)
    g.Send("wildwood_track", "npc_convo_started", {
        quest_id = "q1_pittock_mansion",
        npc_id = "pig_clerk",
        dialogue_variant = "default",
        first_time = true
    })
    wait(0.35)
    g.Send("wildwood_track", "npc_convo_ended", {
        completed = true,
        duration_s = 30.23,
        lines_shown = 3,
        npc_id = "pig_clerk",
        lines_total = 3
    })
    wait(0.15)
    g.Send("progress_quest", 1, "meet_pig_clerk")
    wait(0.1)
    local paper = g.Find_Paper_To_Collect()
    if not paper or not paper:IsA("Model") then g.notify("Error", "There appears to be no papers left to collect!", 3); return end
    local pivot_offset = Vector3.new(0, 3, 0)
    local function fire_prompts()
        for _, descendant in ipairs(paper:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") then
                pcall(function()
                    fireproximityprompt(descendant)
                end)
            end
        end
    end

    for _ = 1, 10 do
        pcall(function() g.Character:PivotTo(paper:GetPivot() + pivot_offset) end)
        wait(0.25)
        fire_prompts()
        wait(0.1)
        g.Get("collect_wildwood_item", paper)
        wait(0.35)
    end
end

g.vehicle_fly = g.vehicle_fly or false
g.vehicle_fly_speed = g.vehicle_fly_speed or 3
g.vehiclefly_conns = g.vehiclefly_conns or {}
g.vehiclefly_control = {f=0,b=0,l=0,r=0,q=0,e=0}
g.vehiclefly_noclip = g.vehiclefly_noclip or false
g.vehiclefly_collisions = g.vehiclefly_collisions or {}
local controlModule
if UserInputService.TouchEnabled then controlModule = require(g.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule")) end
g.cleanup = g.cleanup or function()
    for _, c in pairs(g.vehiclefly_conns) do
        pcall(function() c:Disconnect() end)
    end
    g.vehiclefly_conns = {}
    if g.vehiclefly_bv then
        g.vehiclefly_bv.Velocity = Vector3.zero
        g.vehiclefly_bv:Destroy()
        g.vehiclefly_bv = nil
    end

    if g.vehiclefly_bg then
        g.vehiclefly_bg:Destroy()
        g.vehiclefly_bg = nil
    end
end

g.enable_vehicle_noclip = g.enable_vehicle_noclip or function()
    if g.vehiclefly_noclip then return end
    g.vehiclefly_noclip = true
    g.vehiclefly_collisions = {}
    local car = g.get_vehicle()
    if not car then return end
    if g.ToggleNoclip and typeof(g.ToggleNoclip) == "function" then g.ToggleNoclip(true) end
    for _, v in ipairs(car:GetDescendants()) do
        if v:IsA("BasePart") then
            g.vehiclefly_collisions[v] = v.CanCollide
            v.CanCollide = false
        end
    end
end

g.disable_vehicle_noclip = g.disable_vehicle_noclip or function()
    if not g.vehiclefly_noclip then return end
    g.vehiclefly_noclip = false
    if g.ToggleNoclip and typeof(g.ToggleNoclip) == "function" then g.ToggleNoclip(false) end
    for part, state in pairs(g.vehiclefly_collisions) do if part and part.Parent then part.CanCollide = state end end
    g.vehiclefly_collisions = {}
end

g.start_vehicle_fly = g.start_vehicle_fly or function()
    if g.vehiclefly_bg or g.vehiclefly_bv then return end
    local car = g.get_vehicle()
    if not car then
        g.disable_vehicle_noclip()
        task.wait()
        g.cleanup()
        pcall(function() g.notify("Error", "You do not have a Vehicle spawned.", 3) end)
        return
    end
    local base = car.Base or car:FindFirstChild("Base")
    local bg = Instance.new("BodyGyro")
    bg.P = 3e4
    bg.D = 1e3
    bg.MaxTorque = Vector3.new(0, 9e9, 0)
    bg.CFrame = base.CFrame
    bg.Parent = base

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero
    bv.Parent = base

    g.vehiclefly_bg = bg
    g.vehiclefly_bv = bv
    g.vehiclefly_conns.render = RunService.Heartbeat:Connect(function()
        if not g.vehicle_fly or not base.Parent then
            bv.Velocity = Vector3.zero
            g.vehiclefly_control = {f=0,b=0,l=0,r=0,q=0,e=0}
            if not base.Parent then
                if g.main_vehicle_fly_UI_toggle then g.main_vehicle_fly_UI_toggle:Set(false, false) end
                if g.stop_vehicle_fly then
                    g.stop_vehicle_fly()
                else
                    g.cleanup()
                end
            end
            return
        end

        base.AssemblyAngularVelocity = Vector3.zero
        local cam = workspace.CurrentCamera

        if IsMobile then
            bg.CFrame = cam.CFrame
            local mv = controlModule:GetMoveVector()
            local vel = Vector3.zero
            if mv.X ~= 0 then vel = vel + cam.CFrame.RightVector * (mv.X * (45 * g.vehicle_fly_speed)) end
            if mv.Z ~= 0 then vel = vel - cam.CFrame.LookVector * (mv.Z * (45 * g.vehicle_fly_speed)) end
            bv.Velocity = vel
        else
            local look = cam.CFrame.LookVector
            local yaw = math.atan2(-look.X, -look.Z)
            bg.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, yaw, 0)
            local c = g.vehiclefly_control
            local forward = (c.f or 0) + (c.b or 0)
            local right = (c.l or 0) + (c.r or 0)
            local up = (c.q or 0) + (c.e or 0)

            bv.Velocity = (cam.CFrame.LookVector * forward + cam.CFrame.RightVector * right + Vector3.new(0, up, 0)) * (45 * g.vehicle_fly_speed)
        end
    end)

    if not IsMobile then
        g.vehiclefly_conns.down = UserInputService.InputBegan:Connect(function(i, game_processed)
            if game_processed then return end
            if i.KeyCode == Enum.KeyCode.W then g.vehiclefly_control.f = 1  end
            if i.KeyCode == Enum.KeyCode.S then g.vehiclefly_control.b = -1 end
            if i.KeyCode == Enum.KeyCode.A then g.vehiclefly_control.l = -1 end
            if i.KeyCode == Enum.KeyCode.D then g.vehiclefly_control.r = 1  end
            if i.KeyCode == Enum.KeyCode.E then g.vehiclefly_control.q = 1  end
            if i.KeyCode == Enum.KeyCode.Q then g.vehiclefly_control.e = -1 end
        end)

        g.vehiclefly_conns.up = UserInputService.InputEnded:Connect(function(i)
            if i.KeyCode == Enum.KeyCode.W then g.vehiclefly_control.f = 0 end
            if i.KeyCode == Enum.KeyCode.S then g.vehiclefly_control.b = 0 end
            if i.KeyCode == Enum.KeyCode.A then g.vehiclefly_control.l = 0 end
            if i.KeyCode == Enum.KeyCode.D then g.vehiclefly_control.r = 0 end
            if i.KeyCode == Enum.KeyCode.E then g.vehiclefly_control.q = 0 end
            if i.KeyCode == Enum.KeyCode.Q then g.vehiclefly_control.e = 0 end
        end)
    end
end

g.stop_vehicle_fly = g.stop_vehicle_fly or function()
    g.vehicle_fly = false
    g.disable_vehicle_noclip()
    g.cleanup()
    g.vehiclefly_control = {f=0,b=0,l=0,r=0,q=0,e=0}
end

g.toggle_vehicle_fly = g.toggle_vehicle_fly or function()
    if g.vehicle_fly then
        g.stop_vehicle_fly()
    else
        g.vehicle_fly = true
        g.enable_vehicle_noclip()
        g.start_vehicle_fly()
    end
end

g.owner_in_game = g.owner_in_game or function(user)
    local target = tostring(user):lower()
    for _, v in ipairs(Players:GetPlayers()) do
        if v.Name:lower() == target then
            return true
        end
    end

    return false
end

g.streamer_mode_script = g.streamer_mode_script or function()
    if g.hidden_loaded then g.notify("Warning", "Streamer Mode script is already loaded.", 3); return end
    loadstring(g.http_get("https://pastebin.com/raw/kVYwGVcy"))()
end

g.unload_streamer_mode_script = g.unload_streamer_mode_script or function()
    if g.hidden_settings then
        local h = g.hidden_settings
        if h.Enabled then h.Enabled = false end
        for _, c in pairs(h.conns) do
            pcall(function()
                c:Disconnect()
                c = nil
            end)
        end

        h.conns = {}
    end

    if g.hidden_person then
        for _, c in pairs(g.hidden_person.conns or {}) do
            pcall(function()
                c:Disconnect()
                c = nil
            end)
        end

        g.hidden_person.conns = {}
    end
    g.hidden_loaded = false
    g.hidden_settings = {enabled = false, conns = {}}
    g.hidden_person = {conns = {}}

    for _, v in ipairs(parent_gui:GetChildren()) do
        if v:IsA("ScreenGui") and v.Name:lower():find("streamermode") then
            v:Destroy()
        end
    end
    for _, v in ipairs(CoreGui:GetChildren()) do
        if v:IsA("ScreenGui") and v.Name:lower():find("streamermode") then
            v:Destroy()
        end
    end
end

g.Pick_Vehicle_Color_Func = g.Pick_Vehicle_Color_Func or function(input)
    if not input then return end
    local str = tostring(input):lower():match("^%s*(.-)%s*$")
    local chosen
    local r, g, b = str:match("(%d+)[,%s]+(%d+)[,%s]+(%d+)")
    if r and g and b then chosen = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
    if not chosen then
        local hex = str:match("^#?(%x%x%x%x%x%x)$")
        if hex then
            chosen = Color3.fromRGB(
                tonumber(hex:sub(1,2), 16),
                tonumber(hex:sub(3,4), 16),
                tonumber(hex:sub(5,6), 16)
            )
        end
    end

    if not chosen then
        local color_mapper = {
            red = Color3.fromRGB(255,0,0),
            darkred = Color3.fromRGB(139,0,0),
            crimson = Color3.fromRGB(220,20,60),
            firebrick = Color3.fromRGB(178,34,34),
            indianred = Color3.fromRGB(205,92,92),
            lightcoral = Color3.fromRGB(240,128,128),
            salmon = Color3.fromRGB(250,128,114),
            darksalmon = Color3.fromRGB(233,150,122),
            lightsalmon = Color3.fromRGB(255,160,122),
            tomato = Color3.fromRGB(255,99,71),
            orangered = Color3.fromRGB(255,69,0),
            orange = Color3.fromRGB(255,165,0),
            darkorange = Color3.fromRGB(255,140,0),
            coral = Color3.fromRGB(255,127,80),
            yellow = Color3.fromRGB(255,255,0),
            lightyellow = Color3.fromRGB(255,255,224),
            gold = Color3.fromRGB(255,215,0),
            goldenrod = Color3.fromRGB(218,165,32),
            darkgoldenrod = Color3.fromRGB(184,134,11),
            palegoldenrod = Color3.fromRGB(238,232,170),
            khaki = Color3.fromRGB(240,230,140),
            darkkhaki = Color3.fromRGB(189,183,107),
            lemonchiffon = Color3.fromRGB(255,250,205),
            green = Color3.fromRGB(0,128,0),
            lime = Color3.fromRGB(0,255,0),
            limegreen = Color3.fromRGB(50,205,50),
            forestgreen = Color3.fromRGB(34,139,34),
            darkgreen = Color3.fromRGB(0,100,0),
            seagreen = Color3.fromRGB(46,139,87),
            mediumseagreen = Color3.fromRGB(60,179,113),
            lightseagreen = Color3.fromRGB(32,178,170),
            springgreen = Color3.fromRGB(0,255,127),
            mediumspringgreen = Color3.fromRGB(0,250,154),
            palegreen = Color3.fromRGB(152,251,152),
            lightgreen = Color3.fromRGB(144,238,144),
            olivedrab = Color3.fromRGB(107,142,35),
            darkolivegreen = Color3.fromRGB(85,107,47),
            olive = Color3.fromRGB(128,128,0),
            chartreuse = Color3.fromRGB(127,255,0),
            lawngreen = Color3.fromRGB(124,252,0),
            greenyellow = Color3.fromRGB(173,255,47),
            yellowgreen = Color3.fromRGB(154,205,50),
            blue = Color3.fromRGB(0,0,255),
            navy = Color3.fromRGB(0,0,128),
            darkblue = Color3.fromRGB(0,0,139),
            mediumblue = Color3.fromRGB(0,0,205),
            royalblue = Color3.fromRGB(65,105,225),
            steelblue = Color3.fromRGB(70,130,180),
            lightsteelblue = Color3.fromRGB(176,196,222),
            dodgerblue = Color3.fromRGB(30,144,255),
            deepskyblue = Color3.fromRGB(0,191,255),
            skyblue = Color3.fromRGB(135,206,235),
            lightskyblue = Color3.fromRGB(135,206,250),
            cornflowerblue = Color3.fromRGB(100,149,237),
            cadetblue = Color3.fromRGB(95,158,160),
            midnightblue = Color3.fromRGB(25,25,112),
            slateblue = Color3.fromRGB(106,90,205),
            mediumslateblue = Color3.fromRGB(123,104,238),
            darkslateblue = Color3.fromRGB(72,61,139),
            powderblue = Color3.fromRGB(176,224,230),
            lightblue = Color3.fromRGB(173,216,230),
            purple = Color3.fromRGB(128,0,128),
            darkpurple = Color3.fromRGB(75,0,100),
            rebeccapurple = Color3.fromRGB(102,51,153),
            indigo = Color3.fromRGB(75,0,130),
            violet = Color3.fromRGB(238,130,238),
            darkviolet = Color3.fromRGB(148,0,211),
            blueviolet = Color3.fromRGB(138,43,226),
            mediumpurple = Color3.fromRGB(147,112,219),
            mediumorchid = Color3.fromRGB(186,85,211),
            darkorchid = Color3.fromRGB(153,50,204),
            orchid = Color3.fromRGB(218,112,214),
            plum = Color3.fromRGB(221,160,221),
            thistle = Color3.fromRGB(216,191,216),
            lavender = Color3.fromRGB(230,230,250),
            magenta = Color3.fromRGB(255,0,255),
            fuchsia = Color3.fromRGB(255,0,255),
            darkmagenta = Color3.fromRGB(139,0,139),
            pink = Color3.fromRGB(255,192,203),
            lightpink = Color3.fromRGB(255,182,193),
            hotpink = Color3.fromRGB(255,105,180),
            deeppink = Color3.fromRGB(255,20,147),
            mediumvioletred = Color3.fromRGB(199,21,133),
            palevioletred = Color3.fromRGB(219,112,147),
            cyan = Color3.fromRGB(0,255,255),
            aqua = Color3.fromRGB(0,255,255),
            teal = Color3.fromRGB(0,128,128),
            darkcyan = Color3.fromRGB(0,139,139),
            darkturquoise = Color3.fromRGB(0,206,209),
            mediumturquoise = Color3.fromRGB(72,209,204),
            turquoise = Color3.fromRGB(64,224,208),
            paleturquoise = Color3.fromRGB(175,238,238),
            aquamarine = Color3.fromRGB(127,255,212),
            mediumaquamarine = Color3.fromRGB(102,205,170),
            brown = Color3.fromRGB(165,42,42),
            darkbrown = Color3.fromRGB(101,67,33),
            saddlebrown = Color3.fromRGB(139,69,19),
            sienna = Color3.fromRGB(160,82,45),
            chocolate = Color3.fromRGB(210,105,30),
            peru = Color3.fromRGB(205,133,63),
            tan = Color3.fromRGB(210,180,140),
            burlywood = Color3.fromRGB(222,184,135),
            wheat = Color3.fromRGB(245,222,179),
            sandybrown = Color3.fromRGB(244,164,96),
            rosybrown = Color3.fromRGB(188,143,143),
            maroon = Color3.fromRGB(128,0,0),
            white = Color3.fromRGB(255,255,255),
            black = Color3.fromRGB(0,0,0),
            gray = Color3.fromRGB(128,128,128),
            grey = Color3.fromRGB(128,128,128),
            lightgray = Color3.fromRGB(211,211,211),
            lightgrey = Color3.fromRGB(211,211,211),
            darkgray = Color3.fromRGB(169,169,169),
            darkgrey = Color3.fromRGB(169,169,169),
            silver = Color3.fromRGB(192,192,192),
            dimgray = Color3.fromRGB(105,105,105),
            dimgrey = Color3.fromRGB(105,105,105),
            slategray = Color3.fromRGB(112,128,144),
            slategrey = Color3.fromRGB(112,128,144),
            lightslategray = Color3.fromRGB(119,136,153),
            lightslategrey = Color3.fromRGB(119,136,153),
            darkslategray = Color3.fromRGB(47,79,79),
            darkslategrey = Color3.fromRGB(47,79,79),
            gainsboro = Color3.fromRGB(220,220,220),
            whitesmoke = Color3.fromRGB(245,245,245),
            beige = Color3.fromRGB(245,245,220),
            ivory = Color3.fromRGB(255,255,240),
            snow = Color3.fromRGB(255,250,250),
            honeydew = Color3.fromRGB(240,255,240),
            mintcream = Color3.fromRGB(245,255,250),
            azure = Color3.fromRGB(240,255,255),
            aliceblue = Color3.fromRGB(240,248,255),
            ghostwhite = Color3.fromRGB(248,248,255),
            linen = Color3.fromRGB(250,240,230),
            antiquewhite = Color3.fromRGB(250,235,215),
            bisque = Color3.fromRGB(255,228,196),
            moccasin = Color3.fromRGB(255,228,181),
            peachpuff = Color3.fromRGB(255,218,185),
            mistyrose = Color3.fromRGB(255,228,225),
            lavenderblush = Color3.fromRGB(255,240,245),
            seashell = Color3.fromRGB(255,245,238),
            oldlace = Color3.fromRGB(253,245,230),
            floralwhite = Color3.fromRGB(255,250,240),
            cornsilk = Color3.fromRGB(255,248,220),
            blanchedalmond = Color3.fromRGB(255,235,205),
            navajowhite = Color3.fromRGB(255,222,173),
            papayawhip = Color3.fromRGB(255,239,213),
        }

        local normalized = str:gsub("%s+", "")
        chosen = color_mapper[normalized] or color_mapper[str]
    end

    if not chosen then g.notify("Error", "Invalid color: "..tostring(input), 3); return end
    g.change_vehicle_color(chosen, g.get_vehicle())
end

g.RGB_Vehicle = g.RGB_Vehicle or function(state)
    if state == true then
        if g.Rainbow_Vehicle then g.notify("Warning", "Yadsan Hub | Rainbow Vehicle is already enabled.", 5); return end
        g.Rainbow_Vehicle = true
        g.notify("Success", "Yadsan Hub | Rainbow Vehicle is now enabled.", 5)
        lib.spawn("rgb_vehicle", "spawn", function()
            while g.Rainbow_Vehicle == true do
                for _, color in ipairs(g.colors) do
                    g.change_vehicle_color(color, g.get_vehicle())
                    fw(0)
                end
                RunService.Heartbeat:Wait()
            end
        end)
    elseif state == false then
        if not g.Rainbow_Vehicle then
            if g.notify and typeof(g.notify) == "function" then g.notify("Warning", "Yadsan Hub | Rainbow Vehicle is not enabled.", 5) end
            return
        end
        g.Rainbow_Vehicle = false
        lib.disconnect("rgb_vehicle")
        g.notify("Success", "Yadsan Hub | Rainbow Vehicle is now disabled.", 5)
    else
        return 
    end
end

g.two_color_switcher_FE_func = g.two_color_switcher_FE_func or function(state)
    local lib = g.FlamesLibrary
    if state == true then
        if g.two_tone_vehicle_colors_changing then g.notify("Warning", "Two Color Switcher already enabled.", 5); return end
        g.two_tone_vehicle_colors_changing = true
        local c1 = g.colors[math.random(1,#g.colors)]
        local c2 = g.colors[math.random(1,#g.colors)]
        while c1 == c2 do c2 = g.colors[math.random(1,#g.colors)] end
        g.notify("Success", "Yadsan Hub | Two Tone Vehicle is now enabled.", 5)
        lib.spawn("two_color_vehicle","spawn",function()
            while g.two_tone_vehicle_colors_changing == true do
                fw(0.1)
                g.change_vehicle_color(c1, g.get_vehicle())
                wait(.1)
                g.change_vehicle_color(c2, g.get_vehicle())
                wait(.1)
                RunService.Heartbeat:Wait()
            end
        end)
    elseif state == false then
        if not g.two_tone_vehicle_colors_changing then g.notify("Warning", "Two Color Switcher not enabled.", 5); return end
        g.two_tone_vehicle_colors_changing = false
        lib.disconnect("two_color_vehicle")
        g.notify("Success", "Yassan Hub | Two Tone Vehicle is now disabled.", 5)
    end
end

g.find_vehicles_folder_Life_Together_RP = g.find_vehicles_folder_Life_Together_RP or function()
    local cached = g.vehicles_folder_instance_Life_Together_RP
    if cached and cached.Parent and cached:IsA("Folder") then return cached end
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Folder") and v.Name:lower():find("vehicles") then
            g.vehicles_folder_instance_Life_Together_RP = v
            return v
        end
    end
    return nil
end

if not g.vehicles_folder_instance_Life_Together_RP then pcall(function() g.find_vehicles_folder_Life_Together_RP() end) end
local function init_vehicle_esp()
    g.vehicle_esp_highlights = g.vehicle_esp_highlights or {}
    g.vehicle_esp_connections = g.vehicle_esp_connections or {}
    local highlights = g.vehicle_esp_highlights
    local connections = g.vehicle_esp_connections
    local vehiclesFolder = g.vehicles_folder_instance_Life_Together_RP or workspace:FindFirstChild("Vehicles")
    local function clearESP(model)
        local hl = highlights[model]
        if hl then
            pcall(function()
                hl:Destroy()
            end)
            highlights[model] = nil
        end
        local conn = connections[model]
        if conn then
            pcall(function()
                conn:Disconnect()
            end)
            connections[model] = nil
        end
    end

    local function applyESP(model)
        if not model or not model:IsA("Model") then return end
        if highlights[model] then return end
        local hl = Instance.new("Highlight")
        hl.Adornee = model
        hl.FillTransparency = 0.6
        hl.OutlineTransparency = 0
        hl.Parent = model

        highlights[model] = hl
        connections[model] = model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                clearESP(model)
            end
        end)
    end

    g.vehicle_esp_toggle = g.vehicle_esp_toggle or function(toggled)
        if not vehiclesFolder then return end
        if toggled == true then
            if g.vehicle_esp_is_enabled then g.notify("Warning", "Vehicle ESP is already enabled.", 5); return end
            g.vehicle_esp_is_enabled = true
            for _, v in ipairs(vehiclesFolder:GetChildren()) do applyESP(v) end
            if g.vehicle_esp_folderAdded then
                g.vehicle_esp_folderAdded:Disconnect()
                g.vehicle_esp_folderAdded = nil
            end
            if g.vehicle_esp_folderRemoved then
                g.vehicle_esp_folderRemoved:Disconnect()
                g.vehicle_esp_folderRemoved = nil
            end

            g.vehicle_esp_folderAdded = vehiclesFolder.ChildAdded:Connect(function(child) applyESP(child) end)
            g.vehicle_esp_folderRemoved = vehiclesFolder.ChildRemoved:Connect(function(child) clearESP(child) end)
        elseif toggled == false then
            if not g.vehicle_esp_is_enabled then g.notify("Warning", "Vehicle ESP is not enabled.", 5); return end
            g.vehicle_esp_is_enabled = false
            for model in pairs(highlights) do clearESP(model) end
            if g.vehicle_esp_folderAdded then
                pcall(function()  g.vehicle_esp_folderAdded:Disconnect() end)
                g.vehicle_esp_folderAdded = nil
            end

            if g.vehicle_esp_folderRemoved then
                pcall(function() g.vehicle_esp_folderRemoved:Disconnect() end)
                g.vehicle_esp_folderRemoved = nil
            end
        end
    end
end
fw(0.1)
init_vehicle_esp()

g.RGB_Vehicle_Others = g.RGB_Vehicle_Others or function(Player, state)
    local lib = g.FlamesLibrary
    if not Player then return end
    local name = "rgb_other_"..Player.UserId
    local PlayersName = Player.Name
    if state == true then
        if lib.is_alive(name) then g.notify("Warning", "RGB Vehicle is already enabled for: "..tostring(PlayersName), 5); return end
        g.notify("Success", "Enabled Rainbow Vehicle for: "..tostring(PlayersName), 5)
        lib.spawn(name,"spawn", function()
            while true do
                if not Player or not Player.Parent then
                    lib.disconnect(name)
                    g.notify("Error", PlayersName.." has left the game.", 5)
                    return
                end

                local vehicle = g.get_other_vehicle(Player)
                if not vehicle then wait(.2) end
                if vehicle:GetAttribute("locked") == true then lib.disconnect(name); return end
                for _, color in ipairs(g.colors) do g.change_vehicle_color(color, Player); wait(.2) end
            end
        end)
    elseif state == false then
        if not lib.is_alive(name) then return end
        lib.disconnect(name)
    end
end

g.copy_emote_plr = g.copy_emote_plr or function(player)
    local targetChar = player.Character or g.get_char(player)
    local targetHum = targetChar and targetChar:FindFirstChildWhichIsA("Humanoid") or g.get_human(player, Players.RespawnTime + 1)
    local myChar = g.Character or g.LocalPlayer.Character or g.get_char(LocalPlayer, Players.RespawnTime + 1)
    local myHum = g.Humanoid or myChar and myChar:FindFirstChildWhichIsA("Humanoid") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
    if not (targetHum and myHum) then return end
    for _, track in ipairs(myHum:GetPlayingAnimationTracks()) do pcall(function() track:Stop() end) end
    wait(0.05)
    for _, tTrack in ipairs(targetHum:GetPlayingAnimationTracks()) do
        local animObj = tTrack.Animation
        if animObj and animObj:IsA("Animation") then
            local id = tostring(animObj.AnimationId)
            if id and id ~= "" and id ~= "0" and not id:find("507768375") then
                local newAnim = Instance.new("Animation")
                newAnim.AnimationId = id
                local myTrack = nil
                pcall(function() myTrack = myHum:LoadAnimation(newAnim) end)
                if myTrack and myTrack:IsA("Animation") then
                    myTrack:Play(0.1, 1, tTrack.Speed)
                    myTrack.TimePosition = tTrack.TimePosition
                    g.TrackHasBeenStopped_Watcher_Task = g.TrackHasBeenStopped_Watcher_Task or task.spawn(function()
                        tTrack.Stopped:Wait()
                        pcall(function() myTrack:Stop() end)
                        pcall(function() myTrack:Destroy() end)
                        pcall(function() newAnim:Destroy() end)
                    end)
                else
                    newAnim:Destroy()
                end
            end
        end
    end
end

g.get_emote_properties_and_insert_properties = g.get_emote_properties_and_insert_properties or function()
    local hum = g.Humanoid or g.Character and g.Character:FindFirstChildWhichIsA("Humanoid") or g.get_human(LocalPlayer, Players.RespawnTime + 1)
    if not hum then return end
    local tracks = hum:GetPlayingAnimationTracks()
    if #tracks == 0 then g.notify("Error", "You're not playing an Animation.", 5); return end
    local track = tracks[1]
    local anim = track.Animation
    if not anim then g.notify("Error", "Your animation unexpectedly disappeared?", 5); return end
    local animId = tostring(anim.AnimationId)
    local realId = tonumber(animId:match("%d+"))
    if not realId then return end
    table.insert(g.currently_saved_emotes_list, {
        Id = realId,
        AssetId = realId,
        Name = track.Name ~= "" and track.Name or "Unknown",
        AnimationId = "rbxassetid://" .. realId,
        Favorite = false
    })
end

g.save_copied_plrs_emote = g.save_copied_plrs_emote or function()
    if g.currently_saved_emotes_list and g.saveEmotesToData then
        g.notify("Info", "Saving currently playing emote, please wait.", 2.5)
        g.get_emote_properties_and_insert_properties()
        fw(0.1)
        g.saveEmotesToData()
        wait()
        g.notify("Success", "Saved currently playing emote.", 3)
    else
        if g.FreeEmotes_Enabled then g.notify("Warning", "You already have Yadsan Emoting GUI loaded!", 5); return end
        if CoreGui:FindFirstChild("FlamesEmoteGUI") then g.notify("Warning", "You already have Yadsan Emoting GUI loaded!", 5); return end
        g.FreeEmotes_Enabled = true
        loadstring(g.http_get("https://pastebin.com/raw/RCj6RJtc"))()
        wait(1)
        g.notify("Info", "Try the command again, you did not have our Free Emotes GUI loaded.", 15)
        wait(1)
        while not CoreGui:FindFirstChild("FlamesEmoteGUI", true) do task.wait(0.1) end
        local gui = CoreGui:FindFirstChild("FlamesEmoteGUI", true)
        if gui and gui:IsA("ScreenGui") then
            local Frame_Find = gui:FindFirstChildOfClass("Frame")
            if Frame_Find and Frame_Find.Parent then Frame_Find.Visible = false end
        end
    end
end

g.mutesounds = g.mutesounds or function()
    for _,v in ipairs(Placed_Models:GetDescendants()) do
        if v:IsA("Sound") then
            local n = v.Name
            if n == "SoundDefault" or n == "Music" or n == "Airhorn" then
                v.Volume = 0
            elseif n == "Sound" and v.Parent and v.Parent.Parent and v.Parent.Parent.Name == "BoomBox" then
                v.Volume = 0
            end
        end
    end

    for _,p in ipairs(g.Players:GetPlayers()) do
        local c = p.Character or g.get_char(p, Players.RespawnTime + 0.5)
        if c and c:IsDescendantOf(game) then
            for _,v in ipairs(c:GetDescendants()) do
                if v:IsA("Sound") then
                    if v.Name == "Sound" and v.Parent and v.Parent.Parent and v.Parent.Parent:IsA("Tool") and v.Parent.Parent.Name == "BoomBox" then
                        v.Volume = 0
                    end
                end
            end
        end
    end
end

g.unmutesounds = g.unmutesounds or function()
    for _,v in ipairs(Placed_Models:GetDescendants()) do
        if v:IsA("Sound") then
            local n = v.Name
            if n == "SoundDefault" or n == "Music" or n == "Airhorn" then
                v.Volume = 1
            elseif n == "Sound" and v.Parent and v.Parent.Parent and v.Parent.Parent.Name == "BoomBox" then
                v.Volume = 0.5
            end
        end
    end

    for _,p in ipairs(g.Players:GetPlayers()) do
        local c = p.Character or g.get_char(p, 3)

        if c and c:IsDescendantOf(game) then
            for _,v in ipairs(c:GetDescendants()) do
                if v:IsA("Sound") then
                    if v.Name == "Sound" and v.Parent and v.Parent.Parent and v.Parent.Parent:IsA("Tool") and v.Parent.Parent.Name == "BoomBox" then
                        v.Volume = 0.5
                    end
                end
            end
        end
    end

    g.notify("Success", "Unmuted all tools.", 5)
end

g.mute_all_tools = g.mute_all_tools or function(toggle)
    if toggle == true then
        if g.autosilence then g.notify("Warning", "Tool muter is already enabled.", 5); return end
        g.autosilence = true
        g.notify("Success", "Tool muter is enabled.", 5)
        g.Muting_All_Tool_Sounds_Task = task.spawn(function()
            while g.autosilence == true do
                wait(1)
                g.mutesounds()
            end
        end)
    elseif toggle == false then
        if not g.autosilence then g.notify("Warning", "Tools muter is not enabled.", 5); return end
        if g.Muting_All_Tool_Sounds_Task then
            task.cancel(g.Muting_All_Tool_Sounds_Task)
            g.Muting_All_Tool_Sounds_Task = nil
        end

        g.autosilence = false
        wait(1)
        if not g.autosilence then
            g.notify("Info", "Making all the tools Volume: 1...", 5)
            g.unmutesounds()
        else
            g.g.notify("Warning", "Tools muter is not disabled yet, hold on...", 3)
            repeat task.wait() until not g.autosilence or g.autosilence == false
            wait(1.5)
            if not g.autosilence then
                g.notify("Success", "Unmuting all Tools...", 5)
                wait(0.5)
                g.unmutesounds()
                wait(0.5)
                g.notify("Success", "Unmuted all Tools.", 5)
            end
        end
    else
        return 
    end
end

g.find_skin_body_colors_in_char = g.find_skin_body_colors_in_char or function(char)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BodyColors") then return v end
        local name = v.Name:lower()
        if name:find("body") and name:find("color") then return v end
    end
    return nil
end

g.original_skintone = g.original_skintone or nil
g.rainbow_skin = g.rainbow_skin or function(state)
    local lib = g.FlamesLibrary
    local name = "rainbow_skin"
    local char = g.Character or g.LocalPlayer.Character or g.get_char(LocalPlayer, Players.RespawnTime + 1)
    if not char or not char:IsDescendantOf(game) then return end
    local bodycolors = char and char:FindFirstChildOfClass("BodyColors")
    if not bodycolors then return end
    if state == true then
        if g.rainbow_skintone_currently_enabled then g.notify("Warning", "Yadsan Hub - Rainbow Skin is already enabled.", 5); return end
        g.original_skintone = {
            HeadColor3 = bodycolors.HeadColor3,
            LeftArmColor3 = bodycolors.LeftArmColor3,
            RightArmColor3 = bodycolors.RightArmColor3,
            LeftLegColor3 = bodycolors.LeftLegColor3,
            RightLegColor3 = bodycolors.RightLegColor3,
            TorsoColor3 = bodycolors.TorsoColor3
        }

        g.notify("Success", "Yadsan Hub | Rainbow Skin is now enabled.", 5)
        lib.spawn(name, "spawn", function()
            while true do
                for _, c in ipairs(g.colors) do
                    g.send_remote("skin_tone", c)
                    wait(.1)
                end
            end
        end)
    elseif state == false then
        if not lib.is_alive(name) then return end
        lib.disconnect(name)
        fw(0.2)
        if g.original_skintone then
            local old = g.original_skintone
            g.send_remote("skin_tone", old.HeadColor3)
            wait()
            g.send_remote("skin_tone", old.LeftArmColor3)
            wait()
            g.send_remote("skin_tone", old.RightArmColor3)
            wait()
            g.send_remote("skin_tone", old.LeftLegColor3)
            wait()
            g.send_remote("skin_tone", old.RightLegColor3)
            wait()
            g.send_remote("skin_tone", old.TorsoColor3)
            g.notify("Success", "Reset SkinTone back to your old SkinTone.", 3)
        end
        g.notify("Success", "Yadsan Hub | Rainbow Skin is now disabled.", 5)
    end
end

g.two_tone_skin = g.two_tone_skin or function(state)
    local lib = g.FlamesLibrary
    local fw = lib.wait
    local name = "two_tone_skin"
    local char = g.Character or g.LocalPlayer or g.get_char(LocalPlayer, Players.RespawnTime + 1)
    if not char or not char:IsDescendantOf(game) then return end
    local bodycolors = char and char:FindFirstChildOfClass("BodyColors")
    if not bodycolors then return end
    if state == true then
        if g.Two_Tone_Skin_Tone_Loop_Toggled then g.notify("Warning", "Two Tone Skin is already enabled.", 5); return end
        g.original_skintone = {
            HeadColor3 = bodycolors.HeadColor3,
            LeftArmColor3 = bodycolors.LeftArmColor3,
            RightArmColor3 = bodycolors.RightArmColor3,
            LeftLegColor3 = bodycolors.LeftLegColor3,
            RightLegColor3 = bodycolors.RightLegColor3,
            TorsoColor3 = bodycolors.TorsoColor3
        }
        local c1 = g.colors[math.random(1, #g.colors)]
        local c2 = g.colors[math.random(1, #g.colors)]
        while c2 == c1 do c2 = g.colors[math.random(1, #g.colors)] end
        g.notify("Success", "Yadsan Hub | Two Tone Skin is now enabled.", 5)
        g.Two_Tone_Skin_Tone_Loop_Toggled = true
        lib.spawn(name, "spawn", function()
            while g.Two_Tone_Skin_Tone_Loop_Toggled == true do
                fw(0.1)
                g.Send("skin_tone", c1)
                fw(0.1)
                g.Send("skin_tone", c2)
            end
        end)
    elseif state == false then
        if not g.Two_Tone_Skin_Tone_Loop_Toggled then g.notify("WArning", "Two Tone Skin is not enabled.", 5); return end
        lib.disconnect(name)
        wait(0.25)
        if g.original_skintone then
            local old = g.original_skintone
            g.Send("skin_tone", old.HeadColor3)
            wait()
            g.Send("skin_tone", old.LeftArmColor3)
            wait()
            g.Send("skin_tone", old.RightArmColor3)
            wait()
            g.Send("skin_tone", old.LeftLegColor3)
            wait()
            g.Send("skin_tone", old.RightLegColor3)
            wait()
            g.Send("skin_tone", old.TorsoColor3)
            g.notify("Success", "Reset skintone back to original.", 3)
        end
        g.notify("Success", "Yadsan Hub | Two Tone Skin is now disabled.", 5)
    end
end

g.Amount_Input = 5
g.set_fire_amount_FE = g.set_fire_amount_FE or function(amount)
    amount = tonumber(amount)
    if not amount then g.Amount_Input = 5; return end
    g.Amount_Input = amount
end

local Old_Name_From_Name_Spammer
g.name_changer_premium = g.name_changer_premium or function(state)
    local lib = g.FlamesLibrary
    local name = "name_spammer"
    local words = {
        "root_access","packet_inject","xor_key","decrypting",
        "init_stealth","spoof_id","kernel_hook","bruteforce",
        "sys_reboot","net_breach","ghost_mode","backdoor_init"
    }

    if state == true then
        if g.Name_Spammer_Currently_Enabled then g.notify("Warning", "Yadsan Hub | Name Spammer is already enabled.", 5); return end
        g.Name_Spammer_Currently_Enabled = true
        Old_Name_From_Name_Spammer = g.LocalPlayer:GetAttribute("roleplay_name") or "SERVER"
        local index = 1
        local count = #words
        lib.spawn(name, "spawn", function()
            while g.Name_Spammer_Currently_Enabled == true do
                g.Send("roleplay_name", words[index])
                index = index + 1
                if index > count then index = 1 end
                fw(61)
            end
        end)

        g.notify("Success", "Name Spammer is now enabled.", 3)
    elseif state == false then
        if not g.Name_Spammer_Currently_Enabled then g.notify("Warning", "Yadsan Hub | Name Spammer is not enabled.", 5); return end
        g.Name_Spammer_Currently_Enabled = false
        lib.disconnect(name)
        fw(0.1)
        g.Send("roleplay_name", tostring(Old_Name_From_Name_Spammer))
        g.notify("Success", "Name Spammer is now disabled.", 3)
    end
end

g.spectate_plr_without_distance_limits = g.spectate_plr_without_distance_limits or function(plr)
    g.spectatePlayer = function(target_player)
        if not target_player then return end
        local spectate_target = target_player
        local spectate_subject = nil
        g.originalIO.disconnectSpectateConns()
        local function setCamToCharacter(character)
            if spectate_target ~= target_player or not character then return end
            local hum = g.getPlrHum(character) or g.getHum(character, 5)
            local subj = hum or g.getRoot(character)
            if not subj then return end
            spectate_subject = subj
            g.originalIO.ensureCam()
            g.originalIO.hookCameraGuard()
        end

        setCamToCharacter(target_player.Character)
        g.spectateConns.char = g.FlamesLibrary.connect("spectate_char", target_player.CharacterAdded:Connect(function(character)
            if spectate_target ~= target_player then return end
            setCamToCharacter(character)
        end))

        g.spectateConns.leave = g.NAlib.connect("spectate_leave", Players.PlayerRemoving:Connect(function(player)
            if player == target_player and spectate_target == target_player then g.cleanup(true) end
        end))

        g.spectateConns.loop = g.NAlib.connect("spectate_loop", RunService.RenderStepped:Connect(function()
            if spectate_target ~= target_player then return end
            local char = target_player.Character
            if not char or not char.Parent then return end
            if not spectate_subject or spectate_subject.Parent ~= char then
                setCamToCharacter(char)
            else
                g.originalIO.ensureCam()
            end
        end))
    end

    g.spectatePlayer(plr)
end

g.anti_outfit_copier = function(toggle)
    if toggle == true then
        if g.anti_outfit_stealer then g.notify("Error", "Anti Outfit Stealer is already enabled!", 5); return end
        if g.FlamesLibrary.is_alive("AntiFitStealerConn") then g.notify("Error", "Anti Outfit Stealer is already enabled! [connection].", 5); return end
        g.notify("Success", "Yadsan Hub | Anti Outfit Stealer is now active.", 7)
        local lib = g.FlamesLibrary
        g.ToggleAntiFit_Stealer = g.ToggleAntiFit_Stealer or function(state)
            if not state then
                g.anti_outfit_stealer = false
                lib.disconnect("AntiFitStealerConn")
                local hide_outfit_toggle = g.LocalPlayer:GetAttribute("hide_view_outfit")
                if hide_outfit_toggle and hide_outfit_toggle == false then
                    g.Send("hide_view_outfit", true)
                    g.notify("Success", "hide_view_outfit setting changed, reverted change (keep it on).", 3)
                end
            else
                g.anti_outfit_stealer = true
                g.Send("bio", "`~ Celestial Hub Anti Stealer Is Enabled By Yadsan ~`")
            end

            local last_check = 0
            local target_bio = "`~ Celestial Hub Anti Stealer Is Enabled By Yadsan ~`"
            lib.connect("AntiFitStealerConn", g.RunService.Heartbeat:Connect(function()
                local now = tick()
                if now - last_check < 0.4 then return end
                last_check = now
                local hide_outfit_toggle = g.LocalPlayer:GetAttribute("hide_view_outfit")
                if hide_outfit_toggle and hide_outfit_toggle == false then
                    g.Send("hide_view_outfit", true)
                    g.notify("Success", "hide_view_outfit setting changed, reverted change (keep it on).", 3)
                end

                if g.anti_outfit_stealer then
                    local current_bio = g.LocalPlayer:GetAttribute("bio")
                    if current_bio ~= target_bio then
                        g.Send("bio", target_bio)
                        g.notify("Success", "Bio was changed, reverted back.", 3)
                    end
                end
            end))
        end
        fw(0.1)
        g.ToggleAntiFit_Stealer(true)
    elseif toggle == false then
        if not g.anti_outfit_stealer then g.notify("Error", "Anti Outfit Copier is not enabled!", 5); return end
        g.anti_outfit_stealer = false
        g.FlamesLibrary.disconnect("AntiFitStealerConn")
        g.ToggleAntiFit_Stealer(false)
        g.notify("Success", "Disabled Anti Outfit Stealer.", 5)
    else
        return
    end
end

g.Delete_House = function()
    local s = g.Get
    if s and typeof(s) == "function" then g.Get("request_delete_house") end
end

local upvalues_func_main = getupvalue or getupvalues or rawget and rawget(debug, "getupvalues")
local get_proto_func = getproto or rawget and rawget(debug, "getproto") or getprotos
g.hook_meta_main = g.hook_meta_main or function(obj, metamethod, func)
    if not getrawmetatable or typeof(getrawmetatable) ~= "function" then return end
    local old = getrawmetatable and getrawmetatable(obj)
    if hookfunction and typeof(hookfunction) == "function" then
        return hookfunction(old[metamethod],func)
    else
        local oldmetamethod = old[metamethod]
        if makewriteable and typeof(makewriteable) == "function" then makewriteable(old) end
        old[metamethod] = func
        if makereadonly and typeof(makereadonly) == "function" then makereadonly(old) end
        return oldmetamethod
    end
end

g.find_messages_modulescript = g.find_messages_modulescript or function()
    if g.Messages_Module_Found_Loc then return g.Messages_Module_Found_Loc end
    local found = ReplicatedStorage:FindFirstChild("Messages", true)
    if found and found:IsA("ModuleScript") then g.Messages_Module_Found_Loc = found end
    return g.Messages_Module_Found_Loc
end

g.find_UI_modulescript = g.find_UI_modulescript or function()
    if g.UI_Module_Main then return g.UI_Module_Main end
    local found = ReplicatedStorage:FindFirstChild("UI", true)
    if found and found:IsA("ModuleScript") then g.UI_Module_Main = found end
    return g.UI_Module_Main
end

g.find_RateLimiter_modulescript = g.find_RateLimiter_modulescript or function()
    if g.RateLimiter_Module_Main then return g.RateLimiter_Module_Main end
    local found = ReplicatedStorage:FindFirstChild("RateLimiter", true)
    if found and found:IsA("ModuleScript") then g.RateLimiter_Module_Main = found end
    return g.RateLimiter_Module_Main
end

if not g.RateLimiter_Bypass_Applied then
    if get_proto_func and upvalues_func_main and require then
        local ok = pcall(function()
            local message_module = g.Messages_Module_Found_Loc and require(g.Messages_Module_Found_Loc) or require(g.find_messages_modulescript())
            local rate_limiter = upvalues_func_main(get_proto_func(message_module.loaded, 4, true)[1], 5)
            if typeof(rate_limiter) == "table" and rate_limiter.is_limited then
                rate_limiter.is_limited = function() return false end
                g.RateLimiter_Bypass_Applied = true
                g.RateLimiter_Bypass_Applied_Method_2 = true
            end
        end)
        if not ok then
            warn("RateLimiter bypass method failed unexpectedly.")
        end
    end
end

g.Spam_Survey_Completions = function(state)
    if state == true then
        g.Spam_And_Spoof_Survey_Submissions = true
        g.notify("Success", "Yadsan Hub | Life Together RP survey spammer is now active.", 3)
        FlamesLibrary.spawn("spam_survey_completions", "spawn", function()
            while g.Spam_And_Spoof_Survey_Submissions == true do
            task.wait(0)
                local Survey_Args = {
                    "survey_completed",
                    "5",
                    {
                        {
                            questionKey = "question_1",
                            answerKeys = {"question_5"}
                        },
                        {
                            answerKey = "question_2",
                            questionKey = "question_2"
                        },
                        {
                            questionKey = "question_3",
                            answerKeys = {"question_2"}
                        },
                        {
                            answerKey = "answer_2",
                            questionKey = "question_4"
                        },
                        {
                            answerKey = "answer_1",
                            questionKey = "question_5"
                        }
                    },
                    {
                        platform = spoofed_platforms[math.random(1, #spoofed_platforms)],
                        localeId = locale_ids[math.random(1, #locale_ids)],
                        sdkVersion = matrix_ids[math.random(1, #matrix_ids)]
                    }
                }
                g.Send(unpack(Survey_Args))
            end
        end)
    elseif state == false then
        g.Spam_And_Spoof_Survey_Submissions = false
        FlamesLibrary.disconnect("spam_survey_completions")
        g.notify("Success", "Yadsan Hub | Life Together RP survey spammer is now disabled.", 3)
    else
        return 
    end
end

g.spam_sign_text = g.spam_sign_text or function(toggle)
    local Character = g.Character
    local PlacedModels = workspace:WaitForChild("PlacedModels")
    local random_words = {"yo","wsg bro","aye","lit","fire"}
    local function find_tool_partial(tool_name)
        if not tool_name then return nil end
        local query = tool_name:lower()
        for _, v in ipairs(PlacedModels:GetChildren()) do
            if v:IsA("Model") and v.Name:lower() == query then
                local owner_attr = v:GetAttribute("owner_id")
                if owner_attr and tostring(owner_attr) == tostring(LocalPlayer.UserId) then
                    return v
                end
            end
        end

        for _, v in ipairs(Character:GetChildren()) do if v.Name:lower() == query then return v end end
        return nil
    end

    if toggle == true then
        if g.ToolChanger_FE then g.notify("Warning", "Sign Spammer is already enabled!", 3); return end
        g.ToolChanger_FE = true
        g.Sign_ChangeText_Fast_Loop_Task = task.spawn(function()
            while g.ToolChanger_FE == true do
                local tool = find_tool_partial("sign")
                if not tool then
                    g.Send("get_tool", "Sign")
                    fw(0.1)
                else
                    for _, word in ipairs(random_words) do
                        if not g.ToolChanger_FE then break end
                        g.Send("change_sign", tool, tostring(word))
                        fw(0)
                    end
                end
                fw(0.1)
            end
        end)
    elseif toggle == false then
        if g.Sign_ChangeText_Fast_Loop_Task then
            task.cancel(g.Sign_ChangeText_Fast_Loop_Task)
            g.Sign_ChangeText_Fast_Loop_Task = nil
        end
        g.ToolChanger_FE = false
    else
        return 
    end
end

g.AutoLockConnection = g.AutoLockConnection or nil
g.ToggleAutoLock = g.AutoLockConnection or function(state)
    if not state then
        g.AutoLockOn = false
        if g.AutoLockConnection then
            g.AutoLockConnection:Disconnect()
            g.AutoLockConnection = nil
        end

        local car = g.get_vehicle()
        if car and car:GetAttribute("locked") == true then
            g.lock_vehicle(car)
            g.notify("Success", "Yadsan Hub | Auto Lock Vehicle is now disabled.", 5)
        else
            g.notify("Warning", "Yadsan Hub | Auto Lock Vehicle is now disabled, vehicle not found.", 5)
        end
        return 
    else
        local car = g.get_vehicle()
        if not car then g.notify("Error", "Vehicle not found, spawn one!", 5); return end
        g.AutoLockOn = true
    end

    g.notify("Success", "Yadsan Hub | Auto Lock Vehicle is now enabled.", 5)
    g.AutoLockConnection = g.RunService.Heartbeat:Connect(function()
        if tick() - (g._lastLockCheck or 0) < 1 then return end
        g._lastLockCheck = tick()
        local car = g.get_vehicle()
        if car and car:GetAttribute("locked") ~= true then g.lock_vehicle(car) end
    end)
end

if not g.player_esp_core then
    g.player_esp_core = true
    local localplayer = g.LocalPlayer
    local esp_objects = {}
    g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled = false
    local function wait_character(plr)
        local character = plr.Character
        while g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled and plr.Parent and (not character or not character.Parent) do
            character = plr.Character
            g.heartbeat_wait_function(6)
        end
        return character
    end

    local function remove_esp(plr)
        if esp_objects[plr] then
            esp_objects[plr]:Destroy()
            esp_objects[plr] = nil
        end
    end

    local function apply_esp(plr)
        if not g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled then return end
        if plr == localplayer then return end
        task.spawn(function()
            local character = wait_character(plr)
            if not g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled or not character then return end
            remove_esp(plr)
            local highlight = Instance.new("Highlight")
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Adornee = character
            highlight.Parent = character
            esp_objects[plr] = highlight
        end)
    end

    local function track_player(plr)
        apply_esp(plr)
        FlamesLibrary.connect("esp_char_" .. tostring(plr.UserId), plr.CharacterAdded:Connect(function(new_char)
            if plr == localplayer then return end
            while g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled and new_char and not new_char.Parent do task.wait() end
            apply_esp(plr)
        end))
    end

    local function untrack_player(plr) remove_esp(plr); FlamesLibrary.disconnect("esp_char_" .. tostring(plr.UserId)) end
    g.enable_player_esp = function()
        if g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled then g.notify("Warning", "Yadsan Hub Player ESP is already enabled.", 5); return end
        g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled = true
        for _, plr in ipairs(Players:GetPlayers()) do track_player(plr) end
        FlamesLibrary.connect("esp_playeradded", Players.PlayerAdded:Connect(track_player))
        FlamesLibrary.connect("esp_playerremoving", Players.PlayerRemoving:Connect(untrack_player))
    end

    g.disable_player_esp = function()
        if not g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled then g.notify("Warning", "Yadsan Hub Player ESP is not enabled.", 5); return end
        g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled = false
        for plr in pairs(esp_objects) do remove_esp(plr) end
        FlamesLibrary.disconnect("esp_playeradded")
        FlamesLibrary.disconnect("esp_playerremoving")
    end
end

if Drawing and not g.tracer_core_initialized then
    g.tracer_core_initialized = true
    local camera = workspace.CurrentCamera
    local localplayer = g.LocalPlayer or Players.LocalPlayer
    local tracer_objects = {}
    g.tracer_esp_currently_running_flag_Flames_Hub = false
    if g.disable_tracers and typeof(g.disable_tracers) == "function" then pcall(function() g.disable_tracers() end) end
    local function remove_tracer(plr)
        if tracer_objects[plr] then
            tracer_objects[plr]:Remove()
            tracer_objects[plr] = nil
        end
    end

    local function create_tracer(plr)
        if plr == localplayer then return end
        while g.tracer_esp_currently_running_flag_Flames_Hub and not plr.Parent do task.wait() end
        if not g.tracer_esp_currently_running_flag_Flames_Hub then return end
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Transparency = 1
        line.Visible = false
        tracer_objects[plr] = line
    end

    local function update_tracers()
        if not g.tracer_esp_currently_running_flag_Flames_Hub then pcall(function() g.disable_tracers() end); return end
        local view = camera.ViewportSize
        for plr, line in pairs(tracer_objects) do
            local character = plr.Character or g.get_char(plr, 1)
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                local pos, onscreen = camera:WorldToViewportPoint(root.Position)
                if onscreen then
                    line.Visible = true
                    line.From = Vector2.new(view.X / 2, view.Y)
                    line.To = Vector2.new(pos.X, pos.Y)
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
    end

    g.enable_tracers = function()
        if g.tracer_esp_currently_running_flag_Flames_Hub then g.notify("Warning", "Tracer ESP is already enabled!", 3); return end
        g.tracer_esp_currently_running_flag_Flames_Hub = true
        for _, plr in ipairs(Players:GetPlayers()) do create_tracer(plr) end
        FlamesLibrary.connect("tracer_render", RunService.RenderStepped:Connect(update_tracers))
        FlamesLibrary.connect("tracer_playeradded", Players.PlayerAdded:Connect(create_tracer))
        FlamesLibrary.connect("tracer_playerremoving", Players.PlayerRemoving:Connect(remove_tracer))
    end

    g.disable_tracers = function()
        if not g.tracer_esp_currently_running_flag_Flames_Hub then g.notify("Warning", "Tracer ESP is not enabled!", 3); return end
        g.tracer_esp_currently_running_flag_Flames_Hub = false
        for plr in pairs(tracer_objects) do remove_tracer(plr) end
        FlamesLibrary.disconnect("tracer_render")
        FlamesLibrary.disconnect("tracer_playeradded")
        FlamesLibrary.disconnect("tracer_playerremoving")
    end
end
wait(0.25)
if not g.RateLimiter_Notified then
    g.RateLimiter_Notified = true
    if g.RateLimiter_Bypass_Applied then
        if g.RateLimiter_Bypass_Applied_Method_1 then
            g.notify("Success", "RateLimiter bypass applied with method 1.", 10)
        elseif g.RateLimiter_Bypass_Applied_Method_2 then
            g.notify("Success", "RateLimiter bypass applied with method 2.", 10)
        elseif g.RateLimiter_Bypass_Applied_Method_3 then
            g.notify("Success", "RateLimiter bypass applied with method 3.", 10)
        else
            g.notify("Warning", "We we're unable to apply any RateLimiter bypass.", 10)
        end
    else
        g.notify("Warning", "Not sure if RateLimiter bypass was applied or not.", 10)
    end
end

g.WalkFlingWhitelist = g.WalkFlingWhitelist or {}
g.walkflinging = g.walkflinging or false
g.WalkFlingConnections = g.WalkFlingConnections or {}
g.TouchingWhitelisted = g.TouchingWhitelisted or {}
g.AddToWalkFlingWhitelist = g.AddToWalkFlingWhitelist or function(user)
    local userid = g.ToUserId(user)
    if not userid then return g.notify("Warning", "That player is invalid or has left the game.", 5) end
    if g.WalkFlingWhitelist[userid] then return g.notify("Warning", "That player is already in the WalkFling Whitelist.", 5) end
    g.WalkFlingWhitelist[userid] = true
    return g.notify("Success", "Added to WalkFling Whitelist.", 5)
end

g.RemoveFromWalkFlingWhitelist = g.RemoveFromWalkFlingWhitelist or function(user)
    local userid = g.ToUserId(user)
    if not userid then return g.notify("Warning", "That player is invalid or has left the game.", 5) end
    if not g.WalkFlingWhitelist[userid] then return g.notify("Warning", "That player is not in the WalkFling Whitelist.", 5) end
    g.WalkFlingWhitelist[userid] = nil
    return g.notify("Success", "Removed from WalkFling Whitelist.", 5)
end

g.is_whitelisted = g.is_whitelisted or function(plr)
    if not plr then return false end
    return g.WalkFlingWhitelist[plr.UserId] == true
end

g.stop_walkfling = g.stop_walkfling or function()
    if not g.walkflinging then g.notify("Error", "Yadsan Hub | WalkFling-V3.5 is not enabled.", 5); return end
    g.walkflinging = false
    g.TouchingWhitelisted = {}
    g.FlamesLibrary.disconnect("walkflinger")
    for _, conn in pairs(g.WalkFlingConnections) do conn:Disconnect() end
    g.WalkFlingConnections = {}
    if g.WalkFlingRespawnConn then
        g.WalkFlingRespawnConn:Disconnect()
        g.WalkFlingRespawnConn = nil
    end

    if g.Noclip_Enabled then g.Toggleable_Noclip(false) end
    local root = g.HumanoidRootPart
    if root then root.Velocity = Vector3.zero end
    local hum = g.Humanoid or g.Character:FindFirstChildOfClass("Humanoid") or g.get_human(LocalPlayer or Players.LocalPlayer)
    if hum then hum.PlatformStand = false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    g.notify("Success", "Yadsan Hub | WalkFling-V3.5 has been stopped/disabled.", 5)
end

g.start_walkfling = g.start_walkfling or function()
    if g.walkflinging then g.notify("Warning", "Yadsan Hub | WalkFling-V3.5 is already enabled!", 5); return end
    g.walkflinging = true
    g.TouchingWhitelisted = {}
    if not g.Noclip_Enabled then g.Toggleable_Noclip(true) end
    g.notify("Success", "Yadsan Hub | WalkFling-V3.5 is now enabled.", 5)
    local function connect_touch_fling(character)
        for _, conn in pairs(g.WalkFlingConnections) do conn:Disconnect() end
        g.WalkFlingConnections = {}
        g.TouchingWhitelisted = {}
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                local touch_conn = part.Touched:Connect(function(hit)
                    if not g.walkflinging then return end
                    local hit_char = hit.Parent
                    while hit_char and not Players:GetPlayerFromCharacter(hit_char) and hit_char.Parent ~= workspace do hit_char = hit_char.Parent end
                    local hit_player = Players:GetPlayerFromCharacter(hit_char)
                    if not hit_player or hit_player == speaker then return end
                    if g.is_whitelisted(hit_player) then
                        g.TouchingWhitelisted[hit_player.UserId] = true
                        return
                    end

                    if next(g.TouchingWhitelisted) then return end
                    local hit_root = hit_char:FindFirstChild("HumanoidRootPart")
                    if not hit_root then return end
                    local root = g.HumanoidRootPart
                    local v = root and root.CFrame.LookVector or Vector3.zero
                    local power = 10000
                    hit_root.Velocity = v * power + Vector3.new(0, power, 0)
                    RunService.RenderStepped:Wait()
                    if hit_root then hit_root.Velocity = v * power end
                    RunService.RenderStepped:Wait()
                    if hit_root then hit_root.Velocity = v * power + Vector3.new(0, 0.1, 0) end
                end)

                local untouch_conn = part.TouchEnded:Connect(function(hit)
                    local hit_char = hit.Parent
                    while hit_char and not Players:GetPlayerFromCharacter(hit_char) and hit_char.Parent ~= workspace do hit_char = hit_char.Parent end
                    local hit_player = Players:GetPlayerFromCharacter(hit_char)
                    if hit_player and g.is_whitelisted(hit_player) then g.TouchingWhitelisted[hit_player.UserId] = nil end
                end)
                table.insert(g.WalkFlingConnections, touch_conn)
                table.insert(g.WalkFlingConnections, untouch_conn)
            end
        end
    end

    local char = g.Character or g.LocalPlayer.Character or g.get_char(speaker, 3)
    if char then connect_touch_fling(char) end
    if g.WalkFlingRespawnConn then
        g.WalkFlingRespawnConn:Disconnect()
        g.WalkFlingRespawnConn = nil
    end
    wait(0.25)
    g.WalkFlingRespawnConn = speaker.CharacterAdded:Connect(function(new_char) if g.walkflinging then connect_touch_fling(new_char) end end)
    g.FlamesLibrary.disconnect("walkflinger")
    g.FlamesLibrary.connect("walkflinger", RunService.Heartbeat:Connect(function()
        if not g.walkflinging then return end
        local m = g.Character or g.get_char(speaker, 3)
        local r = m and (g.HumanoidRootPart or m:FindFirstChild("HumanoidRootPart"))
        if not r then return end
        local v = r.Velocity
        r.Velocity = v * 10000 + Vector3.new(0, 10000, 0)
        RunService.RenderStepped:Wait()
        if r then r.Velocity = v end
        RunService.RenderStepped:Wait()
        if r then r.Velocity = v + Vector3.new(0, 0.1, 0) end
    end))
end

g.StartWalkFling = g.start_walkfling
g.StopWalkFling = g.stop_walkfling
g.getcharsize = g.getcharsize or function()
    local hum = g.Humanoid
    if not hum then return 5,2 end
    local d = hum:GetAppliedDescription()
    local h = 5 * (d.HeightScale or 1)
    local w = 2 * (d.WidthScale or 1)
    return h,w
end

g.autospinspeed = g.autospinspeed or function(base) local h = g.getcharsize(); return base / h end
g.change_spin_speed = g.change_spin_speed or function(speed)
    if g.walkflinging then g.notify("Error", "Turn off walkfling first for this to work properly.", 5); return end
    for _, v in ipairs(g.HumanoidRootPart:GetChildren()) do if v.Name == "FlamesHub_Spin" then v.AngularVelocity = Vector3.new(0, speed, 0) end end
end

g.LockHouse_LastState = g.LockHouse_LastState or {}
g.LockHomeLoop = g.LockHomeLoop or false
g.get_plot_of_player = g.get_plot_of_player or function(player)
    if not player then return nil, "No player provided" end
    local plotList = g.PlotMarker and g.PlotMarker.class and g.PlotMarker.class.objects
    if type(plotList) ~= "table" then return nil, "Plots not available" end
    for _, plot in pairs(plotList) do
        if plot and plot.states and plot.states.owner and typeof(plot.states.owner.get) == "function" and plot.instance then
            local ok, owner = pcall(function() return plot.states.owner.get() end)
            if ok and owner == player then  return plot.instance, plot end
        end
    end

    return nil, "Player has no plot"
end

g.toggle_house_lock = g.toggle_house_lock or function(player)
    local plotInstance = select(1, g.get_plot_of_player(player))
    if not plotInstance then return end
    g.Send("lock_home", plotInstance)
end

g.is_home_locked = g.is_home_locked or function(player)
    local plotObject = g.get_plot_of_player(player)
    if not plotObject then return nil, "Player has no plot" end
    if not plotObject.states or not plotObject.states.locked or typeof(plotObject.states.locked.get) ~= "function" then return nil, "Locked state unavailable" end
    local ok, locked = pcall(function() return plotObject.states.locked.get() end)
    if not ok then return nil, "Failed to read lock state" end
    return locked
end

g.LockHouse_LastState = g.LockHouse_LastState or {}
g.LockHomeLoop = g.LockHomeLoop or false
g.LockHomeToken = g.LockHomeToken or 0
g.keep_home_locked = g.keep_home_locked or function(toggle)
    if toggle then
        if g.LockHomeLoop then g.notify("Warning", "Yadsan Hub | Auto Lock Home is already enabled.", 5); return end
        g.LockHomeLoop = true
        g.LockHomeToken = (g.LockHomeToken or 0) + 1
        local myToken = g.LockHomeToken
        g.notify("Success", "Yadsan Hub | Auto Lock Home is now enabled.", 5)
        task.spawn(function()
            while g.LockHomeLoop and myToken == g.LockHomeToken do
                fw(0.2)
                local plot_list = g.PlotMarker and g.PlotMarker.class and g.PlotMarker.class.objects
                if plot_list then
                    for _, plot in pairs(plot_list) do
                        if myToken ~= g.LockHomeToken then return end
                        local okOwner, owner = pcall(function() return plot.states.owner.get() end)
                        if okOwner and owner == g.LocalPlayer then
                            local id = plot.instance:GetDebugId()
                            if g.LockHouse_LastState[id] == nil then g.LockHouse_LastState[id] = plot.states.locked.get() end
                            local locked = plot.states.locked.get()
                            local last = g.LockHouse_LastState[id]
                            if locked == false and last == true then
                                g.toggle_house_lock(g.LocalPlayer)
                                g.LockHouse_LastState[id] = true
                            else
                                g.LockHouse_LastState[id] = locked
                            end
                        end
                    end
                end
            end
        end)
    else
        if not g.LockHomeLoop then g.notify("Warning", "Yadsan Hub | Auto Lock Home is not enabled.", 5); return end
        g.LockHomeLoop = false
        g.LockHomeToken = (g.LockHomeToken or 0) + 1
        table.clear(g.LockHouse_LastState)
        g.notify("Success", "Yadsan Hub | Auto Lock Home is now disabled.", 5)
    end
end

g.spin_plr = g.spin_plr or function(toggle, speed)
    local hrp = g.HumanoidRootPart or g.Character and g.Character:FindFirstChild("HumanoidRootPart") or g.get_root(g.LocalPlayer, Players.RespawnTime + 1)
    if toggle == true then
        if g.already_spinning_localplr then g.notify("Warning", "You are already spinning, changing speed.", 5); return end
        if typeof(speed) ~= "number" then g.notify("Error", "That wasn't a number! Input a number.", 5); return end
        if g.walkflinging then g.notify("Error", "Turn off walkfling first for this to work properly.", 5); return end
        g.already_spinning_localplr = true
        for _, v in pairs(hrp:GetChildren()) do
            if v.Name == "FlamesHub_Spin" then
                v:Destroy()
            end
        end
        wait(.1)
        local Spin = Instance.new("BodyAngularVelocity")
        Spin.Name = "FlamesHub_Spin"
        Spin.MaxTorque = Vector3.new(0, math.huge, 0)
        Spin.AngularVelocity = Vector3.new(0, g.autospinspeed(speed), 0)
        Spin.Parent = hrp
    elseif toggle == false then
        if not g.already_spinning_localplr then g.notify("Error", "You are not using Spin.", 3); return end
        for _, v in ipairs(hrp:GetChildren()) do if v:IsA("BodyAngularVelocity") and v.Name == "FlamesHub_Spin" then v:Destroy() end end
        g.already_spinning_localplr = false
    else
        return
    end
end

g.OrbitConnections = g.OrbitConnections or {}
g.Is_Orbiting = g.Is_Orbiting or false
g.OrbitSpeed = g.OrbitSpeed or 1
g.set_orbit_speed = g.set_orbit_speed or function(new_speed)
    if type(new_speed) == "number" then
        g.OrbitSpeed = new_speed
        g.notify("Info", "Orbit speed set to "..tostring(new_speed), 4)
    else
        g.notify("Error", "Invalid speed value.", 3)
    end
end

g.stop_orbit = g.stop_orbit or function()
    if not g.Is_Orbiting then g.notify("Warning", "You're not orbiting anyone.", 3); return end
    for _, conn in pairs(g.OrbitConnections) do if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end end
    table.clear(g.OrbitConnections)
    g.Is_Orbiting = false
    g.notify("Success", "Stopped orbiting Player.", 3)
end

g.start_orbit_plr = g.start_orbit_plr or function(target, speed, distance)
    if g.Is_Orbiting then g.notify("Warning", "Already orbiting someone!", 3); return end
    if not target or not target.Character then g.notify("Error", "Target invalid or they're missing their Character.", 5); return end
    local target_char = target.Character or g.get_char(target)
    local root = g.HumanoidRootPart or g.get_root(LocalPlayer, 3)
    local humanoid = g.Humanoid or g.Character:FindFirstChildWhichIsA("Humanoid") or g.get_human(LocalPlayer)
    local targetRoot = target_char:FindFirstChild("HumanoidRootPart") or g.get_root(target, 1)
    if not root or not humanoid or not targetRoot then
        g.Is_Orbiting = false
        g.notify("Error", "Missing root or humanoid, cannot orbit this player.", 5)
        return 
    end

    speed = tonumber(speed) or g.OrbitSpeed or 1
    distance = tonumber(distance) or 3
    g.OrbitSpeed = speed
    g.Is_Orbiting = true
    local rotation = 0
    g.OrbitConnections.Heartbeat = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not g.Is_Orbiting or not target_char or not targetRoot or not root then return  end
            rotation = rotation + (g.OrbitSpeed or 0)
            root.CFrame = CFrame.new(targetRoot.Position) * CFrame.Angles(0, math.rad(rotation), 0) * CFrame.new(distance, 0, 0)
        end)
    end)

    g.OrbitConnections.RenderStepped = RunService.RenderStepped:Connect(function()
        pcall(function()
            if root and root.Parent and targetRoot and targetRoot.Parent then root.CFrame = CFrame.new(root.Position, targetRoot.Position) end
        end)
    end)

    g.OrbitConnections.Died = humanoid.Died:Connect(g.stop_orbit)
    g.OrbitConnections.Seated = humanoid.Seated:Connect(function(isSeated) if isSeated then g.stop_orbit() end end)
    g.notify("Success", "Started orbiting: "..tostring(target)..", with speed: "..tostring(speed)..", and with distance: "..tostring(distance), 5)
end

g.water_skie_trailer = g.water_skie_trailer or function(Bool, Vehicle)
    if not Vehicle then g.notify("Warning", "You do not have a Vehicle spawned!", 5); return end
    local HasTrailer = Vehicle:FindFirstChild("WaterSkies")
    if Bool == true then
        if HasTrailer then
            g.notify("Error", "You already have the WaterSkies trailer.", 5)
            return
        else
            g.Get("add_trailer", Vehicle, "WaterSkies")
        end
    elseif Bool == false then
        if HasTrailer then
            g.Get("add_trailer", Vehicle, "WaterSkies")
        else
            g.notify("Warning", "You do not have the WaterSkies trailer to take it off!", 5)
            return
        end
    else
        g.notify("Error", "Invalid toggle value (expected: true/false).", 5)
        return 
    end
end

g.FlyEnabled = g.FlyEnabled or false
g.FlySpeed = g.FlySpeed or 1
g.QEfly = (g.QEfly == nil) and true or g.QEfly
g.flyKeyDown = g.flyKeyDown or nil
g.flyKeyUp = g.flyKeyUp or nil
g.mobileFlyConn = g.mobileFlyConn or nil
g.pcFlyConn = g.pcFlyConn or nil
g.EnableFly = g.EnableFly or function(state, speed, vfly)
    if g.FlyEnabled then
        if speed and tonumber(speed) then
            g.FlySpeed = tonumber(speed)
            g.notify("Success", "Fly speed updated to: "..tostring(g.FlySpeed), 3)
            return
        end
        g.notify("Warning", "Fly is already enabled! Provide a speed to update it.", 5)
        return 
    end

    local char = g.Character or plr.Character or g.get_char(plr, Players.RespawnTime + 1)
    local hrp = g.HumanoidRootPart or char and char:FindFirstChild("HumanoidRootPart") or g.get_root(plr, Players.RespawnTime + 1)
    local hum = g.Humanoid or char and char:FindFirstChildOfClass("Humanoid") or g.get_human(plr, Players.RespawnTime + 1)
    local cam = workspace.CurrentCamera
    if not hrp or not hum then g.notify("Error", "Character is not ready or Humanoid doesn't exist.", 5); return end
    if not state then
        g.DisableFly()
        return
    end

    if speed and tonumber(speed) then g.FlySpeed = tonumber(speed) end
    g.FlyEnabled = true
    if g.flyKeyDown then g.flyKeyDown:Disconnect(); g.flyKeyDown = nil end
    if g.flyKeyUp then g.flyKeyUp:Disconnect(); g.flyKeyUp = nil end
    if g.pcFlyConn then g.pcFlyConn:Disconnect(); g.pcFlyConn = nil end
    if g.mobileFlyConn then g.mobileFlyConn:Disconnect(); g.mobileFlyConn = nil end
    if hrp:FindFirstChild("FlyGyro") then hrp.FlyGyro:Destroy() end
    if hrp:FindFirstChild("FlyVelocity") then hrp.FlyVelocity:Destroy() end

    local BG = Instance.new("BodyGyro")
    BG.P = 9e4
    BG.MaxTorque = Vector3.new(9e9,9e9,9e9)
    BG.CFrame = hrp.CFrame
    BG.Name = "FlyGyro"
    BG.Parent = hrp

    local BV = Instance.new("BodyVelocity")
    BV.MaxForce = Vector3.new(9e9,9e9,9e9)
    BV.Velocity = Vector3.zero
    BV.Name = "FlyVelocity"
    BV.Parent = hrp

    hum.PlatformStand = true
    if not IsMobile then
        local CONTROL = {F=0,B=0,L=0,R=0,Q=0,E=0}
        g.pcFlyConn = RunService.RenderStepped:Connect(function(dt)
            if not g.FlyEnabled then return end
            if not cam or not hrp or not hum then return end
            local speedNow = ((vfly and (g.VehicleFlySpeed or g.FlySpeed)) or g.FlySpeed) * 50
            local look = cam.CFrame
            local move_vec = ((look.LookVector * (CONTROL.F + CONTROL.B)) + ((look * CFrame.new(CONTROL.L + CONTROL.R, (CONTROL.Q + CONTROL.E) * 0.2, 0)).Position - look.Position))
            if move_vec.Magnitude > 0 then
                move_vec = move_vec.Unit
                BV.Velocity = move_vec * speedNow
            else
                BV.Velocity = BV.Velocity * 0.9
            end

            BG.CFrame = cam.CFrame
        end)

        g.flyKeyDown = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 1 end
            if input.KeyCode == Enum.KeyCode.S then CONTROL.B = -1 end
            if input.KeyCode == Enum.KeyCode.A then CONTROL.L = -1 end
            if input.KeyCode == Enum.KeyCode.D then CONTROL.R = 1 end
            if g.QEfly then
                if input.KeyCode == Enum.KeyCode.E then CONTROL.Q = 1 end
                if input.KeyCode == Enum.KeyCode.Q then CONTROL.E = -1 end
            end
            pcall(function() cam.CameraType = Enum.CameraType.Track end)
        end)

        g.flyKeyUp = UIS.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 0 end
            if input.KeyCode == Enum.KeyCode.S then CONTROL.B = 0 end
            if input.KeyCode == Enum.KeyCode.A then CONTROL.L = 0 end
            if input.KeyCode == Enum.KeyCode.D then CONTROL.R = 0 end
            if input.KeyCode == Enum.KeyCode.E then CONTROL.Q = 0 end
            if input.KeyCode == Enum.KeyCode.Q then CONTROL.E = 0 end
        end)

        g.notify("Success", "Fly enabled (PC) | Speed: "..tostring(g.FlySpeed), 5)
        return
    end

    local ok, controlModule = pcall(function()
        return require(plr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
    end)
    if not ok or not controlModule then
        g.notify("Warning", "ControlModule unavailable; using simple touch fallback.", 5)
        g.mobileFlyConn = RunService.RenderStepped:Connect(function()
            if not g.FlyEnabled then return end
            BG.CFrame = cam.CFrame
            BV.Velocity = Vector3.zero
        end)
        return
    end

    g.mobileFlyConn = RunService.RenderStepped:Connect(function()
        if not g.FlyEnabled then return end
        if not hrp or not hum or not cam then return end
        BG.CFrame = cam.CFrame
        local direction = controlModule:GetMoveVector()
        local speedScaled = ((vfly and (g.VehicleFlySpeed or g.FlySpeed)) or g.FlySpeed) * 50
        if direction.Magnitude > 0 then
            BV.Velocity = (cam.CFrame.LookVector * -direction.Z + cam.CFrame.RightVector * direction.X) * speedScaled
        else
            BV.Velocity = Vector3.zero
        end
    end)

    g.notify("Success", "Fly enabled (Mobile) | Speed: "..tostring(g.FlySpeed), 5)
end

g.DisableFly = g.DisableFly or function()
    if not g.FlyEnabled then g.notify("Warning", "Fly is not enabled!", 3); return end
    g.FlyEnabled = false
    if g.flyKeyDown then g.flyKeyDown:Disconnect(); g.flyKeyDown = nil end
    if g.flyKeyUp then g.flyKeyUp:Disconnect(); g.flyKeyUp = nil end
    if g.pcFlyConn then g.pcFlyConn:Disconnect(); g.pcFlyConn = nil end
    if g.mobileFlyConn then g.mobileFlyConn:Disconnect(); g.mobileFlyConn = nil end
    local char = g.Character or plr.Character or g.get_char(plr, 3)
    local hrp = g.HumanoidRootPart or char:FindFirstChild("HumanoidRootPart") or g.get_root(plr, 3)
    local hum = g.Humanoid or char:FindFirstChildWhichIsA("Humanoid") or g.get_human(plr, 3)
    if hrp then
        if hrp:FindFirstChild("FlyGyro") then hrp.FlyGyro:Destroy() end
        if hrp:FindFirstChild("FlyVelocity") then hrp.FlyVelocity:Destroy() end
    end

    if hum then hum.PlatformStand = false end
    g.notify("Success", "Fly is now disabled.", 3)
end

g.VehicleStates = g.VehicleStates or {}
if not g.VehicleStates[g.LocalPlayer.Name] then g.VehicleStates[g.LocalPlayer.Name] = g.LocalPlayer end
g.find_core_folder = g.find_core_folder or function()
    for _, v in ipairs(g.ReplicatedStorage:GetDescendants()) do
        if v:IsA("Folder") and v.Name == "Core" and v.Parent.Name == "Modules" then
            return v
        end
    end

    return nil
end

g.send_msg_phone = g.send_msg_phone or function(player, msg)
    local Core_Folder = g.find_core_folder()
    if not Core_Folder then g.notify("Error", "Core Folder not found (patched?).", 5); return end
    local Privacy = require(Core_Folder:FindFirstChild("Privacy"))
    if not Privacy then g.notify("Error", "Privacy ModuleScript not found (patched?).", 5); return end
    local function get_dm_hash(id)
        local my = LocalPlayer.UserId
        if not id then return nil end
        local a, b = (id < my) and id or my, (id < my) and my or id
        return tostring(a) .. " " .. tostring(b)
    end

    local function send_dm(target, text)
        local targetId = target.UserId
        local hash = get_dm_hash(targetId)
        if not hash then return false end
        local ok, res = pcall(function() return Privacy.send_message("messages", hash, text) end)
        if not ok or res == false then
            g.Sending_DMs_Main_Non_Loop_Task = g.Sending_DMs_Main_Non_Loop_Task or task.spawn(function()
                g.notify("Error", "Send message failed: "..tostring(res), 5)
            end)
            return false
        end

        return true
    end

    local text_to_send = msg
    if not text_to_send or text_to_send == "" then g.notify("Error", "Please input a valid message to send!", 5); return end
    send_dm(player, text_to_send)
end

local data_mod = require and require(g.ReplicatedStorage.Modules.Core:FindFirstChild("Data", true))
local messages_mod = require and require(g.ReplicatedStorage:FindFirstChild("Messages", true))
local function get_other_from_hash(hash, known_id)
    local id1, id2 = hash:match("(%-?%d+) (%-?%d+)")
    id1, id2 = tonumber(id1), tonumber(id2)
    if not id1 or not id2 then return nil end
    if id1 == known_id then return id2 end
    if id2 == known_id then return id1 end
    return nil
end

local function get_recipient_id()
    local convo = messages_mod.active_conversation
    if not convo then return nil end
    return get_other_from_hash(convo.hash, Players.LocalPlayer.UserId)
end

local function get_recipient_from_message(msg_id, sender_id)
    for _, convo in ipairs(data_mod.conversations or {}) do
        if convo.messages then
            for _, msg in ipairs(convo.messages) do
                if msg.id == msg_id then
                    return get_other_from_hash(convo.hash, sender_id)
                end
            end
        end
    end
    return nil
end

local function get_sender_id(msg_id)
    for _, convo in ipairs(data_mod.conversations or {}) do
        if convo.messages then
            for _, msg in ipairs(convo.messages) do
                if msg.id == msg_id then
                    return msg.sender_id, convo.hash
                end
            end
        end
    end
    return nil, nil
end

g.chat_logged_ids = g.chat_logged_ids or {}
g.chat_frame_locks = g.chat_frame_locks or {}
g.chat_text_conns = g.chat_text_conns or {}
g.chat_send_queue = g.chat_send_queue or {}
g.chat_sending = g.chat_sending or false
local function resolve_name(uid)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId == uid then
            return p.Name
        end
    end
    return "User_" .. uid
end

local function enqueue_message(msg) table.insert(g.chat_send_queue, msg) end
local function log_message(frame, txt, msg_id, sender_id)
    local unique_id = msg_id .. "|" .. txt.Text
    if g.chat_logged_ids[unique_id] then return end
    g.chat_logged_ids[unique_id] = true
    local sender_name = resolve_name(sender_id)
    local recipient_id = tonumber(frame:GetAttribute("recipient_id"))
        or get_recipient_from_message(msg_id, sender_id)
        or get_recipient_id()
    local recipient_name = recipient_id and resolve_name(recipient_id) or "unknown"
    local recipient_str  = recipient_id
        and (recipient_name .. " (" .. recipient_id .. ")")
        or "unknown"
    enqueue_message(
        sender_name .. " (" .. sender_id .. " to " .. recipient_str .. "): " .. txt.Text
    )
end

g.process_message_frame = function(frame)
    if frame.Name ~= "Message" then return end
    local msg_id = frame:GetAttribute("id")
    if type(msg_id) ~= "string" then return end
    local sender_id, hash = get_sender_id(msg_id)
    if not sender_id then return end
    local recipient_id = get_other_from_hash(hash, sender_id)
    if recipient_id then frame:SetAttribute("recipient_id", recipient_id) end
    local txt = frame:FindFirstChildWhichIsA("TextLabel", true)
    if not txt then return end
    if not g.chat_text_conns[txt] then
        g.chat_text_conns[txt] = txt:GetPropertyChangedSignal("Text"):Connect(function()
            if txt.Text == "" then return end
            task.delay(0.02, function()
                if txt.Text ~= "" then
                    log_message(frame, txt, msg_id, sender_id)
                end
            end)
        end)
    end

    task.delay(0.05, function()
        if txt and txt.Text ~= "" then
            log_message(frame, txt, msg_id, sender_id)
        end
    end)
end

g.toggle_rgb_streetlights = g.toggle_rgb_streetlights or function(toggle)
    local genv = g
    if toggle == true then
        if genv.RGB_Street_Lights_NightTime_Loop or genv.StreetLightRainbowConnection then genv.notify("Warning", "RGB/Rainbow StreetLights is already running!", 5); return end
        local Map = workspace:FindFirstChild("Map", true)
        if not Map then genv.notify("Error", "Map Folder not found inside of Workspace!", 5); return end
        local StreetLs = Map:FindFirstChild("StreetLights", true)
        if not StreetLs then genv.notify("Error", "StreetLights not found inside of Map Folder!", 5); return end
        if typeof(genv.all_street_lights) ~= "table" then genv.all_street_lights = {} end
        if next(genv.all_street_lights) == nil then
            for _, v in ipairs(StreetLs:GetDescendants()) do
                if v:IsA("PointLight") then
                table.insert(genv.all_street_lights, v)
                end
            end
        end

        local hue = 0
        genv.RGB_Street_Lights_NightTime_Loop = true
        genv.notify("Success", "RGB/Rainbow StreetLights enabled, they will only animate at night.", 10)
        genv.StreetLightRainbowConnection = RunService.Heartbeat:Connect(function(dt)
            local clock_time = g.Lighting.ClockTime
            if clock_time < 18.5 and clock_time > 7.5 then return end
            hue = (hue + dt * 0.0833) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            for i = #genv.all_street_lights, 1, -1 do
                local light = genv.all_street_lights[i]
                if not light or not light.Parent then
                    table.remove(genv.all_street_lights, i)
                else
                    light.Color = color
                end
            end
        end)
    elseif toggle == false then
        if not genv.RGB_Street_Lights_NightTime_Loop then genv.notify("Warning", "RGB/Rainbow StreetLights is not enabled!", 5); return end
        genv.RGB_Street_Lights_NightTime_Loop = false
        if genv.StreetLightRainbowConnection then
            genv.StreetLightRainbowConnection:Disconnect()
            genv.StreetLightRainbowConnection = nil
        end
        genv.notify("Success", "RGB/Rainbow StreetLights disabled.", 10)
    end
end

local excluded_functions = {
    HttpGet = true,
    appendfile = true,
    base64_decode = true,
    base64_encode = true,
    base64decode = true,
    base64encode = true,
    cansignalreplicate = true,
    checkcaller = true,
    checkclosure = true,
    clear_teleport_queue = true,
    cleardrawcache = true,
    clearqueueonteleport = true,
    clearteleportqueue = true,
    clonefunction = true,
    cloneref = true,
    clonereference = true,
    compareinstances = true,
    consoleclear = true,
    consolecreate = true,
    consoledestroy = true,
    consoleerror = true,
    consoleinput = true,
    consoleprint = true,
    consolesettitle = true,
    consolewarn = true,
    create_comm_channel = true,
    createrenderobj = true,
    createrenderobject = true,
    decompile = true,
    delfile = true,
    delfolder = true,
    dofile = true,
    dumpstring = true,
    disable_emote_func = true,
    filtergc = true,
    fireclickdetector = true,
    fireproximityprompt = true,
    firesignal = true,
    firetouchinterest = true,
    get_actor_threads = true,
    get_actors = true,
    get_comm_channel = true,
    get_deleted_actors = true,
    get_hidden_gui = true,
    get_hwid = true,
    get_internal_parent = true,
    get_namecall_method = true,
    get_thread_identity = true,
    get_user_identifier = true,
    getactors = true,
    getactorthreads = true,
    getallthreads = true,
    getbspval = true,
    getcallbackmember = true,
    getcallbackvalue = true,
    getcallingscript = true,
    getcaps = true,
    getclosurecaps = true,
    getconnection = true,
    getconnections = true,
    getconstant = true,
    getconstants = true,
    getcustomasset = true,
    getdeletedactors = true,
    getexecutorname = true,
    getfenv = true,
    getfflag = true,
    getfpscap = true,
    getfunctionhash = true,
    getgc = true,
    getgenv = true,
    gethiddenprop = true,
    gethiddenproperty = true,
    gethui = true,
    gethwid = true,
    getidentity = true,
    getinfo = true,
    getinstances = true,
    getinternalparent = true,
    getloadedmodules = true,
    getnamecallmethod = true,
    getnilinstances = true,
    getobjects = true,
    getpcd = true,
    getproto = true,
    getprotos = true,
    getproximitypromptduration = true,
    getrawmetatable = true,
    getreg = true,
    getregistry = true,
    getrenderproperty = true,
    getrendersteppedlist = true,
    getrenv = true,
    getrunningscripts = true,
    getsafeenv = true,
    getscriptbytecode = true,
    getscriptclosure = true,
    getscriptfromthread = true,
    getscriptfunction = true,
    getscripthash = true,
    getscripts = true,
    getscriptthread = true,
    getsenv = true,
    getsimulationradius = true,
    getstack = true,
    getsynasset = true,
    gettenv = true,
    getthreadcontext = true,
    getthreadidentity = true,
    getupvalue = true,
    getupvalues = true,
    hookfunc = true,
    hookfunction = true,
    hookmetamethod = true,
    http_request = true,
    httpget = true,
    identifyexecutor = true,
    is_parallel = true,
    is_readonly = true,
    iscclosure = true,
    isexecutorclosure = true,
    isfile = true,
    isfolder = true,
    isfunctionhooked = true,
    isgameactive = true,
    islclosure = true,
    isnetworkowner = true,
    isnewcclosure = true,
    isourclosure = true,
    isourthread = true,
    isparallel = true,
    isrbxactive = true,
    isreadonly = true,
    isrenderobj = true,
    isscriptable = true,
    isuntouched = true,
    isvalidlevel = true,
    iswindowactive = true,
    keyclick = true,
    keypress = true,
    keyrelease = true,
    keytap = true,
    listfiles = true,
    loadfile = true,
    loadstring = true,
    lz4compress = true,
    lz4decompress = true,
    makefolder = true,
    makereadonly = true,
    makewritable = true,
    messagebox = true,
    messageboxasync = true,
    mouse1click = true,
    mouse1press = true,
    mouse1release = true,
    mouse2click = true,
    mouse2press = true,
    mouse2release = true,
    mousemoveabs = true,
    mousemoverel = true,
    mousescroll = true,
    newcclosure = true,
    newlclosure = true,
    queue_on_teleport = true,
    queueonteleport = true,
    rconsoleclear = true,
    rconsolecreate = true,
    rconsoledestroy = true,
    rconsoleerr = true,
    rconsoleerror = true,
    rconsolehide = true,
    rconsoleinfo = true,
    rconsoleinput = true,
    rconsolename = true,
    rconsoleprint = true,
    rconsolesettitle = true,
    rconsoleshow = true,
    rconsolewarn = true,
    readfile = true,
    replaceclosure = true,
    replicatesignal = true,
    request = true,
    require = true,
    restorefunc = true,
    restorefunction = true,
    run_on_actor = true,
    run_on_thread = true,
    saveinstance = true,
    set_internal_parent = true,
    set_namecall_method = true,
    set_readonly = true,
    set_thread_identity = true,
    setcaps = true,
    setclipboard = true,
    setclosurecaps = true,
    setconstant = true,
    setfflag = true,
    setfpscap = true,
    sethiddenprop = true,
    sethiddenproperty = true,
    setidentity = true,
    setinternalparent = true,
    setname = true,
    setnamecallmethod = true,
    setproximitypromptduration = true,
    setrawmetatable = true,
    setrbxclipboard = true,
    setreadonly = true,
    setrenderproperty = true,
    setsafeenv = true,
    setscriptable = true,
    setsimulationradius = true,
    setstack = true,
    setstackhidden = true,
    setthreadcontext = true,
    setthreadidentity = true,
    setuntouched = true,
    setupvalue = true,
    setwindowtitle = true,
    toclipboard = true,
    validlevel = true,
    writefile = true,
    playemote = true,
    try_load = true,
    change_gravity_val = true,
    execCmd = true,
    disabled_global_value_correctly = true,
    name_changer_premium = true,
    Flames_Debugger_Function_Tester_GUI = true,
    notify = true,
    start_scan = true,
    SetFPSCap = true,
    low_level_executor = true,
    getcallstack = true,
    getfastflag = true,
    getfastflagtype = true,
    getfflagtype = true,
    gethiddenproperties = true,
    getpcdprop = true,
    getproperties = true,
    getsignalarguments = true,
    getsignalargumentsinfo = true,
    getsignalwhitelist = true,
    getthreadcaps = true,
    info = true,
    makewriteable = true,
    setfastflag = true,
    setinfo = true,
    dumpbytecode = true,
}

g.Flames_Debugger_Function_Tester_GUI = g.Flames_Debugger_Function_Tester_GUI or function()
    local genv = g
    local start_scan

    if genv.__flames_debugger_running then
        if g.notify then
            g.notify("Warning", "Yadsan Debugger is already running!", 5)
            return 
        else
            warn("Yadsan Debugger is already running.")
            return
        end
    end

    if CoreGui:FindFirstChild("FlamesDebugger") then
        CoreGui.FlamesDebugger.Enabled = true
        genv.__flames_debugger_running = false
        g.dont_receive_any_notifications_flames_hub = false
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlamesDebugger"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(400,300)
    frame.Position = UDim2.fromScale(0.4,0.3)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    frame.Parent = gui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-150,0,30)
    title.Position = UDim2.new(0,10,0,5)
    title.BackgroundTransparency = 1
    title.Text = "Yadsan Hub | Debugger"
    title.TextScaled = true
    title.TextColor3 = Color3.new(1,1,1)
    title.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(26,26)
    close.Position = UDim2.new(1,-32,0,4)
    close.Text = "X"
    close.TextScaled = true
    close.BackgroundColor3 = Color3.fromRGB(120,40,40)
    close.TextColor3 = Color3.new(1,1,1)
    close.Parent = frame

    Instance.new("UICorner", close).CornerRadius = UDim.new(1,0)
    close.MouseButton1Click:Connect(function() gui.Enabled = false end)
    local rescan = Instance.new("TextButton")
    rescan.Size = UDim2.fromOffset(90,24)
    rescan.Position = UDim2.new(1,-130,0,6)
    rescan.Text = "Start Scan"
    rescan.TextScaled = true
    rescan.BackgroundColor3 = Color3.fromRGB(40,90,140)
    rescan.TextColor3 = Color3.new(1,1,1)
    rescan.Parent = frame

    rescan.MouseButton1Click:Connect(function()
        if not genv.__flames_debugger_running then
            genv.__flames_debugger_running = true
            g.dont_receive_any_notifications_flames_hub = true
            start_scan()
        end
    end)

    Instance.new("UICorner", rescan).CornerRadius = UDim.new(0,6)

    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.new(0,10,0,40)
    list.Size = UDim2.new(1,-20,1,-50)
    list.CanvasSize = UDim2.new(0,0,0,0)
    list.ScrollBarImageTransparency = 0.2
    list.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,4)
    layout.Parent = list

    local function update_canvas() list.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 6) end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update_canvas)
    local function add_row(text, success)
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1,-6,0,24)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextScaled = true
        row.TextColor3 = Color3.new(1,1,1)
        row.BackgroundColor3 = success and Color3.fromRGB(30,80,30) or Color3.fromRGB(90,30,30)
        row.Text = (success and "  ?  " or "  ?  ") .. text
        row.Parent = list
    end

    local function snapshot_guis()
        local snap = {}
        for _,v in ipairs(CoreGui:GetChildren()) do
            if v:IsA("ScreenGui") then
                snap[v] = true
            end
        end
        return snap
    end

    local function cleanup_guis(before)
        for _,v in ipairs(CoreGui:GetChildren()) do
            if v:IsA("ScreenGui") and not before[v] and v ~= gui then
                pcall(function()
                v:Destroy()
                end)
            end
        end
    end

    local function clear_list()
        for _,v in ipairs(list:GetChildren()) do
            if v:IsA("TextLabel") then
                v:Destroy()
            end
        end
    end

    if rescan and rescan:IsA("TextButton") then
        task.spawn(function()
            while true do
                wait(0.5)
                if g.button_text_changing_for_debug_scanner then
                    wait(0.5)
                    rescan.Text = "Scan Running."
                    wait(0.6)
                    if not g.button_text_changing_for_debug_scanner then continue end
                    rescan.Text = "Scan Running.."
                    wait(0.6)
                    if not g.button_text_changing_for_debug_scanner then continue end
                    rescan.Text = "Scan Running..."
                    wait(0.6)
                else
                    wait(0.6)
                end
            end
        end)
    end

    start_scan = function()
        task.spawn(function()
            g.button_text_changing_for_debug_scanner = true
            local function run_scan()
                clear_list()
                local tested = 0

                for name,value in next,genv do
                    if tested >= 25 then break end
                    if typeof(value) == "function" and not excluded_functions[name] then
                        tested = tested + 1
                        local before = snapshot_guis()
                        local ok, err = pcall(value)
                        cleanup_guis(before)

                        if ok then
                            add_row(name.."()", true)
                        else
                            if typeof(err) == "string" then
                                local lower = err:lower()
                                if lower:find("nil") or lower:find("argument") or lower:find("index") then
                                    add_row(name.."() - ignore", false)
                                else
                                    add_row(name.."() - runtime error", false)
                                end
                            else
                                add_row(name.."()", false)
                            end
                        end

                        wait(0.5)
                    end
                end

                if tested == 0 then
                    add_row("No functions found to test", false)
                    g.dont_receive_any_notifications_flames_hub = false
                else
                    add_row("Completed testing "..tested.." functions", true)
                    g.dont_receive_any_notifications_flames_hub = false
                end
            end

            pcall(function() run_scan() end)
            task.wait(0.15)
            g.button_text_changing_for_debug_scanner = false
            genv.__flames_debugger_running = false
            g.dont_receive_any_notifications_flames_hub = false
            if rescan and rescan:IsA("TextButton") then rescan.Text = "Start Scan" end
        end)
    end

    local dragging = false
    local drag_start
    local start_pos
    local drag_input
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            drag_start = input.Position
            start_pos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            drag_input = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == drag_input and dragging then
            local delta = input.Position - drag_start
            frame.Position = UDim2.new(
                start_pos.X.Scale,
                start_pos.X.Offset + delta.X,
                start_pos.Y.Scale,
                start_pos.Y.Offset + delta.Y
            )
        end
    end)
end

g.CreateCreditsLabel = function()
    if g.CreditsLabelGui then g.CreditsLabelGui:Destroy() end
    local creditsGui = Instance.new("ScreenGui")
    creditsGui.Name = "PrefixCreditsGui_LifeTogether"
    creditsGui.ResetOnSpawn = false
    creditsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    creditsGui.Parent = CoreGui

    local label = Instance.new("TextLabel")
    label.Name = "CreditsLabel"
    g.MainCreditsLabel_WithPrefix = label
    label.AnchorPoint = Vector2.new(0.5, 1)

    if IsMobile then
        label.Position = UDim2.new(0.5, 0, 0.95, -10)
        label.Size = UDim2.new(0.3, 0, 0, 28)
    else
        label.Position = UDim2.new(0.5, 0, 0.949999988, 25)
        label.Size = UDim2.new(0.6, 0, 0, 28)
    end

    label.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    label.TextColor3 = Color3.fromRGB(0, 0, 0)
    g.flowrgb("PrefixCreditsLabelConn", 1, label, true)
    local parts = {tostring(g.Script_Version)}
    if holiday ~= "" then table.insert(parts, holiday) end
    table.insert(parts, "Made By: " .. tostring(g.Script_Creator))
    if masked_flames_hub_server_ID then table.insert(parts, "Your Flames-Hub UUID: " .. tostring(masked_flames_hub_server_ID)) end
    label.Text = table.concat(parts, " | ")
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.RichText = false
    label.TextStrokeTransparency = 1
    label.BackgroundTransparency = 0
    label.ZIndex = 10
    label.Parent = creditsGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = label

    g.CreditsLabelGui = creditsGui
    g.CreditsLabelText = label
    if g._PrefixUpdateConnection then g._PrefixUpdateConnection:Disconnect() end
    local holiday_parts = {tostring(g.Script_Version)}
    if holiday ~= "" then table.insert(holiday_parts, holiday) end
    table.insert(holiday_parts, "Made By: " .. tostring(g.Script_Creator))
    if masked_flames_hub_server_ID then table.insert(holiday_parts, "Your Flames-Hub UUID: " .. tostring(masked_flames_hub_server_ID)) end
    label.Text = table.concat(holiday_parts, " | ")
end

g.CreateCreditsLabel()
g.hidden_pcm = setmetatable({}, { __mode = "k" })
g.HidePhoneModels = g.HidePhoneModels or false
g.phone_model_anti_rgb_phone_hider_values = setmetatable({}, { __mode = "k" })
g._pcm_registry = setmetatable({}, { __mode = "k" })
local SavedValues = g.phone_model_anti_rgb_phone_hider_values
g.hide_pcm = g.hide_pcm or function(pcm)
    if not pcm or not pcm:IsA("Model") then return end
    if g.hidden_pcm[pcm] then return end
    SavedValues[pcm] = SavedValues[pcm] or {}

    for _, v in ipairs(pcm:GetDescendants()) do
        if v:IsA("BasePart") then
            SavedValues[pcm][v] = {
                LocalTransparencyModifier = v.LocalTransparencyModifier,
                CanCollide = v.CanCollide,
                CanQuery = v.CanQuery,
                CanTouch = v.CanTouch
            }
            v.LocalTransparencyModifier = 1
            v.CanCollide = false
            v.CanQuery = false
            v.CanTouch = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            SavedValues[pcm][v] = { Transparency = v.Transparency }
            v.Transparency = 1
        elseif v:IsA("Sound") then
            SavedValues[pcm][v] = { Volume = v.Volume }
            v.Volume = 0
        end
    end

    local desc_conn = pcm.DescendantAdded:Connect(function(v)
        if not g.HidePhoneModels then return end
        SavedValues[pcm] = SavedValues[pcm] or {}
        if v:IsA("BasePart") then
            SavedValues[pcm][v] = {
                LocalTransparencyModifier = v.LocalTransparencyModifier,
                CanCollide = v.CanCollide,
                CanQuery = v.CanQuery,
                CanTouch = v.CanTouch
            }
            v.LocalTransparencyModifier = 1
            v.CanCollide = false
            v.CanQuery = false
            v.CanTouch = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            SavedValues[pcm][v] = { Transparency = v.Transparency }
            v.Transparency = 1
        elseif v:IsA("Sound") then
            SavedValues[pcm][v] = { Volume = v.Volume }
            v.Volume = 0
        end
    end)

    g.hidden_pcm[pcm] = { conn = desc_conn }
end

g.show_pcm = g.show_pcm or function(pcm)
    if not pcm or not pcm:IsA("Model") then return end
    local entry = g.hidden_pcm[pcm]
    if not entry then return end
    if entry.conn and entry.conn.Connected then entry.conn:Disconnect() end
    local pcm_saved = SavedValues[pcm]
    if pcm_saved then
        for _, v in ipairs(pcm:GetDescendants()) do
            local orig = pcm_saved[v]
            if not orig then continue end
            if v:IsA("BasePart") then
                v.LocalTransparencyModifier = orig.LocalTransparencyModifier
                v.CanCollide = orig.CanCollide
                v.CanQuery = orig.CanQuery
                v.CanTouch = orig.CanTouch
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = orig.Transparency
            elseif v:IsA("Sound") then
                v.Volume = orig.Volume
            end
        end
        SavedValues[pcm] = nil
    end

    g.hidden_pcm[pcm] = nil
end

g.try_hide_pcm = g.try_hide_pcm or function(character)
    if not g.HidePhoneModels then return end
    if not character then return end
    local plr = Players:GetPlayerFromCharacter(character)
    if not plr or plr == LocalPlayer then return end
    local pcm = character:FindFirstChild("PhoneCharacterModel")
    if not pcm then return end

    g.hide_pcm(pcm)
end

g.scan_character = g.scan_character or function(character)
    if not character then return end
    task.defer(function() g.try_hide_pcm(character) end)
    local char_id = tostring(character) .. "_childadded"
    local cleanup_id = tostring(character) .. "_ancestry"

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Model") and child.Name == "PhoneCharacterModel" then
            g._pcm_registry[child] = true
        end
    end

    FlamesLibrary.connect(char_id, character.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child.Name == "PhoneCharacterModel" then
            g._pcm_registry[child] = true
            task.defer(function()
                if g.HidePhoneModels then
                    g.hide_pcm(child)
                end
            end)
        end
    end))

    FlamesLibrary.connect(cleanup_id, character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            FlamesLibrary.disconnect(char_id)
            FlamesLibrary.disconnect(cleanup_id)
        end
    end))
end

g.hook_player = g.hook_player or function(plr)
    if plr == LocalPlayer then return end
    local plr_id = tostring(plr.UserId)
    FlamesLibrary.spawn(plr_id .. "_charwait", "spawn", function()
        local char = g.get_char(plr, Players.RespawnTime + 0.75)
        if char then g.scan_character(char) end
    end)

    FlamesLibrary.connect(plr_id .. "_charadded", plr.CharacterAdded:Connect(function(char)
        g.scan_character(char)
    end))
end

FlamesLibrary.disconnect("pmh_playeradded")
FlamesLibrary.disconnect("pmh_playerremoving")
FlamesLibrary.connect("pmh_playeradded", Players.PlayerAdded:Connect(g.hook_player))
FlamesLibrary.connect("pmh_playerremoving", Players.PlayerRemoving:Connect(function(plr)
    local plr_id = tostring(plr.UserId)
    FlamesLibrary.disconnect(plr_id .. "_charadded")
    FlamesLibrary.disconnect(plr_id .. "_charwait")
end))

g.run_hooking_players = function()
    for _, player in ipairs(Players:GetPlayers()) do if player ~= Players.LocalPlayer then g.hook_player(player) end end
end
wait(0.1)
pcall(function() g.run_hooking_players() end)

g.rescan_all_pcms = g.rescan_all_pcms or function()
    for pcm in pairs(g._pcm_registry) do
        if not pcm.Parent then
            g._pcm_registry[pcm] = nil
            continue
        end
        local char = pcm.Parent
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            if g.HidePhoneModels then
                g.hide_pcm(pcm)
            else
                g.show_pcm(pcm)
            end
        end
    end
end

g.TogglePhoneModelHider = g.TogglePhoneModelHider or function(state)
    if type(state) == "boolean" then
        g.HidePhoneModels = state
    else
        g.HidePhoneModels = not g.HidePhoneModels
    end

    if g.HidePhoneModels then
        g.rescan_all_pcms()
    else
        for pcm in pairs(g.hidden_pcm) do
            g.show_pcm(pcm)
        end
    end
end

g.ShutdownPhoneModelHider = g.ShutdownPhoneModelHider or function()
    for pcm in pairs(g.hidden_pcm) do g.show_pcm(pcm) end
    FlamesLibrary.disconnect("pmh_playeradded")
    FlamesLibrary.disconnect("pmh_playerremoving")

    for _, plr in ipairs(Players:GetPlayers()) do
        local plr_id = tostring(plr.UserId)
        FlamesLibrary.disconnect(plr_id .. "_charadded")
        FlamesLibrary.disconnect(plr_id .. "_charwait")
    end

    table.clear(g.hidden_pcm)
    table.clear(SavedValues)
    table.clear(g._pcm_registry)
end

if not g.FlamesHub_CharacterAdded_Initialized then
    g.FlamesHub_CharacterAdded_Initialized = true
    local function character_added_jump_height_changer_Life_Together_RP(Character)
        Character = g.Character or Character
        if not Character or not Character.Parent then Character = LocalPlayer.Character or g.get_char(LocalPlayer, Players.RespawnTime + 0.75) end
        if not Character or not Character.Parent then return end
        local Humanoid = g.Humanoid
        if not Humanoid or not Humanoid.Parent then
            Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 10) or g.get_human(LocalPlayer, Players.RespawnTime + 0.75)
        end

        if Humanoid and Humanoid.Parent then
            Humanoid.JumpHeight = 7
        end
    end

    if g.Character or LocalPlayer.Character then character_added_jump_height_changer_Life_Together_RP(g.Character or LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(character_added_jump_height_changer_Life_Together_RP)
end

g.always_show_title_of_player_regardless_of_chats = g.always_show_title_of_player_regardless_of_chats or function(toggled)
    local lib = g.FlamesLibrary
    local fw = lib.wait
    local key = "showing_billboard_titles_above_heads_anyways"

    if toggled == true then
        if g.always_show_title_above_head then g.notify("Warning", "Yadsan Hub | Anti-Title_Hider is already enabled!", 5); return end
        g.notify("Success", "Yadsan Hub | Anti-Title_Hider is now enabled.", 5)
        g.always_show_title_above_head = true
        lib.spawn(key, "spawn", function()
            while g.always_show_title_above_head == true do
            fw(0)
                for _, v in ipairs(Players:GetPlayers()) do
                    if v ~= Players.LocalPlayer then
                        if not v:GetAttribute("chatting") then lib.disconnect("showing_billboard_titles_above_heads_anyways") end
                        v:SetAttribute("chatting", false)
                    end
                end
            end
        end)
    elseif toggled == false then
        if not g.always_show_title_above_head then g.notify("Warning", "Yadsan Hub | Anti-Title_Hider is not enabled!", 5); return end
        g.always_show_title_above_head = false
        lib.disconnect(key)
        g.notify("Success", "Yadsan Hub | Anti-Title_Hider is now disabled.", 5)
    else
        return 
    end
end

g.change_RP_Name = g.change_RP_Name or function(New_Name) g.Send("roleplay_name", tostring(New_Name)) end
g.change_bio = g.change_bio or function(New_Bio) g.Send("bio", tostring(New_Bio)) end
wait(0.25)
-- [[ ultra safe checking that always works + falls back to your current roleplay name if not already saved so you don't have to do it yourself. ]] --
g.WaitForAttribute = g.WaitForAttribute or function(Instance, Attribute, Timeout)
    local Existing = Instance:GetAttribute(Attribute)
    if Existing ~= nil then return Existing end
    local Start = tick()
    while tick() - Start < (Timeout or 10) do
        local Val = Instance:GetAttribute(Attribute)
        if Val ~= nil then return Val end
        task.wait(0.1)
    end
    return nil
end

g.SafeRead = g.SafeRead or function(File, Fallback)
    if not (isfile and isfile(File)) then return Fallback end
    local Val = readfile(File)
    if not Val or #Val == 0 or Val == "nil" then return Fallback end
    return Val
end

g.SafeAttr = g.SafeAttr or function(Attribute)
    local Val = g.WaitForAttribute(g.LocalPlayer, Attribute, 10)
    if Val == nil then return nil end
    local Str = tostring(Val)
    return (#Str > 0 and Str ~= "nil") and Str or nil
end

if isfile and readfile and writefile and makefolder then
    local Folder = "Life_Together_Custom_Name_Configuration"
    local ConfigPath = Folder .. "/config.json"
    if not isfolder(Folder) then makefolder(Folder) end
    local Config = { Name = "DEFAULT", Bio = "DEFAULT" }
    local function sanitize(val)
        if val == nil or tostring(val) == "nil" or tostring(val) == "" then return "DEFAULT" end
        return tostring(val)
    end

    local Existing = g.SafeRead(ConfigPath, nil)
    if Existing then
        local Decoded = HttpService:JSONDecode(Existing)
        if Decoded then
            Config.Name = sanitize(Decoded.Name)
            Config.Bio = sanitize(Decoded.Bio)
        end
    else
        writefile(ConfigPath, HttpService:JSONEncode(Config))
        g.notify("Success", "Creating config file for you (it didn't exist)...", 10)
    end

    if Config.Name ~= "DEFAULT" then
        g.notify("Success", "Got your last RP name (it was erased by Life Together RP), but we're setting it back!", 15)
        g.change_RP_Name(Config.Name)
    else
        local Name_To_Write = sanitize(g.SafeAttr("roleplay_name"))
        if Name_To_Write ~= "DEFAULT" then
            g.change_RP_Name(Name_To_Write)
            Config.Name = Name_To_Write
        end
    end

    local bio_config = Config
    local bio_config_path = ConfigPath
    lib.spawn("lt_bio_delay", "delay", 61, function()
        if bio_config.Bio ~= "DEFAULT" then
            g.notify("Success", "Got your last RP bio (it was erased by Life Together RP), but we're setting it back!", 15)
            local sanitized_bio = sanitize(bio_config.Bio)
            if sanitized_bio == "DEFAULT" then
                g.change_bio("DEFAULT")
                bio_config.Bio = "DEFAULT"
            else
                g.change_bio(sanitized_bio)
                bio_config.Bio = sanitized_bio
            end
        else
            local Bio_To_Write = sanitize(g.SafeAttr("bio"))
            if Bio_To_Write ~= "DEFAULT" then
                g.change_bio(Bio_To_Write)
                bio_config.Bio = Bio_To_Write
            else
                g.change_bio("DEFAULT")
                bio_config.Bio = "DEFAULT"
            end
        end
        writefile(bio_config_path, HttpService:JSONEncode(bio_config))
    end)

    writefile(ConfigPath, HttpService:JSONEncode(Config))
end

g.job_spammer = g.job_spammer or function(toggle)
    local lib = g.FlamesLibrary
    local key = "job_spammer_loop"
    local fw = lib.wait

    if toggle == true then
        if g.Every_Job then g.notify("Warning", "Job spammer is already enabled! disable it first.", 5); return end
        g.Every_Job = true
        g.notify("Success", "Job Spammer has been enabled.", 5)
        lib.spawn(key, "spawn", function()
            while g.Every_Job == true do
            fw(0)
                g.Send("job", "Police")
                fw(0)
                g.Send("job", "Firefighter")
                fw(0)
                g.Send("job", "Baker")
                fw(0)
                g.Send("job", "Pizza Worker")
                fw(0)
                g.Send("job", "Barista")
                fw(0)
                g.Send("job", "Doctor")
                fw(0)
            end
            lib.disconnect(key)
        end)
    elseif toggle == false then
        if not g.Every_Job then g.notify("Warning", "Job spammer is not enabled! enable it first.", 5); return end
        g.Every_Job = false
        lib.disconnect(key)
        g.notify("Success", "Job Spammer has been disabled.", 5)
    end
end

g.stored_effects_main_tbl = g.stored_effects_main_tbl or {}
g.stored_parts_main_tbl = g.stored_parts_main_tbl or {}
g.parts_seen = g.parts_seen or {}
g.validWorkspacePart = g.validWorkspacePart or function(inst)
    if not inst or not inst.Parent then return false end
    if inst:IsDescendantOf(lighting) then return false end
    if inst:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then return false end
    return true
end

g.saveAndModify = g.saveAndModify or function(inst)
    if g.parts_seen[inst] then return end
    g.parts_seen[inst] = true
    if inst:IsA("BasePart") then
        table.insert(g.stored_parts_main_tbl, {inst = inst, prop = "cast", val = inst.CastShadow})
        inst.CastShadow = false
    elseif inst:IsA("Decal") then
        table.insert(g.stored_parts_main_tbl, {inst = inst, prop = "decal", tex = inst.Texture, transp = inst.Transparency})
        inst.Transparency = 1
        inst.Texture = ""
    elseif inst:IsA("ParticleEmitter") then
        table.insert(g.stored_parts_main_tbl, {inst = inst, prop = "particle", enabled = inst.Enabled, rate = inst.Rate})
        inst.Enabled = false
        inst.Rate = 0
    elseif inst:IsA("Trail") then
        table.insert(g.stored_parts_main_tbl, {inst = inst, prop = "trail", enabled = inst.Enabled})
        inst.Enabled = false
    end
end

g.posteffparts = g.posteffparts or function(toggle)
    local genv = g

    if toggle then
        if genv.post_effects_off_main then return end
        genv.post_effects_off_main = true
        table.clear(genv.stored_effects_main_tbl)
        table.clear(genv.stored_parts_main_tbl)
        table.clear(genv.parts_seen)
        for _, v in ipairs(lighting:GetDescendants()) do
            if v:IsA("PostEffect") then
                table.insert(genv.stored_effects_main_tbl, {inst = v, enabled = v.Enabled})
                v.Enabled = false
            end
        end

        for _, v in ipairs(work:GetDescendants()) do
            if g.validWorkspacePart(v) then
                g.saveAndModify(v)
            end
        end

        genv._saved_fog_start = lighting.FogStart
        genv._saved_fog_end = lighting.FogEnd
        lighting.FogStart = 1e5
        lighting.FogEnd = 1e5

        if genv.parts_disabler_conn then genv.parts_disabler_conn:Disconnect() end
        genv.parts_disabler_conn = work.DescendantAdded:Connect(function(child)
            if not genv.post_effects_off_main then return end
            if not g.validWorkspacePart(child) then return end
            task.defer(function()
                if child.Parent then
                    g.saveAndModify(child)
                end
            end)
        end)
    else
        if not genv.post_effects_off_main then return end
        genv.post_effects_off_main = false

        for _, v in ipairs(genv.stored_effects_main_tbl) do
            if v.inst and v.inst.Parent then
                v.inst.Enabled = v.enabled
            end
        end

        for _, data in ipairs(genv.stored_parts_main_tbl) do
            if data.inst and data.inst.Parent then
                if data.prop == "cast" then
                    data.inst.CastShadow = data.val
                elseif data.prop == "decal" then
                    data.inst.Transparency = data.transp
                    data.inst.Texture = data.tex
                elseif data.prop == "particle" then
                    data.inst.Enabled = data.enabled
                    data.inst.Rate = data.rate
                elseif data.prop == "trail" then
                    data.inst.Enabled = data.enabled
                end
            end
        end

        if genv.parts_disabler_conn then
            genv.parts_disabler_conn:Disconnect()
            genv.parts_disabler_conn = nil
        end

        if genv._saved_fog_start then lighting.FogStart = genv._saved_fog_start end
        if genv._saved_fog_end then lighting.FogEnd = genv._saved_fog_end end
        table.clear(genv.stored_effects_main_tbl)
        table.clear(genv.stored_parts_main_tbl)
        table.clear(genv.parts_seen)
    end
end

g.TogglePostEffectsParts = g.posteffparts
g.FlamesLagReducerFunc = g.FlamesLagReducerFunc or function(toggle)
    if toggle then
        if g.ultimate_lag_reducer then g.notify("Warning", "Yadsan Hub | Lag Reducer : is already enabled.", 3); return end
        g.ultimate_lag_reducer = true
        g.notify("Success", "Yadsan Hub | Lag Reducer : is now enabled.", 5)
        pcall(function() g.Send("hide_other_names", true) end)
        pcall(function() g.Send("hide_map_icon", true) end)
        if g.togglergbflows and typeof(g.togglergbflows) == "function" then pcall(g.togglergbflows, false) end
        g.posteffparts(true)
    else
        if not g.ultimate_lag_reducer then g.notify("Warning", "Yadsan Hub | Lag Reducer : is not enabled.", 3); return end
        g.ultimate_lag_reducer = false
        g.notify("Success", "Yadsan Hub | Lag Reducer : is now disabled.", 5)
        pcall(function() g.Send("hide_other_names", false) end)
        pcall(function() g.Send("hide_map_icon", false) end)
        g.posteffparts(false)
    end
end

g.DefaultSpeed = g.StarterPlayer.CharacterWalkSpeed
g.DefaultJP = g.StarterPlayer.CharacterJumpHeight
g.Old_Workspace_Gravity = g.Workspace.Gravity
g.change_property = g.change_property or function(property, new_property_value)
    local properties_allowed_to_be_changed = {
        WalkSpeed = true,
        JumpHeight = true,
        HipHeight = true
    }

    if properties_allowed_to_be_changed[property] and g.Humanoid then g.Humanoid[property] = new_property_value end
end

g.change_gravity_val = g.change_gravity_val or function(new_val)
    if new_val > 300 then new_val = 196 end
    g.Workspace.Gravity = tonumber(new_val) or 196
end

g.reset_properties = g.reset_properties or function()
   if not g.Humanoid then return end
   g.Humanoid.WalkSpeed = g.DefaultSpeed or 16
   g.Humanoid.JumpHeight = g.DefaultJP or 7
   g.Workspace.Gravity = g.Old_Workspace_Gravity or 196
end

g.rainbow_car = g.rainbow_car or function()
    g.RGB_Vehicle(true)
end

g.stop_rainbow_car = g.stop_rainbow_car or function()
    g.RGB_Vehicle(false)
end

g.rainbow_others_car = g.rainbow_others_car or function(Player)
    g.RGB_Vehicle_Others(Player, true)
end

g.stop_rainbow_others_car = g.stop_rainbow_others_car or function(Player)
    g.RGB_Vehicle_Others(Player, false)
end

local camera = Workspace.CurrentCamera or g.Workspace.CurrentCamera or workspace.CurrentCamera
g.AdonisAdminFlyEnabled = g.AdonisAdminFlyEnabled or false
g.AdonisAdminFlySpeed = g.AdonisAdminFlySpeed or 15
g.FlyConnections = g.FlyConnections or {}
g.FlyPart = g.FlyPart or nil

g.SetAdonisFlySpeed = g.SetAdonisFlySpeed or function(v)
    v = tonumber(v)
    if not v then return end
    g.AdonisAdminFlySpeed = math.clamp(v, 1, 300)
end

g.StartAdonisAdminFlyScript = g.StartAdonisAdminFlyScript or function()
    if g.AdonisAdminFlyEnabled then return end
    g.AdonisAdminFlyEnabled = true
    local dir = {w = false, a = false, s = false, d = false, q = false, e = false}
    local cf = Instance.new("CFrameValue")

    if not g.FlyPart then
        g.FlyPart = Instance.new("Part")
        g.FlyPart.Name = "PART_SURFER"
        g.FlyPart.Anchored = true
        g.FlyPart.Parent = g.StarterPack or cloneref and cloneref(game:GetService("StarterPack")) or game:GetService("StarterPack")
        g.FlyPart.CFrame = g.HumanoidRootPart and g.HumanoidRootPart.CFrame or CFrame.new()
    end

    g.FlyConnections.render = RunService.RenderStepped:Connect(function()
        if not g.AdonisAdminFlyEnabled or not g.HumanoidRootPart then return end
        local speed = tonumber(g.AdonisAdminFlySpeed) or 15
        speed = math.clamp(speed, 1, 300)

        for _, v in pairs(character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Velocity = Vector3.zero
                v.RotVelocity = Vector3.zero
            end
        end

        g.FlyPart.CFrame = CFrame.new(
            g.FlyPart.CFrame.Position,
            (camera.CFrame * CFrame.new(0, 0, -100)).Position
        )

        local offset = Vector3.zero
        if IsMobile and controlModule then
            local mv = controlModule:GetMoveVector()
            if mv.Magnitude > 0 then offset = (camera.CFrame.LookVector * -mv.Z + camera.CFrame.RightVector * mv.X) * speed end
        else
            local x, y, z = 0, 0, 0
            if dir.w then z = -speed end
            if dir.s then z = speed end
            if dir.a then x = -speed end
            if dir.d then x = speed end
            if dir.q then y = speed end
            if dir.e then y = -speed end
            offset = Vector3.new(x, y, z)
        end

        local moveCF = CFrame.new(offset)
        cf.Value = cf.Value:Lerp(moveCF, 0.2)
        g.FlyPart.CFrame = g.FlyPart.CFrame:Lerp(g.FlyPart.CFrame * cf.Value, 0.2)
        g.HumanoidRootPart.CFrame = g.FlyPart.CFrame
        humanoid.PlatformStand = true
    end)

    g.FlyConnections.inputBegan = UserInputService.InputBegan:Connect(function(input, event)
        if event or not g.AdonisAdminFlyEnabled then return end
        local code, codes = input.KeyCode, Enum.KeyCode
        if code == codes.W then
            dir.w = true
        elseif code == codes.A then dir.a = true
        elseif code == codes.S then dir.s = true
        elseif code == codes.D then dir.d = true
        elseif code == codes.Q then dir.q = true
        elseif code == codes.E then dir.e = true
        elseif code == codes.Space then
            dir.q = true
        end
    end)

    g.FlyConnections.inputEnded = UserInputService.InputEnded:Connect(function(input, event)
        if event or not g.AdonisAdminFlyEnabled then return end
        local code, codes = input.KeyCode, Enum.KeyCode
        if code == codes.W then
            dir.w = false
        elseif code == codes.A then dir.a = false
        elseif code == codes.S then dir.s = false
        elseif code == codes.D then dir.d = false
        elseif code == codes.Q then dir.q = false
        elseif code == codes.E then dir.e = false
        elseif code == codes.Space then
            dir.q = false
        end
    end)
    fw(0.1)
    g.notify("Success", "Fly-3 has been enabled with speed: "..tostring(g.AdonisAdminFlySpeed), 6)
end

g.Stop_Fly_3_Function = g.Stop_Fly_3_Function or function()
    if not g.AdonisAdminFlyEnabled then g.notify("Warning", "Fly-3 is not enabled.", 3); return end
    g.AdonisAdminFlyEnabled = false
    for _, conn in pairs(g.FlyConnections) do if conn then conn:Disconnect() end end
    if next(g.FlyConnections) then g.FlyConnections = {} end
    if g.FlyPart then
        g.FlyPart:Destroy()
        g.FlyPart = nil
    end
    if humanoid and humanoid.Parent and humanoid:IsDescendantOf(game) then humanoid.PlatformStand = false end
end

g.Enabled_Flying = g.Enabled_Flying or false
g.Fly2Speed = g.Fly2Speed or 45
g.Fly2Control = nil
g.fly2InputBegan = nil
g.fly2InputEnded = nil
g.fly2Heartbeat = nil
g.fly2MobileConn = nil
g.EnableFly2 = g.EnableFly2 or function(speed)
    if g.Enabled_Flying then g.notify("Warning", "Fly-2 is already enabled!", 3); return end
    local char = g.Character or plr.Character or g.get_char(plr, 3)
    local HRP = g.HumanoidRootPart or char and char:FindFirstChild("HumanoidRootPart") or g.get_root(plr, 3)
    local Humanoid = g.Humanoid or char and char:FindFirstChildOfClass("Humanoid") or g.get_human(plr, 3)
    if not HRP or not Humanoid then g.notify("Error", "Character is not ready or Humanoid is missing.", 5); return end
    g.Enabled_Flying = true
    g.Fly2Speed = tonumber(speed) or 10
    g.Fly2Control = {F=0,B=0,L=0,R=0}
    local flyY, lastPos = 0, nil
    local gyro = Instance.new("BodyGyro")
    gyro.P = 9e4
    gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    gyro.CFrame = HRP.CFrame
    gyro.Name = "Fly2Gyro"
    gyro.Parent = HRP

    local vel = Instance.new("BodyVelocity")
    vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    vel.Velocity = Vector3.zero
    vel.Name = "Fly2Velocity"
    vel.Parent = HRP
    if Humanoid and Humanoid.Parent and Humanoid:IsDescendantOf(game) then Humanoid.PlatformStand = true end
    if not IsMobile then
        if g.fly2InputBegan then g.fly2InputBegan:Disconnect() end
        if g.fly2InputEnded then g.fly2InputEnded:Disconnect() end
        if g.fly2Heartbeat then g.fly2Heartbeat:Disconnect() end

        g.fly2InputBegan = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            local s = g.Fly2Speed
            if input.KeyCode == Enum.KeyCode.W then g.Fly2Control.F = s end
            if input.KeyCode == Enum.KeyCode.S then g.Fly2Control.B = -s end
            if input.KeyCode == Enum.KeyCode.A then g.Fly2Control.L = -s end
            if input.KeyCode == Enum.KeyCode.D then g.Fly2Control.R = s end
            if input.KeyCode == Enum.KeyCode.Space then flyY = s end
            if input.KeyCode == Enum.KeyCode.LeftShift then flyY = -s end
        end)

        g.fly2InputEnded = UIS.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then g.Fly2Control.F = 0 end
            if input.KeyCode == Enum.KeyCode.S then g.Fly2Control.B = 0 end
            if input.KeyCode == Enum.KeyCode.A then g.Fly2Control.L = 0 end
            if input.KeyCode == Enum.KeyCode.D then g.Fly2Control.R = 0 end
            if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.LeftShift then flyY = 0 end
        end)

        g.fly2Heartbeat = RunService.RenderStepped:Connect(function()
            if not g.Enabled_Flying then return end
            local C, cam, SPEED = g.Fly2Control, Workspace.CurrentCamera, g.Fly2Speed * 50
            if C.F~=0 or C.B~=0 or C.L~=0 or C.R~=0 or flyY~=0 then
                local move_vec = ((cam.CFrame.LookVector * (C.F + C.B)) + ((cam.CFrame * CFrame.new(C.L + C.R, flyY * 0.5, 0)).Position - cam.CFrame.Position))
                if move_vec.Magnitude > 0 then vel.Velocity = move_vec.Unit * SPEED end
            else
                vel.Velocity = vel.Velocity * 0.9
            end

            gyro.CFrame = cam.CFrame
            local pos = HRP.Position
            if not lastPos or (pos - lastPos).Magnitude > 1 then
                local part = Instance.new("Part")
                part.Anchored = true
                part.CanCollide = false
                part.Material = Enum.Material.Neon
                part.Size = Vector3.new(1,1,(pos - (lastPos or pos)).Magnitude + 2)
                part.CFrame = CFrame.new((lastPos or pos) + ((pos - (lastPos or pos)) / 2), pos)
                part.Color = g.colors[math.random(1, #g.colors)]
                part.Parent = Workspace
                Debris:AddItem(part, 1)
                lastPos = pos
            end
        end)

        g.notify("Success", "Fly-2 enabled (PC) | Speed: " .. tostring(g.Fly2Speed), 5)
        return
    end

    local controlModule
    local ok, result = pcall(function()
        return require(plr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
    end)
    if ok then controlModule = result end
    g.fly2MobileConn = RunService.RenderStepped:Connect(function()
        if not g.Enabled_Flying then return end
        local cam = Workspace.CurrentCamera
        local s = g.Fly2Speed * 50
        local move = controlModule and controlModule:GetMoveVector() or Vector3.zero

        if move.Magnitude > 0 then
            vel.Velocity = (cam.CFrame.LookVector * -move.Z + cam.CFrame.RightVector * move.X) * s
        else
            vel.Velocity = Vector3.zero
        end

        gyro.CFrame = cam.CFrame

        local pos = HRP.Position
        if not lastPos or (pos - lastPos).Magnitude > 1 then
            local part = Instance.new("Part")
            part.Anchored = true
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Size = Vector3.new(1,1,(pos - (lastPos or pos)).Magnitude + 2)
            part.CFrame = CFrame.new((lastPos or pos) + ((pos - (lastPos or pos)) / 2), pos)
            part.Color = g.colors[math.random(1, #g.colors)]
            part.Parent = Workspace
            Debris:AddItem(part, 1)
            lastPos = pos
        end
    end)

    g.notify("Success", "Fly-2 enabled (Mobile) | Speed: " .. tostring(g.Fly2Speed), 5)
end

g.DisableFly2 = g.DisableFly2 or function()
    if not g.Enabled_Flying then g.notify("Warning", "Fly-2 is not enabled, enable it first!", 5); return end
    g.Enabled_Flying = false
    if g.fly2InputBegan then g.fly2InputBegan:Disconnect() end
    if g.fly2InputEnded then g.fly2InputEnded:Disconnect() end
    if g.fly2Heartbeat then g.fly2Heartbeat:Disconnect() end
    if g.fly2MobileConn then g.fly2MobileConn:Disconnect() end
    local HRP = g.HumanoidRootPart or g.Character:FindFirstChild("HumanoidRootPart") or g.get_root(g.LocalPlayer, 3)
    local Humanoid = g.Humanoid or g.Character:FindFirstChildOfClass("Humanoid") or g.get_human(g.LocalPlayer, 3)
    if HRP then for _, v in ipairs(HRP:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
    if Humanoid then Humanoid.PlatformStand = false end
    g.notify("Success", "Fly-2 is now disabled.", 5)
end

g.vehicle_stats_viewer_GUI = g.vehicle_stats_viewer_GUI or function()
    local Vehicles = Workspace:FindFirstChild("Vehicles")
    if not Vehicles or not Vehicles:IsA("Folder") then g.notify("Error", "Vehicles Folder not found!", 3); return end
    if g.Vehicle_Stats_GUI_Active then g.notify("Error", "Vehicle Stats Viewer already running!", 5); return end
    g.Vehicle_Stats_GUI_Active = true
    g.VehicleUI = {}
    g.vehicle_attr_conns = {}
    g.Vehicle_Added_And_Removed_Conns = {}

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "VehicleStatsGUI"
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = parent_gui
    g.VehicleStatsGUI = ScreenGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0,300,0,400)
    MainFrame.Position = UDim2.new(0,20,0,100)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)
    repeat task.wait(1) until MainFrame and MainFrame:IsA("Frame") and ScreenGui:FindFirstChildOfClass("Frame")
    wait(0.5)
    if g.dragify and typeof(g.dragify) == "function" then g.dragify(MainFrame) end
    g.notify("Info", "Loading Vehicle Stats viewer.", 3)

    g.Unhook = function(vehicle)
        local ui = g.VehicleUI[vehicle]
        if not ui then return end
        local conns = g.vehicle_attr_conns[vehicle]
        if conns then for _,c in ipairs(conns) do if c then pcall(function() c:Disconnect() end) end end end
        if ui.Frame then pcall(function() ui.Frame:Destroy() end) end
        g.vehicle_attr_conns[vehicle] = nil
        g.VehicleUI[vehicle] = nil
    end

    g.Hook = function(vehicle)
        if g.VehicleUI[vehicle] then return end
        local ui = g.CreateEntry(vehicle)
        g.VehicleUI[vehicle] = ui
        local conns = {}
        g.vehicle_attr_conns[vehicle] = conns

        table.insert(conns, vehicle:GetAttributeChangedSignal("speed"):Connect(function() ui.Speed.Text = tostring(vehicle:GetAttribute("speed") or 0) end))
        table.insert(conns, vehicle:GetAttributeChangedSignal("acceleration"):Connect(function() ui.Accel.Text = tostring(vehicle:GetAttribute("acceleration") or 0) end))
        table.insert(conns, vehicle:GetAttributeChangedSignal("handling"):Connect(function() ui.Handling.Text = tostring(vehicle:GetAttribute("handling") or 0) end))
        table.insert(conns, vehicle:GetAttributeChangedSignal("color"):Connect(function()
            local c = vehicle:GetAttribute("color")
            if typeof(c) == "Color3" then ui.Color.BackgroundColor3 = c end
        end))

        table.insert(conns, vehicle.AncestryChanged:Connect(function(_, parent) if not parent then g.Unhook(vehicle) end end))
    end

    local Title = Instance.new("TextLabel")
    Title.Text = "Vehicle Stats Viewer"
    Title.Size = UDim2.new(1,-40,0,30)
    Title.Position = UDim2.new(0,10,0,5)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    local Close = Instance.new("TextButton")
    Close.Text = "X"
    Close.Size = UDim2.new(0,30,0,30)
    Close.Position = UDim2.new(1,-35,0,5)
    Close.BackgroundColor3 = Color3.fromRGB(50,50,50)
    Close.TextColor3 = Color3.fromRGB(255,255,255)
    Close.Parent = MainFrame
    Instance.new("UICorner", Close).CornerRadius = UDim.new(0,8)

    Close.MouseButton1Click:Connect(function()
        g.Vehicle_Stats_GUI_Active = false
        if g.Vehicle_Added_And_Removed_Conns then
            for _, conn in pairs(g.Vehicle_Added_And_Removed_Conns) do
                pcall(function() conn:Disconnect() end)
            end
            table.clear(g.Vehicle_Added_And_Removed_Conns)
        end

        for v in pairs(g.VehicleUI) do g.Unhook(v) end
        ScreenGui:Destroy()
    end)

    local Scroller = Instance.new("ScrollingFrame")
    Scroller.Size = UDim2.new(1,-20,1,-90)
    Scroller.Position = UDim2.new(0,10,0,40)
    Scroller.CanvasSize = UDim2.new(0,0,0,0)
    Scroller.ScrollBarThickness = 6
    Scroller.BackgroundTransparency = 1
    Scroller.Parent = MainFrame

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0,10)
    Layout.Parent = Scroller

    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Scroller.CanvasSize = UDim2.new(0,0,0,Layout.AbsoluteContentSize.Y + 10)
    end)

    local function Validate_Model(v)
        if not v:IsA("Model") then return false end
        if v:FindFirstChild("Base") then return true end
        v:WaitForChild("Base", 3)
        return v:FindFirstChild("Base") ~= nil
    end

    g.get_color_name = function(color)
        if not color or typeof(color) ~= "Color3" then return "Unknown" end
        local get_color_name_colors = {
            {"White",1,242,243,243},
            {"Grey",2,161,165,162},
            {"Light yellow",3,249,233,153},
            {"Brick yellow",5,215,197,154},
            {"Light green (Mint)",6,194,218,184},
            {"Light reddish violet",9,232,186,200},
            {"Pastel Blue",11,128,187,219},
            {"Light orange brown",12,203,132,66},
            {"Nougat",18,204,142,105},
            {"Bright red",21,196,40,28},
            {"Med. reddish violet",22,196,112,160},
            {"Bright blue",23,13,105,172},
            {"Bright yellow",24,245,205,48},
            {"Earth orange",25,98,71,50},
            {"Black",26,27,42,53},
            {"Dark grey",27,109,110,108},
            {"Dark green",28,40,127,71},
            {"Medium green",29,161,196,140},
            {"Lig. Yellowich orange",36,243,207,155},
            {"Bright green",37,75,151,75},
            {"Dark orange",38,160,95,53},
            {"Light bluish violet",39,193,202,222},
            {"Transparent",40,236,236,236},
            {"Tr. Red",41,205,84,75},
            {"Tr. Lg blue",42,193,223,240},
            {"Tr. Blue",43,123,182,232},
            {"Tr. Yellow",44,247,241,141},
            {"Light blue",45,180,210,228},
            {"Tr. Flu. Reddish orange",47,217,133,108},
            {"Tr. Green",48,132,182,141},
            {"Tr. Flu. Green",49,248,241,132},
            {"Phosph. White",50,236,232,222},
            {"Light red",100,238,196,182},
            {"Medium red",101,218,134,122},
            {"Medium blue",102,110,153,202},
            {"Light grey",103,199,193,183},
            {"Bright violet",104,107,50,124},
            {"Br. yellowish orange",105,226,155,64},
            {"Bright orange",106,218,133,65},
            {"Bright bluish green",107,0,143,156},
            {"Earth yellow",108,104,92,67},
            {"Bright bluish violet",110,67,84,147},
            {"Tr. Brown",111,191,183,177},
            {"Medium bluish violet",112,104,116,172},
            {"Tr. Medi. reddish violet",113,229,173,200},
            {"Med. yellowish green",115,199,210,60},
            {"Med. bluish green",116,85,165,175},
            {"Light bluish green",118,183,215,213},
            {"Br. yellowish green",119,164,189,71},
            {"Lig. yellowish green",120,217,228,167},
            {"Med. yellowish orange",121,231,172,88},
            {"Br. reddish orange",123,211,111,76},
            {"Bright reddish violet",124,146,57,120},
            {"Light orange",125,234,184,146},
            {"Tr. Bright bluish violet",126,165,165,203},
            {"Gold",127,220,188,129},
            {"Dark nougat",128,174,122,89},
            {"Silver",131,156,163,168},
            {"Neon orange",133,213,115,61},
            {"Neon green",134,216,221,86},
            {"Sand blue",135,116,134,157},
            {"Sand violet",136,135,124,144},
            {"Medium orange",137,224,152,100},
            {"Sand yellow",138,149,138,115},
            {"Earth blue",140,32,58,86},
            {"Earth green",141,39,70,45},
            {"Tr. Flu. Blue",143,207,226,247},
            {"Sand blue metallic",145,121,136,161},
            {"Sand violet metallic",146,149,142,163},
            {"Sand yellow metallic",147,147,135,103},
            {"Dark grey metallic",148,87,88,87},
            {"Black metallic",149,22,29,50},
            {"Light grey metallic",150,171,173,172},
            {"Sand green",151,120,144,130},
            {"Sand red",153,149,121,119},
            {"Dark red",154,123,46,47},
            {"Tr. Flu. Yellow",157,255,246,123},
            {"Tr. Flu. Red",158,225,164,194},
            {"Gun metallic",168,117,108,98},
            {"Dark stone grey",199,99,95,98},
            {"Medium stone grey",194,163,162,165},
            {"Light stone grey",208,229,228,223},
            {"Really black",1003,17,17,17},
            {"Really red",1004,255,0,0},
            {"Deep orange",1005,255,176,0},
            {"Alder",1006,180,128,255},
            {"Dusty Rose",1007,163,75,75},
            {"Olive",1008,193,190,66},
            {"New Yeller",1009,255,255,0},
            {"Really blue",1010,0,0,255},
            {"Navy blue",1011,0,32,96},
            {"Deep blue",1012,33,84,185},
            {"Cyan",1013,4,175,236},
            {"CGA brown",1014,170,85,0},
            {"Magenta",1015,170,0,170},
            {"Pink",1016,255,102,204},
            {"Deep orange",1017,255,175,0},
            {"Teal",1018,18,238,212},
            {"Toothpaste",1019,0,255,255},
            {"Lime green",1020,0,255,0},
            {"Camo",1021,58,125,21},
            {"Grime",1022,127,142,100},
            {"Lavender",1023,140,91,159},
            {"Pastel light blue",1024,175,221,255},
            {"Pastel orange",1025,255,201,201},
            {"Pastel violet",1026,177,167,255},
            {"Pastel blue-green",1027,159,243,233},
            {"Pastel green",1028,204,255,204},
            {"Pastel yellow",1029,255,255,204},
            {"Pastel brown",1030,255,204,153},
            {"Royal purple",1031,98,37,209},
            {"Hot pink",1032,255,0,191},
        }

        local closest, closestDist = "Unknown", math.huge
        local r, g, b = color.R * 255, color.G * 255, color.B * 255
        for _, c in ipairs(get_color_name_colors) do
            local _, _, R, G, B = unpack(c)
            local dist = (R - r)^2 + (G - g)^2 + (B - b)^2
            if dist < closestDist then
                closestDist = dist
                closest = c[1]
            end
        end

        return closest
    end

    local function CreateEntry(vehicle)
        local Holder = Instance.new("Frame")
        Holder.Size = UDim2.new(1,0,0,220)
        Holder.BackgroundColor3 = Color3.fromRGB(35,35,35)
        Holder.Parent = Scroller
        Instance.new("UICorner", Holder).CornerRadius = UDim.new(0,10)

        local Click = Instance.new("TextButton")
        Click.Size = UDim2.new(1,0,1,0)
        Click.BackgroundTransparency = 1
        Click.Text = ""
        Click.Parent = Holder
        Click.Activated:Connect(function()
            g.SelectedVehicle = vehicle.Name
        end)

        local spawn = Instance.new("TextButton")
        spawn.Size = UDim2.new(1,-20,0,28)
        spawn.Position = UDim2.new(0,10,1,-34)
        spawn.Text = "Spawn"
        spawn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        spawn.TextColor3 = Color3.fromRGB(255,255,255)
        spawn.Font = Enum.Font.GothamMedium
        spawn.TextSize = 14
        spawn.Parent = Holder
        Instance.new("UICorner", spawn).CornerRadius = UDim.new(0,8)

        spawn.Activated:Connect(function()
            g.SelectedVehicle = vehicle.Name
            g.Send("spawn_vehicle", vehicle.Name)

            local my_vehicle
            local t = tick()

            repeat
                my_vehicle = g.get_vehicle()
                task.wait()
            until my_vehicle or tick() - t > 6

            if not my_vehicle then return end

            local col = vehicle:GetAttribute("color")
            if typeof(col) == "Color3" then
                g.Send("vehicle_color", col, my_vehicle)
            end
        end)

        local function label(txt,y)
            local l = Instance.new("TextLabel")
            l.Text = txt
            l.Size = UDim2.new(1,-10,0,18)
            l.Position = UDim2.new(0,5,0,y)
            l.BackgroundTransparency = 1
            l.TextColor3 = Color3.fromRGB(180,180,180)
            l.Font = Enum.Font.Gotham
            l.TextSize = 13
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = Holder
            return l
        end

        local name = label("Vehicle: "..vehicle.Name,5)
        name.TextColor3 = Color3.fromRGB(255,255,255)
        name.Font = Enum.Font.GothamMedium
        local owner = label("Owner: N/A",24)
        local maxAcc = label("Max Acceleration: N/A",44)
        local maxSpeed = label("Max Speed: N/A",64)
        local acc60 = label("Acceleration (0 To 60): N/A",84)
        local turn = label("Turn Angle: N/A",104)
        local locked = label("Locked: N/A",124)
        local color = label("Color: N/A",144)

        g.VehicleUI[vehicle] = {
            Frame = Holder,
            Owner = owner,
            MaxAcc = maxAcc,
            MaxSpeed = maxSpeed,
            Acc60 = acc60,
            TurnAngle = turn,
            LockedStatus = locked,
            ColorLabel = color
        }
    end

    local function Update(vehicle)
        local ui = g.VehicleUI[vehicle]
        if not ui then return end
        ui.MaxAcc.Text = "Max Acceleration: "..math.floor(vehicle:GetAttribute("max_acc") or 0)
        ui.MaxSpeed.Text = "Max Speed: "..math.floor(vehicle:GetAttribute("max_speed") or 0)
        ui.Acc60.Text = "Acceleration (0 To 60): "..math.floor(vehicle:GetAttribute("acc_0_60") or 0)
        ui.TurnAngle.Text = "Turn Angle: "..math.floor(vehicle:GetAttribute("turn_angle") or 0)
        ui.LockedStatus.Text = "Locked: "..tostring(vehicle:GetAttribute("locked"))

        local c = vehicle:GetAttribute("color")
        if typeof(c) ~= "Color3" then
            c = g.WaitForAttribute(vehicle, "color", 5)
        end

        if typeof(c) == "Color3" then
            ui.ColorLabel.Text = "Color: "..g.get_color_name(c)
        else
            ui.ColorLabel.Text = "Color: Unknown"
        end

        local owner = vehicle:GetAttribute("OwnerName")
        ui.Owner.Text = "Owner: "..(owner or "Server Spawned")
    end

    local function Hook(vehicle)
        if g.VehicleUI[vehicle] then return end
        if not Validate_Model(vehicle) then return end

        CreateEntry(vehicle)
        Update(vehicle)

        g.vehicle_attr_conns[vehicle] = {}
        for _,a in ipairs({"OwnerName","max_acc","max_speed","acc_0_60","turn_angle","locked","color"}) do
            table.insert(g.vehicle_attr_conns[vehicle], vehicle:GetAttributeChangedSignal(a):Connect(function()
                Update(vehicle)
            end))
        end
    end

    for _,v in ipairs(Vehicles:GetChildren()) do Hook(v) end
    if g.Vehicle_Added_And_Removed_Conns.Child_Added_Watcher then
        pcall(function() g.Vehicle_Added_And_Removed_Conns.Child_Added_Watcher:Disconnect() end)
    end
    if g.Vehicle_Added_And_Removed_Conns.Child_Removed_Watcher then
        pcall(function() g.Vehicle_Added_And_Removed_Conns.Child_Removed_Watcher:Disconnect() end)
    end
    wait(0.25)
    g.Vehicle_Added_And_Removed_Conns.Child_Added_Watcher = Vehicles.ChildAdded:Connect(function(v)
        task.defer(function() Hook(v) end)
    end)

    g.Vehicle_Added_And_Removed_Conns.Child_Removed_Watcher = Vehicles.ChildRemoved:Connect(function(v)
        task.defer(function() g.Unhook(v) end)
    end)
end

g.check_premium_player = g.check_premium_player or function(plr)
    if plr then
        if plr:GetAttribute("is_verified") == true then
            return true
        else
            return false
        end
    else
        return false
    end
end

g.bansystem = g.bansystem or {
    enabled = false,
    list = {},
    connection = nil
}

function addban(input)
    if not input then return nil end
    if typeof(input) == "Instance" and input.Name then
        local n = input.Name:lower()
        g.bansystem.list[n] = true
        return n
    end
    local q = tostring(input):lower()
    if q == "" then return nil end
    for _,v in pairs(Players:GetPlayers()) do
        local ln = v.Name:lower()
        local ld = v.DisplayName:lower()
        if ln:find(q, 1, true) or ld:find(q, 1, true) then
            g.bansystem.list[ln] = true
            g.kick_plr(v)
            return ln
        end
    end
    g.bansystem.list[q] = true
    return q
end

function removeban(input)
    if not input then return nil end
    local q = tostring(input):lower()
    if q == "" then return nil end
    if g.bansystem.list[q] then
        g.bansystem.list[q] = nil
        return q
    end
    for name,_ in pairs(g.bansystem.list) do
        if name:find(q, 1, true) then
            g.bansystem.list[name] = nil
            return name
        end
    end
    return nil
end

function checkban(player)
    local n = player.Name:lower()
    if g.bansystem.list[n] then
        if g.bansystem.enabled then
            g.kick_plr(player)
        end
    end
end

g.start_bansystem = g.start_bansystem or function()
    if g.bansystem.enabled then return end
    if g.bansystem.starting then return end
    g.bansystem.starting = true
    FlamesLibrary.spawn("bansystem_init", "spawn", function()
        local confirmed_owner = false
        for i = 1, 5 do
            if g.is_localplayer_server_owner() then
                confirmed_owner = true
                break
            end
            FlamesLibrary.wait(1)
        end

        if not confirmed_owner then
            g.bansystem.starting = false
            local is_priv = g.is_in_private_server()
            if is_priv == false then
                g.notify("Info", "You're in a public server.", 3)
            else
                g.notify_priv_server_owner()
            end
            return
        end

        g.bansystem.enabled = true
        g.bansystem.starting = false
        for _, p in ipairs(Players:GetPlayers()) do
            FlamesLibrary.spawn("bansystem_check_" .. p.UserId, "spawn", function()
                FlamesLibrary.wait(0.2)
                checkban(p)
            end)
        end
        FlamesLibrary.connect("bansystem_player_added", Players.PlayerAdded:Connect(checkban))
        g.notify("Success", "Ban system enabled.", 5)
    end)
end
fw(0.1)
if not g.Ban_System_In_Flames_Hub_Has_Been_Started_Already then
    g.Ban_System_In_Flames_Hub_Has_Been_Started_Already = true  -- actually set it!
    pcall(function() g.start_bansystem() end)
end

g.get_server_admin_title_player = g.get_server_admin_title_player or function()
    for _, obj in g.Character:GetDescendants() do
        if obj.Name:lower():find("server") and obj.Name:lower():find("admin") and obj:IsA("TextLabel") then
            return obj
        end
    end
    return 
end

g.flash_server_admin_title_client_sided = g.flash_server_admin_title_client_sided or function(toggle)
    local localplayer_admin_of_priv_server = g.get_server_admin_title_player()
    if not localplayer_admin_of_priv_server then return end
    local fw = g.FlamesLibrary.wait
    local preset_texts = {"Flames Admin", "Server Admin", "Destroyer Admin", "Owner Admin", "Demon Admin", "Straight Crime", "Powerful Admin", "Creator Admin", "fLaMeS rUlEs", "FLAMES ADMIN"}

    if toggle == true then
        if g.Server_Admin_Text_Title_Changer then g.notify("Warning", "Server Admin Title Text changer is already enabled!", 5); return end
        g.Server_Admin_Text_Title_Changer = true
        g.FlamesLibrary.spawn("server_admin_title_text_changer_main_loop", "spawn", function()
            while g.Server_Admin_Text_Title_Changer == true do
            fw(0)
                for _, text in ipairs(preset_texts) do
                    localplayer_admin_of_priv_server.Text = text
                    fw(0)
                end
            end
        end)
    elseif toggle == false then
        if not g.Server_Admin_Text_Title_Changer then g.notify("Warning", "Server Admin Title Text changer is not enabled!", 5); return end
        g.Server_Admin_Text_Title_Changer = false
        g.FlamesLibrary.disconnect("server_admin_title_text_changer_main_loop")
    else
        return 
    end
end

local PANTS_ID = 72466003952524
local SHIRT_ID = 119513877062851
local CLOTHING_IDS = {Pants = PANTS_ID, Shirt = SHIRT_ID}
local MODESTY_ITEMS = {
    __modesty_pants = {class = "Pants", property = "PantsTemplate", template_id = "4667236106"},
    __modesty_shirt = {class = "Shirt", property = "ShirtTemplate", template_id = "121149625778724"},
}
local CONNECTION_NAMES = {"clothing_child_added", "clothing_child_removed", "clothing_char_added"}
g.anti_clothing_ban_enabled = g.anti_clothing_ban_enabled or false
g.is_applying = g.is_applying or false
g.pending_clothing = g.pending_clothing or {}
g.apply_clothing = function(classes)
    if not g.Get or typeof(g.Get) ~= "function" then g.notify("Error", "g.Get is not available or does not exist (patched?).", 3); return end
    for _, class_name in ipairs(classes) do g.Get("wear", CLOTHING_IDS[class_name], class_name) end
end

g.safe_apply_clothing = function(classes)
    if g.is_applying then return end
    g.is_applying = true
    g.notify("Success", "Yadsan Hub | Applying Safe Clothing (Anti-Clothing-Ban).", 1.5)
    local success, reason = pcall(g.apply_clothing, classes)
    if not success then g.notify("Error", tostring(reason), 5) end
    task.delay(0.5, function() g.is_applying = false end)
end

g.is_valid_character = function(c) return c and c:FindFirstChild("HumanoidRootPart") and c:IsDescendantOf(workspace) end
g.get_clothing_class = function(child)
    if child:IsA("Shirt") then return "Shirt" end
    if child:IsA("Pants") then return "Pants" end
    return nil
end

g.get_modesty_class = function(child)
    local entry = MODESTY_ITEMS[child.Name]
    if entry and child:IsA(entry.class) then return entry.class end
    for _, item in pairs(MODESTY_ITEMS) do
        if child:IsA(item.class) then
            local ok, template = pcall(function() return child[item.property] end)
            if ok and type(template) == "string" and string.find(template, item.template_id, 1, true) then return item.class end
        end
    end
    return nil
end

g.needs_restore = function(character, class_name)
    for _, child in ipairs(character:GetChildren()) do if child:IsA(class_name) and not g.get_modesty_class(child) then return false end end
    return true
end

g.flush_clothing = function(character)
    if not g.anti_clothing_ban_enabled then
        table.clear(g.pending_clothing)
        return
    end
    if g.is_applying then
        task.delay(0.3, g.flush_clothing, character)
        return
    end
    local classes = {}
    for class_name in pairs(g.pending_clothing) do
        g.pending_clothing[class_name] = nil
        if g.is_valid_character(character) and g.needs_restore(character, class_name) then table.insert(classes, class_name) end
    end
    if #classes == 0 then return end
    g.safe_apply_clothing(classes)
end

g.queue_clothing = function(character, class_name)
    if not g.anti_clothing_ban_enabled then return end
    g.pending_clothing[class_name] = true
    task.delay(0.25, g.flush_clothing, character)
end

g.watch_clothing = function(character)
    if not g.anti_clothing_ban_enabled then return end
    if not g.is_valid_character(character) then return end
    table.clear(g.pending_clothing)
    FlamesLibrary.connect("clothing_child_added", character.ChildAdded:Connect(function(child)
        if not g.anti_clothing_ban_enabled then return end
        local class_name = g.get_modesty_class(child)
        if not class_name then return end
        if not g.is_valid_character(g.get_char(speaker)) then return end
        g.queue_clothing(character, class_name)
    end))

    FlamesLibrary.connect("clothing_child_removed", character.ChildRemoved:Connect(function(child)
        if not g.anti_clothing_ban_enabled then return end
        local class_name = g.get_clothing_class(child)
        if not class_name then return end
        if not g.is_valid_character(g.get_char(speaker)) then return end
        g.queue_clothing(character, class_name)
    end))

    for _, child in ipairs(character:GetChildren()) do
        local class_name = g.get_modesty_class(child)
        if class_name then g.queue_clothing(character, class_name) end
    end
end

g.toggle_anti_clothing_ban_system = function(state)
    if state == true then
        if g.anti_clothing_ban_enabled then return end
        g.anti_clothing_ban_enabled = true
        local char = g.Character or speaker.Character or g.get_char(speaker)
        if g.is_valid_character(char) then g.watch_clothing(char) end
        FlamesLibrary.connect("clothing_char_added", speaker.CharacterAdded:Connect(function(new_char)
            if not g.anti_clothing_ban_enabled then return end
            if not g.is_valid_character(new_char) then return end
            g.watch_clothing(new_char)
        end))
        g.notify("Success", "Yadsan Hub | Anti-Clothing-Ban enabled.", 3)
    elseif state == false then
        if not g.anti_clothing_ban_enabled then return end
        g.anti_clothing_ban_enabled = false
        for _, connection_name in ipairs(CONNECTION_NAMES) do FlamesLibrary.disconnect(connection_name) end
        table.clear(g.pending_clothing)
        g.is_applying = false
        g.notify("Success", "Yadsan Hub | Anti-Clothing-Ban disabled.", 3)
    else
        return
    end
end

-- [[ Was automatically implemented but was taken out because people did not want it apparently. ]] --
--if not g.Server_Admin_Text_Title_Changer then g.flash_server_admin_title_client_sided(true) end
g.is_tool_colorable = g.is_tool_colorable or function(tool)
    if tool:IsA("Tool") and (tool:GetAttribute("color1") or tool:GetAttribute("Color1")) then
        return true
    else
        return false
    end
end

g.find_backpack_tool = g.find_backpack_tool or function()
    for _, v in ipairs(g.Backpack:GetChildren()) do
        if v:IsA("Tool") and (v:GetAttribute("color1") or v:GetAttribute("Color1")) then
            return v
        end
    end
    return nil
end

g.find_character_tool = g.find_character_tool or function()
    for _, v in ipairs(g.Character:GetChildren()) do
        if v:IsA("Tool") and (v:GetAttribute("color1") or v:GetAttribute("Color1")) then
            return v
        end
    end
    return nil
end

g.find_placed_models_tool = g.find_placed_models_tool or function()
    for _, v in ipairs(g.Workspace:FindFirstChild("PlacedModels"):GetChildren()) do
        if v:IsA("Model") and (v:GetAttribute("color1") or v:GetAttribute("Color1")) then
            if v:GetAttribute("owner_id") == g.LocalPlayer.UserId then
                return v
            end
        end
    end
    return nil
end

g.find_owned_model = g.find_owned_model or function()
    local folder = Workspace:FindFirstChild("PlacedModels")
    if not folder or not folder:IsA("Folder") then return nil end
    local uid = speaker.UserId
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute("owner_id") == uid then
            return model
        end
    end
    return nil
end

g.rainbow_tool = g.rainbow_tool or function(toggled)
    if toggled then
        g.notify("Success", "Yadsan Hub | RGB Tools is now enabled.", 5)
        local tool = g.find_character_tool() or g.find_backpack_tool() or g.find_placed_models_tool()
        if not tool then
            g.Send("get_tool", "Gift")
            g.notify("Warning", "Wait! We're giving you a colorable Tool...", 5)
            fw(0.2)
            tool = g.find_character_tool() or g.find_backpack_tool() or g.find_placed_models_tool()
            if not tool then g.notify("Error", "Tool still not found after giving you the Gift Tool.", 5); return end
            if tool.Parent == g.Backpack then
                fw(0.1)
                tool.Parent = g.Character
            end

            for _, color in ipairs(g.colors) do
                g.Send("tool_color", tool, "color1", color)
                wait()
            end
        end

        if tool.Parent == g.Backpack then
            fw(0.1)
            tool.Parent = g.Character
        end

        g.Rainbow_Tools_FE = true
        while g.Rainbow_Tools_FE do
            tool = g.find_character_tool() or g.find_backpack_tool() or g.find_placed_models_tool()
            if not tool then
                g.Rainbow_Tools_FE = false
                g.notify("Error", "Tool unexpectedly disappeared or was destroyed.", 5)
                return 
            end
            if tool.Parent == g.Backpack then
                fw(0.1)
                tool.Parent = g.Character
            end
            for _, color in ipairs(g.colors) do
                if not g.Rainbow_Tools_FE then break end
                g.Send("tool_color", tool, "color1", color)
                wait()
            end
        end
    else
        if not g.Rainbow_Tools_FE then g.notify("Warning", "Yadsan Hub | RGB Tools is not enabled!", 5); return end
        g.Rainbow_Tools_FE = false
        g.notify("Success", "Yadsan Hub | RGB Tools is now disabled.", 5)
    end
end

g.toggle_name_func = g.toggle_name_func or function(boolean)
    if boolean == true then
        g.Send("hide_name", true)
    elseif boolean == false then
        g.Send("hide_name", false)
    else
        return 
    end
end

g.flashy_name = g.flashy_name or function(Toggle)
    local FL = g.FlamesLibrary
    if Toggle == true then
        if g.Flashing_Name_Title then g.notify("Warning", "Name-Flasher is already enabled.", 5); return end
        g.Flashing_Name_Title = true
        FL.spawn("flashy_name_loop", "spawn", function()
            while g.Flashing_Name_Title == true do
                g.toggle_name_func(true)
                fw(0)
                g.toggle_name_func(false)
                fw(0)
            end
        end)
    elseif Toggle == false then
        if not g.Flashing_Name_Title then g.notify("Warning", "Name-Flasher is not enabled.", 5); return end
        g.Flashing_Name_Title = false
        FL.disconnect("flashy_name_loop")
        fw(1.5)
        g.toggle_name_func(false)
    else
        g.notify("Error", "Invalid argument(s) provided.", 5)
        return 
    end
end

g.flames_nameless_admin_ver = g.flames_nameless_admin_ver or function()
    if g.RealNamelessLoaded then g.notify("Warning", "Nameless Admin (or the Yadsan Hub version) has already been loaded.", 11); return  end
    loadstring(game:HttpGet('https://raw.githubusercontent.com/ltseverydayyou/Nameless-Admin/main/Source.lua'))()
end

g.infinite_premium = g.infinite_premium or function()
    if g.GET_LOADED_IY then g.notify("Warning", "You already have Infinite Premium running.", 5); return end
    if g.IY_LOADED then g.notify("Warning", "You already have Infinite Yield running! You cannot and should NOT run both at the same time.", 10); return end
    loadstring(game:HttpGet('https://pastefy.app/b052AUgc/raw'))()
end

g.infinite_yield = g.infinite_yield or function()
    if g.IY_LOADED then g.notify("Warning", "You already have Infinite Yield running.", 10); return end
    if g.GET_LOADED_IY then g.notify("Warning", "You already have Infinite Premium running! You cannot and should NOT run both at the same time.", 15); return end
    loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
end

g.send_msg_menu = g.send_msg_menu or function()
    if g.sendmsgmenu_loaded then g.notify("Warning", "Send message menu is already loaded!", 5); return end
    g.sendmsgmenu_loaded = true
    local tween = g.TweenService
    local players = g.Players
    local gui = Instance.new("ScreenGui")
    gui.Name = tostring(g.randomString())
    gui.ResetOnSpawn = false
    gui.Parent = parent_gui
    gui.IgnoreGuiInset = true

    local message_menu_frame = Instance.new("Frame")
    message_menu_frame.Parent = gui
    message_menu_frame.AnchorPoint = Vector2.new(0.5,0.5)
    message_menu_frame.Position = UDim2.new(0.5,0,0.5,0)
    message_menu_frame.Size = UDim2.new(0,350,0,0)
    message_menu_frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
    message_menu_frame.BackgroundTransparency = 1
    message_menu_frame.BorderSizePixel = 0
    Instance.new("UICorner",message_menu_frame).CornerRadius = UDim.new(0,15)

    tween:Create(message_menu_frame,TweenInfo.new(0.22,Enum.EasingStyle.Quad),{
        Size = UDim2.new(0,350,0,360),
        BackgroundTransparency = 0
    }):Play()

    local title = Instance.new("TextLabel")
    title.Parent = message_menu_frame
    title.Size = UDim2.new(1, -110, 0, 35)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "> Life Together RP - Message Sender <"
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(0, 0, 255)
    title.TextTransparency = 1
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    tween:Create(title,TweenInfo.new(0.3),{TextTransparency = 0}):Play()

    local refreshbtn = Instance.new("TextButton")
    refreshbtn.Parent = message_menu_frame
    refreshbtn.Size = UDim2.new(0,70,0,26)
    refreshbtn.Position = UDim2.new(1, -110, 0, 5)
    refreshbtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    refreshbtn.TextColor3 = Color3.fromRGB(255,255,255)
    refreshbtn.Text = "Refresh"
    refreshbtn.Font = Enum.Font.Gotham
    refreshbtn.TextScaled = true
    refreshbtn.BorderSizePixel = 0
    Instance.new("UICorner",refreshbtn).CornerRadius = UDim.new(0,6)
    refreshbtn.BackgroundTransparency = 1
    refreshbtn.TextTransparency = 1
    tween:Create(refreshbtn,TweenInfo.new(0.25),{BackgroundTransparency = 0, TextTransparency = 0}):Play()

    local closebtn = Instance.new("TextButton")
    closebtn.Parent = message_menu_frame
    closebtn.Size = UDim2.new(0, 30, 0, 30)
    closebtn.Position = UDim2.new(1, -30, 0, 0)
    closebtn.BackgroundColor3 = Color3.fromRGB(220,50,50)
    closebtn.TextColor3 = Color3.fromRGB(255,255,255)
    closebtn.Text = "X"
    closebtn.Font = Enum.Font.GothamBold
    closebtn.TextScaled = true
    closebtn.BorderSizePixel = 0
    Instance.new("UICorner",closebtn).CornerRadius = UDim.new(0,8)
    closebtn.BackgroundTransparency = 1
    closebtn.TextTransparency = 1
    tween:Create(closebtn,TweenInfo.new(0.25),{BackgroundTransparency = 0, TextTransparency = 0}):Play()

    local search = Instance.new("TextBox")
    search.Parent = message_menu_frame
    search.Size = UDim2.new(1,-20,0,30)
    search.Position = UDim2.new(0,10,0,50)
    search.BackgroundColor3 = Color3.fromRGB(45,45,45)
    search.TextColor3 = Color3.fromRGB(255,255,255)
    search.Text = ""
    search.PlaceholderText = "Search players..."
    search.Font = Enum.Font.Gotham
    search.TextScaled = true
    search.BackgroundTransparency = 1
    search.TextTransparency = 1
    Instance.new("UICorner",search).CornerRadius = UDim.new(0,8)
    tween:Create(search,TweenInfo.new(0.25),{BackgroundTransparency = 0, TextTransparency = 0}):Play()

    local playerscroll = Instance.new("ScrollingFrame")
    playerscroll.Parent = message_menu_frame
    playerscroll.Size = UDim2.new(1,-20,0,140)
    playerscroll.Position = UDim2.new(0,10,0,90)
    playerscroll.CanvasSize = UDim2.new(0,0,0,0)
    playerscroll.ScrollBarThickness = 5
    playerscroll.BackgroundColor3 = Color3.fromRGB(40,40,40)
    playerscroll.BorderSizePixel = 0
    playerscroll.BackgroundTransparency = 1
    Instance.new("UICorner",playerscroll).CornerRadius = UDim.new(0,10)
    tween:Create(playerscroll,TweenInfo.new(0.25),{BackgroundTransparency = 0}):Play()

    local layout = Instance.new("UIListLayout",playerscroll)
    layout.Padding = UDim.new(0,5)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top

    if g.dragify and typeof(g.dragify) == "function" then g.dragify(message_menu_frame) end
    local selected = nil
    local function refresh()
        for _,v in ipairs(playerscroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        selected = nil
        local filter = string.lower(search.Text or "")
        for _,plr in ipairs(players:GetPlayers()) do
            if plr ~= players.LocalPlayer then
                if filter == "" or string.find(string.lower(plr.Name), filter, 1, true) then
                    local b = Instance.new("TextButton")
                    b.Parent = playerscroll
                    b.Size = UDim2.new(1,-10,0,30)
                    b.BackgroundColor3 = Color3.fromRGB(55,55,55)
                    b.TextColor3 = Color3.fromRGB(255,255,255)
                    b.Text = plr.Name
                    b.Font = Enum.Font.Gotham
                    b.TextScaled = true
                    b.BorderSizePixel = 0
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)

                    b.MouseButton1Click:Connect(function()
                        if selected == b then
                            b.BackgroundColor3 = Color3.fromRGB(55,55,55)
                            selected = nil
                            return
                        end
                        if selected then
                            selected.BackgroundColor3 = Color3.fromRGB(55,55,55)
                        end
                        selected = b
                        b.BackgroundColor3 = Color3.fromRGB(30,200,80)
                    end)
                end
            end
        end
        playerscroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 10)
    end

    search:GetPropertyChangedSignal("Text"):Connect(refresh)
    refreshbtn.MouseButton1Click:Connect(refresh)
    if not g._msgmenu_connections then
        g._msgmenu_connections = true
        players.PlayerAdded:Connect(refresh)
        players.PlayerRemoving:Connect(refresh)
    end

    task.delay(0.1, refresh)
    local amount = Instance.new("TextBox")
    amount.Parent = message_menu_frame
    amount.Size = UDim2.new(1,-20,0,30)
    amount.Position = UDim2.new(0,10,0,235)
    amount.BackgroundColor3 = Color3.fromRGB(45,45,45)
    amount.TextColor3 = Color3.fromRGB(255,255,255)
    amount.Text = "1"
    amount.PlaceholderText = "Number of messages (max 15)."
    amount.Font = Enum.Font.Gotham
    amount.TextScaled = true
    amount.BackgroundTransparency = 1
    amount.TextTransparency = 1
    Instance.new("UICorner",amount).CornerRadius = UDim.new(0,10)
    tween:Create(amount,TweenInfo.new(0.25),{BackgroundTransparency = 0, TextTransparency = 0}):Play()

    local msgbox = Instance.new("TextBox")
    msgbox.Parent = message_menu_frame
    msgbox.Size = UDim2.new(1,-20,0,40)
    msgbox.Position = UDim2.new(0,10,0,275)
    msgbox.BackgroundColor3 = Color3.fromRGB(45,45,45)
    msgbox.TextColor3 = Color3.fromRGB(255,255,255)
    msgbox.Text = ""
    msgbox.PlaceholderText = "Enter message..."
    msgbox.Font = Enum.Font.Gotham
    msgbox.TextScaled = true
    msgbox.BackgroundTransparency = 1
    msgbox.TextTransparency = 1
    Instance.new("UICorner",msgbox).CornerRadius = UDim.new(0,10)
    tween:Create(msgbox,TweenInfo.new(0.25),{BackgroundTransparency = 0, TextTransparency = 0}):Play()

    local sendbtn = Instance.new("TextButton")
    sendbtn.Parent = message_menu_frame
    sendbtn.Size = UDim2.new(1,-20,0,35)
    sendbtn.Position = UDim2.new(0,10,0,320)
    sendbtn.BackgroundColor3 = Color3.fromRGB(60,120,255)
    sendbtn.TextColor3 = Color3.fromRGB(255,255,255)
    sendbtn.Text = "Send Message"
    sendbtn.Font = Enum.Font.GothamBold
    sendbtn.TextScaled = true
    sendbtn.BorderSizePixel = 0
    sendbtn.BackgroundTransparency = 1
    sendbtn.TextTransparency = 1
    Instance.new("UICorner",sendbtn).CornerRadius = UDim.new(0,10)
    tween:Create(sendbtn,TweenInfo.new(0.25),{BackgroundTransparency = 0, TextTransparency = 0}):Play()

    closebtn.MouseButton1Click:Connect(function()
        tween:Create(message_menu_frame,TweenInfo.new(0.22,Enum.EasingStyle.Quad),{
            Size = UDim2.new(0,350,0,0),
            BackgroundTransparency = 1
        }):Play()
        wait(0.25)
        gui:Destroy()
        g.sendmsgmenu_loaded = false
    end)

    sendbtn.MouseButton1Click:Connect(function()
        if not selected then g.notify("Warning", "Select a player first!", 3); return end
        local target = players:FindFirstChild(selected.Text)
        if not target then g.notify("Warning", "Player not found!", 3); return end
        local num = tonumber(amount.Text) or 1
        num = math.clamp(num,1,30)
        local raw = msgbox.Text or ""
        if raw == "" then g.notify("Warning", "Message cannot be empty.", 3); return end
        local msgs = {}
        if raw:find("||",1,true) then
            for part in string.gmatch(raw,"([^|]+)") do
                part = part:gsub("^%s+",""):gsub("%s+$","")
                if part ~= "" then table.insert(msgs,part) end
            end
        else
            table.insert(msgs,raw)
        end

        g.Send_Message_Main_Phone_Messages_Module_Task = g.FlamesLibrary.spawn("send_message_phone_task", "spawn", function()
            for i = 1, num do
                local text = msgs[((i - 1) % #msgs) + 1]
                pcall(function() g.send_msg_phone(target, text) end)
                fw(0.02)
            end
        end)
    end)
end

g.lock_vehicle = g.lock_vehicle or function(Vehicle) g.Get("lock_vehicle", Vehicle) end
if not g.HasSeen_Loading_Screen then
    loadstring(game:HttpGet("https://pastebin.com/raw/GgMwGW4p"))()
    g.HasSeen_Loading_Screen = true
end

g.player_admins = g.player_admins or {}
g.friend_checked = g.friend_checked or {}
g.cmds_loaded_plr = g.cmds_loaded_plr or {}
g.Rainbow_Vehicles = g.Rainbow_Vehicles or {}
g.Locked_Vehicles = g.Locked_Vehicles or {}
g.Unlocked_Vehicles = g.Unlocked_Vehicles or {}
g.Rainbow_Tasks = g.Rainbow_Tasks or {}
g.Rainbow_Delays         = g.Rainbow_Delays         or {}
g.Rainbow_Indices        = g.Rainbow_Indices        or {}
g.Rainbow_Next           = g.Rainbow_Next           or {}
g.Rainbow_CachedVehicle  = g.Rainbow_CachedVehicle  or {}
g.Rainbow_ActiveCount    = g.Rainbow_ActiveCount    or 0
g.Rainbow_MIN_DELAY      = g.Rainbow_MIN_DELAY      or 0.04
g.Rainbow_Colors = g.Rainbow_Colors or {
    Color3.fromRGB(255,255,255), Color3.fromRGB(128,128,128), Color3.fromRGB(0,0,0),
    Color3.fromRGB(0,0,255),     Color3.fromRGB(0,255,0),     Color3.fromRGB(0,255,255),
    Color3.fromRGB(255,165,0),   Color3.fromRGB(139,69,19),   Color3.fromRGB(255,255,0),
    Color3.fromRGB(50,205,50),   Color3.fromRGB(255,0,0),     Color3.fromRGB(255,155,172),
    Color3.fromRGB(128,0,128),
}

g.alreadyCheckedUser = function(player)
    if not g.friend_checked[player.Name] then
        g.player_admins[player.Name] = player
    end
    if not g.friend_checked[player.Name] then
        g.friend_checked[player.Name] = player
    end
    if not g.cmds_loaded_plr[player.Name] then
        g.cmds_loaded_plr[player.Name] = player
    end
end

g.disable_rgb_for = function(plr)
    if not plr then g.notify("Error", "Player was not found when trying to disable RGB vehicle!", 5); return end
    local name = plr.Name
    local state = g.VehicleStates[name]
    if not state then
        if g.Rainbow_Tasks[name] then g.Rainbow_Tasks[name] = nil end
        if g.Rainbow_Indices[name] then g.Rainbow_Indices[name] = nil end
        return
    end

    local handle = g.Rainbow_Tasks[name]
    if handle then pcall(function() task.cancel(handle) end) end
    if g.Rainbow_Tasks[name] then g.Rainbow_Tasks[name] = nil end
    if g.Rainbow_Indices[name] then g.Rainbow_Indices[name] = nil end
    state.rainbow = false
    state.rainbowIndex = nil
    g.notify("Success", "Disabled Rainbow Vehicle for: "..tostring(name), 5)
end

if not g.fully_disable_rgb_plr then g.fully_disable_rgb_plr = g.disable_rgb_for end
fw(0.1)
g.enable_rgb_for = function(plr)
    if not plr then return end
    local name = plr.Name
    g.VehicleStates[name] = g.VehicleStates[name] or {}
    local state = g.VehicleStates[name]
    local vehicle = g.get_other_vehicle(plr)
    if not vehicle then
        state.rainbow = false
        state.rainbowIndex = nil
        g.Rainbow_Tasks[name] = nil
        g.Rainbow_Indices[name] = nil
        return false, "you don't have a vehicle"
    end

    if g.Rainbow_Tasks[name] then g.disable_rgb_for(plr) end
    state.rainbow = true
    state.rainbowIndex = 0
    g.Rainbow_Indices[name] = 0
    g.Rainbow_Tasks[name] = task.spawn(function()
        while state.rainbow do
            local v = g.get_other_vehicle(plr)
            if not v then
                state.rainbow = false
                state.rainbowIndex = nil
                g.Rainbow_Tasks[name] = nil
                g.Rainbow_Indices[name] = nil
                break
            end

            local i = (state.rainbowIndex or 0) + 1
            state.rainbowIndex = i
            local color = g.Rainbow_Colors[(i % #g.Rainbow_Colors) + 1]
            g.change_vehicle_color(color, v)
            fw(0.2)
        end
        return
    end)
    return true
end

-- [[ I promise I'll use it later, I know, it's better. ]] --
g.find_configuration_manager_GUI = function()
    local find_GUI_main = CoreGui:FindFirstChild("FlamesAdminGUI", true)
    if find_GUI_main and find_GUI_main:IsA("ScreenGui") then return find_GUI_main end
    for _, v in ipairs(CoreGui:GetDescendants()) do
        if v:IsA("ScreenGui") and v.Name:lower():find("flames") and v.Name:lower():find("admin") then
            return v
        end
    end

    return nil
end

g.toggle_config_manager = function(state)
    if state == true then
        if not CoreGui:FindFirstChild("FlamesAdminGUI", true) then g.notify("Error", "Configuration Manager GUI was not found.", 5); return end
        if CoreGui:FindFirstChild("FlamesAdminGUI", true) then
            CoreGui:FindFirstChild("FlamesAdminGUI", true).Enabled = true
        elseif CoreGui:FindFirstChild("FlamesAdminGUI", true) and CoreGui:FindFirstChild("FlamesAdminGUI", true).Enabled then
            return 
        end
    elseif state == false then
        if not CoreGui:FindFirstChild("FlamesAdminGUI", true) then g.notify("Error", "Configuration Manager GUI was not found.", 5); return end
        if CoreGui:FindFirstChild("FlamesAdminGUI", true) then
            CoreGui:FindFirstChild("FlamesAdminGUI", true).Enabled = false
        elseif CoreGui:FindFirstChild("FlamesAdminGUI", true) and CoreGui:FindFirstChild("FlamesAdminGUI", true).Enabled then
            return 
        end
    else
        return 
    end
end

g.set_rgb_delay = function(name, newDelay)
   if type(newDelay) ~= "number" then return false, "invalid time value" end
   if newDelay < g.Rainbow_MIN_DELAY then newDelay = g.Rainbow_MIN_DELAY end
   g.Rainbow_Delays[name] = newDelay
   g.Rainbow_Next[name] = 0
   return true
end

g.VehicleStates = g.VehicleStates or {}
g.setup_cmd_handler_plr = function(player)
    local prefix = ";"
    local localPlayerName = g.LocalPlayer.Name
    local channel = TextChatService:FindFirstChild("RBXGeneral", true)
    if not player:IsFriendsWith(g.LocalPlayer.UserId) then return end
    local function trim(str) return str:match("^%s*(.-)%s*$") end
    if g.Message_Received_Connection_Other_Players then
        pcall(function() g.Message_Received_Connection_Other_Players:Disconnect() end)
        g.Message_Received_Connection_Other_Players = nil
    end
    wait(0.5)
    g.Message_Received_Connection_Other_Players = TextChatService.MessageReceived:Connect(function(chatMessage)
        local speaker = chatMessage.TextSource
        if not (speaker and speaker.Name ~= localPlayerName and g.player_admins[speaker.Name]) then return end
        local normalizedMessage = trim(chatMessage.Text:lower())
        if normalizedMessage:sub(1, #prefix) ~= prefix then return end
        local command = normalizedMessage:sub(#prefix + 1)
        local playerVehicle = g.get_other_vehicle(g.Players[speaker.Name])
        if not g.Players[speaker.Name]:IsFriendsWith(g.LocalPlayer.UserId) then return end
        local Name = speaker and speaker.Name
        g.VehicleStates[Name] = g.VehicleStates[Name] or {
            locked = false,
            unlocked = false,
            rainbow = false,
        }
        local parts = command:split(" ")
        local cmd = parts[1]
        if g.levenshtein(cmd, "rgbcar") <= 1 then
            local Player = g.Players[speaker.Name]
            if not Player then g.notify("Error", "This player does not exist!", 5); return end
            local vehicle = g.get_other_vehicle(Player)
            if not vehicle then
                g.Rainbow_Vehicles[Player.Name] = nil
                g.notify("Error", "The player doesn't have a car spawned!", 5)
                return 
            end

            g.enable_rgb_for(Player)
        elseif g.levenshtein(command:split(" ")[1], "rgbtime") <= 2 then
            local delayStr = parts[2]
            local newDelay = tonumber(delayStr)
            if not newDelay then return end
            if newDelay < 0.1 then newDelay = 0.1 end
            local name = g.Players[speaker.Name].Name
            g.Rainbow_Delays[name] = newDelay
            g.Rainbow_Next[name] = time()
        elseif g.levenshtein(command, "norgbcar") <= 2 then
            g.disable_rgb_for(g.Players[speaker.Name])
        elseif g.levenshtein(command, "lockcar") <= 2 then
            if not playerVehicle then
                g.LockLoop_Vehicles[speaker.Name] = false
                return 
            end
            if g.Locked_Vehicles[speaker.Name] then return  end
            g.Unlocked_Vehicles[speaker.Name] = false
            fw(0.1)
            g.Locked_Vehicles[speaker.Name] = true
            local player = g.Players[speaker.Name]
            if not player then g.Locked_Vehicles[speaker.Name] = false end
            local v = g.get_other_vehicle(player)
            if v and not v:GetAttribute("locked") then
                g.Get("lock_vehicle", v)
            elseif not v then
                g.Locked_Vehicles[speaker.Name] = false
            end
        elseif g.levenshtein(command, "unlockcar") <= 2 then
            if not playerVehicle then
                g.Unlocked_Vehicles[speaker.Name] = false
                return 
            end

            if g.Unlocked_Vehicles[speaker.Name] then return end
            g.Locked_Vehicles[speaker.Name] = false
            fw(0.1)
            g.Unlocked_Vehicles[speaker.Name] = true
            local player = g.Players[speaker.Name]
            if not player then g.Unlocked_Vehicles[speaker.Name] = false end
            local v = g.get_other_vehicle(player)
            if v and v:GetAttribute("locked") then
                g.Get("lock_vehicle", v)
            elseif not v then
                g.Unlocked_Vehicles[speaker.Name] = false
            end
        elseif g.levenshtein(command, "trailer") <= 2 then
            local player = g.Players[speaker.Name]
            if not playerVehicle then
                g.Unlocked_Vehicles[speaker.Name] = false
                return 
            end

            local Vehicle = g.get_other_vehicle(player)
            if not Vehicle then return end
            if Vehicle:FindFirstChild("WaterSkies") then return end
            fw(0.1)
            g.water_skie_trailer(true, Vehicle)
        elseif g.levenshtein(command, "notrailer") <= 2 then
            local player = g.Players[speaker.Name]
            if not playerVehicle then
                g.Unlocked_Vehicles[speaker.Name] = false
                return 
            end

            local Vehicle = g.get_other_vehicle(player)
            if not Vehicle then return  end
            if not Vehicle:FindFirstChild("WaterSkies") then return end
            g.water_skie_trailer(false, Vehicle)
        elseif command:sub(1, 5) == "check" then
            if g.Check_Cooldown then return end
            g.Check_Cooldown = true
            task.delay(15, function() g.Check_Cooldown = false end)
            local args = command:split(" ")
            local checkTargetName = args[2]
            if not checkTargetName or #checkTargetName <= 0 then g.notify("Warning", "Target player invalid: "..tostring(checkTargetName), 1); return end
            local target = g.findplr(checkTargetName)
            if not target then g.notify("Warning", "Could not find: "..tostring(target), 1); return end
            local isVerified = target:GetAttribute("is_verified")
            local general_channel = TextChatService:FindFirstChild("RBXGeneral", true) or TextChatService:FindFirstChild("TextChannels"):FindFirstChild("RBXGeneral")
            if general_channel then
                if isVerified == true then
                    general_channel:SendAsync("Player: " .. tostring(target.DisplayName) .. " has premium.")
                else
                    general_channel:SendAsync("Player: " .. tostring(target.DisplayName) .. " does not have premium.")
                end
            end
        elseif g.levenshtein(command, "lambo") <= 2 or g.levenshtein(command, "lamborghini") then
            g.spawn_any_vehicle("svj")
        elseif g.levenshtein(command, "ferrari") <= 2 or g.levenshtein(command, "sf90") or g.levenshtein(command, "corvette") then
            g.spawn_any_vehicle("sf90")
        elseif g.levenshtein(command, "bugatti") <= 2 or g.levenshtein(command, "chiron") then
            g.spawn_any_vehicle("chiron")
        elseif g.levenshtein(command, "charger") <= 2 or g.levenshtein(command, "chargersrt") or g.levenshtein(command, "srtcharger") or g.levenshtein(command, "srt") then
            g.spawn_any_vehicle("charger")
        elseif g.levenshtein(command, "cmds") <= 2 then
            if g.Is_OnCooldown then return end
            g.Is_OnCooldown = true
            g.Wait_Time_Cooldown = 45
            channel:SendAsync(
                ";lockcar | ;rgbcar | ;norgbcar | ;unlockcar | ;check Player | ;trailer | ;notrailer | ;lambo | ;sf90 | ;charger | ;bugatti"
            )
            task.delay(g.Wait_Time_Cooldown, function() g.Is_OnCooldown = false end)
        end
    end)
end

g.addPlayerToScriptWhitelistTable = g.addPlayerToScriptWhitelistTable or function(player)
    if not g.player_admins[player.Name] then
        g.player_admins[player.Name] = player
        fw(0.2)
        if g.player_admins[player.Name] then g.notify("Success", tostring(player.Name)..", was added to Admins Whitelist.", 3) end
    end
end

g.removePlayerFromScriptWhitelistTable = g.removePlayerFromScriptWhitelistTable or function(player)
    if g.player_admins[player.Name] then
        g.player_admins[player.Name] = nil
        fw(0.15)
        if g.player_admins[player.Name] == nil then
            g.notify("Success", tostring(player.Name).." was removed from the Admins Whitelist!", 3)
        else
            g.notify("Error", tostring(player)..", does not exist.", 3)
            return 
        end
    end
end

g.start_glitch_script = function()
    if g.SideGlitch_Enabled and FlamesLibrary._connections["SideGlitch_Loop"] and #FlamesLibrary._connections["SideGlitch_Loop"] > 0 then g.notify("Warning", "MonK Hub | Glitch Script is already enabled!", 3); return end
    local char = g.Character or speaker.Character or g.get_char(speaker)
    if not char or not char:IsDescendantOf(game) then return end
    local root  = g.HumanoidRootPart or char and char:FindFirstChild("HumanoidRootPart") or g.get_root(speaker)
    if not root or not root.Parent or not root:IsDescendantOf(game) then return end
    local human = g.Humanoid or char and char:FindFirstChildOfClass("Humanoid")  or g.get_human(speaker)
    if not human or not human.Parent or not human:IsDescendantOf(game) then return end
    if not root or not human or human.Health <= 0 then return end
    local locked_origin = root.CFrame
    local last_flip = 0
    local dir = 1
    g.SideGlitch_Enabled = true
    FlamesLibrary.connect("SideGlitch_Loop", RunService.RenderStepped:Connect(function()
        if not g.SideGlitch_Enabled then return end
        local now      = tick()
        local speed    = math.clamp(g.SideGlitch_Speed or 10, 1, 100)
        local distance = g.SideGlitch_Distance or 1
        local interval = 1 / speed
        if now - last_flip >= interval then
            dir       = -dir
            last_flip = now
        end
        local right = locked_origin.RightVector
        root.CFrame = CFrame.new(locked_origin.Position + right * (dir * distance)) * (locked_origin - locked_origin.Position)
    end))
    FlamesLibrary.connect("SideGlitch_Restore", RunService.RenderStepped:Connect(function()
        if g.SideGlitch_Enabled then return end
        if root.CFrame.Position ~= locked_origin.Position then
            root.CFrame = locked_origin
        else
            FlamesLibrary.disconnect("SideGlitch_Restore")
        end
    end))
end

g.start_smooth_glitch_script = function()
    local char = g.Character or speaker.Character or g.get_char(speaker)
    if not char or not char:IsDescendantOf(game) then return end
    local root  = g.HumanoidRootPart or char and char:FindFirstChild("HumanoidRootPart") or g.get_root(speaker)
    local human = g.Humanoid or char and char:FindFirstChildOfClass("Humanoid") or g.get_human(speaker)
    if not root or not human or human.Health <= 0 then return end
    local locked_origin  = root.CFrame
    local last_flip      = 0
    local dir            = 1
    local current_offset = 0
    local target_offset  = 0
    g.SideGlitch_Enabled  = true
    FlamesLibrary.connect("SideGlitch_Loop", RunService.RenderStepped:Connect(function(dt)
        if not g.SideGlitch_Enabled then return end
        local now      = tick()
        local speed    = math.clamp(g.SideGlitch_Speed    or 5,    1, 100)
        local distance = math.clamp(g.SideGlitch_Distance or 5,    0,  50)
        local smooth   = math.clamp(g.SideGlitch_Smooth   or 0.18, 0,   1)
        local interval = 1 / speed
        if now - last_flip >= interval then
            dir           = -dir
            target_offset = dir * distance
            last_flip     = now
        end

        local alpha   = 1 - (1 - smooth) ^ (dt * 60)
        current_offset = current_offset + (target_offset - current_offset) * alpha
        local rotation_only = locked_origin - locked_origin.Position
        local right          = locked_origin.RightVector
        root.CFrame = CFrame.new(locked_origin.Position + right * current_offset) * rotation_only
    end))

    FlamesLibrary.connect("SideGlitch_Restore", RunService.RenderStepped:Connect(function(dt)
        if g.SideGlitch_Enabled then return end
        local smooth  = math.clamp(g.SideGlitch_Smooth or 0.18, 0, 1)
        local alpha   = 1 - (1 - smooth) ^ (dt * 60)
        current_offset = current_offset + (0 - current_offset) * alpha
        local rotation_only = locked_origin - locked_origin.Position
        local right          = locked_origin.RightVector
        root.CFrame = CFrame.new(locked_origin.Position + right * current_offset) * rotation_only
        if math.abs(current_offset) < 0.01 then
            root.CFrame = locked_origin
            FlamesLibrary.disconnect("SideGlitch_Restore")
        end
    end))
end

g.stop_glitch_script = function()
    g.SideGlitch_Enabled = false
    g.FlamesLibrary.disconnect("SideGlitch_Loop")
end

g.avgSkin = g.avgSkin or function(bc)
    local skin_tone_colors = {
        bc.HeadColor3,
        bc.LeftArmColor3,
        bc.RightArmColor3,
        bc.TorsoColor3,
        bc.LeftLegColor3,
        bc.RightLegColor3
    }

    local r,g,b = 0,0,0
    for _,c in ipairs(skin_tone_colors) do
        r = r + c.R
        g = g + c.G
        b = b + c.B
    end
    return Color3.new(r/6,g/6,b/6)
end

g.clear_avatar = g.clear_avatar or function()
    local args = {
        "wear_outfit_from_desc",
        {
            accessories = {
                {
                    Rotation = "  ",
                    AccessoryType = "Hair",
                    Position = "  ",
                    Scale = "1 1 1",
                    IsLayered = false,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "Face",
                    Position = "  ",
                    Scale = "1 1 1",
                    IsLayered = false,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "Face",
                    Position = "  ",
                    Scale = "1 1 1",
                    IsLayered = false,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "Hat",
                    Position = "  ",
                    Scale = "1 1 1",
                    IsLayered = false,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "Face",
                    Position = "  ",
                    Scale = "1 1 1",
                    IsLayered = false,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "Shirt",
                    Scale = "1 1 1",
                    Position = "  ",
                    Order = 1,
                    IsLayered = true,
                    Puffiness = 0,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "DressSkirt",
                    Scale = "1 1 1",
                    Position = "  ",
                    Order = 2,
                    IsLayered = true,
                    Puffiness = 0,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "RightShoe",
                    Scale = "1 1 1",
                    Position = "  ",
                    Order = 3,
                    IsLayered = true,
                    Puffiness = 0,
                    AssetId = 0
                },
                {
                    Rotation = "  ",
                    AccessoryType = "LeftShoe",
                    Scale = "1 1 1",
                    Position = "  ",
                    Order = 4,
                    IsLayered = true,
                    Puffiness = 0,
                    AssetId = 0
                }
            },
            properties = {
                SwimAnimation = 0,
                RightLegColor = "^zH;",
                MoodAnimation = 0,
                Torso = 0,
                WidthScale = 1,
                BodyTypeScale = 0.25,
                ClimbAnimation = 0,
                LeftArmColor = "^zH;",
                Shirt = 0,
                GraphicTShirt = 0,
                RightArmColor = "^zH;",
                LeftArm = 0,
                RunAnimation = 0,
                JumpAnimation = 0,
                RightArm = 0,
                Face = 0,
                Head = 0,
                DepthScale = 1,
                LeftLegColor = "^zH;",
                FallAnimation = 0,
                Pants = 0,
                HeadColor = "^zH;",
                TorsoColor = "^zH;",
                IdleAnimation = 0,
                RightLeg = 0,
                HeadScale = 1,
                HeightScale = 1,
                ProportionScale = 0,
                LeftLeg = 0
            }
        }
    }

    pcall(function() g.Send(unpack(args)) end)
end
fw(0.2)
g.height_setter_busy = g.height_setter_busy or false
g.session_original_height = g.session_original_height or nil
g.session_original_width = g.session_original_width or nil
g.session_original_skin = g.session_original_skin or nil
g.session_active = g.session_active or false
g.last_height_scale = g.last_height_scale or nil
g.prev_height_scale = g.prev_height_scale or nil
g.last_skin_tone = g.last_skin_tone or nil
g.prev_skin_tone = g.prev_skin_tone or nil
g.size_setter_busy = g.size_setter_busy or false
g.session_original_width = g.session_original_width or nil
g.session_original_depth = g.session_original_depth or nil
g.session_original_skin = g.session_original_skin or nil
g.session_size_active = g.session_size_active or false
g.last_width_scale = g.last_width_scale or nil
g.last_depth_scale = g.last_depth_scale or nil
g.prev_width_scale = g.prev_width_scale or nil
g.prev_depth_scale = g.prev_depth_scale or nil
g.last_skin_tone_s = g.last_skin_tone_s or nil
g.prev_skin_tone_s = g.prev_skin_tone_s or nil
g.apply_skin_tone = function(color) if not color then return end; pcall(function() g.Send("skin_tone", color) end) end
g.copy_plr_avatar = function(Player)
    if g.is_copying_avatar_already_flames then g.notify("Warning","Avatar copier already in progress!", 3); return end
    g.is_copying_avatar_already_flames = true
    if not Player or not Player.Character then
        g.is_copying_avatar_already_flames = false
        g.notify("Warning","Target not found!",3)
        return 
    end

    local hum = Player.Character:FindFirstChildWhichIsA("Humanoid") or g.get_human(Player, Players.RespawnTime + 1)
    if not hum then
        g.is_copying_avatar_already_flames = false
        g.notify("Warning","No humanoid!",3)
        return 
    end

    local desc = hum:GetAppliedDescription()
    if not desc then
        g.is_copying_avatar_already_flames = false
        g.notify("Warning","No description!",3)
        return 
    end

    if Player.Name == "Yadsan_Godverse" or Player.Name == "L0CKED_1N1" or Player.Name == "AuraWithClipFarmin" then
        g.is_copying_avatar_already_flames = false
        g.notify("Warning", "Do not copy the owner of Yadsan Hub's avatar!", 10)
        return 
    end

    if Player:GetAttribute("bio") == "`~ Celestial Hub Anti Stealer Is Enabled By Yadsan ~`" then g.notify("Warning", "This Player has Yadsan Hub | Anti Stealer enabled!", 3); return end
    g.clear_avatar()
    fw(0.2)
    local accessories = {}
    for _,acc in ipairs(desc:GetAccessories(true)) do
        table.insert(accessories,{
            Rotation = "  ",
            Position = "  ",
            Scale = "1 1 1",
            IsLayered = acc.IsLayered,
            AccessoryType = acc.AccessoryType.Name,
            AssetId = acc.AssetId,
            Order = acc.Order,
            Puffiness = acc.Puffiness
        })
    end

    local properties = {
        Head = desc.Head or 0,
        Torso = desc.Torso or 0,
        LeftArm = desc.LeftArm or 0,
        RightArm = desc.RightArm or 0,
        LeftLeg = desc.LeftLeg or 0,
        RightLeg = desc.RightLeg or 0,
        Face = desc.Face or 0,
        Shirt = desc.Shirt or 0,
        Pants = desc.Pants or 0,
        GraphicTShirt = desc.GraphicTShirt or 0,
        RunAnimation = desc.RunAnimation or 0,
        WalkAnimation = desc.WalkAnimation or 0,
        JumpAnimation = desc.JumpAnimation or 0,
        FallAnimation = desc.FallAnimation or 0,
        ClimbAnimation = desc.ClimbAnimation or 0,
        IdleAnimation = desc.IdleAnimation or 0,
        SwimAnimation = desc.SwimAnimation or 0,
        HeightScale = desc.HeightScale or 1,
        WidthScale = desc.WidthScale or 1,
        DepthScale = desc.DepthScale or 1,
        HeadScale = desc.HeadScale or 1,
        BodyTypeScale = desc.BodyTypeScale or 0,
        ProportionScale = desc.ProportionScale or 0,
    }

    local args = {
        "wear_outfit_from_desc",
        {
            accessories = accessories,
            properties = properties
        }
    }

    pcall(function() g.Send(unpack(args)) end)
    fw(0.1)
    local bodyColors = Player.Character:FindFirstChildOfClass("BodyColors")
    if Player.Character and bodyColors then g.Send("skin_tone", g.avgSkin(bodyColors)) end
    local height = math.clamp(math.floor((desc.HeightScale or 1)*100+0.5),90,105)
    local width  = math.clamp(math.floor((desc.WidthScale  or 1)*100+0.5),70,100)
    g.Send("body_scale","HeightScale",height)
    task.wait(0.15)
    g.Send("body_scale","WidthScale",width)
    local age = Player:GetAttribute("age")
    if age then g.Get("age",age) end
    g.notify("Success","Copied avatar from "..Player.Name,5)
    g.is_copying_avatar_already_flames = false
end

g.height_func_setter = g.height_func_setter or function(height_input)
    if g.height_setter_busy then return end
    g.height_setter_busy = true
    local player = g.LocalPlayer
    local char = g.Character or player and player.Character
    local hum = g.Humanoid or char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        g.height_setter_busy = false
        return
    end

    local desc = hum:GetAppliedDescription()
    if not desc then
        g.height_setter_busy = false
        g.notify("Error", "Failed to grab HumanoidDescription.", 3)
        return 
    end

    local bodyColors = char and char:FindFirstChildOfClass("BodyColors")
    local current_skin = bodyColors and g.avgSkin(bodyColors)
    if not g.session_active then
        g.session_original_height = desc.HeightScale or 1
        g.session_original_width = desc.WidthScale or 1
        g.session_original_skin = current_skin
        g.session_active = true
    end

    if current_skin then
        g.prev_skin_tone = g.last_skin_tone or current_skin
        g.last_skin_tone = current_skin
    end

    local height = tonumber(height_input) or desc.HeightScale or 1
    g.prev_height_scale = g.last_height_scale or desc.HeightScale or 1
    g.last_height_scale = height
    local properties = {
        Head = desc.Head or 0,
        Torso = desc.Torso or 0,
        LeftArm = desc.LeftArm or 0,
        RightArm = desc.RightArm or 0,
        LeftLeg = desc.LeftLeg or 0,
        RightLeg = desc.RightLeg or 0,
        Face = desc.Face or 0,
        Shirt = desc.Shirt or 0,
        Pants = desc.Pants or 0,
        GraphicTShirt = desc.GraphicTShirt or 0,
        RunAnimation = desc.RunAnimation or 0,
        WalkAnimation = desc.WalkAnimation or 0,
        JumpAnimation = desc.JumpAnimation or 0,
        FallAnimation = desc.FallAnimation or 0,
        ClimbAnimation = desc.ClimbAnimation or 0,
        IdleAnimation = desc.IdleAnimation or 0,
        SwimAnimation = desc.SwimAnimation or 0,
        HeightScale = height,
        WidthScale = desc.WidthScale or 1,
        DepthScale = desc.DepthScale or 1,
        HeadScale = desc.HeadScale or 1,
        BodyTypeScale = desc.BodyTypeScale or 0,
        ProportionScale = desc.ProportionScale or 0,
    }

    local accessories = {}
    for _, acc in ipairs(desc:GetAccessories(true)) do
        table.insert(accessories,{
            Rotation = "  ",
            Position = "  ",
            Scale = "1 1 1",
            IsLayered = acc.IsLayered,
            AccessoryType = acc.AccessoryType.Name,
            AssetId = acc.AssetId,
            Order = acc.Order,
            Puffiness = acc.Puffiness
        })
    end

    pcall(function()
        g.Send("wear_outfit_from_desc", {
            accessories = accessories,
            properties = properties
        })
    end)

    task.delay(0.10, function()
        g.apply_skin_tone(g.session_original_skin)
        g.height_setter_busy = false
    end)
end

g.reset_to_original_height = g.reset_to_original_height or function()
    if g.height_setter_busy then return end
    if not g.session_original_height then return end
    g.height_func_setter(g.session_original_height)
    if g.session_original_skin then
        task.delay(0.1, function()
            g.apply_skin_tone(g.session_original_skin)
        end)
    end

    task.delay(0.3, function()
        g.session_original_height = nil
        g.session_original_width = nil
        g.session_original_skin = nil
        g.session_active = false
    end)
end

g.reapply_last_skin = g.reapply_last_skin or function()
    if g.last_skin_tone then
        g.apply_skin_tone(g.last_skin_tone)
    end
end

g.reapply_prev_skin = g.reapply_prev_skin or function()
    if g.prev_skin_tone then
        g.apply_skin_tone(g.prev_skin_tone)
    end
end

g.size_func_setter = g.size_func_setter or function(width_input, depth_input)
    if g.size_setter_busy then return end
    g.size_setter_busy = true
    local char = g.Character or speaker.Character or g.get_char(speaker) or g.Char:get()
    local hum = g.Humanoid or char and char:FindFirstChildOfClass("Humanoid") or g.get_human(speaker)
    if not hum then g.size_setter_busy = false; return end
    local desc = hum:GetAppliedDescription()
    if not desc then
        g.size_setter_busy = false
        g.notify("Error", "Failed to grab HumanoidDescription.", 3)
        return
    end

    local body_colors = char and char:FindFirstChildOfClass("BodyColors")
    local current_skin = body_colors and g.avgSkin(body_colors)
    if not g.session_size_active then
        g.session_original_width = desc.WidthScale or 1
        g.session_original_depth = desc.DepthScale or 1
        g.session_original_skin = g.session_original_skin or current_skin
        g.session_size_active = true
    end

    if current_skin then
        g.prev_skin_tone_s = g.last_skin_tone_s or current_skin
        g.last_skin_tone_s = current_skin
    end

    local width = tonumber(width_input) or desc.WidthScale or 1
    local depth = tonumber(depth_input) or desc.DepthScale or 1
    g.prev_width_scale = g.last_width_scale or desc.WidthScale or 1
    g.prev_depth_scale = g.last_depth_scale or desc.DepthScale or 1
    g.last_width_scale = width
    g.last_depth_scale = depth
    local properties = {
        Head = desc.Head or 0,
        Torso = desc.Torso or 0,
        LeftArm = desc.LeftArm or 0,
        RightArm = desc.RightArm or 0,
        LeftLeg = desc.LeftLeg or 0,
        RightLeg = desc.RightLeg or 0,
        Face = desc.Face or 0,
        Shirt = desc.Shirt or 0,
        Pants = desc.Pants or 0,
        GraphicTShirt = desc.GraphicTShirt or 0,
        RunAnimation = desc.RunAnimation or 0,
        WalkAnimation = desc.WalkAnimation or 0,
        JumpAnimation = desc.JumpAnimation or 0,
        FallAnimation = desc.FallAnimation or 0,
        ClimbAnimation = desc.ClimbAnimation or 0,
        IdleAnimation = desc.IdleAnimation or 0,
        SwimAnimation = desc.SwimAnimation or 0,
        HeightScale = desc.HeightScale or 1,
        WidthScale = width,
        DepthScale = depth,
        HeadScale = desc.HeadScale or 1,
        BodyTypeScale = desc.BodyTypeScale or 0,
        ProportionScale = desc.ProportionScale or 0,
    }

    local accessories = {}
    for _, acc in ipairs(desc:GetAccessories(true)) do
        table.insert(accessories, {
            Rotation = "  ",
            Position = "  ",
            Scale = "1 1 1",
            IsLayered = acc.IsLayered,
            AccessoryType = acc.AccessoryType.Name,
            AssetId = acc.AssetId,
            Order = acc.Order,
            Puffiness = acc.Puffiness
        })
    end

    pcall(function()
        g.Send("wear_outfit_from_desc", {
            accessories = accessories,
            properties = properties
        })
    end)

    task.delay(0.10, function()
        g.apply_skin_tone(g.session_original_skin)
        g.size_setter_busy = false
    end)
end

g.reset_to_original_size = g.reset_to_original_size or function()
    if g.size_setter_busy then return end
    if not g.session_original_width and not g.session_original_depth then return end
    g.size_func_setter(g.session_original_width, g.session_original_depth)
    if g.session_original_skin then
        task.delay(0.1, function()
            g.apply_skin_tone(g.session_original_skin)
        end)
    end

    task.delay(0.3, function()
        g.session_original_width = nil
        g.session_original_depth = nil
        g.session_original_skin = nil
        g.session_size_active = false
    end)
end

g.anti_sit_enabled = g.anti_sit_enabled or false
g.anti_sit_connections = g.anti_sit_connections or {}
local local_player = g.LocalPlayer or Players.LocalPlayer
local function cleanup_connections()
	for _, conn in pairs(g.anti_sit_connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	g.anti_sit_connections = {}
end

local function hook_character(character)
	if not character then character = g.get_char(local_player, 10) end
	if not character then return end
	if not character:FindFirstChild("HumanoidRootPart") then character:WaitForChild("HumanoidRootPart") end
	local humanoid = g.Humanoid or g.Character:FindFirstChildOfClass("Humanoid") or g.get_human(local_player, Players.RespawnTime + 0.75)
	if not humanoid or not humanoid.Parent or not humanoid:IsDescendantOf(game) then return end
	local conn
	conn = humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		if not g.anti_sit_enabled then return end
		if humanoid.Sit then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
			task.spawn(function()
				if humanoid.SeatPart then
					local weld = humanoid.SeatPart:FindFirstChildOfClass("Weld")
					if weld then weld:Destroy() end
					local prox = humanoid.SeatPart:FindFirstChildOfClass("ProximityPrompt")
					if prox and prox.Enabled == false then prox.Enabled = true end
				end
				for _ = 1, 5 do
					task.wait()
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					humanoid.Sit = false
				end
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
			end)
		end
	end)
	table.insert(g.anti_sit_connections, conn)
end

local function start_anti_sit()
	if #g.anti_sit_connections > 0 then return end
	hook_character(local_player.Character)
	local char_conn = local_player.CharacterAdded:Connect(function(character) hook_character(character) end)
	table.insert(g.anti_sit_connections, char_conn)
end

local function stop_anti_sit() cleanup_connections() end
g.toggle_anti_sit = function(state)
	g.anti_sit_enabled = state
	if state then
		start_anti_sit()
	else
		stop_anti_sit()
	end
end

local attr_name = "InHumanoidVehicle"
local keys = {loop = "anti_sit_loop", char = "anti_sit_char", spam = "anti_sit_spam", hook = "anti_sit_hook", seat = "anti_sit_seat", hv = "anti_sit_hv"}
local cfg = g.anti_sit_config or {phase_two = 0.75, phase_three = 2, timeout = 5, retry_delay = 0.5}
local spam = g.anti_sit_spam or {active = false, started = 0, last_send = 0, last_hard = 0, cooldown_until = 0, exits = 0, total = 0, fastest = math.huge}
local registry = g.anti_sit_registry or {}
g.seat_cache = {}
local uid = 0
g.anti_sit_config = cfg
g.anti_sit_spam = spam
g.anti_sit_registry = registry
-- [[ Replaced up here but kept down there as well because some scripts reference it after this point. ]] --
g.in_humanoid_vehicle = g.in_humanoid_vehicle or function(player_or_name)
    local humanoid_vehicles = g.Workspace:FindFirstChild("HumanoidVehicles", true)
    if not humanoid_vehicles then return end
    local player = player_or_name
    if typeof(player_or_name) == "string" then
        player = g.Players:FindFirstChild(player_or_name)
        if not player then return end
    end
    local character = player == g.LocalPlayer and g.Character or player.Character
    if not character then return end
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid") or g.get_human(player, 3)
    if not humanoid then return end
    local vehicle_attr = humanoid:GetAttribute("InHumanoidVehicle")
    if vehicle_attr == nil then return end
    if type(g.Humanoid_Vehicles) ~= "table" then return end
    if not table.find(g.Humanoid_Vehicles, vehicle_attr) then return end
    return vehicle_attr
end

g.hum_vehicle_name = g.hum_vehicle_name or function(plr)
    local hv = g.in_humanoid_vehicle(plr)
    if not hv then return nil end
    local folder = g.Workspace:FindFirstChild("HumanoidVehicles", true)
    if not folder or not folder:IsA("Folder") then return nil end
    local inst = folder:FindFirstChild(hv)
    if not inst then return nil end
    return inst.Name
end

g.anti_sit_uid = function() uid += 1; return uid end
g.anti_sit_connect = function(name, conn) registry[name] = true; g.FlamesLibrary.connect(name, conn) end
g.anti_sit_cleanup = function() for name in pairs(registry) do g.FlamesLibrary.disconnect(name) end; table.clear(registry); table.clear(g.seat_cache) end
g.anti_sit_get_char = function() return g.Character or speaker.Character or (g.get_char and g.get_char(speaker)) end
g.anti_sit_get_hum = function(char) return (char and char:FindFirstChildWhichIsA("Humanoid")) or g.Humanoid or (g.get_human and g.get_human(speaker)) or (g.Char and g.Char.get_hum and g.Char.get_hum()) end
g.anti_sit_char_valid = function(char) return char ~= nil and char:FindFirstChild("HumanoidRootPart") ~= nil and char:IsDescendantOf(workspace) end
g.anti_sit_hum_valid = function(hum) return hum ~= nil and hum.Parent ~= nil and hum:IsDescendantOf(game) end
g.anti_sit_attr = function(hum)
    if not hum then return nil end
    local ok, res = pcall(function() return hum:GetAttribute(attr_name) end)
    if ok and res ~= nil then return res end
    return nil
end

g.anti_sit_in_hv = function(hum)
    if g.in_humanoid_vehicle and typeof(g.in_humanoid_vehicle) == "function" then
        local ok, res = pcall(g.in_humanoid_vehicle, speaker)
        if ok and res ~= nil then return res end
    end
    return g.anti_sit_attr(hum)
end

g.anti_sit_hard_eject = function(char, hum)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local folder = workspace:FindFirstChild("HumanoidVehicles")
    if folder and hrp then
        for _, group in folder:GetChildren() do
            for _, model in group:GetChildren() do
                if model:IsA("Model") and model:HasTag("HumanoidVehicle") then
                    local occupant_val = model:FindFirstChild("occupant")
                    local owner_val = model:FindFirstChild("owner")
                    local ours = (occupant_val and occupant_val.Value == hum) or (owner_val and owner_val.Value == speaker)
                    if ours then
                        local touch_part = model:FindFirstChild("TouchPart", true)
                        if touch_part then
                            for _, weld in touch_part:GetChildren() do
                                if weld:IsA("WeldConstraint") and (weld.Part0 == hrp or weld.Part1 == hrp) then pcall(function() weld:Destroy() end) end
                            end
                        end
                        if occupant_val then pcall(function() occupant_val.Value = nil end) end
                    end
                end
            end
        end
    end
    if hrp and hrp.Parent then
        for _, joint in hrp:GetChildren() do
            if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
                local other = joint.Part0 == hrp and joint.Part1 or joint.Part0
                if other and not other:IsDescendantOf(char) then pcall(function() joint:Destroy() end) end
            end
        end
        pcall(function() hrp.CFrame = hrp.CFrame * CFrame.new(0, 4, -3) end)
    end
    pcall(function() hum:SetAttribute(attr_name, nil) end)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    if g.Send and typeof(g.Send) == "function" then pcall(g.Send, "stop_sitting") end
end

g.anti_sit_spam_stop = function(success)
    FlamesLibrary.disconnect(keys.spam)
    if success then
        local took = os.clock() - spam.started
        spam.exits += 1
        spam.total += took
        spam.fastest = math.min(spam.fastest, took)
    end
    spam.active = false
    spam.cooldown_until = os.clock() + (success and 0 or cfg.retry_delay)
end

g.anti_sit_spam_start = function()
    if spam.active or os.clock() < spam.cooldown_until then return end
    spam.active = true
    spam.started = os.clock()
    spam.last_send = 0
    spam.last_hard = 0
    FlamesLibrary.connect(keys.spam, RunService.Heartbeat:Connect(function()
        if not g.Not_Ever_Sitting then g.anti_sit_spam_stop(false); return end
        local char = g.anti_sit_get_char()
        local hum = char and g.anti_sit_get_hum(char)
        if not g.anti_sit_char_valid(char) or not g.anti_sit_hum_valid(hum) then g.anti_sit_spam_stop(false); return end
        if g.anti_sit_in_hv(hum) == nil then g.anti_sit_spam_stop(true); return end
        local now = os.clock()
        local elapsed = now - spam.started
        if elapsed > cfg.timeout then g.anti_sit_spam_stop(false); return end
        pcall(function()
            hum.Jump = true
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        if elapsed > cfg.phase_two then
            pcall(function() hum.Sit = false end)
            if now - spam.last_send > 0.15 then
                spam.last_send = now
                if g.Send and typeof(g.Send) == "function" then pcall(g.Send, "stop_sitting") end
            end
        end
        if elapsed > cfg.phase_three and now - spam.last_hard > 0.4 then
            spam.last_hard = now
            g.anti_sit_hard_eject(char, hum)
        end
    end))
end

g.anti_sit_eject_seat = function(hum, seat)
    local target = seat or hum.SeatPart
    if target and target.Parent then
        pcall(function() target:SetAttribute("Disabled", true) end)
        task.delay(0.3, function() pcall(function() if target.Parent then target:SetAttribute("Disabled", false) end end) end)
    end
    pcall(function() hum.Sit = false end)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    if g.Send then pcall(g.Send, "stop_sitting") end
    local char = hum.Parent
    local hrp = char and char:IsDescendantOf(workspace) and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Parent then pcall(function() hrp.CFrame = hrp.CFrame * CFrame.new(0, 3, -2) end) end
end

g.anti_sit_eject_any = function(char, hum)
    if not g.anti_sit_char_valid(char) or not g.anti_sit_hum_valid(hum) then return end
    if g.anti_sit_in_hv(hum) ~= nil then g.anti_sit_spam_start(); return end
    local seat_part = hum.SeatPart
    local is_sit = hum.Sit or (g.Char and g.Char.is_sitting and g.Char.is_sitting.get())
    if is_sit or seat_part then g.anti_sit_eject_seat(hum, seat_part) end
end

g.anti_sit_disable_nearby = function(char)
    local hrp = g.HumanoidRootPart or char and char:FindFirstChild("HumanoidRootPart") or g.get_root(speaker)
    if not hrp or not hrp.Parent then return end
    for seat in pairs(g.seat_cache) do
        if seat.Parent and seat:GetAttribute("Disabled") ~= true and (seat.Position - hrp.Position).Magnitude < 8 then
            pcall(function() seat:SetAttribute("Disabled", true) end)
            task.delay(0.35, function() pcall(function() if seat.Parent then seat:SetAttribute("Disabled", false) end end) end)
        end
    end
end

g.anti_sit_hook_hum = function(hum, char)
    g.anti_sit_connect(keys.hook .. "_attr", hum:GetAttributeChangedSignal(attr_name):Connect(function()
        if g.Not_Ever_Sitting and g.anti_sit_attr(hum) ~= nil then g.anti_sit_eject_any(char, hum) end
    end))
    g.anti_sit_connect(keys.hook .. "_sit", hum:GetPropertyChangedSignal("Sit"):Connect(function()
        if g.Not_Ever_Sitting and hum.Sit then g.anti_sit_eject_any(char, hum) end
    end))
    g.anti_sit_connect(keys.hook .. "_seatpart", hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
        if not g.Not_Ever_Sitting or not hum.SeatPart then return end
        task.defer(function() if g.Not_Ever_Sitting then g.anti_sit_eject_any(char, hum) end end)
    end))
end

g.anti_sit_watch_seats = function()
    table.clear(g.seat_cache)
    for _, obj in workspace:GetDescendants() do if obj:IsA("Seat") or obj:IsA("VehicleSeat") then g.seat_cache[obj] = true end end
    g.anti_sit_connect(keys.seat .. "_added", workspace.DescendantAdded:Connect(function(obj) if obj:IsA("Seat") or obj:IsA("VehicleSeat") then g.seat_cache[obj] = true end end))
    g.anti_sit_connect(keys.seat .. "_removed", workspace.DescendantRemoving:Connect(function(obj) g.seat_cache[obj] = nil end))
end

g.anti_sit_bind_hv_model = function(model)
    if not (model:IsA("Model") and model:HasTag("HumanoidVehicle")) then return end
    task.spawn(function()
        local occupant_val = model:WaitForChild("occupant", 5)
        if not occupant_val or not occupant_val:IsA("ObjectValue") or not g.Not_Ever_Sitting then return end
        g.anti_sit_connect(keys.hv .. "_occ_" .. g.anti_sit_uid(), occupant_val:GetPropertyChangedSignal("Value"):Connect(function()
            if not g.Not_Ever_Sitting or occupant_val.Value == nil then return end
            local char = g.anti_sit_get_char()
            local hum = char and g.anti_sit_get_hum(char)
            if occupant_val.Value == hum then g.anti_sit_spam_start() end
        end))
    end)
end

g.anti_sit_bind_hv_folder = function(folder)
    if not folder:IsA("Folder") then return end
    for _, model in folder:GetChildren() do g.anti_sit_bind_hv_model(model) end
    g.anti_sit_connect(keys.hv .. "_child_" .. g.anti_sit_uid(), folder.ChildAdded:Connect(function(model)
        if g.Not_Ever_Sitting then g.anti_sit_bind_hv_model(model) end
    end))
end

g.anti_sit_watch_hv = function()
    local root = workspace:FindFirstChild("HumanoidVehicles")
    if not root then return end
    for _, folder in root:GetChildren() do g.anti_sit_bind_hv_folder(folder) end
    g.anti_sit_connect(keys.hv .. "_folders", root.ChildAdded:Connect(function(folder) if g.Not_Ever_Sitting then g.anti_sit_bind_hv_folder(folder) end end))
end

g.anti_sit_func = function(toggle)
    local lib = g.FlamesLibrary
    local fw = lib.wait
    if not g.Seat then
        local ok, res = pcall(function() return require(g.Game_Folder:FindFirstChild("Seat")) end)
        if not ok or not res then g.notify("Error", "Seat ModuleScript not found or failed to load!", 3); return end
        g.Seat = res
    end
    if toggle == true then
        if g.Not_Ever_Sitting then g.notify("Warning", "AntiSit is already enabled!", 3); return end
        g.Not_Ever_Sitting = true
        g.notify("Success", "Anti-Sit is now enabled!", 3)
        g.show_notification("Success:", "Anti-Sit is now enabled.", "Normal")
        local char = g.anti_sit_get_char()
        local hum = char and g.anti_sit_get_hum(char)
        if g.anti_sit_char_valid(char) and g.anti_sit_hum_valid(hum) then g.anti_sit_hook_hum(hum, char) end
        g.anti_sit_watch_seats()
        g.anti_sit_watch_hv()
        g.anti_sit_connect(keys.char, speaker.CharacterAdded:Connect(function(new_char)
            fw(0)
            local new_hum = new_char:WaitForChild("Humanoid", 5)
            if g.anti_sit_char_valid(new_char) and g.anti_sit_hum_valid(new_hum) then g.anti_sit_hook_hum(new_hum, new_char) end
        end))
        lib.spawn(keys.loop, "spawn", function()
            while g.Not_Ever_Sitting == true do
                g.Seat.enabled.set(false)
                local cur_char = g.anti_sit_get_char()
                local cur_hum = cur_char and g.anti_sit_get_hum(cur_char)
                if g.anti_sit_char_valid(cur_char) and g.anti_sit_hum_valid(cur_hum) then
                    g.anti_sit_eject_any(cur_char, cur_hum)
                    if cur_hum.Sit or cur_hum.SeatPart then g.anti_sit_disable_nearby(cur_char) end
                end
                fw(0)
            end
            lib.disconnect(keys.loop)
        end)
    elseif toggle == false then
        if not g.Not_Ever_Sitting then g.notify("Warning", "AntiSit is not enabled!", 3); return end
        g.Not_Ever_Sitting = false
        g.anti_sit_spam_stop(false)
        g.anti_sit_cleanup()
        lib.disconnect(keys.loop)
        fw(0.2)
        g.Seat.enabled.set(true)
        g.notify("Success", "Anti-Sit is now disabled.", 3)
        pcall(function() g.Phone.show_notification("Success:", "Anti-Sit is now disabled.", "Normal") end)
    end
end
wait(0.1)
g.Anti_Tent_Spawning = function(state)
    g.Anti_Tent_Spawning_Currently_Active = state
    if not state then g.FlamesLibrary.disconnect("anti_tent_spawning"); return end
    local PlacedModels = g.cached_placed_models_folder or g.find_placed_models_folder()
    if not PlacedModels or not PlacedModels:IsA("Folder") then g.notify("Error", "Folder: PlacedModels does not exist or was not found.", 3); return end
    if not g.Not_Ever_Sitting then if g.anti_sit_func and typeof(g.anti_sit_func) == "function" then g.anti_sit_func(true) end end
    local function neuter_tent(tent)
        if not tent:IsA("Model") or tent.Name ~= "Tent" then return end
        pcall(function()
            for _, v in ipairs(tent:GetDescendants()) do
                if v:IsA("BasePart") or v:IsA("UnionOperation") or v:IsA("MeshPart") or v:IsA("SpecialMesh") then
                    v.Transparency = 1
                end
                if v:IsA("Seat") or v:IsA("VehicleSeat") then
                    v.Disabled = true
                    v.Transparency = 1
                end
            end
        end)
    end

    for _, v in ipairs(PlacedModels:GetChildren()) do neuter_tent(v) end
    FlamesLibrary.connect("anti_tent_spawning", PlacedModels.ChildAdded:Connect(function(child)
        if not g.Anti_Tent_Spawning_Currently_Active then return end
        neuter_tent(child)
    end))
end

g.is_player_invisible = function(plr)
    local char = plr.Character or g.get_char(plr)
    if not char then return false end
    local parts = {}
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("MeshPart") then
            table.insert(parts, v)
        end
    end

    if #parts == 0 then return false end
    for _, v in ipairs(parts) do if v.Transparency ~= 1 then return false end end
    return true
end

g.Anti_Invisible_Players = function(state)
    g.Anti_Invisible_Players_Currently_Active = state
    if not state then
        g.FlamesLibrary.disconnect("anti_invis_player_added")
        g.FlamesLibrary.disconnect("anti_invis_char_added")
        g.FlamesLibrary.disconnect("anti_invis_loop")
        return
    end

    local function fix_invisible(plr)
        if not g.Anti_Invisible_Players_Currently_Active then return end
        local char = plr.Character or g.get_char(plr)
        if not char then return end
        if not g.is_player_invisible(plr) then return end
        pcall(function()
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("MeshPart") then
                    v.Transparency = 0
                end
            end
        end)
    end

    for _, plr in ipairs(g.Players:GetPlayers()) do fix_invisible(plr) end
    FlamesLibrary.connect("anti_invis_player_added", g.Players.PlayerAdded:Connect(function(plr)
        if not g.Anti_Invisible_Players_Currently_Active then return end
        fix_invisible(plr)
    end))

    FlamesLibrary.connect("anti_invis_char_added", g.Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            if not g.Anti_Invisible_Players_Currently_Active then return end
            task.wait(0.5)
            fix_invisible(plr)
        end)
    end))

    FlamesLibrary.spawn("anti_invis_loop", "spawn", function()
        while g.Anti_Invisible_Players_Currently_Active == true do
            for _, plr in ipairs(g.Players:GetPlayers()) do
                if plr ~= g.LocalPlayer then
                    fix_invisible(plr)
                end
            end
            fw(3)
        end
    end)
end

g.annoyance_GUI = function()
    if CoreGui:FindFirstChild("AnnoyGUI") and CoreGui:FindFirstChild("AnnoyGUI"):IsA("ScreenGui") then
        CoreGui:FindFirstChild("AnnoyGUI").Enabled = true
        return 
    end
    g.AnnoyList = g.AnnoyList or {}
    g.group_chatting_users = g.group_chatting_users or {}
    g.Creating_Groups = false

    local ScreenGui = CoreGui:FindFirstChild("AnnoyGUI") or Instance.new("ScreenGui")
    ScreenGui.Name = "AnnoyGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false

    local AnnoyerGUIFrame = Instance.new("Frame")
    AnnoyerGUIFrame.Size = UDim2.new(0, 300, 0, 400)
    AnnoyerGUIFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    AnnoyerGUIFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    AnnoyerGUIFrame.BorderSizePixel = 0
    AnnoyerGUIFrame.Parent = ScreenGui
    Instance.new("UICorner", AnnoyerGUIFrame).CornerRadius = UDim.new(0, 12)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 35)
    TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = AnnoyerGUIFrame
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -35, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.Text = "Annoy / Group Spam Menu | Made By: "..tostring(g.Script_Creator).."."
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.TextScaled = true
    Title.TextSize = 14
    Title.Parent = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 25, 0, 25)
    CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
    CloseBtn.Text = "X"
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextScaled = true
    CloseBtn.TextSize = 14
    CloseBtn.Parent = TitleBar
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = false
        g.easy_click_plr = false
        g.Creating_Groups = false
    end)

    local PlayerList = Instance.new("ScrollingFrame")
    PlayerList.Size = UDim2.new(1, -10, 1, -45)
    PlayerList.Position = UDim2.new(0, 5, 0, 40)
    PlayerList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PlayerList.BorderSizePixel = 0
    PlayerList.ScrollBarThickness = 6
    PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerList.Parent = AnnoyerGUIFrame
    Instance.new("UICorner", PlayerList).CornerRadius = UDim.new(0, 10)

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = PlayerList
    UIListLayout.Padding = UDim.new(0, 5)

    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)
    if g.dragify and typeof(g.dragify) == "function" then g.dragify(AnnoyerGUIFrame) end
    local function ToggleAnnoy(plr, btn)
        if g.easy_click_plr and g.easy_click_target == plr.Name then
            g.easy_click_plr = false
            if g.Toggling_Annoyance_Loop_Carry_AndCall then
                pcall(function()
                    task.cancel(g.Toggling_Annoyance_Loop_Carry_AndCall)
                    g.Toggling_Annoyance_Loop_Carry_AndCall = nil
                end)
            end
            btn.Text = "Annoy Off"
            btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            g.easy_click_target = plr.Name
            g.easy_click_plr = true
            btn.Text = "Annoy On"
            btn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
            g.Toggling_Annoyance_Loop_Carry_AndCall = g.Toggling_Annoyance_Loop_Carry_AndCall or task.spawn(function()
                while g.easy_click_plr and g.easy_click_target == plr.Name do
                fw(0)
                    g.Send("request_carry", plr.Name)
                    fw(0)
                    g.Send("request_call", plr.Name)
                    fw(0)
                    g.Send("end_call", plr.Name)
                end
            end)
        end
    end

    local function ToggleGroupSpam(plr, btn)
        if table.find(g.group_chatting_users, plr.Name) then
            table.remove(g.group_chatting_users, table.find(g.group_chatting_users, plr.Name))
            if g.Always_Creating_TheGroups_Loop_Task then
                task.cancel(g.Always_Creating_TheGroups_Loop_Task)
                g.Always_Creating_TheGroups_Loop_Task = nil
            end
            btn.Text = "Group Spam Off"
            btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            if #g.group_chatting_users == 0 then
                g.Creating_Groups = false
            end
        else
            table.insert(g.group_chatting_users, plr.Name)
            btn.Text = "Group Spam On"
            btn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
            g.Creating_Groups = true
            g.Always_Creating_TheGroups_Loop_Task = g.Always_Creating_TheGroups_Loop_Task or task.spawn(function()
                while g.Creating_Groups == true do
                wait(.4)
                    local userIds = {}
                    for _, name in ipairs(g.group_chatting_users) do
                        local success, userId = pcall(function()
                            return Players:GetUserIdFromNameAsync(name)
                        end)
                        if success and userId then
                            table.insert(userIds, userId)
                        end
                    end

                    if #userIds == 1 then
                        local others = {}
                        for _, other in ipairs(Players:GetPlayers()) do
                            if other.Name ~= g.group_chatting_users[1] and other ~= LocalPlayer then
                                table.insert(others, other)
                            end
                        end

                        for i = #others, 2, -1 do
                            local j = math.random(i)
                            others[i], others[j] = others[j], others[i]
                        end

                        for i = 1, math.min(3, #others) do
                            table.insert(userIds, others[i].UserId)
                        end
                    end

                    if #userIds > 0 then
                        g.Get("new_group", userIds)
                    end
                end
            end)
        end
    end

    local function createPlayerEntry(plr)
        if plr == LocalPlayer then return end
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, -5, 0, 110)
        Container.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        Container.BorderSizePixel = 0
        Container.Parent = PlayerList
        Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 8)

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Size = UDim2.new(1, -10, 0, 20)
        NameLabel.Position = UDim2.new(0, 5, 0, 5)
        NameLabel.Text = "DisplayName: " .. plr.DisplayName
        NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        NameLabel.BackgroundTransparency = 1
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.Font = Enum.Font.Gotham
        NameLabel.TextSize = 13
        NameLabel.Parent = Container

        local UserLabel = Instance.new("TextLabel")
        UserLabel.Size = UDim2.new(1, -10, 0, 20)
        UserLabel.Position = UDim2.new(0, 5, 0, 25)
        UserLabel.Text = "Username: " .. plr.Name
        UserLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        UserLabel.BackgroundTransparency = 1
        UserLabel.TextXAlignment = Enum.TextXAlignment.Left
        UserLabel.Font = Enum.Font.Gotham
        UserLabel.TextSize = 12
        UserLabel.Parent = Container

        local IdLabel = Instance.new("TextLabel")
        IdLabel.Size = UDim2.new(1, -10, 0, 20)
        IdLabel.Position = UDim2.new(0, 5, 0, 45)
        IdLabel.Text = "UserId: " .. tostring(plr.UserId)
        IdLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        IdLabel.BackgroundTransparency = 1
        IdLabel.TextXAlignment = Enum.TextXAlignment.Left
        IdLabel.Font = Enum.Font.Gotham
        IdLabel.TextSize = 12
        IdLabel.Parent = Container

        local AnnoyButton = Instance.new("TextButton")
        AnnoyButton.Size = UDim2.new(0, 110, 0, 20)
        AnnoyButton.Position = UDim2.new(0, 10, 0, 70)
        AnnoyButton.Text = "Annoy Off"
        AnnoyButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        AnnoyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        AnnoyButton.Font = Enum.Font.GothamBold
        AnnoyButton.TextScaled = true
        AnnoyButton.TextSize = 13
        AnnoyButton.Parent = Container
        AnnoyButton.MouseButton1Click:Connect(function()
            ToggleAnnoy(plr, AnnoyButton)
        end)

        local GroupButton = Instance.new("TextButton")
        GroupButton.Size = UDim2.new(0, 110, 0, 20)
        GroupButton.Position = UDim2.new(0, 140, 0, 70)
        GroupButton.Text = "Group Spam Off"
        GroupButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        GroupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        GroupButton.Font = Enum.Font.GothamBold
        GroupButton.TextScaled = true
        GroupButton.TextSize = 13
        GroupButton.Parent = Container
        Instance.new("UICorner", GroupButton).CornerRadius = UDim.new(0, 6)
        GroupButton.MouseButton1Click:Connect(function()
            ToggleGroupSpam(plr, GroupButton)
        end)

        Instance.new("UICorner", AnnoyButton).CornerRadius = UDim.new(0, 6)
        Instance.new("UICorner", GroupButton).CornerRadius = UDim.new(0, 6)
        if g.easy_click_plr and g.easy_click_target == plr.Name then
            AnnoyButton.Text = "Annoy On"
            AnnoyButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
        end

        if table.find(g.group_chatting_users, plr.Name) then
            GroupButton.Text = "Group Spam On"
            GroupButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
        end

        PlayerList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
    end

    local function refresh_player_list()
        for _, child in ipairs(PlayerList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            createPlayerEntry(plr)
        end
    end

    if not g.RefreshPlayer_ListAdded_Conn then
        g.RefreshPlayer_ListAdded_Conn = true
        Players.PlayerAdded:Connect(refresh_player_list)
        Players.PlayerRemoving:Connect(refresh_player_list)
    end

    refresh_player_list()
end

local Hum = g.Humanoid or g.Character and g.Character:FindFirstChildOfClass("Humanoid") or g.get_human(LocalPlayer or Players.LocalPlayer, Players.RespawnTime + 0.5)
local HD = Hum:FindFirstChildOfClass("HumanoidDescription")
g.GlitchIDs = {
   Shirts = {6028801590, 11595159513},
   Pants  = {6028804735, 11595172734}
}

g.isWearing = g.isWearing or function(desc, slot, id)
    return desc and tostring(desc[slot]) == tostring(id)
end

g.forceEquip = g.forceEquip or function(slot, id)
    if not g.isWearing(HD, slot, id) then
        g.Get("code", id, slot)
    end
end

g.forceUnequip = g.forceUnequip or function(slot, id)
    if g.isWearing(HD, slot, id) then
        g.Get("wear", id, slot)
    end
end

local applied = g.Humanoid:GetAppliedDescription()
local Old_Shirt = applied.Shirt
local Old_Pants = applied.Pants
g.glitch_outfit = g.glitch_outfit or function(toggle)
    local FL = g.FlamesLibrary

    if toggle == true then
        if g.Glitching_Outfit then g.notify("Warning", "Glitch Outfit is already enabled.", 3); return end
        g.Glitching_Outfit = true
        FL.spawn("glitch_outfit_loop", "spawn", function()
            while g.Glitching_Outfit == true do
                fw(0)
                for _, shirtId in ipairs(g.GlitchIDs.Shirts) do
                    g.forceEquip("Shirt", shirtId)
                    task.wait()
                    g.forceUnequip("Shirt", shirtId)
                end
                fw(0.1)
                for _, pantsId in ipairs(g.GlitchIDs.Pants) do
                    g.forceEquip("Pants", pantsId)
                    task.wait()
                    g.forceUnequip("Pants", pantsId)
                end
            end
        end)
    else
        if not g.Glitching_Outfit then g.notify("Warning", "Glitch Outfit is not enabled.", 3); return end
        g.Glitching_Outfit = false
        FL.disconnect("glitch_outfit_loop")
        FL.spawn("glitch_outfit_restore", "delay", 0.5, function()
            g.Send("code", Old_Shirt, "Shirt")
            task.wait()
            g.Send("code", Old_Pants, "Pants")
        end)
    end
end

function check_friends()
    for _, v in ipairs(g.Players:GetPlayers()) do
        if v ~= g.LocalPlayer and v:IsFriendsWith(g.LocalPlayer.UserId) then
            g.alreadyCheckedUser(v)
        end
    end
end

function auto_add_friends()
    for _, v in ipairs(g.Players:GetPlayers()) do
        if v ~= g.LocalPlayer and v:IsFriendsWith(g.LocalPlayer.UserId) then
            check_friends()
            g.addPlayerToScriptWhitelistTable(v)
        end
    end
end

auto_add_friends()

if g.PlayerControls == nil then
    local PlayerModule = require(g.PlayerScripts:WaitForChild("PlayerModule"))
    g.PlayerControls = PlayerModule:GetControls()
end

g.Viewing_Plr_Tbl = g.Viewing_Plr_Tbl or {}
g.viewTarget = g.viewTarget or function(player)
    if g.Viewing_A_Player then
        if g.Viewing_Plr_Tbl[player.Name] then g.notify("Error","You're already viewing: "..player.DisplayName, 3); return end
        g.notify("Error","You're already viewing a Player.",5)
        return 
    end

    if not player or not player.Character then g.notify("Error", "Invalid player.", 3); return end
    local char = player.Character or g.get_char(player, Players.RespawnTime + 0.75)
    local hum = char and char:FindFirstChildWhichIsA("Humanoid") or g.get_human(player, Players.RespawnTime + 0.5)
    if not hum or not hum.Parent or not hum:IsDescendantOf(game) then g.notify("Error", "Player has no humanoid.", 3); return end
    local root = hum and hum.RootPart or char and char:FindFirstChild("HumanoidRootPart") or g.get_root(player, Players.RespawnTime + 0.5)
    g.Camera.CameraSubject = hum
    g.Viewing_A_Player = true
    g.Viewing_Plr_Tbl[player.Name] = {
        Name = player.Name,
        DisplayName = player.DisplayName,
        UserId = player.UserId,
        Character = char,
        Humanoid = hum,
        HumanoidRootPart = root
    }
end

g.unview_player = g.unview_player or function()
    local genv = g
    if not genv.Viewing_A_Player then genv.notify("Error", "You're not viewing anyone.", 5); return end
    local hum = genv.Humanoid or genv.Character:FindFirstChildOfClass("Humanoid") or g.get_human(LocalPlayer, 1)
    local char = genv.Character or genv.LocalPlayer.Character or g.get_char(LocalPlayer, 1)
    local subject = hum or (char and char:FindFirstChildWhichIsA("Humanoid")) or char
    if subject and genv.Camera then
        genv.Camera.CameraSubject = subject
    elseif not genv.Camera then
        workspace.CurrentCamera.CameraSubject = subject
    end

    if typeof(genv.Viewing_Plr_Tbl) ~= "table" then genv.Viewing_Plr_Tbl = {} end
    if next(genv.Viewing_Plr_Tbl) == nil then
        genv.notify(
            "Error",
            "Viewing table is empty (tried unviewing nobody? how?).",
            10
        )
        return 
    end

    local viewed
    for k, v in pairs(genv.Viewing_Plr_Tbl) do
        local ok, display = pcall(function() return (v :: any).DisplayName end)
        viewed = (typeof(v) == "Instance" and ok and display) or k
        break
    end

    genv.Viewing_A_Player = false
    table.clear(genv.Viewing_Plr_Tbl)
    genv.notify("Success", "Stopped viewing: "..tostring(viewed), 5)
end

g.check_friend = g.check_friend or function(Player)
    if Player ~= g.LocalPlayer and Player:IsFriendsWith(g.LocalPlayer.UserId) then
        return true
    else
        return false
    end
end

g.spam_create_groups = g.spam_create_groups or function(toggle)
    local FL = g.FlamesLibrary
    if toggle == true then
        if g.Creating_Groups then g.notify("Warning", "Group spammer is already enabled.", 3); return end
        g.group_chatting_users = g.group_chatting_users or {}
        g.Creating_Groups = true
        FL.spawn("spam_create_groups_loop", "spawn", function()
            while g.Creating_Groups == true do
                fw(0)
                for _, name in ipairs(g.group_chatting_users) do
                    local success, userId = pcall(function()
                        return Players:GetUserIdFromNameAsync(name)
                    end)

                    if success and userId then
                        g.Get("new_group", userId)
                    end
                end
            end
        end)
    elseif toggle == false then
        if not g.Creating_Groups then g.notify("Warning", "Group spammer is not enabled.", 3); return end
        g.Creating_Groups = false
        FL.disconnect("spam_create_groups_loop")
    else
        return
    end
end

g.attach_with_script = g.attach_with_script or function()
    local Methods = {
        "Secret",
        "Sneaky",
        "Private",
        "Normal",
        "Bypass",
        "External",
        "Internal",
        "Rage",
        "Silent",
        "Source",
        "MainClass",
        "Class_C",
        "Non-Closure",
        "Encoded",
        "Bytecode",
        "Obfuscated"
    }

    local Attached = false
    g.Script_Was_Attached_Successfully = Attached
    local Old_Text = g.CreditsLabelText.Text
    task.wait(0.4)
    for i = 1, 3 do
        wait(0.6)
        g.CreditsLabelText.Text = "[Starting]: Attaching."
        wait(0.6)
        g.CreditsLabelText.Text = "[Starting]: Attaching.."
        wait(0.6)
        g.CreditsLabelText.Text = "[Starting]: Attaching..."
    end
    task.wait(.1)
    Attached = true
    task.wait(.1)
    if Attached == true then
        g.CreditsLabelText.Text = "[Starting]: Getting requirements."
        wait(0.6)
        g.CreditsLabelText.Text = "[Starting]: Getting requirements.."
        wait(0.6)
        g.CreditsLabelText.Text = "[Starting]: Getting requirements..."
        wait(0.5)
        g.CreditsLabelText.Text = "[Success]: Got requirements successfully!"
        wait(0.6)
        for i = 1, 3 do
            wait(0.6)
            g.CreditsLabelText.Text = "[Initializing]: Collecting prerequisites."
            wait(0.6)
            g.CreditsLabelText.Text = "[Initializing]: Collecting prerequisites.."
            wait(0.6)
            g.CreditsLabelText.Text = "[Initializing]: Collecting prerequisites..."
        end
    end
    task.wait(0.3)
    for i = 1, 8 do
        wait(0.6)
        g.CreditsLabelText.Text = "[Finalizing]: Collecting prerequisites."
        wait(0.6)
        g.CreditsLabelText.Text = "[Finalizing]: Collecting prerequisites.."
        wait(0.6)
        g.CreditsLabelText.Text = "[Finalizing]: Collecting prerequisites..."
    end
    fw(0.2)
    for i = 1, 4 do
        wait(0.6)
        g.CreditsLabelText.Text = "[Finishing]: Selecting method."
        wait(0.6)
        g.CreditsLabelText.Text = "[Finishing]: Selecting method.."
        wait(0.6)
        g.CreditsLabelText.Text = "[Finishing]: Selecting method..."
    end
    task.wait(0.3)
    local function ChooseMethod() return Methods[math.random(1, #Methods)] end
    g.CreditsLabelText.Text = "[Finished]: Method: "..tostring(ChooseMethod())
    wait(0.7)
    g.CreditsLabelText.Text = "Attached."
    wait(0.8)
    g.CreditsLabelText.Text = Old_Text
end

g.PlotAreas = {}
g.update_plot_areas = g.update_plot_areas or function()
    table.clear(g.PlotAreas)
    fw(0.2)
    for _, v in ipairs(g.Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "PlotArea" then
            g.PlotAreas[v] = v
        end
    end
end

g.in_humanoid_vehicle = g.in_humanoid_vehicle or function(PlayerOrName)
    local HumanoidVehicles = g.Workspace:FindFirstChild("HumanoidVehicles", true)
    if not HumanoidVehicles then return end
    local Player = PlayerOrName
    if typeof(PlayerOrName) == "string" then
        Player = g.Players:FindFirstChild(PlayerOrName)
        if not Player then return end
    end

    local Character = Player == g.LocalPlayer and g.Character or Player.Character
    if not Character then return end
    local humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid") or g.get_human(Player, 3)
    if not humanoid then return end
    local vehicleAttr = humanoid:GetAttribute("InHumanoidVehicle")
    if vehicleAttr == nil then return end
    if type(g.Humanoid_Vehicles) ~= "table" then return end
    if not table.find(g.Humanoid_Vehicles, vehicleAttr) then return end
    return vehicleAttr
end

g.hum_vehicle_name = g.hum_vehicle_name or function(plr)
    local hv = g.in_humanoid_vehicle(plr)
    if not hv then return nil end
    local folder = g.Workspace:FindFirstChild("HumanoidVehicles", true)
    if not folder or not folder:IsA("Folder") then return nil end
    local inst = folder:FindFirstChild(hv)
    if not inst then return nil end
    return inst.Name
end

g.set_hum_vehicle_speed = g.set_hum_vehicle_speed or function(speed)
    speed = tonumber(speed) or 50
    if typeof(speed) ~= "number" then speed = 50 end
    if g.in_humanoid_vehicle(g.LocalPlayer) then pcall(function() g.Humanoid.WalkSpeed = tonumber(speed) end) end
end

local screenGui
g.update_plot_areas()
wait(0.15)
if CoreGui:FindFirstChild("TemporaryBanner_GUI") then
    pcall(function()
        if g.camConn then
            g.camConn:Disconnect()
            g.camConn = nil
        end
        if screenGui and screenGui.Parent then screenGui:Destroy() end
        g.updatePosition = nil
        g.clamp = nil
    end)
end
wait(0.7)
screenGui = Instance.new("ScreenGui")
screenGui.Name = "TemporaryBanner_GUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Name = "BannerFrame"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 20)
frame.Size = UDim2.new(0.6, 0, 0, 48)
frame.BackgroundTransparency = 0
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Parent = screenGui

g.make_round(frame, 12)
g.flowrgb("banner_announcement_frame_flowing_rgb_smooth_conn", 3.5, frame, true)
g.make_stroke(frame, 1.5, 0.25)

local label = Instance.new("TextLabel")
label.Name = "BannerText"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.5, 0)
label.Size = UDim2.new(0.95, 0, 0.9, 0)
label.BackgroundTransparency = 1
label.Text = tostring(Announcement_Message)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.RichText = false
label.TextWrapped = true
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Parent = frame

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0)
shadow.Position = UDim2.new(0.5, 0, 0, 24)
shadow.Size = UDim2.new(0.62, 0, 0, 56)
shadow.Image = "rbxassetid://5059716102"
shadow.BackgroundTransparency = 1
shadow.ImageTransparency = 0.8
shadow.ZIndex = frame.ZIndex - 1
shadow.Parent = screenGui
shadow.Visible = false

g.clamp = g.clamp or function(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

g.updatePosition = g.updatePosition or function()
    local _, vh = g.Workspace.CurrentCamera.ViewportSize.X, g.Workspace.CurrentCamera.ViewportSize.Y
    local widthScale = g.clamp(0.6, 0.4, 0.8)
    local heightPx = g.clamp(math.floor(vh * 0.07), 36, 72)
    frame.Size = UDim2.new(widthScale, 0, 0, heightPx)
    local topOffset = math.max(12, math.floor(vh * 0.03))
    frame.Position = UDim2.new(0.5, 0, 0, topOffset)
    shadow.Position = UDim2.new(0.5, 0, 0, topOffset + math.floor(heightPx/2))
    shadow.Size = UDim2.new(widthScale + 0.02, 0, 0, heightPx + 12)
end

g.updatePosition()
g.camConn = nil
if g.Workspace and g.Workspace.CurrentCamera then g.camConn = g.Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(g.updatePosition) end
frame.BackgroundTransparency = 1
label.TextTransparency = 1
shadow.ImageTransparency = 1
appearInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
g.TweenService:Create(frame, appearInfo, {BackgroundTransparency = 0}):Play()
g.TweenService:Create(label, appearInfo, {TextTransparency = 0}):Play()
shadow.Visible = false
g.TweenService:Create(shadow, appearInfo, {ImageTransparency = 0.8}):Play()
displayTime = g.displayTimeMax
delay(displayTime, function()
    local fadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    local t1 = g.TweenService:Create(frame, fadeInfo, {BackgroundTransparency = 1})
    local t2 = g.TweenService:Create(label, fadeInfo, {TextTransparency = 1})
    local t3 = g.TweenService:Create(shadow, fadeInfo, {ImageTransparency = 1})
    t1:Play(); t2:Play(); t3:Play()
    t1.Completed:Wait()
    pcall(function()
        if g.camConn then
            g.camConn:Disconnect()
            g.camConn = nil
        end
        screenGui:Destroy()
    end)
end)

if not g.SetupGone_Through_Flames_Hub then
    pcall(function()
        g.LocalPlayer:SetSuperSafeChat(false)
        g.LocalPlayer.CameraMaxZoomDistance = 100000
        g.LocalPlayer.CameraMinZoomDistance = 0.5
    
        if g.LocalPlayer.CameraMaxZoomDistance > 90000 then
            g.notify("Success", "Set CameraMaxZoomDistance to: "..tostring(g.LocalPlayer.CameraMaxZoomDistance), 7)
        else
            g.notify("Warning", "We we're not able to correctly set CameraMaxZoomDistance!", 5)
        end
        if g.LocalPlayer.CameraMinZoomDistance < 5 then
            g.notify("Success", "Set CameraMinZoomDistance to: "..tostring(g.LocalPlayer.CameraMinZoomDistance), 7)
        else
            g.notify("Warning", "We we're not able to correctly set CameraMinZoomDistance!", 5)
        end

        if g.StarterPlayer.CharacterUseJumpPower then
            g.Humanoid.JumpPower = 50
            g.notify("Success", "Spoofed JumpPower to: "..tostring(g.Humanoid.JumpPower))
        else
            g.Humanoid.JumpHeight = 7
            g.notify("Success", "Spoofed JumpHeight to: "..tostring(g.Humanoid.JumpHeight))
        end
        g.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        if g.LocalPlayer.Name == "Yadsan_Godverse" or g.LocalPlayer.Name == "L0CKED_1N1" or g.LocalPlayer.Name == "AuraWithClipFarmin" then
            g.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
            g.notify("Success", "Enabled Leaderboard & Backpack.", 5)
        else
            g.notify("Success", "Enabled Leaderboard.", 5)
        end
    end)

    g.SetupGone_Through_Flames_Hub = true
end

if not g.SeenCommandAndCameraIntro then
    g.notify("Success", "[HOOKED]: We have hooked the Camera successfully.", 5)
    fw(0.2)
    g.notify("Warning", "[INITIALIZING]: Setting up command receiver...", 5)
    fw(0.1)
    g.SeenCommandAndCameraIntro = true
end

for _, v in ipairs(Players:GetPlayers()) do g.setup_cmd_handler_plr(v) end
if not g.AdminHasBeenLoaded_NotificationCheck then
    g.notify("Success", "[INITIALIZED]: Life Together RP-Admin has been loaded!", 7)
    g.notify("Success", "[LOADED]: | [Life Together-RP : Admin_Commands]: Loaded!", 7)
    g.AdminHasBeenLoaded_NotificationCheck = true
end

g.automatically_add_friends = function()
    for _, v in ipairs(g.Players:GetPlayers()) do
        if v ~= g.LocalPlayer and v:IsFriendsWith(g.LocalPlayer.UserId) then
            g.alreadyCheckedUser(v)
        end
    end
end

g.automatically_remove_friends = function()
    for _, v in ipairs(g.Players:GetPlayers()) do
        if v ~= g.LocalPlayer and v:IsFriendsWith(g.LocalPlayer.UserId) and v.Character == nil then
            g.Rainbow_Others_Vehicle = false
        end
    end
end

if g.LifeTogetherRP_Admin and g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub and g.LifeTogether_Actual_Flames_Hub_Running_Functioning_Currently_On_Client then
    g.notify("Success", "Reloaded script successfully.", 15)
end

for _, v in ipairs(Players:GetPlayers()) do
    if v.Name == "Yadsan_Godverse" or v.Name == "L0CKED_1N1" or v.Name == "AuraWithClipFarmin" then
        local owner_content = "Yadsan Hub | Owner is currently in this server, come to me: ("..tostring(v.Name)..") for assistance (if you need help)."
        g.notify("Success", owner_content, 30)
    elseif allowed[v.Name] and v.Name ~= "Yadsan_Godverse" and v.Name ~= "L0CKED_1N1" and v.Name ~= "AuraWithClipFarmin" then
        local staff_content = "A Yadsan Hub | Staff member is currently in this server, this is more rare and they can get in contact with me faster."
        g.notify("Success", staff_content, 15)
    end
end

g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub = g.Script_Loaded_Correctly_LifeTogether_Admin_Flames_Hub or true
if not g.FlamesHubPlayerEvents_Check then
    g.FlamesHubPlayerEvents_Check = true
    g.FlamesLibrary.connect("PlayerAdded_OwnerAdminCheck", Players.PlayerAdded:Connect(function(Player)
        local Name = Player and Player.Name
        g.Blacklisted_Friends = g.Blacklisted_Friends or {}
        if Player:IsFriendsWith(speaker.UserId) then
            if not g.Blacklisted_Friends[Name] then
                g.automatically_add_friends()
            end
        end

        -- [[ make who ever you want the owner, like yourself. ]] --
        if Name == "Yadsan_Godverse" or Name == "L0CKED_1N1" or Name == "AuraWithClipFarmin" then
            g.owner_joined(Name)
            if g.friend_checked[Name] then
                g.player_admins[Name] = nil
                g.friend_checked[Name] = nil
            end
            if g.cmds_loaded_plr[Name] then
                g.cmds_loaded_plr[Name] = nil
            end
        elseif allowed[Name] and Name ~= "L0CKED_1N1" and Name ~= "Yadsan_Godverse" and Name ~= "AuraWithClipFarmin" then
            g.notify("Success", "An official staff member of Yadsan Hub has joined your server, UserName: "..tostring(Name), 15)
        end
    end))

    g.FlamesLibrary.connect("PlayerRemoving_OwnerAdminRemoval", Players.PlayerRemoving:Connect(function(Player)
        local Name = Player.Name
        if Name == "Yadsan_Godverse" or Name == "L0CKED_1N1" or Name == "AuraWithClipFarmin" then
            g.notify("Info", "The owner of this script has left the server.", 5)
        elseif allowed[Name] and Name ~= "L0CKED_1N1" and Name ~= "Yadsan_Godverse" and Name ~= "AuraWithClipFarmin" then
            g.notify("Success", "Yadsan Hub | Staff member has left your server: "..tostring(Name), 15)
        end

        g.disable_rgb_for(Name)
        g.fully_disable_rgb_plr(Name)
        if g.Locked_Vehicles[Name] then g.Locked_Vehicles[Name] = false end
        if g.Unlocked_Vehicles[Name] then g.Unlocked_Vehicles[Name] = false end
    end))
end

local Atlas = loadstring(game:HttpGet("https://gitlab.com/flames2431233/Starter/-/raw/main/UIs/Atlas.lua?ref_type=heads", true))()
local UI = Atlas.new({
    Name = "Yadsan Hub | Life Together RP",
    ConfigFolder = "FlamesHub_Life_Together_RP_Menu_Configuration",
    Color = Color3.fromRGB(255, 215, 0),
    Credit = "Yadsan Hub",
    Bind = "RightShift",
})
wait(0.25)
g.create_ui_element = g.create_ui_element or function(element_type, parent, config, global_name, flag)
    local creators = {
        Tab         = function() return parent:CreatePage(config) end,
        Section     = function() return parent:CreateSection(config) end,
        Toggle      = function() return parent:CreateToggle(config, flag) end,
        Slider      = function() return parent:CreateSlider(config, flag) end,
        Button      = function() return parent:CreateButton(config, flag) end,
        ColorPicker = function() return parent:CreateColorPicker(config, flag) end,
        Input       = function() return parent:CreateTextBox(config, flag) end,
        Dropdown    = function() return parent:CreateDropdown(config, flag) end,
        Label       = function() return parent:CreateLabel(config, flag) end,
    }

    local creator = creators[element_type]
    if not creator then return g.notify("Error", "Unknown element type: " .. tostring(element_type), 1) end
    local element
    local done = false
    task.defer(function()
        element = creator()
        done = true
    end)

    while not done do task.wait() end
    if global_name then g[global_name] = element end
    return element
end
wait(0.25)
g.notify("Success", "Now loading UI elements...", 10)
local Home_Page = UI:CreatePage("Main")
local Home_Section = Home_Page:CreateSection("Main")
local LocalPlayer_Section = Home_Page:CreateSection("LocalPlayer")
local Vehicle_Section = Home_Page:CreateSection("Vehicle")
local Players_Section = Home_Page:CreateSection("Players")
local priv_server_is_in = g.is_in_private_server()
local PrivServer_Section
if priv_server_is_in == true then
    PrivServer_Section = Home_Page:CreateSection("Private Server")
end
local Phone_Section = Home_Page:CreateSection("Phone")
local Houses_Section = Home_Page:CreateSection("Houses")
local Extras_Section = Home_Page:CreateSection("Extras")
wait(0.25)
g.create_ui_element("Button", Home_Section, {
Name = "Join the Yadsan Hub Discord server.",
Callback = function()
    local http_requesting_func = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    local opened = false
    if http_requesting_func and typeof(http_requesting_func) == "function" then
        local success = pcall(function()
            http_requesting_func({
                Url = 'http://127.0.0.1:6463/rpc?v=1',
                Method = 'POST',
                Headers = {
                    ['Content-Type'] = 'application/json',
                    Origin = 'https://discord.com'
                },
                Body = HttpService:JSONEncode({
                    cmd = 'INVITE_BROWSER',
                    nonce = HttpService:GenerateGUID(false),
                    args = {code = 'yadsan_godverse'}
                })
            })
        end)
        opened = success
    end
    wait(0.25)
    if not opened then
        if g.AllClipboards then g.AllClipboards("https://discord.gg/yadsan_godverse_78097") end
        if g.notify then g.notify("Success", "Successfully copied Discord server link to your Clipboard.", 5) end
    end
end,})

g.create_ui_element("Toggle", Home_Section, {
Name = "Survey Spam (YS)",
Default = g.Spam_And_Spoof_Survey_Submissions or false,
Flag = "Survey_Spammer_Toggle_UI",
Callback = function(state)
    g.Spam_Survey_Completions(state)
end}, "Survey_Spammer_Toggle_UI")

g.create_ui_element("Toggle", Home_Section, {
Name = "Hide DAISE Area",
Default = g.DAISE_Area_Hidden or false,
Flag = "Hide_DAISE_Area_Toggle_UI",
Callback = function(state)
    g.Hide_DAISE_Area(state)
end}, "Hide_DAISE_Area_Toggle_UI")

g.create_ui_element("Toggle", Home_Section, {
Name = "Anti Tent Spawn",
Default = g.Anti_Tent_Spawning_Currently_Active or false,
Flag = "Anti_Tent_Spawning_Toggled_UI",
Callback = function(state)
    g.Anti_Tent_Spawning(state)
end}, "Anti_Tent_Spawning_Toggled_UI")

g.create_ui_element("Toggle", Players_Section, {
Name = "Anti Invisible Players",
Default = g.Anti_Invisible_Players_Currently_Active or false,
Flag = "No_Player_Invisible_Toggle_UI",
Callback = function(state)
    g.Anti_Invisible_Players(state)
end}, "No_Player_Invisible_Toggle_UI")

g.create_ui_element("Button", Home_Section, {
Name = "Open Mini-Games GUI (Fun)",
Callback = function()
    g.open_minigame_menu()
end,})

g.create_ui_element("Button", Home_Section, {
Name = "Destroy GUI",
Callback = function()
    if Atlas then Atlas:Destroy() end
end,})

g.create_ui_element("Toggle", Home_Section, {
Name = "Anti Hashtags (YS) BETA!",
Default = (FlamesLibrary.modules and FlamesLibrary.modules.chat_filter_override.enabled) or false,
Flag = "Anti_Hashtags_Toggle_UI",
Callback = function(state)
    if FlamesLibrary.modules then FlamesLibrary.modules.chat_filter_override:toggle(state) end
end}, "Anti_Hashtags_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Job Spammer (YS)",
Default = g.Every_Job or false,
Flag = "Job_Spammer_Toggled_UI",
Callback = function(state)
    g.job_spammer(state)
end}, "Job_Spammer_Toggled_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Anti Clothing Ban (YS)",
Default = false,
Flag = "Anti_Clothes_Ban_Roblox_Bypass_Toggle_UI",
Callback = function(state)
    g.toggle_anti_clothing_ban_system(state)
end}, "Anti_Clothes_Ban_Roblox_Bypass_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Glitch Outfit (YS)",
Default = g.Glitching_Outfit or false,
Flag = "Glitch_Outfit_Toggle_UI",
Callback = function(state)
    g.glitch_outfit(state)
end}, "Glitch_Outfit_Toggle_UI")

g.create_ui_element("Slider", LocalPlayer_Section, {
Name = "Side To Side Speed",
Min = 1,
Max = 100,
Default = g.SideGlitch_Speed or 25,
Flag = "Side_To_Side_Speed_Slider_UI",
Callback = function(val)
    g.SideGlitch_Speed = val
end}, "Side_To_Side_Speed_Slider_UI")

g.create_ui_element("Slider", LocalPlayer_Section, {
Name = "Side To Side Distance",
Min = 1,
Max = 25,
Default = g.SideGlitch_Distance or 5,
Flag = "Side_To_Side_Distance_Slider_UI",
Callback = function(val)
    g.SideGlitch_Distance = val
end}, "Side_To_Side_Distance_Slider_UI")

g.create_ui_element("Slider", LocalPlayer_Section, {
Name = "Side To Side Smoothness",
Min = 0.1,
Max = 1,
Default = g.SideGlitch_Smooth or 5,
Flag = "Side_To_Side_Smoothness_UI_Slider",
Callback = function(val)
    g.SideGlitch_Smooth = val
end}, "Side_To_Side_Smoothness_UI_Slider")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Side To Side Glitch (YS)",
Default = g.SideGlitch_Enabled or false,
Flag = "Side_To_Side_Glitch_Not_Smooth_Toggle_UI",
Callback = function(state)
    if state then
        g.start_glitch_script()
    else
        g.stop_glitch_script()
    end
end}, "Side_To_Side_Glitch_Not_Smooth_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Smooth Side To Side Glitch (YS)",
Default = g.SideGlitch_Enabled or false,
Flag = "Side_To_Side_Glitch_Smooth_Toggle_UI",
Callback = function(state)
    if state then
        g.start_smooth_glitch_script()
    else
        g.stop_glitch_script()
    end
end}, "Side_To_Side_Glitch_Smooth_Toggle_UI")

g.create_ui_element("Button", Vehicle_Section, {
Name = "Despawn Vehicle (YS)",
Callback = function()
    local Current_Car = g.get_vehicle()
    if not Current_Car or not Current_Car:IsA("Model") then g.notify("Error", "You do not have a vehicle spawned!", 3); return end
    if Current_Car then
        g.notify("Success", "Despawned Vehicle: " .. tostring(Current_Car), 5)
        g.spawn_any_vehicle(tostring(Current_Car.Name))
    end
end,})

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Rainbow Vehicle (YS)",
Default = g.Rainbow_Vehicle or false,
Flag = "Rainbow_Vehicle_Toggle_UI",
Callback = function(state)
    g.RGB_Vehicle(state)
end}, "Rainbow_Vehicle_Toggle_UI")

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Two Tone Vehicle (YS)",
Default = g.two_tone_vehicle_colors_changing or false,
Flag = "Two_Tone_Car_Toggle_UI",
Callback = function(state)
    g.two_color_switcher_FE_func(state)
end}, "Two_Tone_Car_Toggle_UI")

g.create_ui_element("Toggle", Phone_Section, {
Name = "Rainbow Phone (YS)",
Default = g.RGB_Rainbow_Phone or false,
Flag = "Rainbow_Phone_Toggle_UI",
Callback = function(state)
    g.RGB_Phone(state)
end}, "Rainbow_Phone_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Free Premium (YS)",
Default = g.Has_Free_LifePremium or false,
Flag = "Free_Premium_Toggle_UI",
Callback = function(state)
    g.FreePayFuncToggle(state)
end}, "Free_Premium_Toggle_UI")

g.create_ui_element("Input", Vehicle_Section, {
Name = "Spawn Vehicle (YS)",
PlaceholderText = "Enter vehicle name...",
Flag = "Spawn_Vehicle_Input_UI",
Callback = function(split)
    local input = split:lower():gsub("%s+", "")
    local matched = false
    if input:find("broom") or input:find("broomstick") then
        g.spawn_any_vehicle("Magic Carpet")
        g.notify("Success", "Spawning requested vehicle: Broomstick.", 3)
        return
    elseif input:find("magiccarpet") or input:find("carpet") then
        g.spawn_any_vehicle("Magic Carpett")
        g.notify("Success", "Spawning requested vehicle: Magic Carpet.", 3)
        return
    end

    for car_key, full_name in pairs(CarMap) do
        local cleanKey = car_key:lower():gsub("%s+", "")
        if cleanKey:find(input, 1, true) then
            g.spawn_any_vehicle(full_name)
            g.notify("Success", "Spawning requested vehicle: " .. tostring(full_name), 3)
            matched = true
            break
        end
    end

    if not matched then g.notify("Error", tostring(input) .. " did not match any existing Vehicles.", 15) end
end}, "Spawn_Vehicle_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Teleport To Player",
PlaceholderText = "user or display...",
Flag = "Teleport_Player_Input_UI",
Callback = function(text)
    local Target = g.findplr(text)
    if not Target then g.notify("Error", "That is not a valid Player.", 3); return end
    local Target_Char = Target.Character or g.get_char(Target, 3)
    if not Target_Char then g.notify("Error", "Target character is not loaded.", 3); return end
    local Char = g.Character or g.LocalPlayer.Character or g.get_char(LocalPlayer, 3)
    if not Char then g.notify("Error", "Your Character does not exist.", 5); return end
    local Hum = g.Humanoid or Char:FindFirstChildOfClass("Humanoid") or g.get_human(LocalPlayer, 10)
    if not (Char and Hum) then g.notify("Error", "Your character is not loaded yet!", 3); return end
    if Hum.Sit then
        pcall(function() Hum:ChangeState(3) end)
        task.wait(0.2)
    end
    local Ok, Pivot = pcall(function() return Target_Char:GetPivot() end)
    if not Ok or not Pivot then g.notify("Error", "Failed to get target position.", 3); return end
    if Char and Char:FindFirstChildOfClass("Humanoid") then Char:PivotTo(Pivot * CFrame.new(0, 5, 0)) end
    g.notify("Success", "Teleported to "..Target.Name, 3)
end}, "Teleport_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "View Player",
PlaceholderText = "Username or displayname...",
Flag = "View_Player_Input_UI",
Callback = function(split)
    local View_Target = g.findplr(split)
    if not View_Target then g.notify("Error", "Target was not found or does not exist!", 5); return end
    if g.Viewing_A_Player then g.notify("Error", "You're already viewing someone, unview them first.", 5); return end
    local target_char = View_Target.Character or g.get_char(View_Target, 5)
    if not target_char then g.notify("Error", "Target character not loaded!", 5); return end
    local target_human = target_char:FindFirstChildOfClass("Humanoid") or g.get_human(View_Target, 5)
    if not target_human then g.notify("Error", "Target humanoid not found!", 5); return end
    g.Viewing_A_Player = true
    workspace.CurrentCamera.CameraSubject = target_human or target_char or g.Character
end}, "View_Player_Input_UI")

g.create_ui_element("Button", Players_Section, {
Name = "Unview Player",
Callback = function()
    if not g.Viewing_A_Player then g.notify("Error", "You're not viewing anyone.", 3); return end
    g.Viewing_A_Player = false
    workspace.CurrentCamera.CameraSubject = g.Humanoid or g.Character or g.LocalPlayer.Character or g.get_char(LocalPlayer, 10)
end})

g.main_vehicle_fly_UI_toggle = g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Vehicle Fly (YS)",
Default = g.vehicle_fly or false,
Flag = "Vehicle_Fly_Toggle_UI",
Callback = function(state)
    g.toggle_vehicle_fly(state)
end}, "Vehicle_Fly_Toggle_UI")

g.create_ui_element("Slider", Vehicle_Section, {
Name = "Vehicle Fly Speed",
Min = 1,
Max = 100,
Default = g.vehicle_fly_speed or 5,
Flag = "Vehicle_Fly_Speed",
Callback = function(val)
    if g.vehicle_fly then g.vehicle_fly_speed = val end
end}, "Vehicle_Fly_Speed")

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Anti Car Fling (YS)",
Default = g.VehicleDestroyer_Enabled or false,
Flag = "Anti_Car_Fling_Toggle_UI",
Callback = function(state)
    g.anti_car_fling(state)
end}, "Anti_Car_Fling_Toggle_UI")

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Auto Lock Car (YS)",
Default = g.AutoLockOn or false,
Flag = "Auto_Lock_Car_Toggle_UI",
Callback = function(state)
    if g.ToggleAutoLock then g.ToggleAutoLock(state) end
end}, "Auto_Lock_Car_Toggle_UI")

g.create_ui_element("Button", Vehicle_Section, {
Name = "Lock Car (YS)",
Callback = function()
    local Current_Car = g.get_vehicle()
    if not Current_Car then g.notify("Error", "You do not have a vehicle spawned!", 5); return end
    if Current_Car:GetAttribute("locked") == true then g.notify("Error", "Your Vehicle is already locked.", 5); return end
    g.lock_vehicle(g.get_vehicle())
    g.notify("Success", "Locked vehicle: " .. tostring(Current_Car), 5)
end,})

g.create_ui_element("Button", Vehicle_Section, {
Name = "Unlock Car (YS)",
Callback = function()
    local Current_Car = g.get_vehicle()
    if not Current_Car then g.notify("Error", "You do not have a vehicle spawned!", 5); return end
    if Current_Car:GetAttribute("locked") ~= true then g.notify("Error", "Your vehicle is already unlocked!", 5); return end
    g.lock_vehicle(g.get_vehicle())
    g.notify("Success", "Unlocked vehicle: " .. tostring(Current_Car), 5)
end,})

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Trailer (YS)",
Default = g.trailer_enabled or false,
Flag = "Trailer_Toggle_UI",
Callback = function(state)
    local Vehicle = g.get_vehicle()
    if not Vehicle then g.notify("Error", "You do not have a Vehicle spawned, spawn one and try again!", 7); return  end
    if state then
        g.notify("Success", "Added WaterSkies to Vehicle: " .. tostring(Vehicle), 5)
    else
        g.notify("Success", "Removed WaterSkies trailer from: " .. tostring(Vehicle), 5)
    end
    g.water_skie_trailer(state, g.get_vehicle())
end}, "Trailer_Toggle_UI")

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "View Car (YS)",
Default = g.viewing_car or false,
Flag = "View_Car_Toggle_UI",
Callback = function(state)
    if state then
        local Camera = g.Camera or workspace.CurrentCamera
        local Vehicle = g.get_vehicle()
        if not Vehicle then g.notify("Error", "You don't have a Vehicle spawned, spawn one and try again!", 7); return end
        local fallback = g.Humanoid or g.Character or g.get_human(g.LocalPlayer, Players.RespawnTime + 0.5) or g.get_char(g.LocalPlayer, Players.RespawnTime + 0.75)
        if not fallback then g.notify("Error", "No fallback camera subject found.", 5); return end
        if g.CamWatcherConn then
            g.CamWatcherConn:Disconnect()
            g.CamWatcherConn = nil
        end
        local function find_vehicle_part(v)
            return v:FindFirstChildWhichIsA("VehicleSeat", true)
                or v:FindFirstChildWhichIsA("Seat", true)
                or v:FindFirstChildWhichIsA("BasePart", true)
        end
        local target = find_vehicle_part(Vehicle)
        if not target then g.notify("Error", "Could not find a valid vehicle part.", 5); return end
        Camera.CameraSubject = target
        g.viewing_car = true
        g.notify("Info", "Now viewing Vehicle.", 5)
        g.CamWatcherConn = target.AncestryChanged:Connect(function()
            if not target:IsDescendantOf(workspace) then
                Camera.CameraSubject = fallback
                if g.CamWatcherConn then
                    g.CamWatcherConn:Disconnect()
                    g.CamWatcherConn = nil
                end
                g.viewing_car = false
                g.notify("Info", "Vehicle lost, camera reset.", 5)
            end
        end)
    else
        local Camera = g.Camera or workspace.CurrentCamera
        local function fallbackto()
            return g.Humanoid or g.Character or g.LocalPlayer.Character
        end
        if g.CamWatcherConn then
            g.CamWatcherConn:Disconnect()
            g.CamWatcherConn = nil
        end
        local fb = fallbackto()
        if fb then
            Camera.CameraSubject = fb
            g.notify("Info", "Camera now set back to your character.", 5)
        end
        g.viewing_car = false
    end
end}, "View_Car_Toggle_UI")

g.create_ui_element("Button", Vehicle_Section, {
Name = "Bring Vehicle To Me (YS)",
Callback = function()
    local Util = g.Util or require(g.ReplicatedStorage:FindFirstChild("Util", true))
    if not Util then g.notify("Error", "ModuleScript: 'Util' does not seem to exist.", 5); return end
    local function get_hrp()
        if g.HumanoidRootPart then return g.HumanoidRootPart end
        return g.Char.get_hrp()
    end
    local hrp = get_hrp()
    if not hrp then g.notify("Error", "Could not find HumanoidRootPart!", 3); return end
    local myVehicle = nil
    for _, v in ipairs(workspace:WaitForChild("Vehicles"):GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("owner") and v.owner.Value == Players.LocalPlayer then
            if v:FindFirstChild("VehicleSeat") then
                myVehicle = v
                break
            end
        end
    end
    if not myVehicle then g.notify("Error", "No owned vehicle found!", 3); return end
    local seat = myVehicle:FindFirstChild("VehicleSeat", true)
    local savedCF = hrp.CFrame
    if seat and g.Humanoid then
        g.Character:PivotTo(seat.CFrame)
        fw(0.2)
        seat:Sit(g.Humanoid)
    end
    fw(0.1)
    local targetCF = savedCF * CFrame.new(0, 10, 0)
    local tween = Util.tween_model(myVehicle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetCF)
    if tween then tween.Completed:Wait() end
    g.notify("Success", "Brought your Vehicle to you!", 5)
end,})

g.create_ui_element("Button", Vehicle_Section, {
Name = "Go To Vehicle (YS)",
Callback = function()
    local Vehicle = g.get_vehicle()
    if not Vehicle then g.notify("Error", "You do not have a vehicle spawned, spawn one and try again!", 5); return end
    if g.Character and g.Character:FindFirstChild("HumanoidRootPart") then
        g.Character:PivotTo(g.get_vehicle():GetPivot() * CFrame.new(0, 5, 0))
    end
end,})

g.create_ui_element("Input", Vehicle_Section, {
Name = "Teleport Car To Player (YS)",
PlaceholderText = "user or display...",
Flag = "TP_Car_To_Player_Input_UI",
Callback = function(split)
    local Vehicle = g.get_vehicle()
    if not Vehicle then g.notify("Error", "You do not have a vehicle spawned, spawn one and try again!", 5); return end
    local Goto_Player = g.findplr(split)
    if not Goto_Player then g.notify("Error", "Target player not found / does not exist / or has left the game.", 6); return end
    local Old_CFrame_TP_Car = g.Character:FindFirstChild("HumanoidRootPart").CFrame
    if Goto_Player and Goto_Player.Character and Goto_Player.Character:FindFirstChildWhichIsA("Humanoid") then
        local Target_Char = Goto_Player.Character or g.get_char(Goto_Player)
        if not Target_Char then return end
        local Target_CFrame = Target_Char and Target_Char:GetPivot() * CFrame.new(0, 5, 0)
        local myVehicle = nil

        for _, v in ipairs(g.Workspace.Vehicles:GetChildren()) do
            if v:IsA("Model") and v:FindFirstChild("owner") and v.owner.Value == g.LocalPlayer then
                if v:FindFirstChild("VehicleSeat") then
                    myVehicle = v
                    break
                end
            end
        end

        if not myVehicle then g.notify("Error", "No owned vehicle found.", 5); return end
        local seat = myVehicle:FindFirstChild("VehicleSeat")
        if seat and g.Humanoid then
            g.Character:PivotTo(seat.CFrame)
            fw(0.2)
            seat:Sit(g.Humanoid)
        end
        fw(0.1)
        myVehicle:PivotTo(Target_CFrame)
        fw(0.3)
        if g.Humanoid.Sit then
            g.Humanoid:ChangeState(3)
            fw(0.2)
            g.HumanoidRootPart.CFrame = Old_CFrame_TP_Car
        else
            g.HumanoidRootPart.CFrame = Old_CFrame_TP_Car
        end

        g.notify("Success", "Teleported vehicle to target player: " .. tostring(Goto_Player), 5)
    end
end}, "TP_Car_To_Player_Input_UI")

g.create_ui_element("Input", Vehicle_Section, {
Name = "Steal Car (YS)",
PlaceholderText = "user or display...",
Flag = "Steal_Car_Input_UI",
Callback = function(split)
    local take_vehicle_target_plr = g.findplr(split)
    if not take_vehicle_target_plr then g.notify("Error", "That Player does not exist, or has left the game.", 7); return end
    local plrs_spawned_vehicle = g.get_other_vehicle(take_vehicle_target_plr)
    if not plrs_spawned_vehicle then g.notify("Error", "That Player does not have a Vehicle spawned.", 6); return end
    if g.Character and g.Character.Parent and g.Character:FindFirstChild("HumanoidRootPart") then
        g.Character:PivotTo(plrs_spawned_vehicle:GetPivot() + Vector3.new(0, 3, 0))
    end
    fw(0.2)
    g.steal_car_functionality(take_vehicle_target_plr)
end}, "Steal_Car_Input_UI")

g.create_ui_element("Toggle", Vehicle_Section, {
Name = "Vehicle ESP",
Default = g.vehicle_esp_enabled or false,
Flag = "Vehicle_ESP_Toggle_UI",
Callback = function(state)
    g.vehicle_esp_toggle(state)
end}, "Vehicle_ESP_Toggle_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Orbit Player (YS)",
PlaceholderText = "user or display...",
Flag = "Orbit_Player_Input_UI",
Callback = function(split)
    local Target = g.findplr(split)
    if not Target then g.notify("Error", "Target doesn't exist or has left the game.", 5); return end
    if g.Is_Orbiting then g.notify("Warning", "You're already orbiting somebody.", 5); return end
    local speed = g.Orbit_Speed_Value or 1
    local distance = g.Orbit_Distance_Value or 5
    g.start_orbit_plr(Target, speed, distance)
end}, "Orbit_Player_Input_UI")

g.create_ui_element("Slider", Players_Section, {
Name = "Orbit Speed",
Min = 1,
Max = 75,
Default = g.Orbit_Speed_Value or 1,
Flag = "Orbit_Speed_Slider_UI",
Callback = function(val)
    g.Orbit_Speed_Value = val
    if g.Is_Orbiting then
        g.set_orbit_speed(val)
    end
end}, "Orbit_Speed_Slider_UI")

g.create_ui_element("Slider", Players_Section, {
Name = "Orbit Distance",
Min = 1,
Max = 75,
Default = g.Orbit_Distance_Value or 5,
Flag = "Orbit_Distance_Slider_UI",
Callback = function(val)
    g.Orbit_Distance_Value = val
end}, "Orbit_Distance_Slider_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Annoy Player (YS)",
PlaceholderText = "user or display...",
Flag = "Annoy_Player_Input_UI",
Callback = function(split)
    local Target = g.findplr(split)
    if not Target then g.notify("Error", "That Player does not exist or has left the game.", 7); return end
    if Target.Name == "Yadsan_Godverse" or Target.Name == "L0CKED_1N1" then return end
    if g.Currently_Running_Annoy_Loop then
        if g.Currently_Annoying_Player then
            g.notify("Error", "You are already annoying: " .. tostring(g.Currently_Annoying_Player) .. "!", 5)
            return
        else
            g.notify("Error", "You are already annoying a Player!", 5)
            return 
        end
    end

    local target_userid = Target.UserId
    local rejoin_limit = 60
    g.Currently_Annoying_Player = Target.Name
    g.annoy_active = true
    g.notify("Success", "Now annoying Player: " .. Target.Name, 7)
    local Annoy_Thread = task.spawn(function()
        while g.annoy_active == true do
            fw(0)
            local success = pcall(function()
                if not Target or not Target.Parent or not Target.Character then
                    local elapsed_time = 0
                    g.notify("Warning", "Target left, waiting 60 seconds for them to rejoin...", 12)
                    while elapsed_time < rejoin_limit and g.annoy_active == true do
                        local found_player = false
                        for _, plr in ipairs(g.Players:GetPlayers()) do
                            if plr.UserId == target_userid then
                                Target = plr
                                g.notify("Success", "Target rejoined, resuming annoyance loop!", 6)
                                found_player = true
                                break
                            end
                        end
                        if found_player then break end
                        fw(1)
                        elapsed_time += 1
                    end

                    if elapsed_time >= rejoin_limit then
                        g.annoy_active = false
                        g.Currently_Annoying_Player = nil
                        g.Currently_Running_Annoy_Loop = nil
                        g.notify("Warning", "Target did not rejoin within 60 seconds, loop disabled.", 10)
                        return 
                    end
                end

                g.Send("request_carry", Target)
                fw(0)
                g.Send("request_call", Target)
                fw(0)
                g.Send("end_call", Target)
            end)

            if not success then
                g.annoy_active = false
                g.Currently_Annoying_Player = nil
                g.Currently_Running_Annoy_Loop = nil
            end
        end

        g.Currently_Annoying_Player = nil
        g.Currently_Running_Annoy_Loop = nil
    end)
    g.Currently_Running_Annoy_Loop = Annoy_Thread
end}, "Annoy_Player_Input_UI")

g.create_ui_element("Button", Players_Section, {
Name = "UnAnnoy Player",
Callback = function() 
    if not g.annoy_active then g.notify("Warning", "Annoy Player is not running.", 5); return end
    g.annoy_active = false
    if g.Currently_Annoying_Player then g.Currently_Annoying_Player = nil end
    if g.Currently_Running_Annoy_Loop then g.Currently_Running_Annoy_Loop = nil end
    g.notify("Success", "Annoy loop disabled.", 5)
end,})

g.create_ui_element("Input", Players_Section, {
Name = "Loop Fling Player",
PlaceholderText = "user or display...",
Flag = "Loop_Fling_Input_UI",
Callback = function(split)
    local loop_fling_victim = g.findplr(split)
    if not loop_fling_victim then g.notify("Error", "That Player does not exist!", 3); return end
    if loop_fling_victim and loop_fling_victim.Character then
        g.start_loopfling(loop_fling_victim)
    end
end}, "Loop_Fling_Input_UI")

g.create_ui_element("Button", Players_Section, {
Name = "UnLoopfling Player",
Callback = function()
    g.stop_loopfling()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Tools Menu (Pistol + Laser) (YS)",
Callback = function()
    g.tools_menu_for_life_together_flames_hub()
end,})

g.create_ui_element("Input", Players_Section, {
Name = "Bring Player (YS)",
PlaceholderText = "user or display...",
Flag = "Bring_Player_Input_UI",
Callback = function(split)
    local target = g.findplr(split)
    if not target then g.notify("Error", "Target not found.", 5); return end
    if g.Not_Ever_Sitting then g.notify("Error", "Anti-Sit is enabled, turn it off first!", 5); return end
    local function wait_for_bus(timeout)
        local t = 0
        while t < timeout do
            for _, v in ipairs(g.Workspace.Vehicles:GetChildren()) do
                if v:IsA("Model") and v.Name == "SchoolBus" and v:FindFirstChild("owner") and v.owner.Value == g.LocalPlayer then
                    return v
                end
            end
            fw(0.2)
            t = t + 0.2
        end
        return nil
    end

    local Vehicle = g.get_vehicle()
    if not Vehicle or Vehicle.Name ~= "SchoolBus" then
        g.spawn_any_vehicle("SchoolBus")
        fw(0.5)
        Vehicle = wait_for_bus(5)
    end

    if Vehicle and Vehicle.Name == "SchoolBus" then
        g.vehicle_bring_player(target)
        g.notify("Success", "Bringing player: " .. target.Name, 3)
    else
        g.notify("Error", "Failed to spawn/find SchoolBus.", 3)
    end
end}, "Bring_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Kill Player (YS)",
PlaceholderText = "user or display...",
Flag = "Kill_Player_Input_UI",
Callback = function(split)
    local target = g.findplr(split)
    if not target then g.notify("Error", "Target not found.", 5); return end
    if g.Not_Ever_Sitting then g.notify("Error", "Anti-Sit is enabled, turn it off first!", 5); return end
    local function wait_for_bus(timeout)
        local t = 0
        while t < timeout do
            for _, v in ipairs(g.Workspace.Vehicles:GetChildren()) do
                if v:IsA("Model") and v.Name == "SchoolBus" and v:FindFirstChild("owner") and v.owner.Value == g.LocalPlayer then
                    return v
                end
            end
            fw(0.2)
            t = t + 0.2
        end
        return nil
    end

    local Vehicle = g.get_vehicle()
    if not Vehicle or Vehicle.Name ~= "SchoolBus" then
        g.spawn_any_vehicle("SchoolBus")
        fw(0.5)
        Vehicle = wait_for_bus(5)
    end

    if Vehicle and Vehicle.Name == "SchoolBus" then
        g.vehicle_kill_player(target)
        g.notify("Success", "Killing player: "..tostring(target.Name), 3)
    else
        g.notify("Error", "Failed to spawn/find SchoolBus.", 3)
    end
end}, "Kill_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Void Player (YS)",
PlaceholderText = "user or display...",
Flag = "Void_Player_Input_UI",
Callback = function(split)
    local target = g.findplr(split)
    if not target then g.notify("Error", "Target Player not found.", 5); return end
    if g.Not_Ever_Sitting then g.notify("Error", "Anti-Sit is enabled, turn it off first!", 5); return end
    local function wait_for_bus(timeout)
        local t = 0
        while t < timeout do
            for _, v in ipairs(g.Workspace.Vehicles:GetChildren()) do
                if v:IsA("Model") and v.Name == "SchoolBus" and v:FindFirstChild("owner") and v.owner.Value == g.LocalPlayer then
                    return v
                end
            end
            fw(0.2)
            t = t + 0.2
        end
        return nil
    end

    local Vehicle = g.get_vehicle()
    if not Vehicle or Vehicle.Name ~= "SchoolBus" then
        g.spawn_any_vehicle("SchoolBus")
        fw(0.5)
        Vehicle = wait_for_bus(5)
    end

    if Vehicle and Vehicle.Name == "SchoolBus" then
        g.vehicle_void_player(target)
        g.notify("Success", "Sending player to the Void | player: " .. target.Name, 3)
    else
        g.notify("Error", "Failed to spawn/find SchoolBus.", 3)
    end
end}, "Void_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Skydive Player (YS)",
PlaceholderText = "user or display...",
Flag = "Skydive_Player_Input_UI",
Callback = function(split)
    local target = g.findplr(split)
    if not target then g.notify("Error", "Target not found.", 5); return end
    if g.Not_Ever_Sitting then g.notify("Error", "Anti-Sit is enabled, turn it off first!", 5); return end
    local function wait_for_bus(timeout)
        local t = 0
        while t < timeout do
            for _, v in ipairs(g.Workspace.Vehicles:GetChildren()) do
                if v:IsA("Model") and v.Name == "SchoolBus" and v:FindFirstChild("owner") and v.owner.Value == g.LocalPlayer then
                    return v
                end
            end
            fw(0.2)
            t = t + 0.2
        end
        return nil
    end

    local Vehicle = g.get_vehicle()
    if not Vehicle or Vehicle.Name ~= "SchoolBus" then
        g.spawn_any_vehicle("SchoolBus")
        fw(0.5)
        Vehicle = wait_for_bus(5)
    end

    if Vehicle and Vehicle.Name == "SchoolBus" then
        g.vehicle_skydive_player(target)
        g.notify("Success", "Skydiving player: " .. target.Name, 3)
    else
        g.notify("Error", "Failed to spawn/find SchoolBus.", 3)
    end
end}, "Skydive_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Copy Avatar (YS)",
Description = "Copies the target players entire avatar (YS).",
PlaceholderText = "user or display...",
Flag = "Copy_Avatar_Input_UI",
Callback = function(split)
    local Target = g.findplr(split)
    if not Target then g.notify("Error", "That player doesn't exist in this game!", 5); return end
    if g.is_copying_avatar_already_flames then g.notify("Warning", "Copy avatar is already running!, wait a moment, until it's done.", 5); return end
    if Target.Name == "Yadsan_Godverse" or Target.Name == "L0CKED_1N1" then g.notify("Error", "You can't copy this player's avatar!", 5); return end
    g.copy_plr_avatar(Target)
end}, "Copy_Avatar_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Copy Player Emote (YS)",
PlaceholderText = "user or display...",
Flag = "Copy_Emote_Input_UI",
Callback = function(split)
    local target_plr = g.findplr(split)
    if not target_plr then g.notify("Error", "Player not found or does not exist.", 5); return end
    g.copy_emote_plr(target_plr)
end}, "Copy_Emote_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Check Premium",
PlaceholderText = "user or display...",
Flag = "Check_Premium_Input_UI",
Callback = function(split)
    local Player = g.findplr(split)
    if not Player then g.notify("Error", "Player doesn't exist or left the game.", 5); return end
    local Result = g.check_premium_player(Player)
    if Result == true then
        g.notify("Success", "[Result]: " .. tostring(Player.Name) .. " does have premium!", 6); return
    elseif Result == false then
        g.notify("Success", "[Result]: " .. tostring(Player.Name) .. " does not have premium.", 6); return
    else
        g.notify("Error", "Something unexpectedly happened while checking Player.", 5); return
    end
end}, "Check_Premium_Input_UI")

g.create_ui_element("Input", LocalPlayer_Section, {
Name = "WalkSpeed (YS)",
PlaceholderText = "Enter walkspeed...",
Flag = "Speed_Input_UI",
Callback = function(split)
    local New_Val = tonumber(split) or 16
    if not g.Humanoid then g.notify("Warning", "Wait until you respawn (or reset), we think you're dead, Humanoid is missing.", 10); return end
    if g.Humanoid.WalkSpeed == New_Val then g.notify("Warning", "Your WalkSpeed is already: " .. tostring(New_Val), 5); return end
    g.change_property("WalkSpeed", New_Val)
    g.notify("Success", "Updated WalkSpeed to: " .. tostring(New_Val), 5)
end}, "Speed_Input_UI")

g.create_ui_element("Input", LocalPlayer_Section, {
Name = "Jump Height (YS)",
PlaceholderText = "Enter jump height...",
Flag = "Jump_Height_Input_UI",
Callback = function(split)
    local New_ValJP = tonumber(split) or 7
    if not g.Humanoid then g.notify("Warning", "Wait until you respawn (or reset), we think you're dead, Humanoid is missing.", 10); return end
    if g.Humanoid.JumpPower == New_ValJP then g.notify("Warning", "Your JumpPower is already: " .. tostring(New_ValJP), 5); return end
    g.change_property("JumpHeight", New_ValJP)
    g.notify("Success", "Updated JumpHeight to: " .. tostring(New_ValJP), 5)
end}, "Jump_Height_Input_UI")

g.create_ui_element("Input", LocalPlayer_Section, {
Name = "Gravity (YS)",
PlaceholderText = "Enter gravity value...",
Flag = "Gravity_Input_UI",
Callback = function(split)
    local New_Grav = tonumber(split) or 196
    if g.Workspace.Gravity == New_Grav then g.notify("Warning", "Gravity is already: " .. tostring(New_Grav), 5); return end
    g.change_gravity_val(New_Grav)
    g.notify("Success", "Updated Gravity to: "..tostring(New_Grav), 5)
end}, "Gravity_Input_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Noclip (YS)",
Default = g.Noclip_Enabled or false,
Flag = "Noclip_Toggle_UI",
Callback = function(state)
    if state then
        if g.Noclip_Connection then g.notify("Warning", "Noclip connection is active, disable Noclip and try again.", 6); return end
        g.Toggleable_Noclip(true)
    else
        if not g.Noclip_Enabled then g.notify("Error", "Noclip is not enabled, enable it first.", 5); return end
        g.Toggleable_Noclip(false)
    end
end}, "Noclip_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Invisible (YS)",
Default = g.is_invisible_script_toggled or false,
Flag = "Invisible_Toggle_UI",
Callback = function(state)
    if state then
        if g.is_invisible_script_toggled then g.notify("Warning", "You're already Invisible.", 5); return end
        g.set_invisible(true)
    else
        if not g.is_invisible_script_toggled then g.notify("Warning", "You're not currently Invisible.", 5); return end
        g.set_invisible(false)
    end
end}, "Invisible_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Float (YS)",
Default = g.Float_Running_In_Flames_Hub or false,
Flag = "Float_Toggle_UI",
Callback = function(state)
    if state then
        g.start_flames_float()
    else
        g.stop_flames_float()
    end
end}, "Float_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Spin (YS)",
Default = g.already_spinning_localplr or false,
Flag = "Spin_Toggle_UI",
Callback = function(state)
    if state then
        local speed = g.Spin_Speed_Value or 5
        g.spin_plr(true, speed)
    else
        g.spin_plr(false)
    end
end}, "Spin_Toggle_UI")

g.create_ui_element("Slider", LocalPlayer_Section, {
Name = "Spin Speed",
Min = 1,
Max = 100,
Default = g.Spin_Speed_Value or 5,
Flag = "Spin_Speed_Slider_UI",
Callback = function(val)
    g.Spin_Speed_Value = val
    if g.already_spinning_localplr then g.change_spin_speed(val) end
end}, "Spin_Speed_Slider_UI")

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Cover Map With Your Avatar (YS)",
Callback = function()
    g.size_func_setter(85, 85)
end,})

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Reset Size (YS)",
Callback = function()
    g.size_func_setter(1, 1)
end,})

g.create_ui_element("Input", LocalPlayer_Section, {
Name = "Size Character (YS)",
PlaceholderText = "Enter size...",
Flag = "Size_Input_UI",
Callback = function(split)
    local new_size = split
    if not new_size then return end
    g.height_func_setter(new_size)
end}, "Size_Input_UI")

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Normal Size (YS)",
Callback = function()
    pcall(function()
        g.reset_to_original_height()
    end)
end}, "Normal_Size_Button_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Flash Name (YS)",
Default = g.Flashing_Name_Title or false,
Flag = "Flash_Name_Toggle_UI",
Callback = function(state)
    if state then
        if g.Flashing_Name_Title then g.notify("Error", "You're already running Flash Name!", 5); return end
        g.flashy_name(true)
        g.notify("Success", "Flash Name is now enabled.", 5)
    else
        if not g.Flashing_Name_Title then g.notify("Error", "You're not currently running Flash Name!", 5); return end
        g.flashy_name(false)
        g.notify("Success", "Flash Name is now disabled.", 5)
    end
end}, "Flash_Name_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Flash Invisible (YS)",
Default = g.Invisible_Flash or false,
Flag = "Flash_Invis_Toggle_UI",
Callback = function(state)
    if state then
        if g.LocalPlayer:GetAttribute("is_verified") == false then g.notify("Error", "You do not have LifePay premium for this (will not be FE without it).", 10); return end
        fw(0.2)
        local Is_Invis = g.InvisibleMode.enabled.get()
        g.Invisible_Flash = true
        if Is_Invis then g.InvisibleMode.enabled.set(false) end
        fw(0.1)
        FlamesLibrary.spawn("flames_flash_invis", "spawn", function()
            while g.Invisible_Flash == true do
                g.InvisibleMode.enabled.set(true)
                fw(0.05)
                g.InvisibleMode.enabled.set(false)
                fw(0.05)
            end
            g.InvisibleMode.enabled.set(false)
        end)
    else
        g.Invisible_Flash = false
        FlamesLibrary.disconnect("flames_flash_invis")
    end
end}, "Flash_Invis_Toggle_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "Night Vision",
Default = g.NightVisionEnabled or false,
Flag = "Night_Vision_Toggle_UI",
Callback = function(state)
    g.night_vision(state)
end}, "Night_Vision_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Anti Fling",
Default = g.afEnabled or false,
Flag = "Anti_Fling_Toggle_UI",
Callback = function(state)
    if state then
        if g.afEnabled then g.notify("Warning", "Anti-Fling is already enabled!", 5); return end
        g.Toggle_AntiFling_Boolean_Func(true)
        g.ToggleNoclip(true)
        g.hasSeen_AntiFling_WarningPrompt = true
        g.notify("Success", "Successfully enabled Anti-Fling.", 9)
    else
        if not g.afEnabled then g.notify("Error", "Anti-Fling is not enabled.", 5); return end
        g.Toggle_AntiFling_Boolean_Func(false)
        g.ToggleNoclip(false)
    end
end}, "Anti_Fling_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Anti Void",
Default = g.Anti_Void_Enabled_Bool or false,
Flag = "Anti_Void_Toggle_UI",
Callback = function(state)
    g.anti_void(state)
end}, "Anti_Void_Toggle_UI")

g.create_ui_element("Button", Houses_Section, {
Name = "Delete House (YS)",
Callback = function()
    g.Delete_House()
end,})

g.create_ui_element("Toggle", Houses_Section, {
Name = "Anti House Ban (YS)",
Default = g.never_banned_houses or false,
Flag = "Anti_House_Ban_Toggle_UI",
Callback = function(state)
    if state then
        if g.never_banned_houses or g.AntiTeleport then g.notify("Error", "AntiHouseBan / AntiTeleport is already enabled.", 6); return end
        local lib = g.FlamesLibrary
        g.never_banned_houses = true
        g.AntiTeleport = true
        local LocalPlayer = g.LocalPlayer or Players.LocalPlayer
        local Character = g.Character or LocalPlayer.Character or g.get_char(LocalPlayer, 3)
        local HRP = g.HumanoidRootPart or Character and Character:FindFirstChild("HumanoidRootPart") or g.get_root(LocalPlayer, 3)
        local safe_cframe = HRP.CFrame
        local last_position = HRP.Position
        local latch_until = 0
        local function rebind()
            Character = g.Character or LocalPlayer.Character or g.get_char(LocalPlayer, 3)
            HRP = g.HumanoidRootPart or Character and Character:FindFirstChild("HumanoidRootPart") or g.get_root(LocalPlayer, 3)
            if not HRP then return end
            safe_cframe = HRP.CFrame
            last_position = HRP.Position
            latch_until = 0
        end
        lib.connect("AntiHouseBan_CharAdded", LocalPlayer.CharacterAdded:Connect(function()
            fw(0.1)
            rebind()
        end))
        lib.connect("AntiHouseBan_Heartbeat", RunService.Heartbeat:Connect(function()
            if not g.AntiTeleport then return end
            if not HRP or not HRP.Parent then return end
            local now = os.clock()
            local current_position = HRP.Position
            local delta = (current_position - last_position).Magnitude
            if delta > 12 then
                latch_until = now + 0.4
                HRP.CFrame = safe_cframe
                last_position = safe_cframe.Position
            elseif latch_until > now then
                HRP.CFrame = safe_cframe
                last_position = safe_cframe.Position
            else
                safe_cframe = HRP.CFrame
                last_position = HRP.Position
            end
        end))
        if g.PlotAreas then
            lib.spawn("AntiHouseBan_PlotLoop", "spawn", function()
                while g.never_banned_houses == true do
                    fw()
                    for _, v in ipairs(g.PlotAreas) do
                        if v then v.CanCollide = false end
                    end
                end
            end)
        else
            lib.disconnect("AntiHouseBan_CharAdded")
            lib.disconnect("AntiHouseBan_Heartbeat")
            g.never_banned_houses = false
            g.AntiTeleport = false
            g.notify("Error", "PlotAreas missing or patched.", 10); return
        end
        g.notify("Success", "Yadsan Hub | Anti-House-Ban V2 is now enabled.", 7)
    else
        if not g.never_banned_houses and not g.AntiTeleport then g.notify("Warning", "AntiHouseBan is not enabled.", 5); return end
        local lib = g.FlamesLibrary
        lib.disconnect("AntiHouseBan_CharAdded")
        lib.disconnect("AntiHouseBan_Heartbeat")
        lib.disconnect("AntiHouseBan_PlotLoop")
        g.never_banned_houses = false
        g.AntiTeleport = false
        g.notify("Success", "Yadsan Hub | Anti-House-Ban V2 is now disabled.", 7)
    end
end}, "Anti_House_Ban_Toggle_UI")

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Set SpawnPoint",
Callback = function()
    g.set_spawnpoint(0.1)
end}, "Set_Spawnpoint_Button_UI")

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Clear SpawnPoint",
Callback = function()
    g.clear_spawnpoint()
end}, "Clear_Spawnpoint_Button_UI")

g.create_ui_element("Button", Extras_Section, {
Name = "Rejoin",
Callback = function()
    local PlaceID = game.PlaceId
    local JobID = game.JobId
    local function safe_teleport()
        local success, err = pcall(function()
            if #g.Players:GetPlayers() <= 1 then
                g.notify("Success", "You are now going to rejoin into a different server (this server is empty).", 10)
                wait(0.25)
                g.TeleportService:Teleport(PlaceID, g.LocalPlayer)
            else
                g.notify("Success", "You are now being rejoined.", 5)
                wait(0.25)
                g.TeleportService:TeleportToPlaceInstance(PlaceID, JobID, g.LocalPlayer)
            end
        end)
        if not success then
            g.notify("Error", "Teleporting failed: " .. tostring(err) .. " | going to re-try.", 15)
            fw(3)
            safe_teleport()
        end
    end
    safe_teleport()
end}, "Rejoin_Button_UI")

g.create_ui_element("Button", Extras_Section, {
Name = "YouTube Music Player (MIGHT CRASH/FREEZE YOU!)",
Callback = function()
    g.load_youtube_music_player_func()
end})

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Anti Sit",
Default = g.Not_Ever_Sitting or false,
Flag = "Anti_Sit_Toggle_UI",
Callback = function(state)
    g.anti_sit_func(state)
end}, "Anti_Sit_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Walk Fling (YS)",
Default = g.walkflinging or false,
Flag = "Walk_Fling_Toggle_UI",
Callback = function(state)
    if state then
        local fn = g.FlamesLibrary.safe_func(g.StartWalkFling)
        fn()
    else
        local fn = g.FlamesLibrary.safe_func(g.StopWalkFling)
        fn()
    end
end}, "Walk_Fling_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Name Spam (YS)",
Default = g.Name_Spammer_Currently_Enabled or false,
Flag = "Name_Spam_Toggle_UI",
Callback = function(state)
    g.name_changer_premium(state)
end}, "Name_Spam_Toggle_UI")

g.create_ui_element("Toggle", Phone_Section, {
Name = "Block Calls (YS)",
Default = g.Auto_Calls_Blocker_V3_Is_Enabled_Boolean_Flag or false,
Flag = "Block_Calls_Toggle_UI",
Callback = function(state)
    if state then
        if g.Auto_Calls_Blocker_V3_Is_Enabled_Boolean_Flag then g.notify("Warning", "You already have Calls_Blocker_V3 enabled!", 5); return end
        g.notify("Success", "Calls_Blocker_V3 has been enabled.", 5)
        g.Auto_Calls_Blocker_V3_Is_Enabled_Boolean_Flag = true
        g.FlamesLibrary.spawn("calls_blocker", "spawn", function()
            local net = g.Net
            local incoming_hook
            local emergency_hook
            incoming_hook = net.hook("incoming_call", function(plr)
                pcall(function()
                    g.Send("end_call", plr)
                end)
                return false
            end)
            emergency_hook = net.hook("incoming_emergency_call", function(plr)
                pcall(function()
                    g.Send("end_call", plr)
                end)
                return false
            end)
            g.calls_blocker_hooks = {
                incoming = incoming_hook,
                emergency = emergency_hook
            }
            while g.FlamesLibrary.is_alive("calls_blocker") do
                fw(1)
            end
        end)
    else
        if not g.Auto_Calls_Blocker_V3_Is_Enabled_Boolean_Flag then g.notify("Warning", "You do NOT have Calls_Blocker_V3 enabled!", 5); return end
        if g.calls_blocker_hooks then
            for _, v in pairs(g.calls_blocker_hooks) do
                pcall(function()
                    if typeof(v) == "RBXScriptConnection" then
                        v:Disconnect()
                    elseif type(v) == "function" then
                        v()
                    end
                end)
            end
            g.calls_blocker_hooks = nil
        end
        g.Auto_Calls_Blocker_V3_Is_Enabled_Boolean_Flag = false
        g.FlamesLibrary.disconnect("calls_blocker")
        g.notify("Success", "Calls_Blocker_V3 has been disabled.", 5)
    end
end}, "Block_Calls_Toggle_UI")

g.create_ui_element("Slider", LocalPlayer_Section, {
Name = "Fly Speed",
Min = 1,
Max = 200,
Default = g.Fly_Speed_Value or 5,
Flag = "Fly_Speed_Slider_UI",
Callback = function(val)
    g.Fly_Speed_Value = val
end}, "Fly_Speed_Slider_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Fly (YS)",
Default = g.FlyEnabled or false,
Flag = "Fly_Toggle_UI",
Callback = function(state)
    if state then
        if g.FlyEnabled then g.notify("Error", "Fly is already enabled!", 5); return end
        if g.Enabled_Flying then g.notify("Error", "Another fly is already enabled!", 5); return end
        local speed = g.Fly_Speed_Value or nil
        g.EnableFly(true, speed)
        g.notify("Warning", "E = up, Q = down, WASD to move.", 3)
    else
        g.DisableFly()
    end
end}, "Fly_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Fly 2 - Magic Carpet (YS)",
Default = g.Enabled_Flying or false,
Flag = "Fly2_Toggle_UI",
Callback = function(state)
    if state then
        if g.Enabled_Flying then g.notify("Error", "Fly-2 is already enabled!", 5); return end
        if g.FlyEnabled then g.notify("Error", "Fly-1 is already enabled, disable it first.", 6); return end
        local speed = g.Fly_Speed_Value or nil
        g.EnableFly2(speed)
        g.notify("Info", "Space = up, Shift = down, WASD to move.", 3)
    else
        g.DisableFly2()
    end
end}, "Fly2_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Fly 3 - Adonis (YS)",
Default = g.AdonisAdminFlyEnabled or false,
Flag = "Fly3_Toggle_UI",
Callback = function(state)
    if state then
        if g.Enabled_Flying then g.notify("Error", "Fly-2 is already enabled, disable it first.", 5); return end
        if g.FlyEnabled then g.notify("Error", "Fly-1 is already enabled, disable it first.", 6); return end
        local speed = g.Fly_Speed_Value or nil
        if speed then g.SetAdonisFlySpeed(speed) end
        g.notify("Info", "E = up, Q = down, WASD to move.", 5)
        g.StartAdonisAdminFlyScript()
    else
        g.Stop_Fly_3_Function()
    end
end}, "Fly3_Toggle_UI")

g.create_ui_element("Input", Vehicle_Section, {
Name = "Car Max Speed (YS)",
PlaceholderText = "Enter number...",
Flag = "Car_Speed_Input_UI",
Callback = function(split)
    local Vehicle = g.get_vehicle()
    local Hum = g.in_humanoid_vehicle(g.LocalPlayer)
    local Hum_Vehicle_Name = g.hum_vehicle_name(g.LocalPlayer)
    local n = tonumber(split)
    if not n then g.notify("Warning", "Enter a valid number!", 3); return end
    if Hum and Hum_Vehicle_Name then
        g.set_hum_vehicle_speed(n)
        g.notify("Success", "Set HumanoidVehicle: " .. tostring(Hum_Vehicle_Name) .. "'s speed to: " .. tostring(n), 5); return
    end
    if Vehicle and Vehicle:GetAttribute("max_speed") ~= nil then
        Vehicle:SetAttribute("max_speed", n)
        g.notify("Success", "Set Vehicle: " .. tostring(Vehicle) .. "'s speed to: " .. tostring(n), 5); return
    end
    g.notify("Error", "No car or humanoid vehicle found.", 5)
end}, "Car_Speed_Input_UI")

g.create_ui_element("Input", Vehicle_Section, {
Name = "Car Max Accel (YS)",
PlaceholderText = "Enter number...",
Flag = "Car_Accel_Input_UI",
Callback = function(split)
    local val = tonumber(split)
    if not val then g.notify("Warning", "Usage: enter a valid number.", 5); return end
    local car = g.get_vehicle()
    local humcar = g.in_humanoid_vehicle(g.LocalPlayer)
    if humcar then
        g.set_hum_vehicle_speed(val)
    elseif car and car:GetAttribute("max_acc") then
        car:SetAttribute("max_acc", val)
        g.notify("Success", "Set car max_acc to: " .. val, 5)
    else
        g.notify("Error", "Could not find car or humanoid vehicle.", 10)
    end
end}, "Car_Accel_Input_UI")

g.create_ui_element("Input", Vehicle_Section, {
Name = "Car Accel 0-60 (YS)",
PlaceholderText = "Enter number...",
Flag = "Car_Accel_060_Input_UI",
Callback = function(split)
    local val = tonumber(split)
    if not val then g.notify("Warning", "Enter a valid number.", 3); return end
    local car = g.get_vehicle()
    local humcar = g.in_humanoid_vehicle(g.LocalPlayer)
    if humcar then
        g.set_hum_vehicle_speed(val)
    elseif car and car:GetAttribute("acc_0_60") then
        car:SetAttribute("acc_0_60", val)
        g.notify("Success", "Set car acc_0_60 to: " .. val, 4)
    else
        g.notify("Error", "Could not find car or humanoid vehicle.", 10)
    end
end}, "Car_Accel_060_Input_UI")

g.create_ui_element("Input", Vehicle_Section, {
Name = "Car Turn Angle (YS)",
PlaceholderText = "Enter number...",
Flag = "Car_Turn_Angle_Input_UI",
Callback = function(split)
    local val = tonumber(split)
    if not val then g.notify("Warning", "Enter a valid number.", 3); return end
    local car = g.get_vehicle()
    local humcar = g.in_humanoid_vehicle(g.LocalPlayer)
    if humcar then
        g.set_hum_vehicle_speed(val)
    elseif car and car:GetAttribute("turn_angle") then
        car:SetAttribute("turn_angle", val)
        g.notify("Success", "Set car turn_angle to: " .. tostring(val), 5)
    else
        g.notify("Error", "Could not find car or humanoid vehicle.", 10)
    end
end}, "Car_Turn_Angle_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Rainbow Car (YS)",
PlaceholderText = "Username or displayname...",
Flag = "Rainbow_Car_Input_UI",
Callback = function(split)
    local Player_To_RGB_Car = g.findplr(split)
    if not Player_To_RGB_Car then g.notify("Error", "Player does not exist!", 3); return end
    if not g.get_other_vehicle(Player_To_RGB_Car) then g.notify("Error", "Player does not have a Vehicle spawned!", 5); return end
    local checker = g.check_friend(Player_To_RGB_Car)
    if not checker or checker ~= true then g.notify("Error", "Player is not your friend, add them to use this!", 5); return end
    if g.FlamesLibrary.is_alive("rainbow_car_" .. Player_To_RGB_Car.Name) then g.notify("Error", "Player already has their car rainbow!", 5); return end
    local colors = {
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(128, 128, 128),
        Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 255),
        Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 255, 255),
        Color3.fromRGB(255, 165, 0), Color3.fromRGB(139, 69, 19),
        Color3.fromRGB(255, 255, 0), Color3.fromRGB(50, 205, 50),
        Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 155, 172),
        Color3.fromRGB(128, 0, 128),
    }
    local thread_name = "rainbow_car_" .. Player_To_RGB_Car.Name
    g.FlamesLibrary.spawn(thread_name, "spawn", function()
        while g.FlamesLibrary.is_alive(thread_name) do
            fw(0.2)
            local current_plr = g.Players:FindFirstChild(Player_To_RGB_Car.Name)
            if not current_plr then
                g.FlamesLibrary.disconnect(thread_name)
                g.notify("Error", "Player must have left the game.", 5)
                return
            end
            for _, color in ipairs(colors) do
                if not g.FlamesLibrary.is_alive(thread_name) then break end
                fw(0.2)
                g.change_vehicle_color(color, g.get_other_vehicle(current_plr))
            end
        end
    end)
    g.notify("Success", "Rainbow car enabled for: " .. Player_To_RGB_Car.Name, 5)
end}, "Rainbow_Car_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Stop Rainbow Car (YS)",
PlaceholderText = "Username or displayname...",
Flag = "Stop_Rainbow_Car_Input_UI",
Callback = function(split)
    local Player_To_RGB_Car_Stop = g.findplr(split)
    if not Player_To_RGB_Car_Stop then g.notify("Error", "Player does not exist!", 5); return end
    if not g.get_other_vehicle(Player_To_RGB_Car_Stop) then g.notify("Error", "Player does not have a Vehicle spawned!", 5); return end
    local checker = g.check_friend(Player_To_RGB_Car_Stop) or Player_To_RGB_Car_Stop:IsFriendsWith(g.LocalPlayer.UserId)
    if checker ~= true then g.notify("Error", "Player is not your friend, add them to use this!", 5) end
    local thread_name = "rainbow_car_" .. Player_To_RGB_Car_Stop.Name
    if not g.FlamesLibrary.is_alive(thread_name) then g.notify("Warning", "This Player does not have Rainbow Vehicle enabled.", 6); return end
    g.FlamesLibrary.disconnect(thread_name)
    g.disable_rgb_for(Player_To_RGB_Car_Stop)
    g.notify("Success", "Disabled Rainbow Vehicle for: " .. Player_To_RGB_Car_Stop.Name, 5)
end}, "Stop_Rainbow_Car_Input_UI")

g.create_ui_element("Button", Houses_Section, {
Name = "Lock Home (YS)",
Callback = function()
    local is_locked = g.is_home_locked(g.LocalPlayer)
    if is_locked == true then
        g.notify("Warning", "Your home is already locked.", 5)
        return 
    elseif is_locked == false then
        g.toggle_house_lock(g.LocalPlayer)
        g.notify("Success", "Locked your home.", 5)
    else
        g.notify("Error", "Something unexpected happened while checking if House is locked.", 10)
    end
end}, "Lock_Home_Button_UI")

g.create_ui_element("Button", Houses_Section, {
Name = "Unlock Home (YS)",
Callback = function()
    local is_locked = g.is_home_locked(g.LocalPlayer)
    if is_locked == false then
        g.notify("Warning", "Your home is not locked.", 5)
        return 
    elseif is_locked == true then
        g.toggle_house_lock(g.LocalPlayer)
        g.notify("Success", "Unlocked your home.", 5)
    else
        g.notify("Error", "Something unexpected happened while checking if House is locked.", 10)
    end
end}, "Unlock_Home_Button_UI")

g.create_ui_element("Toggle", Houses_Section, {
Name = "Auto Lock Home (YS)",
Default = g.LockHomeLoop or false,
Flag = "Auto_Lock_Home_Toggle_UI",
Callback = function(state)
    g.keep_home_locked(state)
end}, "Auto_Lock_Home_Toggle_UI")

g.create_ui_element("Input", Houses_Section, {
Name = "Lock Player Home (YS)",
PlaceholderText = "Username or displayname...",
Flag = "Lock_Player_Home_Input_UI",
Callback = function(split)
    local plr_to_lock = g.findplr(split)
    if not plr_to_lock then g.notify("Error", "Player not found or does not exist.", 5); return end
    if not plr_to_lock:IsFriendsWith(g.LocalPlayer.UserId) then g.notify("Error", "You must be friends with the player to lock their House!", 10); return end
    local is_locked = g.is_home_locked(plr_to_lock)
    if is_locked == true then
        g.notify("Warning", tostring(plr_to_lock) .. "'s home is already locked.", 5)
        return 
    elseif is_locked == false then
        g.toggle_house_lock(plr_to_lock)
        g.notify("Success", "Locked: " .. tostring(plr_to_lock) .. "'s home.", 5)
    else
        g.notify("Error", "Something happened while trying to lock: " .. tostring(plr_to_lock) .. "'s home!", 10)
    end
end}, "Lock_Player_Home_Input_UI")

g.create_ui_element("Input", Houses_Section, {
Name = "Unlock Player Home (YS)",
PlaceholderText = "Username or displayname...",
Flag = "Unlock_Player_Home_Input_UI",
Callback = function(split)
    local plr_to_unlock = g.findplr(split)
    if not plr_to_unlock then g.notify("Error", "Player not found or does not exist.", 5); return end
    if not plr_to_unlock:IsFriendsWith(g.LocalPlayer.UserId) then g.notify("Error", "You must be friends with the player to unlock their House!", 10); return end
    local is_locked = g.is_home_locked(plr_to_unlock)
    if is_locked == false then
        g.notify("Warning", tostring(plr_to_unlock) .. "'s home is not locked.", 5)
        return
    elseif is_locked == true then
        g.toggle_house_lock(plr_to_unlock)
        g.notify("Success", "Unlocked: " .. tostring(plr_to_unlock) .. "'s home.", 5)
    else
        g.notify("Error", "Something happened while trying to unlock: " .. tostring(plr_to_unlock) .. "'s home!", 10)
    end
end}, "Unlock_Player_Home_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Friend Player",
PlaceholderText = "user or display...",
Flag = "Friend_Player_Input_UI",
Callback = function(split)
    local target_friend_plr = g.findplr(split)
    if not target_friend_plr then g.notify("Error", "That player does not exist or has left the game.", 6); return end
    g.friend_user_async_function(target_friend_plr)
end}, "Friend_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Unfriend Player",
PlaceholderText = "user or display...",
Flag = "Unfriend_Player_Input_UI",
Callback = function(split)
    local target_unfriend_plr = g.findplr(split)
    if not target_unfriend_plr then g.notify("Error", "That player does not exist or has left the game.", 6); return end
    g.unfriend_user_async(target_unfriend_plr)
end}, "Unfriend_Player_Input_UI")

if executor_contains("delta") then
    g.create_ui_element("Toggle", Home_Section, {
    Name = "Toggle Delta Icon",
    Default = g.Is_Deltas_Icon_Currently_Toggled or false,
    Flag = "Hide_Delta_Toggle_UI",
    Callback = function(state)
        g.toggle_delta_image_button_flames_hub(not state)
    end}, "Hide_Delta_Toggle_UI")
end

g.create_ui_element("Toggle", Phone_Section, {
Name = "Anti RGB Phone",
Default = g.HidePhoneModels or false,
Flag = "Anti_RGB_Phone_Toggle_UI",
Callback = function(state)
    if state then
        if g.HidePhoneModels then g.notify("Warning", "Anti RGB Phone is already enabled.", 5); return end
        g.notify("Success", "Enabled Anti RGB Phone.", 5)
        g.TogglePhoneModelHider(true)
    else
        if not g.HidePhoneModels then g.notify("Warning", "Anti RGB Phone is not enabled.", 5); return end
        g.notify("Success", "Disabled Anti RGB Phone.", 5)
        g.TogglePhoneModelHider(false)
    end
end}, "Anti_RGB_Phone_Toggle_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "FPS Boost",
Default = g.ultimate_lag_reducer or false,
Flag = "FPS_Boost_Toggle_UI",
Callback = function(state)
    g.FlamesLagReducerFunc(state)
end}, "FPS_Boost_Toggle_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "Always Show Titles",
Default = g.always_show_title_above_head or false,
Flag = "Always_Show_Titles_Toggle_UI",
Callback = function(state)
    g.always_show_title_of_player_regardless_of_chats(state)
end}, "Always_Show_Titles_Toggle_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "RGB Skin (YS)",
Default = g.rainbow_skintone_currently_enabled or false,
Flag = "RGB_Skin_Toggle_UI",
Callback = function(state)
    g.rainbow_skin(state)
end}, "RGB_Skin_Toggle_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "RGB Tool (YS)",
Default = g.Rainbow_Tools_FE or false,
Flag = "RGB_Tool_Toggle_UI",
Callback = function(state)
    if state then
        if g.Rainbow_Tools_FE then g.notify("Warning", "Rainbow Tool is already enabled.", 5); return end
        g.rainbow_tool(true)
    else
        if not g.Rainbow_Tools_FE then g.notify("Warning", "Rainbow Tool is not enabled.", 5); return end
        g.rainbow_tool(false)
    end
end}, "RGB_Tool_Toggle_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "Anti Fire",
Default = g.firehidden or false,
Flag = "Anti_Fire_Toggle_UI",
Callback = function(state)
    if state then
        if g.firehidden then g.notify("Warning", "Yadsan Anti-Fire Spammer V3 is already enabled.", 6); return end
        if g.spamming_all_that_fire then g.notify("Warning", "Yadsan Spammer is enabled, disable it first!", 10); return end
        g.notify("Success", "Yadsan Anti-Fire Spammer V3 is now enabled.", 6)
        g.set_fire_state(true)
    else
        if not g.firehidden then g.notify("Warning", "Yadsan Anti-Fire Spammer V3 is not enabled.", 6); return end
        g.notify("Success", "Yadsan Anti-Fire Spammer V3 is now disabled.", 6)
        g.set_fire_state(false)
    end
end}, "Anti_Fire_Toggle_UI")

if priv_server_is_in == true then
    g.create_ui_element("Toggle", PrivServer_Section, {
    Name = "Stop Time (YS)",
    Default = g.is_time_currently_stopped_priv_server or false,
    Flag = "Stop_Time_Toggle_UI",
    Callback = function(state)
        g.stop_time_toggle(state)
    end}, "Stop_Time_Toggle_UI")

    g.create_ui_element("Toggle", PrivServer_Section, {
    Name = "Flash Time (YS)",
    Default = g.flashing_time_fe_toggle or false,
    Flag = "Flash_Time_Toggle_UI",
    Callback = function(state)
        g.flash_time_toggle(state)
    end}, "Flash_Time_Toggle_UI")

    g.create_ui_element("Toggle", PrivServer_Section, {
    Name = "Flash Weather (YS)",
    Default = g.changing_weather_on_repeat or false,
    Flag = "Flash_Weather_Toggle_UI",
    Callback = function(state)
        g.weather_flasher_loop(state)
    end}, "Flash_Weather_Toggle_UI")

    g.create_ui_element("Toggle", PrivServer_Section, {
    Name = "Server Lock (YS)",
    Default = g.server_lock_enabled or false,
    Flag = "Server_Lock_Toggle_UI",
    Callback = function(state)
        g.server_lock_toggle(state)
    end}, "Server_Lock_Toggle_UI")

    g.create_ui_element("Button", PrivServer_Section, {
    Name = "Server Lock Manager",
    Callback = function()
        g.server_lock_whitelist_gui()
    end}, "Server_Lock_Manager_Button_UI")

    g.create_ui_element("Input", PrivServer_Section, {
    Name = "Kick Player (YS)",
    PlaceholderText = "user or display...",
    Flag = "Kick_Player_Input_UI",
    Callback = function(split)
        local target_plr = g.findplr(split)
        if not target_plr then g.notify("Error", "That player does not exist or has left.", 5); return end
        if not g.is_localplayer_server_owner() then g.notify("Error", "You are not the private server owner!", 5); return end
        if target_plr.Name == "Yadsan_Godverse" or target_plr.Name == "L0CKED_1N1" then return end
        g.kick_plr(target_plr)
        g.notify("Success", "Kicked Player: " .. tostring(target_plr), 5)
    end}, "Kick_Player_Input_UI")

    g.create_ui_element("Input", PrivServer_Section, {
    Name = "Ban Player (YS)",
    PlaceholderText = "user or display...",
    Flag = "Ban_Player_Input_UI",
    Callback = function(split)
        if not g.is_localplayer_server_owner() then
            local admin_player = g.get_server_admin_player()
            g.notify("Warning", "Private Server is owned by: " .. tostring(admin_player and admin_player.Name or "Unknown"), 7)
            g.notify("Error", "Not a Private Server or you don't own it!", 5)
            return
        end
        local target = g.findplr(split) or split
        local added = addban(target)
        if added then
            g.notify("Success", "Banned player: " .. added, 5)
        else
            g.notify("Error", "Failed to ban target.", 6)
        end
    end}, "Ban_Player_Input_UI")

    g.create_ui_element("Input", PrivServer_Section, {
    Name = "Unban Player (YS)",
    PlaceholderText = "user or display...",
    Flag = "Unban_Player_Input_UI",
    Callback = function(split)
        if not g.is_localplayer_server_owner() then
            local admin_player = g.get_server_admin_player()
            g.notify("Warning", "Private Server is owned by: " .. tostring(admin_player and admin_player.Name or "Unknown"), 7)
            g.notify("Error", "Not a Private Server or you don't own it!", 5)
            return
        end
        local target = g.findplr(split) or split
        local removed = removeban(target)
        if removed then
            g.notify("Success", "Unbanned player: " .. removed, 5)
        else
            g.notify("Error", "Player is not banned.", 3)
        end
    end}, "Unban_Player_Input_UI")
end

g.create_ui_element("Toggle", Extras_Section, {
Name = "RGB Street Lights",
Default = g.RGB_Street_Lights_NightTime_Loop or false,
Flag = "RGB_Street_Lights_Toggle_UI",
Callback = function(state)
    g.toggle_rgb_streetlights(state)
end}, "RGB_Street_Lights_Toggle_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Admin Player (YS)",
PlaceholderText = "Username or displayname...",
Flag = "Admin_Player_Input_UI",
Callback = function(split)
    local Player = g.findplr(split)
    if not Player then g.notify("Error", "Player does not exist!", 5); return end
    if not Player:IsFriendsWith(g.LocalPlayer.UserId) then g.notify("Error", "This player isn't friends with you, add them!", 5); return end
    if g.player_admins[Player.Name] then g.notify("Error", "Player is already an admin!", 5); return end
    g.alreadyCheckedUser(Player)
    fw(0.5)
    g.notify("Success", "Added " .. tostring(Player.Name) .. " to the admin's table!", 3)
end}, "Admin_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "UnAdmin Player (YS)",
PlaceholderText = "user or display...",
Flag = "Unadmin_Player_Input_UI",
Callback = function(split)
    local Player = g.findplr(split)
    if not Player then g.notify("Error", "Player does not exist!", 5); return end
    if not Player:IsFriendsWith(g.LocalPlayer.UserId) then g.notify("Error", "This player isn't friends with you!", 5); return end
    local Name = Player.Name
    g.notify("Warning", "Removing admin for: " .. tostring(Name), 5)
    if g.player_admins[Name] then g.player_admins[Name] = nil end
    if g.Rainbow_Vehicles[Name] then g.Rainbow_Vehicles[Name] = false end
    if g.Locked_Vehicles[Name] then g.Locked_Vehicles[Name] = false end
    if g.Unlocked_Vehicles[Name] then g.Unlocked_Vehicles[Name] = false end
    if g.Rainbow_Tasks[Name] then g.Rainbow_Tasks[Name] = nil end
    fw(0.5)
    if not g.player_admins[Name] then
        g.notify("Success", "Player's admin has been removed successfully.", 5)
    else
        g.notify("Error", "Player's admin abilities were not removed.", 5)
    end
end}, "Unadmin_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Blacklist Player (YS)",
PlaceholderText = "user or display...",
Flag = "Blacklist_Player_Input_UI",
Callback = function(split)
    local Player = g.findplr(split)
    if not Player then return end
    local Name = Player.Name
    if Player:IsFriendsWith(g.LocalPlayer.UserId) then
        if not g.Blacklisted_Friends[Name] then
            g.Blacklisted_Friends[Name] = Player
        end
    end
    fw(0.3)
    if g.player_admins[Name] then g.player_admins[Name] = nil end
    if g.Rainbow_Vehicles[Name] then g.Rainbow_Vehicles[Name] = false end
    if g.Locked_Vehicles[Name] then g.Locked_Vehicles[Name] = false end
    if g.Unlocked_Vehicles[Name] then g.Unlocked_Vehicles[Name] = false end
    if g.Rainbow_Tasks[Name] then g.Rainbow_Tasks[Name] = nil end
    g.notify("Success", "Blacklisted: " .. tostring(Name), 5)
end}, "Blacklist_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Unblacklist Player (YS)",
PlaceholderText = "Username or displayname...",
Flag = "Unblacklist_Player_Input_UI",
Callback = function(split)
    local Player = g.findplr(split)
    if not Player then return end
    local Name = Player.Name
    if Player:IsFriendsWith(g.LocalPlayer.UserId) then
        if g.Blacklisted_Friends[Name] then
            g.Blacklisted_Friends[Name] = nil
            g.notify("Success", "Removed blacklist for: " .. tostring(Name), 5)
        else
            g.notify("Warning", tostring(Name) .. " is not blacklisted.", 5)
        end
    end
end}, "Unblacklist_Player_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Rainbow Time (Friend, YS)",
PlaceholderText = "Username number (e.g. PlayerName 1)...",
Flag = "Rainbow_Time_Input_UI",
Callback = function(split)
    local parts = split and split:split(" ") or {}
    local Player = g.findplr(parts[1])
    if not Player then g.notify("Error", "Player doesn't exist or has left!", 5); return end
    if not Player:IsFriendsWith(g.LocalPlayer.UserId) then g.notify("Error", "Player is not friends with you, add them!", 5); return end
    local new_delay = tonumber(parts[2]) or 1
    g.Rainbow_Delays = g.Rainbow_Delays or {}
    g.Rainbow_Delays[Player.Name] = new_delay
    fw(0.2)
    g.notify("Success", "Set rainbow delay for " .. Player.Name .. " to " .. new_delay, 5)
end}, "Rainbow_Time_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Walk Fling Whitelist",
PlaceholderText = "user or display...",
Flag = "Walk_Fling_Whitelist_Input_UI",
Callback = function(split)
    local plr = g.findplr(split)
    if typeof(plr) ~= "Instance" or not plr:IsA("Player") then g.notify("Error", "Player not found in game.", 3); return end
    g.AddToWalkFlingWhitelist(plr)
end}, "Walk_Fling_Whitelist_Input_UI")

g.create_ui_element("Input", Players_Section, {
Name = "Walk Fling Unwhitelist",
PlaceholderText = "Username or displayname...",
Flag = "Walk_Fling_Unwhitelist_Input_UI",
Callback = function(split)
    local plr = g.findplr(split)
    if typeof(plr) ~= "Instance" or not plr:IsA("Player") then g.notify("Error", "Player not found in game.", 5); return end
    g.RemoveFromWalkFlingWhitelist(plr)
end}, "Walk_Fling_Unwhitelist_Input_UI")

g.create_ui_element("Button", Home_Section, {
Name = "Get Priv Server Owner",
Callback = function()
    g.notify_priv_server_owner()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Open Config Manager",
Callback = function()
    g.toggle_config_manager(true)
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Streamer Mode",
Callback = function()
    g.streamer_mode_script()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Annoyer GUI",
Callback = function()
    g.annoyance_GUI()
end,})

g.create_ui_element("Button", Vehicle_Section, {
Name = "Car Stats GUI",
Callback = function()
    g.vehicle_stats_viewer_GUI()
end,})

g.create_ui_element("Button", Vehicle_Section, {
Name = "All Cars GUI",
Callback = function()
    g.car_listing_gui()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Free Emotes GUI",
Callback = function()
    loadstring(game:HttpGet("https://pastebin.com/raw/RCj6RJtc"))()
end,})

g.create_ui_element("Button", Phone_Section, {
Name = "Message GUI",
Callback = function()
    g.send_msg_menu()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Workspace Editor",
Callback = function()
    g.workspace_editor_script_GUI()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Debugger",
Callback = function()
    if g.Flames_Debugger_Function_Tester_GUI then
        pcall(function() g.Flames_Debugger_Function_Tester_GUI() end)
    else
        g.notify("Error", "Yadsan Debugger function not found or was not created at runtime.", 10)
    end
end,})

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Outfits Manager (Save outfits GUI)",
Callback = function()
    g.save_outfits_GUI()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Chat Bypass",
Callback = function()
    g.load_workaround_script()
end,})

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Save Emote",
Callback = function()
    g.save_copied_plrs_emote()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Infinite Yield",
Callback = function()
    g.infinite_yield()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Infinite Premium",
Callback = function()
    g.infinite_premium()
end,})

g.create_ui_element("Button", Extras_Section, {
Name = "Nameless Admin",
Callback = function()
    g.flames_nameless_admin_ver()
end,})

g.Toggle_Fire_Spam = g.create_ui_element("Toggle", Extras_Section, {
Name = "Flames (YS)",
Default = g.spamming_all_that_fire or false,
Flag = "Flames_Toggle_UI",
Callback = function(state)
    if state then
        if g.LocalPlayer:GetAttribute("is_verified") == false then
            if g.Toggle_Fire_Spam then g.Toggle_Fire_Spam:Set(false, false) end
            g.notify("Error", "You need actual LifePay premium to run this!", 5)
            return
        end
        if g.spamming_flames and typeof(g.spamming_flames) == "function" then
            g.spamming_flames(true)
        else
            g.notify("Error", "Function: g.spamming_flames does not exist.", 3); return
        end
    else
        if g.spamming_flames and typeof(g.spamming_flames) == "function" then
            g.spamming_flames(false)
        else
            g.notify("Error", "Function: g.spamming_flames does not exist.", 3); return
        end
    end
end}, "Flames_Toggle_UI")

g.create_ui_element("Input", Extras_Section, {
Name = "Spawn Fire (YS)",
PlaceholderText = "Enter amount...",
Flag = "Spawn_Fire_Input_UI",
Callback = function(split)
    local amount = tonumber(split) or 5
    local is_verified = g.LocalPlayer:GetAttribute("is_verified")
    if not is_verified then g.notify("Error", "You do not have premium, you cannot run this!", 8); return end
    g.HasSeen_Fire_AlertFlamesHub = g.HasSeen_Fire_AlertFlamesHub or false
    g.set_fire_amount_FE(amount)
    g.HasSeen_Fire_AlertFlamesHub = true
    fw(0.2)
    for i = 1, amount do g.Send("request_fire") end
end}, "Spawn_Fire_Input_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "Sign Spam (YS)",
Default = g.ToolChanger_FE or false,
Flag = "Sign_Spam_Toggle_UI",
Callback = function(state)
    if state then
        if g.ToolChanger_FE then g.notify("Warning", "Sign spammer is already enabled!", 5); return end
        g.spam_sign_text(true)
    else
        if not g.ToolChanger_FE then g.notify("Warning", "Sign spammer is not enabled!", 5); return end
        g.spam_sign_text(false)
    end
end}, "Sign_Spam_Toggle_UI")

g.create_ui_element("Button", Extras_Section, {
Name = "Collect All NBA Props (YS)",
Callback = function()
    local attr = g.LocalPlayer:GetAttribute("NBA_HUNT_PROGRESS")
    if not attr then return end
    if attr ~= "PLAYING" then g.notify("Warning", "Talk to the NPC first and enter before trying this!", 10); return end
    g.collect_all_nba_props()
end,})

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Anti Outfit Copier (YS)",
Default = g.anti_outfit_stealer or false,
Flag = "Anti_Outfit_Copier_Toggle_UI",
Callback = function(state)
    g.anti_outfit_copier(state)
end}, "Anti_Outfit_Copier_Toggle_UI")

g.create_ui_element("Toggle", Extras_Section, {
Name = "Mute Tools",
Default = g.autosilence or false,
Flag = "Mute_Tools_Toggle_UI",
Callback = function(state)
    g.mute_all_tools(state)
end}, "Mute_Tools_Toggle_UI")

g.create_ui_element("Dropdown", LocalPlayer_Section, {
Name = "Emotes",
Options = {
	"Needy",
	"Griddy",
	"Jiggy",
	"Scenario",
	"Superman",
	"Zen",
	"Orange Justice",
	"Aura Farm",
	"Worm",
	"Jabba",
	"Popular",
	"Default Dance",
	"Koto Nai",
	"Glitching",
	"Billy Jean",
	"Billy Bounce",
	"Michael Myers",
	"Sturdy",
	"Electro Shuffle",
	"Take The L",
	"Laugh It Up",
	"Reanimated",
	"Motion",
	"Tuff",
	"Michael Jackson"
},
DefaultItemSelected = "None",
ItemSelecting = false,
Callback = function(selected)
	local emote_map = {
		["Needy"]           = "needy_twerk",
		["Griddy"]          = "griddy",
		["Jiggy"]           = "jiggy",
		["Scenario"]        = "scenario",
		["Superman"]        = "superman",
		["Zen"]             = "zen",
		["Orange Justice"]  = "orangej",
		["Aura Farm"]       = "aura",
		["Worm"]            = "worm",
		["Jabba"]           = "jabba",
		["Popular"]         = "popular",
		["Default Dance"]   = "defaultdance",
		["Koto Nai"]        = "kotonai",
		["Glitching"]       = "glitch",
		["Billy Jean"]      = "billyjean",
		["Billy Bounce"]    = "billybounce",
		["Michael Myers"]   = "michaelmyers",
		["Sturdy"]          = "sturdy",
		["Electro Shuffle"] = "electroshuffle",
		["Take The L"]      = "takethel",
		["Laugh It Up"]     = "laughitup",
		["Reanimated"]      = "reanimated",
		["Motion"]          = "motion",
		["Tuff"]            = "tuff",
		["Michael Jackson"] = "michaeljackson",
	}
	local emote = emote_map[selected]
	if not emote then g.notify("Error", "Unknown emote selected.", 2.5); return end
	g.do_emote(emote)
end}, "Emotes_Dropdown_UI")

g.create_ui_element("Button", LocalPlayer_Section, {
Name = "Stop Emoting",
Callback = function()
    g.disable_emoting_script()
end}, "No_Emote_Button_UI")

g.create_ui_element("Input", LocalPlayer_Section, {
Name = "RP Name (YS)",
PlaceholderText = "Enter new RP name...",
Flag = "RP_Name_Input_UI",
Callback = function(text)
    local max_len = 19
    if #text > max_len and writefile then
        g.notify("Info", "Your roleplay Name exceeds 19 characters, we're saving it for you, it'll be automatically set back once you reload the script.", 15)
        writefile("LifeTogether_RP_Admin_Custom_Name.txt", text)
    end
    g.change_RP_Name(text)
end}, "RP_Name_Input_UI")

g.create_ui_element("Input", LocalPlayer_Section, {
Name = "RP Bio (YS)",
PlaceholderText = "Enter new RP bio...",
Flag = "RP_Bio_Input_UI",
Callback = function(text)
    local max_len = 49
    if #text > max_len and writefile then
        g.notify("Info", "Your roleplay Bio exceeds 49 characters, we're saving it for you, it'll be automatically set back once you reload the script.", 15)
        writefile("LifeTogether_RP_Admin_Custom_Bio.txt", text)
    end
    g.change_bio(text)
end}, "RP_Bio_Input_UI")

g.create_ui_element("Button", Extras_Section, {
Name = "Performance GUI",
Callback = function()
    g.LoadPerformanceStatsGUI()
end}, "Stats_GUI_Button_UI")

g.create_ui_element("Toggle", LocalPlayer_Section, {
Name = "Two Tone Skin (YS)",
Default = g.Two_Tone_Skin_Tone_Loop_Toggled or false,
Flag = "Two_Tone_Skin_Toggle_UI",
Callback = function(state)
    g.two_tone_skin(state)
end}, "Two_Tone_Skin_Toggle_UI")

g.create_ui_element("ColorPicker", Vehicle_Section, {
Name = "Car Color (YS)",
Default = Color3.fromRGB(255, 0, 0),
Flag = "Car_Color_Picker_UI",
Callback = function(color)
    local vehicle = g.get_vehicle()
    if not vehicle then g.notify("Error", "You do not have a vehicle spawned!", 0.75); return end
    g.change_vehicle_color(color, vehicle)
end}, "Car_Color_Picker_UI")

g.create_ui_element("Toggle", Players_Section, {
Name = "Player ESP",
Default = g.Flames_Hub_Player_ESP_Core_Has_Been_Enabled or false,
Flag = "Player_ESP_Toggle_UI",
Callback = function(state)
    if state then
        g.enable_player_esp()
    else
        g.disable_player_esp()
    end
end}, "Player_ESP_Toggle_UI")

g.create_ui_element("Toggle", Players_Section, {
Name = "Tracer ESP",
Default = g.tracer_esp_currently_running_flag_Flames_Hub or false,
Flag = "Tracer_ESP_Toggle_UI",
Callback = function(state)
    if state then
        g.enable_tracers()
    else
        g.disable_tracers()
    end
end}, "Tracer_ESP_Toggle_UI")

g.notify("Success", "Welcome back, "..tostring(g.LocalPlayer.DisplayName)..".", 10)
g.print_bytes = function(label, s)
    local bytes = {}
    for i = 1, #s do
        table.insert(bytes, string.byte(s, i))
    end
    print(label .. ": " .. table.concat(bytes, ","))
end
local function clean(s) return s:gsub("[%c%z%s]", ""):gsub("[^\32-\126]", "") end
local version_url = "https://gitlab.com/flames2431233/Starter/-/raw/main/Assets/Script_Versions_JSON.json?ref_type=heads"
local function ws_get_version()
    local http_req = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not http_req then return nil end
    local ok, result = pcall(function()
        return http_req({
            Url = version_url .. "?cache=" .. tostring(os.clock()),
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" }
        })
    end)

    if not ok or not result or result.StatusCode ~= 200 then return nil end
    local ok2, data = pcall(function() return g.HttpService:JSONDecode(result.Body) end)
    if not ok2 or type(data) ~= "table" then return nil end
    local version = data.LifeTogether_Hub_Version
    if not version then return nil end
    return tostring(version):gsub("%s+", "")
end

local function Notify(msg, dur)
    dur = dur or 5
    local gui = Instance.new("ScreenGui")
    gui.Name = "CustomNotifyGui"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(0, 500, 0, 120)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.Parent = gui

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Position = UDim2.new(0, 15, 0.5, -25)
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Image = "rbxasset://textures/ui/Emotes/ErrorIcon.png"
    icon.ImageTransparency = 1
    icon.Parent = frame

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 80, 0, 10)
    label.Size = UDim2.new(1, -90, 1, -20)
    label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json")
    label.Text = msg
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 20
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextTransparency = 1
    label.Parent = frame

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    g.TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 0.3 }):Play()
    g.TweenService:Create(icon, TweenInfo.new(0.3), { ImageTransparency = 0 }):Play()
    g.TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()

    task.delay(dur, function()
        if not frame.Parent then return end
        g.TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        g.TweenService:Create(icon, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
        g.TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
        task.wait(0.35)
        if gui and gui:IsA("ScreenGui") then gui:Destroy() end
    end)
end

g.lta_updater_running = g.lta_updater_running or false
g.lta_updater_thread_id = (g.lta_updater_thread_id or 0) + 1
local thread_id = g.lta_updater_thread_id
if not g.lta_updater_running then
    g.lta_updater_running = true
    task.spawn(function()
        while g.lta_updater_running and thread_id == g.lta_updater_thread_id do
            task.wait(20)
            local local_version = clean(tostring(g.Script_Version))
            if local_version == "" then continue end
            local remote_version = ws_get_version()
            if not remote_version or remote_version == "" then continue end
            if remote_version ~= local_version then
                g.lta_updater_running = false
                Notify("[UPDATE DETECTED]:\nLocal: " .. local_version .. "\nServer: " .. remote_version .. "\nReloading...", 6)
                task.wait(0.6)
                g.LifeTogether_Actual_Flames_Hub_Running_Functioning_Currently_On_Client = false
                g.Script_Version = nil
                g.LifeTogetherRP_Admin = false
                pcall(function()
                    loadstring(game:HttpGet(script_url .. "?cache=" .. tostring(os.clock())))()
                end)
                break
            end
        end
    end)
end

-- [[ YADSAN / FLAMES HUB GOLD OWNER COMMANDS & ANNOUNCEMENT ]] --
do
    local Players = game:GetService("Players")
    local TextChatService = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local CoreGui = game:GetService("CoreGui")
    local Lighting = game:GetService("Lighting")

    local plr = Players.LocalPlayer
    local Owners = {"AGKaBaap_YadsanAsuka", "Yadsan_GodVerse"}
    local isFrozen = false

    local function isOwner(name)
        if type(name) ~= "string" then return false end
        local lowerName = name:lower()
        for _, ownerName in ipairs(Owners) do
            if lowerName == ownerName:lower() then
                return true
            end
        end
        return false
    end

    local function matchesTarget(player, targetName, senderPlayer)
        if not player or type(targetName) ~= "string" or targetName == "" then
            return false
        end
        local lowerTarget = targetName:lower()
        if lowerTarget == "all" then
            return true
        elseif lowerTarget == "others" then
            return player ~= senderPlayer
        elseif lowerTarget == "me" then
            return player == senderPlayer
        end

        return player.Name:lower():sub(1, #lowerTarget) == lowerTarget
            or player.DisplayName:lower():sub(1, #lowerTarget) == lowerTarget
    end

    local function setFrozen(state)
        isFrozen = state
        local char = plr.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if state then
                hum.Sit = false
            end
            hum.PlatformStand = state
            if not state then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = state
            end
        end
    end

    if g.Flames_Yellow_CharAdded_Conn then
        pcall(function() g.Flames_Yellow_CharAdded_Conn:Disconnect() end)
        g.Flames_Yellow_CharAdded_Conn = nil
    end

    g.Flames_Yellow_CharAdded_Conn = plr.CharacterAdded:Connect(function()
        if isFrozen then
            task.wait(0.1)
            setFrozen(true)
        end
    end)

    if g.Flames_Yellow_MessageReceived_Conn then
        pcall(function() g.Flames_Yellow_MessageReceived_Conn:Disconnect() end)
        g.Flames_Yellow_MessageReceived_Conn = nil
    end

    g.Flames_Yellow_MessageReceived_Conn = TextChatService.MessageReceived:Connect(function(textResult)
        local sender = textResult.TextSource
        if not sender then return end

        local senderPlayer = Players:GetPlayerByUserId(sender.UserId)
        if not senderPlayer or not isOwner(senderPlayer.Name) then return end

        local text = textResult.Text
        if type(text) ~= "string" or text == "" then return end

        local rawArgs = text:split(" ")
        local cmd = rawArgs[1] and rawArgs[1]:lower()
        local targetName = rawArgs[2]

        if cmd == ";bring" and targetName then
            if matchesTarget(plr, targetName, senderPlayer) and plr ~= senderPlayer then
                if senderPlayer.Character and plr.Character then
                    plr.Character:PivotTo(senderPlayer.Character:GetPivot())
                end
            end

        elseif cmd == ";kill" then
            if not targetName or matchesTarget(plr, targetName, senderPlayer) then
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.Health = 0
                    end
                    char:BreakJoints()
                end
            end

        elseif cmd == ";freeze" and targetName then
            if matchesTarget(plr, targetName, senderPlayer) then
                setFrozen(true)
            end

        elseif cmd == ";unfreeze" and targetName then
            if matchesTarget(plr, targetName, senderPlayer) then
                setFrozen(false)
            end

        elseif cmd == ";kick" and targetName then
            if matchesTarget(plr, targetName, senderPlayer) then
                local reason = table.concat(rawArgs, " ", 3)
                if reason == "" then reason = "No reason provided." end
                plr:Kick("\n[ EXC KICK ]\nAdmin: " .. senderPlayer.Name .. "\nReason: " .. reason)
            end

        elseif cmd == ";ban" and targetName then
            if matchesTarget(plr, targetName, senderPlayer) then
                local reason = table.concat(rawArgs, " ", 3)
                if reason == "" then reason = "Banned by Catel Gang" end
                plr:Kick("\n@@@@@@-@-@-@-@-@-@\nbanned from Life Together RP\nduration 30 mins!\n\nReason: " .. reason:upper() .. "\nAdmin: " .. senderPlayer.Name)
            end

        elseif cmd == "!stopall" then
            if gui then pcall(function() gui:Destroy() end) end
            if blur then pcall(function() blur:Destroy() end) end
            pcall(function()
                for _, v in ipairs(CoreGui:GetChildren()) do
                    if v:IsA("ScreenGui") and (v.Name == "FlamesAdminGUI" or v.Name == "PrefixCreditsGui_LifeTogether" or v.Name:find("Flames")) then
                        v:Destroy()
                    end
                end
                for _, v in ipairs(Lighting:GetChildren()) do
                    if v:IsA("BlurEffect") then
                        v:Destroy()
                    end
                end
            end)
        end
    end)

    -- Announcement
    task.spawn(function()
        local text = "------------------//////FLAMES HUB GOLD LOADED (🎩Made by Yadsan_Godverse -- CELESTIAL SYNDICATE ON TOP 🔮 ////////--------------------"
        pcall(function()
            if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local textChannels = TextChatService:FindFirstChild("TextChannels") or TextChatService:WaitForChild("TextChannels", 10)
                local channel = textChannels and (textChannels:FindFirstChild("RBXGeneral") or textChannels:WaitForChild("RBXGeneral", 10))
                if channel then
                    channel:SendAsync(text)
                end
            else
                local defaultEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if defaultEvents and defaultEvents:FindFirstChild("SayMessageRequest") then
                    defaultEvents.SayMessageRequest:FireServer(text, "All")
                end
            end
        end)
    end)
end
    pcall(BuildFlamesNovaUI)
end

local function RunWhiteLifeHub()
    local NovaUI = SharedNovaUI


--[[
    YADSAN HUB  -  FINAL VERSION (English only)
    Blackhole theme + intro, Bigger Blackhole orb, fixed Resizer, Touch Vibration.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

-- ========== INTRO: two black holes merge into a white hole, YADSAN appears letter by letter, loading, white-hole release ==========
local introGui
NovaUI.HoldOpen = true
task.spawn(function()
	local TweenService = game:GetService("TweenService")
	local T0, skipped, revealed, sfx = nil, false, false, nil
	local function reveal()
		if revealed then return end
		revealed = true
		task.spawn(function()
			local waited = 0
			while not (NovaUI._window and NovaUI.HubReady) and waited < 25 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			NovaUI.HoldOpen = false
			local w = NovaUI._window
			if w then
				pcall(function() w:Reveal() end)
			end
		end)
	end
	local okIntro, errIntro = pcall(function()
		local parent
		local okHui, hui = pcall(function() return gethui and gethui() end)
		if okHui and hui then
			parent = hui
		else
			local okCore = pcall(function() return game:GetService("CoreGui").Name end)
			parent = okCore and game:GetService("CoreGui") or lp:WaitForChild("PlayerGui")
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "YadsanIntro"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 1000000
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = parent
		introGui = gui
		task.delay(16, function()
			if gui.Parent then gui:Destroy() end
		end)

		local vp = gui.AbsoluteSize
		if vp.X < 10 then vp = Vector2.new(800, 600) end
		local k = math.clamp(vp.Y / 600, 0.6, 1.6)
		local ACC = Color3.fromRGB(150, 70, 255)
		local HOT = Color3.fromRGB(235, 215, 255)
		local rng = Random.new()

		local bg = Instance.new("TextButton")
		bg.Text, bg.AutoButtonColor, bg.BorderSizePixel = "", false, 0
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(1, 0, 4)
		bg.Parent = gui
		local stage = Instance.new("CanvasGroup")
		stage.BackgroundTransparency = 1
		stage.Size = UDim2.fromScale(1, 1)
		stage.ZIndex = 2
		stage.Parent = bg
		local shakeBox = Instance.new("Frame")
		shakeBox.BackgroundTransparency = 1
		shakeBox.Size = UDim2.fromScale(1, 1)
		shakeBox.Parent = stage
		local flash = Instance.new("Frame")
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BorderSizePixel = 0
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundTransparency = 1
		flash.ZIndex = 20
		flash.Parent = bg
		local vig = Instance.new("Frame")
		vig.BackgroundColor3 = ACC
		vig.BorderSizePixel = 0
		vig.Size = UDim2.fromScale(1, 1)
		vig.BackgroundTransparency = 1
		vig.ZIndex = 1
		vig.Parent = bg
		local vg = Instance.new("UIGradient")
		vg.Rotation = 90
		vg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.7) })
		vg.Parent = vig

		-- stars that get pulled toward the hole
		local stars, phase = {}, "pull"
		for i = 1, 80 do
			local s = Instance.new("Frame")
			s.BorderSizePixel = 0
			s.BackgroundColor3 = rng:NextNumber() > 0.65 and Color3.fromRGB(200, 170, 255) or Color3.new(1, 1, 1)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.ZIndex = 2
			s.Parent = shakeBox
			stars[i] = { f = s, a = rng:NextNumber() * math.pi * 2, r = rng:NextNumber(0.1, 1), v = rng:NextNumber(0.04, 0.12), s = rng:NextNumber(1, 3) }
		end
		local pull = 0
		local starConn = RunService.Heartbeat:Connect(function(dt)
			local cx, cy = vp.X / 2, vp.Y / 2
			local R = math.max(vp.X, vp.Y) * 0.62
			for _, st in ipairs(stars) do
				st.r = st.r - dt * st.v * (1 + pull * 4) * (0.4 + (1 - st.r) * 1.4)
				if st.r < 0.045 then
					st.r = rng:NextNumber(0.85, 1.05)
					st.a = rng:NextNumber() * math.pi * 2
				end
				st.a = st.a + dt * 0.25 * (1 - st.r) * (1 + pull)
				local x, y = cx + math.cos(st.a) * st.r * R, cy + math.sin(st.a) * st.r * R * 0.8
				st.f.Position = UDim2.fromOffset(x, y)
				local sz = math.max(1, st.s * (0.4 + st.r) * k)
				st.f.Size = UDim2.fromOffset(sz * (1 + pull * 1.5 * (1 - st.r)), sz)
				st.f.Rotation = math.deg(st.a)
				st.f.BackgroundTransparency = math.clamp(0.1 + st.r * 0.5, 0, 0.9)
			end
		end)

		local shakeMag = 0
		-- ===== two blazing suns =====
		local holeSize = 300 * k
		local hA, apiA = NovaUI.MakeBlackhole(shakeBox, holeSize, { Color = Color3.fromRGB(255, 190, 45), ZIndex = 5, ParticleCount = 16, White = false })
		local hB, apiB = NovaUI.MakeBlackhole(shakeBox, holeSize, { Color = Color3.fromRGB(255, 105, 30), ZIndex = 5, ParticleCount = 16, White = false })
		apiA.SetWhite(false, true)
		apiB.SetWhite(false, true)
		local sA, sB = Instance.new("UIScale"), Instance.new("UIScale")
		sA.Scale, sB.Scale = 0.001, 0.001
		sA.Parent, sB.Parent = hA, hB
		local function scaleTo(sc, v, t, style, dir)
			TweenService:Create(sc, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), { Scale = v }):Play()
		end
		local orbit = { on = false, t = 0 }
		local theta0 = rng:NextNumber() * math.pi * 2
		local orbitConn = RunService.Heartbeat:Connect(function()
			if not orbit.on or not T0 then return end
			local u = math.clamp((os.clock() - T0 - 0.45) / 3.1, 0, 1)
			local R = vp.X * 0.27 * (1 - u ^ 1.7)
			local th = theta0 + math.pi * 2 * (0.7 * u + 4.3 * u ^ 2.3)
			local x, y = math.cos(th) * R, math.sin(th) * R * 0.5
			hA.Position = UDim2.new(0.5, x, 0.5, y)
			hB.Position = UDim2.new(0.5, -x, 0.5, -y)
			local sc = 0.16 + 0.46 * u
			sA.Scale, sB.Scale = sc, sc
			pull = 0.15 + u * 1.9
			shakeMag = u * u * 7 * k
		end)

		-- ===== letters CELESTIAL GODVERSE centered & responsive to screen width =====
		local word = "CELESTIAL GODVERSE"
		local letters = {}
		local mid = (#word + 1) / 2
		local spacing = math.min(44 * k, (vp.X * 0.88) / #word)
		local lsz = math.min(54 * k, spacing * 1.18)
		for i = 1, #word do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Text = word:sub(i, i)
			l.Font = Enum.Font.GothamBlack
			l.TextSize = lsz
			l.TextColor3 = Color3.fromRGB(45, 16, 4)
			l.TextTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.new(0.5, (i - mid) * spacing, 0.5, -26 * k)
			l.Size = UDim2.fromOffset(lsz, lsz)
			l.ZIndex = 12
			l.Parent = shakeBox
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = Color3.fromRGB(255, 225, 120)
			st.Transparency = 1
			st.Parent = l
			local sc = Instance.new("UIScale")
			sc.Scale = 0.2
			sc.Parent = l
			letters[i] = { l = l, st = st, sc = sc, x = (i - mid) * spacing }
		end
		local function showLetter(i)
			local L = letters[i]
			TweenService:Create(L.l, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, L.x, 0.5, 0), TextTransparency = 0 }):Play()
			TweenService:Create(L.st, TweenInfo.new(0.3), { Transparency = 0 }):Play()
			TweenService:Create(L.sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		local function allTogether()
			for _, L in ipairs(letters) do
				L.l.TextColor3 = Color3.new(1, 1, 1)
				L.st.Color = Color3.fromRGB(150, 80, 255)
				L.st.Thickness = 7
				L.sc.Scale = 1.3
				TweenService:Create(L.sc, TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				TweenService:Create(L.l, TweenInfo.new(0.9), { TextColor3 = Color3.fromRGB(22, 8, 52) }):Play()
				TweenService:Create(L.st, TweenInfo.new(0.9), { Color = Color3.new(1, 1, 1), Thickness = 3.5 }):Play()
			end
		end
		-- gentle float once they are all there
		local floating = false
		local floatConn = RunService.Heartbeat:Connect(function()
			if not floating then return end
			local t = os.clock()
			for i, L in ipairs(letters) do
				L.l.Position = UDim2.new(0.5, L.x, 0.5, math.sin(t * 2 + i * 0.7) * 4 * k)
			end
		end)

		-- ===== loading UI =====
		local function uiLabel(txtc, size, font, y)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Font = font
			l.Text = txtc
			l.TextSize = size * k
			l.TextColor3 = HOT
			l.TextTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.new(0.5, 0, 0.5, y * k)
			l.Size = UDim2.fromOffset(360 * k, size * 1.5 * k)
			l.ZIndex = 12
			l.Parent = shakeBox
			return l
		end
		local loadL = uiLabel("L O A D I N G", 17, Enum.Font.GothamBold, 218)
		local pctL = uiLabel("0%", 12, Enum.Font.Code, 262)
		local barBg = Instance.new("Frame")
		barBg.BackgroundColor3 = Color3.fromRGB(34, 20, 64)
		barBg.BorderSizePixel = 0
		barBg.AnchorPoint = Vector2.new(0.5, 0.5)
		barBg.Position = UDim2.new(0.5, 0, 0.5, 240 * k)
		barBg.Size = UDim2.fromOffset(280 * k, 5 * k)
		barBg.BackgroundTransparency = 1
		barBg.ZIndex = 12
		barBg.Parent = shakeBox
		Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
		local barFill = Instance.new("Frame")
		barFill.BackgroundColor3 = Color3.new(1, 1, 1)
		barFill.BorderSizePixel = 0
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.ZIndex = 13
		barFill.Parent = barBg
		Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
		local barGrad = Instance.new("UIGradient")
		barGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)) })
		barGrad.Parent = barFill

		-- shake driver
		local shakeConn = RunService.Heartbeat:Connect(function()
			if shakeMag > 0.05 then
				shakeBox.Position = UDim2.fromOffset(rng:NextNumber(-shakeMag, shakeMag), rng:NextNumber(-shakeMag, shakeMag))
			else
				shakeBox.Position = UDim2.new()
			end
		end)
		local function bump(mag, dur)
			task.spawn(function()
				local steps = math.max(1, math.floor(dur / 0.03))
				for i = 1, steps do
					if not gui.Parent then return end
					shakeMag = math.max(shakeMag, mag * (1 - i / steps))
					task.wait(0.03)
				end
			end)
		end
		local function alive() return gui.Parent ~= nil end
		local function at(tm)
			while gui.Parent and os.clock() - T0 < tm do RunService.Heartbeat:Wait() end
			return alive()
		end
		local function shock(delay, size, thick)
			task.delay(delay, function()
				if not gui.Parent then return end
				local r = Instance.new("Frame")
				r.BackgroundTransparency = 1
				r.AnchorPoint = Vector2.new(0.5, 0.5)
				r.Position = UDim2.fromScale(0.5, 0.5)
				r.Size = UDim2.fromOffset(40 * k, 40 * k)
				r.ZIndex = 14
				r.Parent = shakeBox
				Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
				local s = Instance.new("UIStroke")
				s.Thickness = thick
				s.Color = Color3.new(1, 1, 1)
				s.Transparency = 0
				s.Parent = r
				TweenService:Create(r, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(size * k, size * k) }):Play()
				TweenService:Create(s, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 0.5 }):Play()
				task.delay(1.2, function() r:Destroy() end)
			end)
		end
		local function sparks(n)
			for _ = 1, n do
				local ang = rng:NextNumber() * math.pi * 2
				local dist = rng:NextNumber(200, 700) * k
				local d = Instance.new("Frame")
				d.BorderSizePixel = 0
				d.BackgroundColor3 = rng:NextNumber() > 0.5 and Color3.new(1, 1, 1) or HOT
				d.AnchorPoint = Vector2.new(0.5, 0.5)
				d.Position = UDim2.fromScale(0.5, 0.5)
				local sz = rng:NextInteger(2, 6)
				d.Size = UDim2.fromOffset(sz * 2, sz)
				d.Rotation = math.deg(ang)
				d.ZIndex = 15
				d.Parent = shakeBox
				local dur = rng:NextNumber(0.5, 1.2)
				TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist), BackgroundTransparency = 1 }):Play()
				task.delay(dur + 0.05, function() d:Destroy() end)
			end
		end

		local function cleanup(fade)
			for _, c in ipairs({ starConn, orbitConn, floatConn, shakeConn }) do pcall(function() c:Disconnect() end) end
			if gui.Parent then gui:Destroy() end
		end

		-- ===== play =====
		local sndA = NovaUI.Sound("intro_a", 0.9, 10, true)
		T0 = os.clock()
		TweenService:Create(vig, TweenInfo.new(3), { BackgroundTransparency = 0.88 }):Play()
		-- 0.0 - 3.6 : two holes open and spiral into each other
		if not at(0.1) then return end
		orbit.on = true
		pull = 0.15
		for _, hb in ipairs({ 0.5, 1.3, 2.0, 2.55, 2.95, 3.25 }) do
			task.delay(math.max(0, hb - (os.clock() - T0)), function()
				if not alive() or not orbit.on then return end
				apiA.Boost(0.9)
				apiB.Boost(0.9)
				vig.BackgroundTransparency = 0.72
				TweenService:Create(vig, TweenInfo.new(0.45), { BackgroundTransparency = 0.88 }):Play()
				bump(3, 0.28)
			end)
		end
		-- 3.6 : they merge into one white hole
		if not at(3.58) then return end
		orbit.on = false
		pull = 0.4
		shakeMag = 0
		hA.Position, hB.Position = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		scaleTo(sB, 0.001, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		sA.Scale = 0.7
		scaleTo(sA, 1.25, 1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		apiA.SetWhite(true, false)
		apiA.Boost(2)
		flash.BackgroundTransparency = 0.1
		TweenService:Create(flash, TweenInfo.new(1.0, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		bump(18 * k, 0.6)
		shock(0, 1400, 6)
		shock(0.14, 1000, 4)
		shock(0.3, 760, 3)
		sparks(40)
		-- 3.95 - 5.65 : CELESTIAL GODVERSE one by one
		for i = 1, #letters do
			if not at(3.95 + 0.09 * (i - 1) - 0.02) then return end
			showLetter(i)
			apiA.Boost(1.1)
			bump(5, 0.2)
			shock(0.04, 520, 2)
		end
		-- 5.75 : all five together
		if not at(5.75) then return end
		allTogether()
		apiA.Boost(2)
		flash.BackgroundTransparency = 0.8
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		bump(10 * k, 0.4)
		shock(0, 900, 4)
		sparks(26)
		floating = true
		-- 5.95+ : LOADING (finishes when the hub is really ready, at least 2.5 s)
		if not at(5.95) then return end
		for _, o in ipairs({ loadL, pctL }) do TweenService:Create(o, TweenInfo.new(0.5), { TextTransparency = 0.05 }):Play() end
		TweenService:Create(barBg, TweenInfo.new(0.4), { BackgroundTransparency = 0.1 }):Play()
		local lt0, hum = os.clock(), nil
		local dots = { "CELESTIAL LOADING", "CELESTIAL LOADING .", "CELESTIAL LOADING . .", "CELESTIAL LOADING . . ." }
		local shown = 0
		while alive() do
			local el = os.clock() - lt0
			local p = math.clamp(el / 2.6, 0, 1)
			local ready = NovaUI._window and NovaUI.HubReady
			if not ready then p = math.min(p, 0.96) end
			if p > shown then shown = p end
			barFill.Size = UDim2.fromScale(shown, 1)
			pctL.Text = math.floor(shown * 100 + 0.5) .. "%"
			loadL.Text = dots[(math.floor(el * 3) % 4) + 1]
			barGrad.Offset = Vector2.new(math.sin(os.clock() * 3) * 0.3, 0)
			if os.clock() - T0 > 8.5 and not hum then
				hum = NovaUI.Sound("intro_hum", 0.6, 60, true)
				if hum then hum.Looped = true end
			end
			if shown >= 1 or el > 22 then break end
			RunService.Heartbeat:Wait()
		end
		if not alive() then return end
		pctL.Text = "100%"
		loadL.Text = "R E A D Y"
		-- ===== release: collapse, silence, white hole birth =====
		local tb = os.clock()
		if hum then pcall(function() hum:Destroy() end) end
		pcall(function() if sndA then sndA:Destroy() end end)
		NovaUI.Sound("intro_b", 0.95, 8, true)
		floating = false
		for _, o in ipairs({ loadL, pctL }) do TweenService:Create(o, TweenInfo.new(0.25), { TextTransparency = 1 }):Play() end
		TweenService:Create(barBg, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		barFill.BackgroundTransparency = 1
		for _, L in ipairs(letters) do
			TweenService:Create(L.sc, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = 0.001 }):Play()
			TweenService:Create(L.l, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		end
		apiA.SetWhite(false, false)
		scaleTo(sA, 0.12, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		pull = 3
		bump(8 * k, 0.3)
		while alive() and os.clock() - tb < 0.3 do RunService.Heartbeat:Wait() end
		TweenService:Create(stage, TweenInfo.new(0.18), { GroupTransparency = 1 }):Play()
		vig.BackgroundTransparency = 1
		while alive() and os.clock() - tb < 0.5 do RunService.Heartbeat:Wait() end
		if not alive() then return end
		-- BOOM: the white hole is born
		stage.GroupTransparency = 0
		pull = 0
		for _, L in ipairs(letters) do L.l.TextTransparency = 1 L.st.Transparency = 1 end
		apiA.SetWhite(true, true)
		apiA.Boost(2.5)
		sA.Scale = 0.3
		scaleTo(sA, 1.7, 1.0, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		bump(26 * k, 0.7)
		shock(0, 1700, 7)
		shock(0.12, 1200, 5)
		shock(0.26, 900, 3)
		sparks(54)
		reveal()
		while alive() and os.clock() - tb < 1.5 do RunService.Heartbeat:Wait() end
		TweenService:Create(stage, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
		TweenService:Create(bg, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		while alive() and os.clock() - tb < 2.9 do RunService.Heartbeat:Wait() end
		cleanup(false)
	end)
	if not okIntro then
		warn("[YADSAN] intro error: " .. tostring(errIntro))
		if introGui then pcall(function() introGui:Destroy() end) end
		reveal()
	elseif not revealed then
		reveal()
	end
end)


local Window = NovaUI:CreateWindow({
	Name = "Celestial Syndicate",
	Theme = "Sun",
	OrbText = "Yadsan x Yakuza",
	Folder = "YADSAN_HUB",
})

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function notify(title, content)
	Window:Notify({ Title = title, Content = content })
end

local function getHum()
	local c = lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local L = {}
local function startLoop(name, event, fn)
	if L[name] then
		L[name]:Disconnect()
	end
	L[name] = event:Connect(fn)
end
local function stopLoop(name)
	if L[name] then
		L[name]:Disconnect()
		L[name] = nil
	end
end

local net
task.spawn(function()
	pcall(function()
		local m = RS:WaitForChild("Modules", 10)
		local core = m:WaitForChild("Core", 10)
		net = require(core:WaitForChild("Net", 10))
	end)
end)

------------------------------------------------------------------------
-- movement
------------------------------------------------------------------------
local flying, flySpeed = false, 60
local flyBV, flyBG

local function stopFly()
	stopLoop("fly")
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local h = getHum()
	if h then
		h.PlatformStand = false
	end
end

local function startFly()
	stopFly()
	local root, h = getRoot(), getHum()
	if not root or not h then
		return
	end
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	flyBG.P = 1e4
	flyBG.CFrame = root.CFrame
	flyBG.Parent = root
	h.PlatformStand = true
	startLoop("fly", RunService.RenderStepped, function()
		local cam = workspace.CurrentCamera
		if not cam or not root.Parent then
			return
		end
		local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
		if look.Magnitude > 0 then look = look.Unit end
		if right.Magnitude > 0 then right = right.Unit end
		local dir = h.MoveDirection
		local fwd, side = dir:Dot(look), dir:Dot(right)
		local vel = (cam.CFrame.LookVector * fwd + cam.CFrame.RightVector * side) * flySpeed
		if UIS:IsKeyDown(Enum.KeyCode.Space) then
			vel = vel + Vector3.new(0, flySpeed, 0)
		end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
			vel = vel - Vector3.new(0, flySpeed, 0)
		end
		flyBV.Velocity = vel
		flyBG.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
	end)
end

------------------------------------------------------------------------
-- world
------------------------------------------------------------------------
local lightSaved
local function nightOn()
	if not lightSaved then
		lightSaved = {
			Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		}
	end
	startLoop("night", RunService.Heartbeat, function()
		Lighting.Brightness = 2
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(190, 190, 190)
		Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
	end)
end
local function nightOff()
	stopLoop("night")
	if lightSaved then
		for k, v in pairs(lightSaved) do
			Lighting[k] = v
		end
		lightSaved = nil
	end
end

local fpsSaved
local function fpsOn()
	fpsSaved = { shadows = Lighting.GlobalShadows, items = {} }
	Lighting.GlobalShadows = false
	task.spawn(function()
		local n = 0
		for _, o in ipairs(workspace:GetDescendants()) do
			if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") or o:IsA("Beam") then
				if o.Enabled and fpsSaved then
					table.insert(fpsSaved.items, o)
					o.Enabled = false
				end
			end
			n = n + 1
			if n % 400 == 0 then
				task.wait()
			end
		end
	end)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") and e.Enabled then
			table.insert(fpsSaved.items, e)
			e.Enabled = false
		end
	end
end
local function fpsOff()
	if fpsSaved then
		Lighting.GlobalShadows = fpsSaved.shadows
		for _, o in ipairs(fpsSaved.items) do
			pcall(function() o.Enabled = true end)
		end
		fpsSaved = nil
	end
end

local streetLights, streetOrig = {}, {}
local function collectStreetLights()
	streetLights, streetOrig = {}, {}
	local n = 0
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("Light") then
			local p, hit = o, false
			for _ = 1, 3 do
				if not p then break end
				local nm = p.Name:lower()
				if nm:find("light") or nm:find("lamp") or nm:find("street") then
					hit = true
					break
				end
				p = p.Parent
			end
			if hit then
				table.insert(streetLights, o)
				streetOrig[o] = o.Color
			end
		end
		n = n + 1
		if n % 400 == 0 then
			task.wait()
		end
	end
end

------------------------------------------------------------------------
-- character
------------------------------------------------------------------------
local rgbSkin, rgbTool, rgbLights = false, false, false
local skinSaved, toolSaved = nil, {}
local hue = 0

local BODY_PROPS = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

RunService.Heartbeat:Connect(function(dt)
	if not (rgbSkin or rgbTool or rgbLights) then
		return
	end
	hue = (hue + dt * 0.25) % 1
	local col = Color3.fromHSV(hue, 1, 1)
	local c = lp.Character
	if c and rgbSkin then
		local bc = c:FindFirstChildOfClass("BodyColors")
		if bc then
			if not skinSaved then
				skinSaved = {}
				for _, k in ipairs(BODY_PROPS) do
					skinSaved[k] = bc[k]
				end
			end
			for _, k in ipairs(BODY_PROPS) do
				bc[k] = col
			end
		end
	end
	if c and rgbTool then
		local tool = c:FindFirstChildOfClass("Tool")
		if tool then
			for _, p in ipairs(tool:GetDescendants()) do
				if p:IsA("BasePart") then
					if not toolSaved[p] then
						toolSaved[p] = p.Color
					end
					p.Color = col
				end
			end
		end
	end
	if rgbLights then
		for _, l in ipairs(streetLights) do
			if l.Parent then
				l.Color = col
			end
		end
	end
end)

local function restoreSkin()
	local c = lp.Character
	local bc = c and c:FindFirstChildOfClass("BodyColors")
	if bc and skinSaved then
		for k, v in pairs(skinSaved) do
			bc[k] = v
		end
	end
	skinSaved = nil
end
local function restoreTool()
	for p, col in pairs(toolSaved) do
		if p.Parent then
			p.Color = col
		end
	end
	toolSaved = {}
end
local function restoreLights()
	for l, col in pairs(streetOrig) do
		if l.Parent then
			l.Color = col
		end
	end
end

local flash = false
task.spawn(function()
	local on = false
	while true do
		task.wait(0.35)
		if flash then
			on = not on
			local c = lp.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = on and 1 or 0
					end
				end
			end
		else
			on = false
		end
	end
end)

local espOn, espColor, espHL = false, Color3.fromRGB(92, 124, 255), {}
local function espClear(p)
	if espHL[p] then
		espHL[p]:Destroy()
		espHL[p] = nil
	end
end
local function espAdd(p)
	espClear(p)
	if p == lp or not espOn or not p.Character then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = espColor
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.55
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = p.Character
	espHL[p] = h
end
local function hookPlayer(p)
	p.CharacterAdded:Connect(function()
		task.wait(0.6)
		espAdd(p)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(espClear)

local antiInvis = false
task.spawn(function()
	while true do
		task.wait(0.5)
		if antiInvis then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp and p.Character then
					for _, part in ipairs(p.Character:GetChildren()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency > 0.9 then
							part.Transparency = 0
						end
					end
				end
			end
		end
	end
end)

local spawnCF
lp.CharacterAdded:Connect(function(c)
	if flying then
		task.wait(1)
		startFly()
	end
	if spawnCF then
		local r = c:WaitForChild("HumanoidRootPart", 8)
		task.wait(0.5)
		if r and r.Parent then
			c:PivotTo(spawnCF)
		end
	end
end)

------------------------------------------------------------------------
-- body size + outfit
------------------------------------------------------------------------
local function myDesc()
	local h = getHum()
	return h and h:GetAppliedDescription()
end

local PART_PROPS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local ANIM_PROPS = { "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation" }

------------------------------------------------------------------------
-- OUTFIT CORE
-- Fast path: ONE batched "wear_outfit_from_desc" call (same as Flames Hub) + skin_tone + body_scale + age.
-- Fallback: the game's own "code" remote per missing item (parallel, 0.02s apart).
------------------------------------------------------------------------
local applySize -- resizer, defined in the next block
NovaUI.Stat = NovaUI.Stat or function() end
local copyReport = {}
local captureItems, captureSkin, captureScale, wearItems
do
	local BODY_PROPS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
	-- { description property, code type }
	local CLOTH_PROPS = { { "Pants", "Pants" }, { "Shirt", "Shirt" }, { "GraphicTShirt", "TShirt" }, { "Face", "Face" } }
	local wearBusy = false

	local function idKey(n)
		return ("%.0f"):format(tonumber(n) or 0)
	end

	local function accBase(a)
		local t = a.AccessoryType
		return (typeof(t) == "EnumItem") and t.Name or tostring(t)
	end

	function captureItems(desc)
		local items = {}
		local function add(id, ty, kind, extra)
			id = tonumber(id)
			if id and id ~= 0 then
				local it = { id = id, type = ty, kind = kind }
				if extra then
					for k, v in pairs(extra) do
						it[k] = v
					end
				end
				items[#items + 1] = it
			end
		end
		local ok, accs = pcall(function()
			return desc:GetAccessories(true)
		end)
		if ok and type(accs) == "table" then
			for _, a in ipairs(accs) do
				local base = accBase(a)
				add(a.AssetId, base:find("Accessory") and base or (base .. "Accessory"), "acc", {
					atype = base:gsub("Accessory$", ""), layered = a.IsLayered and true or false, order = a.Order or 0, puff = a.Puffiness or 0,
				})
			end
		end
		for _, c in ipairs(CLOTH_PROPS) do
			add(desc[c[1]], c[2], "cloth", { prop = c[1] })
		end
		for _, k in ipairs(ANIM_PROPS) do
			add(desc[k], k, "anim", { prop = k })
		end
		for _, k in ipairs(BODY_PROPS) do
			add(desc[k], k, "body", { prop = k })
		end
		return items
	end

	local function avgColors(getter)
		local r, g, b, n = 0, 0, 0, 0
		for _, k in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }) do
			local ok, c = pcall(getter, k)
			if ok and typeof(c) == "Color3" then
				r, g, b, n = r + c.R, g + c.G, b + c.B, n + 1
			end
		end
		if n > 0 then
			return { r / n, g / n, b / n }
		end
	end

	function captureSkin(desc, char)
		local bc = char and char:FindFirstChildOfClass("BodyColors")
		if bc then
			local s = avgColors(function(k)
				return bc[k .. "Color3"]
			end)
			if s then
				return s
			end
		end
		return avgColors(function(k)
			return desc[k .. "Color"]
		end)
	end

	function captureScale(desc)
		local function g(k, d)
			local ok, v = pcall(function()
				return desc[k]
			end)
			return (ok and tonumber(v)) or d
		end
		return { g("HeightScale", 1), g("WidthScale", 1), g("HeadScale", 1), g("DepthScale", g("WidthScale", 1)), g("BodyTypeScale", 0), g("ProportionScale", 0) }
	end

	local function wornSet()
		local d = myDesc()
		if not d then
			return nil
		end
		local s = {}
		local ok, accs = pcall(function()
			return d:GetAccessories(true)
		end)
		if ok and type(accs) == "table" then
			for _, a in ipairs(accs) do
				s["acc" .. idKey(a.AssetId)] = true
			end
		end
		for _, c in ipairs(CLOTH_PROPS) do
			s[c[2] .. idKey(d[c[1]])] = true
		end
		for _, k in ipairs(ANIM_PROPS) do
			s[k .. idKey(d[k])] = true
		end
		for _, k in ipairs(BODY_PROPS) do
			s[k .. idKey(d[k])] = true
		end
		return s
	end

	local function isWorn(s, it)
		if it.kind == "acc" then
			return s["acc" .. idKey(it.id)] == true
		end
		return s[it.type .. idKey(it.id)] == true
	end

	local function zeroProps()
		local p = {}
		for _, k in ipairs({ "Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
			"WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "IdleAnimation", "SwimAnimation" }) do
			p[k] = 0
		end
		p.HeightScale, p.HeadScale, p.WidthScale, p.DepthScale, p.ProportionScale, p.BodyTypeScale = 1, 1, 1, 1, 0, 0
		return p
	end

	local function clearOutfit()
		if not net then
			return
		end
		local function slot(t, layered, order)
			return { Rotation = "  ", Position = "  ", Scale = "1 1 1", AccessoryType = t, IsLayered = layered, AssetId = 0, Order = order, Puffiness = 0 }
		end
		local accs = { slot("Hair", false), slot("Face", false), slot("Hat", false), slot("Shirt", true, 1), slot("DressSkirt", true, 2), slot("RightShoe", true, 3), slot("LeftShoe", true, 4) }
		pcall(function()
			net.send("wear_outfit_from_desc", { accessories = accs, properties = zeroProps() })
		end)
		task.wait(0.2)
	end

	local function buildBatch(items, scale)
		local accs, props = {}, zeroProps()
		for _, it in ipairs(items) do
			if it.kind == "acc" then
				accs[#accs + 1] = {
					Rotation = "  ", Position = "  ", Scale = "1 1 1", IsLayered = it.layered or false,
					AccessoryType = it.atype or tostring(it.type):gsub("Accessory$", ""), AssetId = it.id, Order = it.order or 0, Puffiness = it.puff or 0,
				}
			elseif it.prop then
				props[it.prop] = it.id
			end
		end
		if scale then
			props.HeightScale, props.WidthScale, props.HeadScale = scale[1] or 1, scale[2] or 1, scale[3] or 1
			props.DepthScale = scale[4] or scale[2] or 1
			props.BodyTypeScale, props.ProportionScale = scale[5] or 0, scale[6] or 0
		end
		return { accessories = accs, properties = props }
	end

	-- items = { {id=, type=, kind=, ...}, ... }, skin = {r, g, b} or nil, onProgress(i, n) optional,
	-- extra = { scale = {h, w, head, depth, bodytype, proportion}, age = number }  (if scale is nil your own size is kept)
	function wearItems(items, skin, who, onProgress, extra)
		if wearBusy then
			return false, "Already busy, wait a moment"
		end
		if not net then
			return false, "Game network module not found (this only works inside Life Together RP)"
		end
		if type(items) ~= "table" or #items == 0 then
			return false, "Nothing to wear (empty outfit)"
		end
		extra = extra or {}
		if NovaUI.beforeWear then pcall(NovaUI.beforeWear) end
		wearBusy = true
		copyReport = { "Target: " .. tostring(who), "Items: " .. #items }
		local t0 = os.clock()
		local scale = extra.scale
		if not scale then
			local prev = myDesc()
			if prev then
				scale = captureScale(prev)
			end
		end
		local failedCalls = 0
		local verified, missing = false, {}
		local okRun, errRun = pcall(function()
			clearOutfit()
			-- 1) ONE batched call with the whole outfit
			pcall(function()
				net.send("wear_outfit_from_desc", buildBatch(items, scale))
			end)
			task.wait(0.25)
			local function check()
				local s = wornSet()
				if not s then
					return nil
				end
				local miss = {}
				for _, it in ipairs(items) do
					if not isWorn(s, it) then
						miss[#miss + 1] = it
					end
				end
				return miss
			end
			missing = check()
			verified = missing ~= nil
			missing = missing or {}
			copyReport[#copyReport + 1] = ("batch: %d/%d applied"):format(#items - #missing, #items)
			if onProgress then
				pcall(onProgress, #items - #missing, #items)
			end
			-- 2) anything the batch did not apply goes through the "code" remote (parallel, 0.02s apart)
			if #missing > 0 then
				local done = 0
				local missList = missing
				for _, it in ipairs(missList) do
					task.spawn(function()
						local okc, res = pcall(function()
							return net.get("code", it.id, it.type)
						end)
						if not okc or res == false then
							failedCalls = failedCalls + 1
							copyReport[#copyReport + 1] = ("code %s %s -> %s"):format(it.type, idKey(it.id), okc and "false" or tostring(res))
						end
						done = done + 1
					end)
					task.wait(0.02)
				end
				local w0 = os.clock()
				while done < #missList and os.clock() - w0 < 4 do
					task.wait(0.03)
				end
				task.wait(0.3)
				missing = check() or missing
			end
		end)
		if not okRun then
			copyReport[#copyReport + 1] = "run error: " .. tostring(errRun)
		end
		for _, it in ipairs(missing) do
			copyReport[#copyReport + 1] = ("missing: %s %s"):format(it.type, idKey(it.id))
		end

		-- skin colour + body scale + age (sent last so nothing overwrites them)
		if skin then
			pcall(function()
				net.send("skin_tone", Color3.new(skin[1], skin[2], skin[3]))
			end)
			task.wait(0.03)
			pcall(function()
				net.send("skin_tone", skin[1], skin[2], skin[3])
			end)
		end
		if scale and extra.scale then
			local h = math.clamp(math.floor((scale[1] or 1) * 100 + 0.5), 90, 105)
			local w = math.clamp(math.floor((scale[2] or 1) * 100 + 0.5), 70, 100)
			pcall(function()
				net.send("body_scale", "HeightScale", h)
			end)
			task.wait(0.05)
			pcall(function()
				net.send("body_scale", "WidthScale", w)
			end)
		end
		if extra.age then
			pcall(function()
				net.get("age", extra.age)
			end)
		end
		wearBusy = false

		local worn = verified and (#items - #missing) or #items
		local detail = ("%d/%d items worn in %.2fs"):format(worn, #items, os.clock() - t0)
		if not verified then
			detail = ("%d items sent (could not verify)"):format(#items)
		end
		copyReport[#copyReport + 1] = detail
		if verified and worn == 0 then
			return false, "Server did not apply any item (" .. failedCalls .. " call errors) - use Exploits > Copy fit report"
		end
		NovaUI.Stat("copies")
		return true, detail
	end
end


local function avgSkin(hum)
	local bc = hum and hum.Parent and hum.Parent:FindFirstChildOfClass("BodyColors")
	if not bc then
		return nil
	end
	local cols = { bc.HeadColor3, bc.TorsoColor3, bc.LeftArmColor3, bc.RightArmColor3, bc.LeftLegColor3, bc.RightLegColor3 }
	local r, g, b = 0, 0, 0
	for _, c in ipairs(cols) do
		r, g, b = r + c.R, g + c.G, b + c.B
	end
	return Color3.new(r / 6, g / 6, b / 6)
end

local function sendOutfit(outfit, skin)
	local ok, err = pcall(function()
		net.send("wear_outfit_from_desc", outfit)
	end)
	if not ok then
		return false, err
	end
	if skin then
		task.wait(0.03)
		pcall(function()
			net.send("skin_tone", skin)
		end)
	end
	return true
end

-- ========== Yadsan Papa (per Celestial Frostbite X re-sizer: full description + new scales through wear_outfit_from_desc) ==========
local function serializeDesc(d)
	local P = {}
	for _, k in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face", "Shirt", "Pants", "GraphicTShirt",
		"RunAnimation", "WalkAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "IdleAnimation", "SwimAnimation" }) do
		P[k] = d[k] or 0
	end
	for _, k in ipairs({ "HeightScale", "WidthScale", "DepthScale", "HeadScale" }) do
		P[k] = d[k] or 1
	end
	P.BodyTypeScale = d.BodyTypeScale or 0
	P.ProportionScale = d.ProportionScale or 0
	local out = { accessories = {}, properties = P }
	pcall(function()
		for _, a in ipairs(d:GetAccessories(true)) do
			out.accessories[#out.accessories + 1] = {
				Rotation = "0 0 0", Position = "0 0 0", Scale = "1 1 1", IsLayered = a.IsLayered,
				AccessoryType = a.AccessoryType.Name, AssetId = a.AssetId, Order = a.Order or 0, Puffiness = a.Puffiness or 0,
			}
		end
	end)
	return out
end

function applySize(hs, ws, hds, skinOverride, ds)
	hds = hds or hs
	ds = ds or ws
	local h = getHum()
	if not h then
		return false, "Character not found"
	end
	local localOk = false
	for name, v in pairs({ BodyHeightScale = hs, BodyWidthScale = ws, BodyDepthScale = ds, HeadScale = hds }) do
		local o = h:FindFirstChild(name)
		if o and o:IsA("NumberValue") then
			o.Value = v
			localOk = true
		end
	end
	if net then
		local skin = avgSkin(h)
		local skinF
		if type(skinOverride) == "table" then
			skin = Color3.new(skinOverride[1], skinOverride[2], skinOverride[3])
			skinF = skinOverride
		end
		local okd, d = pcall(function()
			return h:GetAppliedDescription()
		end)
		if okd and d then
			local data = serializeDesc(d)
			data.properties.HeightScale = hs
			data.properties.WidthScale = ws
			data.properties.DepthScale = ds
			data.properties.HeadScale = hds
			local ok = pcall(function()
				net.send("wear_outfit_from_desc", data)
			end)
			if ok then
				task.wait(0.15)
				if skin then
					pcall(function()
						net.send("skin_tone", skin)
					end)
				end
				if skinF then
					task.wait(0.05)
					pcall(function()
						net.send("skin_tone", skinF[1], skinF[2], skinF[3])
					end)
				end
				return true, string.format("H=%.1f W=%.1f Head=%.1f", hs, ws, hds)
			end
		end
	end
	if localOk then
		return true, "Size applied (local only)"
	end
	return false, "Could not apply: Net module and scale values not found"
end

-- the AUTH0R auto formulas
local function autoW(s)
	if s <= 1 then return 1 end
	return math.max(1, math.floor(1 + (s - 1) * 1.34 + 0.5))
end
local function autoHead(s)
	if s <= 1 then return 1 end
	return math.max(1, math.floor(s + 0.5))
end

local sizeH, sizeW, sizeHead = 1, 1, 1

------------------------------------------------------------------------
-- avatar tools
------------------------------------------------------------------------
local target
local function needTarget()
	if not target or not target.Parent then
		notify("Select a player", "Pick someone from the list first.")
		return nil
	end
	return target
end

-- ========== SYNC ANIM (rewritten) ==========
-- Mirrors every animation track the target is playing, with matching speed/weight/time.
local syncConn, syncTracks, syncChar, animateWas = nil, {}, nil, nil

local function dropSyncTracks()
	for id, t in pairs(syncTracks) do
		pcall(function()
			t:Stop(0.15)
			t:Destroy()
		end)
		syncTracks[id] = nil
	end
end

local function stopSync()
	if syncConn then
		syncConn:Disconnect()
		syncConn = nil
	end
	dropSyncTracks()
	local an = syncChar and syncChar.Parent and syncChar:FindFirstChild("Animate")
	if an and animateWas ~= nil then
		an.Disabled = animateWas
	end
	animateWas, syncChar = nil, nil
end

local function startSync(getTarget, onLost)
	stopSync()
	local acc = 0
	syncConn = RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.08 then
			return
		end
		acc = 0
		local p = getTarget()
		if not p or not p.Parent then
			stopSync()
			if onLost then
				onLost()
			end
			return
		end
		local mc = lp.Character
		local mh = getHum()
		local ma = mh and mh:FindFirstChildOfClass("Animator")
		if not (mc and ma) then
			return
		end
		if mc ~= syncChar then
			dropSyncTracks()
			syncChar = mc
			local an = mc:FindFirstChild("Animate")
			if an then
				animateWas = an.Disabled
				an.Disabled = true
			end
			for _, t in ipairs(ma:GetPlayingAnimationTracks()) do
				t:Stop(0.1)
			end
		end
		local th = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local ta = th and th:FindFirstChildOfClass("Animator")
		if not ta then
			return
		end
		local playing = {}
		for _, tr in ipairs(ta:GetPlayingAnimationTracks()) do
			local id = tr.Animation and tr.Animation.AnimationId
			if id and id ~= "" and tr.WeightCurrent > 0.01 then
				playing[id] = true
				local mt = syncTracks[id]
				if not mt then
					local a = Instance.new("Animation")
					a.AnimationId = id
					local ok, t = pcall(function()
						return ma:LoadAnimation(a)
					end)
					if ok and t then
						local pr = tr.Priority
						t.Priority = (pr == Enum.AnimationPriority.Core or pr == Enum.AnimationPriority.Idle or pr == Enum.AnimationPriority.Movement) and Enum.AnimationPriority.Action or Enum.AnimationPriority.Action4
						t.Looped = tr.Looped
						t:Play(0.1, math.max(tr.WeightCurrent, 0.01), tr.Speed)
						pcall(function()
							t.TimePosition = tr.TimePosition
						end)
						syncTracks[id] = t
					end
				else
					if not mt.IsPlaying then
						mt:Play(0.1, math.max(tr.WeightCurrent, 0.01), tr.Speed)
					end
					mt:AdjustSpeed(tr.Speed)
					mt:AdjustWeight(math.max(tr.WeightCurrent, 0.01), 0.1)
					if math.abs(mt.TimePosition - tr.TimePosition) > 0.35 then
						pcall(function()
							mt.TimePosition = tr.TimePosition
						end)
					end
				end
			end
		end
		for id, t in pairs(syncTracks) do
			if not playing[id] then
				pcall(function()
					t:Stop(0.15)
					t:Destroy()
				end)
				syncTracks[id] = nil
			end
		end
	end)
end

-- ========== FIT COPIER (code remote, same method as the original working copier) ==========
local function optedOut(p)
	local function flag(o)
		local ok, v = pcall(function()
			return o:GetAttribute("hide_view_outfit")
		end)
		return ok and v == true
	end
	if flag(p) or (p.Character and flag(p.Character)) then
		return true
	end
	local ok, bio = pcall(function()
		return p:GetAttribute("bio")
	end)
	if ok and type(bio) == "string" then
		local b = bio:lower()
		if b:find("anti%s*%-?%s*steal") or b:find("anti%s*%-?%s*copy") or b:find("no%s*copy") then
			return true
		end
	end
	return false
end

local function copyAvatar(p)
	if p and optedOut(p) then
		return false, p.DisplayName .. " hides their outfit (privacy setting), not copied"
	end
	if not p or not p.Character then
		return false, "Target character not loaded"
	end
	local th = p.Character:FindFirstChildOfClass("Humanoid") or p.Character:WaitForChild("Humanoid", 3)
	if not th then
		return false, "Target Humanoid not found"
	end
	local okd, td = pcall(function()
		return th:GetAppliedDescription()
	end)
	if not okd or not td then
		return false, "Could not read their outfit"
	end
	return wearItems(captureItems(td), captureSkin(td, p.Character), p.Name, nil, { scale = captureScale(td), age = p:GetAttribute("age") })
end

------------------------------------------------------------------------
-- STAFF TITLES (winged swirl title like the MKnight/24H script, matched by USERNAME)
-- Only people running YADSAN HUB see these.
------------------------------------------------------------------------
local roleOf
do
local TAGS = {
	ZMxCS_Yakuza7 = { title = "HUB ADMIN", colors = { Color3.fromRGB(255, 150, 150), Color3.fromRGB(150, 24, 60) } },
	AGKaBaap_YadsanAsuka = { title = "HUB OWNER", colors = { Color3.new(1, 1, 1), Color3.fromRGB(125, 201, 245) } },
}
local titleGui = Instance.new("ScreenGui")
titleGui.Name = "YadsanTitles"
titleGui.ResetOnSpawn = false
titleGui.Parent = Window.Gui.Parent
local titleAnims, titleBoards = {}, {}
RunService.RenderStepped:Connect(function()
	local t = os.clock() * 60
	for i = #titleAnims, 1, -1 do
		local a = titleAnims[i]
		if not a.board.Parent then
			table.remove(titleAnims, i)
		else
			local s, c = math.sin(t / 20), math.cos(t / 20)
			a.left.Rotation = 180 - 10 * s
			a.right.Rotation = 10 * s
			a.lt.Rotation, a.lm.Rotation, a.lb.Rotation = 120 + 7 * c, 90 + 7 * c, 60 + 7 * c
			a.rt.Rotation, a.rm.Rotation, a.rb.Rotation = 120 - 7 * c, 90 - 7 * c, 60 - 7 * c
			a.swirl.Rotation = -t
			a.spin.Rotation = t * 2
			a.whoG.Rotation = 180 + t / 1.125
			a.titleG.Rotation = -t / 1.125
		end
	end
end)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function sarpanch(o)
	pcall(function()
		o.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
	end)
end

local function buildBoard(name, info)
	local col = info.colors[1]
	local seq = ColorSequence.new(info.colors[1], info.colors[2])
	local half = Vector2.new(0.5, 0.5)
	local bb = mk("BillboardGui", { AlwaysOnTop = true, StudsOffsetWorldSpace = Vector3.new(0, 5, 0), Size = UDim2.new(8.75, 0, 8.75, 0), ResetOnSpawn = false }, titleGui)
	local main = mk("Frame", { AnchorPoint = half, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, bb)
	local a = { board = bb }
	local function side(posX, isLeft)
		local fr = mk("Frame", { ZIndex = -2, AnchorPoint = half, Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(posX, 0.5), Rotation = isLeft and 180 or 0, BackgroundTransparency = 1, BorderSizePixel = 0 }, main)
		local wings = mk("Frame", { ZIndex = -1, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, fr)
		local function arm(rot, px, py)
			local im = mk("ImageLabel", { BorderSizePixel = 0, ImageColor3 = col, AnchorPoint = Vector2.new(1, 0.5), Image = "rbxassetid://14221272033", Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Rotation = rot, Position = UDim2.fromScale(px, py) }, wings)
			mk("UIGradient", { Rotation = -90, Color = seq }, im)
			return im
		end
		local m, t, b = arm(90, 0.75, 0.5), arm(120, 0.8, 0.15), arm(60, 0.8, 0.85)
		return fr, t, m, b
	end
	a.left, a.lt, a.lm, a.lb = side(0.4, true)
	a.right, a.rt, a.rm, a.rb = side(0.6, false)
	local infoF = mk("Frame", { BorderSizePixel = 0, AnchorPoint = half, Size = UDim2.fromScale(0.35, 0.35), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, main)
	a.swirl = mk("ImageLabel", { ZIndex = 4, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ImageColor3 = col, AnchorPoint = half, Image = "rbxassetid://12363692920", Size = UDim2.fromScale(1.15, 1.15), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	local who = mk("TextLabel", { TextWrapped = true, ZIndex = 5, BorderSizePixel = 0, TextScaled = true, TextColor3 = col, BackgroundTransparency = 1, AnchorPoint = half, Size = UDim2.fromScale(1.25, 0.35), Position = UDim2.fromScale(0.5, 0.25), Text = name }, infoF)
	sarpanch(who)
	a.whoG = mk("UIGradient", { Color = seq }, who)
	mk("UIStroke", {}, who)
	local ttl = mk("TextLabel", { TextWrapped = true, ZIndex = 5, BorderSizePixel = 0, TextScaled = true, TextColor3 = col, BackgroundTransparency = 1, AnchorPoint = half, Size = UDim2.fromScale(1.25, 0.35), Position = UDim2.fromScale(0.5, 0.675), Text = info.title }, infoF)
	sarpanch(ttl)
	a.titleG = mk("UIGradient", { Color = seq }, ttl)
	mk("UIStroke", {}, ttl)
	mk("ImageLabel", { ZIndex = 3, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ImageColor3 = col, ResampleMode = Enum.ResamplerMode.Pixelated, AnchorPoint = half, Image = "rbxassetid://13273852131", Size = UDim2.fromScale(1.25, 1.25), BackgroundTransparency = 1, Rotation = 45, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	a.spin = mk("ImageLabel", { BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ImageColor3 = col, AnchorPoint = half, Image = "rbxassetid://9563796105", Size = UDim2.fromScale(1.25, 1.25), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	mk("ImageLabel", { ZIndex = 2, BorderSizePixel = 0, ImageColor3 = col, ResampleMode = Enum.ResamplerMode.Pixelated, AnchorPoint = half, Image = "rbxassetid://108982568848492", Size = UDim2.fromScale(2, 1.4), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	titleAnims[#titleAnims + 1] = a
	return bb
end

local function tagPlayer(p)
	local info = TAGS[p.Name:lower()]
	if not info or titleBoards[p] then
		return
	end
	local bb = buildBoard(p.Name, info)
	titleBoards[p] = bb
	local function attach(c)
		local hrp = c:WaitForChild("HumanoidRootPart", 10)
		if hrp and bb.Parent then
			bb.Adornee = hrp
		end
	end
	if p.Character then
		task.spawn(attach, p.Character)
	end
	p.CharacterAdded:Connect(function(c)
		task.spawn(attach, c)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	tagPlayer(p)
end
Players.PlayerAdded:Connect(tagPlayer)
Players.PlayerRemoving:Connect(function(p)
	local bb = titleBoards[p]
	if bb then
		bb:Destroy()
		titleBoards[p] = nil
	end
end)
roleOf = function(name)
	local i = TAGS[tostring(name):lower()]
	if not i then
		return nil
	end
	return i.title:find("OWNER") and "OWNER" or "ADMIN"
end
end
local espToggle
------------------------------------------------------------------------
-- feature switches (used by the Home tiles and by commands)
------------------------------------------------------------------------
local runCommand
local function setFly(v)
	flying = v
	if v then startFly() else stopFly() end
end
local function setNoclip(v)
	if v then
		startLoop("noclip", RunService.Stepped, function()
			local c = lp.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanCollide = false
					end
				end
			end
		end)
	else
		stopLoop("noclip")
	end
end
local function setInfJump(v)
	stopLoop("infjump")
	if v then
		L.infjump = UIS.JumpRequest:Connect(function()
			local h = getHum()
			if h then
				h:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end
local function setAntiFling(v)
	if v then
		startLoop("antifling", RunService.Stepped, function()
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp and p.Character then
					for _, part in ipairs(p.Character:GetChildren()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end
			local r = getRoot()
			if r and r.AssemblyLinearVelocity.Magnitude > 250 then
				r.AssemblyLinearVelocity = Vector3.zero
				r.AssemblyAngularVelocity = Vector3.zero
			end
		end)
	else
		stopLoop("antifling")
	end
end
local function setNight(v)
	if v then nightOn() else nightOff() end
end
local function setFps(v)
	if v then fpsOn() else fpsOff() end
end

------------------------------------------------------------------------
-- HOME  (Hub Interface + game card)
------------------------------------------------------------------------
local Home = Window:CreateTab({ Name = "Home", Icon = "🏠" })

local hubSec = Home:Section({ Title = "Hub Interface", Icon = "grid", Side = "Left" })
local tiles = hubSec:Actions({
	{ Title = "Fly", Description = "Off", Icon = "✈️", Toggle = true, Flag = "Fly", Callback = setFly },
	{ Title = "Noclip", Description = "Off", Icon = "👻", Toggle = true, Flag = "Noclip", Callback = setNoclip },
	{ Title = "Infinite Jump", Description = "Off", Icon = "😬", Toggle = true, Flag = "InfJump", Callback = setInfJump },
	{ Title = "Anti Fling", Description = "Off", Icon = "🛡️", Toggle = true, Flag = "AntiFling", Callback = setAntiFling },
	{ Title = "Night Vision", Description = "Off", Icon = "🌚", Toggle = true, Flag = "NightVision", Callback = setNight },
	{ Title = "FPS Boost", Description = "Off", Icon = "🏁", Toggle = true, Flag = "FPSBoost", Callback = setFps },
})

local move = Home:Section({ Title = "Movement", Icon = "bolt", Side = "Left" })
move:Slider({ Title = "Fly speed", Min = 10, Max = 200, Default = 60, Increment = 5, Flag = "FlySpeed", Callback = function(v) flySpeed = v end })
move:Keybind({ Title = "Fly key", Default = Enum.KeyCode.F, Flag = "FlyKey", Callback = function() tiles["Fly"]:Set(not tiles["Fly"]:Get()) end })

local gameSec = Home:Section({ Title = "Now Playing", Icon = "game", Side = "Right" })
gameSec:GameCard()

local world = Home:Section({ Title = "World", Icon = "☀️", Side = "Right" })
world:Slider({ Title = "Time of day", Min = 0, Max = 24, Default = math.floor(Lighting.ClockTime), Increment = 1, Suffix = "h", Flag = "ClockTime", Callback = function(v)
	Lighting.ClockTime = v
end })

local quick = Home:Section({ Title = "Quick Commands", Icon = "🌡️", Side = "Left" })
quick:Actions({
	{ Title = "Commands", Description = "Open tab", Icon = "🌡️", Callback = function() Window:SelectTab("Commands") end },
	{ Title = "Fullbright", Description = "Light up", Icon = "☀️", Callback = function() runCommand("fullbright") end },
	{ Title = "Reset", Description = "Respawn", Icon = "🔃", Callback = function() runCommand("reset") end },
	{ Title = "Rejoin", Description = "Same server", Icon = "🚪", Callback = function() runCommand("rejoin") end },
})

------------------------------------------------------------------------
-- HOME hero card (centre column, only when the window is wide enough)
------------------------------------------------------------------------
do
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.AnchorPoint = Vector2.new(0.5, 0)
	hero.Position = UDim2.new(0.5, 0, 0, 318)
	hero.Size = UDim2.fromOffset(280, 236)
	hero.BackgroundColor3 = Color3.fromRGB(14, 8, 26)
	hero.BackgroundTransparency = 0.25
	hero.Visible = false
	hero.Parent = Home.Page
	Instance.new("UICorner", hero).CornerRadius = UDim.new(0, 18)
	local hs = Instance.new("UIStroke")
	hs.Color = Color3.fromRGB(150, 70, 255)
	hs.Transparency = 0.55
	hs.Parent = hero
	local hg = Instance.new("UIGradient")
	hg.Rotation = 90
	hg.Color = ColorSequence.new(Color3.fromRGB(30, 14, 56), Color3.fromRGB(8, 4, 16))
	hg.Parent = hero
	local av = Instance.new("ImageLabel")
	av.Size = UDim2.fromOffset(96, 96)
	av.AnchorPoint = Vector2.new(0.5, 0)
	av.Position = UDim2.new(0.5, 0, 0, 14)
	av.BackgroundColor3 = Color3.fromRGB(24, 14, 42)
	av.Parent = hero
	Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)
	local avs = Instance.new("UIStroke")
	avs.Color = Color3.fromRGB(190, 130, 255)
	avs.Thickness = 2
	avs.Parent = av
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then av.Image = url end
	end)
	local function lbl(text, y, size, color, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, -24, 0, size + 4)
		l.Font = font or Enum.Font.GothamMedium
		l.TextSize = size
		l.TextColor3 = color
		l.Text = text
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = hero
		return l
	end
	lbl(lp.DisplayName, 120, 18, Color3.fromRGB(240, 228, 255), Enum.Font.GothamBold)
	lbl("@" .. lp.Name, 143, 12, Color3.fromRGB(140, 118, 186))
	local role = roleOf(lp.Name) or "MEMBER"
	local rc = role == "OWNER" and Color3.fromRGB(255, 202, 74) or (role == "ADMIN" and Color3.fromRGB(255, 96, 96) or Color3.fromRGB(190, 130, 255))
	lbl(role, 166, 13, rc, Enum.Font.GothamBlack)
	local exec = "Unknown executor"
	pcall(function() exec = identifyexecutor() end)
	lbl(tostring(exec) .. "  |  " .. #Players:GetPlayers() .. " online", 192, 12, Color3.fromRGB(140, 118, 186))
	local function fit()
		local sc = 1
		pcall(function() sc = Window._main.Parent:FindFirstChildOfClass("UIScale").Scale end)
		hero.Visible = (Window._main.AbsoluteSize.X / sc) >= 960
	end
	Window._main:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

------------------------------------------------------------------------
-- ambient starfield behind the whole window (cheap tween loops)
------------------------------------------------------------------------
do
	local TS = game:GetService("TweenService")
	local layer = Instance.new("Frame")
	layer.Name = "YadsanStars"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.new(1, -24, 1, -24)
	layer.Position = UDim2.fromOffset(12, 12)
	layer.ClipsDescendants = true
	layer.ZIndex = 0
	layer.Active = false
	layer.Parent = Window._main
	local rnd = Random.new()
	for i = 1, 44 do
		local s = Instance.new("Frame")
		local sz = rnd:NextInteger(1, 3)
		s.Size = UDim2.fromOffset(sz, sz)
		local x, y = rnd:NextNumber(), rnd:NextNumber()
		s.Position = UDim2.fromScale(x, y)
		s.BackgroundColor3 = (i % 4 == 0) and Color3.fromRGB(200, 160, 255) or Color3.new(1, 1, 1)
		s.BackgroundTransparency = rnd:NextNumber(0.55, 0.9)
		s.BorderSizePixel = 0
		s.ZIndex = 0
		s.Parent = layer
		TS:Create(s, TweenInfo.new(rnd:NextNumber(1.2, 3.2), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rnd:NextNumber(0, 2)), { BackgroundTransparency = 0.97 }):Play()
		TS:Create(s, TweenInfo.new(rnd:NextNumber(9, 20), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(math.clamp(x + rnd:NextNumber(-0.05, 0.05), 0, 1), math.clamp(y + rnd:NextNumber(-0.08, 0.08), 0, 1)) }):Play()
	end
end


------------------------------------------------------------------------
-- AVATAR
------------------------------------------------------------------------
local Avatar = Window:CreateTab({ Name = "Avatar", Icon = "👤" })

local pinfo
local listSec = Avatar:Section({ Title = "Avatar Copying", Side = "Left" })
listSec:PlayerList({ Height = 330, Callback = function(p)
	target = p
	if pinfo then
		pinfo:Set(p)
	end
end })

local actSec = Avatar:Section({ Side = "Right" })
pinfo = actSec:PlayerInfo({ Range = 60 })

local act
local syncing = false
local hideOn = false
task.spawn(function()
	while true do
		task.wait(0.3)
		if hideOn and target and target.Character then
			for _, p in ipairs(target.Character:GetDescendants()) do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 1
				end
			end
		end
	end
end)
act = actSec:Actions({
	{ Title = "Copy Avatar", Description = "Wear their look", Icon = "👤", Callback = function()
		local p = needTarget()
		if not p then return end
		task.spawn(function()
			local ok, d = copyAvatar(p)
			notify(ok and "Copy Avatar" or "Copy Avatar failed", ok and ("Copied " .. p.DisplayName .. ": " .. tostring(d)) or tostring(d))
		end)
	end },
	{ Title = "Sync Anim", Description = "Off", Icon = "🎮", Toggle = true, Callback = function(v)
		if v then
			if not needTarget() then
				act["Sync Anim"]:Set(false, true)
				return
			end
			startSync(function() return target end, function() act["Sync Anim"]:Set(false, true) end)
		else
			stopSync()
		end
	end },
	{ Title = "Spectate", Description = "Off", Icon = "👁️", Toggle = true, Callback = function(v)
		local cam = workspace.CurrentCamera
		if v then
			local p = needTarget()
			local th = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if not th then
				act["Spectate"]:Set(false, true)
				return
			end
			cam.CameraSubject = th
		else
			local h = getHum()
			if h then
				cam.CameraSubject = h
			end
		end
	end },
	{ Title = "Hide", Description = "Off", Icon = "👀", Toggle = true, Callback = function(v)
		hideOn = v
		if v then
			if not needTarget() then
				hideOn = false
				act["Hide"]:Set(false, true)
			end
		else
			local c = target and target.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end },
	{ Title = "Go To", Description = "Teleport next to them", Icon = "⚡", Callback = function()
		local p = needTarget()
		local tr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local r = getRoot()
		if tr and r then
			r.CFrame = tr.CFrame * CFrame.new(0, 0, 3)
		end
	end },
	{ Title = "Copy Emote", Description = "Mimic them for 8s", Icon = "⭐", Callback = function()
		local p = needTarget()
		if not p then return end
		act["Sync Anim"]:Set(true)
		task.delay(8, function()
			act["Sync Anim"]:Set(false)
		end)
	end },
	{ Title = "Stop Anim", Description = "Stop copied anims", Icon = "❌", Callback = function()
		act["Sync Anim"]:Set(false)
	end },
})

------------------------------------------------------------------------
-- FEATURES
------------------------------------------------------------------------
local Features = Window:CreateTab({ Name = "Features", Icon = "feature" })

local char = Features:Section({ Title = "Character", Icon = "👤", Side = "Left" })
char:Toggle({ Title = "RGB Skin", Description = "Cycle your skin tone (only you see it)", Icon = "🔮", Flag = "RGBSkin", Callback = function(v)
	rgbSkin = v
	if not v then restoreSkin() end
end })
char:Toggle({ Title = "RGB Tool", Description = "Cycle your tool color (only you see it)", Icon = "🔮", Flag = "RGBTool", Callback = function(v)
	rgbTool = v
	if not v then restoreTool() end
end })
char:Toggle({ Title = "Flash Invisible", Description = "Blink your character (only you see it)", Icon = "eye", Flag = "FlashInvis", Callback = function(v)
	flash = v
	if not v then
		local c = lp.Character
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 0
				end
			end
		end
	end
end })

local body = Features:Section({ Title = "Body Size", Icon = "settings", Side = "Left" })
local autoScale = true
local function sizeNote(ok, msg, label)
	notify(ok and "Body Size" or "Body Size failed", ok and (label or msg) or tostring(msg))
end
local function applyHeight(hh, label)
	local ww, hd = sizeW, sizeHead
	if autoScale then
		ww, hd = autoW(hh), autoHead(hh)
	end
	task.spawn(function()
		local ok, e = applySize(hh, ww, hd)
		sizeNote(ok, e, label or string.format("H %s  W %s  Head %s", hh, ww, hd))
	end)
end
body:Toggle({ Title = "Auto width + head", Description = "Width/head follow height (AUTH0R formula)", Icon = "ruler", Default = true, Flag = "SizeAuto", Callback = function(v)
	autoScale = v
end })
body:Input({ Placeholder = "Height (0.1 - 10000), type & enter", Numeric = true, Callback = function(t)
	local n = tonumber(t)
	if not n then return end
	n = math.clamp(n, 0.1, 10000)
	sizeH = n
	applyHeight(n)
end })
body:Slider({ Title = "Height", Min = 0.1, Max = 100, Default = 1, Increment = 0.1, Suffix = "x", Flag = "SizeH", Callback = function(v) sizeH = v end })
body:Slider({ Title = "Width", Min = 0.1, Max = 100, Default = 1, Increment = 0.1, Suffix = "x", Flag = "SizeW", Callback = function(v) sizeW = v end })
body:Slider({ Title = "Head", Min = 0.1, Max = 100, Default = 1, Increment = 0.1, Suffix = "x", Flag = "SizeHead", Callback = function(v) sizeHead = v end })
body:Button({ Title = "Apply size", Style = "Primary", Callback = function()
	applyHeight(sizeH)
end })
body:Button({ Title = "Reset size", Callback = function()
	task.spawn(function()
		local ok, e = applySize(1, 1, 1)
		sizeNote(ok, e, "Back to normal")
	end)
end })

local SIZE_PRESETS = {
	{ "Normal", 1, 1, 1, "user" }, { "Tall", 3, 4, 3, "ruler" }, { "Giant", 6, 8, 6, "stand" }, { "Titan", 15, 20, 15, "flame" },
	{ "Mega", 30, 40, 30, "rocket" }, { "Short", 0.6, 1, 0.8, "minus" }, { "Custom 59", 59, 79, 59, "star" }, { "Big Head", 1, 1, 3, "eye" },
	{ "Small Head", 3, 4, 1, "eye" }, { "Chonky", 2, 4, 2, "user" }, { "Wide", 1, 5, 1, "ruler" },
}
local presetActs = {}
for _, p in ipairs(SIZE_PRESETS) do
	presetActs[#presetActs + 1] = { Title = p[1], Description = string.format("H%s W%s Hd%s", p[2], p[3], p[4]), Icon = p[5], Callback = function()
		task.spawn(function()
			local ok, e = applySize(p[2], p[3], p[4])
			sizeNote(ok, e, p[1])
		end)
	end }
end
body:Actions(presetActs)


local util = Features:Section({ Title = "Utility", Icon = "settings", Side = "Right" })
espToggle = util:Toggle({ Title = "Player ESP", Description = "Highlight everyone through walls", Icon = "👁️", Flag = "ESP", Callback = function(v)
	espOn = v
	for _, p in ipairs(Players:GetPlayers()) do
		if v then espAdd(p) else espClear(p) end
	end
end })
util:ColorPicker({ Title = "ESP color", Default = espColor, Flag = "ESPColor", Callback = function(c)
	espColor = c
	for _, h in pairs(espHL) do
		h.FillColor = c
	end
end })
util:Toggle({ Title = "Anti Invisible Players", Description = "See invisible players", Icon = "👀", Flag = "AntiInvis", Callback = function(v) antiInvis = v end })
util:Toggle({ Title = "RGB Street Lights", Description = "Cycle the street lights (only you see it)", Icon = "🪩", Flag = "RGBLights", Callback = function(v)
	if v then
		task.spawn(function()
			collectStreetLights()
			rgbLights = true
		end)
	else
		rgbLights = false
		restoreLights()
	end
end })
util:Button({ Title = "Set SpawnPoint", Callback = function()
	local r = getRoot()
	if r then
		spawnCF = r.CFrame
		notify("Spawn", "Spawn point saved. You will respawn here.")
	end
end })
util:Button({ Title = "Clear SpawnPoint", Callback = function()
	spawnCF = nil
	notify("Spawn", "Spawn point cleared.")
end })

------------------------------------------------------------------------
-- MORE FEATURES (Novoline-style)
------------------------------------------------------------------------
local function cmdToggle(on, off)
	return function(v) runCommand(v and on or off) end
end
local vis = Features:Section({ Title = "Visuals & Camera", Icon = "👁️", Side = "Left" })
vis:Actions({
	{ Title = "Freecam", Description = "Off", Icon = "📸", Toggle = true, Callback = cmdToggle("freecam", "unfreecam") },
	{ Title = "X-Ray", Description = "Off", Icon = "scan", Toggle = true, Callback = cmdToggle("xray", "unxray") },
	{ Title = "Fullbright", Description = "Tap", Icon = "☀️", Callback = function() runCommand("fullbright") end },
	{ Title = "No Fog", Description = "Tap", Icon = "☁️", Callback = function() runCommand("nofog") end },
})
vis:Slider({ Title = "Max zoom", Min = 10, Max = 2000, Default = 128, Increment = 10, Flag = "MaxZoom", Callback = function(v) lp.CameraMaxZoomDistance = v end })
vis:Slider({ Title = "Brightness", Min = 0, Max = 10, Default = 2, Increment = 0.5, Flag = "Bright", Callback = function(v) Lighting.Brightness = v end })

local mov = Features:Section({ Title = "Movement+", Icon = "run", Side = "Right" })
mov:Actions({
	{ Title = "Airwalk", Description = "Off", Icon = "🌌", Toggle = true, Callback = cmdToggle("airwalk", "unairwalk") },
	{ Title = "Spin", Description = "Off", Icon = "💫", Toggle = true, Callback = cmdToggle("spin 12", "unspin") },
	{ Title = "Anti AFK", Description = "Off", Icon = "🕘", Toggle = true, Callback = cmdToggle("antiafk", "unantiafk") },
	{ Title = "Anti Sit", Description = "Off", Icon = "🔐", Toggle = true, Callback = cmdToggle("antisit", "enablesit") },
	{ Title = "Click TP", Description = "Get tool", Icon = "🐁", Callback = function() runCommand("clicktp") end },
	{ Title = "Float", Description = "No gravity", Icon = "🍃", Toggle = true, Callback = function(v) workspace.Gravity = v and 0 or 196.2 end },
})
mov:Slider({ Title = "Gravity", Min = 0, Max = 400, Default = 196, Increment = 4, Flag = "Gravity", Callback = function(v) workspace.Gravity = v end })
mov:Slider({ Title = "Hip height", Min = 0, Max = 50, Default = 0, Increment = 0.5, Flag = "HipHeight", Callback = function(v) local h = getHum() if h then h.HipHeight = v end end })

local wp = Features:Section({ Title = "Waypoints", Icon = "🗺️", Side = "Left" })
local wpName = wp:Input({ Placeholder = "Waypoint name" })
wp:Actions({
	{ Title = "Save here", Description = "Current spot", Icon = "✅", Callback = function() runCommand("setwaypoint " .. tostring(wpName:Get() or ""):gsub("%s", "_")) end },
	{ Title = "Teleport", Description = "To name", Icon = "📟", Callback = function() runCommand("gotowaypoint " .. tostring(wpName:Get() or ""):gsub("%s", "_")) end },
	{ Title = "List", Description = "All saved", Icon = "list", Callback = function() runCommand("waypoints") end },
	{ Title = "Delete", Description = "By name", Icon = "🗑️", Callback = function() runCommand("deletewaypoint " .. tostring(wpName:Get() or ""):gsub("%s", "_")) end },
})

------------------------------------------------------------------------
-- EXPLOITS
------------------------------------------------------------------------
local Dev = Window:CreateTab({ Name = "Exploits", Icon = "🔥" })
local logSec = Dev:Section({ Title = "Net Logger", Icon = "🌐", Side = "Left" })
local logHow = Dev:Section({ Title = "How to use", Side = "Right" })
logHow:Paragraph({
	Title = "For missing features",
	Content = "1) Turn Logger ON.\n2) Use the game's own buttons once for that action (Lock Home, Spawn Vehicle, Block Calls, Rainbow Vehicle etc.).\n3) Press Copy log and paste it back. That reveals the exact remote calls.",
})

local logLines, logOn, logHooked = {}, false, false
local HttpService = game:GetService("HttpService")
local rec = { on = false, calls = {}, last = 0 }
local replaying = false

local function ser(v, d)
	d = d or 0
	local t = typeof(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "Instance" then
		return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">"
	elseif t == "table" then
		if d >= 2 then
			return "{...}"
		end
		local parts, n = {}, 0
		for k, x in pairs(v) do
			n = n + 1
			if n > 12 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. ser(k, d + 1) .. "]=" .. ser(x, d + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function record(kind, name, ...)
	local args = table.pack(...)
	local parts = {}
	for i = 1, args.n do
		parts[i] = ser(args[i])
	end
	local line = ("net.%s(%s%s)"):format(kind, ser(name), #parts > 0 and (", " .. table.concat(parts, ", ")) or "")
	table.insert(logLines, line)
	if #logLines > 300 then
		table.remove(logLines, 1)
	end
	print("[Yadsan NetLog] " .. line)
end

local function capture(kind, name, ...)
	local now = os.clock()
	table.insert(rec.calls, { kind = kind, name = name, args = table.pack(...), dt = rec.last > 0 and (now - rec.last) or 0 })
	rec.last = now
end

local function hookNet()
	if logHooked then
		return true
	end
	if not net then
		return false
	end
	local origSend, origGet = net.send, net.get
	if type(origSend) ~= "function" or type(origGet) ~= "function" then
		return false
	end
	net.send = function(name, ...)
		if not replaying then
			if logOn then
				pcall(record, "send", name, ...)
			end
			if rec.on then
				pcall(capture, "send", name, ...)
			end
		end
		return origSend(name, ...)
	end
	net.get = function(name, ...)
		if not replaying then
			if logOn then
				pcall(record, "get", name, ...)
			end
			if rec.on then
				pcall(capture, "get", name, ...)
			end
		end
		return origGet(name, ...)
	end
	logHooked = true
	return true
end

logSec:Toggle({ Title = "Net Logger", Description = "Record the game's remote calls", Icon = "🌐", Callback = function(v)
	if v and not hookNet() then
		notify("Net Logger", "Game Net module not found.")
		logOn = false
		return
	end
	logOn = v
end })
logSec:Button({ Title = "Copy log", Style = "Primary", Callback = function()
	if #logLines == 0 then
		notify("Net Logger", "Log is empty.")
		return
	end
	if setclipboard then
		setclipboard(table.concat(logLines, "\n"))
		notify("Net Logger", #logLines .. " lines copied to clipboard.")
	else
		notify("Net Logger", "setclipboard not supported. Check console (F9).")
	end
end })
logSec:Button({ Title = "Clear log", Callback = function()
	logLines = {}
	notify("Net Logger", "Log cleared.")
end })
logSec:Button({ Title = "Copy fit report", Callback = function()
	if #copyReport == 0 then
		notify("Fit report", "Run Copy Avatar first.")
		return
	end
	if setclipboard then
		setclipboard(table.concat(copyReport, "\n"))
		notify("Fit report", "Copied. Paste it to the developer if Copy Avatar fails.")
	else
		notify("Fit report", table.concat(copyReport, " | "))
	end
end })

do

------------------------------------------------------------------------
-- ACTION RECORDER
------------------------------------------------------------------------
local ACTION_FOLDER = "YADSAN_HUB"
local ACTION_FILE = ACTION_FOLDER .. "/actions.json"
local actions, actionOrder = {}, {}

local myActs = Home:Section({ Title = "My Actions", Icon = "star", Side = "Right" })
myActs:Label("Record in the Exploits tab to create buttons here.")

local function enc(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	elseif t == "nil" then
		return { __t = "N" }
	elseif t == "Vector3" then
		return { __t = "V3", x = v.X, y = v.Y, z = v.Z }
	elseif t == "CFrame" then
		return { __t = "CF", c = { v:GetComponents() } }
	elseif t == "Color3" then
		return { __t = "C3", r = v.R, g = v.G, b = v.B }
	elseif t == "EnumItem" then
		return { __t = "E", s = tostring(v) }
	elseif t == "Instance" then
		return { __t = "I", p = v:GetFullName() }
	elseif t == "table" then
		local list = {}
		for k, x in pairs(v) do
			local ek, ex = enc(k), enc(x)
			if ek == nil or ex == nil then
				return nil
			end
			table.insert(list, { ek, ex })
		end
		return { __t = "T", p = list }
	end
	return nil
end

local function resolvePath(path)
	local cur = game
	for part in string.gmatch(path, "[^%.]+") do
		cur = cur and cur:FindFirstChild(part)
	end
	return cur
end

local function dec(v)
	if type(v) ~= "table" then
		return v
	end
	local t = v.__t
	if t == "N" then
		return nil
	elseif t == "V3" then
		return Vector3.new(v.x, v.y, v.z)
	elseif t == "CF" then
		return CFrame.new(table.unpack(v.c))
	elseif t == "C3" then
		return Color3.new(v.r, v.g, v.b)
	elseif t == "E" then
		local _, b, c = string.match(v.s, "^(%w+)%.(%w+)%.(%w+)$")
		if b then
			local ok, e = pcall(function()
				return Enum[b][c]
			end)
			if ok then
				return e
			end
		end
		return nil
	elseif t == "I" then
		return resolvePath(v.p)
	elseif t == "T" then
		local out = {}
		for _, pr in ipairs(v.p) do
			local k = dec(pr[1])
			if k ~= nil then
				out[k] = dec(pr[2])
			end
		end
		return out
	end
	return v
end

local function buildJson(name, calls)
	local jc = {}
	for _, c in ipairs(calls) do
		local ja = {}
		for i = 1, c.args.n do
			local e = enc(c.args[i])
			if e == nil then
				return nil
			end
			ja[i] = e
		end
		table.insert(jc, { k = c.kind, n = c.name, a = ja, an = c.args.n, d = c.dt })
	end
	return { name = name, calls = jc }
end

local function saveActions()
	if not (writefile and makefolder) then
		return
	end
	local list = {}
	for _, name in ipairs(actionOrder) do
		local a = actions[name]
		if a and a.json then
			table.insert(list, a.json)
		end
	end
	pcall(makefolder, ACTION_FOLDER)
	pcall(writefile, ACTION_FILE, HttpService:JSONEncode(list))
end

local function replay(a)
	if not net then
		notify("Action", "Game Net module not found.")
		return
	end
	task.spawn(function()
		replaying = true
		for _, c in ipairs(a.calls) do
			task.wait(math.min(c.dt or 0, 0.5))
			local f = (c.kind == "get") and net.get or net.send
			local ok, err = pcall(f, c.name, table.unpack(c.args, 1, c.args.n))
			if not ok then
				notify("Action failed", tostring(err))
				break
			end
		end
		replaying = false
	end)
end

local function addAction(name, calls, json)
	local isNew = actions[name] == nil
	actions[name] = { calls = calls, json = json }
	if isNew then
		table.insert(actionOrder, name)
		myActs:Button({ Title = name, Callback = function()
			local a = actions[name]
			if a then
				replay(a)
			else
				notify("Action", "This action has been deleted.")
			end
		end })
	end
end

local function loadActions()
	if not (readfile and isfile and isfile(ACTION_FILE)) then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(ACTION_FILE))
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	for _, j in ipairs(data) do
		local calls = {}
		for _, c in ipairs(j.calls) do
			local args = { n = c.an }
			for i = 1, c.an do
				args[i] = dec(c.a[i])
			end
			table.insert(calls, { kind = c.k, name = c.n, args = args, dt = c.d })
		end
		addAction(j.name, calls, j)
	end
end

local recSec = Dev:Section({ Title = "Action Recorder", Icon = "📽️", Side = "Left" })
recSec:Paragraph({
	Title = "Turn a game action into a hub button",
	Content = "1) Type an action name (e.g. Lock Home).\n2) Turn Record ON.\n3) Use the game's own button once for that action.\n4) Turn Record OFF. A button appears in Home tab's My Actions.",
})
local actName = recSec:Input({ Placeholder = "Action name (e.g. Lock Home)" })
local recToggle
recToggle = recSec:Toggle({ Title = "Record action", Description = "Turn ON, then press the game button", Icon = "🎮", Callback = function(v)
	if v then
		if not hookNet() then
			notify("Recorder", "Game Net module not found.")
			recToggle:Set(false, true)
			return
		end
		rec.calls, rec.last, rec.on = {}, 0, true
		notify("Recording", "Press the game button now, then turn Record OFF.")
		return
	end
	rec.on = false
	local n = #rec.calls
	if n == 0 then
		notify("Recorder", "No calls recorded. Maybe this action doesn't use a server call.")
		return
	end
	local name = actName:Get()
	if name == "" then
		name = "Action " .. (#actionOrder + 1)
	end
	local json = buildJson(name, rec.calls)
	addAction(name, rec.calls, json)
	saveActions()
	local names = {}
	for i = 1, math.min(n, 5) do
		names[#names + 1] = tostring(rec.calls[i].name)
	end
	notify("Saved: " .. name, n .. " call(s): " .. table.concat(names, ", ") .. (json and "" or "  (session only)"))
end })
recSec:Label("Tip: If more than 1-2 calls appear, background calls were captured too. Re-record by pressing the button and turning OFF quickly.")

loadActions()
end

------------------------------------------------------------------------
-- COMMANDS  (everything here only affects YOUR character / client)
------------------------------------------------------------------------
local Commands = Window:CreateTab({ Name = "Commands", Icon = "terminal" })

local function findPlayer(q)
	q = tostring(q or ""):lower()
	if q == "" then
		return nil
	end
	if q == "me" then
		return lp
	end
	local part
	for _, p in ipairs(Players:GetPlayers()) do
		local n, d = p.Name:lower(), p.DisplayName:lower()
		if n == q or d == q then
			return p
		end
		if not part and (n:sub(1, #q) == q or d:sub(1, #q) == q) then
			part = p
		end
	end
	if part then
		return part
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
			return p
		end
	end
	return nil
end

local cmdOut
local CMD, CMD_ORDER = {}, {}
local function defCmd(name, usage, desc, fn)
	CMD[name] = { usage = usage, desc = desc, fn = fn }
	table.insert(CMD_ORDER, name)
end
local function alias(a, name)
	CMD[a] = CMD[name]
end

local spinConn
local clickTpTool

defCmd("fly", "fly [speed]", "Toggle flying", function(a)
	if tonumber(a[1]) then
		flySpeed = tonumber(a[1])
	end
	tiles["Fly"]:Set(true)
	return "Fly on"
end)
defCmd("unfly", "unfly", "Stop flying", function() tiles["Fly"]:Set(false) return "Fly off" end)
defCmd("noclip", "noclip", "Walk through walls", function() tiles["Noclip"]:Set(true) return "Noclip on" end)
defCmd("clip", "clip", "Turn noclip off", function() tiles["Noclip"]:Set(false) return "Noclip off" end)
defCmd("infjump", "infjump", "Infinite jump on", function() tiles["Infinite Jump"]:Set(true) return "Infinite jump on" end)
defCmd("uninfjump", "uninfjump", "Infinite jump off", function() tiles["Infinite Jump"]:Set(false) return "Infinite jump off" end)
defCmd("night", "night", "Night vision on", function() tiles["Night Vision"]:Set(true) return "Night vision on" end)
defCmd("unnight", "unnight", "Night vision off", function() tiles["Night Vision"]:Set(false) return "Night vision off" end)
defCmd("fps", "fps", "Toggle FPS boost", function() local t = tiles["FPS Boost"] t:Set(not t:Get()) return "FPS boost " .. (t:Get() and "on" or "off") end)
defCmd("antifling", "antifling", "Toggle anti fling", function() local t = tiles["Anti Fling"] t:Set(not t:Get()) return "Anti fling " .. (t:Get() and "on" or "off") end)
defCmd("speed", "speed <n>", "Set walk speed", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: speed <number>" end
	Window.Speed:Set(n)
	return "Speed " .. n
end)
defCmd("jump", "jump <n>", "Set jump power", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: jump <number>" end
	Window.Jump:Set(n)
	return "Jump " .. n
end)
defCmd("fov", "fov <n>", "Set field of view", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: fov <number>" end
	Window.FOV:Set(n)
	return "FOV " .. n
end)
defCmd("gravity", "gravity <n>", "Set gravity (196.2 = normal)", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: gravity <number>" end
	workspace.Gravity = n
	return "Gravity " .. n
end)
defCmd("time", "time <0-24>", "Set time of day", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: time <0-24>" end
	Lighting.ClockTime = n
	return "Time " .. n
end)
defCmd("esp", "esp", "Player ESP on", function() espToggle:Set(true) return "ESP on" end)
defCmd("unesp", "unesp", "Player ESP off", function() espToggle:Set(false) return "ESP off" end)
defCmd("goto", "goto <player>", "Teleport next to a player", function(a)
	local p = findPlayer(a[1])
	local tr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local r = getRoot()
	if not (tr and r) then return "Player not found" end
	r.CFrame = tr.CFrame * CFrame.new(0, 0, 3)
	return "Teleported to " .. p.DisplayName
end)
defCmd("view", "view <player>", "Spectate a player", function(a)
	local p = findPlayer(a[1])
	local th = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not th then return "Player not found" end
	workspace.CurrentCamera.CameraSubject = th
	return "Viewing " .. p.DisplayName
end)
defCmd("unview", "unview", "Stop spectating", function()
	local h = getHum()
	if h then workspace.CurrentCamera.CameraSubject = h end
	return "Camera back to you"
end)
defCmd("copy", "copy <player>", "Copy a player's outfit (Fit Copier)", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	task.spawn(function()
		local ok, d = copyAvatar(p)
		notify(ok and "Copy Avatar" or "Copy Avatar failed", ok and ("Copied " .. p.DisplayName .. ": " .. tostring(d)) or tostring(d))
	end)
	return "Copying " .. p.DisplayName .. "..."
end)
defCmd("sync", "sync <player>", "Mirror a player's animations", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	target = p
	act["Sync Anim"]:Set(true)
	return "Syncing with " .. p.DisplayName
end)
defCmd("unsync", "unsync", "Stop animation sync", function() act["Sync Anim"]:Set(false) return "Sync stopped" end)
defCmd("size", "size <n>", "Set body scale (0.1 - 10000)", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: size <number>" end
	n = math.clamp(n, 0.1, 10000)
	local ok, e = applySize(n, autoW(n), autoHead(n))
	return ok and ("Size " .. n) or tostring(e)
end)
defCmd("resetsize", "resetsize", "Back to normal size", function() local ok, e = applySize(1, 1, 1) return ok and "Size reset" or tostring(e) end)
defCmd("sit", "sit", "Sit down", function() local h = getHum() if h then h.Sit = true end return "Sat down" end)
defCmd("reset", "reset", "Respawn your character", function() local h = getHum() if h then h.Health = 0 end return "Resetting..." end)
defCmd("spin", "spin [speed]", "Spin your character", function(a)
	if spinConn then spinConn:Disconnect() end
	local sp = tonumber(a[1]) or 10
	spinConn = RunService.Heartbeat:Connect(function()
		local r = getRoot()
		if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(sp), 0) end
	end)
	return "Spinning"
end)
defCmd("unspin", "unspin", "Stop spinning", function() if spinConn then spinConn:Disconnect() spinConn = nil end return "Stopped" end)
defCmd("clicktp", "clicktp", "Get a tool: click to teleport", function()
	if clickTpTool and clickTpTool.Parent then return "You already have it" end
	clickTpTool = Instance.new("Tool")
	clickTpTool.Name = "Click TP"
	clickTpTool.RequiresHandle = false
	clickTpTool.Parent = lp:FindFirstChildOfClass("Backpack")
	clickTpTool.Activated:Connect(function()
		local m = lp:GetMouse()
		local r = getRoot()
		if r and m.Hit then r.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0, 3, 0)) end
	end)
	return "Click TP tool added to your backpack"
end)
defCmd("rejoin", "rejoin", "Rejoin this server", function()
	pcall(function()
		if #Players:GetPlayers() <= 1 then
			lp:Kick("\nRejoining...")
			task.wait()
			game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
		else
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
		end
	end)
	return "Rejoining..."
end)
defCmd("cmds", "cmds", "List all commands", function()
	local t = {}
	for _, n in ipairs(CMD_ORDER) do t[#t + 1] = CMD[n].usage end
	return table.concat(t, ", ")
end)
-- ===== extra commands (names follow Novoline's list; self/client only) =====
local wps = {}
local afkConn2
local loops = {}
local function loopProp(name, setter)
	if loops[name] then loops[name]:Disconnect() end
	loops[name] = RunService.Heartbeat:Connect(setter)
end
local function stopLoopProp(name)
	if loops[name] then loops[name]:Disconnect() loops[name] = nil end
end
local function num(a, usage)
	local n = tonumber(a[1])
	if not n then error("Usage: " .. usage, 0) end
	return n
end

defCmd("antiafk", "antiafk", "Prevent AFK kick", function()
	if afkConn2 then afkConn2:Disconnect() end
	afkConn2 = lp.Idled:Connect(function()
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end)
	return "Anti-AFK on"
end)
defCmd("unantiafk", "unantiafk", "Disable anti-AFK", function() if afkConn2 then afkConn2:Disconnect() afkConn2 = nil end return "Anti-AFK off" end)
defCmd("brightness", "brightness <n>", "Set lighting brightness", function(a) Lighting.Brightness = num(a, "brightness <n>") return "Brightness set" end)
defCmd("loopbrightness", "loopbrightness <n>", "Lock lighting brightness", function(a)
	local n = num(a, "loopbrightness <n>")
	loopProp("bright", function() Lighting.Brightness = n end)
	return "Brightness locked"
end)
defCmd("unloopbrightness", "unloopbrightness", "Unlock brightness", function() stopLoopProp("bright") return "Unlocked" end)
defCmd("fullbright", "fullbright", "Maximize lighting", function()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 1e6
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
	return "Fullbright"
end)
defCmd("nofog", "nofog", "Remove fog", function()
	Lighting.FogEnd = 1e6
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("Atmosphere") then e.Density = 0 end
	end
	return "Fog removed"
end)
defCmd("loopnofog", "loopnofog", "Keep fog removed", function()
	loopProp("fog", function() Lighting.FogEnd = 1e6 end)
	return "Fog locked off"
end)
defCmd("unloopnofog", "unloopnofog", "Stop keeping fog off", function() stopLoopProp("fog") return "Done" end)
defCmd("loopnoeffect", "loopnoeffect", "Keep post effects disabled", function()
	loopProp("fx", function()
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") then e.Enabled = false end
		end
	end)
	return "Effects locked off"
end)
defCmd("unloopnoeffect", "unloopnoeffect", "Stop keeping effects off", function() stopLoopProp("fx") return "Done" end)
defCmd("nogravity", "nogravity", "Float (zero gravity)", function() workspace.Gravity = 0 return "Gravity 0" end)
defCmd("hipheight", "hipheight <n>", "Set hip height", function(a)
	local h = getHum()
	if h then h.HipHeight = num(a, "hipheight <n>") end
	return "Hip height set"
end)
defCmd("loopws", "loopws <n>", "Lock walkspeed", function(a)
	local n = num(a, "loopws <n>")
	loopProp("ws", function() local h = getHum() if h then h.WalkSpeed = n end end)
	return "Walkspeed locked " .. n
end)
defCmd("unloopws", "unloopws", "Unlock walkspeed", function() stopLoopProp("ws") return "Unlocked" end)
defCmd("loopjp", "loopjp <n>", "Lock jump power", function(a)
	local n = num(a, "loopjp <n>")
	loopProp("jp", function()
		local h = getHum()
		if h then
			if h.UseJumpPower then h.JumpPower = n else h.JumpHeight = n end
		end
	end)
	return "Jump locked " .. n
end)
defCmd("unloopjp", "unloopjp", "Unlock jump", function() stopLoopProp("jp") return "Unlocked" end)
defCmd("maxzoom", "maxzoom <n>", "Set max camera zoom", function(a) lp.CameraMaxZoomDistance = num(a, "maxzoom <n>") return "Max zoom set" end)
defCmd("freeze", "freeze", "Anchor your character (client)", function()
	local c = lp.Character
	if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end end
	return "Frozen"
end)
defCmd("unfreeze", "unfreeze", "Unanchor your character", function()
	local c = lp.Character
	if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = false end end end
	return "Unfrozen"
end)
defCmd("airwalk", "airwalk", "Walk on air", function()
	local plat
	loopProp("air", function()
		local r = getRoot()
		if not r then return end
		if not plat then
			plat = Instance.new("Part")
			plat.Size = Vector3.new(8, 1, 8)
			plat.Anchored = true
			plat.Transparency = 1
			plat.Parent = workspace
			loops.airPlat = plat
		end
		local y = r.Position.Y - 3.5
		if UIS:IsKeyDown(Enum.KeyCode.Space) then plat.CFrame = CFrame.new(r.Position.X, y + 1, r.Position.Z) else plat.CFrame = CFrame.new(r.Position.X, y, r.Position.Z) end
	end)
	return "Airwalk on"
end)
defCmd("unairwalk", "unairwalk", "Disable airwalk", function()
	stopLoopProp("air")
	if loops.airPlat then loops.airPlat:Destroy() loops.airPlat = nil end
	return "Airwalk off"
end)
local function antiSit(v)
	local h = getHum()
	if h then h:SetStateEnabled(Enum.HumanoidStateType.Seated, not v) end
end
defCmd("antisit", "antisit", "Prevent being sat in a seat", function() antiSit(true) return "Anti-sit on" end)
defCmd("disablesit", "disablesit", "Prevent sitting", function() antiSit(true) return "Sitting disabled" end)
defCmd("enablesit", "enablesit", "Re-enable sitting", function() antiSit(false) return "Sitting enabled" end)
defCmd("unequiptools", "unequiptools", "Unequip held tools", function() local h = getHum() if h then h:UnequipTools() end return "Done" end)
defCmd("ping", "ping", "Show your ping", function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
defCmd("copyuser", "copyuser <player>", "Copy a player's username", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	if setclipboard then setclipboard(p.Name) end
	return "Copied " .. p.Name
end)
defCmd("join", "join <jobId>", "Join a server by Job ID", function(a)
	if not a[1] then return "Usage: join <jobId>" end
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, a[1], lp)
	return "Joining..."
end)
defCmd("setwaypoint", "setwaypoint <name>", "Save your position", function(a)
	local r = getRoot()
	if not (r and a[1]) then return "Usage: setwaypoint <name>" end
	wps[a[1]:lower()] = r.CFrame
	return "Saved " .. a[1]
end)
defCmd("gotowaypoint", "gotowaypoint <name>", "Teleport to a waypoint", function(a)
	local r, cf = getRoot(), a[1] and wps[a[1]:lower()]
	if not (r and cf) then return "Waypoint not found" end
	r.CFrame = cf
	return "Teleported"
end)
defCmd("deletewaypoint", "deletewaypoint <name>", "Delete a waypoint", function(a) if a[1] then wps[a[1]:lower()] = nil end return "Deleted" end)
defCmd("waypoints", "waypoints", "List waypoints", function()
	local t = {}
	for k in pairs(wps) do t[#t + 1] = k end
	return #t == 0 and "No waypoints" or table.concat(t, ", ")
end)
defCmd("volume", "volume <0-10>", "Set master volume", function(a)
	pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = num(a, "volume <0-10>") / 10 end)
	return "Volume set"
end)
local xrayParts = {}
defCmd("xray", "xray", "See through walls (client)", function()
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("BasePart") and not (lp.Character and o:IsDescendantOf(lp.Character)) and not o.Parent:FindFirstChildOfClass("Humanoid") and o.Transparency < 0.5 then
			xrayParts[o] = o.Transparency
			o.LocalTransparencyModifier = 0.6
		end
	end
	return "X-ray on"
end)
defCmd("unxray", "unxray", "Disable x-ray", function()
	for o in pairs(xrayParts) do pcall(function() o.LocalTransparencyModifier = 0 end) end
	xrayParts = {}
	return "X-ray off"
end)
defCmd("iy", "iy", "Load Infinite Yield", function()
	task.spawn(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)
	return "Loading Infinite Yield..."
end)
alias("unnoclip", "clip")
alias("lockws", "loopws")

-- ===== freecam + local hide (client only) =====
local fc = { on = false, speed = 50, yaw = 0, pitch = 0, conns = {} }
local function fcStop()
	if not fc.on then return end
	fc.on = false
	for _, c in ipairs(fc.conns) do c:Disconnect() end
	fc.conns = {}
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local h, r = getHum(), getRoot()
	if h then cam.CameraSubject = h end
	if r then r.Anchored = false end
end
local function fcStart()
	if fc.on then return end
	local cam, r = workspace.CurrentCamera, getRoot()
	if not r then error("Character not found", 0) end
	fc.on = true
	local look = cam.CFrame.LookVector
	fc.yaw, fc.pitch = math.atan2(-look.X, -look.Z), math.asin(look.Y)
	local pos = cam.CFrame.Position
	cam.CameraType = Enum.CameraType.Scriptable
	r.Anchored = true
	local rmb = false
	table.insert(fc.conns, UIS.InputBegan:Connect(function(i, gp)
		if i.UserInputType == Enum.UserInputType.MouseButton2 then rmb = true end
	end))
	table.insert(fc.conns, UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton2 then rmb = false end
	end))
	table.insert(fc.conns, UIS.InputChanged:Connect(function(i, gp)
		local d
		if i.UserInputType == Enum.UserInputType.MouseMovement and rmb then d = i.Delta
		elseif i.UserInputType == Enum.UserInputType.Touch and not gp then d = i.Delta end
		if d then
			fc.yaw = fc.yaw - d.X * 0.004
			fc.pitch = math.clamp(fc.pitch - d.Y * 0.004, -1.5, 1.5)
		end
	end))
	table.insert(fc.conns, RunService.RenderStepped:Connect(function(dt)
		local rot = CFrame.Angles(0, fc.yaw, 0) * CFrame.Angles(fc.pitch, 0, 0)
		local move = Vector3.zero
		local h = getHum()
		if h then
			local md = h.MoveDirection
			if md.Magnitude > 0 then
				local flat = CFrame.Angles(0, fc.yaw, 0)
				local c = workspace.CurrentCamera.CFrame
				move = flat:VectorToWorldSpace(Vector3.new(md:Dot(c.RightVector), 0, -md:Dot(Vector3.new(c.LookVector.X, 0, c.LookVector.Z).Unit))) 
			end
		end
		if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.E) or UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.yAxis end
		pos = pos + move * fc.speed * dt
		workspace.CurrentCamera.CFrame = CFrame.new(pos) * rot
	end))
	fc.setPos = function(p) pos = p end
end
defCmd("freecam", "freecam", "Free camera (WASD/QE, right-drag or touch-drag to look)", function() fcStart() return "Freecam on" end)
defCmd("unfreecam", "unfreecam", "Exit freecam", function() fcStop() return "Freecam off" end)
defCmd("fcspeed", "fcspeed <n>", "Freecam speed", function(a) fc.speed = num(a, "fcspeed <n>") return "Freecam speed " .. fc.speed end)
defCmd("fcgoto", "fcgoto <player>", "Move freecam to a player", function(a)
	local p = findPlayer(a[1])
	local tr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not tr then return "Player not found" end
	if not fc.on then fcStart() end
	fc.setPos(tr.Position + Vector3.new(0, 4, 8))
	return "Freecam at " .. p.DisplayName
end)
local hiddenLoop = {}
defCmd("hide", "hide <player>", "Hide a player on your screen only", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	hiddenLoop[p] = true
	return "Hiding " .. p.DisplayName .. " (only you)"
end)
alias("loopdelete", "hide")
defCmd("unhide", "unhide <player>", "Show a hidden player again", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	hiddenLoop[p] = nil
	if p.Character then
		for _, o in ipairs(p.Character:GetDescendants()) do
			if o:IsA("BasePart") then o.LocalTransparencyModifier = 0 end
		end
	end
	return "Showing " .. p.DisplayName
end)
RunService.RenderStepped:Connect(function()
	for p in pairs(hiddenLoop) do
		if p.Parent and p.Character then
			for _, o in ipairs(p.Character:GetDescendants()) do
				if o:IsA("BasePart") then o.LocalTransparencyModifier = 1 end
			end
		else
			hiddenLoop[p] = nil
		end
	end
end)

alias("tp", "goto")
alias("spectate", "view")
alias("walkspeed", "speed")
alias("ws", "speed")
alias("jp", "jump")
alias("respawn", "reset")
alias("fit", "copy")

function runCommand(line)
	line = tostring(line or ""):gsub("^%s*[;/!:]?%s*", "")
	if line == "" then return end
	local args = {}
	for w in line:gmatch("%S+") do args[#args + 1] = w end
	local name = table.remove(args, 1):lower()
	local c = CMD[name]
	local msg
	if not c then
		msg = "Unknown command: " .. name .. "  (try: cmds)"
	else
		local ok, r = pcall(c.fn, args)
		msg = ok and tostring(r or "Done") or ("Error: " .. tostring(r))
	end
	if cmdOut then cmdOut:Set(msg) end
	notify("Command", msg)
end

local runSec = Commands:Section({ Title = "Command bar", Icon = "terminal", Side = "Left" })
local cmdInput = runSec:Input({ Placeholder = "e.g. speed 80, goto name, fly", OnBlur = false, Callback = function(t)
	runCommand(t)
end })
runSec:Button({ Title = "Run", Style = "Primary", Callback = function()
	runCommand(cmdInput:Get())
end })
cmdOut = runSec:Label("Result shows here.")
runSec:Actions({
	{ Title = "Reset", Description = "Respawn", Icon = "refresh", Callback = function() runCommand("reset") end },
	{ Title = "Sit", Description = "Sit down", Icon = "stand", Callback = function() runCommand("sit") end },
	{ Title = "Click TP", Description = "Get tool", Icon = "mouse", Callback = function() runCommand("clicktp") end },
	{ Title = "Rejoin", Description = "Same server", Icon = "door", Callback = function() runCommand("rejoin") end },
})

local listSecC = Commands:Section({ Title = "All commands", Icon = "list", Side = "Right" })
local lines = {}
for _, n in ipairs(CMD_ORDER) do
	lines[#lines + 1] = CMD[n].usage .. "  -  " .. CMD[n].desc
end
listSecC:Paragraph({ Title = "Type in the bar, press Enter", Content = table.concat(lines, "\n") })
listSecC:Label("Player names can be partial (e.g. 'man' finds 'Manas'). 'me' means you.")

;(function()
------------------------------------------------------------------------
-- FIT SAVER: every fit is its own file  YADSAN_HUB/fits/<name>.json  in your executor workspace
-- file = { name, file, saved, by, from, count, codes = {asset ids}, items = {{id,type,kind}}, skin = {r,g,b}, scale = {h,w,head} }
------------------------------------------------------------------------
local FIT_DIR = "YADSAN_HUB/fits"
local FitStore = { fits = {}, listeners = {} }
do
	local function mkdirs()
		pcall(function()
			if makefolder then
				pcall(makefolder, "YADSAN_HUB")
				pcall(makefolder, FIT_DIR)
			end
		end)
	end
	local function fileSafe(name)
		local s = tostring(name):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_")
		if s == "" then
			s = "fit"
		end
		return s:sub(1, 40)
	end
	local function fire()
		for _, f in ipairs(FitStore.listeners) do
			pcall(f)
		end
	end
	function FitStore.onChange(f)
		FitStore.listeners[#FitStore.listeners + 1] = f
	end
	function FitStore.names()
		local n = {}
		for k in pairs(FitStore.fits) do
			n[#n + 1] = k
		end
		table.sort(n, function(a, b)
			return (FitStore.fits[a].saved or 0) > (FitStore.fits[b].saved or 0)
		end)
		return n
	end
	function FitStore.get(name)
		return FitStore.fits[name]
	end
	local function write(data)
		mkdirs()
		local ok, err = pcall(function()
			writefile(FIT_DIR .. "/" .. data.file .. ".json", HttpService:JSONEncode(data))
		end)
		return ok, err
	end
	function FitStore.save(name, desc, byName, fromName, char)
		name = tostring(name):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 28)
		if name == "" then
			name = "Fit " .. os.date("%H:%M:%S")
		end
		local items = captureItems(desc)
		if #items == 0 then
			return false, "No items found on that avatar"
		end
		local codes = {}
		for i, it in ipairs(items) do
			codes[i] = it.id
		end
		local sk = captureSkin(desc, char or lp.Character)
		local data = {
			name = name, file = fileSafe(name), saved = os.time(), by = byName, from = fromName or byName,
			count = #items, codes = codes, items = items, skin = sk,
			scale = captureScale(desc),
		}
		local old = FitStore.fits[name]
		FitStore.fits[name] = data
		local ok, err = write(data)
		fire()
		if not ok then
			return true, ("Saved in memory (file write failed: %s)"):format(tostring(err)), data
		end
		if name ~= "_previous_fit" then NovaUI.Stat("saves") end
		return true, (old and "Overwrote " or "Saved ") .. name .. " -> " .. FIT_DIR .. "/" .. data.file .. ".json", data
	end
	function FitStore.delete(name)
		local d = FitStore.fits[name]
		if not d then
			return false
		end
		FitStore.fits[name] = nil
		pcall(function()
			if delfile then
				delfile(FIT_DIR .. "/" .. d.file .. ".json")
			end
		end)
		fire()
		return true
	end
	function FitStore.wear(name, onProgress)
		local d = FitStore.fits[name]
		if not d then
			return false, "Fit not found"
		end
		return wearItems(d.items, d.skin, "saved:" .. name, onProgress, { scale = d.scale })
	end
	function FitStore.copyIds(name)
		local d = FitStore.fits[name]
		if d and setclipboard then
			local t = {}
			for _, c in ipairs(d.codes) do
				t[#t + 1] = ("%.0f"):format(c)
			end
			pcall(setclipboard, table.concat(t, ", "))
			return true
		end
		return false
	end
	NovaUI.beforeWear = function()
		local h = getHum()
		local d = h and h:GetAppliedDescription()
		if d then pcall(FitStore.save, "_previous_fit", d, lp.Name, lp.Name, lp.Character) end
	end
	function FitStore.saveMine()
		local h = getHum()
		local d = h and h:GetAppliedDescription()
		return d
	end

	-- load existing files (+ migrate the old single fits.json once)
	mkdirs()
	pcall(function()
		if listfiles then
			for _, path in ipairs(listfiles(FIT_DIR)) do
				if tostring(path):lower():match("%.json$") then
					local ok, data = pcall(function()
						return HttpService:JSONDecode(readfile(path))
					end)
					if ok and type(data) == "table" and data.name and type(data.items) == "table" then
						data.file = data.file or fileSafe(data.name)
						FitStore.fits[data.name] = data
					end
				end
			end
		end
	end)
	pcall(function()
		local OLD = "YADSAN_HUB/fits.json"
		if isfile and isfile(OLD) then
			local old = HttpService:JSONDecode(readfile(OLD))
			for name, d in pairs(old) do
				if type(d) == "table" and not FitStore.fits[name] then
					local items = {}
					for _, a in ipairs(d.acc or {}) do
						local t = tostring(a.AccessoryType or "Hat")
						if not t:find("Accessory") then
							t = t .. "Accessory"
						end
						items[#items + 1] = { id = a.AssetId, type = t, kind = "acc" }
					end
					local p = d.props or {}
					for _, c in ipairs({ { "Pants", "Pants" }, { "Shirt", "Shirt" }, { "GraphicTShirt", "TShirt" }, { "Face", "Face" } }) do
						if tonumber(p[c[1]]) and p[c[1]] ~= 0 then
							items[#items + 1] = { id = p[c[1]], type = c[2], kind = "cloth" }
						end
					end
					for _, k in ipairs(ANIM_PROPS) do
						if tonumber(p[k]) and p[k] ~= 0 then
							items[#items + 1] = { id = p[k], type = k, kind = "anim" }
						end
					end
					if #items > 0 then
						local codes = {}
						for i, it in ipairs(items) do
							codes[i] = it.id
						end
						local data = { name = name, file = fileSafe(name), saved = os.time(), by = "migrated", count = #items, codes = codes, items = items, skin = d.skin }
						FitStore.fits[name] = data
						write(data)
					end
				end
			end
			pcall(function()
				writefile("YADSAN_HUB/fits.json.migrated", readfile(OLD))
				if delfile then
					delfile(OLD)
				end
			end)
		end
	end)
end

-- hub (Avatar tab) UI
local fitSec = Avatar:Section({ Title = "Fit Saver", Icon = "shirt", Side = "Right" })
local fitName = fitSec:Input({ Placeholder = "Fit name" })
local fitRows = {}
local function fitNameOrDefault(prefix)
	local n = tostring(fitName:Get() or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if n == "" then
		n = prefix .. " " .. os.date("%H:%M:%S")
	end
	return n:sub(1, 28)
end
local function rebuildFitRows()
	for _, r in ipairs(fitRows) do
		pcall(function()
			r:Destroy()
		end)
	end
	fitRows = {}
	for _, name in ipairs(FitStore.names()) do
		local before = {}
		for _, c in ipairs(fitSec.Body:GetChildren()) do
			before[c] = true
		end
		fitSec:Actions({
			{ Title = name, Description = (FitStore.get(name).count or 0) .. " items - tap to wear", Icon = "shirt", Callback = function()
				task.spawn(function()
					notify("Fit Saver", "Wearing " .. name .. "...")
					local ok, d = FitStore.wear(name)
					notify(ok and "Fit worn" or "Fit failed", ok and (name .. ": " .. tostring(d)) or tostring(d))
				end)
			end },
			{ Title = "Delete", Description = name, Icon = "trash", Callback = function()
				FitStore.delete(name)
				notify("Fit Saver", "Deleted " .. name)
			end },
		})
		for _, c in ipairs(fitSec.Body:GetChildren()) do
			if c:IsA("GuiObject") and not before[c] then
				fitRows[#fitRows + 1] = c
			end
		end
	end
end
fitSec:Actions({
	{ Title = "Save my fit", Description = "Current outfit", Icon = "✅", Callback = function()
		local d = FitStore.saveMine()
		if not d then notify("Fit Saver", "Character not loaded") return end
		local ok, msg = FitStore.save(fitNameOrDefault("My fit"), d, lp.Name)
		notify("Fit Saver", tostring(msg))
	end },
	{ Title = "Save selected", Description = "Their outfit", Icon = "shirts", Callback = function()
		local p = needTarget()
		local th = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local d = th and th:GetAppliedDescription()
		if not d then return end
		local ok, msg = FitStore.save(fitNameOrDefault(p.DisplayName), d, lp.Name, p.Name, p.Character)
		notify("Fit Saver", tostring(msg))
	end },
})
FitStore.onChange(rebuildFitRows)
rebuildFitRows()
------------------------------------------------------------------------
-- HUB CHAT: a messenger only for YADSAN HUB users (separate from the game's own Messages app).
-- Default relay: the free public ntfy.sh service (no setup). Optional: your own Firebase Realtime DB.
-- NOTE: the relay is public and has rate limits - do not share secrets here.
------------------------------------------------------------------------
local HubChat = { msgs = {}, listeners = {}, status = "starting", uiOpen = false, mode = "ntfy", scope = "g", presence = {} }
do
	local NTFY = "https://ntfy.sh/yadsanhub-lt-7f3a9c2e51d84b60a1"
	local CHAT_FILE = "YADSAN_HUB/chat_url.txt"
	local fbUrl = tostring(YADSAN_CHAT_SERVER or ""):gsub("%s+", ""):gsub("/+$", "")
	pcall(function()
		if fbUrl == "" and isfile and isfile(CHAT_FILE) then
			fbUrl = readfile(CHAT_FILE):gsub("%s+", ""):gsub("/+$", "")
		end
	end)
	if fbUrl ~= "" then
		HubChat.mode = "firebase"
	end
	local httpReq = (syn and syn.request) or http_request or request
	local seen, pending, lastId = {}, {}, nil
	local firstPoll, activeUntil, backoff = true, 0, 0
	local bucket, bucketT = 40, os.clock()

	local function clean(s, n)
		s = tostring(s or ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
		return s:sub(1, n)
	end
	local function fire()
		for _, f in ipairs(HubChat.listeners) do
			pcall(f, HubChat.msgs)
		end
	end
	function HubChat.onUpdate(f)
		HubChat.listeners[#HubChat.listeners + 1] = f
	end
	function HubChat.setUiOpen(v)
		HubChat.uiOpen = v and true or false
		if v then
			activeUntil = os.clock() + 60
		end
	end
	local function take(n)
		local now = os.clock()
		bucket = math.min(40, bucket + (now - bucketT) * 0.1)
		bucketT = now
		if bucket >= n then
			bucket = bucket - n
			return true
		end
		return false
	end
	local function request(opt)
		if httpReq then
			local ok, r = pcall(httpReq, opt)
			if ok and type(r) == "table" then
				return r.StatusCode or (r.Success and 200) or 0, r.Body or ""
			end
			return 0, tostring(r)
		end
		if opt.Method == "GET" then
			local ok, b = pcall(function()
				return game:HttpGet(opt.Url)
			end)
			return ok and 200 or 0, ok and b or tostring(b)
		end
		return 0, "no http function"
	end
	local function addMsg(e)
		table.insert(HubChat.msgs, e)
		table.sort(HubChat.msgs, function(a, b)
			return (a.t or 0) < (b.t or 0)
		end)
		while #HubChat.msgs > 80 do
			table.remove(HubChat.msgs, 1)
		end
	end

	-- hub profile (name + status) and friends list, saved in the executor folder
	local PROF_FILE, FR_FILE = "YADSAN_HUB/hub_profile.json", "YADSAN_HUB/friends.json"
	HubChat.me = { hn = "", st = "" }
	HubChat.staffMute = {}
	HubChat.fr = { friends = {}, incoming = {}, outgoing = {}, ctl = {} }
	pcall(function()
		if isfile and isfile(PROF_FILE) then
			local d = HttpService:JSONDecode(readfile(PROF_FILE))
			if type(d) == "table" then
				HubChat.me.hn = tostring(d.hn or ""):sub(1, 20)
				HubChat.me.st = tostring(d.st or ""):sub(1, 40)
			end
		end
		if isfile and isfile(FR_FILE) then
			local d = HttpService:JSONDecode(readfile(FR_FILE))
			if type(d) == "table" then
				for _, k in ipairs({ "friends", "incoming", "outgoing", "ctl" }) do
					if type(d[k]) == "table" then HubChat.fr[k] = d[k] end
				end
			end
		end
	end)
	local function saveJson(path, t)
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			writefile(path, HttpService:JSONEncode(t))
		end)
	end
	function HubChat.myName()
		return (HubChat.me.hn ~= "") and HubChat.me.hn or lp.DisplayName
	end
	function HubChat.setProfile(hn, st)
		hn = tostring(hn or ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 20)
		HubChat.me.hn = hn
		HubChat.me.st = tostring(st or ""):gsub("[%c]", ""):sub(1, 40)
		saveJson(PROF_FILE, HubChat.me)
		pcall(function() HubChat.ping() end)
	end
	local function myLevel()
		local ok, lv = pcall(function() return NovaUI.Profile.level() end)
		return ok and tonumber(lv) or 1
	end
	local function fireFr()
		saveJson(FR_FILE, HubChat.fr)
		for _, f in ipairs(HubChat.listeners) do pcall(f) end
	end
	local function ingest(key, raw)
		local okd, m = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not okd or type(m) ~= "table" then
			return
		end
		if type(m.n) ~= "string" or type(m.m) ~= "string" then
			return
		end
		local uid = (type(m.i) == "string" and m.i ~= "") and m.i or key
		if seen[uid] then
			return
		end
		seen[uid] = true
		local who = clean(m.n, 30)
		if who ~= lp.Name or m.c == "p" then
			HubChat.presence[who] = { d = clean(m.d or m.n, 30), u = tonumber(m.u), t = tonumber(m.t) or os.time(), s = tostring(m.s or ""), st = clean(m.st or "", 40), lv = tonumber(m.lv) or 1 }
		end
		if m.c == "p" then return end
		-- staff control messages (announcements / chat mute), only trusted when sent by the owner or an admin
		if m.c == "s" then
			local sf = HubChat.STAFF and HubChat.STAFF[who:lower()]
			if sf and sf.uid and tonumber(m.u) == sf.uid then
				if m.a == "mute" and type(m.to) == "string" then
					HubChat.staffMute[m.to] = true
					if m.to == lp.Name and not firstPoll then notify("Hub Chat", "Staff muted you in Hub Chat") end
				elseif m.a == "unm" and type(m.to) == "string" then
					HubChat.staffMute[m.to] = nil
				elseif m.a == "ann" then
					if not firstPoll and os.time() - (tonumber(m.t) or 0) < 300 then
						NovaUI.Sound("ping", 0.7)
						notify("ANNOUNCEMENT - " .. (sf.title or "STAFF"), clean(m.m, 200))
					end
					m.c = "g"
					m.m = "[ANNOUNCEMENT] " .. clean(m.m, 180)
				else
					return
				end
				if m.a ~= "ann" then return end
			else
				return
			end
		end
		if HubChat.staffMute[who] and not (HubChat.STAFF and HubChat.STAFF[who:lower()]) then return end
		if HubChat.fr.friends[who] then
			HubChat.fr.friends[who].d = clean(m.d or m.n, 30)
			HubChat.fr.friends[who].u = tonumber(m.u) or HubChat.fr.friends[who].u
		end
		if m.c == "f" then
			-- friend control message (request / accept / decline / remove) addressed to me
			if m.to == lp.Name and who ~= lp.Name then
				local ts = tonumber(m.t) or os.time()
				local fr = HubChat.fr
				if (fr.ctl[who] or 0) < ts then
					fr.ctl[who] = ts
					local info = { d = clean(m.d or m.n, 30), u = tonumber(m.u) }
					if m.a == "req" then
						if fr.friends[who] then
							HubChat.post({ c = "f", to = who, a = "acc", m = "." })
						else
							fr.incoming[who] = { d = info.d, u = info.u, t = ts }
							if not firstPoll then
								NovaUI.Sound("ping", 0.4)
								notify("Friend request", info.d .. " wants to be your friend (Hub Chat > Friends)")
							end
						end
					elseif m.a == "acc" then
						fr.friends[who] = info
						fr.incoming[who], fr.outgoing[who] = nil, nil
						if not firstPoll then notify("Friends", info.d .. " accepted your request") end
					elseif m.a == "dec" then
						fr.outgoing[who] = nil
					elseif m.a == "rem" then
						fr.friends[who] = nil
					end
					fireFr()
				end
			end
			return
		end
		if m.c == "d" and not (m.to == lp.Name or who == lp.Name) then return end
		local mine = m.n == lp.Name
		local e = { id = uid, n = clean(m.n, 30), d = clean(m.d or m.n, 30), m = clean(m.m, 200), t = tonumber(m.t) or os.time(), mine = mine, state = "ok", u = tonumber(m.u), c = (m.c == "l" or m.c == "d") and m.c or "g", s = tostring(m.s or ""), to = (m.c == "d") and tostring(m.to or "") or nil, st = clean(m.st or "", 40), lv = tonumber(m.lv) or 1 }
		if e.m == "" then
			return
		end
		local p = pending[uid]
		if p then
			p.state = "ok"
			p.t = e.t
			pending[uid] = nil
		else
			addMsg(e)
			if not firstPoll and not mine and HubChat.visible(e, "any") then
				activeUntil = os.clock() + 45
				local low = tostring(e.m):lower()
				if low:find("@" .. lp.Name:lower(), 1, true) or low:find("@" .. lp.DisplayName:lower(), 1, true) then
					NovaUI.Sound("ping", 0.5)
					notify("You were mentioned by " .. e.d, e.m)
				elseif not HubChat.uiOpen and not HubChat.muted then
					NovaUI.Sound("ping", 0.3)
					notify("Hub Chat - " .. e.d, e.m)
				end
			end
		end
	end
	local function poll()
		if not take(0.12) then
			return
		end
		if HubChat.mode == "ntfy" then
			local since = lastId or "3h"
			local code, body = request({ Url = NTFY .. "/json?poll=1&since=" .. since, Method = "GET" })
			if code == 429 then
				backoff = math.min(60, math.max(10, backoff * 2))
				HubChat.status = "rate limited, slowing down"
				return
			end
			if code ~= 200 then
				HubChat.status = "offline (" .. tostring(code) .. ")"
				backoff = math.min(30, backoff + 5)
				return
			end
			backoff = 0
			HubChat.status = "online"
			for line in tostring(body):gmatch("[^\r\n]+") do
				local ok, o = pcall(function()
					return HttpService:JSONDecode(line)
				end)
				if ok and type(o) == "table" and o.event == "message" and type(o.message) == "string" then
					lastId = o.id or lastId
					ingest(o.id, o.message)
				end
			end
		else
			local code, body = request({ Url = fbUrl .. '/yadsanchat.json?orderBy=%22$key%22&limitToLast=40', Method = "GET" })
			if code ~= 200 then
				HubChat.status = "offline (" .. tostring(code) .. ")"
				backoff = math.min(30, backoff + 5)
				return
			end
			backoff = 0
			HubChat.status = "online"
			local ok, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if ok and type(data) == "table" then
				local keys = {}
				for k in pairs(data) do
					keys[#keys + 1] = k
				end
				table.sort(keys)
				for _, k in ipairs(keys) do
					if type(data[k]) == "table" then
						ingest(k, HttpService:JSONEncode(data[k]))
					end
				end
			end
		end
		firstPoll = false
		fire()
	end
	-- chat history saved in the executor folder
	local HIST = "YADSAN_HUB/chat_history.json"
	local histT = 0
	pcall(function()
		if isfile and isfile(HIST) then
			local d = HttpService:JSONDecode(readfile(HIST))
			if type(d) == "table" then
				for _, m in ipairs(d) do
					if type(m) == "table" and type(m.n) == "string" and type(m.m) == "string" and type(m.id) == "string" then
						seen[m.id] = true
						table.insert(HubChat.msgs, { id = m.id, n = m.n, d = m.d or m.n, m = m.m, t = tonumber(m.t) or 0, mine = m.n == lp.Name, state = "ok", u = tonumber(m.u), c = (m.c == "l" or m.c == "d") and m.c or "g", s = tostring(m.s or ""), to = m.to, st = m.st, lv = tonumber(m.lv) or 1 })
					end
				end
			end
		end
	end)
	task.spawn(function()
		local lastN, lastId = -1, nil
		while true do
			task.wait(8)
			local n, l = #HubChat.msgs, HubChat.msgs[#HubChat.msgs]
			if n ~= lastN or (l and l.id) ~= lastId then
				lastN, lastId = n, l and l.id
				pcall(function()
					local out = {}
					for _, m in ipairs(HubChat.msgs) do
						if m.state == "ok" then out[#out + 1] = { id = m.id, n = m.n, d = m.d, m = m.m, t = m.t, u = m.u, c = m.c, s = m.s, to = m.to, st = m.st, lv = m.lv } end
					end
					pcall(makefolder, "YADSAN_HUB")
					writefile(HIST, HttpService:JSONEncode(out))
				end)
			end
		end
	end)
	local lastSend = 0
	function HubChat.send(text, scope, to)
		if HubChat.staffMute[lp.Name] then return false, "You are muted by staff" end
		scope = scope or HubChat.scope
		scope = (scope == "d" and to) and "d" or (scope == "l" and "l" or "g")
		text = clean(text, 200)
		if text == "" then
			return false, "empty"
		end
		if os.clock() - lastSend < 1.2 then
			return false, "Slow down a little"
		end
		if not httpReq then
			return false, "Your executor has no http request function"
		end
		if not take(3) then
			return false, "Too many messages, wait a bit"
		end
		lastSend = os.clock()
		activeUntil = os.clock() + 45
		local uid = HttpService:GenerateGUID(false)
		local e = { id = uid, n = lp.Name, d = HubChat.myName(), m = text, t = os.time(), mine = true, state = "sending", u = lp.UserId, c = scope, s = game.JobId, to = (scope == "d") and to or nil, st = HubChat.me.st, lv = myLevel() }
		pending[uid] = e
		addMsg(e)
		fire()
		NovaUI.Stat("msgs")
		task.spawn(function()
			local payload = HttpService:JSONEncode({ n = lp.Name, d = HubChat.myName(), t = os.time(), m = text, i = uid, u = lp.UserId, c = scope, s = game.JobId, to = e.to, st = HubChat.me.st, lv = e.lv })
			local code
			if HubChat.mode == "ntfy" then
				code = request({ Url = NTFY, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }, Body = payload })
			else
				code = request({ Url = fbUrl .. "/yadsanchat.json", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
			end
			if code ~= 200 then
				e.state = "failed"
				pending[uid] = nil
				seen[uid] = true
				fire()
			else
				task.delay(2, function()
					if pending[uid] then
						pending[uid].state = "ok"
						pending[uid] = nil
					end
					fire()
				end)
				task.defer(poll)
			end
		end)
		return true
	end
	-- scope "g" = global chat, "l" = this server only, "any" = anything this client may see
	function HubChat.visible(m, scope)
		scope = scope or HubChat.scope
		if m.c == "d" then return scope == "any" end
		local isLocal = m.c == "l"
		if isLocal and m.s ~= game.JobId then return false end
		if scope == "l" then return isLocal end
		if scope == "g" then return not isLocal end
		return true
	end
	function HubChat.list(scope)
		local out = {}
		for _, m in ipairs(HubChat.msgs) do
			if HubChat.visible(m, scope) then out[#out + 1] = m end
		end
		return out
	end
	-- tiny "I'm online" ping (not shown as a message): used for the staff user list
	function HubChat.ping()
		if not httpReq or not take(2) then return end
		local payload = HttpService:JSONEncode({ n = lp.Name, d = HubChat.myName(), t = os.time(), m = ".", i = HttpService:GenerateGUID(false), u = lp.UserId, c = "p", s = game.JobId, st = HubChat.me.st, lv = myLevel() })
		if HubChat.mode == "ntfy" then
			request({ Url = NTFY, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }, Body = payload })
		else
			request({ Url = fbUrl .. "/yadsanchat.json", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
		end
		HubChat.presence[lp.Name] = { d = HubChat.myName(), u = lp.UserId, t = os.time(), s = game.JobId, st = HubChat.me.st, lv = myLevel() }
	end
	task.spawn(function()
		task.wait(6)
		while true do
			pcall(HubChat.ping)
			task.wait(600)
		end
	end)
	function HubChat.allUsers()
		local u, now = {}, os.time()
		for n, v in pairs(HubChat.presence) do
			if now - v.t < 2400 then u[n] = { n = n, d = v.d, u = v.u, t = v.t, s = v.s } end
		end
		for _, m in ipairs(HubChat.msgs) do
			if now - (m.t or 0) < 2400 and (not u[m.n] or u[m.n].t < m.t) then u[m.n] = { n = m.n, d = m.d, u = m.u, t = m.t, s = m.s } end
		end
		local out = {}
		for _, v in pairs(u) do out[#out + 1] = v end
		table.sort(out, function(a, b) return a.t > b.t end)
		return out
	end
	-- generic post (friend control etc.)
	function HubChat.post(t)
		if not httpReq or not take(2) then return false end
		t.n, t.d, t.t, t.i, t.u, t.s = lp.Name, HubChat.myName(), os.time(), HttpService:GenerateGUID(false), lp.UserId, game.JobId
		t.st, t.lv = HubChat.me.st, myLevel()
		seen[t.i] = true
		task.spawn(function()
			local payload = HttpService:JSONEncode(t)
			pcall(function()
				if HubChat.mode == "ntfy" then
					request({ Url = NTFY, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }, Body = payload })
				else
					request({ Url = fbUrl .. "/yadsanchat.json", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
				end
			end)
		end)
		return true
	end
	function HubChat.isFriend(n) return HubChat.fr.friends[n] ~= nil end
	function HubChat.request(n, d, u)
		if n == lp.Name or HubChat.isFriend(n) then return false end
		HubChat.fr.outgoing[n] = os.time()
		HubChat.post({ c = "f", to = n, a = "req", m = "." })
		fireFr()
		return true
	end
	function HubChat.accept(n)
		local inc = HubChat.fr.incoming[n]
		HubChat.fr.friends[n] = { d = inc and inc.d or n, u = inc and inc.u }
		HubChat.fr.incoming[n], HubChat.fr.outgoing[n] = nil, nil
		HubChat.post({ c = "f", to = n, a = "acc", m = "." })
		fireFr()
	end
	function HubChat.decline(n)
		HubChat.fr.incoming[n] = nil
		HubChat.post({ c = "f", to = n, a = "dec", m = "." })
		fireFr()
	end
	function HubChat.unfriend(n)
		HubChat.fr.friends[n] = nil
		HubChat.post({ c = "f", to = n, a = "rem", m = "." })
		fireFr()
	end
	function HubChat.online(n)
		local p = HubChat.presence[n]
		return p ~= nil and os.time() - (p.t or 0) < 1200
	end
	function HubChat.dm(n)
		local out = {}
		for _, m in ipairs(HubChat.msgs) do
			if m.c == "d" and ((m.mine and m.to == n) or (not m.mine and m.n == n)) then out[#out + 1] = m end
		end
		return out
	end
	function HubChat.joinFriend(n)
		local p = HubChat.presence[n]
		if not p or not p.s or p.s == "" then return false, "No server info for " .. n .. " yet (they appear after they chat or open the hub)" end
		if p.s == game.JobId then return false, n .. " is already in your server" end
		local ok, err = pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, p.s, lp) end)
		return ok, ok and ("Joining " .. n) or tostring(err)
	end
	function HubChat.users(scope)
		local u, now = {}, os.time()
		for _, m in ipairs(HubChat.msgs) do
			if now - (m.t or 0) < 900 and (scope ~= "l" or Players:FindFirstChild(m.n)) then
				u[m.n] = { d = m.d, t = m.t, u = m.u }
			end
		end
		local out = {}
		for n, v in pairs(u) do
			out[#out + 1] = { n = n, d = v.d, t = v.t, u = v.u }
		end
		table.sort(out, function(a, b)
			return a.t > b.t
		end)
		return out
	end
	function HubChat.setServer(u)
		u = tostring(u or ""):gsub("%s+", ""):gsub("/+$", "")
		if u == "" then
			HubChat.mode, fbUrl = "ntfy", ""
			pcall(function()
				if delfile and isfile and isfile(CHAT_FILE) then
					delfile(CHAT_FILE)
				end
			end)
		else
			if not u:match("^https://") then
				return false
			end
			HubChat.mode, fbUrl = "firebase", u
			pcall(function()
				pcall(makefolder, "YADSAN_HUB")
				writefile(CHAT_FILE, u)
			end)
		end
		seen, pending, lastId, firstPoll = {}, {}, nil, true
		HubChat.msgs = {}
		return true
	end
	HubChat.poll = poll
	function HubChat.announce(text)
		text = clean(text, 180)
		if text == "" then return false end
		return HubChat.post({ c = "s", a = "ann", m = text })
	end
	function HubChat.mute(name, on)
		name = tostring(name or ""):gsub("%s+", "")
		if name == "" then return false end
		HubChat.staffMute[name] = on and true or nil
		return HubChat.post({ c = "s", a = on and "mute" or "unm", to = name, m = "." })
	end
	NovaUI.HubChat = HubChat
	-- owner / admin recognition: matched by username AND the real userId (resolved from the name)
	HubChat.STAFF = {
		supermonkxscripts = { real = "AGKaBaap_YadsanAsuka", title = "OWNER", a = Color3.fromRGB(255, 226, 120), b = Color3.fromRGB(255, 150, 30) },
		theredauth0r = { real = "ZMxCS_Yakuza7", title = "ADMIN", a = Color3.fromRGB(255, 214, 90), b = Color3.fromRGB(255, 110, 60) },
	}
	function HubChat.staffOf(name, uid)
		local s = HubChat.STAFF[tostring(name or ""):lower()]
		if s and s.uid and tonumber(uid) == s.uid then
			return s
		end
		return nil
	end
	task.spawn(function()
		for _, s in pairs(HubChat.STAFF) do
			local ok, id = pcall(function()
				return Players:GetUserIdFromNameAsync(s.real)
			end)
			if ok and type(id) == "number" then
				s.uid = id
			end
		end
		fire()
	end)
	task.spawn(function()
		task.wait(1)
		local wsAlive = 0
		local wsStarted = false
		-- realtime push through a websocket (ntfy supports it); polling stays as a slow safety net
		local function startWs()
			if wsStarted then return end
			wsStarted = true
			task.spawn(function()
				while true do
					local WS = WebSocket
					if HubChat.mode == "ntfy" and WS and WS.connect then
						local url = NTFY:gsub("^https://", "wss://"):gsub("^http://", "ws://") .. "/ws?since=" .. tostring(lastId or "20s")
						local ok, sock = pcall(WS.connect, url)
						if ok and sock then
							local closed = false
							sock.OnMessage:Connect(function(msg)
								local okj, o = pcall(function() return HttpService:JSONDecode(msg) end)
								if okj and type(o) == "table" then
									wsAlive = os.clock()
									if o.event == "message" and type(o.message) == "string" then
										lastId = o.id or lastId
										pcall(ingest, o.id, o.message)
										HubChat.status = "online (live)"
										fire()
									end
								end
							end)
							sock.OnClose:Connect(function() closed = true end)
							wsAlive = os.clock()
							while not closed and HubChat.mode == "ntfy" and os.clock() - wsAlive < 90 do task.wait(2) end
							pcall(function() sock:Close() end)
							wsAlive = 0
						end
					end
					task.wait(4)
				end
			end)
		end
		while true do
			pcall(poll)
			startWs()
			local live = os.clock() - wsAlive < 60
			local wait = live and 20 or ((os.clock() < activeUntil or HubChat.uiOpen) and 3 or 6)
			task.wait(wait + backoff)
		end
	end)
end

local function chatText(maxN)
	local out = {}
	local L = HubChat.list("g")
	local from = math.max(1, #L - (maxN or 25) + 1)
	for i = from, #L do
		local m = L[i]
		out[#out + 1] = ((HubChat.staffOf(m.n, m.u) and ("[" .. HubChat.staffOf(m.n, m.u).title .. "] ") or "") .. (m.mine and "You" or m.d)) .. (m.state == "sending" and " (sending)" or m.state == "failed" and " (FAILED)" or "") .. ": " .. m.m
	end
	return #out == 0 and "No messages yet. Say hi!" or table.concat(out, "\n")
end

local Chat = Window:CreateTab({ Name = "Chat", Icon = "chat" })
local chatBox = Chat:Section({ Title = "Hub Chat (YADSAN users only)", Icon = "chat", Side = "Left" })
local chatLog = chatBox:Label("Connecting...")
local chatMsg
chatMsg = chatBox:Input({ Placeholder = "Type a message and press Enter", OnBlur = false, Callback = function(t)
	local ok, e = HubChat.send(t)
	if not ok and e ~= "empty" then notify("Chat", tostring(e)) end
	task.defer(function() chatMsg:Set("", true) end)
end })
chatBox:Button({ Title = "Send", Style = "Primary", Callback = function()
	local ok, e = HubChat.send(chatMsg:Get())
	if not ok and e ~= "empty" then notify("Chat", tostring(e)) end
	chatMsg:Set("", true)
end })
local chatUsers = chatBox:Label("Active: nobody yet")
HubChat.onUpdate(function()
	chatLog:Set(chatText(25))
	local u = HubChat.users()
	local names = {}
	for _, x in ipairs(u) do names[#names + 1] = x.d end
	chatUsers:Set("Active (15 min): " .. (#names == 0 and "nobody yet" or table.concat(names, ", ")) .. "  |  " .. HubChat.status)
end)
local chatSet = Chat:Section({ Title = "Server", Icon = "settings", Side = "Right" })
chatSet:Paragraph({ Title = "How it works", Content = "Works out of the box through the free public ntfy.sh relay: every YADSAN HUB user is in one chat. It is NOT private and has rate limits, so don't share secrets. For a private chat, paste your own Firebase Realtime Database URL below (everyone must use the same one). Leave empty and Save to go back to the default." })
local urlIn = chatSet:Input({ Placeholder = "https://your-db.firebaseio.com (optional)" })
chatSet:Button({ Title = "Save server", Style = "Primary", Callback = function()
	local ok = HubChat.setServer(urlIn:Get())
	notify("Chat", ok and "Server saved, reconnecting..." or "URL must start with https://")
end })
do
------------------------------------------------------------------------
-- PHONE APPS: Hub Chat + Fit Saver run INSIDE the Life Together phone screen (overlay on the phone)
------------------------------------------------------------------------
local appGuiParent = Window.Gui.Parent
local TS = game:GetService("TweenService")
local TH = { good = Color3.fromRGB(90, 220, 150), bad = Color3.fromRGB(255, 100, 120) }
local THEMES = {
	{ name = "Purple", h = 0.75, s = 1 }, { name = "Crimson", h = 0.98, s = 1 }, { name = "Rose", h = 0.9, s = 0.85 },
	{ name = "Ocean", h = 0.56, s = 1 }, { name = "Emerald", h = 0.4, s = 0.9 }, { name = "Gold", h = 0.12, s = 1 },
	{ name = "Sunset", h = 0.04, s = 0.9 }, { name = "Mono", h = 0, s = 0 },
}
local function applyThemeData(t)
	local h, s = t.h, t.s
	local function c(sat, val)
		return Color3.fromHSV(h, math.clamp(sat * s, 0, 1), val)
	end
	TH.name = t.name
	TH.acc, TH.bg, TH.bar = c(0.72, 0.95), c(0.6, 0.09), c(0.6, 0.14)
	TH.card, TH.card2 = c(0.55, 0.22), c(0.5, 0.31)
	TH.bgTop, TH.bgBot = c(0.6, 0.17), c(0.55, 0.07)
	TH.hdrA, TH.hdrB = c(0.75, 0.62), c(0.7, 0.24)
	TH.bubA, TH.bubB = c(0.7, 1), c(0.8, 0.78)
	TH.cardA, TH.cardB = c(0.5, 0.32), c(0.55, 0.2)
	TH.text, TH.dim = Color3.fromHSV(h, 0.06 * s, 1), c(0.25, 0.8)
end
do
	local saved
	pcall(function()
		if isfile and isfile("YADSAN_HUB/app_theme.txt") then saved = readfile("YADSAN_HUB/app_theme.txt"):gsub("%s+", "") end
	end)
	local pick = THEMES[1]
	for _, t in ipairs(THEMES) do
		if t.name == saved then pick = t end
	end
	applyThemeData(pick)
end
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	if parent then
		if o:IsA("GuiObject") and (props == nil or props.ZIndex == nil) and parent:IsA("GuiObject") then
			o.ZIndex = parent.ZIndex + 1
		end
		o.Parent = parent
	end
	return o
end
local function round(o, r)
	return mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end
local function pad(o, l, r, t, b)
	return mk("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l), PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l) }, o)
end
local function txt(parent, text, size, color, font, props)
	local p = { BackgroundTransparency = 1, Text = text, TextSize = size or 13, TextColor3 = color or TH.text, Font = font or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return mk("TextLabel", p, parent)
end
local function btn(parent, text, accent, props)
	local p = { Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TH.text, AutoButtonColor = true, BackgroundColor3 = accent and TH.acc or TH.card2, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = mk("TextButton", p, parent)
	round(b, 9)
	return b
end
local function shown(o)
	while o and o ~= game do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end
local function phoneGui()
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	return pg and pg:FindFirstChild("Phone")
end
local function overlayHost()
	local o = phoneGui()
	for _, n in ipairs({ "PhoneHome", "MasterFrame" }) do
		o = o and o:FindFirstChild(n)
	end
	if not o then return nil end
	local h = o:FindFirstChild("Holder")
	if h and not (h:FindFirstChildWhichIsA("UIListLayout") or h:FindFirstChildWhichIsA("UIGridLayout")) then
		return h, o
	end
	return o, o
end

-- manual fit of the app inside the phone screen (saved in YADSAN_HUB/app_fit.json)
NovaUI.AppFit = { l = 0, r = 0, t = 0, b = 0, whole = false }
pcall(function()
	if isfile and isfile("YADSAN_HUB/app_fit.json") then
		local d = HttpService:JSONDecode(readfile("YADSAN_HUB/app_fit.json"))
		for _, k in ipairs({ "l", "r", "t", "b" }) do
			if type(d[k]) == "number" then NovaUI.AppFit[k] = math.clamp(d[k], -30, 60) end
		end
		NovaUI.AppFit.whole = d.whole == true
	end
end)
local function saveFit()
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile("YADSAN_HUB/app_fit.json", HttpService:JSONEncode(NovaUI.AppFit))
	end)
end
local current
local closeApp
function closeApp(instant)
	local c = current
	if not c then return end
	current = nil
	c.alive = false
	for _, e in ipairs(c.stack) do
		if e.onClose then pcall(e.onClose) end
	end
	pcall(c.def.onClose)
	if instant or not c.overlay.Parent then
		pcall(function() c.overlay:Destroy() end)
		return
	end
	pcall(function() TS:Create(c.scaler, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(0, 1) }):Play() end)
	task.delay(0.25, function() pcall(function() c.overlay:Destroy() end) end)
end

local function openApp(def, opts)
	opts = opts or {}
	if current then
		local same = current.def == def
		closeApp(true)
		if same and not opts.reopen then return end
	end
	local host, mf = overlayHost()
	if not host or host.AbsoluteSize.X < 20 or not shown(host) then
		notify("Phone", "Open your phone first, then tap the app.")
		return
	end
	-- CanvasGroup clips its children to the rounded corners (a plain Frame cannot), so nothing pokes out of the phone
	local FI = NovaUI.AppFit
	if FI.whole and mf then host = mf end
	local overlay = mk("CanvasGroup", { Name = "YadsanAppOverlay", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(FI.l, FI.t), Size = UDim2.new(1, -(FI.l + FI.r), 1, -(FI.t + FI.b)), Active = true, ZIndex = 100 }, host)
	local hc = host:FindFirstChildOfClass("UICorner") or (mf and mf:FindFirstChildOfClass("UICorner"))
	local rad = math.clamp(math.floor(math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) * 0.13), 18, 46)
	if hc and hc.CornerRadius.Offset > rad then rad = hc.CornerRadius.Offset end
	mk("UICorner", { CornerRadius = UDim.new(0, rad) }, overlay)
	local DW = 300
	local scaler = mk("Frame", { Name = "Scaler", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(DW, 600), Position = UDim2.fromScale(0, 1) }, overlay)
	mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(TH.bgTop, TH.bgBot) }, scaler)
	local us = mk("UIScale", {}, scaler)
	local function fit()
		local a = overlay.AbsoluteSize
		if a.X < 10 then return end
		us.Scale = 1
		local m = scaler.AbsoluteSize.X
		if m < 1 then m = DW end
		us.Scale = a.X / m
		scaler.Size = UDim2.fromOffset(DW, DW * a.Y / a.X)
	end
	fit()
	overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local ctx = { startTab = opts.tab, alive = true, def = def, overlay = overlay, scaler = scaler, stack = {}, DW = DW }
	local header = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 50) }, scaler)
	mk("UIGradient", { Rotation = 0, Color = ColorSequence.new(TH.hdrA, TH.hdrB) }, header)
	mk("Frame", { BackgroundColor3 = TH.acc, BackgroundTransparency = 0.55, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) }, header)
	local backB = mk("TextButton", { Text = "‹", Font = Enum.Font.GothamBold, TextSize = 30, TextColor3 = TH.text, BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 50) }, header)
	local titleL = txt(header, def.title, 16, TH.text, Enum.Font.GothamBlack, { Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -120, 0, 20) })
	local subL = txt(header, "", 10, TH.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(40, 26), Size = UDim2.new(1, -120, 0, 14) })
	local function ctx_setSub(t) subL.Text = t end
	local right = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.new(1, -78, 0, 0), Size = UDim2.fromOffset(74, 50) }, header)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4) }, right)
	local content = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -72), ClipsDescendants = true }, scaler)
	local homeBar = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22) }, scaler)
	local pill = mk("Frame", { BackgroundColor3 = TH.dim, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 5) }, homeBar)
	round(pill, 3)
	homeBar.MouseButton1Click:Connect(function() closeApp() end)

	local function setRight(build)
		for _, c in ipairs(right:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		if build then build(right) end
	end
	ctx.setSub = ctx_setSub
	function ctx.push(title, build, rightBuild)
		local top = ctx.stack[#ctx.stack]
		local view = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = (#ctx.stack == 0) and UDim2.fromScale(0, 0) or UDim2.fromScale(1, 0) }, content)
		local entry = { view = view, title = title, rightBuild = rightBuild }
		ctx.stack[#ctx.stack + 1] = entry
		entry.onClose = build(view, entry)
		titleL.Text = title
		setRight(rightBuild)
		if top then
			TS:Create(top.view, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(-0.3, 0) }):Play()
			TS:Create(view, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0, 0) }):Play()
		end
	end
	function ctx.pop()
		if #ctx.stack <= 1 then return false end
		local e = table.remove(ctx.stack)
		if e.onClose then pcall(e.onClose) end
		local prev = ctx.stack[#ctx.stack]
		TS:Create(e.view, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(1, 0) }):Play()
		TS:Create(prev.view, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0, 0) }):Play()
		task.delay(0.22, function() pcall(function() e.view:Destroy() end) end)
		titleL.Text = prev.title
		setRight(prev.rightBuild)
		return true
	end
	function ctx.back()
		if not ctx.pop() then closeApp() end
	end
	backB.MouseButton1Click:Connect(ctx.back)
	current = ctx
	def.build(ctx)
	if opts.instant then
		scaler.Position = UDim2.fromScale(0, 0)
	else
		TS:Create(scaler, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }):Play()
	end
end

------------------------------------------------------------------------
-- Hub Chat app
------------------------------------------------------------------------
local function dropListener(list, fn)
	for i, f in ipairs(list) do
		if f == fn then table.remove(list, i) break end
	end
end
local function reopen(def, tab)
	closeApp(true)
	openApp(def, { tab = tab, reopen = true, instant = true })
end
local function setTheme(t, def, tab)
	applyThemeData(t)
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile("YADSAN_HUB/app_theme.txt", t.name)
	end)
	reopen(def, tab)
end
local function scrollList(body)
	local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 10, 10, 6, 12)
	return sf
end
local function pfp(parent, name, disp, uid, size, ring)
	local pl = Players:FindFirstChild(tostring(name))
	uid = tonumber(uid) or (pl and pl.UserId)
	local f
	if uid then
		f = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(uid) }, parent)
	else
		local hue = (#tostring(name) * 37) % 100 / 100
		f = mk("TextLabel", { BackgroundColor3 = Color3.fromHSV(0.7 + hue * 0.2, 0.55, 0.7), BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Text = tostring(disp or name):sub(1, 1):upper(), Font = Enum.Font.GothamBlack, TextSize = size * 0.5, TextColor3 = Color3.new(1, 1, 1) }, parent)
	end
	round(f, size)
	if ring then
		local st = mk("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, f)
		mk("UIGradient", { Color = ColorSequence.new(ring.a, ring.b) }, st)
	end
	return f
end
local function goldName(parent, text, st, props)
	local p = { Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in pairs(props or {}) do p[k] = v end
	local l = txt(parent, text, 11, Color3.new(1, 1, 1), Enum.Font.GothamBlack, p)
	if st then
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, l)
	else
		l.TextColor3 = Color3.fromHSV(0, 0, 0.82)
		l.Font = Enum.Font.GothamBold
	end
	return l
end
local function titlePill(parent, st, order)
	local pill = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 0, 0, 13), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 2 }, parent)
	round(pill, 7)
	mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, pill)
	local l = txt(pill, st.title, 8, Color3.fromRGB(25, 10, 30), Enum.Font.GothamBlack, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center })
	pad(l, 6, 6, 0, 0)
	return pill
end

-- tabs with a content body; every page builder may return a cleanup function
local function tabbed(ctx, view, names, builders, start)
	local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, view)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, bar)
	pad(bar, 10, 10, 5, 3)
	local body = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), ClipsDescendants = true }, view)
	local btns, cleanup, active = {}, nil, nil
	local api = { body = body }
	function api.select(n)
		if cleanup then pcall(cleanup) cleanup = nil end
		for _, c in ipairs(body:GetChildren()) do c:Destroy() end
		active = n
		for k, b in pairs(btns) do
			b.BackgroundColor3 = (k == n) and TH.acc or TH.card
		end
		cleanup = builders[n](body, api)
	end
	function api.current() return active end
	function api.close() if cleanup then pcall(cleanup) cleanup = nil end end
	for _, n in ipairs(names) do
		local b = btn(bar, n, false, { Size = UDim2.new(1 / #names, -5, 1, 0), BackgroundColor3 = TH.card, TextSize = 12 })
		btns[n] = b
		b.MouseButton1Click:Connect(function() if active ~= n then api.select(n) end end)
	end
	api.select(start and builders[start] and start or names[1])
	return api
end

local function settingsPage(body, def, tabName, extra)
	local sf = scrollList(body)
	txt(sf, "APP THEME", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1 })
	local grid = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, sf)
	mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 54), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, t in ipairs(THEMES) do
		local b = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, LayoutOrder = i }, grid)
		round(b, 12)
		mk("UIGradient", { Rotation = 25, Color = ColorSequence.new(Color3.fromHSV(t.h, 0.75 * t.s, 0.72), Color3.fromHSV(t.h, 0.7 * t.s, 0.22)) }, b)
		if TH.name == t.name then
			mk("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, b)
		end
		txt(b, t.name, 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0) })
		if TH.name == t.name then
			txt(b, "ACTIVE", 8, Color3.new(1, 1, 1), Enum.Font.GothamBlack, { Position = UDim2.new(1, -52, 0, 6), Size = UDim2.fromOffset(46, 10), TextXAlignment = Enum.TextXAlignment.Right })
		end
		b.MouseButton1Click:Connect(function() setTheme(t, def, tabName) end)
	end
	txt(sf, "SCREEN FIT (if the app does not match your phone)", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 20 })
	local FIT = NovaUI.AppFit
	for i, d in ipairs({ { "l", "Left" }, { "r", "Right" }, { "t", "Top" }, { "b", "Bottom" } }) do
		local row = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 20 + i }, sf)
		round(row, 12)
		txt(row, d[2] .. " edge", 12, TH.text, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0) })
		local val = txt(row, tostring(FIT[d[1]]), 12, TH.acc, Enum.Font.GothamBold, { Position = UDim2.new(1, -96, 0, 0), Size = UDim2.fromOffset(40, 40), TextXAlignment = Enum.TextXAlignment.Center })
		local mi = btn(row, "-", false, { Position = UDim2.new(1, -136, 0.5, -14), Size = UDim2.fromOffset(34, 28), TextSize = 16 })
		local pl = btn(row, "+", false, { Position = UDim2.new(1, -50, 0.5, -14), Size = UDim2.fromOffset(34, 28), TextSize = 16 })
		local function bump(dv)
			FIT[d[1]] = math.clamp(FIT[d[1]] + dv, -30, 60)
			val.Text = tostring(FIT[d[1]])
			saveFit()
		end
		mi.MouseButton1Click:Connect(function() bump(-2) end)
		pl.MouseButton1Click:Connect(function() bump(2) end)
	end
	local wr = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 26 }, sf)
	round(wr, 12)
	txt(wr, "Use the whole phone frame", 12, TH.text, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0) })
	local wb = btn(wr, FIT.whole and "ON" or "OFF", FIT.whole, { Position = UDim2.new(1, -62, 0.5, -14), Size = UDim2.fromOffset(52, 28), TextSize = 12 })
	wb.MouseButton1Click:Connect(function()
		FIT.whole = not FIT.whole
		wb.Text = FIT.whole and "ON" or "OFF"
		saveFit()
	end)
	txt(sf, "Changes apply the next time you open an app.", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 27 })
	if extra then extra(sf) end
end

------------------------------------------------------------------------
-- Hub Chat app  (tabs: Chat / People / Settings)
------------------------------------------------------------------------
local ChatApp = { id = "Chat", title = "Hub Chat", icon = "chat" }
local profileCard
local function scopeBar(parent, onChange)
	local bar = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 30) }, parent)
	round(bar, 15)
	local bs = {}
	local function paint()
		for k, b in pairs(bs) do
			b.BackgroundColor3 = (HubChat.scope == k) and TH.acc or TH.card
			b.BackgroundTransparency = (HubChat.scope == k) and 0 or 1
		end
	end
	for i, d in ipairs({ { "g", "Global" }, { "l", "Local server" } }) do
		local b = btn(bar, d[2], false, { Position = UDim2.new((i - 1) / 2, 2, 0, 2), Size = UDim2.new(0.5, -4, 1, -4), TextSize = 11 })
		round(b, 13)
		bs[d[1]] = b
		b.MouseButton1Click:Connect(function()
			if HubChat.scope ~= d[1] then HubChat.scope = d[1] paint() onChange() end
		end)
	end
	paint()
	return bar
end
local function chatPage(ctx, body)
	local anim = {}
	local animConn = game:GetService("RunService").Heartbeat:Connect(function()
		local t = os.clock()
		for g, kind in pairs(anim) do
			if g.Parent then
				if kind == 1 then g.Rotation = (t * 80) % 360 else g.Offset = Vector2.new(math.sin(t * 1.6) * 0.5, 0) end
			else
				anim[g] = nil
			end
		end
	end)
	local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -86), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 10, 10, 8, 8)
	local lastSig
	local function render(force)
		local msgs = HubChat.list(HubChat.scope)
		local users = HubChat.users(HubChat.scope)
		ctx.setSub((HubChat.scope == "l" and "this server" or "global") .. "  -  " .. #users .. " online  -  " .. tostring(HubChat.status))
		local last = msgs[#msgs]
		local bad = 0
		for _, m in ipairs(msgs) do if m.state ~= "ok" then bad = bad + 1 end end
		local sig = HubChat.scope .. #msgs .. ":" .. (last and last.id or "") .. ":" .. bad .. ":" .. tostring(HubChat.STAFF.AGKaBaap_YadsanAsuka.uid) .. tostring(HubChat.STAFF.theredauth0r.uid)
		if not force and sig == lastSig then return end
		lastSig = sig
		for _, c in ipairs(sf:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		if #msgs == 0 then
			local e = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), LayoutOrder = 1 }, sf)
			local ring = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, -35, 0, 24) }, e)
			round(ring, 35)
			mk("UIStroke", { Color = TH.acc, Thickness = 2, Transparency = 0.2 }, ring)
			txt(ring, "M", 34, TH.acc, Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			txt(e, "No messages yet", 15, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
			txt(e, HubChat.scope == "l" and "Only people in this server see local messages" or "Say hi to everyone using Celestial Godverse", 11, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local first = math.max(1, #msgs - 39)
		local holes = 0
		for i = #msgs, first, -1 do
			local m = msgs[i]
			if HubChat.staffOf(m.n, m.u) then holes = holes + 1 end
		end
		local holeBudget = 8
		for i = first, #msgs do
			local m, prev, nxt = msgs[i], msgs[i - 1], msgs[i + 1]
			if i == first then prev = nil end
			local st = HubChat.staffOf(m.n, m.u)
			local newGroup = not prev or prev.n ~= m.n or (m.t - (prev.t or 0)) > 180
			local lastInGroup = not nxt or nxt.n ~= m.n or (nxt.t - m.t) > 180
			local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i + 1 }, sf)
			mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = m.mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left }, row)
			local function avatarSlot(order)
				local slot = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = order }, row)
				if lastInGroup then
					pfp(slot, m.n, m.d, m.u, 28, st)
					local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = slot.ZIndex + 6 }, slot)
					hit.MouseButton1Click:Connect(function() ctx.push(m.d, function(v) profileCard(ctx, v, m.n) end) end)
				end
			end
			if not m.mine then avatarSlot(1) end
			local col = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 }, row)
			mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), HorizontalAlignment = m.mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left }, col)
			if newGroup and (not m.mine or st) then
				local nrow = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, col)
				mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, nrow)
				local gl = goldName(nrow, (st and "★ " or "") .. m.d, st, { LayoutOrder = 1 })
				if st then local ug = gl:FindFirstChildOfClass("UIGradient") if ug then anim[ug] = 2 end end
				if st then titlePill(nrow, st, 2) end
			end
			local b = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), LayoutOrder = 2, ClipsDescendants = true }, col)
			round(b, 14)
			mk("UISizeConstraint", { MaxSize = Vector2.new(190, math.huge) }, b)
			local textZ = b.ZIndex + 4
			if st then
				b.BackgroundColor3 = Color3.fromRGB(8, 4, 16)
				local gs = mk("UIStroke", { Thickness = 1.6, Color = Color3.new(1, 1, 1) }, b)
				anim[mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)] = 1
				mk("UIGradient", { Rotation = 25, Color = ColorSequence.new(Color3.fromRGB(46, 20, 62), Color3.fromRGB(58, 36, 10)) }, b)
				b.BackgroundColor3 = Color3.new(1, 1, 1)
				if holeBudget > 0 and #msgs - i < 14 then
					holeBudget = holeBudget - 1
					local fx = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = b.ZIndex + 1 }, b)
					pcall(function()
						NovaUI.MakeBlackhole(fx, 96, { Position = UDim2.new(1, -8, 0.5, 0), ParticleCount = 5, ZIndex = fx.ZIndex + 1 })
						NovaUI.MakeBlackhole(fx, 70, { Position = UDim2.new(0, 4, 0.5, 0), ParticleCount = 4, ZIndex = fx.ZIndex + 1 })
					end)
				end
			elseif m.mine then
				mk("UIGradient", { Rotation = 35, Color = ColorSequence.new(TH.bubA, TH.bubB) }, b)
			else
				b.BackgroundColor3 = TH.card
				mk("UIStroke", { Color = TH.acc, Transparency = 0.8, Thickness = 1 }, b)
			end
			local tl = mk("TextLabel", { BackgroundTransparency = 1, Text = m.m, TextWrapped = true, TextSize = 13, Font = st and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextColor3 = st and Color3.fromRGB(255, 240, 200) or Color3.new(1, 1, 1), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = textZ }, b)
			pad(tl, 11, 11, 7, 7)
			mk("UISizeConstraint", { MaxSize = Vector2.new(190, math.huge) }, tl)
			if lastInGroup or m.state ~= "ok" then
				local meta = os.date("%H:%M", m.t or os.time())
				if m.state == "sending" then meta = "sending..." elseif m.state == "failed" then meta = "failed to send" end
				txt(col, meta, 9, m.state == "failed" and TH.bad or TH.dim, Enum.Font.Gotham, { Size = UDim2.new(0, 0, 0, 11), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3 })
			end
			if m.mine then
				local slot = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = 3 }, row)
				if lastInGroup then pfp(slot, m.n, m.d, m.u or lp.UserId, 28, st) end
			end
		end
		task.defer(function()
			if sf.Parent then sf.CanvasPosition = Vector2.new(0, 1e6) end
		end)
	end
	local box
	scopeBar(body, function()
		if box then box.PlaceholderText = (HubChat.scope == "l") and "Message this server..." or "Message everyone..." end
		render(true)
	end)
	local bar = mk("Frame", { BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 48) }, body)
	box = mk("TextBox", { PlaceholderText = (HubChat.scope == "l") and "Message this server..." or "Message everyone...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -78, 0, 36) }, bar)
	round(box, 18)
	pad(box, 12, 8, 0, 0)
	local send = btn(bar, "Send", true, { Position = UDim2.new(1, -66, 0, 6), Size = UDim2.fromOffset(58, 36), BackgroundColor3 = TH.acc })
	round(send, 18)
	local function go()
		local ok, e = HubChat.send(box.Text, HubChat.scope)
		if ok then
			box.Text = ""
		elseif e ~= "empty" then
			notify("Chat", tostring(e))
		end
	end
	send.MouseButton1Click:Connect(go)
	box.FocusLost:Connect(function(enter) if enter then go() end end)
	local fn = function()
		if ctx.alive and body.Parent then render(false) end
	end
	table.insert(HubChat.listeners, fn)
	HubChat.setUiOpen(true)
	render(true)
	task.spawn(function() pcall(HubChat.poll) end)
	return function()
		pcall(function() animConn:Disconnect() end)
		dropListener(HubChat.listeners, fn)
		HubChat.setUiOpen(false)
	end
end
local function staffInfo(n, u) return HubChat.staffOf(n, u) end
local function nameOk(hn)
	if hn == "" then return true end
	if #hn < 2 then return false, "Name must be at least 2 characters" end
	local low = hn:lower():gsub("[%s_%.%-]", "")
	if low:find("AGKaBaap_YadsanAsuka") or low:find("ZMxCS_Yakuza7") or low:find("owner") or low:find("admin") then
		if not HubChat.staffOf(lp.Name, lp.UserId) then return false, "That name is reserved" end
	end
	return true
end
local function infoOf(n)
	local p = HubChat.presence[n] or {}
	local f = HubChat.fr.friends[n] or {}
	return { n = n, d = p.d or f.d or n, u = p.u or f.u, st = p.st or "", lv = p.lv or 1, s = p.s, t = p.t }
end
local function pill(parent, text, col, order)
	local f = mk("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 0, 0, 13), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 3 }, parent)
	round(f, 7)
	local l = txt(f, text, 8, Color3.fromRGB(20, 8, 30), Enum.Font.GothamBlack, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center })
	pad(l, 6, 6, 0, 0)
	return f
end

-- one conversation (direct messages)
local function dmView(ctx, view, name)
	local info = infoOf(name)
	local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -48), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, view)
	mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 10, 10, 8, 8)
	local lastSig
	local function render()
		local list = HubChat.dm(name)
		local last = list[#list]
		local sig = #list .. ":" .. (last and last.id or "") .. (last and last.state or "")
		if sig == lastSig then return end
		lastSig = sig
		for _, c in ipairs(sf:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		txt(sf, "Direct messages use the shared YADSAN HUB relay. Anyone technical can read them, so never share passwords.", 9, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 26), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 0 })
		for i, m in ipairs(list) do
			local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i }, sf)
			mk("UIListLayout", { HorizontalAlignment = m.mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, row)
			local b = mk("Frame", { BackgroundColor3 = m.mine and Color3.new(1, 1, 1) or TH.card, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), LayoutOrder = 1 }, row)
			round(b, 14)
			mk("UISizeConstraint", { MaxSize = Vector2.new(200, math.huge) }, b)
			if m.mine then mk("UIGradient", { Rotation = 35, Color = ColorSequence.new(TH.bubA, TH.bubB) }, b) end
			local tl = mk("TextLabel", { BackgroundTransparency = 1, Text = m.m, TextWrapped = true, TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Color3.new(1, 1, 1), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = b.ZIndex + 2 }, b)
			pad(tl, 11, 11, 7, 7)
			mk("UISizeConstraint", { MaxSize = Vector2.new(200, math.huge) }, tl)
			txt(row, (m.state == "failed" and "failed" or os.date("%H:%M", m.t or os.time())), 9, m.state == "failed" and TH.bad or TH.dim, Enum.Font.Gotham, { Size = UDim2.new(0, 0, 0, 11), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 })
		end
		task.defer(function() if sf.Parent then sf.CanvasPosition = Vector2.new(0, 1e6) end end)
	end
	local bar = mk("Frame", { BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 48) }, view)
	local box = mk("TextBox", { PlaceholderText = "Message " .. info.d .. "...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -78, 0, 36) }, bar)
	round(box, 18)
	pad(box, 12, 8, 0, 0)
	local send = btn(bar, "Send", true, { Position = UDim2.new(1, -66, 0, 6), Size = UDim2.fromOffset(58, 36), BackgroundColor3 = TH.acc })
	round(send, 18)
	local function go()
		local ok, e = HubChat.send(box.Text, "d", name)
		if ok then box.Text = "" elseif e ~= "empty" then notify("Chat", tostring(e)) end
	end
	send.MouseButton1Click:Connect(go)
	box.FocusLost:Connect(function(enter) if enter then go() end end)
	local fn = function() if ctx.alive and view.Parent then render() end end
	table.insert(HubChat.listeners, fn)
	render()
	return function() dropListener(HubChat.listeners, fn) end
end

-- profile card of another hub user
function profileCard(ctx, view, name)
	local sf = scrollList(view)
	local info = infoOf(name)
	local st = staffInfo(name, info.u)
	local card = mk("Frame", { BackgroundColor3 = st and Color3.fromRGB(14, 8, 22) or TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 170), LayoutOrder = 1, ClipsDescendants = true }, sf)
	round(card, 16)
	if st then
		local gs = mk("UIStroke", { Thickness = 1.6, Color = Color3.new(1, 1, 1) }, card)
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)
		pcall(function() NovaUI.MakeBlackhole(card, 150, { Position = UDim2.new(0.5, 0, 0.3, 0), ParticleCount = 6, ZIndex = card.ZIndex + 1 }) end)
	end
	local av = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(72, 72), ZIndex = card.ZIndex + 3 }, card)
	pfp(av, name, info.d, info.u, 72, st or { a = TH.acc, b = TH.bubB })
	local nrow = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 18), ZIndex = card.ZIndex + 3 }, card)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, nrow)
	goldName(nrow, (st and "★ " or "") .. info.d, st, { LayoutOrder = 1, TextSize = 15, Size = UDim2.new(0, 0, 0, 18) })
	if st then titlePill(nrow, st, 2) end
	txt(card, "@" .. name .. "   -   Level " .. tostring(info.lv), 11, TH.dim, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 3 })
	txt(card, info.st ~= "" and ('"' .. info.st .. '"') or "No status set", 11, TH.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(10, 130), Size = UDim2.new(1, -20, 0, 28), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 3 })
	local acts = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, sf)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, acts)
	local function act(text, primary, fn, order)
		local b = btn(acts, text, primary, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
		b.MouseButton1Click:Connect(fn)
		return b
	end
	local isF = HubChat.isFriend(name)
	if name ~= lp.Name then
		if isF then
			act("Message", true, function() ctx.push(info.d, function(v) return dmView(ctx, v, name) end) end, 1)
			act("Join their server", false, function()
				local ok, msg = HubChat.joinFriend(name)
				notify(ok and "Join" or "Cannot join", tostring(msg))
			end, 2)
			local rm = act("Remove friend", false, function() end, 3)
			rm.TextColor3 = TH.bad
			rm.MouseButton1Click:Connect(function()
				if rm.Text == "Sure?" then HubChat.unfriend(name) ctx.back() else rm.Text = "Sure?" task.delay(2, function() pcall(function() rm.Text = "Remove friend" end) end) end
			end)
		elseif HubChat.fr.incoming[name] then
			act("Accept friend request", true, function() HubChat.accept(name) ctx.back() end, 1)
			act("Decline", false, function() HubChat.decline(name) ctx.back() end, 2)
		elseif HubChat.fr.outgoing[name] then
			act("Request sent", false, function() end, 1)
		else
			act("Add friend", true, function()
				HubChat.request(name)
				notify("Friends", "Request sent to " .. info.d)
				ctx.back()
			end, 1)
		end
	end
end

local function friendRow(ctx, parent, name, order, sub)
	local info = infoOf(name)
	local st = staffInfo(name, info.u)
	local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = st and Color3.fromRGB(14, 8, 22) or TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, ClipsDescendants = true }, parent)
	round(row, 12)
	if st then
		local gs = mk("UIStroke", { Thickness = 1.3, Color = Color3.new(1, 1, 1) }, row)
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)
	end
	local av = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(34, 34), ZIndex = row.ZIndex + 2 }, row)
	pfp(av, name, info.d, info.u, 34, st)
	local dot = mk("Frame", { BackgroundColor3 = HubChat.online(name) and Color3.fromRGB(70, 220, 120) or Color3.fromRGB(110, 110, 120), BorderSizePixel = 0, Position = UDim2.fromOffset(34, 34), Size = UDim2.fromOffset(11, 11), ZIndex = row.ZIndex + 4 }, row)
	round(dot, 6)
	mk("UIStroke", { Color = TH.card, Thickness = 2 }, dot)
	local nm = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -70, 0, 16), ZIndex = row.ZIndex + 2 }, row)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, nm)
	goldName(nm, (st and "★ " or "") .. info.d, st, { LayoutOrder = 1, TextSize = 13 })
	if st then titlePill(nm, st, 2) end
	pill(nm, "LV " .. tostring(info.lv), Color3.fromRGB(190, 160, 255), 3)
	txt(row, sub or (info.st ~= "" and info.st or ("@" .. name)), 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(54, 27), Size = UDim2.new(1, -70, 0, 14), ZIndex = row.ZIndex + 2, TextTruncate = Enum.TextTruncate.AtEnd })
	row.MouseButton1Click:Connect(function()
		ctx.push(info.d, function(v) profileCard(ctx, v, name) end)
	end)
	return row
end

local function friendsPage(ctx, body)
	local holder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
	local function build()
		for _, c in ipairs(holder:GetChildren()) do c:Destroy() end
		local sf = scrollList(holder)
		local fr = HubChat.fr
		local nInc = 0
		for _ in pairs(fr.incoming) do nInc = nInc + 1 end
		local nFr = 0
		for _ in pairs(fr.friends) do nFr = nFr + 1 end
		ctx.setSub(nFr .. " friends  -  " .. nInc .. " requests")
		local order = 0
		local function nextO() order = order + 1 return order end
		-- add by username
		local addRow = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextO() }, sf)
		local box = mk("TextBox", { PlaceholderText = "Add friend by username...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -70, 1, 0) }, addRow)
		round(box, 18)
		pad(box, 14, 8, 0, 0)
		local addB = btn(addRow, "Add", true, { Position = UDim2.new(1, -62, 0, 0), Size = UDim2.fromOffset(62, 36) })
		round(addB, 18)
		local function doAdd()
			local n = box.Text:gsub("[%s@]", "")
			if n == "" then return end
			local canon = n
			for name in pairs(HubChat.presence) do if name:lower() == n:lower() then canon = name end end
			if canon:lower() == lp.Name:lower() then notify("Friends", "That is you") return end
			HubChat.request(canon)
			box.Text = ""
			notify("Friends", "Request sent to " .. canon .. " (works if they use YADSAN HUB)")
		end
		addB.MouseButton1Click:Connect(doAdd)
		box.FocusLost:Connect(function(enter) if enter then doAdd() end end)
		if nInc > 0 then
			txt(sf, "FRIEND REQUESTS", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextO() })
			for n in pairs(fr.incoming) do friendRow(ctx, sf, n, nextO(), "wants to be your friend - tap to answer") end
		end
		txt(sf, "FRIENDS", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextO() })
		local names = {}
		for n in pairs(fr.friends) do names[#names + 1] = n end
		table.sort(names, function(a, b)
			local oa, ob = HubChat.online(a) and 1 or 0, HubChat.online(b) and 1 or 0
			if oa ~= ob then return oa > ob end
			return a:lower() < b:lower()
		end)
		if #names == 0 then
			txt(sf, "No friends yet. Tap someone in the list below, or add a username above.", 11, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, LayoutOrder = nextO() })
		end
		for _, n in ipairs(names) do friendRow(ctx, sf, n, nextO()) end
		txt(sf, "ONLINE NOW (HUB USERS)", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextO() })
		local cnt = 0
		for _, u in ipairs(HubChat.allUsers()) do
			if u.n ~= lp.Name and not fr.friends[u.n] and not fr.incoming[u.n] and cnt < 25 then
				cnt = cnt + 1
				friendRow(ctx, sf, u.n, nextO())
			end
		end
		if cnt == 0 then
			txt(sf, "Nobody else seen yet.", 11, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextO() })
		end
	end
	build()
	local lastSig = ""
	local fn = function()
		if not (ctx.alive and holder.Parent) then return end
		local sig = HttpService:JSONEncode({ HubChat.fr.friends, HubChat.fr.incoming, #HubChat.allUsers() })
		if sig ~= lastSig then lastSig = sig build() end
	end
	table.insert(HubChat.listeners, fn)
	return function() dropListener(HubChat.listeners, fn) end
end

local function myProfilePage(ctx, body)
	ctx.setSub("how other hub users see you")
	local sf = scrollList(body)
	local st = staffInfo(lp.Name, lp.UserId)
	local card = mk("Frame", { BackgroundColor3 = st and Color3.fromRGB(14, 8, 22) or TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 1, ClipsDescendants = true }, sf)
	round(card, 16)
	if st then
		local gs = mk("UIStroke", { Thickness = 1.6, Color = Color3.new(1, 1, 1) }, card)
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)
	end
	local av = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(72, 72), ZIndex = card.ZIndex + 2 }, card)
	pfp(av, lp.Name, lp.DisplayName, lp.UserId, 72, st or { a = TH.acc, b = TH.bubB })
	local nameL = txt(card, HubChat.myName(), 16, TH.text, Enum.Font.GothamBlack, { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
	local lv = 1
	pcall(function() lv = NovaUI.Profile.level() end)
	local nFr = 0
	for _ in pairs(HubChat.fr.friends) do nFr = nFr + 1 end
	txt(card, "@" .. lp.Name .. "   -   Level " .. lv .. "   -   " .. nFr .. " friends", 11, TH.dim, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
	txt(card, (HubChat.me.st ~= "") and ('"' .. HubChat.me.st .. '"') or "No status set", 11, TH.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(10, 128), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
	txt(sf, "YOUR HUB NAME", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 })
	local nb = mk("TextBox", { Text = HubChat.me.hn, PlaceholderText = "Shown in chat (empty = " .. lp.DisplayName .. ")", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3 }, sf)
	round(nb, 12)
	pad(nb, 12, 8, 0, 0)
	txt(sf, "STATUS", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 4 })
	local sb = mk("TextBox", { Text = HubChat.me.st, PlaceholderText = "What are you up to?", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 5 }, sf)
	round(sb, 12)
	pad(sb, 12, 8, 0, 0)
	local save = btn(sf, "Save profile", true, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 6 })
	save.MouseButton1Click:Connect(function()
		local hn = nb.Text:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		local ok, why = nameOk(hn)
		if not ok then notify("Profile", why) return end
		HubChat.setProfile(hn, sb.Text)
		nameL.Text = HubChat.myName()
		notify("Profile", "Saved. Other hub users will see it.")
	end)
	txt(sf, "Your profile picture is your Roblox avatar headshot. Name and status are saved in YADSAN_HUB/hub_profile.json.", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, LayoutOrder = 7 })
end

function ChatApp.build(ctx)
	ctx.push("Hub Chat", function(view)
		local t = tabbed(ctx, view, { "Chat", "Friends", "Profile", "Settings" }, {
			Chat = function(body) return chatPage(ctx, body) end,
			Friends = function(body) return friendsPage(ctx, body) end,
			Profile = function(body) return myProfilePage(ctx, body) end,
			Settings = function(body)
				ctx.setSub("make the app yours")
				settingsPage(body, ChatApp, "Settings", function(sf)
					txt(sf, "CHAT", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 10 })
					local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 11 }, sf)
					round(row, 12)
					txt(row, "New message sound", 13, TH.text, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0) })
					local pillB = btn(row, HubChat.muted and "OFF" or "ON", not HubChat.muted, { Position = UDim2.new(1, -62, 0.5, -14), Size = UDim2.fromOffset(52, 28), TextSize = 12, BackgroundColor3 = HubChat.muted and TH.card2 or TH.acc })
					pillB.MouseButton1Click:Connect(function()
						HubChat.muted = not HubChat.muted
						pillB.Text = HubChat.muted and "OFF" or "ON"
						pillB.BackgroundColor3 = HubChat.muted and TH.card2 or TH.acc
					end)
				end)
				return nil
			end,
		}, ctx.startTab)
		return function() t.close() end
	end)
end

------------------------------------------------------------------------
-- Fit Saver app
------------------------------------------------------------------------
local FitApp = { id = "Fits", title = "Fit Saver", icon = "shirt" }
function FitApp.build(ctx)
	ctx.push("Fit Saver", function(view)
		ctx.setSub("your outfits, saved as files")
		local tabBar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38) }, view)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, tabBar)
		pad(tabBar, 10, 10, 4, 2)
		local body = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38), ClipsDescendants = true }, view)
		local tabs, active = {}, nil
		local select
		local nameBox
		local function scroller()
			for _, c in ipairs(body:GetChildren()) do c:Destroy() end
			local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
			mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
			pad(sf, 10, 10, 6, 10)
			return sf
		end
		local function thumb(parent, id, x, size)
			local img = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(size, size), Image = ("rbxthumb://type=Asset&id=%.0f&w=150&h=150"):format(id), ScaleType = Enum.ScaleType.Fit }, parent)
			round(img, 6)
			return img
		end
		local FAVF = "YADSAN_HUB/fit_favs.txt"
		local favs = {}
		pcall(function()
			if isfile and isfile(FAVF) then
				for n in readfile(FAVF):gmatch("[^\r\n]+") do favs[n] = true end
			end
		end)
		local function saveFavs()
			pcall(function()
				pcall(makefolder, "YADSAN_HUB")
				local t = {}
				for n in pairs(favs) do t[#t + 1] = n end
				writefile(FAVF, table.concat(t, "\n"))
			end)
		end
		local function savedTab()
			local sf = scroller()
			local names = FitStore.names()
			table.sort(names, function(a, b)
				if (favs[a] and 1 or 0) ~= (favs[b] and 1 or 0) then return favs[a] end
				return a:lower() < b:lower()
			end)
			local search = mk("TextBox", { PlaceholderText = "Search fits (" .. #names .. ")", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 0 }, sf)
			round(search, 16)
			pad(search, 14, 10, 0, 0)
			local cards = {}
			if #names == 0 then
				txt(sf, "No saved fits yet.\nUse the Save tab to save your outfit, or the Players tab to save someone else's.", 12, TH.dim, Enum.Font.GothamMedium, { Size = UDim2.new(1, 0, 0, 70), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1 })
			end
			for i, name in ipairs(names) do
				local d = FitStore.get(name)
				local fav = favs[name]
				local card = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = i }, sf)
				cards[name] = card
				round(card, 14)
				local cs = mk("UIStroke", { Color = fav and Color3.fromRGB(255, 200, 70) or TH.acc, Transparency = fav and 0.1 or 0.7, Thickness = fav and 1.6 or 1 }, card)
				mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(TH.cardA, TH.cardB) }, card)
				txt(card, name, 14, fav and Color3.fromRGB(255, 222, 130) or TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -56, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
				local star = btn(card, fav and "*" or "+", false, { Position = UDim2.new(1, -40, 0, 4), Size = UDim2.fromOffset(30, 24), TextSize = 16, BackgroundColor3 = fav and Color3.fromRGB(255, 190, 60) or TH.card2, TextColor3 = fav and Color3.fromRGB(40, 20, 0) or TH.text })
				star.MouseButton1Click:Connect(function()
					favs[name] = (not favs[name]) or nil
					saveFavs()
					select("Saved")
				end)
				txt(card, (d.count or 0) .. " items  -  from " .. tostring(d.from or d.by or "?") .. "  -  " .. os.date("%d %b", d.saved or os.time()), 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -20, 0, 12) })
				local strip = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 42) }, card)
				local nT = 0
				for _, it in ipairs(d.items or {}) do
					if it.kind == "acc" and nT < 6 then
						thumb(strip, it.id, nT * 46, 42)
						nT = nT + 1
					end
				end
				local wear = btn(card, "Wear", true, { Position = UDim2.fromOffset(10, 96), Size = UDim2.new(0.42, -10, 0, 40) })
				local ids = btn(card, "Copy IDs", false, { Position = UDim2.new(0.42, 2, 0, 96), Size = UDim2.new(0.34, -4, 0, 40), TextSize = 11 })
				local del = btn(card, "Delete", false, { Position = UDim2.new(0.76, 2, 0, 96), Size = UDim2.new(0.24, -12, 0, 40), TextSize = 11, TextColor3 = TH.bad })
				local busy = false
				wear.MouseButton1Click:Connect(function()
					if busy then return end
					busy = true
					task.spawn(function()
						local ok, msg = FitStore.wear(name, function(a, n) pcall(function() wear.Text = a .. "/" .. n end) end)
						pcall(function() wear.Text = "Wear" end)
						busy = false
						notify(ok and "Fit worn" or "Fit failed", ok and (name .. ": " .. tostring(msg)) or tostring(msg))
					end)
				end)
				ids.MouseButton1Click:Connect(function()
					notify("Fit Saver", FitStore.copyIds(name) and "Item IDs copied" or "Clipboard not available")
				end)
				del.MouseButton1Click:Connect(function()
					if del.Text == "Sure?" then
						favs[name] = nil
						FitStore.delete(name)
					else
						del.Text = "Sure?"
						task.delay(2, function() pcall(function() del.Text = "Delete" end) end)
					end
				end)
			end
			search:GetPropertyChangedSignal("Text"):Connect(function()
				local q = search.Text:lower()
				for n, c in pairs(cards) do
					c.Visible = q == "" or n:lower():find(q, 1, true) ~= nil
				end
			end)
		end
		local function saveTab()
			local sf = scroller()
			local card = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 1 }, sf)
			round(card, 12)
			txt(card, "Save your current outfit", 14, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18) })
			nameBox = mk("TextBox", { PlaceholderText = "Fit name", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 36) }, card)
			round(nameBox, 9)
			pad(nameBox, 10, 8, 0, 0)
			local save = btn(card, "Save my fit", true, { Position = UDim2.fromOffset(12, 78), Size = UDim2.new(1, -24, 0, 36) })
			txt(card, "Saved as YADSAN_HUB/fits/<name>.json in your executor folder", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(12, 120), Size = UDim2.new(1, -24, 0, 24), TextWrapped = true })
			save.MouseButton1Click:Connect(function()
				local d = FitStore.saveMine()
				if not d then notify("Fit Saver", "Character not loaded") return end
				local n = tostring(nameBox.Text):gsub("^%s+", ""):gsub("%s+$", "")
				local ok, msg = FitStore.save(n ~= "" and n or ("My fit " .. os.date("%H:%M:%S")), d, lp.Name)
				notify("Fit Saver", tostring(msg))
				if ok then nameBox.Text = "" end
			end)
		end
		local function playersTab()
			local sf = scroller()
			local any = false
			for i, p in ipairs(Players:GetPlayers()) do
				if p ~= lp then
					any = true
					local row = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i }, sf)
					round(row, 12)
					local av = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(36, 36), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(p.UserId) }, row)
					round(av, 18)
					txt(row, p.DisplayName, 13, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(52, 6), Size = UDim2.new(1, -170, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
					txt(row, "@" .. p.Name, 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(52, 24), Size = UDim2.new(1, -170, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
					local cp = btn(row, "Copy", true, { Position = UDim2.new(1, -110, 0, 10), Size = UDim2.fromOffset(52, 32), TextSize = 12 })
					local sv = btn(row, "Save", false, { Position = UDim2.new(1, -54, 0, 10), Size = UDim2.fromOffset(46, 32), TextSize = 12 })
					cp.MouseButton1Click:Connect(function()
						task.spawn(function()
							cp.Text = "..."
							local ok, d = copyAvatar(p)
							pcall(function() cp.Text = "Copy" end)
							notify(ok and "Copy Avatar" or "Copy Avatar failed", ok and (p.DisplayName .. ": " .. tostring(d)) or tostring(d))
						end)
					end)
					sv.MouseButton1Click:Connect(function()
						local th = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
						local okd, d = pcall(function() return th and th:GetAppliedDescription() end)
						if not okd or not d then notify("Fit Saver", "Could not read their outfit") return end
						if optedOut(p) then notify("Fit Saver", p.DisplayName .. " hides their outfit") return end
						local ok, msg = FitStore.save(p.DisplayName, d, lp.Name, p.Name, p.Character)
						notify("Fit Saver", tostring(msg))
					end)
				end
			end
			if not any then
				txt(sf, "Nobody else is in the server.", 13, TH.dim, Enum.Font.GothamMedium, { Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
			end
		end
		local pages = { Saved = savedTab, Save = saveTab, Players = playersTab, Settings = function()
			for _, c in ipairs(body:GetChildren()) do c:Destroy() end
			ctx.setSub("make the app yours")
			settingsPage(body, FitApp, "Settings")
		end }
		function select(n)
			active = n
			for k, b in pairs(tabs) do
				b.BackgroundColor3 = (k == n) and TH.acc or TH.card
			end
			pages[n]()
		end
		for _, n in ipairs({ "Saved", "Save", "Players", "Settings" }) do
			local b = btn(tabBar, n, false, { Size = UDim2.new(1 / 4, -5, 1, 0), BackgroundColor3 = TH.card, TextSize = 12 })
			tabs[n] = b
			b.MouseButton1Click:Connect(function() select(n) end)
		end
		local fn = function()
			if ctx.alive and view.Parent and active == "Saved" then select("Saved") end
		end
		FitStore.onChange(fn)
		select(ctx.startTab or (#FitStore.names() > 0 and "Saved" or "Save"))
		return function() dropListener(FitStore.listeners, fn) end
	end)
end

------------------------------------------------------------------------
-- Music: search (Deezer = 30s previews, no key; Jamendo = full indie songs, free client_id) and play in-game.
-- Tracks are cached in YADSAN_HUB/music/ and played from there with getcustomasset. Only you hear it.
------------------------------------------------------------------------
local Music = { queue = {}, idx = 0, state = "idle", vol = 0.6, listeners = {}, favs = {}, recent = {}, lists = {}, note = "", shuffle = false, rep = 0, eq = 1, sleepAt = nil, covers = {} }
local MUSIC_EQ = {
	{ "Flat", 0, 0, 0 }, { "Bass boost", 8, 0, -2 }, { "Vocal", -4, 6, 2 }, { "Treble", -3, 0, 8 }, { "Party", 6, -2, 6 },
}
do
	-- NOTE: the chat module has its own local "request" (returns code, body), so use the executor's real function
	local genv = (getgenv and getgenv()) or {}
	local httpReq = (syn and syn.request) or http_request or genv.http_request or genv.request or (http and http.request) or (fluxus and fluxus.request)
	local DIR, FAVF, JID = "YADSAN_HUB/music", "YADSAN_HUB/music_favs.json", "YADSAN_HUB/jamendo_id.txt"
	local RECF, LISTF, SETF = "YADSAN_HUB/music_recent.json", "YADSAN_HUB/music_lists.json", "YADSAN_HUB/music_set.json"
	local function jload(f, def)
		local v = def
		pcall(function()
			if isfile and isfile(f) then
				local d = HttpService:JSONDecode(readfile(f))
				if type(d) == "table" then v = d end
			end
		end)
		return v
	end
	local function jsave(f, v)
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			writefile(f, HttpService:JSONEncode(v))
		end)
	end
	Music.favs, Music.recent, Music.lists = jload(FAVF, {}), jload(RECF, {}), jload(LISTF, {})
	local st0 = jload(SETF, {})
	if type(st0.vol) == "number" then Music.vol = math.clamp(st0.vol, 0, 1) end
	if type(st0.eq) == "number" and MUSIC_EQ[st0.eq] then Music.eq = st0.eq end
	if st0.shuffle == true then Music.shuffle = true end
	if type(st0.rep) == "number" then Music.rep = st0.rep % 3 end
	local function saveSet() jsave(SETF, { vol = Music.vol, eq = Music.eq, shuffle = Music.shuffle, rep = Music.rep }) end
	local sound = Instance.new("Sound")
	sound.Name = "YadsanMusic"
	sound.Volume = Music.vol
	sound.Parent = game:GetService("SoundService")
	Music.sound = sound
	local eqfx = Instance.new("EqualizerSoundEffect")
	eqfx.Parent = sound
	local function applyEq()
		local e = MUSIC_EQ[Music.eq]
		eqfx.LowGain, eqfx.MidGain, eqfx.HighGain = e[2], e[3], e[4]
	end
	applyEq()
	local function fire() for _, f in ipairs(Music.listeners) do pcall(f) end end
	Music.fire = fire
	Music.lastErr = ""
	local function get(url)
		Music.lastErr = ""
		if httpReq then
			local ok, r = pcall(httpReq, { Url = url, Method = "GET" })
			if ok and type(r) == "table" then
				if (r.StatusCode == 200 or r.Success) and r.Body and #r.Body > 0 then return r.Body end
				Music.lastErr = "HTTP " .. tostring(r.StatusCode)
			else
				Music.lastErr = tostring(r):sub(1, 60)
			end
		else
			Music.lastErr = "no request function"
		end
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok and type(body) == "string" and #body > 0 then return body end
		if not ok then Music.lastErr = Music.lastErr .. " / " .. tostring(body):sub(1, 60) end
		return nil
	end
	function Music.check()
		local out = {}
		out[#out + 1] = "request fn: " .. (httpReq and "yes" or "NO") .. "  |  HttpGet: yes"
		out[#out + 1] = "getcustomasset: " .. ((getcustomasset and "yes") or "NO") .. "  writefile: " .. ((writefile and "yes") or "NO")
		local b = get("https://api.deezer.com/search?q=arijit&limit=1")
		out[#out + 1] = "Deezer search: " .. (b and "OK" or ("FAILED (" .. Music.lastErr .. ")"))
		local url
		pcall(function() url = HttpService:JSONDecode(b).data[1].preview end)
		if url then
			local mp = get(url)
			out[#out + 1] = "Preview download: " .. (mp and (#mp .. " bytes OK") or ("FAILED (" .. Music.lastErr .. ")"))
		end
		return table.concat(out, "\n")
	end
	function Music.jamendoId()
		local v = (YADSAN_JAMENDO_ID and tostring(YADSAN_JAMENDO_ID)) or ""
		pcall(function()
			if v == "" and isfile and isfile(JID) then v = readfile(JID):gsub("%s+", "") end
		end)
		return v
	end
	function Music.setJamendoId(v)
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			writefile(JID, tostring(v or ""):gsub("%s+", ""))
		end)
	end
	local function dz(t)
		return { src = "dz", id = tostring(t.id), title = t.title, artist = t.artist and t.artist.name or "?", url = t.preview, note = "30s preview", cover = t.album and (t.album.cover_medium or t.album.cover) or nil, dur = 30 }
	end
	function Music.search(q)
		local out, errs = {}, {}
		local enc = HttpService:UrlEncode(q)
		local body = get("https://api.deezer.com/search?q=" .. enc .. "&limit=25")
		if body then
			pcall(function()
				for _, t in ipairs(HttpService:JSONDecode(body).data or {}) do
					if t.preview and t.preview ~= "" then out[#out + 1] = dz(t) end
				end
			end)
		else
			errs[#errs + 1] = "Deezer not reachable (" .. Music.lastErr .. ")"
		end
		local jid = Music.jamendoId()
		if jid ~= "" then
			local jb = get("https://api.jamendo.com/v3.0/tracks/?client_id=" .. jid .. "&format=json&limit=15&audioformat=mp31&search=" .. enc)
			if jb then
				pcall(function()
					for _, t in ipairs(HttpService:JSONDecode(jb).results or {}) do
						if t.audio and t.audio ~= "" then
							out[#out + 1] = { src = "jm", id = tostring(t.id), title = t.name, artist = t.artist_name or "?", url = t.audio, note = "full song", cover = t.image, dur = tonumber(t.duration) }
						end
					end
				end)
			else
				errs[#errs + 1] = "Jamendo not reachable (check client id)"
			end
		end
		return out, errs
	end
	-- recommended mix: a few songs from several popular searches, interleaved
	function Music.forYou()
		if Music._fy and os.clock() - (Music._fyT or 0) < 1800 then return Music._fy end
		local qs = { "bollywood hits", "arijit singh", "punjabi songs", "english pop hits", "rap hits", "lofi hindi", "romantic hindi songs", "edm party" }
		local res, pending = {}, #qs
		for i, q in ipairs(qs) do
			task.spawn(function()
				local ok, l = pcall(Music.search, q)
				res[i] = ok and l or {}
				pending = pending - 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 14 do task.wait(0.1) end
		local out, seen = {}, {}
		for r = 1, 5 do
			for i = 1, #qs do
				local t = res[i] and res[i][r]
				if t and not seen[t.src .. t.id] then
					seen[t.src .. t.id] = true
					out[#out + 1] = t
				end
			end
		end
		if #out == 0 then out = Music.chart() end
		if #out > 0 then Music._fy, Music._fyT = out, os.clock() end
		return out
	end
	function Music.chart()
		local out = {}
		local body = get("https://api.deezer.com/chart/0/tracks?limit=30")
		if body then
			pcall(function()
				for _, t in ipairs(HttpService:JSONDecode(body).data or {}) do
					if t.preview and t.preview ~= "" then out[#out + 1] = dz(t) end
				end
			end)
		end
		return out
	end
	-- cover art: downloaded once, shown through getcustomasset
	function Music.cover(t, cb)
		if not (t and t.cover and getcustomasset and writefile and isfile) then return end
		local key = t.src .. "_" .. t.id
		if Music.covers[key] then return cb(Music.covers[key]) end
		task.spawn(function()
			pcall(makefolder, "YADSAN_HUB")
			pcall(makefolder, DIR)
			local path = ("%s/c_%s.jpg"):format(DIR, key:gsub("[^%w_]", ""))
			if not isfile(path) then
				local b = get(t.cover)
				if not b then return end
				pcall(writefile, path, b)
			end
			local ok, a = pcall(getcustomasset, path)
			if ok then
				Music.covers[key] = a
				cb(a)
			end
		end)
	end
	local function same(a, b) return a.src == b.src and a.id == b.id end
	local function slim(t) return { src = t.src, id = t.id, title = t.title, artist = t.artist, url = t.url, note = t.note, cover = t.cover, dur = t.dur } end
	function Music.isFav(t)
		for _, f in ipairs(Music.favs) do if same(f, t) then return true end end
		return false
	end
	function Music.toggleFav(t)
		for i, f in ipairs(Music.favs) do
			if same(f, t) then
				table.remove(Music.favs, i)
				jsave(FAVF, Music.favs)
				fire()
				return false
			end
		end
		Music.favs[#Music.favs + 1] = slim(t)
		jsave(FAVF, Music.favs)
		fire()
		return true
	end
	-- playlists: Music.lists = { { name = "...", tracks = { ... } } }
	function Music.newList(name)
		name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 24)
		if name == "" then return nil end
		for _, l in ipairs(Music.lists) do if l.name:lower() == name:lower() then return l end end
		local l = { name = name, tracks = {} }
		Music.lists[#Music.lists + 1] = l
		jsave(LISTF, Music.lists)
		return l
	end
	function Music.addToList(l, t)
		for _, x in ipairs(l.tracks) do if same(x, t) then return false end end
		l.tracks[#l.tracks + 1] = slim(t)
		jsave(LISTF, Music.lists)
		return true
	end
	function Music.delList(l)
		for i, x in ipairs(Music.lists) do if x == l then table.remove(Music.lists, i) end end
		jsave(LISTF, Music.lists)
	end
	local function pushRecent(t)
		for i, r in ipairs(Music.recent) do if same(r, t) then table.remove(Music.recent, i) break end end
		table.insert(Music.recent, 1, slim(t))
		while #Music.recent > 30 do table.remove(Music.recent) end
		jsave(RECF, Music.recent)
	end
	local token = 0
	function Music.play(list, i)
		Music.queue, Music.idx = list, i
		local t = list[i]
		if not t then return end
		token = token + 1
		local my = token
		sound:Stop()
		Music.state, Music.note = "loading", ""
		pushRecent(t)
		fire()
		task.spawn(function()
			if not (getcustomasset and writefile and isfile) then
				Music.state, Music.note = "error", "This executor has no getcustomasset/writefile"
				return fire()
			end
			pcall(makefolder, "YADSAN_HUB")
			pcall(makefolder, DIR)
			local path = ("%s/%s_%s.mp3"):format(DIR, t.src, t.id:gsub("[^%w]", ""))
			if not isfile(path) then
				local body = get(t.url)
				if not body then
					Music.state, Music.note = "error", "Download failed (" .. Music.lastErr .. ")"
					return fire()
				end
				pcall(writefile, path, body)
			end
			if my ~= token then return end
			local ok, asset = pcall(getcustomasset, path)
			if not ok then
				Music.state, Music.note = "error", "getcustomasset failed"
				return fire()
			end
			sound.SoundId = asset
			local w0 = os.clock()
			while not sound.IsLoaded and os.clock() - w0 < 8 and my == token do task.wait(0.1) end
			if my ~= token then return end
			if not sound.IsLoaded then
				Music.state, Music.note = "error", "Audio would not load in this executor"
				return fire()
			end
			sound:Play()
			Music.state = "playing"
			fire()
		end)
	end
	function Music.toggle()
		if Music.state == "playing" then sound:Pause() Music.state = "paused"
		elseif Music.state == "paused" then sound:Resume() Music.state = "playing"
		elseif Music.idx > 0 then Music.play(Music.queue, Music.idx) end
		fire()
	end
	function Music.step(d, auto)
		local n = #Music.queue
		if n == 0 then return end
		local i = Music.idx + d
		if Music.shuffle and n > 1 then
			repeat i = math.random(1, n) until i ~= Music.idx
		elseif i > n then i = 1 elseif i < 1 then i = n end
		Music.play(Music.queue, i)
	end
	function Music.stop() token = token + 1 sound:Stop() Music.state = "idle" fire() end
	function Music.setVol(v) Music.vol = math.clamp(v, 0, 1) sound.Volume = Music.vol saveSet() fire() end
	function Music.seek(f)
		if sound.TimeLength > 0 then sound.TimePosition = math.clamp(f, 0, 1) * sound.TimeLength end
	end
	function Music.toggleShuffle() Music.shuffle = not Music.shuffle saveSet() fire() end
	function Music.cycleRepeat() Music.rep = (Music.rep + 1) % 3 saveSet() fire() end
	function Music.cycleEq() Music.eq = Music.eq % #MUSIC_EQ + 1 applyEq() saveSet() fire() return MUSIC_EQ[Music.eq][1] end
	local stok = 0
	function Music.setSleep(min)
		stok = stok + 1
		local my = stok
		if not min then Music.sleepAt = nil return fire() end
		Music.sleepAt = os.clock() + min * 60
		task.delay(min * 60, function()
			if my == stok then Music.sleepAt = nil Music.stop() notify("Music", "Sleep timer: music stopped") end
		end)
		fire()
	end
	function Music.clearCache()
		local n = 0
		pcall(function()
			for _, f in ipairs(listfiles(DIR)) do
				if delfile then pcall(delfile, f) n = n + 1 end
			end
		end)
		Music.covers = {}
		return n
	end
	sound.Ended:Connect(function()
		if Music.state ~= "playing" then return end
		if Music.rep == 2 then
			sound.TimePosition = 0
			sound:Play()
		elseif Music.rep == 0 and not Music.shuffle and Music.idx >= #Music.queue then
			Music.state = "paused"
			fire()
		else
			Music.step(1, true)
		end
	end)
end
local function fmtTime(s)
	s = math.max(0, math.floor(s or 0))
	return ("%d:%02d"):format(s // 60, s % 60)
end
-- horizontal slider / seek bar: tap or drag
local function slider(parent, props, onSet)
	local bg = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card2, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do bg[k] = v end
	round(bg, 8)
	local fill = mk("Frame", { BackgroundColor3 = TH.acc, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, bg)
	round(fill, 8)
	local knob = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12) }, bg)
	round(knob, 6)
	local UIS = game:GetService("UserInputService")
	local drag = false
	local function upd(x)
		local f = math.clamp((x - bg.AbsolutePosition.X) / math.max(1, bg.AbsoluteSize.X), 0, 1)
		onSet(f)
	end
	bg.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			upd(i.Position.X)
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)
	bg.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)
	return function(f)
		fill.Size = UDim2.fromScale(f, 1)
		knob.Position = UDim2.fromScale(f, 0.5)
	end, bg
end

local MusicApp = { id = "Music", title = "Music", icon = "music" }
local function trackRow(parent, list, i, order, onAfter)
	local t = list[i]
	local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = order }, parent)
	round(row, 12)
	local cur = Music.queue[Music.idx]
	local isCur = cur and cur.src == t.src and cur.id == t.id
	if isCur then mk("UIStroke", { Color = TH.acc, Thickness = 1.5 }, row) end
	local art = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(40, 40), ScaleType = Enum.ScaleType.Crop }, row)
	round(art, 8)
	local ph = txt(art, isCur and ">" or tostring(i), 13, TH.dim, Enum.Font.GothamBold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	if t.cover then Music.cover(t, function(a) if art.Parent then art.Image = a ph.Visible = false end end) end
	txt(row, t.title, 13, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(56, 8), Size = UDim2.new(1, -108, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	txt(row, t.artist .. "  -  " .. (t.note or ""), 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(56, 28), Size = UDim2.new(1, -108, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	local function favStyle(b, on)
		b.Text = on and "<3" or "+"
		b.BackgroundColor3 = on and Color3.fromRGB(255, 90, 140) or TH.card2
		b.TextColor3 = on and Color3.new(1, 1, 1) or TH.text
	end
	local star = btn(row, "+", false, { Position = UDim2.new(1, -44, 0.5, -14), Size = UDim2.fromOffset(34, 28), TextSize = 13 })
	round(star, 14)
	favStyle(star, Music.isFav(t))
	star.MouseButton1Click:Connect(function()
		favStyle(star, Music.toggleFav(t))
		if onAfter then onAfter() end
	end)
	row.MouseButton1Click:Connect(function() Music.play(list, i) end)
end
local function musicList(body, list, emptyText, header)
	local sf = scrollList(body)
	if header then header(sf) end
	if #list == 0 then txt(sf, emptyText, 12, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2 }) end
	for i = 1, #list do trackRow(sf, list, i, i + 10) end
	return sf
end
local function chip(parent, text, on, order)
	local c = btn(parent, text, on, { Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, LayoutOrder = order })
	round(c, 14)
	pad(c, 12, 12, 0, 0)
	return c
end

function MusicApp.build(ctx)
	ctx.push("Music", function(view)
		local main = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64) }, view)
		-- mini player (tap the song to open Now Playing)
		local player = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 64) }, view)
		mk("UIStroke", { Color = TH.acc, Thickness = 1, Transparency = 0.6 }, player)
		local miniArt = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(44, 44), ScaleType = Enum.ScaleType.Crop }, player)
		round(miniArt, 10)
		local miniNote = txt(miniArt, "~", 18, TH.dim, Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local mTitle = txt(player, "Nothing playing", 12, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -170, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local mSub = txt(player, "Pick a song", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(60, 25), Size = UDim2.new(1, -170, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd })
		local setMini = slider(player, { Position = UDim2.fromOffset(60, 44), Size = UDim2.new(1, -170, 0, 5) }, function(f) Music.seek(f) end)
		local function pbtn(text, x, w)
			local b = btn(player, text, false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(w, 32), TextSize = 12 })
			round(b, 16)
			return b
		end
		local mNext, mPlay, mPrev = pbtn(">>", -8, 34), pbtn("Play", -46, 50), pbtn("<<", -100, 34)

		-- ===== Now Playing page =====
		local np = mk("Frame", { BackgroundColor3 = TH.bgTop or TH.card, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50 }, view)
		mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHSV(TH.h or 0.75, 0.55, 0.30), Color3.fromRGB(8, 6, 16)) }, np)
		local npBack = btn(np, "v", false, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(34, 28), TextSize = 14 })
		round(npBack, 14)
		txt(np, "NOW PLAYING", 10, TH.dim, Enum.Font.GothamBold, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center })
		local cover = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(120, 120), ScaleType = Enum.ScaleType.Crop }, np)
		round(cover, 18)
		mk("UIStroke", { Color = TH.acc, Thickness = 2, Transparency = 0.3 }, cover)
		local coverNote = txt(cover, "~", 42, TH.dim, Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local nTitle = txt(np, "Nothing playing", 16, TH.text, Enum.Font.GothamBlack, { Position = UDim2.fromOffset(14, 170), Size = UDim2.new(1, -28, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		local nSub = txt(np, "", 11, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(14, 192), Size = UDim2.new(1, -28, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		local setSeek = slider(np, { Position = UDim2.fromOffset(18, 216), Size = UDim2.new(1, -36, 0, 8) }, function(f) Music.seek(f) end)
		local tCur = txt(np, "0:00", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(18, 226), Size = UDim2.fromOffset(50, 12) })
		local tEnd = txt(np, "0:00", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.new(1, -68, 0, 226), Size = UDim2.fromOffset(50, 12), TextXAlignment = Enum.TextXAlignment.Right })
		local row1 = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 46) }, np)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, row1)
		local function rb(text, w, h, acc)
			local b = btn(row1, text, acc, { Size = UDim2.fromOffset(w, h), TextSize = 13 })
			round(b, h)
			return b
		end
		local bShuf, bPrev, bPlay, bNext, bRep = rb("Shuf", 44, 34), rb("<<", 44, 38), rb("Play", 70, 46, true), rb(">>", 44, 38), rb("Rep", 44, 34)
		local row2 = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 296), Size = UDim2.new(1, 0, 0, 34) }, np)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }, row2)
		local function cb(text)
			local b = btn(row2, text, false, { Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, TextSize = 10 })
			round(b, 14)
			pad(b, 9, 9, 0, 0)
			return b
		end
		local bFav, bEq, bSleep, bList, bShare = cb("Like"), cb("EQ: Flat"), cb("Sleep: off"), cb("+ List"), cb("Share")
		txt(np, "VOLUME", 9, TH.dim, Enum.Font.GothamBold, { Position = UDim2.fromOffset(18, 336), Size = UDim2.fromOffset(60, 12) })
		local setVol = slider(np, { Position = UDim2.fromOffset(18, 350), Size = UDim2.new(1, -36, 0, 8) }, function(f) Music.setVol(f) end)
		local npMsg = txt(np, "", 10, TH.acc, Enum.Font.GothamBold, { Position = UDim2.fromOffset(14, 364), Size = UDim2.new(1, -28, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })

		local function openNP() np.Visible = true end
		player.MouseButton1Click:Connect(openNP)
		npBack.MouseButton1Click:Connect(function() np.Visible = false end)
		local function togglePlay() if Music.idx == 0 then notify("Music", "Pick a song first") else Music.toggle() end end
		mPlay.MouseButton1Click:Connect(togglePlay)
		bPlay.MouseButton1Click:Connect(togglePlay)
		mNext.MouseButton1Click:Connect(function() Music.step(1) end)
		bNext.MouseButton1Click:Connect(function() Music.step(1) end)
		mPrev.MouseButton1Click:Connect(function() Music.step(-1) end)
		bPrev.MouseButton1Click:Connect(function() Music.step(-1) end)
		bShuf.MouseButton1Click:Connect(Music.toggleShuffle)
		bRep.MouseButton1Click:Connect(Music.cycleRepeat)
		bFav.MouseButton1Click:Connect(function() local t = Music.queue[Music.idx] if t then Music.toggleFav(t) end end)
		bEq.MouseButton1Click:Connect(function() Music.cycleEq() end)
		local sleepSteps, sleepI = { false, 15, 30, 60 }, 1
		bSleep.MouseButton1Click:Connect(function()
			sleepI = sleepI % #sleepSteps + 1
			Music.setSleep(sleepSteps[sleepI] or nil)
		end)
		bList.MouseButton1Click:Connect(function()
			local t = Music.queue[Music.idx]
			if not t then return end
			local l = Music.lists[1] or Music.newList("My Playlist")
			npMsg.Text = Music.addToList(l, t) and ("Added to " .. l.name) or ("Already in " .. l.name)
		end)
		bShare.MouseButton1Click:Connect(function()
			local t = Music.queue[Music.idx]
			local HC = NovaUI.HubChat
			if not (t and HC) then return end
			local ok, why = HC.send("Now playing on YADSAN Music: " .. t.title .. " - " .. t.artist, "g")
			npMsg.Text = ok and "Shared to Hub chat" or tostring(why or "Could not share")
		end)

		local lastCoverKey
		local function refresh()
			local t = Music.queue[Music.idx]
			local st = Music.state
			mTitle.Text = t and t.title or "Nothing playing"
			mSub.Text = t and (t.artist .. "  -  " .. (st == "loading" and "loading..." or st == "error" and Music.note or (t.note or ""))) or "Pick a song"
			nTitle.Text = t and t.title or "Nothing playing"
			nSub.Text = t and (t.artist .. "  -  " .. (st == "loading" and "loading..." or st == "error" and Music.note or (t.note or ""))) or "Discover or search a song"
			local pt = (st == "playing") and "Pause" or "Play"
			mPlay.Text, bPlay.Text = pt, pt
			local on = function(b, v) b.BackgroundColor3 = v and TH.acc or TH.card2 end
			on(bShuf, Music.shuffle)
			on(bRep, Music.rep > 0)
			bRep.Text = Music.rep == 2 and "R1" or "Rep"
			bEq.Text = "EQ: " .. MUSIC_EQ[Music.eq][1]
			bSleep.Text = Music.sleepAt and ("Sleep: " .. math.max(1, math.ceil((Music.sleepAt - os.clock()) / 60)) .. "m") or "Sleep: off"
			bFav.Text = (t and Music.isFav(t)) and "Liked" or "Like"
			bFav.BackgroundColor3 = (t and Music.isFav(t)) and Color3.fromRGB(255, 90, 140) or TH.card2
			setVol(Music.vol)
			local key = t and (t.src .. t.id)
			if key ~= lastCoverKey then
				lastCoverKey = key
				cover.Image, miniArt.Image = "", ""
				coverNote.Visible, miniNote.Visible = true, true
				if t then
					Music.cover(t, function(a)
						if lastCoverKey == key and cover.Parent then
							cover.Image, miniArt.Image = a, a
							coverNote.Visible, miniNote.Visible = false, false
						end
					end)
				end
			end
		end
		table.insert(Music.listeners, refresh)
		local conn = game:GetService("RunService").Heartbeat:Connect(function()
			local s = Music.sound
			local f = (s.TimeLength > 0) and math.clamp(s.TimePosition / s.TimeLength, 0, 1) or 0
			setMini(f)
			if np.Visible then
				setSeek(f)
				tCur.Text, tEnd.Text = fmtTime(s.TimePosition), fmtTime(s.TimeLength)
			end
		end)
		refresh()

		local cache = { results = {}, err = "", chart = nil, genre = nil }
		local tabsObj = tabbed(ctx, main, { "Discover", "Search", "Library", "Settings" }, {
			Discover = function(body)
				ctx.setSub("charts and moods")
				local top = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X }, body)
				mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, top)
				pad(top, 10, 10, 4, 4)
				local res = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38) }, body)
				local moods = { { "For You", nil, true }, { "Top charts", nil }, { "Bollywood", "bollywood hits" }, { "Punjabi", "punjabi hits" }, { "Lofi", "lofi chill" }, { "Hip Hop", "hip hop" }, { "Romantic", "romantic hindi" }, { "Gym", "workout" }, { "Retro", "old hindi songs" }, { "Phonk", "phonk" } }
				local chips, token2 = {}, 0
				local function load(i)
					token2 = token2 + 1
					local my = token2
					cache.genre = i
					for j, c in pairs(chips) do c.BackgroundColor3 = (j == i) and TH.acc or TH.card2 end
					for _, c in ipairs(res:GetChildren()) do c:Destroy() end
					txt(res, "Loading...", 12, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
					task.spawn(function()
						local list
						if moods[i][3] then list = Music.forYou() elseif moods[i][2] then list = (Music.search(moods[i][2])) else list = Music.chart() end
						if my ~= token2 or not res.Parent then return end
						for _, c in ipairs(res:GetChildren()) do c:Destroy() end
						musicList(res, list, "Could not load. Check your connection.", function(sf)
							if #list > 0 then
								local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 })
								round(pa, 17)
								pa.MouseButton1Click:Connect(function() Music.play(list, 1) end)
							end
						end)
					end)
				end
				for i, m in ipairs(moods) do
					local c = chip(top, m[1], false, i)
					chips[i] = c
					c.MouseButton1Click:Connect(function() load(i) end)
				end
				load(cache.genre or 1)
			end,
			Search = function(body)
				ctx.setSub("Deezer" .. (Music.jamendoId() ~= "" and " + Jamendo" or ""))
				local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, body)
				local box = mk("TextBox", { PlaceholderText = "Search song or artist...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -90, 0, 34) }, bar)
				round(box, 17)
				pad(box, 14, 8, 0, 0)
				local go = btn(bar, "Search", true, { Position = UDim2.new(1, -72, 0, 4), Size = UDim2.fromOffset(64, 34), TextSize = 12 })
				round(go, 17)
				local res = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) }, body)
				local function show(list, msg)
					for _, c in ipairs(res:GetChildren()) do c:Destroy() end
					musicList(res, list, msg)
				end
				show(cache.results, cache.err ~= "" and cache.err or "Type a song or artist and press Search.")
				local busy = false
				local function doSearch()
					local q = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
					if q == "" or busy then return end
					busy = true
					go.Text = "..."
					task.spawn(function()
						local list, errs = Music.search(q)
						cache.results, cache.err = list, (#list == 0) and (#errs > 0 and table.concat(errs, ", ") or "No results") or ""
						busy = false
						pcall(function() go.Text = "Search" end)
						if res.Parent then show(list, cache.err) end
					end)
				end
				go.MouseButton1Click:Connect(doSearch)
				box.FocusLost:Connect(function(enter) if enter then doSearch() end end)
			end,
			Library = function(body)
				ctx.setSub("your music")
				local top = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) }, body)
				mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, top)
				pad(top, 10, 10, 4, 4)
				local res = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38) }, body)
				local names, chips, openList = { "Liked", "Recent", "Playlists" }, {}, nil
				local show
				show = function(i)
					cache.lib = i
					for j, c in pairs(chips) do c.BackgroundColor3 = (j == i) and TH.acc or TH.card2 end
					for _, c in ipairs(res:GetChildren()) do c:Destroy() end
					if i == 1 then
						musicList(res, Music.favs, "No liked songs yet. Tap + on a song.", function(sf)
							if #Music.favs > 0 then
								local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 })
								round(pa, 17)
								pa.MouseButton1Click:Connect(function() Music.play(Music.favs, 1) end)
							end
						end)
					elseif i == 2 then
						musicList(res, Music.recent, "Songs you play will show up here.", function(sf)
							if #Music.recent > 0 then
								local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 })
								round(pa, 17)
								pa.MouseButton1Click:Connect(function() Music.play(Music.recent, 1) end)
							end
						end)
					else
						if openList then
							local l = openList
							musicList(res, l.tracks, "Empty. Open Now Playing and press + List.", function(sf)
								local bk = btn(sf, "< All playlists", false, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 })
								bk.MouseButton1Click:Connect(function() openList = nil show(3) end)
								if #l.tracks > 0 then
									local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2 })
									round(pa, 17)
									pa.MouseButton1Click:Connect(function() Music.play(l.tracks, 1) end)
								end
								local dl = btn(sf, "Delete playlist", false, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, TextColor3 = TH.bad })
								dl.MouseButton1Click:Connect(function() Music.delList(l) openList = nil show(3) end)
							end)
						else
							local sf = scrollList(res)
							local box = mk("TextBox", { PlaceholderText = "New playlist name (Enter)", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 }, sf)
							round(box, 17)
							pad(box, 14, 8, 0, 0)
							box.FocusLost:Connect(function(enter)
								if enter and Music.newList(box.Text) then show(3) end
							end)
							if #Music.lists == 0 then txt(sf, "No playlists yet. Create one above, then add songs from Now Playing.", 11, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, LayoutOrder = 2 }) end
							for k, l in ipairs(Music.lists) do
								local r = btn(sf, l.name .. "   (" .. #l.tracks .. ")", false, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 10 + k, TextXAlignment = Enum.TextXAlignment.Left })
								round(r, 12)
								pad(r, 14, 8, 0, 0)
								r.MouseButton1Click:Connect(function() openList = l show(3) end)
							end
						end
					end
				end
				for i, n in ipairs(names) do
					local c = chip(top, n, false, i)
					chips[i] = c
					c.MouseButton1Click:Connect(function() openList = nil show(i) end)
				end
				show(cache.lib or 1)
			end,
			Settings = function(body)
				ctx.setSub("make the app yours")
				settingsPage(body, MusicApp, "Settings", function(sf)
					txt(sf, "MUSIC SOURCES", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 10 })
					txt(sf, "Deezer works with no setup (30 second previews). For full songs add a free Jamendo client id (developer.jamendo.com).", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, LayoutOrder = 11 })
					local jb = mk("TextBox", { Text = Music.jamendoId(), PlaceholderText = "Jamendo client id (Enter to save)", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 12 }, sf)
					round(jb, 12)
					pad(jb, 12, 8, 0, 0)
					jb.FocusLost:Connect(function() Music.setJamendoId(jb.Text) notify("Music", "Jamendo id saved") end)
					local chk = btn(sf, "Run music check", true, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 14 })
					local chkOut = txt(sf, "Tap to test internet, Deezer and audio support.", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 15 })
					chk.MouseButton1Click:Connect(function()
						chkOut.Text = "Checking..."
						task.spawn(function() local r = Music.check() if chkOut.Parent then chkOut.Text = r end end)
					end)
					local cc = btn(sf, "Clear downloaded songs", false, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 13 })
					cc.MouseButton1Click:Connect(function() notify("Music", Music.clearCache() .. " cached songs removed") end)
				end)
			end,
		}, ctx.startTab)
		return function()
			tabsObj.close()
			conn:Disconnect()
			for i, f in ipairs(Music.listeners) do if f == refresh then table.remove(Music.listeners, i) break end end
		end
	end)
end

local PHONE_APPS = {
	{ id = "Chat", title = "Hub Chat", icon = "chat", open = function() openApp(ChatApp) end },
	{ id = "Fits", title = "Fit Saver", icon = "shirt", open = function() openApp(FitApp) end },
	{ id = "Music", title = "Music", icon = "music", takeover = true, open = function() openApp(MusicApp) end },
}

------------------------------------------------------------------------
-- phone navigation: the phone's own home / back buttons close the app (best effort),
-- plus our own back chevron and home bar inside the app.
------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })
local function navName(n)
	n = n:lower()
	if n:find("background") or n:find("backdrop") then return false end
	return n == "home" or n == "homebutton" or n == "home_button" or n == "homebtn" or n == "back" or n == "backbutton" or n == "back_button" or n == "backbtn" or n == "goback" or n == "gohome" or n == "closeapp" or n == "exitapp"
end
local function hookNav()
	local ph = phoneGui()
	if not ph then return end
	for _, d in ipairs(ph:GetDescendants()) do
		if d:IsA("GuiButton") and not hooked[d] and not d:FindFirstAncestor("YadsanAppOverlay") and not d.Name:find("YadsanApp") and navName(d.Name) then
			hooked[d] = true
			d.Activated:Connect(function()
				if current then closeApp() end
			end)
		end
	end
end
task.spawn(function()
	while true do
		task.wait(2)
		pcall(hookNav)
	end
end)
UIS.InputBegan:Connect(function(i)
	if not current then return end
	if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	pcall(function()
		local ph, ov = phoneGui(), current.overlay
		if not ph or not ov.Parent then return end
		local pos = i.Position
		local function inside(x, y)
			local p, s = ov.AbsolutePosition, ov.AbsoluteSize
			return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
		end
		local inset = game:GetService("GuiService"):GetGuiInset()
		if inside(pos.X, pos.Y) or inside(pos.X, pos.Y + inset.Y) then return end
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		for _, o in ipairs(pg:GetGuiObjectsAtPosition(pos.X, pos.Y)) do
			if o:IsA("GuiButton") and o:IsDescendantOf(ph) and not o:IsDescendantOf(ov) and not o.Name:find("YadsanApp") then
				closeApp()
				return
			end
		end
	end)
end)
task.spawn(function()
	while true do
		task.wait(0.4)
		if current then
			local host = overlayHost()
			if not current.overlay.Parent or not host or not shown(host) then closeApp(true) end
		end
	end
end)

-- ===== inject app icons into the game's phone =====
local function isOurs(o)
	local g = o:FindFirstAncestorWhichIsA("ScreenGui")
	return g ~= nil and (g == Window.Gui or g.Name:find("Yadsan") ~= nil)
end
local function clickable(o)
	if o:IsA("GuiButton") then return o end
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("GuiButton") then return d end
	end
	return nil
end
local APP_WORDS = { avatar = 1, vehicles = 1, lifesnap = 1, misc = 1, family = 1, store = 1, items = 1, settings = 1, home = 1, shop = 1, cars = 1 }
local function hasLayout(o)
	return o:FindFirstChildWhichIsA("UIGridLayout") ~= nil or o:FindFirstChildWhichIsA("UIListLayout") ~= nil or o:FindFirstChildWhichIsA("UIPageLayout") ~= nil
end
-- find the phone's app grid by looking for the known app names (Avatar, Vehicles, Family...) and climbing to the layout parent
local lastHost
local function getPhoneHost()
	if lastHost and lastHost.Parent and lastHost.AbsoluteSize.X > 10 then return lastHost end
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local votes = {}
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = tostring(d.Text):lower():gsub("^%s+", ""):gsub("%s+$", "")
			if APP_WORDS[t] and not isOurs(d) then
				local node = d
				while node.Parent and node.Parent ~= pg do
					local par = node.Parent
					if par:IsA("GuiObject") and hasLayout(par) then
						votes[par] = (votes[par] or 0) + 1
						break
					end
					node = par
				end
			end
		end
	end
	local best, bn = nil, 0
	for h, n in pairs(votes) do
		if n > bn and h.AbsoluteSize.X > 10 then best, bn = h, n end
	end
	if not best then
		-- hand-placed grid: the parent that holds several children that each contain an app label
		local cnt = {}
		for _, d in ipairs(pg:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and APP_WORDS[tostring(d.Text):lower()] and not isOurs(d) then
				local node = d
				for _ = 1, 4 do
					if node.Parent and node.Parent ~= pg then
						node = node.Parent
						if node.Parent and node.Parent:IsA("GuiObject") then cnt[node.Parent] = (cnt[node.Parent] or 0) + 1 end
					end
				end
			end
		end
		for h, n in pairs(cnt) do
			if n > bn and n >= 4 and h.AbsoluteSize.X > 10 then best, bn = h, n end
		end
	end
	if not best then
		local o = pg
		for _, n in ipairs({ "Phone", "PhoneHome", "MasterFrame", "Holder", "AppsHolder" }) do
			o = o and o:FindFirstChild(n)
		end
		best = o
	end
	lastHost = best
	return best
end

-- the unlabelled "?" tile (the one that asks to join a group): we put the Music app in its place
local function unlabeled(c)
	for _, d in ipairs(c:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:gsub("%s", "") ~= "" and d.Text ~= "?" then return false end
	end
	if (c:IsA("TextButton") or c:IsA("TextLabel")) and c.Text:gsub("%s", "") ~= "" and c.Text ~= "?" then return false end
	return true
end
local function findQuestionTile(host)
	local best, bs = nil, 0
	for _, c in ipairs(host:GetChildren()) do
		if c:IsA("GuiObject") and not c.Name:find("YadsanApp") and c.AbsoluteSize.X > 8 and clickable(c) then
			local nm, sc = c.Name:lower(), 0
			if unlabeled(c) then sc = sc + 2 end
			if nm:find("group") or nm:find("join") or nm:find("lock") or nm:find("question") or nm:find("soon") or nm:find("unknown") then sc = sc + 3 end
			for _, d in ipairs(c:GetDescendants()) do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == "?" then sc = sc + 3 break end
			end
			if sc >= 2 then
				sc = sc + (c.LayoutOrder or 0) / 1e6 + (c.AbsolutePosition.Y * 1e-4)
				if sc > bs then best, bs = c, sc end
			end
		end
	end
	return best
end

local function allImages(c)
	local t = {}
	if c:IsA("ImageLabel") or c:IsA("ImageButton") then t[#t + 1] = c end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then t[#t + 1] = d end
	end
	return t
end

-- find a free spot in a hand-placed grid of app frames
local function placeInFreeSlot(host, clone, template)
	local lay = host:FindFirstChildWhichIsA("UIGridLayout") or host:FindFirstChildWhichIsA("UIListLayout")
	if lay then
		clone.LayoutOrder = 99990
		return true
	end
	local hp, hs = host.AbsolutePosition, host.AbsoluteSize
	local items = {}
	for _, c in ipairs(host:GetChildren()) do
		if c:IsA("GuiObject") and c ~= clone and c.Visible then
			local rx, ry = c.AbsolutePosition.X - hp.X, c.AbsolutePosition.Y - hp.Y
			if rx >= -2 and ry >= -2 and rx + c.AbsoluteSize.X <= hs.X + 2 and ry + c.AbsoluteSize.Y <= hs.Y + 2 and c.AbsoluteSize.X > 4 then
				items[#items + 1] = { x = math.floor(rx / 4 + 0.5) * 4, y = math.floor(ry / 4 + 0.5) * 4 }
			end
		end
	end
	local xs, ys, occ, seenX, seenY = {}, {}, {}, {}, {}
	for _, it in ipairs(items) do
		if not seenX[it.x] then seenX[it.x] = true xs[#xs + 1] = it.x end
		if not seenY[it.y] then seenY[it.y] = true ys[#ys + 1] = it.y end
		occ[it.x .. "," .. it.y] = true
	end
	table.sort(xs)
	table.sort(ys)
	if #xs == 0 or #ys == 0 then return false end
	local tx, ty = nil, nil
	for _, y in ipairs(ys) do
		for _, x in ipairs(xs) do
			if not occ[x .. "," .. y] then tx, ty = x, y break end
		end
		if tx then break end
	end
	if not tx then
		local step = #ys >= 2 and (ys[#ys] - ys[#ys - 1]) or (template.AbsoluteSize.Y + 12)
		tx, ty = xs[1], ys[#ys] + step
	end
	local trx, try = template.AbsolutePosition.X - hp.X, template.AbsolutePosition.Y - hp.Y
	clone.Position = template.Position + UDim2.fromScale((tx - trx) / hs.X, (ty - try) / hs.Y)
	return true
end

local function styleClone(c, app)
	-- text: first label gets our title, the rest are hidden
	local first = true
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			if d.Text ~= "" then
				if first then d.Text = app.title first = false else d.Text = "" end
			end
		end
	end
	if c:IsA("TextButton") and c.Text ~= "" and first then c.Text = app.title end
	-- icon: keep the biggest image as the tile, hide the other glyphs, then draw ours
	local imgs = allImages(c)
	table.sort(imgs, function(a, b) return a.AbsoluteSize.X * a.AbsoluteSize.Y > b.AbsoluteSize.X * b.AbsoluteSize.Y end)
	local tile = imgs[1]
	for i = 2, #imgs do imgs[i].Visible = false end
	if tile then
		tile.Image = ""
		tile.BackgroundTransparency = 0
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		local uc = tile:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", tile)
		uc.CornerRadius = UDim.new(0.28, 0)
		for _, o in ipairs(tile:GetChildren()) do
			if o:IsA("UIGradient") or o:IsA("UIStroke") then o:Destroy() end
		end
		local ug = Instance.new("UIGradient")
		ug.Rotation = 55
		ug.Color = ColorSequence.new(Color3.fromHSV(TH.h or 0.75, 0.7, 0.85), Color3.fromHSV(TH.h or 0.75, 0.85, 0.28))
		ug.Parent = tile
		local us2 = Instance.new("UIStroke")
		us2.Thickness = 1.5
		us2.Transparency = 0.35
		us2.Color = Color3.new(1, 1, 1)
		us2.Parent = tile
		local asset = NovaUI.Asset(app.icon)
		local g = Instance.new("ImageLabel")
		g.BackgroundTransparency = 1
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.62, 0.62)
		g.ZIndex = tile.ZIndex + 2
		if asset then
			g.Image = asset
			g.ImageColor3 = Color3.new(1, 1, 1)
		end
		g.Parent = tile
		if not asset then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(220, 180, 255)
			t.Text = app.id == "Chat" and "C" or "F"
			t.ZIndex = tile.ZIndex + 2
			t.Parent = tile
		end
	end
end

local function injectApp(host, app)
	local existing = host:FindFirstChild("YadsanApp_" .. app.id)
	if existing then
		if app.takeover and app._slot and app._slot.Parent then
			if app._slot.Visible then app._slot.Visible = false end
		end
		return true
	end
	if host.AbsoluteSize.X < 10 then return false end
	local slot = nil
	if app.takeover then slot = findQuestionTile(host) end
	local template = host:FindFirstChild("Tools")
	if not (template and template:IsA("GuiObject") and clickable(template)) then
		template = nil
		for _, c in ipairs(host:GetChildren()) do
			if c:IsA("GuiObject") and not c.Name:find("YadsanApp") and c ~= slot and c.Name ~= "Misc" and clickable(c) and not unlabeled(c) then template = c break end
		end
	end
	if not template then return false end
	local c = template:Clone()
	c.Name = "YadsanApp_" .. app.id
	c.Visible = true
	-- strip everything the game could use to hook this clone to its own app (tags, attributes, scripts)
	local CS = game:GetService("CollectionService")
	local function strip(o)
		pcall(function()
			for _, tg in ipairs(CS:GetTags(o)) do CS:RemoveTag(o, tg) end
			for k in pairs(o:GetAttributes()) do o:SetAttribute(k, nil) end
		end)
		if o:IsA("LocalScript") or o:IsA("Script") or o:IsA("ModuleScript") then
			o:Destroy()
			return
		end
		if o:IsA("GuiButton") then
			pcall(function() o.Interactable = false end)
			pcall(function() o.Active = false end)
		end
		for _, d in ipairs(o:GetChildren()) do strip(d) end
	end
	strip(c)
	c.Parent = host
	if slot then
		c.LayoutOrder = slot.LayoutOrder
		c.Position, c.Size, c.AnchorPoint = slot.Position, slot.Size, slot.AnchorPoint
		c.ZIndex = slot.ZIndex
		slot.Visible = false
		app._slot = slot
	elseif not placeInFreeSlot(host, c, template) then
		c:Destroy()
		return false
	end
	styleClone(c, app)
	-- our own click catcher on top (the cloned buttons are disabled, so the game's Items app cannot open)
	local catcher = Instance.new("TextButton")
	catcher.Name = "YadsanAppCatcher"
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.AutoButtonColor = false
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 200
	catcher.Active = true
	catcher.Parent = c
	local fired = 0
	local function go()
		if os.clock() - fired < 0.3 then return end
		fired = os.clock()
		app.open()
	end
	catcher.Activated:Connect(go)
	return true
end
NovaUI.PhoneApps, NovaUI.Music, NovaUI.FitStore = PHONE_APPS, Music, FitStore
local phoneState = { host = false, told = false, t0 = os.clock() }
local function installPhoneApps(silent)
	local host = getPhoneHost()
	if not host then
		if not silent then notify("Phone apps", "Phone not found. Open your phone once, then press Install again.") end
		return false
	end
	local ok = true
	for _, app in ipairs(PHONE_APPS) do ok = injectApp(host, app) and ok end
	if ok and not phoneState.told then
		phoneState.told = true
		local took = PHONE_APPS[3]._slot and "Music replaced the '?' tile" or "Music added in a free slot"
		notify("Phone apps", "Added to your phone. " .. took .. ".")
	end
	if ok and not silent then notify("Phone apps", "Hub Chat and Fit Saver added to your phone home screen.") end
	if not ok and not silent then notify("Phone apps", "Could not place the icons. Use 'Copy phone scan report' and send it.") end
	return ok
end
task.spawn(function()
	while true do
		task.wait(3)
		pcall(installPhoneApps, true)
		if not phoneState.told and not phoneState.warned and os.clock() - phoneState.t0 > 90 then
			phoneState.warned = true
			notify("Phone apps", "Phone grid not found yet. Open your phone home screen, or use the floating M button to open Music / Chat / Fits.")
		end
	end
end)

local phoneSec = Dev:Section({ Title = "Phone apps", Icon = "chat", Side = "Right" })
phoneSec:Button({ Title = "Install apps in phone", Style = "Primary", Callback = function() installPhoneApps(false) end })
phoneSec:Button({ Title = "Open Hub Chat app", Callback = function() PHONE_APPS[1].open() end })
phoneSec:Button({ Title = "Copy screen-edge UI scan", Callback = function()
	local out, pg = {}, lp:FindFirstChild("PlayerGui")
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1600, 720)
	for _, d in ipairs(pg and pg:GetDescendants() or {}) do
		if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 6 and d.AbsoluteSize.Y > 6 and d.AbsoluteSize.X < 400 and (d.AbsolutePosition.X < 60 or d.AbsolutePosition.X + d.AbsoluteSize.X > vp.X - 60) then
			out[#out + 1] = ("%s [%s] pos %d,%d size %d,%d %s"):format(d:GetFullName():gsub("^Players%.[^.]+%.PlayerGui%.", ""), d.ClassName, d.AbsolutePosition.X, d.AbsolutePosition.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y, (d:IsA("TextLabel") or d:IsA("TextButton")) and ("text=" .. d.Text) or "")
			if #out >= 80 then break end
		end
	end
	pcall(function() setclipboard(table.concat(out, "\n")) end)
	notify("Scan", #out .. " edge elements copied")
end })
phoneSec:Button({ Title = "Open Fit Saver app", Callback = function() PHONE_APPS[2].open() end })
phoneSec:Button({ Title = "Copy phone UI map", Callback = function()
	local ph = phoneGui()
	if not ph then notify("Phone map", "Phone UI not found. Open the phone first.") return end
	local lines = {}
	local function walk(o, d)
		if d > 5 or #lines > 450 then return end
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("GuiObject") or c:IsA("ScreenGui") or c:IsA("Folder") then
				if not (c.Name:find("YadsanApp")) then
					local extra = ""
					if c:IsA("GuiButton") then extra = extra .. " [BTN]" end
					if c:IsA("GuiObject") then extra = extra .. (c.Visible and "" or " hidden") .. (" %dx%d"):format(c.AbsoluteSize.X, c.AbsoluteSize.Y) end
					if c:IsA("TextLabel") or c:IsA("TextButton") then extra = extra .. ' "' .. tostring(c.Text):sub(1, 18) .. '"' end
					lines[#lines + 1] = string.rep("  ", d) .. c.Name .. ":" .. c.ClassName .. extra
					walk(c, d + 1)
				end
			end
		end
	end
	lines[1] = "Phone"
	walk(ph, 1)
	if setclipboard then setclipboard(table.concat(lines, "\n")) end
	notify("Phone map", #lines .. " lines copied to clipboard.")
end })
phoneSec:Label("Open the phone once, then press Install. Apps open inside the phone screen; its back/home buttons (or our own) close them.")

defCmd("chatapp", "chatapp", "Open Hub Chat in the phone", function() PHONE_APPS[1].open() return "Chat app" end)
defCmd("musicapp", "musicapp", "Open the Music app", function() PHONE_APPS[3].open() return "Music app" end)
defCmd("fitapp", "fitapp", "Open Fit Saver in the phone", function() PHONE_APPS[2].open() return "Fit app" end)
end
end)()
;(function()
------------------------------------------------------------------------
-- LIFE RP tab: Life Together specific features (remotes taken from the Flames Hub script).
-- Only features that affect your own character / car / home / phone. Nothing that targets other players.
------------------------------------------------------------------------
local Life = Window:CreateTab({ Name = "Life RP", Icon = "flame" })
local function send(...)
	if not net then notify("Life RP", "Game network not found (are you in Life Together RP?)") return false end
	local a = table.pack(...)
	local ok, e = pcall(function() return net.send(table.unpack(a, 1, a.n)) end)
	return ok
end
local function get(...)
	if not net then return false end
	local a = table.pack(...)
	local ok, r = pcall(function() return net.get(table.unpack(a, 1, a.n)) end)
	return ok, r
end
local running = {}
local function startLoop(key, interval, fn)
	if running[key] then return end
	running[key] = true
	task.spawn(function()
		while running[key] do
			pcall(fn)
			task.wait(interval)
		end
	end)
end
local function stopLoop(key)
	running[key] = nil
end

local function myVehicle()
	local vf = workspace:FindFirstChild("Vehicles")
	if not vf then return nil end
	for _, v in ipairs(vf:GetChildren()) do
		local o = v:FindFirstChild("owner") or v:FindFirstChild("owner", true)
		if o and o.Value == lp then return v end
	end
end
local function myPlot()
	local plotInst, plotObj
	pcall(function()
		local mods = require(game:GetService("ReplicatedStorage"):FindFirstChild("Modules", true))
		for _, m in pairs(mods) do
			if type(m) == "table" then
				local okc, objs = pcall(function() return m.class and m.class.objects end)
				if okc and type(objs) == "table" then
					for _, plot in pairs(objs) do
						if type(plot) == "table" and plot.states and plot.states.owner and plot.instance then
							local okg, owner = pcall(function() return plot.states.owner.get() end)
							if okg and owner == lp then
								plotInst, plotObj = plot.instance, plot
								return
							end
						end
					end
				end
			end
		end
	end)
	return plotInst, plotObj
end
local function plotLocked(plotObj)
	local ok, v = pcall(function() return plotObj.states.locked.get() end)
	if ok then return v end
end

-- ===== Profile =====
local prof = Life:Section({ Title = "Profile", Icon = "user", Side = "Left" })
prof:Input({ Placeholder = "Roleplay name (press Enter)", Callback = function(t)
	if t and t ~= "" then send("roleplay_name", tostring(t)) notify("Life RP", "Roleplay name set") end
end })
prof:Input({ Placeholder = "Bio (press Enter)", Callback = function(t)
	if t and t ~= "" then send("bio", tostring(t)) notify("Life RP", "Bio set") end
end })
local MARK = "`~ Celestial•Yadsan Anti Stealer Is Enabled ~`"
local prevBio
prof:Toggle({ Title = "Anti Outfit Copier", Description = "Hides your outfit and marks your bio so copiers skip you", Icon = "shield", Default = false, Flag = "AntiCopy", Callback = function(v)
	if v then
		prevBio = lp:GetAttribute("bio")
		send("hide_view_outfit", true)
		send("bio", MARK)
		startLoop("anticopy", 0.5, function()
			if lp:GetAttribute("hide_view_outfit") == false then send("hide_view_outfit", true) end
			if lp:GetAttribute("bio") ~= MARK then send("bio", MARK) end
		end)
	else
		stopLoop("anticopy")
		if type(prevBio) == "string" and prevBio ~= MARK then send("bio", prevBio) end
	end
end })
prof:Toggle({ Title = "Hide my name", Icon = "eye", Default = false, Flag = "HideName", Callback = function(v) send("hide_name", v) end })
prof:Toggle({ Title = "Hide other names", Icon = "eye", Default = false, Flag = "HideOthers", Callback = function(v) send("hide_other_names", v) end })
prof:Toggle({ Title = "Hide map icon", Icon = "eye", Default = false, Flag = "HideMapIcon", Callback = function(v) send("hide_map_icon", v) end })

-- ===== Jobs =====
local jobs = Life:Section({ Title = "Job", Icon = "star", Side = "Left" })
local jobActs = {}
for _, j in ipairs({ "Police", "Firefighter", "Baker", "Pizza Worker", "Barista", "Doctor" }) do
	jobActs[#jobActs + 1] = { Title = j, Description = "Set job", Icon = "star", Callback = function()
		send("job", j)
		notify("Life RP", "Job: " .. j)
	end }
end
jobs:Actions(jobActs)

-- ===== Phone =====
local ph = Life:Section({ Title = "Phone", Icon = "chat", Side = "Left" })
ph:Toggle({ Title = "Rainbow phone", Icon = "sparkles", Default = false, Flag = "RainbowPhone", Callback = function(v)
	if v then
		local h = 0
		startLoop("rphone", 0.15, function()
			h = (h + 0.04) % 1
			send("phone_color", Color3.fromHSV(h, 1, 1))
		end)
	else
		stopLoop("rphone")
		task.wait(0.2)
		send("phone_color", Color3.new(1, 1, 1))
	end
end })
local PCOL = { { "Red", Color3.fromRGB(255, 60, 60) }, { "Blue", Color3.fromRGB(60, 120, 255) }, { "Green", Color3.fromRGB(60, 220, 110) }, { "Pink", Color3.fromRGB(255, 120, 200) }, { "Purple", Color3.fromRGB(150, 70, 255) }, { "White", Color3.new(1, 1, 1) } }
local pAct = {}
for _, c in ipairs(PCOL) do
	pAct[#pAct + 1] = { Title = c[1], Description = "Phone color", Icon = "star", Callback = function() send("phone_color", c[2]) end }
end
ph:Actions(pAct)	

-- =====================================================================
-- YADSAN X YAKUZA | YadsanUI Vehicle & Player-Vehicle Module
-- =====================================================================
do
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer

	local vehTab = Window:CreateTab({ Name = "Vehicle", Icon = "bolt" })
	local secVeh = vehTab:Section({ Title = "Vehicle Controls", Icon = "bolt", Side = "Left" })
	local secFly = vehTab:Section({ Title = "Fly & Fling", Icon = "shield", Side = "Left" })
	local secView = vehTab:Section({ Title = "View, Style & ESP", Icon = "eye", Side = "Right" })
	local secTarget = vehTab:Section({ Title = "Target & Bus Actions", Icon = "users", Side = "Right" })

	local vehFlySpeed = 80
	local vehFlyConn, vehBV, vehBG
	local autoLockConn
	local rainbow2xConn
	local viewVehConn, prevCamSubject
	local antiFlingConn
	local vehEspConn, vehEspFolder

	local function getChar()
		return lp.Character
	end

	local function getHum()
		local c = getChar()
		return c and c:FindFirstChildOfClass("Humanoid")
	end

	local function getRoot()
		local c = getChar()
		return c and c:FindFirstChild("HumanoidRootPart")
	end

	local function getOwnedVehicle()
		local vf = workspace:FindFirstChild("Vehicles")
		if not vf then return nil end
		for _, v in ipairs(vf:GetChildren()) do
			if v:IsA("Model") then
				local owner = v:FindFirstChild("owner") or v:FindFirstChild("owner", true)
				if owner and owner:IsA("ObjectValue") and owner.Value == lp then
					return v
				end
			end
		end
		return nil
	end

	local function getOtherVehicle(plr)
		if not plr then return nil end
		local vf = workspace:FindFirstChild("Vehicles")
		if not vf then return nil end
		for _, v in ipairs(vf:GetChildren()) do
			if v:IsA("Model") then
				local owner = v:FindFirstChild("owner") or v:FindFirstChild("owner", true)
				if owner and owner:IsA("ObjectValue") and owner.Value == plr then
					return v
				end
			end
		end
		return nil
	end

	local function getSeat(veh)
		if not veh then return nil end
		return veh:FindFirstChildWhichIsA("VehicleSeat", true) or veh:FindFirstChildWhichIsA("Seat", true)
	end

	local function findPlayer(query)
		query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
		if query == "" then return nil end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower() == query or p.DisplayName:lower() == query then
				return p
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower():find(query, 1, true) or p.DisplayName:lower():find(query, 1, true) then
				return p
			end
		end
		return nil
	end

	local function paintVehicle(veh, colA, colB)
		if not veh then return end
		local bodyParts = {}
		for _, d in ipairs(veh:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local n = d.Name:lower()
				if not n:find("wheel") and not n:find("tire") and not n:find("glass") and not n:find("window") then
					table.insert(bodyParts, d)
				end
			end
		end
		for i, part in ipairs(bodyParts) do
			pcall(function()
				if colB and i % 2 == 0 then
					part.Color = colB
				else
					part.Color = colA
				end
			end)
		end
	end

	local function stopVehFly()
		if vehFlyConn then vehFlyConn:Disconnect() vehFlyConn = nil end
		if vehBV then vehBV:Destroy() vehBV = nil end
		if vehBG then vehBG:Destroy() vehBG = nil end
	end

	local function startVehFly()
		stopVehFly()
		local veh = getOwnedVehicle()
		local anchor = getSeat(veh) or (veh and veh.PrimaryPart) or (veh and veh:FindFirstChildWhichIsA("BasePart", true))
		if not anchor then
			Window:Notify({ Title = "Vehicle Fly", Content = "Spawn a vehicle first." })
			return
		end

		vehBV = Instance.new("BodyVelocity")
		vehBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		vehBV.Velocity = Vector3.zero
		vehBV.Parent = anchor

		vehBG = Instance.new("BodyGyro")
		vehBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		vehBG.P = 1e4
		vehBG.CFrame = anchor.CFrame
		vehBG.Parent = anchor

		vehFlyConn = RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			local hum = getHum()
			if not cam or not anchor.Parent then
				stopVehFly()
				return
			end
			local md = hum and hum.MoveDirection or Vector3.zero
			local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
			local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
			if look.Magnitude > 0 then look = look.Unit end
			if right.Magnitude > 0 then right = right.Unit end

			local vel = (cam.CFrame.LookVector * md:Dot(look) + cam.CFrame.RightVector * md:Dot(right)) * vehFlySpeed
			if UIS:IsKeyDown(Enum.KeyCode.Space) then
				vel += Vector3.new(0, vehFlySpeed, 0)
			end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
				vel -= Vector3.new(0, vehFlySpeed, 0)
			end

			vehBV.Velocity = vel
			vehBG.CFrame = CFrame.new(anchor.Position, anchor.Position + cam.CFrame.LookVector)
		end)
	end

	-- ===== Vehicle Controls =====
	local spawnName = "Monster Truck"
	secVeh:Input({
		Placeholder = "Vehicle name (e.g. Monster Truck)",
		Callback = function(t)
			if t and t ~= "" then
				spawnName = t
			end
		end,
	})

	secVeh:Button({
		Title = "Spawn Vehicle",
		Style = "Primary",
		Callback = function()
			if _G.net and typeof(_G.net.get) == "function" then
				pcall(_G.net.get, "spawn_vehicle", spawnName)
			elseif _G.g and typeof(_G.g.spawn_any_vehicle) == "function" then
				pcall(_G.g.spawn_any_vehicle, spawnName)
			end
			Window:Notify({ Title = "Vehicle", Content = "Requested spawn: " .. spawnName })
		end,
	})

	secVeh:Button({
		Title = "Despawn Vehicle",
		Callback = function()
			local veh = getOwnedVehicle()
			if not veh then
				Window:Notify({ Title = "Vehicle", Content = "No owned vehicle found." })
				return
			end
			if _G.net and typeof(_G.net.get) == "function" then
				pcall(_G.net.get, "spawn_vehicle", veh.Name)
			else
				pcall(function() veh:Destroy() end)
			end
			Window:Notify({ Title = "Vehicle", Content = "Despawned vehicle." })
		end,
	})

	secVeh:Toggle({
		Title = "Auto Lock Vehicle To Me",
		Description = "Keeps your vehicle locked",
		Default = false,
		Flag = "AutoLockVehicleToMe",
		Callback = function(on)
			if autoLockConn then autoLockConn:Disconnect() autoLockConn = nil end
			if on then
				autoLockConn = RunService.Heartbeat:Connect(function()
					local veh = getOwnedVehicle()
					if veh and veh:GetAttribute("locked") ~= true then
						pcall(function() veh:SetAttribute("locked", true) end)
						if _G.net and typeof(_G.net.get) == "function" then
							pcall(_G.net.get, "lock_vehicle", veh)
						end
					end
				end)
			end
		end,
	})

	secVeh:Button({
		Title = "Bring Vehicle To Me",
		Callback = function()
			local veh = getOwnedVehicle()
			local root = getRoot()
			if veh and root then
				pcall(function() veh:PivotTo(root.CFrame * CFrame.new(0, 3, -9)) end)
				Window:Notify({ Title = "Vehicle", Content = "Brought your vehicle to you." })
			else
				Window:Notify({ Title = "Vehicle", Content = "No vehicle or character found." })
			end
		end,
	})

	secVeh:Button({
		Title = "Go To Vehicle",
		Callback = function()
			local veh = getOwnedVehicle()
			local root = getRoot()
			if veh and root then
				pcall(function() root.CFrame = veh:GetPivot() * CFrame.new(0, 5, 0) end)
				Window:Notify({ Title = "Vehicle", Content = "Teleported to your vehicle." })
			else
				Window:Notify({ Title = "Vehicle", Content = "No vehicle or character found." })
			end
		end,
	})

	-- ===== Fly & Fling =====
	secFly:Toggle({
		Title = "Vehicle Fly",
		Description = "Fly your vehicle (WASD + Space/Shift)",
		Default = false,
		Flag = "VehicleFly",
		Callback = function(on)
			if on then startVehFly() else stopVehFly() end
		end,
	})

	secFly:Slider({
		Title = "Vehicle Fly Speed",
		Min = 15,
		Max = 300,
		Default = 80,
		Increment = 5,
		Flag = "VehicleFlySpeed",
		Callback = function(v)
			vehFlySpeed = v
		end,
	})

	secFly:Toggle({
		Title = "Anti Vehicle Fling",
		Description = "Stops fling velocities and disables other vehicle collisions",
		Default = false,
		Flag = "AntiVehicleFling",
		Callback = function(on)
			if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
			if on then
				antiFlingConn = RunService.Stepped:Connect(function()
					local vf = workspace:FindFirstChild("Vehicles")
					local mine = getOwnedVehicle()
					if vf then
						for _, v in ipairs(vf:GetChildren()) do
							if v ~= mine then
								for _, p in ipairs(v:GetDescendants()) do
									if p:IsA("BasePart") then
										p.CanCollide = false
									end
								end
							end
						end
					end
					local root = getRoot()
					if root and root.AssemblyLinearVelocity.Magnitude > 220 then
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
					end
				end)
			end
		end,
	})

	-- ===== View, Style & ESP =====
	secView:Toggle({
		Title = "View Vehicle",
		Description = "Focus camera on your vehicle",
		Default = false,
		Flag = "ViewVehicle",
		Callback = function(on)
			local cam = workspace.CurrentCamera
			if viewVehConn then viewVehConn:Disconnect() viewVehConn = nil end
			if on then
				local veh = getOwnedVehicle()
				local part = getSeat(veh) or (veh and veh:FindFirstChildWhichIsA("BasePart", true))
				if not part or not cam then
					Window:Notify({ Title = "View Vehicle", Content = "No spawned vehicle found." })
					return
				end
				prevCamSubject = cam.CameraSubject
				cam.CameraSubject = part
				viewVehConn = part.AncestryChanged:Connect(function(_, parent)
					if not parent and cam then
						cam.CameraSubject = prevCamSubject or getHum()
					end
				end)
			elseif cam then
				cam.CameraSubject = prevCamSubject or getHum()
			end
		end,
	})

	secView:Button({
		Title = "Two Tone Vehicle",
		Callback = function()
			local veh = getOwnedVehicle()
			if not veh then
				Window:Notify({ Title = "Two Tone", Content = "No owned vehicle found." })
				return
			end
			paintVehicle(veh, Color3.fromRGB(255, 175, 36), Color3.fromRGB(25, 25, 35))
			Window:Notify({ Title = "Two Tone", Content = "Applied two-tone colors." })
		end,
	})

	secView:Toggle({
		Title = "Rainbow Vehicle (2x Fast)",
		Description = "Cycles vehicle colors at 2x speed",
		Default = false,
		Flag = "RainbowVehicle2x",
		Callback = function(on)
			if rainbow2xConn then rainbow2xConn:Disconnect() rainbow2xConn = nil end
			if on then
				local hue = 0
				local accum = 0
				rainbow2xConn = RunService.Heartbeat:Connect(function(dt)
					accum += dt * 2
					if accum >= 0.1 then
						accum = 0
						hue = (hue + 0.08) % 1
						local veh = getOwnedVehicle()
						if veh then
							local col = Color3.fromHSV(hue, 1, 1)
							paintVehicle(veh, col, nil)
							if _G.net and typeof(_G.net.send) == "function" then
								pcall(_G.net.send, "vehicle_color", col, veh)
							end
						end
					end
				end)
			end
		end,
	})

	local function clearVehEsp()
		if vehEspConn then vehEspConn:Disconnect() vehEspConn = nil end
		if vehEspFolder then vehEspFolder:Destroy() vehEspFolder = nil end
	end

	secView:Toggle({
		Title = "Vehicle ESP",
		Description = "Highlight vehicles through walls",
		Default = false,
		Flag = "VehicleESP",
		Callback = function(on)
			clearVehEsp()
			if not on then return end
			vehEspFolder = Instance.new("Folder")
			vehEspFolder.Name = "YadsanVehESP"
			vehEspFolder.Parent = workspace

			local function sync()
				if not vehEspFolder then return end
				for _, c in ipairs(vehEspFolder:GetChildren()) do c:Destroy() end
				local vf = workspace:FindFirstChild("Vehicles")
				if not vf then return end
				for _, v in ipairs(vf:GetChildren()) do
					if v:IsA("Model") then
						local hl = Instance.new("Highlight")
						hl.FillColor = Color3.fromRGB(255, 175, 36)
						hl.OutlineColor = Color3.new(1, 1, 1)
						hl.FillTransparency = 0.55
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Adornee = v
						hl.Parent = vehEspFolder
					end
				end
			end

			sync()
			local vf = workspace:FindFirstChild("Vehicles")
			if vf then
				vehEspConn = vf.ChildAdded:Connect(function()
					task.defer(sync)
				end)
			end
		end,
	})

	-- ===== Target & SchoolBus Actions =====
	local targetQuery = ""
	secTarget:Input({
		Placeholder = "Username or display name...",
		Callback = function(t)
			targetQuery = t or ""
		end,
	})

	secTarget:Button({
		Title = "Teleport Car To Player",
		Callback = function()
			local p = findPlayer(targetQuery)
			local veh = getOwnedVehicle()
			local tRoot = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if p and veh and tRoot then
				pcall(function() veh:PivotTo(tRoot.CFrame * CFrame.new(0, 4, -8)) end)
				Window:Notify({ Title = "Vehicle", Content = "Teleported vehicle to " .. p.DisplayName })
			else
				Window:Notify({ Title = "Vehicle", Content = "Target or owned vehicle not found." })
			end
		end,
	})

	secTarget:Button({
		Title = "Steal Car",
		Callback = function()
			local p = findPlayer(targetQuery)
			local oVeh = getOtherVehicle(p)
			local root = getRoot()
			local hum = getHum()
			if not p or not oVeh or not root then
				Window:Notify({ Title = "Steal Car", Content = "Target or their vehicle not found." })
				return
			end
			root.CFrame = oVeh:GetPivot() * CFrame.new(0, 3, 0)
			task.wait(0.15)
			local seat = getSeat(oVeh)
			if seat and hum then
				pcall(function() seat:Sit(hum) end)
			end
			Window:Notify({ Title = "Steal Car", Content = "Moved to " .. p.DisplayName .. "'s vehicle." })
		end,
	})

	local function getNet()
		local n = _G.net or (_G.g and _G.g.Net)
		if not n then
			local rs = game:GetService("ReplicatedStorage")
			local mod = rs:FindFirstChild("Modules", true)
			local core = mod and mod:FindFirstChild("Core")
			local netMod = core and core:FindFirstChild("Net")
			if netMod and netMod:IsA("ModuleScript") then
				pcall(function() n = require(netMod) end)
			end
		end
		return n
	end

	local function remoteGet(name, ...)
		local n = getNet()
		if n and typeof(n.get) == "function" then
			return pcall(n.get, name, ...)
		elseif _G.g and typeof(_G.g.Get) == "function" then
			return pcall(_G.g.Get, name, ...)
		end
		return false
	end

	local function ensureBus()
		local bus = getOtherVehicle(lp)
		if bus and bus.Name == "SchoolBus" then
			return bus
		end
		remoteGet("spawn_vehicle", "SchoolBus")
		local elapsed = 0
		while elapsed < 5 do
			task.wait(0.2)
			elapsed += 0.2
			local found = getOtherVehicle(lp)
			if found and found.Name == "SchoolBus" then
				return found
			end
		end
		return getOtherVehicle(lp)
	end

	local function sitInSeat(seat)
		local hum = getHum()
		local char = getChar()
		if seat and hum and char then
			pcall(function() char:PivotTo(seat.CFrame * CFrame.new(0, 2, 0)) end)
			task.wait(0.15)
			pcall(function() seat:Sit(hum) end)
			if seat.Occupant ~= hum then
				remoteGet("sit", seat)
			end
		end
	end

	local function executeBusTargetAction(actionKind, targetPlr)
		local tRoot = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
		local myRoot = getRoot()
		if not tRoot or not myRoot then
			Window:Notify({ Title = actionKind, Content = "Target or your character is missing." })
			return
		end

		local bus = ensureBus()
		if not bus then
			Window:Notify({ Title = actionKind, Content = "Could not spawn or find SchoolBus." })
			return
		end

		local seat = getSeat(bus)
		local savedCF = myRoot.CFrame

		pcall(function() bus:PivotTo(tRoot.CFrame * CFrame.new(0, 0, -6)) end)
		sitInSeat(seat)
		task.wait(0.2)

		if actionKind == "Bring Player" then
			pcall(function() bus:PivotTo(savedCF * CFrame.new(0, 2, -8)) end)
		elseif actionKind == "Kill Player" then
			pcall(function() bus:PivotTo(CFrame.new(tRoot.Position.X, -500, tRoot.Position.Z)) end)
		elseif actionKind == "Void Player" then
			pcall(function() bus:PivotTo(CFrame.new(tRoot.Position.X, -10000, tRoot.Position.Z)) end)
		elseif actionKind == "Skydive Player" then
			pcall(function() bus:PivotTo(CFrame.new(tRoot.Position.X, tRoot.Position.Y + 1200, tRoot.Position.Z)) end)
		end

		task.wait(0.25)
		local hum = getHum()
		if hum and hum.Sit then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait(0.15)
		end
		if myRoot and myRoot.Parent then
			myRoot.CFrame = savedCF
		end

		Window:Notify({ Title = actionKind, Content = actionKind .. " executed on " .. targetPlr.DisplayName })
	end

	secTarget:Button({
		Title = "Bring Player",
		Callback = function()
			local p = findPlayer(targetQuery)
			if not p then Window:Notify({ Title = "Bring Player", Content = "Target not found." }) return end
			executeBusTargetAction("Bring Player", p)
		end,
	})

	secTarget:Button({
		Title = "Kill Player",
		Callback = function()
			local p = findPlayer(targetQuery)
			if not p then Window:Notify({ Title = "Kill Player", Content = "Target not found." }) return end
			executeBusTargetAction("Kill Player", p)
		end,
	})

	secTarget:Button({
		Title = "Void Player",
		Callback = function()
			local p = findPlayer(targetQuery)
			if not p then Window:Notify({ Title = "Void Player", Content = "Target not found." }) return end
			executeBusTargetAction("Void Player", p)
		end,
	})

	secTarget:Button({
		Title = "Skydive Player",
		Callback = function()
			local p = findPlayer(targetQuery)
			if not p then Window:Notify({ Title = "Skydive Player", Content = "Target not found." }) return end
			executeBusTargetAction("Skydive Player", p)
		end,
	})
		end
		
-- ===== Home =====
local home = Life:Section({ Title = "Home", Icon = "settings", Side = "Right" })
home:Button({ Title = "Lock my home", Callback = function()
	local inst, obj = myPlot()
	if not inst then notify("Home", "Could not find your home plot") return end
	if plotLocked(obj) ~= true then send("lock_home", inst) end
	notify("Home", "Home locked")
end })
home:Button({ Title = "Unlock my home", Callback = function()
	local inst, obj = myPlot()
	if not inst then notify("Home", "Could not find your home plot") return end
	if plotLocked(obj) ~= false then send("lock_home", inst) end
	notify("Home", "Home unlocked")
end })
home:Toggle({ Title = "Auto lock my home", Icon = "shield", Default = false, Flag = "AutoLockHome", Callback = function(v)
	if v then
		startLoop("autolockhome", 1.5, function()
			local inst, obj = myPlot()
			if inst and plotLocked(obj) == false then send("lock_home", inst) end
		end)
	else
		stopLoop("autolockhome")
	end
end })

-- ===== Private server (owner only) =====
local ps = Life:Section({ Title = "Private server (owner only)", Icon = "settings", Side = "Right" })
ps:Toggle({ Title = "Stop time", Icon = "eye", Default = false, Flag = "StopTime", Callback = function(v) send("time_toggle", v) end })
ps:Input({ Placeholder = "Set time number, press Enter", Numeric = true, Callback = function(t)
	local n = tonumber(t)
	if n then send("change_time", n) end
end })
ps:Label("These only work if you own the private server.")
end)()
;(function()
------------------------------------------------------------------------
-- SPAWN BANNER: big "YADSAN HUB" billboard + Owner / Admin cards above the spawn (client side: script users see it).
-- Tap / click any panel for a burst effect.
------------------------------------------------------------------------
local PLAYERS = game:GetService("Players")
local STAFF = {
	{ name = "AGKaBaap_YadsanAsuka", title = "OWNER", colA = Color3.fromRGB(255, 214, 90), colB = Color3.fromRGB(255, 140, 30) },
	{ name = "ZMxCS_Yakuza7", title = "ADMIN", colA = Color3.fromRGB(255, 120, 130), colB = Color3.fromRGB(190, 30, 70), x = 38 },
}
local parts, conn, base = {}, nil, CFrame.new()
local ACC = Color3.fromRGB(170, 100, 255)

-- returns floor point + flat look direction of the spawn closest to you (or a spot near you if none is close)
local function findSpawnCF()
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local best, bd
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			local dist = root and (d.Position - root.Position).Magnitude or 0
			if not bd or dist < bd then best, bd = d, dist end
		end
	end
	if best and (not root or bd < 600) then
		local look = Vector3.new(best.CFrame.LookVector.X, 0, best.CFrame.LookVector.Z)
		if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
		NovaUI.BannerDist = bd
		return Vector3.new(best.Position.X, best.Position.Y + best.Size.Y / 2, best.Position.Z), look.Unit
	end
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
		NovaUI.BannerDist = 0
		return Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z), look.Unit
	end
end

-- local profile: level / days of use / account date, saved in the executor folder (YADSAN_HUB/profile.json)
local DISCORD = "https://discord.gg/gW65gk7tg"
local Profile = { xp = 0, days = 0, minutes = 0 }
local PF = "YADSAN_HUB/profile.json"
local function profSave()
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile(PF, HttpService:JSONEncode({ xp = Profile.xp, days = Profile.days, minutes = Profile.minutes, first = Profile.first, last = Profile.last, streak = Profile.streak, best = Profile.best, copies = Profile.copies, saves = Profile.saves, msgs = Profile.msgs }))
	end)
end
function Profile.level()
	local xp = Profile.xp or 0
	local lv = math.floor(math.sqrt(xp / 40)) + 1
	local lo, hi = 40 * (lv - 1) ^ 2, 40 * lv ^ 2
	return lv, math.clamp((xp - lo) / (hi - lo), 0, 1), xp, hi
end
function Profile.age()
	local a = lp.AccountAge
	return type(a) == "number" and a or 0
end
function Profile.joined()
	return os.date("%d %b %Y", os.time() - Profile.age() * 86400)
end
do
	pcall(function()
		if isfile and isfile(PF) then
			local d = HttpService:JSONDecode(readfile(PF))
			if type(d) == "table" then
				for _, k in ipairs({ "xp", "days", "minutes", "first", "last", "streak", "best", "copies", "saves", "msgs" }) do
					if d[k] ~= nil then Profile[k] = d[k] end
				end
			end
		end
	end)
	Profile.first = tonumber(Profile.first) or os.time()
	local today = os.date("%Y-%m-%d")
	if Profile.last ~= today then
		local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
		Profile.streak = (Profile.last == yesterday) and ((tonumber(Profile.streak) or 0) + 1) or 1
		Profile.best = math.max(tonumber(Profile.best) or 0, Profile.streak)
		Profile.days = (tonumber(Profile.days) or 0) + 1
		Profile.xp = (tonumber(Profile.xp) or 0) + 25
		Profile.last = today
	end
	profSave()
	task.spawn(function()
		while true do
			task.wait(60)
			Profile.xp = Profile.xp + 1
			Profile.minutes = (Profile.minutes or 0) + 1
			profSave()
		end
	end)
end
NovaUI.Profile = Profile
function NovaUI.Stat(k)
	Profile[k] = (tonumber(Profile[k]) or 0) + 1
	profSave()
end
function Profile.achievements()
	local lv = Profile.level()
	local list = {
		{ "First fit copied", (Profile.copies or 0) >= 1 }, { "Fit collector (5 fits saved)", (Profile.saves or 0) >= 5 },
		{ "Chatterbox (25 messages)", (Profile.msgs or 0) >= 25 }, { "Regular (7 days)", (Profile.days or 0) >= 7 },
		{ "3-day streak", (Profile.best or 0) >= 3 }, { "Level 5", lv >= 5 }, { "Level 10", lv >= 10 },
	}
	local out = {}
	for _, a in ipairs(list) do out[#out + 1] = (a[2] and "[x] " or "[ ] ") .. a[1] end
	return table.concat(out, "\n")
end
-- player-made banner settings (YADSAN_HUB/banner.json)
local PALETTES = {
	{ name = "Violet", a = Color3.fromRGB(170, 100, 255), b = Color3.fromRGB(90, 200, 255), bg1 = Color3.fromRGB(44, 16, 88), bg2 = Color3.fromRGB(6, 3, 14) },
	{ name = "Sunset", a = Color3.fromRGB(255, 150, 70), b = Color3.fromRGB(255, 70, 130), bg1 = Color3.fromRGB(90, 28, 40), bg2 = Color3.fromRGB(16, 4, 10) },
	{ name = "Ocean", a = Color3.fromRGB(70, 200, 255), b = Color3.fromRGB(60, 110, 255), bg1 = Color3.fromRGB(12, 44, 90), bg2 = Color3.fromRGB(3, 6, 18) },
	{ name = "Emerald", a = Color3.fromRGB(90, 255, 170), b = Color3.fromRGB(40, 170, 110), bg1 = Color3.fromRGB(10, 70, 50), bg2 = Color3.fromRGB(3, 12, 10) },
	{ name = "Rose", a = Color3.fromRGB(255, 130, 200), b = Color3.fromRGB(200, 80, 255), bg1 = Color3.fromRGB(88, 20, 70), bg2 = Color3.fromRGB(14, 3, 14) },
	{ name = "Gold", a = Color3.fromRGB(255, 226, 120), b = Color3.fromRGB(255, 150, 30), bg1 = Color3.fromRGB(80, 54, 8), bg2 = Color3.fromRGB(14, 9, 3) },
}
local BF = "YADSAN_HUB/banner.json"
local BCFG = { pal = 1, title = "", tag = "" }
pcall(function()
	if isfile and isfile(BF) then
		local d = HttpService:JSONDecode(readfile(BF))
		if type(d) == "table" then
			BCFG.pal = math.clamp(tonumber(d.pal) or 1, 1, #PALETTES)
			BCFG.title = tostring(d.title or ""):sub(1, 24)
			BCFG.tag = tostring(d.tag or ""):sub(1, 40)
		end
	end
end)
local function bcfgSave()
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile(BF, HttpService:JSONEncode(BCFG))
	end)
end
local function copyDiscord()
	local ok = pcall(function() setclipboard(DISCORD) end)
	notify("Discord", ok and "Invite link copied!" or DISCORD)
end

local function newFace(part, face)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "YadsanBannerFace"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40 * (part:GetAttribute("refW") or 48) / math.max(part.Size.X, 1)
	sg.LightInfluence = 0
	sg.Adornee = part
	sg.ResetOnSpawn = false
	sg.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = sg
	local bgg = Instance.new("UIGradient")
	bgg.Color = ColorSequence.new(Color3.fromRGB(44, 16, 88), Color3.fromRGB(6, 3, 14))
	bgg.Rotation = 35
	bgg.Parent = bg
	local st = Instance.new("UIStroke")
	st.Thickness = 10
	st.Color = Color3.new(1, 1, 1)
	st.Parent = bg
	local sg2 = Instance.new("UIGradient")
	sg2.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 60, 255)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 60, 255)) })
	sg2.Parent = st
	return { sg = sg, bg = bg, bgg = bgg, sg2 = sg2 }
end
local function label(parent, text, font, color, pos, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.Position = pos
	l.Size = size
	l.Parent = parent
	return l
end

local function mainFace(part, face)
	local f = newFace(part, face)
	for _, x in ipairs({ 0.09, 0.91 }) do
		pcall(function()
			NovaUI.MakeBlackhole(f.bg, 440, { Position = UDim2.fromScale(x, 0.5), ParticleCount = 10 })
		end)
	end
	local title = label(f.bg, "CELESTIAL SYNDICATE", Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.15, 0.12), UDim2.fromScale(0.7, 0.55))
	title.TextStrokeTransparency = 0.5
	title.TextStrokeColor3 = Color3.fromRGB(110, 40, 230)
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 140, 255)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) })
	tg.Parent = title
	f.tscale = Instance.new("UIScale")
	f.tscale.Parent = title
	f.tg = tg
	f.live = label(f.bg, "L I F E   T O G E T H E R   R P   -   S C R I P T   U S E R S", Enum.Font.GothamBold, Color3.fromRGB(200, 170, 255), UDim2.fromScale(0.15, 0.68), UDim2.fromScale(0.7, 0.12))
	for _, y in ipairs({ 0.045, 0.955 }) do
		local ln = Instance.new("Frame")
		ln.AnchorPoint = Vector2.new(0.5, 0.5)
		ln.Position = UDim2.fromScale(0.5, y)
		ln.Size = UDim2.fromScale(0.86, 0.012)
		ln.BorderSizePixel = 0
		ln.BackgroundColor3 = Color3.new(1, 1, 1)
		ln.Parent = f.bg
		local lg = Instance.new("UIGradient")
		lg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 40, 160)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 40, 160)) })
		lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
		lg.Parent = ln
	end
	-- light sweep across the whole banner
	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Size = UDim2.fromScale(0.12, 1.6)
	shine.Position = UDim2.fromScale(-0.2, 0.5)
	shine.Rotation = 18
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.88
	shine.ZIndex = 20
	shine.Parent = f.bg
	f.shine = shine
	label(f.bg, "TAP TO COPY DISCORD INVITE   -   https://discord.gg/gW65gk7tg", Enum.Font.GothamBold, Color3.fromRGB(150, 160, 255), UDim2.fromScale(0.2, 0.83), UDim2.fromScale(0.6, 0.09))
	return f
end

-- ===== BLACK HOLE banner: animated accretion disc, spiralling particles, wavy glowing "YADSAN HUB" =====
local function holeFace(part, face)
	part.Transparency = 1
	local f = newFace(part, face)
	f.sg.AlwaysOnTop = false
	f.bg.BackgroundTransparency = 1
	f.bg.ClipsDescendants = false
	for _, o in ipairs(f.bg:GetChildren()) do if o:IsA("UIStroke") or o:IsA("UIGradient") then o:Destroy() end end
	f.bgg, f.sg2 = Instance.new("UIGradient"), Instance.new("UIGradient") -- dummies for the shared animation loop
	local root = f.bg
	local H = Vector2.new(0.5, 0.5)
	local function box(parent, cx, cy, w, h, z)
		local o = Instance.new("Frame")
		o.AnchorPoint = H
		o.Position = UDim2.fromScale(cx, cy)
		o.Size = UDim2.fromScale(w, h)
		o.BackgroundTransparency = 1
		o.BorderSizePixel = 0
		o.ZIndex = z or 1
		o.Parent = parent
		return o
	end
	local function circle(o) Instance.new("UICorner", o).CornerRadius = UDim.new(1, 0) return o end
	local function ring(parent, cx, cy, w, h, thick, cols, tr, z)
		local o = circle(box(parent, cx, cy, w, h, z))
		local s = Instance.new("UIStroke")
		s.Thickness = thick
		s.Color = Color3.new(1, 1, 1)
		s.Transparency = tr or 0
		s.Parent = o
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(cols)
		g.Parent = s
		return o, g, s
	end
	local function seq(...)
		local t, n = {}, select("#", ...)
		for i = 1, n do t[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), (select(i, ...))) end
		return t
	end
	local C = Color3.fromRGB
	local grads = {}
	-- soft halo
	local halos = {}
	for i, sz in ipairs({ 1.0, 0.88, 0.76, 0.64 }) do
		local h = circle(box(root, 0.5, 0.5, sz, sz, 1))
		h.BackgroundColor3 = i < 3 and C(255, 175, 40) or C(255, 100, 25)
		h.BackgroundTransparency = 0.93 - i * 0.012
		halos[#halos + 1] = h
	end
	-- outer slow rings
	local _, g1 = ring(root, 0.5, 0.5, 0.96, 0.96, 5, seq(C(150, 90, 255), C(20, 10, 60), C(90, 220, 255), C(20, 10, 60), C(150, 90, 255)), 0.25, 2)
	local _, g2 = ring(root, 0.5, 0.5, 0.84, 0.84, 3, seq(C(255, 160, 80), C(30, 10, 40), C(255, 90, 170), C(30, 10, 40), C(255, 160, 80)), 0.45, 2)
	grads[#grads + 1] = { g1, 40 }
	grads[#grads + 1] = { g2, -70 }
	-- back half of the accretion disc (behind the hole)
	local discCols = seq(C(255, 245, 200), C(255, 160, 50), C(230, 60, 160), C(110, 50, 230), C(60, 200, 255), C(255, 160, 50), C(255, 245, 200))
	local hotCols = seq(C(255, 255, 255), C(255, 220, 140), C(255, 120, 80), C(255, 255, 255), C(255, 220, 140), C(255, 255, 255))
	local function disc(parent, yc, hs, z)
		local _, a = ring(parent, 0.5, yc, 0.98, 0.30 * hs, 54, discCols, 0.05, z)
		local _, b = ring(parent, 0.5, yc, 0.70, 0.215 * hs, 24, hotCols, 0.0, z + 1)
		grads[#grads + 1] = { a, 55 }
		grads[#grads + 1] = { b, -95 }
	end
	disc(root, 0.5, 1, 3)
	-- the blazing Sun core
	local hole = circle(box(root, 0.5, 0.5, 0.42, 0.42, 6))
	hole.BackgroundColor3 = C(255, 200, 50)
	hole.BackgroundTransparency = 0
	local sunCoreG = Instance.new("UIGradient")
	sunCoreG.Rotation = 45
	sunCoreG.Color = ColorSequence.new(seq(C(255, 252, 200), C(255, 180, 40), C(255, 95, 20)))
	sunCoreG.Parent = hole
	local _, g3 = ring(root, 0.5, 0.5, 0.425, 0.425, 9, seq(C(255, 255, 220), C(255, 200, 70), C(255, 120, 30), C(255, 255, 220)), 0, 7)
	local _, g4 = ring(root, 0.5, 0.5, 0.47, 0.47, 4, seq(C(255, 230, 120), C(255, 255, 255), C(255, 150, 40), C(255, 230, 120)), 0.25, 7)
	grads[#grads + 1] = { g3, 120 }
	grads[#grads + 1] = { g4, -160 }
	-- front half of the disc: lower half only (passes in front of the hole)
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromScale(0, 0.5)
	clip.Size = UDim2.fromScale(1, 0.5)
	clip.ZIndex = 9
	clip.Parent = root
	disc(clip, 0, 2, 9)
	-- star dust
	local stars = {}
	for i = 1, 34 do
		local s = circle(box(root, math.random(), math.random(), 0.006 + math.random() * 0.006, 0.006 + math.random() * 0.006, 4))
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		stars[i] = { o = s, p = math.random() * 6.28, sp = 1 + math.random() * 3 }
	end
	-- particles spiralling into the hole
	local dots = {}
	for i = 1, 44 do
		local d = circle(box(root, 0.5, 0.5, 0.012, 0.012, 11))
		d.BackgroundColor3 = Color3.fromHSV(0.05 + math.random() * 0.75, 0.55, 1)
		d.BorderSizePixel = 0
		dots[i] = { o = d, a = math.random() * 6.28, r = 0.22 + math.random() * 0.28, v = 0.5 + math.random() * 0.9 }
	end
	-- title: every letter floats on its own wave
	local word = "YADSAN HUB"
	local letters = {}
	local tgroup = box(root, 0.5, 0.5, 1, 1, 20)
	local tscale = Instance.new("UIScale")
	tscale.Parent = tgroup
	for i = 1, #word do
		local ch = word:sub(i, i)
		if ch ~= " " then
			local l = Instance.new("TextLabel")
			l.AnchorPoint = H
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.5 + (i - 5) * 0.088, 0.5)
			l.Size = UDim2.fromScale(0.092, 0.17)
			l.Font = Enum.Font.GothamBlack
			l.Text = ch
			l.TextScaled = true
			l.TextColor3 = Color3.new(1, 1, 1)
			l.ZIndex = 21
			l.Parent = tgroup
			local st = Instance.new("UIStroke")
			st.Thickness = 7
			st.Color = C(60, 20, 150)
			st.Parent = l
			letters[#letters + 1] = { o = l, st = st, i = i }
		end
	end
	local sub = label(root, "TAP TO COPY DISCORD INVITE", Enum.Font.GothamBold, C(210, 190, 255), UDim2.fromScale(0.25, 0.77), UDim2.fromScale(0.5, 0.035))
	sub.ZIndex = 22
	local live = label(root, "SCRIPT USERS ONLINE", Enum.Font.GothamBold, C(150, 160, 255), UDim2.fromScale(0.3, 0.815), UDim2.fromScale(0.4, 0.026))
	live.ZIndex = 22
	-- relativistic jets (top and bottom) + periodic gravity ripple
	local jets = {}
	for i, dir in ipairs({ -1, 1 }) do
		local j = box(root, 0.5, 0.5 + dir * 0.27, 0.035, 0.46, 5)
		j.BackgroundTransparency = 0
		j.BackgroundColor3 = C(255, 255, 255)
		local jg = Instance.new("UIGradient")
		jg.Rotation = 90
		jg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 235, 130)), ColorSequenceKeypoint.new(1, C(255, 130, 35)) })
		jg.Transparency = NumberSequence.new(dir == -1 and { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.6), NumberSequenceKeypoint.new(1, 0.25) } or { NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 1) })
		jg.Parent = j
		jets[i] = j
	end
	local ripples = {}
	for i = 1, 2 do
		local r = circle(box(root, 0.5, 0.5, 0.4, 0.4, 3))
		local rs = Instance.new("UIStroke")
		rs.Thickness = 6
		rs.Color = C(190, 150, 255)
		rs.Transparency = 1
		rs.Parent = r
		ripples[i] = { o = r, s = rs, ph = (i - 1) * 0.5 }
	end
	-- click shockwave
	local shock = circle(box(root, 0.5, 0.5, 0.3, 0.3, 25))
	shock.Visible = false
	local shs = Instance.new("UIStroke")
	shs.Thickness = 14
	shs.Color = C(255, 255, 255)
	shs.Parent = shock
	function f.shockFn()
		shock.Visible = true
		shock.Size = UDim2.fromScale(0.3, 0.3)
		shs.Transparency = 0
		TweenService:Create(shock, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.15, 1.15) }):Play()
		TweenService:Create(shs, TweenInfo.new(0.9), { Transparency = 1 }):Play()
		f.boost = 1
	end
	local nextLive = 0
	function f.tick(t, dt)
		local boost = f.boost or 0
		for _, g in ipairs(grads) do g[1].Rotation = (t * (g[2] * (1 + boost * 3))) % 360 end
		for i, h in ipairs(halos) do
			local k = 1 + math.sin(t * 1.3 + i) * 0.02
			h.Size = UDim2.fromScale(({ 1.0, 0.88, 0.76, 0.64 })[i] * k, ({ 1.0, 0.88, 0.76, 0.64 })[i] * k)
		end
		for _, s in ipairs(stars) do s.o.BackgroundTransparency = 0.25 + (math.sin(t * s.sp + s.p) + 1) * 0.37 end
		for _, d in ipairs(dots) do
			d.a = d.a + dt * d.v * (1.2 + (0.5 - d.r) * 5)
			d.r = d.r - dt * 0.018 * d.v
			if d.r < 0.205 then d.r = 0.5 d.a = math.random() * 6.28 end
			local x, y = math.cos(d.a) * d.r, math.sin(d.a) * d.r * 0.30
			d.o.Position = UDim2.fromScale(0.5 + x, 0.5 + y)
			local behind = y < 0 and math.abs(x) < 0.2
			d.o.Visible = not behind
			local sz = 0.006 + (d.r - 0.2) * 0.03
			d.o.Size = UDim2.fromScale(sz, sz)
		end
		tscale.Scale = 1 + math.sin(t * 1.5) * 0.015 + boost * 0.08
		for _, L in ipairs(letters) do
			local ph = t * 2.2 + L.i * 0.55
			L.o.Position = UDim2.fromScale(0.5 + (L.i - 5) * 0.088, 0.5 + math.sin(ph) * 0.014)
			L.o.Rotation = math.sin(ph * 0.8) * 3
			local hue = 0.74 + math.sin(t * 0.9 + L.i * 0.45) * 0.12
			L.o.TextColor3 = Color3.fromHSV(hue, 0.18 + (math.sin(ph) + 1) * 0.12, 1)
			L.st.Color = Color3.fromHSV(hue, 0.85, 0.55)
			L.st.Thickness = 7 + math.sin(ph) * 2
		end
		for i, j in ipairs(jets) do
			j.Size = UDim2.fromScale(0.03 + math.sin(t * 3 + i) * 0.008 + boost * 0.02, 0.44 + math.sin(t * 1.7 + i * 2) * 0.05 + boost * 0.12)
		end
		for _, r in ipairs(ripples) do
			local p = ((t * 0.16) + r.ph) % 1
			r.o.Size = UDim2.fromScale(0.42 + p * 0.62, 0.42 + p * 0.62)
			r.s.Transparency = 0.35 + p * 0.65
			r.s.Thickness = 7 * (1 - p) + 1
		end
		sub.TextTransparency = 0.15 + (math.sin(t * 2.4) + 1) * 0.2
		if t > nextLive then
			nextLive = t + 2
			pcall(function()
				local HC, M = NovaUI.HubChat, NovaUI.Music
				local n = HC and #HC.allUsers() or 0
				local tr = M and M.state == "playing" and M.queue[M.idx]
				live.Text = ("%d SCRIPT USERS ONLINE"):format(math.max(1, n)) .. (tr and ("  -  NOW PLAYING: " .. tr.title:upper():sub(1, 26)) or "")
			end)
		end
	end
	return f
end

local function staffFace(part, face, who)
	local f = newFace(part, face)
	pcall(function()
		NovaUI.MakeBlackhole(f.bg, 760, { Position = UDim2.fromScale(0.5, 0.36), ParticleCount = 10 })
	end)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.36)
	ring.Size = UDim2.fromScale(0.62, 0.52)
	ring.BackgroundColor3 = Color3.fromRGB(12, 6, 26)
	ring.Parent = f.bg
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = ring
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke")
	rs.Thickness = 12
	rs.Color = Color3.new(1, 1, 1)
	rs.Parent = ring
	local rg = Instance.new("UIGradient")
	rg.Color = ColorSequence.new(who.colA, who.colB)
	rg.Parent = rs
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = who.uid and ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(who.uid) or ""
	img.Parent = ring
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	local nm = label(f.bg, who.name, Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.08, 0.66), UDim2.fromScale(0.84, 0.1))
	nm.TextStrokeTransparency = 0.6
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.79)
	pill.Size = UDim2.fromScale(0.62, 0.12)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = f.bg
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(who.colA, who.colB)
	pg.Parent = pill
	local tl = label(pill, who.title, Enum.Font.GothamBlack, Color3.fromRGB(20, 8, 30), UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.8, 0.76))
	label(f.bg, "Celestial Syndicate", Enum.Font.GothamBold, Color3.fromRGB(150, 130, 190), UDim2.fromScale(0.3, 0.925), UDim2.fromScale(0.4, 0.05))
	f.rg = rg
	f.pg = pg
	f.tscale = Instance.new("UIScale")
	f.tscale.Parent = ring
	return f
end


local function discordFace(part, face)
	local f = newFace(part, face)
	f.bgg.Color = ColorSequence.new(Color3.fromRGB(70, 82, 220), Color3.fromRGB(14, 12, 40))
	pcall(function() NovaUI.MakeBlackhole(f.bg, 200, { Position = UDim2.fromScale(0.1, 0.5), ParticleCount = 6 }) end)
	local mk = label(f.bg, "M", Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.12, 0.6))
	local t = label(f.bg, "JOIN OUR DISCORD", Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.76, 0.45))
	t.TextXAlignment = Enum.TextXAlignment.Left
	local u = label(f.bg, "https://discord.gg/gW65gk7tg   -   tap to copy invite", Enum.Font.GothamBold, Color3.fromRGB(200, 205, 255), UDim2.fromScale(0.2, 0.58), UDim2.fromScale(0.76, 0.28))
	u.TextXAlignment = Enum.TextXAlignment.Left
	return f
end

local function profileFace(part, face)
	local f = newFace(part, face)
	local P = PALETTES[BCFG.pal] or PALETTES[1]
	f.bgg.Color = ColorSequence.new(P.bg1, P.bg2)
	pcall(function() NovaUI.MakeBlackhole(f.bg, 200, { Position = UDim2.fromScale(0.95, 0.5), ParticleCount = 6 }) end)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.fromScale(0.03, 0.5)
	ring.Size = UDim2.fromScale(0.7, 0.72)
	ring.BackgroundColor3 = Color3.fromRGB(12, 6, 26)
	ring.Parent = f.bg
	Instance.new("UIAspectRatioConstraint").Parent = ring
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke")
	rs.Thickness = 6
	rs.Color = Color3.new(1, 1, 1)
	rs.Parent = ring
	local rg = Instance.new("UIGradient")
	rg.Color = ColorSequence.new(P.a, P.b)
	rg.Parent = rs
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(lp.UserId)
	img.Parent = ring
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	local lv, frac = Profile.level()
	local n = label(f.bg, BCFG.title ~= "" and BCFG.title or tostring(lp.DisplayName), Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.27, 0.04), UDim2.fromScale(0.5, 0.24))
	n.TextXAlignment = Enum.TextXAlignment.Left
	local pill = Instance.new("Frame")
	pill.Position = UDim2.fromScale(0.79, 0.1)
	pill.Size = UDim2.fromScale(0.18, 0.22)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = f.bg
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(P.a, P.b)
	pg.Parent = pill
	label(pill, "LV " .. lv, Enum.Font.GothamBlack, Color3.fromRGB(20, 8, 30), UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.8, 0.76))
	local a = label(f.bg, "Account created  " .. Profile.joined() .. "  (" .. Profile.age() .. " days old)", Enum.Font.GothamMedium, Color3.fromRGB(210, 190, 255), UDim2.fromScale(0.27, 0.3), UDim2.fromScale(0.7, 0.16))
	a.TextXAlignment = Enum.TextXAlignment.Left
	local d = label(f.bg, Profile.days .. " days with YADSAN HUB  -  " .. math.floor((Profile.minutes or 0) / 60) .. "h played", Enum.Font.GothamMedium, Color3.fromRGB(160, 140, 200), UDim2.fromScale(0.27, 0.48), UDim2.fromScale(0.7, 0.14))
	d.TextXAlignment = Enum.TextXAlignment.Left
	if BCFG.tag ~= "" then
		local tg = label(f.bg, '"' .. BCFG.tag .. '"', Enum.Font.GothamBold, P.a, UDim2.fromScale(0.27, 0.64), UDim2.fromScale(0.7, 0.16))
		tg.TextXAlignment = Enum.TextXAlignment.Left
	end
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.27, 0.86)
	bar.Size = UDim2.fromScale(0.7, 0.07)
	bar.BackgroundColor3 = Color3.fromRGB(30, 18, 55)
	bar.Parent = f.bg
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.max(frac, 0.03), 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(P.a, P.b)
	fg.Parent = fill
	f.rg = rg
	return f
end

-- tap / click effect: a blackhole opens on the panel and vanishes after 2 seconds
local function burst(f)
	if f.shockFn then pcall(f.shockFn) return end
	if f.holeBox and f.holeBox.Parent then return end
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = 18
	box.Parent = f.bg
	local sc = Instance.new("UIScale")
	sc.Scale = 0.02
	sc.Parent = box
	f.holeBox = box
	local sz = math.clamp(f.bg.AbsoluteSize.Y * 0.95, 180, 620)
	local ok, hold, api = pcall(function()
		return NovaUI.MakeBlackhole(box, sz, { Position = UDim2.fromScale(0.5, 0.5), ParticleCount = 14 })
	end)
	if ok and api then pcall(function() api.Boost(1.5) end) end
	TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.5, function()
		if box.Parent then
			TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.02 }):Play()
		end
	end)
	task.delay(2.05, function() box:Destroy() end)
	if f.tscale then
		f.tscale.Scale = 1.12
		TweenService:Create(f.tscale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	f.boost = 1
end

local faces = {}
local function destroy()
	if conn then conn:Disconnect() conn = nil end
	for _, p in ipairs(parts) do p.part:Destroy() end
	parts, faces = {}, {}
end

local function makePart(size, cf, builder, amp, refW, onClick)
	local part = Instance.new("Part")
	part.Name = "YadsanSpawnBanner"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(10, 5, 22)
	part.Size = size
	part:SetAttribute("refW", refW)
	part.CFrame = cf
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 80, 255)
	light.Range = 40
	light.Brightness = 2
	light.Parent = part
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 400
	cd.Parent = part
	local fs = { builder(part, Enum.NormalId.Front), builder(part, Enum.NormalId.Back) }
	for _, f in ipairs(fs) do faces[#faces + 1] = f end
	cd.MouseClick:Connect(function()
		pcall(function() NovaUI.Sound("burst", 0.45, 3, true) end)
		for _, f in ipairs(fs) do burst(f) end
		light.Brightness = 8
		if onClick then pcall(onClick) end
	end)
	do
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 5
		pe.Lifetime = NumberRange.new(1.5, 2.6)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Color = ColorSequence.new(Color3.fromRGB(190, 140, 255), Color3.fromRGB(140, 200, 255))
		pe.Parent = part
		local full = size
		part.Size = size * 0.05
		task.delay(0.15 * #parts, function()
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full }):Play()
			end
		end)
		task.delay(0.15 * #parts + 2, function()
			if part.Parent then part.Size = full end
		end)
	end
	part.Parent = workspace
	parts[#parts + 1] = { part = part, cf = cf, amp = amp, light = light }
end

-- how far a ray from the spawn runs before it hits something solid-looking (see-through parts are skipped)
local function clearDist(origin, dir, maxD)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { lp.Character }
	for _, p in ipairs(parts) do ign[#ign + 1] = p.part end
	rp.FilterDescendantsInstances = ign
	local o, left = origin, maxD
	for _ = 1, 6 do
		local r = workspace:Raycast(o, dir * left, rp)
		if not r then return maxD end
		if r.Instance.Transparency < 0.9 and r.Instance.CanCollide then
			return maxD - left + r.Distance
		end
		ign[#ign + 1] = r.Instance
		rp.FilterDescendantsInstances = ign
		o, left = r.Position, left - r.Distance
		if left <= 1 then return maxD end
	end
	return maxD
end

local BANNER_SIZE = Vector3.new(36, 36, 0.4)
-- true when a banner box at cf touches visible parts (trees, walls, buildings) - ground right under it is ignored
local function boxBlocked(cf, floorY)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { lp.Character }
	for _, p in ipairs(parts) do ign[#ign + 1] = p.part end
	op.FilterDescendantsInstances = ign
	local hits = workspace:GetPartBoundsInBox(cf, BANNER_SIZE + Vector3.new(2, 2, 10), op)
	for _, h in ipairs(hits) do
		if h.Transparency < 0.9 and (h.Position.Y + h.Size.Y / 2) > floorY + 3 then return true end
	end
	return false
end
-- nothing solid/visible between the spawn and the banner
local function sightClear(from, to)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { lp.Character }
	for _, p in ipairs(parts) do ign[#ign + 1] = p.part end
	rp.FilterDescendantsInstances = ign
	local o = from
	for _ = 1, 6 do
		local r = workspace:Raycast(o, to - o, rp)
		if not r then return true end
		if r.Instance.Transparency < 0.9 then return false end
		ign[#ign + 1] = r.Instance
		rp.FilterDescendantsInstances = ign
		o = r.Position
	end
	return true
end

local function create(floor, look)
	destroy()
	if not floor then floor, look = findSpawnCF() end
	if not floor then return false end
	local up = Vector3.new(0, 1, 0)
	local right = look:Cross(up).Unit
	-- search for a spot where the big banner is not inside a tree/building and can be seen from the spawn
	local best, bestDist, bestDeg
	local eye = floor + up * 6
	for _, h in ipairs({ 22, 26, 31, 38 }) do
		for _, d in ipairs({ 42, 36, 30, 24 }) do
			for _, deg in ipairs({ 0, 25, -25, 50, -50, 80, -80, 115, -115, 180 }) do
				local rad = math.rad(deg)
				local dv = (look * math.cos(rad) + right * math.sin(rad)).Unit
				local pos = floor + dv * d + up * h
				local cf = CFrame.lookAt(pos, Vector3.new(floor.X, pos.Y, floor.Z))
				if not boxBlocked(cf, floor.Y) and sightClear(eye, pos) then
					best, bestDist, bestDeg = cf, d, deg
					break
				end
			end
			if best then break end
		end
		if best then break end
	end
	if not best then
		local pos = floor + look * 40 + up * 28
		best, bestDist, bestDeg = CFrame.lookAt(pos, Vector3.new(floor.X, pos.Y, floor.Z)), 40, 0
	end
	base = best
	local dist, lookDeg = bestDist, bestDeg
	local ok, e = pcall(makePart, BANNER_SIZE, base, holeFace, 0.6, 36, copyDiscord)
	if not ok then notify("Spawn banner", "panel error: " .. tostring(e)) end
	NovaUI.BannerInfo = ('banner %d studs from spawn at %d deg'):format(dist, lookDeg)
	local t0 = os.clock()
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		for i, p in ipairs(parts) do
			if p.part.Parent then
				p.part.CFrame = p.cf * CFrame.new(0, math.sin(t * 0.9 + i) * p.amp, 0) * CFrame.Angles(0, 0, math.sin(t * 0.5 + i) * 0.006)
				p.light.Brightness = math.max(2 + math.sin(t * 2) * 0.6, p.light.Brightness - dt * 14)
			end
		end
		for _, f in ipairs(faces) do
			f.bgg.Rotation = 35 + math.sin(t * 0.4) * 25
			f.boost = math.max(0, (f.boost or 0) - dt * 1.2)
			if f.tick then f.tick(t, dt) end
			f.sg2.Rotation = (t * (80 + (f.boost or 0) * 700)) % 360
			if f.live and f.live.Parent and (f.liveT or 0) < t then
				f.liveT = t + 2
				pcall(function()
					local HC, M = NovaUI.HubChat, NovaUI.Music
					local n = HC and #HC.allUsers() or 0
					local tr = M and M.state == "playing" and M.queue[M.idx]
					f.live.Text = ("%d SCRIPT USERS ONLINE"):format(math.max(1, n)) .. (tr and ("   -   NOW PLAYING: " .. tr.title:upper():sub(1, 28)) or "   -   LIFE TOGETHER RP")
				end)
			end
			if f.tscale then f.tscale.Scale = 1 + math.sin(t * 1.6) * 0.018 end
			if f.shine and f.shine.Parent then f.shine.Position = UDim2.fromScale(-0.2 + ((t * 0.22) % 1.6), 0.5) end
			if f.tg then f.tg.Offset = Vector2.new(math.sin(t * 1.2) * 0.35, 0) end
			if f.rg then f.rg.Rotation = (t * 120) % 360 end
		end
	end)
	return true
end

local ProfTab = Window:CreateTab({ Name = "Profile", Icon = "user" })
NovaUI.ProfTab = ProfTab
local pS = ProfTab:Section({ Title = "Your Profile Yadsan X Yakuza", Icon = "👤", Side = "Left" })
local pLbl = pS:Label("...")
local function pRefresh()
	local lv, frac, xp, nxt = Profile.level()
	pLbl:Set(("%s (@%s)\nLevel %d  -  %d / %d XP\nAccount created: %s (%d days old)\nDays with YADSAN HUB: %d  -  streak %d (best %d)  -  time used: %dh %dm\nFits copied: %d  -  fits saved: %d  -  messages: %d\nFirst use: %s\n\n%s"):format(lp.DisplayName, lp.Name, lv, xp, nxt, Profile.joined(), Profile.age(), Profile.days or 0, Profile.streak or 1, Profile.best or 1, math.floor((Profile.minutes or 0) / 60), (Profile.minutes or 0) % 60, Profile.copies or 0, Profile.saves or 0, Profile.msgs or 0, os.date("%d %b %Y", Profile.first), Profile.achievements()))
end
pRefresh()
task.spawn(function() while true do task.wait(30) pcall(pRefresh) end end)
pS:Paragraph({ Title = "How levels work", Content = "+25 XP the first time you open the hub each day, +1 XP for every minute you use it. Everything (profile, fits, chat history, app theme) is stored in your executor's YADSAN_HUB folder." })
local dS = ProfTab:Section({ Title = "Community", Icon = "chat", Side = "Right" })
local bS = ProfTab:Section({ Title = "My banner", Icon = "star", Side = "Left" })
local function rebuildBanners()
	bcfgSave()
	if NovaUI.SpawnBanner then NovaUI.SpawnBanner.Set(false) NovaUI.SpawnBanner.Set(true) end
end
bS:Paragraph({ Title = "Make it yours", Content = "Your profile banner (below the spawn banner) can have your own title, a tagline and a colour style. Saved in YADSAN_HUB/banner.json." })
local bTitle = bS:Input({ Placeholder = "Banner title (empty = display name)", Callback = function(t) BCFG.title = tostring(t or ""):sub(1, 24) rebuildBanners() end })
local bTag = bS:Input({ Placeholder = "Tagline, e.g. Life RP legend", Callback = function(t) BCFG.tag = tostring(t or ""):sub(1, 40) rebuildBanners() end })
for i, p in ipairs(PALETTES) do
	bS:Button({ Title = "Style: " .. p.name, Callback = function() BCFG.pal = i rebuildBanners() end })
end
dS:Button({ Title = "Copy Discord invite", Style = "Primary", Callback = copyDiscord })
dS:Button({ Title = "Rebuild spawn banners", Callback = function() if NovaUI.SpawnBanner then NovaUI.SpawnBanner.Set(false) NovaUI.SpawnBanner.Set(true) end end })

-- resolve the staff avatars by username (no ids hard coded)
task.spawn(function()
	for _, who in ipairs(STAFF) do
		local ok, id = pcall(function() return PLAYERS:GetUserIdFromNameAsync(who.name) end)
		if ok and type(id) == "number" then who.uid = id end
	end
end)

NovaUI.SpawnBanner = {
	Set = function(on)
		if on then
			if #parts == 0 then create() end
		else
			destroy()
		end
	end,
	PlaceHere = function()
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not root then return false end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
		return create(Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z), look.Unit)
	end,
}
task.spawn(function()
	local w = 0
	while not (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")) and w < 20 do
		task.wait(0.5)
		w = w + 0.5
	end
	while NovaUI.HoldOpen do task.wait(0.3) end
	-- wait a moment for the staff avatars to resolve
	local t = 0
	while t < 4 and not (STAFF[1].uid and STAFF[2].uid) do task.wait(0.2) t = t + 0.2 end
	if NovaUI.SpawnBannerOn ~= false then
		local ok, err = pcall(create)
		if not ok then notify("Spawn banner", "Could not build: " .. tostring(err)) end
		if ok then
			local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			local n, d = 0, nil
			for _, p in ipairs(parts) do
				n = n + 1
				if root then d = d or (p.part.Position - root.Position).Magnitude end
			end
			notify("Spawn banner", ("%d panels built%s"):format(n, d and (", main one " .. math.floor(d) .. " studs from you") or ""))
		end
		if ok and NovaUI.BannerDist and NovaUI.BannerDist > 60 then
			notify("Spawn banner", ("Banner is at the spawn, %d studs from you. Settings > 'Put banner in front of me' brings it here."):format(NovaUI.BannerDist))
		end
	end
end)

-- ===== staff tools: user list (staff only) and the script ban list =====
-- BAN LIST: the owner puts the raw link of a text file here (one userId or username per line, # = comment).
-- Anyone listed is shut out of the hub when it starts. This is checked by the script itself, so it only stops
-- people running the unmodified script; it cannot kick anyone from the Roblox server.
local BANLIST_URL = ""
local HC = NovaUI.HubChat
local myStaff = HC and HC.STAFF[lp.Name:lower()]
task.spawn(function()
	while true do
	if BANLIST_URL == "" or myStaff or NovaUI.Banned then return end
	local ok, body = pcall(function() return game:HttpGet(BANLIST_URL) end)
	if ok then
	for line in tostring(body):gsub("#[^\r\n]*", ""):gmatch("[^\r\n]+") do
		local id = line:match("^%s*(%d+)")
		local nm = line:match("^%s*([%w_]+)%s*$")
		if (id and tonumber(id) == lp.UserId) or (nm and nm:lower() == lp.Name:lower()) then
			NovaUI.Banned = true
			notify("YADSAN HUB", "You are banned from using this script.")
			pcall(function() NovaUI.SpawnBanner.Set(false) end)
			pcall(function() NovaUI._window:Destroy() end)
			return
		end
	end
	end
	task.wait(300)
	end
end)
if myStaff then
	local SW = Window:CreateTab({ Name = "Staff", Icon = "star" })
	local sl = SW:Section({ Title = "Celestial Godverse users online", Icon = "👤", Side = "Left" })
	local lbl = sl:Label("loading...")
	local function refresh()
		local list = HC.allUsers()
		local out = { #list .. " users seen in the last 40 min" }
		for i, u in ipairs(list) do
			if i > 40 then break end
			out[#out + 1] = ("%s (@%s)  id %s  %s  %dm ago"):format(u.d, u.n, tostring(u.u or "?"), (u.s == game.JobId) and "[your server]" or "[other server]", math.floor((os.time() - u.t) / 60))
		end
		lbl:Set(table.concat(out, "\n"))
	end
	refresh()
	task.spawn(function() while true do task.wait(20) pcall(refresh) end end)
	local function exportUsers()
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			local t = {}
			for _, u in ipairs(HC.allUsers()) do t[#t + 1] = { name = u.n, display = u.d, id = u.u, server = u.s, seen = u.t } end
			writefile("YADSAN_HUB/staff_users.json", HttpService:JSONEncode(t))
		end)
	end
	task.spawn(function() while true do task.wait(60) exportUsers() end end)
	local ps = SW:Section({ Title = "Staff powers", Icon = "⭐", Side = "Right" })
	ps:Paragraph({ Title = "Announce / mute", Content = "Announcement pops up for every YADSAN HUB user with a sound and lands in Global chat. Mute stops a user's messages in Hub Chat for everyone (unmute undoes it). Both only work from owner/admin accounts." })
	local annBox = ps:Input({ Placeholder = "Announcement text" })
	ps:Button({ Title = "Send announcement", Style = "Primary", Callback = function()
		local ok = HC.announce(annBox:Get())
		notify("Staff", ok and "Announcement sent" or "Could not send (empty text or slow down)")
	end })
	local muteBox = ps:Input({ Placeholder = "Roblox username to mute / unmute" })
	ps:Button({ Title = "Mute in Hub Chat", Callback = function()
		local n = tostring(muteBox:Get() or "")
		if HC.STAFF[n:lower()] then notify("Staff", "You cannot mute staff") return end
		notify("Staff", HC.mute(n, true) and (n .. " muted") or "Type a username first")
	end })
	ps:Button({ Title = "Unmute", Callback = function()
		notify("Staff", HC.mute(muteBox:Get(), false) and "Unmuted" or "Type a username first")
	end })
	ps:Button({ Title = "Copy user list to clipboard", Callback = function()
		local t = {}
		for _, u in ipairs(HC.allUsers()) do t[#t + 1] = ("%s (@%s) id %s"):format(u.d, u.n, tostring(u.u or "?")) end
		pcall(setclipboard, table.concat(t, "\n"))
		notify("Staff", #t .. " users copied")
	end })
	sl:Button({ Title = "Refresh now", Callback = function() pcall(HC.poll) refresh() end })
	sl:Button({ Title = "Copy ban-list lines (id # name)", Style = "Primary", Callback = function()
		local t = {}
		for _, u in ipairs(HC.allUsers()) do
			if not HC.STAFF[u.n:lower()] and u.u then t[#t + 1] = u.u .. "  # " .. u.n end
		end
		pcall(function() setclipboard(table.concat(t, "\n")) end)
		notify("Staff", "Copied. Paste the lines you want banned into your ban-list file.")
	end })
	local BL = "YADSAN_HUB/banlist.txt"
	local bl = SW:Section({ Title = "Ban list file", Icon = "⚙️", Side = "Left" })
	bl:Input({ Placeholder = "userId or username to add (Enter)", Callback = function(t)
		t = tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if t == "" then return end
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			local old = (isfile and isfile(BL)) and readfile(BL) or ""
			writefile(BL, old .. (old ~= "" and "\n" or "") .. t)
		end)
		notify("Staff", "Added to " .. BL)
	end })
	bl:Button({ Title = "Copy ban list file", Callback = function()
		local ok, body = pcall(function() return (isfile and isfile(BL)) and readfile(BL) or "" end)
		pcall(function() setclipboard(ok and body or "") end)
		notify("Staff", "Ban list copied. Upload it and put the raw link in BANLIST_URL.")
	end })
	local sh = SW:Section({ Title = "How banning works", Icon = "settings", Side = "Right" })
	sh:Paragraph({ Title = "Ban from the script", Content = "Put the ids you want banned in a text file online (one per line) and set BANLIST_URL at the top of the Staff block in this script to its raw link. Banned users are locked out when they start the hub. The script cannot kick anyone from the Roblox server." })
end
end)()


-- hub preferences are remembered in the executor folder (YADSAN_HUB/settings.json)
do
	local SF = "YADSAN_HUB/settings.json"
	local keys = { "Haptics", "UISounds", "UIAnim", "BGBlur", "SpawnBanner", "Ambient" }
	task.spawn(function()
		task.wait(4)
		pcall(function()
			if isfile and isfile(SF) then
				local d = HttpService:JSONDecode(readfile(SF))
				for _, k in ipairs(keys) do
					if type(d[k]) == "boolean" and Window._setters[k] and NovaUI.Flags[k] ~= d[k] then
						pcall(Window._setters[k], d[k])
					end
				end
			end
		end)
		local last = ""
		while true do
			task.wait(10)
			local t = {}
			for _, k in ipairs(keys) do t[k] = NovaUI.Flags[k] end
			local ok, enc = pcall(function() return HttpService:JSONEncode(t) end)
			if ok and enc ~= last then
				last = enc
				pcall(function()
					pcall(makefolder, "YADSAN_HUB")
					writefile(SF, enc)
				end)
			end
		end
	end)
end


-- RGB "YADSAN HUB" sign: you aim at the exact spot (e.g. the middle tube of the playground) and place it there.
-- Saved in YADSAN_HUB/sign.json and restored every time the script runs.
task.spawn(function()
	local RS = game:GetService("RunService")
	local HS = game:GetService("HttpService")
	local FILE = "YADSAN_HUB/sign.json"
	local S = { has = false, px = 0, py = 0, pz = 0, nx = 0, ny = 0, nz = 1, w = 16, roll = 0, off = 0.12 }
	pcall(function()
		if isfile and isfile(FILE) then
			local d = HS:JSONDecode(readfile(FILE))
			for k in pairs(S) do if d[k] ~= nil then S[k] = d[k] end end
		end
	end)
	local function save()
		pcall(function()
			if makefolder and not (isfolder and isfolder("YADSAN_HUB")) then makefolder("YADSAN_HUB") end
			writefile(FILE, HS:JSONEncode(S))
		end)
	end
	-- remove any older sign (the swing one)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "YadsanSwingSign" or d.Name == "YadsanRgbSign" then pcall(function() d:Destroy() end) end
	end
	local part, grad
	local function clear()
		if part then pcall(function() part:Destroy() end) end
		part, grad = nil, nil
	end
	local function build()
		clear()
		if not S.has then return end
		local pos, n = Vector3.new(S.px, S.py, S.pz), Vector3.new(S.nx, S.ny, S.nz)
		if n.Magnitude < 0.1 then n = Vector3.new(0, 0, 1) end
		n = n.Unit
		local p = Instance.new("Part")
		p.Name = "YadsanRgbSign"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(S.w, S.w * 0.26, 0.1)
		p.CFrame = CFrame.lookAt(pos + n * S.off, pos + n * (S.off + 1)) * CFrame.Angles(0, 0, math.rad(S.roll))
		p.Parent = workspace
		part = p
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = Instance.new("SurfaceGui")
			sg.Face = face
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 60
			sg.LightInfluence = 0
			sg.Brightness = 2
			sg.AlwaysOnTop = false
			sg.MaxDistance = 400
			sg.Parent = p
			local plate = Instance.new("Frame")
			plate.Size = UDim2.fromScale(1, 1)
			plate.BackgroundColor3 = Color3.fromRGB(6, 4, 16)
			plate.BackgroundTransparency = 0.45
			plate.BorderSizePixel = 0
			plate.Parent = sg
			local uc = Instance.new("UICorner")
			uc.CornerRadius = UDim.new(0.22, 0)
			uc.Parent = plate
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = Color3.new(1, 1, 1)
			st.Parent = plate
			local sgr = Instance.new("UIGradient")
			local k = {}
			for i = 0, 6 do k[#k + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i % 6 / 6, 0.9, 1)) end
			k[#k] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 0.9, 1))
			sgr.Color = ColorSequence.new(k)
			sgr.Parent = st
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.92, 0.7)
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromScale(0.5, 0.5)
			t.Text = "YADSAN X YAKUZA"
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1)
			t.Parent = plate
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(k)
			g.Parent = t
			if face == Enum.NormalId.Front then grad = { g, sgr } end
			p:SetAttribute("n", (p:GetAttribute("n") or 0) + 1)
			if face == Enum.NormalId.Back then grad[3], grad[4] = g, sgr end
		end
	end
	RS.Heartbeat:Connect(function()
		if part and part.Parent and grad then
			local t = os.clock()
			local off = Vector2.new((t * 0.4) % 2 - 1, 0)
			grad[1].Offset = off
			if grad[3] then grad[3].Offset = off end
			local r = (t * 90) % 360
			grad[2].Rotation = r
			if grad[4] then grad[4].Rotation = r end
		elseif S.has and not (part and part.Parent) then
			-- streamed out / destroyed: rebuild now and then
			if (S._t or 0) < os.clock() then S._t = os.clock() + 5 build() end
		end
	end)
	build()
	if not S.has then
		task.delay(12, function()
			if not S.has then notify("RGB sign", "Go next to the middle tube, look at it, then tap the M button > 'Sign here'.") end
		end)
	end

	local function aimHit()
		local cam = workspace.CurrentCamera
		if not cam then return nil end
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local ex = {}
		if lp.Character then ex[#ex + 1] = lp.Character end
		if part then ex[#ex + 1] = part end
		rp.FilterDescendantsInstances = ex
		return workspace:Raycast(ray.Origin, ray.Direction * 400, rp)
	end
	local function placeAim()
		local hit = aimHit()
		if not hit then notify("Sign", "Nothing under the crosshair. Look at the tube from close and try again.") return end
		S.has = true
		S.px, S.py, S.pz = hit.Position.X, hit.Position.Y, hit.Position.Z
		S.nx, S.ny, S.nz = hit.Normal.X, hit.Normal.Y, hit.Normal.Z
		S.roll = 0
		build() save()
		notify("Sign", "Celestial sign placed on " .. hit.Instance.Name .. ". Adjust with Bigger / Smaller / Rotate / Out / In.")
	end
	-- first guess: nearest tube / tunnel / pipe shaped part around you
	local function placeNearest()
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local best, bd
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "YadsanRgbSign" then
				local nm = d.Name:lower()
				local pn = d.Parent and d.Parent.Name:lower() or ""
				local c = d.Color
				local big = math.max(d.Size.X, d.Size.Y, d.Size.Z) > 6
				local blue = c.B > c.R + 0.2 and c.B >= c.G
				local orange = c.R > 0.78 and c.G > 0.3 and c.G < 0.68 and c.B < 0.35
				if nm:find("tube") or nm:find("tunnel") or nm:find("pipe") or pn:find("tube") or pn:find("tunnel") or (big and d.CanCollide and (blue or orange)) then
					local dist = (d.Position - root.Position).Magnitude
					if dist < 150 and (not bd or dist < bd) then best, bd = d, dist end
				end
			end
		end
		if not best then notify("Sign", "No tube found by name. Use 'Place sign where I look' instead.") return end
		local toMe = root.Position - best.Position
		local dir = best.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local pick = Vector3.new(0, 0, 1)
		for _, v in ipairs({ best.CFrame.RightVector, -best.CFrame.RightVector, best.CFrame.LookVector, -best.CFrame.LookVector }) do
			if v:Dot(toMe) > pick:Dot(toMe) or pick == Vector3.new(0, 0, 1) then if math.abs(v.Y) < 0.5 then pick = v end end
		end
		local half = math.max(best.Size.X, best.Size.Z) / 2
		S.has = true
		S.px, S.py, S.pz = best.Position.X + pick.X * half, best.Position.Y, best.Position.Z + pick.Z * half
		S.nx, S.ny, S.nz = pick.X, 0, pick.Z
		build() save()
		notify("Sign", "Sign placed on " .. best.Name .. ". Not right? Look at the tube and press 'Place sign where I look'.")
	end
	local ProfTab = NovaUI.ProfTab
	NovaUI.PlaceSign = placeAim
	local sS = ProfTab:Section({ Title = "RGB Celestial sign", Icon = "⭐", Side = "Right" })
	sS:Paragraph({ Title = "Put it exactly on the tube", Content = "Stand near the blue/orange middle tube, point the camera so the crosshair (screen centre) is on the tube, then press Place. Saved for next time." })
	sS:Button({ Title = "Place sign where I look", Style = "Primary", Callback = placeAim })
	sS:Button({ Title = "Auto-guess nearest tube", Callback = placeNearest })
	sS:Button({ Title = "Bigger", Callback = function() if S.has then S.w = math.min(60, S.w * 1.15) build() save() end end })
	sS:Button({ Title = "Smaller", Callback = function() if S.has then S.w = math.max(3, S.w / 1.15) build() save() end end })
	sS:Button({ Title = "Rotate 90 degrees", Callback = function() if S.has then S.roll = (S.roll + 90) % 360 build() save() end end })
	sS:Button({ Title = "Move out", Callback = function() if S.has then S.off = S.off + 0.15 build() save() end end })
	sS:Button({ Title = "Move in", Callback = function() if S.has then S.off = math.max(0.02, S.off - 0.15) build() save() end end })
	sS:Button({ Title = "Remove sign", Callback = function() S.has = false clear() save() notify("Sign", "Sign removed.") end })
	defCmd("sign", "sign", "Place the RGB sign where you look", function() placeAim() return "sign" end)
end)

-- floating launcher: always-available way to open the apps + music controls (works even if the phone icons are hidden)
task.spawn(function()
	task.wait(3)
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")
	local RS = game:GetService("RunService")
	local gui = Instance.new("ScreenGui")
	gui.Name = "YadsanLauncher"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = Window.Gui.Parent
	local function mk(c, p, par)
		local o = Instance.new(c)
		for k, v in pairs(p) do o[k] = v end
		o.Parent = par
		return o
	end
	local function corner(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
	local pos0 = UDim2.new(0, 10, 0.5, -20)
	local FS = 46
	local fab = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(FS, FS), Position = pos0 }, gui)
	local fcore = mk("Frame", { BackgroundColor3 = Color3.fromRGB(255, 195, 50), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(FS, FS) }, fab)
	corner(fcore, FS)
	local function fring(size, thick, cols, tr)
		local r = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size) }, fcore)
		corner(r, 200)
		local st = mk("UIStroke", { Thickness = thick, Color = Color3.new(1, 1, 1), Transparency = tr or 0 }, r)
		return mk("UIGradient", { Color = cols }, st)
	end
	local function fseq(...)
		local t, n = {}, select("#", ...)
		for i = 1, n do t[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), (select(i, ...))) end
		return ColorSequence.new(t)
	end
	local fg1 = fring(1.0, 3, fseq(Color3.fromRGB(120, 210, 255), Color3.fromRGB(180, 90, 255), Color3.fromRGB(255, 170, 110), Color3.fromRGB(120, 210, 255)))
	local fg2 = fring(0.72, 2, fseq(Color3.new(1, 1, 1), Color3.fromRGB(110, 60, 220), Color3.new(1, 1, 1)), 0.3)
	local fhole = mk("Frame", { BackgroundColor3 = Color3.fromRGB(255, 240, 145), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.58) }, fcore)
	corner(fhole, 100)
	local fm = mk("TextLabel", { BackgroundTransparency = 1, Text = "M", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 5 }, fcore)
	mk("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(130, 70, 240) }, fm)
	local fdisc = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.45, 0.28), ZIndex = 4 }, fcore)
	corner(fdisc, 40)
	local fds = mk("UIStroke", { Thickness = 2.5, Color = Color3.new(1, 1, 1), Transparency = 0.15 }, fdisc)
	local fgd = mk("UIGradient", { Color = fseq(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 110, 70), Color3.fromRGB(190, 80, 255), Color3.fromRGB(255, 230, 160)) }, fds)
	local panel = mk("Frame", { BackgroundColor3 = Color3.fromRGB(14, 10, 28), BackgroundTransparency = 0.08, Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, BorderSizePixel = 0 }, gui)
	corner(panel, 14)
	mk("UIStroke", { Color = Color3.fromRGB(150, 100, 240), Thickness = 1.5, Transparency = 0.3 }, panel)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	local function row(h, order)
		return mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = order }, panel)
	end
	local function button(par, text, size, pos, fn, accent)
		local b = mk("TextButton", { Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, BackgroundColor3 = accent and Color3.fromRGB(110, 60, 220) or Color3.fromRGB(38, 28, 66), Size = size, Position = pos, BorderSizePixel = 0 }, par)
		corner(b, 9)
		b.MouseButton1Click:Connect(function() pcall(fn) end)
		return b
	end
	local function openApp(i)
		local apps = NovaUI.PhoneApps
		if apps and apps[i] then
			panel.Visible = false
			apps[i].open()
		end
	end
	local r1 = row(30, 1)
	button(r1, "Chat", UDim2.new(0.33, -3, 1, 0), UDim2.fromScale(0, 0), function() openApp(1) end)
	button(r1, "Fits", UDim2.new(0.33, -3, 1, 0), UDim2.fromScale(0.335, 0), function() openApp(2) end)
	button(r1, "Music", UDim2.new(0.33, -3, 1, 0), UDim2.fromScale(0.67, 0), function() openApp(3) end, true)
	local song = mk("TextLabel", { BackgroundTransparency = 1, Text = "Nothing playing", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(200, 180, 255), TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 }, panel)
	local r2 = row(30, 3)
	button(r2, "<<", UDim2.new(0.25, -3, 1, 0), UDim2.fromScale(0, 0), function() NovaUI.Music.step(-1) end)
	local pp = button(r2, "Play", UDim2.new(0.5, -3, 1, 0), UDim2.fromScale(0.25, 0), function() NovaUI.Music.toggle() end, true)
	button(r2, ">>", UDim2.new(0.25, -3, 1, 0), UDim2.fromScale(0.75, 0), function() NovaUI.Music.step(1) end)
	local r3 = row(30, 4)
	button(r3, "Random fit", UDim2.new(0.5, -3, 1, 0), UDim2.fromScale(0, 0), function()
		local FS = NovaUI.FitStore
		local names = FS and FS.names() or {}
		if #names == 0 then notify("Fit Saver", "No saved fits yet") return end
		local n = names[math.random(1, #names)]
		notify("Fit Saver", "Wearing " .. n .. "...")
		task.spawn(function() FS.wear(n) end)
	end)
	button(r3, "Sign here", UDim2.new(0.5, -3, 1, 0), UDim2.fromScale(0.5, 0), function() if NovaUI.PlaceSign then NovaUI.PlaceSign() end end)
	-- open / close + drag
	local dragging, moved, startIn, startPos = false, false, nil, nil
	fab.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, startIn, startPos = true, false, i.Position, fab.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then moved = true end
			if moved then fab.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then panel.Visible = not panel.Visible end
		end
	end)
	RS.Heartbeat:Connect(function()
		panel.Position = UDim2.new(fab.Position.X.Scale, fab.Position.X.Offset + 52, fab.Position.Y.Scale, fab.Position.Y.Offset)
		local sp = os.clock() * 110
		fg1.Rotation, fg2.Rotation, fgd.Rotation = sp % 360, (-sp * 1.5) % 360, (sp * 0.6) % 360
		local pz = 1 + math.sin(os.clock() * 2.2) * 0.03
		fcore.Size = UDim2.fromOffset(FS * pz, FS * pz)
		if panel.Visible then
			local M = NovaUI.Music
			local t = M and M.queue[M.idx]
			song.Text = t and (t.title .. " - " .. t.artist) or "Nothing playing"
			pp.Text = (M and M.state == "playing") and "Pause" or "Play"
		end
	end)
end)

-- ===== floating MUSIC black hole button + standalone music window (search, categories, play) =====
task.spawn(function()
	task.wait(3.5)
	local UIS = game:GetService("UserInputService")
	local RS = game:GetService("RunService")
	local TS = game:GetService("TweenService")
	local C = Color3.fromRGB
	local gui = Instance.new("ScreenGui")
	gui.Name = "YadsanMusicWin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 52
	gui.Parent = Window.Gui.Parent
	local function mk(c, p, par)
		local o = Instance.new(c)
		for k, v in pairs(p) do o[k] = v end
		o.Parent = par
		return o
	end
	local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
	local function seq(...)
		local t, n = {}, select("#", ...)
		for i = 1, n do t[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), (select(i, ...))) end
		return ColorSequence.new(t)
	end
	local function label(par, text, size, col, font, props)
		local p = { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = col, Font = font or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left }
		for k, v in pairs(props or {}) do p[k] = v end
		return mk("TextLabel", p, par)
	end
	local function button(par, text, props, accent)
		local p = { Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, BackgroundColor3 = accent and C(112, 60, 225) or C(38, 28, 66), BorderSizePixel = 0 }
		for k, v in pairs(props or {}) do p[k] = v end
		local b = mk("TextButton", p, par)
		corner(b, 10)
		return b
	end
	local vp = gui.AbsoluteSize
	if vp.X < 50 then vp = Vector2.new(800, 400) end
	-- ---------------- floating black hole button ----------------
	local BS = 58
	local fab = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(BS, BS + 14), Position = UDim2.new(0, 8, 0.5, 34) }, gui)
	local core = mk("Frame", { BackgroundColor3 = C(255, 195, 50), BorderSizePixel = 0, Size = UDim2.fromOffset(BS, BS), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0) }, fab)
	corner(core, BS)
	local function ringOn(par, size, thick, cols, tr)
		local r = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size) }, par)
		corner(r, 200)
		local s = mk("UIStroke", { Thickness = thick, Color = Color3.new(1, 1, 1), Transparency = tr or 0 }, r)
		local g = mk("UIGradient", { Color = cols }, s)
		return r, g
	end
	local _, rg1 = ringOn(core, 1.0, 3, seq(C(255, 190, 110), C(190, 90, 255), C(70, 200, 255), C(255, 190, 110)))
	local _, rg2 = ringOn(core, 0.74, 2, seq(C(255, 255, 255), C(120, 60, 220), C(255, 255, 255)), 0.3)
	local hole = mk("Frame", { BackgroundColor3 = C(255, 240, 145), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.58) }, core)
	corner(hole, 100)
	local note = label(core, "~", 22, C(255, 255, 255), Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	mk("UIStroke", { Thickness = 1.5, Color = C(150, 80, 255) }, note)
	local disc = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.45, 0.3), ZIndex = 4 }, core)
	corner(disc, 40)
	local ds = mk("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Transparency = 0.15 }, disc)
	local dg = mk("UIGradient", { Color = seq(C(255, 230, 160), C(255, 110, 70), C(190, 80, 255), C(255, 230, 160)) }, ds)
	local tag = label(fab, "MUSIC", 11, C(255, 255, 255), Enum.Font.GothamBlack, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, BS + 1), TextXAlignment = Enum.TextXAlignment.Center })
	mk("UIStroke", { Thickness = 1.5, Color = C(90, 30, 190) }, tag)

	-- ---------------- window ----------------
	local W = math.min(360, vp.X - 16)
	local H = math.min(450, vp.Y - 16)
	local win = mk("Frame", { BackgroundColor3 = C(11, 8, 22), Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false, BorderSizePixel = 0, ClipsDescendants = true }, gui)
	corner(win, 16)
	mk("UIStroke", { Thickness = 2, Color = C(150, 100, 255), Transparency = 0.25 }, win)
	mk("UIGradient", { Rotation = 90, Color = seq(C(36, 18, 78), C(9, 6, 18)) }, win)
	local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) }, win)
	label(head, "MUSIC", 16, C(255, 255, 255), Enum.Font.GothamBlack, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -60, 1, 0) })
	local closeB = button(head, "X", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(28, 26), TextSize = 12 })
	closeB.MouseButton1Click:Connect(function() win.Visible = false end)
	-- search row
	local sBox = mk("TextBox", { PlaceholderText = "Search any song or artist...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = C(150, 140, 190), BackgroundColor3 = C(28, 20, 52), BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -90, 0, 32) }, win)
	corner(sBox, 16)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8) }, sBox)
	local sGo = button(win, "Search", { Position = UDim2.new(1, -74, 0, 38), Size = UDim2.fromOffset(64, 32), TextSize = 12 }, true)
	corner(sGo, 16)
	-- category chips
	local chipBar = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 34), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X }, win)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, chipBar)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chipBar)
	-- results
	local PLAYER_H = 92
	local resBox = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 1, -(110 + PLAYER_H)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C(150, 100, 255) }, win)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, resBox)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, resBox)
	-- now playing bar
	local bar = mk("Frame", { BackgroundColor3 = C(18, 12, 36), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -PLAYER_H), Size = UDim2.new(1, 0, 0, PLAYER_H) }, win)
	mk("UIStroke", { Thickness = 1, Color = C(150, 100, 255), Transparency = 0.6 }, bar)
	local nArt = mk("ImageLabel", { BackgroundColor3 = C(34, 24, 62), BorderSizePixel = 0, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(40, 40), ScaleType = Enum.ScaleType.Crop }, bar)
	corner(nArt, 8)
	local nTitle = label(bar, "Nothing playing", 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, { Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -140, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local nSub = label(bar, "Pick a song above", 10, C(170, 160, 210), Enum.Font.Gotham, { Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -140, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	-- equalizer visualizer
	local vbars = {}
	for i = 1, 12 do
		local vb = mk("Frame", { BackgroundColor3 = Color3.fromHSV(0.72 + i * 0.012, 0.6, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(1, -78 + (i - 1) * 6, 0, 46), Size = UDim2.fromOffset(4, 4) }, bar)
		corner(vb, 2)
		vbars[i] = { f = vb, ph = math.random() * 6.28, sp = 5 + math.random() * 6 }
	end
	-- seek bar
	local seekBg = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C(40, 30, 72), BorderSizePixel = 0, Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 7) }, bar)
	corner(seekBg, 4)
	local seekFill = mk("Frame", { BackgroundColor3 = C(170, 110, 255), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, seekBg)
	corner(seekFill, 4)
	local drag = false
	local function seekTo(x)
		local M = NovaUI.Music
		if M then M.seek(math.clamp((x - seekBg.AbsolutePosition.X) / math.max(1, seekBg.AbsoluteSize.X), 0, 1)) end
	end
	seekBg.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true seekTo(i.Position.X) end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then seekTo(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)
	local bPrev = button(bar, "<<", { Position = UDim2.fromOffset(10, 64), Size = UDim2.fromOffset(40, 24), TextSize = 12 })
	local bPlay = button(bar, "Play", { Position = UDim2.fromOffset(56, 64), Size = UDim2.fromOffset(64, 24), TextSize = 12 }, true)
	local bNext = button(bar, ">>", { Position = UDim2.fromOffset(126, 64), Size = UDim2.fromOffset(40, 24), TextSize = 12 })
	local bShuf = button(bar, "Shuf", { Position = UDim2.fromOffset(172, 64), Size = UDim2.fromOffset(44, 24), TextSize = 11 })
	local bVm = button(bar, "-", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -54, 0, 64), Size = UDim2.fromOffset(30, 24), TextSize = 13 })
	local bVp = button(bar, "+", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 64), Size = UDim2.fromOffset(30, 24), TextSize = 13 })
	local volTxt = label(bar, "60%", 10, C(170, 160, 210), Enum.Font.GothamBold, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 64), Size = UDim2.fromOffset(10, 24), TextXAlignment = Enum.TextXAlignment.Center })
	volTxt.Visible = false
	local function M() return NovaUI.Music end
	bPrev.MouseButton1Click:Connect(function() M().step(-1) end)
	bNext.MouseButton1Click:Connect(function() M().step(1) end)
	bPlay.MouseButton1Click:Connect(function() if M().idx == 0 then notify("Music", "Pick a song first") else M().toggle() end end)
	bShuf.MouseButton1Click:Connect(function() M().toggleShuffle() end)
	bVm.MouseButton1Click:Connect(function() M().setVol(M().vol - 0.1) end)
	bVp.MouseButton1Click:Connect(function() M().setVol(M().vol + 0.1) end)

	-- ---------------- results list ----------------
	local curList = {}
	local token = 0
	local function clearRes()
		for _, c in ipairs(resBox:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end
	local function message(text)
		clearRes()
		label(resBox, text, 12, C(170, 160, 210), Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local function render(list)
		clearRes()
		curList = list
		local Mu = M()
		for i, t in ipairs(list) do
			local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C(26, 19, 50), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i }, resBox)
			corner(row, 12)
			local cur = Mu.queue[Mu.idx]
			if cur and cur.src == t.src and cur.id == t.id then mk("UIStroke", { Color = C(170, 110, 255), Thickness = 1.5 }, row) end
			local art = mk("ImageLabel", { BackgroundColor3 = C(40, 30, 72), BorderSizePixel = 0, Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(40, 40), ScaleType = Enum.ScaleType.Crop }, row)
			corner(art, 8)
			local num = label(art, tostring(i), 12, C(160, 150, 200), Enum.Font.GothamBold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			if t.cover then Mu.cover(t, function(a) if art.Parent then art.Image = a num.Visible = false end end) end
			label(row, t.title, 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, { Position = UDim2.fromOffset(56, 7), Size = UDim2.new(1, -112, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			label(row, t.artist .. "  -  " .. (t.note or ""), 10, C(160, 150, 200), Enum.Font.Gotham, { Position = UDim2.fromOffset(56, 27), Size = UDim2.new(1, -112, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
			local fav = button(row, Mu.isFav(t) and "<3" or "+", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(34, 28), TextSize = 12 })
			corner(fav, 14)
			fav.BackgroundColor3 = Mu.isFav(t) and C(255, 90, 140) or C(38, 28, 66)
			fav.MouseButton1Click:Connect(function()
				local on = Mu.toggleFav(t)
				fav.Text = on and "<3" or "+"
				fav.BackgroundColor3 = on and C(255, 90, 140) or C(38, 28, 66)
			end)
			row.MouseButton1Click:Connect(function()
				Mu.play(list, i)
				render(list)
			end)
		end
	end
	local function runQuery(q, isChart, favs, fy)
		token = token + 1
		local my = token
		message("Searching...")
		task.spawn(function()
			local Mu = M()
			local list, errs = {}, {}
			if favs then list = Mu.favs
			elseif fy then list = Mu.forYou()
			elseif isChart then list = Mu.chart()
			else list, errs = Mu.search(q) end
			if my ~= token then return end
			if #list == 0 then
				message((#errs > 0 and table.concat(errs, ", ") or "No results found") .. "\nTry another word, or check your internet.")
			else
				render(list)
			end
		end)
	end
	local cats = {
		{ "For You", nil, false, false, true }, { "Trending", nil, true }, { "Hindi", "hindi songs" }, { "Bollywood", "bollywood hits" }, { "English", "english pop hits" }, { "Rap", "rap hits" },
		{ "Hip Hop", "hip hop" }, { "Desi Hip Hop", "desi hip hop" }, { "Punjabi", "punjabi songs" }, { "Romantic", "romantic hindi songs" }, { "Sad", "sad hindi songs" },
		{ "Lofi", "lofi chill" }, { "Pop", "pop hits" }, { "Rock", "rock classics" }, { "EDM", "edm party" }, { "Gym", "workout motivation" }, { "Retro", "old hindi songs" },
		{ "Arijit Singh", "arijit singh" }, { "Badshah", "badshah" }, { "Diljit", "diljit dosanjh" }, { "Phonk", "phonk" }, { "Liked", nil, false, true },
	}
	local chipBtns = {}
	local function pick(i)
		for j, b in ipairs(chipBtns) do b.BackgroundColor3 = (j == i) and C(112, 60, 225) or C(38, 28, 66) end
		local c = cats[i]
		runQuery(c[2], c[3], c[4], c[5])
	end
	for i, c in ipairs(cats) do
		local b = button(chipBar, c[1], { Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, LayoutOrder = i })
		corner(b, 13)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
		chipBtns[i] = b
		b.MouseButton1Click:Connect(function() pick(i) end)
	end
	local function doSearch()
		local q = sBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if q == "" then return end
		for _, b in ipairs(chipBtns) do b.BackgroundColor3 = C(38, 28, 66) end
		runQuery(q)
	end
	sGo.MouseButton1Click:Connect(doSearch)
	sBox.FocusLost:Connect(function(enter) if enter then doSearch() end end)

	-- ---------------- open / drag / live updates ----------------
	local firstOpen = true
	local function toggle()
		win.Visible = not win.Visible
		if win.Visible and firstOpen then
			firstOpen = false
			pick(1)
		end
	end
	local dragging, moved, startIn, startPos = false, false, nil, nil
	fab.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, startIn, startPos = true, false, i.Position, fab.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then moved = true end
			if moved then fab.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then toggle() end
		end
	end)
	-- drag the window by its header
	local wd, wStart, wPos = false, nil, nil
	head.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then wd, wStart, wPos = true, i.Position, win.Position end
	end)
	UIS.InputChanged:Connect(function(i)
		if wd and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - wStart
			win.Position = UDim2.new(wPos.X.Scale, wPos.X.Offset + d.X, wPos.Y.Scale, wPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then wd = false end
	end)
	local lastKey
	local function refresh()
		local Mu = M()
		if not Mu then return end
		local t = Mu.queue[Mu.idx]
		local st = Mu.state
		nTitle.Text = t and t.title or "Nothing playing"
		nSub.Text = t and (t.artist .. "  -  " .. (st == "loading" and "loading..." or st == "error" and Mu.note or (t.note or ""))) or "Pick a song above"
		bPlay.Text = (st == "playing") and "Pause" or "Play"
		bShuf.BackgroundColor3 = Mu.shuffle and C(112, 60, 225) or C(38, 28, 66)
		local key = t and (t.src .. t.id)
		if key ~= lastKey then
			lastKey = key
			nArt.Image = ""
			if t then Mu.cover(t, function(a) if lastKey == key then nArt.Image = a end end) end
			if win.Visible and #curList > 0 then render(curList) end
		end
	end
	task.spawn(function()
		while not NovaUI.Music do task.wait(0.5) end
		table.insert(NovaUI.Music.listeners, refresh)
		refresh()
	end)
	local spin = 0
	RS.Heartbeat:Connect(function(dt)
		local Mu = NovaUI.Music
		local playing = Mu and Mu.state == "playing"
		spin = spin + dt * (playing and 260 or 70)
		rg1.Rotation = spin % 360
		rg2.Rotation = (-spin * 1.4) % 360
		dg.Rotation = (spin * 0.6) % 360
		local pulse = 1 + math.sin(os.clock() * (playing and 6 or 2)) * (playing and 0.06 or 0.02)
		core.Size = UDim2.fromOffset(BS * pulse, BS * pulse)
		if Mu and win.Visible then
			local lv = (Mu.state == "playing") and math.clamp(Mu.sound.PlaybackLoudness / 450, 0.05, 1) or 0
			for _, v in ipairs(vbars) do
				local h = 3 + (lv * 30) * (0.45 + 0.55 * math.abs(math.sin(os.clock() * v.sp + v.ph)))
				v.f.Size = UDim2.fromOffset(4, h)
			end
			local s = Mu.sound
			seekFill.Size = UDim2.fromScale((s.TimeLength > 0) and math.clamp(s.TimePosition / s.TimeLength, 0, 1) or 0, 1)
		end
	end)
end)
------------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------------
local settingsTab = Window:CreateSettingsTab({ Discord = "https://discord.gg/yourinvite" })
local hubPref = settingsTab:Section({ Title = "Hub", Icon = "sparkles", Side = "Left" })
hubPref:Toggle({ Title = "Touch vibration", Description = "Haptic tick when you tap things (phones)", Icon = "bolt", Default = true, Flag = "Haptics", Callback = function(v)
	NovaUI.Haptics = v
end })

hubPref:Toggle({ Title = "UI sounds", Description = "Clicks, chat ping and intro sound", Icon = "🔊", Default = true, Flag = "UISounds", Callback = function(v)
	NovaUI.Sounds = v
end })

hubPref:Toggle({ Title = "Open/close animation", Description = "Hub is sucked into the orb and bursts back out", Icon = "✨", Default = true, Flag = "UIAnim", Callback = function(v)
	NovaUI.Animations = v
end })
hubPref:Toggle({ Title = "Background blur", Description = "Blur the game behind the open hub", Icon = "👁️", Default = true, Flag = "BGBlur", Callback = function(v)
	NovaUI.Blur = v
	if Window._blurTo then Window._blurTo(Window.Visible) end
end })
hubPref:Toggle({ Title = "Spawn banner", Description = "Big Celestial billboard at the spawn (only you see it)", Icon = "✨", Default = true, Flag = "SpawnBanner", Callback = function(v)
	NovaUI.SpawnBannerOn = v
	if NovaUI.SpawnBanner then NovaUI.SpawnBanner.Set(v) end
end })
hubPref:Button({ Title = "Put banner in front of me", Callback = function()
	if NovaUI.SpawnBanner then NovaUI.SpawnBanner.PlaceHere() end
end })
hubPref:Toggle({ Title = "Corner Suns", Description = "Animated blazing Suns in the corners and sides", Icon = "✨", Default = true, Flag = "Ambient", Callback = function(v)
	if Window._ambient then Window._ambient.Visible = v end
end })


------------------------------------------------------------------------
-- SOLAR SYSTEM (Closest to farthest from the Sun)
------------------------------------------------------------------------
local SOLAR_PLANETS = {
	"Mercury",
	"Venus",
	"Earth",
	"Mars",
	"Jupiter",
	"Saturn",
	"Uranus",
	"Neptune",
}
NovaUI.SolarPlanets = SOLAR_PLANETS


------------------------------------------------------------------------
-- NEXT LEVEL SOLAR SYSTEM: 8 Planets (Mercury -> Neptune) + Orbit Mode
------------------------------------------------------------------------
do
	local PLANET_DATA = {
		{ Name = "Mercury", Color = Color3.fromRGB(165, 165, 175), Order = 1, Tip = "Closest to the Sun - fast & scorching" },
		{ Name = "Venus",   Color = Color3.fromRGB(235, 185, 110), Order = 2, Tip = "Thick golden clouds & bright glow" },
		{ Name = "Earth",   Color = Color3.fromRGB(65, 165, 255),  Order = 3, Tip = "Home world - balanced blue & green" },
		{ Name = "Mars",    Color = Color3.fromRGB(225, 95, 65),   Order = 4, Tip = "The Red Planet - dusty crimson" },
		{ Name = "Jupiter", Color = Color3.fromRGB(215, 165, 120), Order = 5, Tip = "Gas giant - banded storms & bold energy" },
		{ Name = "Saturn",  Color = Color3.fromRGB(240, 205, 125), Order = 6, Tip = "Ringed titan - golden halo" },
		{ Name = "Uranus",  Color = Color3.fromRGB(115, 225, 235), Order = 7, Tip = "Ice giant - tilted cyan horizon" },
		{ Name = "Neptune", Color = Color3.fromRGB(65, 105, 245),  Order = 8, Tip = "Farthest planet - deep cosmic blue" },
	}
	NovaUI.PlanetData = PLANET_DATA

	local solarTab = Window:CreateTab({ Name = "Solar System", Icon = "sun" })
	local orderSec = solarTab:Section({ Title = "8 Planets (Sun -> Neptune)", Icon = "sun", Side = "Left" })
	local lines = {}
	for _, p in ipairs(PLANET_DATA) do
		lines[#lines + 1] = string.format("%d. %s — %s", p.Order, p.Name, p.Tip)
	end
	orderSec:Paragraph({
		Title = "Closest to Farthest from the Sun",
		Content = table.concat(lines, "\n"),
	})

	local statusLbl = orderSec:Label("Active Sun Core: Blazing Solar")
	local planetActions = {}
	for _, p in ipairs(PLANET_DATA) do
		planetActions[#planetActions + 1] = {
			Title = p.Order .. ". " .. p.Name,
			Description = "Solar tint",
			Icon = "star",
			Callback = function()
				statusLbl:Set("Focused Planet: #" .. p.Order .. " " .. p.Name)
				Window:Notify({
					Title = "Planet #" .. p.Order .. ": " .. p.Name,
					Content = p.Tip,
					Duration = 3.5,
				})
			end,
		}
	end
	orderSec:Actions(planetActions)

	local orbitSec = solarTab:Section({ Title = "Solar Orbit & Boost", Icon = "bolt", Side = "Right" })
	local orbitSpin = false
	local orbitSpeed = 48
	local orbitConn
	orbitSec:Toggle({
		Title = "Solar Orbit Spin",
		Description = "Smoothly rotates your character around the current spot",
		Icon = "refresh",
		Flag = "SolarOrbitSpin",
		Callback = function(v)
			orbitSpin = v
			if orbitConn then
				orbitConn:Disconnect()
				orbitConn = nil
			end
			if v then
				orbitConn = RunService.Heartbeat:Connect(function(dt)
					local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
					if r then
						r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(orbitSpeed * dt * 4), 0)
					end
				end)
			end
		end,
	})
	orbitSec:Slider({
		Title = "Orbit Speed",
		Min = 5,
		Max = 100,
		Default = 48,
		Increment = 1,
		Flag = "SolarOrbitSpeed",
		Callback = function(v)
			orbitSpeed = v
		end,
	})
	
	orbitSec:Toggle({
		Title = "Show 8-Planet Orbit UI",
		Description = "Displays Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus & Neptune orbiting the Sun",
		Icon = "sun",
		Default = true,
		Flag = "Show8PlanetsUI",
		Callback = function(v)
			if NovaUI.SolarOrbitUI then
				NovaUI.SolarOrbitUI.Visible = v
			end
		end,
	})

	orbitSec:Button({
		Title = "Solar Flare Pulse",
		Style = "Primary",
		Callback = function()
			if Window._bh and Window._bh.Boost then
				pcall(function() Window._bh.Boost(2.5) end)
			end
			if Window._orbFx then
				pcall(function() Window._orbFx(true) end)
			end
			Window:Notify({
				Title = "Solar Flare",
				Content = "Sun core boosted across Mercury to Neptune!",
				Duration = 3,
			})
		end,
	})
end


------------------------------------------------------------------------
-- SOLAR SYSTEM UI: 2x SPIN + 8 PLANETS (Mercury -> Neptune)
------------------------------------------------------------------------
do
	local Planets8 = {
		{ Name = "Mercury", R = 26,  Sz = 6,  Sp = 4.8,  Col = Color3.fromRGB(185, 185, 195) },
		{ Name = "Venus",   R = 38,  Sz = 8,  Sp = 3.6,  Col = Color3.fromRGB(245, 195, 110) },
		{ Name = "Earth",   R = 52,  Sz = 9,  Sp = 2.8,  Col = Color3.fromRGB(70, 175, 255) },
		{ Name = "Mars",    R = 66,  Sz = 7,  Sp = 2.2,  Col = Color3.fromRGB(235, 95, 65) },
		{ Name = "Jupiter", R = 84,  Sz = 14, Sp = 1.5,  Col = Color3.fromRGB(225, 170, 120) },
		{ Name = "Saturn",  R = 103, Sz = 12, Sp = 1.1,  Col = Color3.fromRGB(250, 215, 130), Ring = true },
		{ Name = "Uranus",  R = 120, Sz = 10, Sp = 0.8,  Col = Color3.fromRGB(115, 230, 240) },
		{ Name = "Neptune", R = 136, Sz = 10, Sp = 0.6,  Col = Color3.fromRGB(70, 115, 250) },
	}
	NovaUI.Planets8 = Planets8
	NovaUI.PlanetSpinMult = 2.0

	task.spawn(function()
		while not (Window and Window._main) do task.wait(0.2) end
		local box = Instance.new("Frame")
		box.Name = "SolarOrbit8UI"
		box.BackgroundColor3 = Color3.fromRGB(10, 6, 3)
		box.BackgroundTransparency = 0.12
		box.BorderSizePixel = 0
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.new(0.5, 0, 0.54, 0)
		box.Size = UDim2.fromOffset(296, 296)
		box.ZIndex = 25
		box.Visible = true
		box.Parent = Window._main
		Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)

		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(255, 180, 40)
		st.Thickness = 2.5
		st.Transparency = 0.2
		st.Parent = box

		-- Center Blazing Sun
		local sun = Instance.new("Frame")
		sun.AnchorPoint = Vector2.new(0.5, 0.5)
		sun.Position = UDim2.fromScale(0.5, 0.5)
		sun.Size = UDim2.fromOffset(26, 26)
		sun.BackgroundColor3 = Color3.fromRGB(255, 200, 45)
		sun.BorderSizePixel = 0
		sun.ZIndex = 28
		sun.Parent = box
		Instance.new("UICorner", sun).CornerRadius = UDim.new(1, 0)
		local sunSt = Instance.new("UIStroke")
		sunSt.Color = Color3.fromRGB(255, 245, 160)
		sunSt.Thickness = 2
		sunSt.Parent = sun

		local items = {}
		for idx, p in ipairs(Planets8) do
			local ring = Instance.new("Frame")
			ring.BackgroundTransparency = 1
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.Position = UDim2.fromScale(0.5, 0.5)
			ring.Size = UDim2.fromOffset(p.R * 2, p.R * 2)
			ring.ZIndex = 26
			ring.Parent = box
			Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
			local rStroke = Instance.new("UIStroke")
			rStroke.Color = p.Col
			rStroke.Thickness = 1
			rStroke.Transparency = 0.65
			rStroke.Parent = ring

			local dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Size = UDim2.fromOffset(p.Sz, p.Sz)
			dot.BackgroundColor3 = p.Col
			dot.BorderSizePixel = 0
			dot.ZIndex = 29
			dot.Parent = box
			Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

			if p.Ring then
				local pRing = Instance.new("Frame")
				pRing.BackgroundTransparency = 1
				pRing.AnchorPoint = Vector2.new(0.5, 0.5)
				pRing.Position = UDim2.fromScale(0.5, 0.5)
				pRing.Size = UDim2.fromOffset(p.Sz * 1.9, p.Sz * 0.65)
				pRing.Rotation = -22
				pRing.ZIndex = 30
				pRing.Parent = dot
				Instance.new("UICorner", pRing).CornerRadius = UDim.new(1, 0)
				local pSt = Instance.new("UIStroke")
				pSt.Color = Color3.fromRGB(255, 235, 165)
				pSt.Thickness = 1.5
				pSt.Parent = pRing
			end

			items[idx] = { data = p, dot = dot, angle = idx * 0.785 }
		end

		local tag = Instance.new("TextLabel")
		tag.BackgroundTransparency = 1
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 1, 6)
		tag.Size = UDim2.new(1, 40, 0, 18)
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 11
		tag.TextColor3 = Color3.fromRGB(255, 225, 145)
		tag.Text = "2x Spin • 8 Planets: Mercury -> Neptune"
		tag.ZIndex = 30
		tag.Parent = box

		NovaUI.SolarOrbitUI = box
		RunService.Heartbeat:Connect(function(dt)
			if not box.Visible then return end
			local mult = NovaUI.PlanetSpinMult or 2.0
			for _, it in ipairs(items) do
				it.angle = (it.angle + dt * it.data.Sp * mult) % (math.pi * 2)
				local x = 148 + math.cos(it.angle) * it.data.R
				local y = 148 + math.sin(it.angle) * it.data.R
				it.dot.Position = UDim2.fromOffset(x, y)
			end
		end)
	end)
end


------------------------------------------------------------------------
-- CELESTIAL GODVERSE: 8 PLANETS ORBIT (No circle box • 2x Spin • Mercury -> Neptune)
------------------------------------------------------------------------
do
	local PLANETS_8 = {
		{ Name = "Mercury", R = 28,  Sz = 6,  Sp = 4.8, Col = Color3.fromRGB(190, 195, 205) },
		{ Name = "Venus",   R = 42,  Sz = 8,  Sp = 3.6, Col = Color3.fromRGB(250, 200, 115) },
		{ Name = "Earth",   R = 58,  Sz = 9,  Sp = 2.8, Col = Color3.fromRGB(70, 180, 255) },
		{ Name = "Mars",    R = 74,  Sz = 7,  Sp = 2.2, Col = Color3.fromRGB(240, 100, 70) },
		{ Name = "Jupiter", R = 94,  Sz = 14, Sp = 1.5, Col = Color3.fromRGB(230, 175, 125) },
		{ Name = "Saturn",  R = 114, Sz = 12, Sp = 1.1, Col = Color3.fromRGB(255, 220, 135), Ring = true },
		{ Name = "Uranus",  R = 132, Sz = 10, Sp = 0.8, Col = Color3.fromRGB(115, 235, 245) },
		{ Name = "Neptune", R = 148, Sz = 10, Sp = 0.6, Col = Color3.fromRGB(75, 125, 255) },
	}
	NovaUI.Planets8 = PLANETS_8
	NovaUI.PlanetSpinMult = 2.0

	task.spawn(function()
		while not (Window and Window._main) do task.wait(0.2) end
		if NovaUI.Solar5UI then
			pcall(function() NovaUI.Solar5UI:Destroy() end)
		end

		local solarPage
		for _, t in ipairs(Window.Tabs or {}) do
			if t.Name == "Solar System" then
				solarPage = t.Page
				break
			end
		end
		if not solarPage then return end

		-- Borderless planet stage inside the Solar System tab (no circular frame/box around it)
		local stage = Instance.new("Frame")
		stage.Name = "Planets8Stage"
		stage.BackgroundTransparency = 1
		stage.BorderSizePixel = 0
		stage.AnchorPoint = Vector2.new(0.5, 0.5)
		stage.Position = UDim2.new(0.5, 0, 0.54, 0)
		stage.Size = UDim2.fromOffset(312, 312)
		stage.ZIndex = 12
		stage.Parent = solarPage

		-- Central Sun node
		local sun = Instance.new("Frame")
		sun.AnchorPoint = Vector2.new(0.5, 0.5)
		sun.Position = UDim2.fromScale(0.5, 0.5)
		sun.Size = UDim2.fromOffset(24, 24)
		sun.BackgroundColor3 = Color3.fromRGB(255, 195, 45)
		sun.BorderSizePixel = 0
		sun.ZIndex = 15
		sun.Parent = stage
		Instance.new("UICorner", sun).CornerRadius = UDim.new(1, 0)

		local orbiting = {}
		for idx, p in ipairs(PLANETS_8) do
			local dot = Instance.new("Frame")
			dot.Name = p.Name
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Size = UDim2.fromOffset(p.Sz, p.Sz)
			dot.BackgroundColor3 = p.Col
			dot.BorderSizePixel = 0
			dot.ZIndex = 16
			dot.Parent = stage
			Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

			if p.Ring then
				local pRing = Instance.new("Frame")
				pRing.BackgroundTransparency = 1
				pRing.AnchorPoint = Vector2.new(0.5, 0.5)
				pRing.Position = UDim2.fromScale(0.5, 0.5)
				pRing.Size = UDim2.fromOffset(p.Sz * 1.9, p.Sz * 0.65)
				pRing.Rotation = -20
				pRing.ZIndex = 17
				pRing.Parent = dot
				Instance.new("UICorner", pRing).CornerRadius = UDim.new(1, 0)
				local pSt = Instance.new("UIStroke")
				pSt.Color = Color3.fromRGB(255, 235, 165)
				pSt.Thickness = 1.5
				pSt.Parent = pRing
			end

			orbiting[idx] = { data = p, dot = dot, angle = idx * 0.785 }
		end

		NovaUI.Planets8Stage = stage
		RunService.Heartbeat:Connect(function(dt)
			if not (stage.Visible and solarPage.Visible) then return end
			local mult = NovaUI.PlanetSpinMult or 2.0
			for _, it in ipairs(orbiting) do
				it.angle = (it.angle + dt * it.data.Sp * mult) % (math.pi * 2)
				local x = 156 + math.cos(it.angle) * it.data.R
				local y = 156 + math.sin(it.angle) * it.data.R
				it.dot.Position = UDim2.fromOffset(x, y)
			end
		end)
	end)
end

NovaUI.HubReady = true
task.spawn(function()
	while NovaUI.HoldOpen do task.wait(0.2) end
	task.wait(1.4)
Window:Notify({ Title = "Celestial Godverse loaded", Content = "RightShift or tap the Sun orb to hide/show.", Duration = 5 })
end)

task.spawn(function()
    local text = "------------------//////CELESTIAL GODVERSE UV1.0 LOADED 🪩 (Made by Yadsan_Godverse 🔱-- YADSAN X YAKUZA CELESTIAL SYNDICATE ON TOP😎////////--------------------)"
    local textChatService = game:GetService("TextChatService")
    if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local channel = textChatService:FindFirstChild("TextChannels") and textChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(text)
        end
    else
        local defaultEvents = RS:FindFirstChild("DefaultChatSystemChatEvents")
        if defaultEvents and defaultEvents:FindFirstChild("SayMessageRequest") then
            defaultEvents.SayMessageRequest:FireServer(text, "All")
        end
    end
end)
end

-- ===================== PICKER =====================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local function launch(which)
    local fn = (which == "flames") and RunFlamesHub or RunWhiteLifeHub
    local ok, err = pcall(fn)
    if not ok then warn("[Merged Hub] " .. tostring(which) .. " failed: " .. tostring(err)) end
end

if AUTO_RUN then
    task.spawn(launch, AUTO_RUN)
    return
end

local parent
pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not parent then parent = LP:WaitForChild("PlayerGui") end

local gui = Instance.new("ScreenGui")
gui.Name = "MergedHubPicker"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(300, 190)
frame.Position = UDim2.new(0.5, -150, 0.5, -95)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(255, 140, 40)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.BackgroundTransparency = 1
title.Text = "Choose your hub"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame

local function makeButton(text, y, color, which)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -40, 0, 48)
    b.Position = UDim2.new(0, 20, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.AutoButtonColor = true
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.Activated:Connect(function()
        gui:Destroy()
        task.spawn(launch, which)
    end)
end

makeButton("Flames Hub Gold", 56, Color3.fromRGB(200, 80, 20), "flames")
makeButton("White Life Hub (NovaUI)", 116, Color3.fromRGB(60, 60, 90), "white")
