--[[ 	iSAC Library by Apple

		iSAC is based upon Sida's Auto Carry and offers a base for champion scripts.
		Credits to Sida, SAC has been a great source of inspiration and some logic has been taken from SAC.

		Note: Class names are prefixed with 'i' to prevent multiple similar classes from interfering with eachother. (And because I love being me.)

		Special thanks to:
		HeX - For giving me a lot of ideas and being an awesome mate to talk to while working.
		Mom - For giving birth to me.
		My psychiatrist - For prescribing me pills.
		]]--

if VIP_USER then require "Collision" end

--[[ iOrbWalker Class ]]--

class 'iOrbWalker'

STAGE_WINDUP = 1
STAGE_ORBWALK = 2
STAGE_NONE = 3

function iOrbWalker:__init(AARange)
	self.AARange = AARange or (myHero.range + GetDistance(myHero.minBBox))
	self.ShotCast = 0
	self.NextShot = 0
end

--[[ Main Functions ]]--

function iOrbWalker:Move(movePos)
	assert(movePos and movePos.x and movePos.z, "Error: iOrbWalker:Move(movePos), invalid movePos.")
	if self:GetStage() ~= STAGE_WINDUP then
		myHero:MoveTo(movePos.x, movePos.z)
	end
end

function iOrbWalker:Orbwalk(movePos, target)
	assert(movePos and movePos.x and movePos.z, "Error: iOrbWalker:Orbwalk(movePos, target), invalid movePos.")
	assert(not target or ValidTarget(target), "Error: iOrbWalker:Orbwalk(movePos, target), invalid target.")
	if self:GetStage() == STAGE_NONE and ValidTarget(target, self.AARange) then
		myHero:Attack(target)
	elseif self:GetStage() == STAGE_ORBWALK then
		myHero:MoveTo(movePos.x, movePos.z)
	end
end

function iOrbWalker:Attack(target)
	assert(not target or ValidTarget(target), "Error: iOrbWalker:Attack(target), invalid target.")
	if self:GetStage() == STAGE_NONE and ValidTarget(target, self.AARange) then
		myHero:Attack(target)
	end
end

function iOrbWalker:GetStage()
	if GetTickCount() > self.NextShot then return STAGE_NONE end
	if GetTickCount() > self.ShotCast then return STAGE_ORBWALK end
	return STAGE_WINDUP
end

function iOrbWalker:GetDPS(unit, target)
	local unit = unit or myHero
	if target then
		return unit.totalDamage and unit.attackSpeed and unit:CalcDamage(target, (1/(unit.attackSpeed * 0.625))*unit.totalDamage) or 0
	else
		return unit.totalDamage and unit.attackSpeed and (1/(unit.attackSpeed * 0.625))*unit.totalDamage or 0
	end
end

--[[ Configuration Functions ]]--

function iOrbWalker:addAA(AAName) -- Add AA spell
	assert(type(AAName) == "string", "Error: iOrbWalker:addAA(AAName), <string> expected.")
	if not self.AASpells then self.AASpells = {} end
	self.AASpells[#self.AASpells+1] = AAName
end

function iOrbWalker:addReset(resetName) -- Add AA-timer resetting spell
	assert(type(resetName) == "string", "Error: iOrbWalker:addReset(resetName), <string> expected.")
	if not self.ResetSpells then self.ResetSpells = {} end
	self.ResetSpells[#self.ResetSpells+1] = resetName
end

function iOrbWalker:OnProcessSpell(unit, spell)
	if unit.isMe then
		if self.ResetSpells then
			for _, resetName in ipairs(self.ResetSpells) do
				if spell.name:find(resetName) then
					self.ShotCast = GetTickCount()
					self.NextShot = GetTickCount()
					return
				end
			end
		end
		if self.AASpells then
			for _, AAName in ipairs(self.AASpells) do
				if AAName == "attack" and spell.name:lower():find("attack") then -- Simple lowercase checking for "attack" for the lazy people who don't want to search for all the basic attack names (like me) 
					self.ShotCast = GetTickCount() + spell.windUpTime * 1000 - GetLatency() / 2
					self.NextShot = GetTickCount() + spell.animationTime * 1000 - GetLatency() / 2
					return
				elseif spell.name:find(AAName) then
					self.ShotCast = GetTickCount() + spell.windUpTime * 1000 - GetLatency() / 2
					self.NextShot = GetTickCount() + spell.animationTime * 1000 - GetLatency() / 2
					return
				end
			end
		end
	end
end

--[[ iCaster ]]--

class 'iCaster'

SPELL_TARGETED = 1
SPELL_LINEAR = 2
SPELL_CIRCLE = 3
SPELL_CONE = 4
SPELL_LINEAR_COL = 5
SPELL_SELF = 6

function iCaster:__init(spell, range, spellType, speed, delay, width, useCollisionLib)
	assert(spell and range, "Error: iCaster:__init(spell, range, spellType, [speed, delay, width, useCollisionLib]), invalid arguments.")
	self.spell = spell
	self.spellType = spellType
	self.range = range
	self.speed = speed
	self.delay = delay
	self.width = width
	self.spellData = myHero:GetSpellData(spell)
	if spellType == SPELL_LINEAR or spellType == SPELL_CIRCLE or spellType == SPELL_LINEAR_COL then
		assert(type(range) == "number" and type(speed) == "number" and type(delay) == "number" and (type(width) == "number" or not width), "Error: iCaster:__init(spell, range, [spellType, speed, delay, width, useCollisionLib]), invalid arguments for skillshot-type.")
		self.pred = VIP_USER and TargetPredictionVIP(range, speed, delay, width) or TargetPrediction(range, speed/1000, delay*1000, width)
		if spellType == SPELL_LINEAR_COL then
			self.coll = VIP_USER and useCollisionLib ~= false and Collision(range, speed, delay, width) or nil
		end
	end
end

function iCaster:Cast(target, minHitChance)
	if myHero:CanUseSpell(self.spell) ~= READY then return false end
	if self.spellType == SPELL_SELF then
		CastSpell(self.spell)
		return true
	elseif self.spellType == SPELL_TARGETED then
		if ValidTarget(target, self.range) then
			CastSpell(self.spell, target)
			return true
		end
	elseif self.spellType == SPELL_CONE then
		if ValidTarget(target, self.range) then
			CastSpell(self.spell, target.x, target.z)
			return true
		end
	elseif self.spellType == SPELL_LINEAR or self.spellType == SPELL_CIRCLE then
		if self.pred and ValidTarget(target) then
			local spellPos,_ = self.pred:GetPrediction(target)
			if spellPos and (not minHitChance or self.pred:GetHitChance(target) > minHitChance) then
				CastSpell(self.spell, spellPos.x, spellPos.z)
				return true
			end
		end
	elseif self.spellType == SPELL_LINEAR_COL then
		if self.pred and ValidTarget(target) then
			local spellPos,_ = self.pred:GetPrediction(target)
			if spellPos and (not minHitChance or self.pred:GetHitChance(target) > minHitChance) then
				if self.coll then
					local willCollide,_ = self.coll:GetMinionCollision(myHero, spellPos)
					if not willCollide then
						CastSpell(self.spell, spellPos.x, spellPos.z)
						return true
					end
				elseif not iCollision(spellPos, self.width) then
					CastSpell(self.spell, spellPos.x, spellPos.z)
					return true
				end
			end
		end
	end
	return false
end

function iCaster:CastMouse(spellPos, nearestTarget)
	assert(spellPos and spellPos.x and spellPos.z, "Error: iCaster:CastMouse(spellPos, nearestTarget), invalid spellPos.")
	assert(self.spellType ~= SPELL_TARGETED or (nearestTarget == nil or type(nearestTarget) == "boolean"), "Error: iCaster:CastMouse(spellPos, nearestTarget), <boolean> or nil expected for nearestTarget.")
	if myHero:CanUseSpell(self.spell) ~= READY then return false end
	if self.spellType == SPELL_SELF then
		CastSpell(self.spell)
		return true
	elseif self.spellType == SPELL_TARGETED then
		if nearestTarget ~= false then
			local targetEnemy
			for _, enemy in ipairs(GetEnemyHeroes()) do
				if ValidTarget(targetEnemy, self.range) and (targetEnemy == nil or GetDistanceFromMouse(enemy) < GetDistanceFromMouse(targetEnemy)) then
					targetEnemy = enemy
				end
			end
			if targetEnemy then
				CastSpell(self.spell, targetEnemy)
				return true
			end
		end
	elseif self.spellType == SPELL_LINEAR_COL or self.spellType == SPELL_LINEAR or self.spellType == SPELL_CIRCLE or self.spellType == SPELL_CONE then
		CastSpell(self.spell, spellPos.x, spellPos.z)
		return true
	end
end

function iCaster:AACast(iOW, target, minHitChance) -- Cast after AA
	if not iOW then return end
	if iOW:GetStage() == STAGE_ORBWALK then
		return self:Cast(target, minHitChance)
	end
end

function iCaster:Ready()
	return myHero:CanUseSpell(self.spell) == READY
end

--[[ iSummoners ]]--

class 'iSummoners'
local _SummonerSpells = {
	SummonerMana = {name = "SummonerMana", shortName = "Clarity", range = 600},
	SummonerOdinGarrison = {name = "SummonerOdinGarrison", shortName = "Garrison", range = 1000},
	SummonerHaste = {name = "SummonerHaste", shortName = "Ghost", range = nil},
	SummonerHeal = {name = "SummonerHeal", shortName = "Heal", range = 300},
	SummonerRevive = {name = "SummonerRevive", shortName = "Revive", range = nil},
	SummonerSmite = {name = "SummonerSmite", shortName = "Smite", range = 625},
	SummonerBoost = {name = "SummonerBoost", shortName = "Cleanse", range = nil},
	SummonerTeleport = {name = "SummonerTeleport", shortName = "Teleport", range = nil},
	SummonerBarrier = {name = "SummonerBarrier", shortName = "Barrier", range = nil},
	SummonerExhaust = {name = "SummonerExhaust", shortName = "Exhaust", range = 550},
	SummonerDot = {name = "SummonerDot", shortName = "Ignite", range = 600},
	SummonerClairvoyance = {name = "SummonerClairvoyance", shortName = "Clairvoyance", range = nil},
	SummonerFlash = {name = "SummonerFlash", shortName = "Flash", range = 400}
}

function iSummoners:__init()
	self.SUMMONER_1 = _SummonerSpells[myHero:GetSpellData(SUMMONER_1).name]
	self.SUMMONER_1.slot = SUMMONER_1
	self.SUMMONER_2 = _SummonerSpells[myHero:GetSpellData(SUMMONER_2).name]
	self.SUMMONER_2.slot = SUMMONER_2
	self[self.SUMMONER_1.shortName] = self.SUMMONER_1
	self[self.SUMMONER_2.shortName] = self.SUMMONER_2
end

function iSummoners:AutoIgnite(dmgMultiplier)
	assert(not dmgMultiplier or (type(dmgMultiplier) == "number" and dmgMultiplier <= 100 and dmgMultiplier > 0), "Error: iSummoners:AutoIgnite(dmgMultiplier, invalid dmgMultiplier.")
	if self.Ignite and not myHero.dead and myHero:CanUseSpell(self.Ignite.slot) == READY then
		local dmgMultiplier = dmgMultiplier and dmgMultiplier / 100 or 1
		for _, enemy in ipairs(GetEnemyHeroes()) do
			if ValidTarget(enemy, self.Ignite.range) and getDmg("IGNITE", enemy, myHero) * dmgMultiplier > enemy.health then
				CastSpell(self.Ignite.slot, enemy)
			end
		end
	end
end

function iSummoners:AutoBarrier(maxHPPerc, procRate)
	assert(not maxHPPerc or (type(maxHPPerc) == "number" and maxHPPerc <= 100 and maxHPPerc > 0), "Error: iSummoners:AutoBarrier(maxHPPerc, procRate), invalid maxHPPerc.")
	assert(not procRate or (type(procRate) == "number" and procRate <= 100 and procRate > 0), "Error: iSummoners:AutoBarrier(maxHPPerc, procRate), invalid procRate.")
	if self.Barrier then
		local maxHPPerc = maxHPPerc and maxHPPerc / 100 or 0.3
		local procRate = procRate and procRate / 100 or 0.3
		if not self.Barrier.nextCheck then self.Barrier.nextCheck = 0 end
		if not self.Barrier.healthBefore then
			self.Barrier.healthBefore = {}
		elseif GetTickCount() >= self.Barrier.nextCheck then
			if myHero:CanUseSpell(self.Barrier.slot) == READY then
				local HPRatio = myHero.health / myHero.maxHealth
				local procHP = self.Barrier.healthBefore[1] * procRate 
				if myHero.health < procHP and maxHPPerc < HPRatio then
					CastSpell(self.Barrier.slot)
				end
			end
			self.Barrier.nextCheck = GetTickCount() + 100
			self.Barrier.healthBefore[#self.Barrier.healthBefore+1] = myHero.health
			if #self.Barrier.healthBefore > 10 then
				table.remove(self.Barrier.healthBefore, 1)
			end
		end
	end
end

function iSummoners:AutoRevive(condition)
	assert(not condition or type(condition) == "function", "Error: iSummoners:AutoRevive(condition), invalid condition.")
	if self.Revive and myHero.dead and myHero:CanUseSpell(self.Revive.slot) == READY and (not condition or condition()) then
		CastSpell(self.Revive.slot)
	end
end

function iSummoners:AutoClarity(maxManaPerc, condition)
	assert(not maxManaPerc or (type(maxManaPerc) == "number" and maxManaPerc <= 100 and maxManaPerc > 0), "Error: iSummoners:AutoClarity(maxManaPerc), invalid maxManaPerc.")
	if self.Clarity then
		local maxManaPerc = maxManaPerc and maxManaPerc / 100 or 0.3
		if myHero:CanUseSpell(self.Clarity.slot) == READY and myHero.mana / myHero.maxMana < maxManaPerc and (not condition or condition()) then
			CastSpell(self.Clarity.slot)
		end
	end
end

function iSummoners:AutoHeal(maxHPPerc, procRate, useForTeam)
	assert(not maxHPPerc or (type(maxHPPerc) == "number" and maxHPPerc <= 100 and maxHPPerc > 0), "Error: iSummoners:AutoHeal(maxHPPerc, procRate, useForTeam), invalid maxHPPerc.")
	assert(not procRate or (type(procRate) == "number" and procRate <= 100 and procRate > 0), "Error: iSummoners:AutoHeal(maxHPPerc, procRate, useForTeam), invalid procRate.")
	assert(useForTeam == nil or type(useForTeam) == "boolean", "Error: iSummoners:AutoHeal(maxHPPerc, procRate, useForTeam), invalid useForTeam")
	if self.Heal then
		local maxHPPerc = maxHPPerc and maxHPPerc / 100 or 0.3
		local procRate = procRate and procRate / 100 or 0.3
		local useForTeam = useForTeam ~= false
		if not self.Heal.nextCheck then self.Heal.nextCheck = 0 end
		if not self.Heal.healthBefore then
			self.Heal.healthBefore = {}
		elseif GetTickCount() >= self.Heal.nextCheck then
			if myHero:CanUseSpell(self.Heal.slot) == READY then
				local HPRatio = myHero.health / myHero.maxHealth
				local procHP = self.Heal.healthBefore[myHero.charName][1] * procRate 
				if myHero.health < procHP and maxHPPerc < HPRatio then
					CastSpell(self.Heal.slot)
				end
				if useForTeam then
					for _, ally in ipairs(GetAllyHeroes()) do
						if GetDistance(ally) < self.Heal.range and not ally.dead then
							local HPRatio = ally.health / ally.maxHealth
							local procHP = self.Heal.healthBefore[ally.charName][1] * procRate 
							if ally.health < procHP and maxHPPerc < HPRatio then
								CastSpell(self.Heal.slot)
							end
						end
					end
				end
			end
			self.Heal.nextCheck = GetTickCount() + 100
			self.Heal.healthBefore[myHero.charName][#self.Heal.healthBefore[myHero.charName]+1] = myHero.health
			if #self.Heal.healthBefore[myHero.charName] > 10 then
				table.remove(self.Heal.healthBefore[myHero.charName], 1)
			end
			for _, ally in ipairs(GetAllyHeroes()) do
				self.Heal.healthBefore[ally.charName][#self.Heal.healthBefore[ally.charName]+1] = ally.health
				if #self.Heal.healthBefore[ally.charName] > 10 then
					table.remove(self.Heal.healthBefore[ally.charName], 1)
				end
			end
		end
	end
end

function iSummoners:Exhaust(target) -- No AutoExhaust until I find a reliable logic. (No, AutoExhaust anyone below 50% HP is NOT reliable...)
	if self.Exhaust and ValidTarget(target, self.Exhaust.range) and myHero:CanUseSpell(self.Exhaust.slot) then
		CastSpell(self.Exhaust.slot, target)
	end
end

--[[ iTems ]]--

class 'iTems'

local itemsAliasForDmgCalc = { -- Item Aliases for spellDmg lib, including their corresponding itemID's.
	["DFG"] = 3128,
	["HXG"] = 3146,
	["BWC"] = 3144,
	["HYDRA"] = 3074,
	["SHEEN"] = 3057,
	["KITAES"] = 3186,
	["TIAMAT"] = 3077,
	["NTOOTH"] = 3115,
	["SUNFIRE"] = 3068,
	["WITSEND"] = 3091,
	["TRINITY"] = 3078,
	["STATIKK"] = 3087,
	["ICEBORN"] = 3025,
	["MURAMANA"] = 3042,
	["LICHBANE"] = 3100,
	["LIANDRYS"] = 3151,
	["BLACKFIRE"] = 3188,
	["HURRICANE"] = 3085,
	["RUINEDKING"] = 3153,
	["LIGHTBRINGER"] = 3185,
	["SPIRITLIZARD"] = 3209,
	--["ENTROPY"] = 3184,
}

function iTems:__init()
	self.items = {}
end

function iTems:add(name, ID, range, extraOptions)
	assert(type(name) == "string" and type(ID) == "number" and (not range or range == math.huge or type(range) == "number") and (extraOptions == nil or type(extraOptions) == "table"))
	self.items[name] = {ID = ID, range = range or math.huge, slot = nil, ready = false}
	for key, value in pairs(extraOptions) do
		self.items[name][key] = value
	end
end

function iTems:update()
	for itemName, item in pairs(self.items) do
		item.slot = GetInventorySlotItem(item.ID)
		item.ready = (item.slot and myHero:CanUseSpell(item.slot) == READY or false)
	end
end

function iTems:Have(itemID, unit)
	return GetInventorySlotItem(type(itemID) == "string" and self.items[itemID].ID or type(itemID) == "number" and itemID, unit) ~= nil
end

function iTems:Slot(itemID, unit)
	return GetInventorySlotItem(type(itemID) == "string" and self.items[itemID].ID or type(itemID) == "number" and itemID, unit)
end

function iTems:Dmg(itemID, target, source)
	if type(itemID) == "string" then
		if itemsAliasForDmgCalc[itemID] ~= nil then return getDmg(itemID, target, source or myHero) end
		if self.items[itemID] then
			for itemName, aliasID in pairs(itemsAliasForDmgCalc) do
				if self.items[itemID].ID == aliasID then return getDmg(itemName, target, source or myHero) end
			end
		end
	elseif type(itemID) == "number" then
		for itemName, aliasID in pairs(itemsAliasForDmgCalc) do
			if itemID == aliasID then return getDmg(itemName, target, source or myHero) end
		end
	end
	return 0
end

function iTems:InRange(itemID, enemy, source)
	if type(itemID) == "string" then return (self.items[itemID] and (not self.items[itemID].range or self.items[itemID].range > GetDistance(enemy, source or myHero))) end
	if type(itemID) == "number" then
		for _, item in pairs(self.items) do
			if itemID == item.ID then
				return (not item.range or item.range > GetDistance(enemy, source or myHero))
			end
		end
	end		
end

function iTems:Use(itemID, arg1, arg2, condition) -- Condition could be a function, such as (function(item) return item.slot ~= ITEM_6 end) or perhaps (function(item, target) return (target.health / target.maxHealth > 0.5) end)
	for itemName, item in pairs(self.items) do
		if type(itemID) == "string" and (itemID == "all" or itemID == itemName) or type(itemID) == "number" and itemID == item.ID then
			if item.ready and (condition == nil or condition(item, arg1, arg2)) then
				if arg2 then
					CastSpell(item.slot, arg1, arg2)
				elseif arg1 then
					if self:InRange(itemName, arg1) then
						CastSpell(item.slot, arg1)
					end
				else
					CastSpell(item.slot)
				end
			end
		end
	end
end

--[[ iMinions ]]--

class 'iMinions'

local _enemyMinions, _lastMinionsUpdate = nil, 0

function iMinions:__init(range, includeAD) -- includeAD adds myHero.totalDamage for AA's. Set to false if you wish to use iMinions for spells.
	enemyMinions_update(range)
	self.includeAD = includeAD ~= false
	self.ADDmg, self.APDmg, self.TrueDmg = 0, 0, 0
	self.killable = {}
end

function iMinions:setADDmg(damage) -- For additional on-hit AD damage
	self.ADDmg = damage or 0
end

function iMinions:setAPDmg(damage) -- For additional on-hit AP damage
	self.APDmg = damage or 0
end

function iMinions:setTrueDmg(damage) -- For additional on-hit True damage
	self.TrueDmg = damage or 0
end

function iMinions:update()
	enemyMinions_update()
	self.killable = {}
	for _, minion in ipairs(_enemyMinions.objects) do
		if ValidTarget(minion) then
			local damage = ((self.includeAD or self.ADDmg ~= 0) and (myHero:CalcDamage((self.includeAD and myHero.totalDamage) + self.ADDmg, minion)) or 0) + (self.APDmg ~= 0 and myHero:CalcMagicDamage(self.APDmg, minion) or 0) + self.TrueDmg
			self.killable[#self.killable+1] = minion
		end
	end
	return self.killable
end

function iMinions:marker(radius, colour, thickness)
	for _, minion in ipairs(self.killable) do
		if thickness and thickness > 1 then
			for i = 1, thickness do
				DrawCircle(minion.x, minion.y, minion.z, radius+i, colour)
			end
		else
			DrawCircle(minion.x, minion.y, minion.z, radius, colour)
		end
	end
end

function iMinions:LastHit(range, condition) -- Very basic, too tired to expand now.
	for _, minion in ipairs(self.killable) do
		if GetDistance(minion) < range and (not condition or condition(minion)) then
			myHero:Attack(minion)
			return minion
		end
	end
end

--[[ Other General Functions ]]--

function enemyMinions_update(range)
	if not _enemyMinions then
		_enemyMinions = minionManager(MINION_ENEMY, (range or 2000), myHero, MINION_SORT_HEALTH_ASC)
	elseif range and range > _enemyMinions.range then
		_enemyMinions.range = range
	end
	if _lastMinionsUpdate < GetTickCount() then
		_enemyMinions:update()
		_lastMinionsUpdate = GetTickCount()
	end
end

function iCollision(endPos, width) -- Derp collision, altered a bit for own readability.
	enemyMinions_update()
	if not endPos or not width then return end
	for _, minion in pairs(_enemyMinions.objects) do
		if ValidTarget(minion) and myHero.x ~= minion.x then
			local myX = myHero.x
			local myZ = myHero.z
			local tarX = endPos.x
			local tarZ = endPos.z
			local deltaX = myX - tarX
			local deltaZ = myZ - tarZ
			local m = deltaZ/deltaX
			local c = myX - m*myX
			local minionX = minion.x
			local minionZ = minion.z
			local distanc = (math.abs(minionZ - m*minionX - c))/(math.sqrt(m*m+1))
			if distanc < width and ((tarX - myX)*(tarX - myX) + (tarZ - myZ)*(tarZ - myZ)) > ((tarX - minionX)*(tarX - minionX) + (tarZ - minionZ)*(tarZ - minionZ)) then
				return true
			end
		end
   end
   return false
end