local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local mod = Skada:NewModule("DamageMode", "AceEvent-3.0")
local playermod = Skada:NewModule("DamageModePlayerView")
local spellmod = Skada:NewModule("DamageModeSpellView")

mod.name = L["Damage"]

function mod:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	Skada:AddMode(self)
end

function mod:OnDisable()
	Skada:RemoveMode(self)
end

function mod:AddToTooltip(set, tooltip)
	local endtime = set.endtime
	if not endtime then
		endtime = time()
	end
	local raiddps = set.damage / (endtime - set.starttime + 1)
 	GameTooltip:AddDoubleLine(L["DPS"], ("%02.1f"):format(raiddps), 1,1,1)
end

-- Called by Skada when a new player is added to a set.
function mod:AddPlayerAttributes(player)
	if not player.damage then
		player.damage = 0
		player.damagespells = {}
	end
end

-- Called by Skada when a new set is created.
function mod:AddSetAttributes(set)
	if not set.damage then
		set.damage = 0
	end
end

function mod:log_damage(set, dmg)
	if set then
		-- Get the player.
		local player = Skada:get_player(set, dmg.playerid, dmg.playername)
		if player then
		
			-- Subtract overkill
	--		local amount = math.max(0,dmg.amount - dmg.overkill)
			-- Or don't. Seems to be the way other meters do it.
			local amount = dmg.amount
	--		self:Print(player.name..": "..dmg.spellname.." for "..tostring(amount))
	
			-- Also add to set total damage.
			set.damage = set.damage + amount
			
			-- Add spell to player if it does not exist.
			if not player.damagespells[dmg.spellname] then
				player.damagespells[dmg.spellname] = {id = dmg.spellid, name = dmg.spellname, missed = 0, hit = 0, totalhits = 0, damage = 0, overkill = 0, resisted = 0, blocked = 0, absorbed = 0, critical = 0, glancing = 0, crushing = 0}
			end
			
			-- Add to player total damage.
			player.damage = player.damage + amount
			
			-- Get the spell from player.
			local spell = player.damagespells[dmg.spellname]
			
			spell.totalhits = spell.totalhits + 1
		
			spell.damage = spell.damage + amount
			if dmg.overkill then
				spell.overkill = spell.overkill + dmg.overkill
			end
			if dmg.resisted then
				spell.resisted = spell.resisted + dmg.resisted
			end
			if dmg.blocked then
				spell.blocked = spell.blocked + dmg.blocked
			end
			if dmg.absorbed then
				spell.absorbed = spell.absorbed + dmg.absorbed
			end
			if dmg.critical then
				spell.critical = spell.critical + dmg.critical
			elseif dmg.missed then
				spell.missed = spell.missed + 1
			else
				spell.hit = spell.hit + 1
			end
			if dmg.glancing then
				spell.glancing = spell.glancing + dmg.glancing
			end
			if dmg.crushing then
				spell.crushing = spell.crushing + dmg.crushing
			end
	
			-- Mark set as changed.
			set.changed = true
		end
	end
end

function mod:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	-- This line will determine if the src player is being tracked.
	if Skada:IsDataCollectionActive() and srcName and Skada:UnitIsInteresting(srcName) then
	
		local current = Skada:GetCurrentSet()
		local total = Skada:GetTotalSet()

		-- Spell damage.
		if eventtype == 'SPELL_DAMAGE' or eventtype == 'SPELL_PERIODIC_DAMAGE' or eventtype == 'SPELL_BUILDING_DAMAGE' or eventtype == 'RANGE_DAMAGE' then
			if not UnitIsUnit(srcName, dstName) then
				local spellId, spellName, spellSchool, samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...
				local dmg = {playerid = srcGUID, playername = srcName, spellid = spellId, spellname = spellName, amount = samount, overkill = soverkill, resisted = sresisted, blocked = sblocked, absorbed = sabsorbed, critical = scritical, glancing = sglancing, crushing = scrushing}
				Skada:FixPets(dmg)
				self:log_damage(current, dmg)
				self:log_damage(total, dmg)
			end
		elseif eventtype == 'SWING_DAMAGE' then
			-- White melee.
			if not UnitIsUnit(srcName, dstName) then
				local samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...
				local dmg = {playerid = srcGUID, playername = srcName, spellid = 6603, spellname = "Attack", amount = samount, overkill = soverkill, resisted = sresisted, blocked = sblocked, absorbed = sabsorbed, critical = scritical, glancing = sglancing, crushing = scrushing}
	
				Skada:FixPets(dmg)
				self:log_damage(current, dmg)
				self:log_damage(total, dmg)
			end
		elseif eventtype == 'SWING_MISSED' then
			-- Melee misses
			local dmg = {playerid = srcGUID, playername = srcName, spellid = 6603, spellname = "Attack", amount = 0, overkill = 0, resisted = 0, blocked = 0, absorbed = 0, critical = 0, glancing = 0, crushing = 0, missed = 1}
			
			Skada:FixPets(dmg)
			self:log_damage(current, dmg)
			self:log_damage(total, dmg)
					
		elseif eventtype == 'SPELL_DAMAGE_MISSED' or eventtype == 'SPELL_PERIODIC_MISSED' or eventtype == 'RANGE_MISSED' then
			-- Misses
			local spellId, spellName, spellSchool, missType, samount = ...
			local dmg = {playerid = srcGUID, playername = srcName, spellid = spellId, spellname = spellName, amount = 0, overkill = 0, resisted = 0, blocked = 0, absorbed = 0, critical = 0, glancing = 0, crushing = 0, missed = 1}
			
			Skada:FixPets(dmg)
			self:log_damage(current, dmg)
			self:log_damage(total, dmg)
		
		end
	end

end

function mod:Update(set)
	-- Calculate the highest damage.
	-- How to get rid of this iteration?
	local maxdamage = 0
	for i, player in ipairs(set.players) do
		if player.damage > maxdamage then
			maxdamage = player.damage
		end
	end
	
	-- Sort players according to healing done.
	table.sort(set.players, function(a,b) return a.damage > b.damage end)

	-- For each player in the set, see if we have a bar already.
	-- If so, update values, else create bar.
	for i, player in ipairs(set.players) do
		if player.damage > 0 then
			--Skada:Print("found "..player.name)
			local bar = Skada:GetBar(tostring(player.id))
			if bar then
				bar:SetMaxValue(maxdamage)
				bar:SetValue(player.damage)
			else
				bar = Skada:CreateBar(tostring(player.id), ("%2u. %s"):format(i, player.name), player.damage, maxdamage, nil, false)
				bar:EnableMouse()
				bar.playername = player.name
				bar:SetScript("OnMouseDown",function(bar, button)
												if button == "LeftButton" then
													playermod.name = player.name..L["'s Damage"]
													playermod.playerid = player.id
													Skada:DisplayMode(playermod)
												elseif button == "RightButton" then
													Skada:RightClick()
												end
											end)
				local color = Skada.classcolors[player.class] or Skada:GetDefaultBarColor()
				bar:SetColorAt(0, color.r, color.g, color.b, color.a)
			end
			bar:SetLabel(("%2u. %s"):format(i, player.name))
			local dps = player.damage / (player.last - player.first + 1)
			bar:SetTimerLabel(Skada:FormatNumber(player.damage)..(" (%02.1f, %02.1f%%)"):format(dps, player.damage / set.damage * 100))
		end
		
	end
	
	-- Sort the possibly changed bars.
	Skada:SortBars()
end

-- Detail view of a player.
function playermod:Update(set)
	-- View spells for this player.
		
	local player = Skada:get_selected_player(set, self.playerid)
	local color = Skada:GetDefaultBarColor()
	
	if player then
		for spellname, spell in pairs(player.damagespells) do
		
			local bar = Skada:GetBar(tostring(spellname))
			--self:Print("max: "..tostring(player.damage))
			--self:Print(spell.name..": "..tostring(spell.damage))
			if bar then
				bar:SetMaxValue(player.damage)
				bar:SetValue(spell.damage)
			else
				local icon = select(3, GetSpellInfo(spell.id))
			
				bar = Skada:CreateBar(spellname, spell.name, spell.damage, player.damage, icon, false)
				bar:SetColorAt(0, color.r, color.g, color.b, color.a)
				bar:ShowTimerLabel()
				bar:EnableMouse(true)
				bar:SetScript("OnMouseDown",function(bar, button)
												if button == "LeftButton" then
													spellmod.spellname = spellname
													spellmod.name = player.name.."'s "..spell.name
													Skada:DisplayMode(spellmod)
												elseif button == "RightButton" then
													Skada:DisplayMode(mod)
												end
											end)
				if icon then
					bar:ShowIcon()
				end
			end
			bar:SetTimerLabel(Skada:FormatNumber(spell.damage)..(" (%02.1f%%)"):format(spell.damage / player.damage * 100))
			
		end
	end
	
	-- Sort the possibly changed bars.
	Skada:SortBars()
end

local function add_detail_bar(title, value, maxvalue)
	local color = Skada:GetDefaultBarColor()
	local bar = Skada:GetBar(title)
	if bar then
		bar:SetMaxValue(maxvalue)
		bar:SetValue(value)
	else
		bar = Skada:CreateBar(title, title, value, maxvalue, nil, false)
		bar:SetColorAt(0, color.r, color.g, color.b, color.a)
		bar:EnableMouse(true)
		bar:SetScript("OnMouseDown", function(bar, button) if button == "RightButton" then Skada:DisplayMode(playermod) end end)
	end				
	bar:SetTimerLabel(("%u (%02.1f%%)"):format(value, value / maxvalue * 100))
end

function spellmod:Update(set)
	local player = Skada:get_selected_player(set,playermod.playerid)
	
	if player then
		local spell = player.damagespells[self.spellname]
		
		if spell then
			if spell.hit > 0 then
				add_detail_bar(L["Hit"], spell.hit, spell.totalhits)
			end
			if spell.critical > 0 then
				add_detail_bar(L["Critical"], spell.critical, spell.totalhits)
			end
			if spell.missed > 0 then
				add_detail_bar(L["Missed"], spell.missed, spell.totalhits)
			end
			---[[
			--This bit needs a section of its own somehow. Split the bar display maybe?
			if spell.resisted > 0 then
				add_detail_bar(L["Resisted"], spell.resisted, spell.totalhits)
			end
			if spell.blocked > 0 then
				add_detail_bar(L["Blocked"], spell.blocked, spell.totalhits)
			end
			if spell.glancing > 0 then
				add_detail_bar(L["Glancing"], spell.glancing, spell.totalhits)
			end
			if spell.absorbed > 0 then
				add_detail_bar(L["Absorbed"], spell.absorbed, spell.totalhits)
			end
			---]]
		end
	end

end
