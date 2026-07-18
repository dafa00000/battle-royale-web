--[[
	Shared Utility Functions - Common helpers for both Lobby and Match
]]

local Util = {}

-- Services
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Constants
local EPSILON = 1e-6

-- ==================== MATH UTILITIES ====================

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.LerpVector3(a: Vector3, b: Vector3, t: number): Vector3
	return a:Lerp(b, t)
end

function Util.LerpCFrame(a: CFrame, b: CFrame, t: number): CFrame
	return a:Lerp(b, t)
end

function Util.Clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

function Util.ClampVector3(v: Vector3, min: Vector3, max: Vector3): Vector3
	return Vector3.new(
		Util.Clamp(v.X, min.X, max.X),
		Util.Clamp(v.Y, min.Y, max.Y),
		Util.Clamp(v.Z, min.Z, max.Z)
	)
end

function Util.Remap(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

function Util.Round(value: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

function Util.RoundVector3(v: Vector3, decimals: number?): Vector3
	return Vector3.new(Util.Round(v.X, decimals), Util.Round(v.Y, decimals), Util.Round(v.Z, decimals))
end

function Util.DistanceSquared(a: Vector3, b: Vector3): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return dx * dx + dy * dy + dz * dz
end

function Util.AngleBetween(v1: Vector3, v2: Vector3): number
	local dot = v1:Dot(v2)
	local mag = v1.Magnitude * v2.Magnitude
	if mag < EPSILON then return 0 end
	return math.acos(Util.Clamp(dot / mag, -1, 1))
end

function Util.SignedAngle(from: Vector3, to: Vector3, axis: Vector3): number
	local angle = Util.AngleBetween(from, to)
	local cross = from:Cross(to)
	if cross:Dot(axis) < 0 then
		return -angle
	end
	return angle
end

-- ==================== RANDOM & ID GENERATION ====================

local rng = Random.new()

function Util.RandomFloat(min: number, max: number): number
	return rng:NextNumber(min, max)
end

function Util.RandomInt(min: number, max: number): number
	return rng:NextInteger(min, max)
end

function Util.RandomVector3(min: Vector3, max: Vector3): Vector3
	return Vector3.new(
		rng:NextNumber(min.X, max.X),
		rng:NextNumber(min.Y, max.Y),
		rng:NextNumber(min.Z, max.Z)
	)
end

function Util.RandomUnitVector(): Vector3
	-- Uniform random point on sphere
	local u = rng:NextNumber()
	local v = rng:NextNumber()
	local theta = 2 * math.pi * u
	local phi = math.acos(2 * v - 1)
	local x = math.sin(phi) * math.cos(theta)
	local y = math.sin(phi) * math.sin(theta)
	local z = math.cos(phi)
	return Vector3.new(x, y, z)
end

function Util.RandomInCircle(radius: number): Vector2
	local r = math.sqrt(rng:NextNumber()) * radius
	local theta = rng:NextNumber() * 2 * math.pi
	return Vector2.new(r * math.cos(theta), r * math.sin(theta))
end

function Util.RandomInSphere(radius: number): Vector3
	local r = math.cbrt(rng:NextNumber()) * radius
	local theta = rng:NextNumber() * 2 * math.pi
	local phi = math.acos(2 * rng:NextNumber() - 1)
	return Vector3.new(
		r * math.sin(phi) * math.cos(theta),
		r * math.sin(phi) * math.sin(theta),
		r * math.cos(phi)
	)
end

function Util.GenerateUID(): string
	return HttpService:GenerateGUID(false)
end

function Util.GenerateShortUID(length: number?): string
	length = length or 8
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local result = {}
	for i = 1, length do
		result[i] = chars:sub(rng:NextInteger(1, #chars), rng:NextInteger(1, #chars))
	end
	return table.concat(result)
end

-- ==================== TIME & FORMATTING ====================

function Util.FormatTime(seconds: number, showMs: boolean?): string
	if seconds < 0 then seconds = 0 end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	local ms = math.floor((seconds % 1) * 1000)
	
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%d:%02d", minutes, secs)
	elseif showMs then
		return string.format("%d.%03d", secs, ms)
	else
		return string.format("%ds", secs)
	end
end

function Util.FormatNumber(num: number): string
	if num >= 1e9 then
		return string.format("%.1fB", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.1fM", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fK", num / 1e3)
	else
		return tostring(math.floor(num))
	end
end

function Util.FormatCurrency(cash: number, credits: number): string
	local parts = {}
	if cash > 0 then table.insert(parts, Util.FormatNumber(cash) .. "💰") end
	if credits > 0 then table.insert(parts, Util.FormatNumber(credits) .. "💎") end
	return table.concat(parts, " ")
end

-- ==================== COLOR & VISUAL ====================

function Util.HexToColor3(hex: string): Color3
	hex = hex:gsub("#", "")
	return Color3.fromRGB(
		tonumber(hex:sub(1, 2), 16),
		tonumber(hex:sub(3, 4), 16),
		tonumber(hex:sub(5, 6), 16)
	)
end

function Util.Color3ToHex(color: Color3): string
	return string.format("#%02X%02X%02X", 
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Util.LerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		Util.Lerp(a.R, b.R, t),
		Util.Lerp(a.G, b.G, t),
		Util.Lerp(a.B, b.B, t)
	)
end

function Util.GetRarityColor(rarity: string): Color3
	local colors = {
		Common = Color3.fromRGB(180, 180, 180),
		Uncommon = Color3.fromRGB(50, 200, 50),
		Rare = Color3.fromRGB(50, 150, 255),
		Epic = Color3.fromRGB(180, 50, 255),
		Legendary = Color3.fromRGB(255, 180, 0),
		Mythic = Color3.fromRGB(255, 50, 50),
	}
	return colors[rarity] or colors.Common
end

-- ==================== TABLE UTILITIES ====================

function Util.DeepCopy<T>(original: T): T
	if type(original) ~= "table" then return original end
	local copy = {}
	for k, v in pairs(original) do
		copy[Util.DeepCopy(k)] = Util.DeepCopy(v)
	end
	return setmetatable(copy, getmetatable(original))
end

function Util.ShallowCopy<T>(original: T): T
	if type(original) ~= "table" then return original end
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = v
	end
	return setmetatable(copy, getmetatable(original))
end

function Util.TableLength(t: { [any]: any }): number
	local count = 0
	for _ in pairs(t) do count += 1 end
	return count
end

function Util.TableContains(t: { [any]: any }, value: any): boolean
	for _, v in pairs(t) do
		if v == value then return true end
	end
	return false
end

function Util.TableFind(t: { any }, value: any): number?
	for i, v in ipairs(t) do
		if v == value then return i end
	end
	return nil
end

function Util.TableRemoveValue(t: { any }, value: any): boolean
	local index = Util.TableFind(t, value)
	if index then
		table.remove(t, index)
		return true
	end
	return false
end

function Util.WeightedRandom(weights: { [any]: number }): any
	local total = 0
	for _, w in pairs(weights) do total += w end
	local roll = rng:NextNumber() * total
	local accum = 0
	for k, w in pairs(weights) do
		accum += w
		if roll <= accum then return k end
	end
	return next(weights)
end

function Util.ShuffleInPlace<T>(t: { T }): { T }
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- ==================== INSTANCE UTILITIES ====================

function Util.Create(instanceType: string, properties: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(instanceType)
	for prop, value in pairs(properties) do
		instance[prop] = value
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	return instance
end

function Util.New(instanceType: string): (properties: { [string]: any }) -> Instance
	return function(properties)
		return Util.Create(instanceType, properties)
	end
end

function Util.DestroyChildren(instance: Instance, className: string?)
	for _, child in ipairs(instance:GetChildren()) do
		if not className or child:IsA(className) then
			child:Destroy()
		end
	end
end

function Util.GetDescendantsOfClass(instance: Instance, className: string): { Instance }
	local results = {}
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA(className) then
			table.insert(results, desc)
		end
	end
	return results
end

function Util.WaitForChildOfClass(parent: Instance, className: string, timeout: number?): Instance?
	local start = os.clock()
	while true do
		local child = parent:FindFirstChildOfClass(className)
		if child then return child end
		if timeout and os.clock() - start > timeout then return nil end
		task.wait()
	end
end

-- ==================== RAYCAST UTILITIES ====================

function Util.Raycast(origin: Vector3, direction: Vector3, params: RaycastParams?): RaycastResult?
	local result = workspace:Raycast(origin, direction, params)
	return result
end

function Util.RaycastAll(origin: Vector3, direction: Vector3, params: RaycastParams?): { RaycastResult }
	local results = {}
	local currentOrigin = origin
	local remainingDirection = direction
	local maxIterations = 10
	
	for i = 1, maxIterations do
		local result = workspace:Raycast(currentOrigin, remainingDirection, params)
		if not result then break end
		table.insert(results, result)
		
		-- Continue from just past the hit
		currentOrigin = result.Position + result.Normal * 0.01
		remainingDirection = direction.Unit * (direction.Magnitude - (currentOrigin - origin).Magnitude)
		
		if remainingDirection.Magnitude < 0.01 then break end
		
		-- Modify params to ignore this hit
		if params then
			local filter = params.FilterDescendantsInstances
			table.insert(filter, result.Instance)
			params = RaycastParams.new()
			params.FilterDescendantsInstances = filter
			params.FilterType = params.FilterType
			params.CollisionGroup = params.CollisionGroup
			params.IgnoreWater = params.IgnoreWater
		end
	end
	
	return results
end

function Util.CastHitbox(origin: CFrame, size: Vector3, direction: Vector3, params: RaycastParams?): { RaycastResult }
	-- Boxcast using multiple rays
	local results = {}
	local halfSize = size * 0.5
	local corners = {
		origin * CFrame.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
		origin * CFrame.new(halfSize.X, -halfSize.Y, -halfSize.Z),
		origin * CFrame.new(-halfSize.X, halfSize.Y, -halfSize.Z),
		origin * CFrame.new(halfSize.X, halfSize.Y, -halfSize.Z),
		origin * CFrame.new(-halfSize.X, -halfSize.Y, halfSize.Z),
		origin * CFrame.new(halfSize.X, -halfSize.Y, halfSize.Z),
		origin * CFrame.new(-halfSize.X, halfSize.Y, halfSize.Z),
		origin * CFrame.new(halfSize.X, halfSize.Y, halfSize.Z),
	}
	
	for _, corner in ipairs(corners) do
		local result = Util.Raycast(corner.Position, direction, params)
		if result then table.insert(results, result) end
	end
	
	-- Sort by distance
	table.sort(results, function(a, b) return a.Distance < b.Distance end)
	return results
end

-- ==================== NETWORK UTILITIES ====================

function Util.CompressVector3(v: Vector3, precision: number?): string
	precision = precision or 0.01
	local x = math.floor(v.X / precision + 0.5)
	local y = math.floor(v.Y / precision + 0.5)
	local z = math.floor(v.Z / precision + 0.5)
	return string.pack("iii", x, y, z)
end

function Util.DecompressVector3(data: string, precision: number?): Vector3
	precision = precision or 0.01
	local x, y, z = string.unpack("iii", data)
	return Vector3.new(x * precision, y * precision, z * precision)
end

function Util.CompressCFrame(cf: CFrame): string
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return string.pack("ffffffffffff", x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

function Util.DecompressCFrame(data: string): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = string.unpack("ffffffffffff", data)
	return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

-- ==================== VALIDATION ====================

function Util.ValidatePlayer(player: Player?): boolean
	return player and player:IsA("Player") and player.Parent == Players
end

function Util.ValidateCharacter(character: Model?): boolean
	return character 
		and character:IsA("Model") 
		and character:FindFirstChild("Humanoid") 
		and character:FindFirstChild("HumanoidRootPart")
		and character.Humanoid.Health > 0
end

function Util.ValidatePosition(pos: Vector3, maxRange: number?): boolean
	if maxRange and pos.Magnitude > maxRange then return false end
	return pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z -- NaN check
end

function Util.SanitizeInput(input: string, maxLength: number?): string
	maxLength = maxLength or 1000
	input = input:sub(1, maxLength)
	-- Remove control characters except newline/tab
	return input:gsub("[\0-\8\11-\12\14-\31\127]", "")
end

-- ==================== PERFORMANCE ====================

local objectPools: { [string]: { Instance } } = {}

function Util.GetFromPool(className: string, parent: Instance?): Instance
	local pool = objectPools[className]
	if pool and #pool > 0 then
		local obj = table.remove(pool)
		if parent then obj.Parent = parent end
		return obj
	end
	return Instance.new(className)
end

function Util.ReturnToPool(obj: Instance, className: string)
	if not obj or not obj.Parent then return end
	obj.Parent = nil
	-- Reset common properties
	if obj:IsA("BasePart") then
		obj.Anchored = true
		obj.CanCollide = false
		obj.CanTouch = false
		obj.CanQuery = false
		obj.Transparency = 1
		obj.Velocity = Vector3.zero
		obj.RotVelocity = Vector3.zero
	end
	if obj:IsA("ParticleEmitter") then
		obj.Enabled = false
	end
	if obj:IsA("Trail") then
		obj.Enabled = false
	end
	if obj:IsA("Sound") then
		obj:Stop()
	end
	
	local pool = objectPools[className]
	if not pool then
		pool = {}
		objectPools[className] = pool
	end
	if #pool < 50 then -- Max pool size
		table.insert(pool, obj)
	else
		obj:Destroy()
	end
end

function Util.ClearPools()
	for _, pool in pairs(objectPools) do
		for _, obj in ipairs(pool) do
			obj:Destroy()
		end
	end
	table.clear(objectPools)
end

-- ==================== DEBUG ====================

local DEBUG_ENABLED = false

function Util.SetDebug(enabled: boolean)
	DEBUG_ENABLED = enabled
end

function Util.DebugLog(...)
	if DEBUG_ENABLED then
		print("[DEBUG]", os.clock(), ...)
	end
end

function Util.DebugWarn(...)
	if DEBUG_ENABLED then
		warn("[DEBUG]", os.clock(), ...)
	end
end

function Util.Assert(condition: boolean, message: string)
	if not condition then
		error("[ASSERT] " .. message, 2)
	end
end

function Util.TimeFunction(func: () -> any): (number, any)
	local start = os.clock()
	local result = func()
	return os.clock() - start, result
end

return Util