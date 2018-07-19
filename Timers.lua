local UnitCastingInfo = UnitCastingInfo;
local UnitChannelInfo = UnitChannelInfo;
local GetItemInfo = GetItemInfo;
local GetSpellInfo = GetSpellInfo;
local GetSpellCooldown = GetSpellCooldown;
local GetSpellCharges = GetSpellCharges;
local GetTime = GetTime;
local UnitAura = UnitAura;
local GetItemCooldown = GetItemCooldown;
local GetRuneCooldown = GetRuneCooldown;
local GetRuneType = GetRuneType;
local GetTotemInfo = GetTotemInfo;
local GetWeaponEnchantInfo = GetWeaponEnchantInfo;
local GetInventoryItemTexture = GetInventoryItemTexture;
local GetGlyphSocketInfo = GetGlyphSocketInfo;
local GetSpecialization = GetSpecialization;
local GetSpecializationInfo = GetSpecializationInfo;
local GetTalentInfo = GetTalentInfo;
local UnitExists = UnitExists;
local UnitPower = UnitPower;
local UnitPowerMax = UnitPowerMax;
local UnitHealth = UnitHealth;
local UnitHealthMax = UnitHealthMax;
local UnitAlternatePowerInfo = UnitAlternatePowerInfo;
local UnitAlternatePowerTextureInfo = UnitAlternatePowerTextureInfo;
local UnitGetIncomingHeals = UnitGetIncomingHeals;
local select = select;
local pairs = pairs;
local ipairs = ipairs;
local wipe = wipe;
local tonumber = tonumber;
local string_find = string.find;
local string_match = string.match;
local string_gmatch = string.gmatch;
local string_trim = strtrim;
local string_gsub = string.gsub;
local string_len = strlenutf8;
local string_lower = string.lower;
local string_split = strsplit;
local strconcat = strconcat;
local table_insert = table.insert;

-- boolean operators for timer entries
local BOOLOP_NONE, BOOLOP_AND, BOOLOP_OR, BOOLOP_RELAXEDAND = 0, 1, 2, 3;

-- local variables
local _;

function Gnosis:ParseTimer_TrimCmd(line)
	return string_gsub(line, "^[%s%.,]*(.-)%s*$", "%1");
end

local function ParseTimer_IsComment(line)
	local comment = string_find(line, "^[%s%.,]*(%-%-)");
	
	if (comment) then
		return true;
	else
		return false;
	end
end

function Gnosis:ParseTimer_GetCommand(bnwlist, linetostart)
	local curcmd, boolop;
	
	-- is valid table?
	if (type(bnwlist) ~= "table") then
		return;
	end
	
	-- remove comments
	while (#bnwlist >= linetostart and ParseTimer_IsComment(bnwlist[linetostart])) do
		linetostart = linetostart + 1;		
	end
	
	if (linetostart > #bnwlist) then
		return;
	end
	
	-- grab first non comment (and remove tokens)
	-- remove tokens '\\'. '&', '+'. '*'
	-- '\\': append line; '&': previous and current line have to be valid, same as 'and'
	-- '?': either previous or current line has to be valid (or both)
	-- '*': simply compute line, same as 'or', belongs to previous '&' or '+'
	curcmd = string_match(bnwlist[linetostart], "^[%s%.,\\&%?%*]*(.*)")
	linetostart = linetostart + 1;
	if (not curcmd) then
		return;
	end	
	
	-- append lines beginning with '\\'
	while (linetostart <= #bnwlist) do
		if (ParseTimer_IsComment(bnwlist[linetostart])) then
			-- comment, next line
			linetostart = linetostart + 1;
		else	
			local token, append = string_match(bnwlist[linetostart], "^[%s%.,]*([\\&%?%*])[%s%.,\\&%?%*]*(.*)");
			
			if (token) then
				if (token == "\\") then
					-- append line
					curcmd = curcmd .. " " .. append;
					linetostart = linetostart + 1;			
				elseif (token == "&") then
					boolop = BOOLOP_AND;
					break;
				elseif (token == "?") then
					boolop = BOOLOP_RELAXEDAND;
					break;
				elseif (token == "*") then
					boolop = BOOLOP_OR;
					break;	
				else
					break;
				end
			else
				break;
			end
		end
	end
	
	return curcmd, linetostart, boolop;
end

local function in_value_range(cur_val, cur_val_perc, range_tab)
	--[[ range_tab structure
		[1] == value lower bound (>=)
		[2] == value upper bound (<=)
		[3] == stacks lower bound (>=)
		[4] == stacks upper bound (<=)
		[5] == value lower bound is in percent (true, nil)
		[6] == value upper bound is in percent (true, nil) ]]

	if(range_tab[1]) then
		if(range_tab[5]) then
			if(cur_val_perc < range_tab[1]) then
				return false;
			end
		elseif(cur_val < range_tab[1]) then
			return false;
		end
	end

	if(range_tab[2]) then
		if(range_tab[6]) then
			if(cur_val_perc > range_tab[2]) then
				return false;
			end
		elseif(cur_val > range_tab[2]) then
			return false;
		end
	end

	return true;
end

local function in_stacks_range(stacks, range_tab)
	if(range_tab[3]) then
		if(not stacks or stacks < range_tab[3]) then
			return false;
		end
	end

	if(range_tab[4]) then
		if(not stacks or stacks > range_tab[4]) then
			return false;
		end
	end

	return true;
end

local function set_not(ti)
	ti.bChannel = true;
	ti.dur = 1;
	ti.fin = 1;
	ti.bSpecial = true;
	ti.valIsStatic = true;
	ti.ok = true;
end

local function set_times(timer, ti, dur, fin, ischannel)
	if (ti.ok) then
		if (timer.bNot) then
			ti.ok = nil;
		else
			if (ti.valIsStatic or timer.bExists) then
				set_not(ti);
			else
				ti.bChannel = ischannel;
				ti.dur = dur;
				ti.fin = fin;
			end
		end
	elseif (timer.bNot) then
		set_not(ti);
	end
end

function Gnosis:Timers_Spell(bar, timer, ti)
	-- cast
	local spell, _, icon, s, d, _, _, notInterruptible = UnitCastingInfo(timer.unit);
	if(d and d > 0) then
		if(timer.spell == "all" or timer.spell == "any" or timer.spell == spell) then
			ti.cname = spell;
			ti.icon = icon;
			ti.unit = timer.unit;
			ti.notInterruptible = notInterruptible or nil;
			local dur, fin = d-s, d;
			if(timer.brange) then
				local rem = fin/1000-GetTime();
				ti.ok = in_value_range(rem, rem*100000/dur, timer.range_tab);
			else
				ti.ok = true;
			end
			set_times(timer, ti, dur, fin, false);
		end
	else
		spell, _, icon, s, d, _, _, notInterruptible = UnitChannelInfo(timer.unit);
		if(d and d > 0) then
			if(timer.spell == "all" or timer.spell == "any" or timer.spell == spell) then
				ti.cname = spell;
				ti.icon = icon;
				ti.unit = timer.unit;
				ti.notInterruptible = notInterruptible or nil;
				local dur, fin = d-s, d;
				if(timer.brange) then
					local rem = fin/1000-GetTime();
					ti.ok = in_value_range(rem, rem*100000/dur, timer.range_tab);
				else
					ti.ok = true;
				end
				set_times(timer, ti, dur, fin, true);
			end
		end
	end
end

function Gnosis:Timers_SpellCD(bar, timer, ti)
	-- cooldown, player only
	ti.unit = "player";
	local s, d = GetSpellCooldown(timer.spell);
	
	local dur, fin;
	local cd_info = Gnosis.timer_cds[timer.spell];
	local curtime = GetTime();
	if (d and d <= 1.5 and cd_info and curtime < cd_info.fin and (s+d) >= cd_info.fin) then
		-- duration of the global cooldown
		dur, fin = cd_info.dur, cd_info.fin;
	elseif (d and d > 1.5) then
		-- duration greater than global cd
		dur, fin = d, s + d;
		
		if (cd_info) then
			cd_info.dur = dur;
			cd_info.fin = fin;
		else
			Gnosis.timer_cds[timer.spell] = { dur = dur, fin = fin };
		end
	end
		
	if (dur) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		
		if(timer.brange) then
			local rem = fin - curtime;
			ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur*1000, fin*1000, true);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_Counter(bar, timer, ti)
	ti.unit = "player";
	
	local cnter = Gnosis.counters[timer.spell];
	if (cnter and cnter.endtime < GetTime()) then
		cnter = nil;
	end
	
	if (cnter) then
		ti.cname = timer.spell;
		if (timer.brange) then
			local curcnt = GetTime() - cnter.starttime;
			local totcnt = cnter.endtime - cnter.starttime;
			ti.ok = in_value_range(curcnt, curcnt*100/totcnt, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti,
			(cnter.endtime-cnter.starttime)*1000,
			cnter.endtime*1000,
			true
		);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		set_not(ti);
	end
end

local function GetAura(timer, unit)
	if (timer.spellid) then
		-- aura id
		local _, name, ic, sta, d, s, eff1, eff2, eff3, id;
		local i = 1;
		
		repeat
			name, ic, sta, _, d, s, _, _, _, id, _, _, _, _, _, eff1, eff2, eff3 =
				UnitAura(unit, i, timer.filter);
			
			if (id and id == timer.spellid) then
				timer.spell = name;
				
				if (timer.auraeffect3) then
					if (eff3 and eff3 > 0) then
						return ic, sta, timer.auraeffect3, eff3, eff3, true;
					end
				elseif (timer.auraeffect2) then
					if (eff2 and eff2 > 0) then
						return ic, sta, timer.auraeffect2, eff2, eff2, true;
					end
				elseif (timer.auraeffect1) then
					if (eff1 and eff1 > 0) then
						return ic, sta, timer.auraeffect1, eff1, eff1, true;
					end
				elseif (timer.aurastacks) then
					if (sta and sta > 0) then
						return ic, sta, timer.aurastacks, sta, eff1, true;
					end
				else
					-- timer bar
					return ic, sta, d, s, eff, false;
				end
				
				-- nothing to return
				return ic;				
			end
			
			i = i + 1;
		until id == nil or i > 40;

		return;
	else
		-- aura name
		local _, ic, sta, _, d, s, _, _, _, _, _, _, _, _, _, eff1, eff2, eff3 =
			AuraUtil.FindAuraByName(timer.spell, unit, timer.filter);
		
		if (timer.auraeffect3) then
			if (eff3 and eff3 > 0) then
				return ic, sta, timer.auraeffect3, eff3, eff3, true;
			end
		elseif (timer.auraeffect2) then
			if (eff2 and eff2 > 0) then
				return ic, sta, timer.auraeffect2, eff2, eff2, true;
			end
		elseif (timer.auraeffect1) then
			if (eff1 and eff1 > 0) then
				return ic, sta, timer.auraeffect1, eff1, eff1, true;
			end
		elseif (timer.aurastacks) then
			if (sta and sta > 0) then
				return ic, sta, timer.aurastacks, sta, eff1, true;
			end
		else
			-- timer bar
			return ic, sta, d, s, eff, false;
		end
		
		-- nothing to return
		return ic;
	end	
end

function Gnosis:Timers_Aura(bar, timer, ti)
	-- aura == buff or debuff (== hot or dot)
	ti.unit = timer.unit;
	local ic, sta, d, s, effect, isspecial = GetAura(timer, timer.unit);
	
	if (s) then
		ti.cname = timer.spell;
		ti.stacks = (sta and sta > 0) and sta or nil;		
		ti.icon = ic;
		
		if (isspecial) then
			ti.unit = timer.unit;
			ti.bSpecial = true;
			
			if (timer.brange) then
				ti.ok = in_value_range(s, s*100/d, timer.range_tab);
			else
				ti.ok = true;
			end
			set_times(timer, ti, d, s, true);
		else
			local rem = 0;		
			if (s > 0) then
				rem = s - GetTime();
			end
			
			if (rem > 0) then
				-- dynamic aura
				if (timer.brange) then
					if (in_value_range(rem, rem*100/d, timer.range_tab) and
							in_stacks_range(sta, timer.range_tab)) then
						ti.ok = true;
					end
				else
					ti.ok = true;
				end
				set_times(timer, ti, d * 1000, s * 1000, true);
			elseif (s == 0 and d == 0 and not timer.bNot) then
				-- static aura
				if (timer.brange) then
					if (in_stacks_range(sta, timer.range_tab)) then
						ti.ok = true;
					end
				else
					ti.ok = true;
				end
				ti.valIsStatic = true;
				set_times(timer, ti);
			end
		end
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_GroupAura(bar, timer, ti)
	ti.unit = nil;
	
	-- scan current group for aura, also scan existing pets
	local _, ic, sta, d, s, effect, isspecial;
	
	local n = GetNumGroupMembers();
	if (IsInRaid() and n >= 2) then
		-- scan raid
		for i = 1, n do
			local curunit = "raid" .. i;
			ic, sta, d, s, effect, isspecial = GetAura(timer, curunit);
			
			if (s) then
				ti.unit = curunit;
				break;
			end
			
			curunit = "raidpet" .. i;
			if (UnitExists(curunit)) then
				ic, sta, d, s, effect, isspecial = GetAura(timer, curunit);
			
				if (s) then
					ti.unit = curunit;
					break;
				end
			end
		end
	elseif (n >= 2) then
		-- scan player and group members
		ic, sta, d, s, effect, isspecial = GetAura(timer, "player");
		
		if (s) then
			ti.unit = "player";
		else
			if (UnitExists("playerpet")) then
				ic, sta, d, s, effect, isspecial = GetAura(timer, "playerpet");
			end
			
			if (s) then
				ti.unit = "playerpet";
			else
				for i = 1, (n - 1) do
					local curunit = "party" .. i;
					ic, sta, d, s, effect, isspecial = GetAura(timer, curunit);
					
					if (s) then
						ti.unit = curunit;
						break;
					end
					
					curunit = "partypet" .. i;
					if (UnitExists(curunit)) then
						ic, sta, d, s, effect, isspecial = GetAura(timer, curunit);
					
						if (s) then
							ti.unit = curunit;
							break;
						end
					end
				end
			end
		end
	else
		-- scan player (player not in group)
		ic, sta, d, s, effect, isspecial = GetAura(timer, "player");
		
		if (s) then
			ti.unit = "player";
		else
			if (UnitExists("playerpet")) then
				ic, sta, d, s, effect, isspecial = GetAura(timer, "playerpet");
				
				if (s) then
					ti.unit = "playerpet";
				end
			end
		end
	end
	
	if (ti.unit) then
		ti.cname = timer.spell;
		ti.stacks = (sta and sta > 0) and sta or nil;
		ti.effect = effect;	
		ti.icon = ic;
		
		if (isspecial) then
			ti.unit = timer.unit;
			ti.bSpecial = true;
			
			if (timer.brange) then
				ti.ok = in_value_range(s, s*100/d, timer.range_tab);
			else
				ti.ok = true;
			end
			set_times(timer, ti, d, s, true);
		else
			local rem = 0;		
			if (s > 0) then
				rem = s - GetTime();
			end
			
			if (rem > 0) then
				-- dynamic aura
				if (timer.brange) then
					if (in_value_range(rem, rem*100/d, timer.range_tab) and
							in_stacks_range(sta, timer.range_tab)) then
						ti.ok = true;
					end
				else
					ti.ok = true;
				end
				set_times(timer, ti, d * 1000, s * 1000, true);
			elseif (s == 0 and d == 0 and not timer.bNot) then
				-- static aura
				if (timer.brange) then
					if (in_stacks_range(sta, timer.range_tab)) then
						ti.ok = true;
					end
				else
					ti.ok = true;
				end
				ti.valIsStatic = true;
				set_times(timer, ti);
			end
		end
	elseif (timer.bNot) then
		ti.unit = timer.unit;
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_SpellRecharge(bar, timer, ti)
	-- spell charges, player only
	ti.unit = "player";
	
	local curcharges, maxcharges, cdstart, cddur = GetSpellCharges(timer.spell);
		
	if (curcharges == nil) then
		return;
	end
	
	if (timer.chargecnt) then
		-- display amount of charges
		ti.cname = timer.spell;
		ti.icon = timer.icon;
		ti.bSpecial = true;
		
		if (timer.brange) then
			ti.ok = in_value_range(curcharges, curcharges*100/maxcharges, timer.range_tab);
		else
			ti.ok = true;
		end
		
		set_times(timer, ti, maxcharges, curcharges);
	else
		-- recharge cooldown
		if (curcharges ~= maxcharges) then
			if (timer.brange) then
				local rem = cddur-(GetTime()-cdstart);
				ti.ok = in_value_range(rem, rem*100/cddur, timer.range_tab) and
					in_stacks_range(curcharges, timer.range_tab);
			else
				ti.ok = true;
			end
			
			ti.cname = timer.spell;
			ti.stacks = curcharges;
			ti.icon = timer.icon;
			
			set_times(timer, ti, cddur*1000, (cdstart+cddur)*1000, true);
		elseif (timer.bNot) then			
			ti.cname = timer.spell;
			ti.stacks = curcharges;
			ti.icon = timer.icon;
			set_not(ti);
		end
	end
end

function Gnosis:Timers_ItemCD(bar, timer, ti)
	-- itemcd, player only
	if (not timer.iid) then
		local itemname, link, _, _, _, _, _, _, _, itex = GetItemInfo(timer.spell);
		if (link) then
			timer.iid = string_match(link, "|Hitem:(%d+):");
			timer.itex = itex;
			timer.iname = itemname;
		end
	end

	if (timer.iid) then
		ti.unit = "player";
		local s, d = GetItemCooldown(timer.iid);
		if (d and d > 1.5) then	-- duration greater than global cd
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			local dur, fin = d, s+d;
			if (timer.brange) then
				local rem = fin - GetTime();
				ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
			else
				ti.ok = true;
			end
			set_times(timer, ti, dur*1000, fin*1000, true);
		elseif (timer.bNot) then
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			set_not(ti);
		end
	end
end

function Gnosis:Timers_ItemEquipped(bar, timer, ti)
	-- item equipped? player only	
	if (not timer.iid) then
		local itemname, link, _, _, _, _, _, _, _, itex = GetItemInfo(timer.spell);
		if (link) then
			timer.iid = string_match(link, "|Hitem:(%d+):");
			timer.itex = itex;
			timer.iname = itemname;
		end
	end
	
	if (timer.iname) then
		ti.unit = "player";
		if (IsEquippedItem(timer.iname)) then
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			ti.ok = true;
			ti.valIsStatic = true;
			set_times(timer, ti);
		elseif (timer.bNot) then
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			set_not(ti);
		end
	end
end

function Gnosis:Timers_RuneCD(bar, timer, ti)
	-- rune cooldown, player only
	ti.unit = "player";
	
	-- check for runetype
	local rune = GetRuneType(timer.spell);
	if (rune and timer.runetype and timer.runetype ~= rune) then
		return;
	end
	
	-- check cooldown
	local s, d, rdy = GetRuneCooldown(timer.spell);
	if (s and (not rdy) and (s+d) >= GetTime()) then	
		if (rune) then
			ti.cname = Gnosis.tRuneName[rune];
			ti.icon = Gnosis.tRuneTexture[rune];
		else
			ti.cname = "";
			ti.icon = nil;
		end
		local dur, fin = d, s+d;
		if (timer.brange) then
			local rem = fin - GetTime();
			ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur*1000, fin*1000, true);
	elseif (timer.bNot) then
		if (rune) then
			ti.cname = Gnosis.tRuneName[rune];
			ti.icon = Gnosis.tRuneTexture[rune];
		else
			ti.cname = "";
			ti.icon = nil;
		end
		set_not(ti);
	end
end

function Gnosis:Timers_TotemDuration(bar, timer, ti)
	-- totem duration
	ti.unit = "player";
	local bExist, name, s, d, icon = GetTotemInfo(timer.spell);
	if(bExist and name and s and s > 0) then
		ti.cname = name;
		ti.icon = icon;
		local dur, fin = d, s+d;
		if(timer.brange) then
			local rem = fin - GetTime();
			ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur*1000, fin*1000, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		set_not(ti);
	end
end

function Gnosis:Timers_InnerCD(bar, timer, ti)
	ti.unit = "player";
	local bExist = false;
	if (Gnosis.ti_icd_active[timer.spell]) then
		if (GetTime() * 1000 >= Gnosis.ti_icd_active[timer.spell]) then
			-- inner cd expired
			Gnosis.ti_icd_active[timer.spell] = nil;
		else
			bExist = true;
		end
	end
	
	if (bExist) then
		ti.cname = timer.spell;
		ti.icon = timer.icon;
		local dur, fin = Gnosis.ti_icd[timer.spell].duration, Gnosis.ti_icd_active[timer.spell];
		if(timer.brange) then
			local rem = fin / 1000 - GetTime();
			ti.ok = in_value_range(rem, rem*100000/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur, fin, true);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon;
		set_not(ti);
	end
end

function Gnosis:Timers_WeaponEnchant(bar, timer, ti, exists, expires, charges)
	-- weapon enchant (player only)
	if(exists) then
		ti.cname = timer.spell;
		local dur = expires;
		local fin = expires + GetTime()*1000;
		local bardur = (bar.dur or bar.duration);
		if(timer.spell == bar.castname and bardur and bardur > dur) then
			dur = bardur;
		end
		if(timer.brange) then
			local rem = expires;
			ti.ok = in_value_range(rem/1000, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur, fin, true);
	end
end

function Gnosis:Timers_WeaponEnchantMain(bar, timer, ti)
	ti.unit = "player";
	local exists, expires, charges = select(1, GetWeaponEnchantInfo());
	if(exists) then
		local tt = Gnosis.tooltip;

		tt:ClearLines();
		tt:SetInventoryItem("player", 16);

		local num = tt:NumLines();
		for i = 1, num do
			if(string_find(_G["GnosisGameTooltipTextLeft"..i]:GetText(), timer.spell)) then
				ti.icon = GetInventoryItemTexture("player", 16);
				Gnosis:Timers_WeaponEnchant(bar, timer, ti, exists, expires, charges);
			end
		end
	elseif(timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = GetInventoryItemTexture("player", 16);
		set_not(ti);
	end
end

function Gnosis:Timers_WeaponEnchantOff(bar, timer, ti)
	ti.unit = "player";
	local exists, expires, charges = select(4, GetWeaponEnchantInfo());
	if(exists) then
		local tt = Gnosis.tooltip;
		tt:ClearLines();
		tt:SetInventoryItem("player", 17);

		local num = tt:NumLines();
		for i = 1, num do
			if(string_find(_G["GnosisGameTooltipTextLeft"..i]:GetText(), timer.spell)) then
				ti.icon = GetInventoryItemTexture("player", 17);
				Gnosis:Timers_WeaponEnchant(bar, timer, ti, exists, expires, charges);
			end
		end
	elseif(timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = GetInventoryItemTexture("player", 17);
		set_not(ti);
	end
end

function Gnosis:Timers_Range(bar, timer, ti)
	-- range between player and selected unit
	local minRange, maxRange;
	
	if (UnitExists(timer.unit)) then
		minRange, maxRange = Gnosis.range:GetRange(timer.unit);
	end
	
	if (minRange and maxRange) then
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if (timer.brange) then
			--[[ range_tab structure
				[1] == value lower bound (>=)
				[2] == value upper bound (<=)
				[3] == stacks lower bound (>=)
				[4] == stacks upper bound (<=)
				[5] == value lower bound is in percent (true, nil)
				[6] == value upper bound is in percent (true, nil) ]]
			
			if (timer.range_tab[5] or timer.range_tab[6]) then
				-- percentages of what??? (not allowed)
				ti.ok = false;
			else
				if (minRange <= (timer.range_tab[2] or 10000) and
					maxRange >= (timer.range_tab[1] or 0)) then
					ti.ok = true;
				end
			end
		else
			ti.ok = true;
		end
		set_times(timer, ti, maxRange, minRange, true);
	elseif (timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Power(bar, timer, ti)
	-- mana, rage, focus, energy
	local s, d = UnitPower(timer.unit), UnitPowerMax(timer.unit);
	if(d and d > 0) then
		local pts = select(2, UnitPowerType(timer.unit));
		ti.cname = pts and _G[pts] or "";
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_PowerGeneric(bar, timer, ti)
	-- soul shards, eclipse, holy power, dark force, light force (chi)
	-- shadow orbs, burning embers and demonic fury
	-- combo points (6.0)
	local idx = timer.type - 2000;
	local s, d = UnitPower(timer.unit, idx, timer.resource_decimals), UnitPowerMax(timer.unit, idx, timer.resource_decimals);
	if (d and d > 0) then
		-- values including decimals?
		if (timer.resource_decimals) then
			s = s / 10;
			d = d / 10;
		end
		
		-- get name and icon of the effect
		if (not ti.cname or ti.cname == "") then
			ti.cname =
					(idx == 4 and _G["COMBO_POINTS"]) or
					(idx == 7 and _G["SOUL_SHARDS"]) or
					(idx == 8 and _G["ECLIPSE"]) or
					(idx == 9 and _G["HOLY_POWER"]) or
					(idx == 12 and _G["LIGHT_FORCE"]) or
					(idx == 13 and _G["SHADOW_ORBS"]) or
					(idx == 14 and _G["BURNING_EMBERS"]) or
					(idx == 15 and _G["DEMONIC_FURY"]) or
				"";
			ti.icon = select(3, GetSpellInfo(
					(idx == 4 and 108209) or	-- combo points, no exact icon match
					(idx == 7 and 117198) or	-- soul shards
					(idx == 8 and 79577) or		-- eclipse
					(idx == 9 and 85247) or		-- holy power
					(idx == 12 and 157411) or	-- chi, no exact icon match
					(idx == 13 and 95740) or	-- shadow orbs
					(idx == 14 and 108647) or	-- burning embers
					(idx == 15 and 104315) or	-- demonic fury
					nil
				)); 
		end
		
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if (timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif (timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Experience(bar, timer, ti)
	local xp = UnitXP("player");
	local xpmax = UnitXPMax("player");
	
	if (xp and xpmax) then
		ti.icon = nil;
		ti.unit = "player";
		ti.bSpecial = true;
		if (timer.brange) then
			ti.ok = in_value_range(xp, xp*100/xpmax, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, xpmax, xp, true);
	end
end

function Gnosis:Timers_RestedXP(bar, timer, ti)
	local rested = GetXPExhaustion();
	local xpmax = UnitXPMax("player");
	
	if (rested and xpmax) then
		ti.icon = nil;
		ti.unit = "player";
		ti.bSpecial = true;
		if (timer.brange) then
			ti.ok = in_value_range(rested, min(rested*100/xpmax, 100), timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, xpmax, rested, true); 
	end
end

function Gnosis:Timers_Health(bar, timer, ti)
	local s, d = UnitHealth(timer.unit), UnitHealthMax(timer.unit);
	if(d and d > 0) then
		ti.cname = _G["HEALTH"];
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_PowerAlternate(bar, timer, ti)
	local s, d = UnitPower(timer.unit, ALTERNATE_POWER_INDEX), UnitPowerMax(timer.unit, ALTERNATE_POWER_INDEX);
	if(d and d > 0) then
		local altpowerinfo_cname = select(11, UnitAlternatePowerInfo(timer.unit));
		ti.cname = altpowerinfo_cname or "";
		ti.icon = UnitAlternatePowerTextureInfo(timer.unit, 2);
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_IncomingHealth(bar, timer, ti)
	local s, d = UnitGetIncomingHeals(timer.unit), UnitHealthMax(timer.unit);
	if(s and d and d > 0) then
		ti.cname = "";
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_TargetThreat(bar, timer, ti)
	local _, status, pct, _, val = UnitDetailedThreatSituation(timer.unit, "target");
	if(status and pct > 0) then
		val = val / 100;
		ti.cname = "";
		ti.unit = timer.unit;
		ti.bSpecial = true;
		ti.stacks = status;
		if(timer.brange) then
			if(in_value_range(val, pct, timer.range_tab) and
					in_stacks_range(status, timer.range_tab)) then
				ti.ok = true;
			end
		else
			ti.ok = true;
		end
		set_times(timer, ti, val * 100 / pct, val, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Fixed(bar, timer, ti)
	-- show fixed bar (pass text in nfs)
	ti.unit = "player";
	ti.cname = "";
	ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
	set_not(ti);
end

function Gnosis:Timers_SpellKnown(bar, timer, ti)
	ti.unit = "player";
	if (GetSpellLink(timer.spell)) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		ti.ok = true;
		ti.valIsStatic = true;
		set_times(timer, ti);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_UnitName(bar, timer, ti)
	local n = UnitName(timer.unit);
	
	if (n and (timer.spell == "any" or n == timer.spell)) then
		ti.cname = n;
		ti.unit = timer.unit;
		ti.ok = true;
		ti.valIsStatic = true;
		set_times(timer, ti);
		return;
	end
	
	if (timer.bNot) then
		ti.cname = timer.spell;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Npc(bar, timer, ti)
	local guid = UnitGUID(timer.unit);
	
	if (guid) then
		local _, _, _, _, _, npc_id, _ = string_split("-", guid);
		
		if (npc_id and (timer.spell == "any" or npc_id == timer.spell)) then
			ti.cname = npc_id;
			ti.unit = timer.unit;
			ti.ok = true;
			ti.valIsStatic = true;
			set_times(timer, ti);
			return;
		end
	end
	
	if (timer.bNot) then
		ti.cname = timer.spell;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Charspec(bar, timer, ti)
	local current_spec = GetSpecialization();
	
	if (current_spec) then
		-- spec active
		local spec_id, spec_name = GetSpecializationInfo(current_spec);
		local spell_number = tonumber(timer.spell);
		
		local matched = false;
		-- try to compare to specialization id first
		-- http://www.wowwiki.com/Specialization_IDs
		if (spell_number and spell_number == spec_id) then
			matched = true;			
		-- otherwise compare to string
		elseif (timer.spell == spec_name) then
			matched = true;
		end
		
		if (matched) then
			ti.cname = spec_name;
			ti.unit = "player";
			ti.ok = true;
			ti.valIsStatic = true;
			set_times(timer, ti);
		elseif (timer.bNot) then
			ti.cname = spec_name;
			ti.unit = "player";
			set_not(ti);			
		end
	end
end

function Gnosis:Timers_Talent(bar, timer, ti)
	if (Gnosis.iCurSpec) then
		local tier, column = string_split("-", timer.spell);
		
		if (tier and column) then
			local tier_num = tonumber(tier);
			local column_num = tonumber(column);
			
			if (tier_num and column_num) then
				--local _, tname, ttex, tsel = GetTalentInfo(tier_num, column_num, Gnosis.iCurSpec);
				-- bandaid...
				local _, tname, ttex, tsel = GetTalentInfo(tier_num, column_num, 1);
				
				-- talent selected?
				if (tsel) then
					ti.cname = tname;
					ti.unit = "player";
					ti.icon = ttex;
					ti.ok = true;
					ti.valIsStatic = true;
					set_times(timer, ti);
				elseif (timer.bNot and tname) then
					ti.cname = tname;
					ti.unit = "player";
					ti.icon = ttex;
					set_not(ti);
				end
			end
		end
	end
end

function Gnosis:Timers_Glyph(bar, timer, ti)
	-- check for glyph match
	local matched, glyph_name, glyph_icon;
	local spellnum = tonumber(timer.spell);
	
	for i=1, NUM_GLYPH_SLOTS do
		local valid, _, _, id = GetGlyphSocketInfo(i);
		
		if (valid) then
			glyph_name, _, glyph_icon = GetSpellInfo(id);
			
			if (spellnum) then
				if (spellnum == id) then
					matched = true;
					break;
				end
			elseif (glyph_name == timer.spell) then
				matched = true;
				break;
			end
		end
	end
	
	-- glyph found
	if (matched) then
		ti.cname = glyph_name;
		ti.unit = "player";
		ti.icon = glyph_icon;
		ti.ok = true;
		ti.valIsStatic = true;
		set_times(timer, ti);
	-- glyph not found
	elseif (timer.bNot) then
		ti.unit = "player";
		
		if (spellnum) then
			local sname, _, stex = GetSpellInfo(spellnum);
			
			if (sname) then
				ti.cname = sname;
				ti.icon = stex;
				set_not(ti);
			end
		else
			ti.cname = timer.spell;
			set_not(ti);
		end		
	end
end

function Gnosis:Timers_GlobalCD(bar, timer, ti)
	local gcd = Gnosis.current_gcd;
	local rem = gcd and (gcd.finish - GetTime()) or 0;
	
	if (rem > 0 and (timer.spell == "any" or gcd.spell == timer.spell)) then
		ti.cname = gcd.spell;
		ti.unit = "player";
		ti.icon = timer.icon or select(3, GetSpellInfo(gcd.spellid));
		if (timer.brange) then
			ti.ok = in_value_range(rem, rem*100/gcd.cd, timer.range_tab);			
		else
			ti.ok = true;
		end
		set_times(timer, ti, gcd.cd*1000, gcd.finish*1000);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.unit = "player";
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_Exit(bar, timer, ti)
	ti.ok = true;
end

function Gnosis:ExtractRegex(str, regex_a, regex_b, dotrim)
	local res = string_match(str, regex_a);
	if (res) then
		if (dotrim) then
			res = string_trim(res);
		end
		return res, string_gsub(str, regex_a, "");
	elseif (regex_b) then
		res = string_match(str, regex_b);
		if (res) then
			if (dotrim) then
				res = string_trim(res);
			end
			return res, string_gsub(str, regex_b, "");
		else
			return nil, str;
		end
	else
		return nil, str;
	end
end

-- local functions
local function validate_value(val, isperc)
   if(val and tonumber(val)) then
      val = tonumber(val);
      if(isperc) then
         if(val > 100) then
            return 100;
         elseif(val < 0) then
            return 0;
         else
            return val;
         end
      elseif(val < 0) then
         return 0;
      else
         return val;
      end
   end

   return nil;
end

local function validate_value(val, isperc)
	if(val and tonumber(val)) then
		val = tonumber(val);
		if(isperc) then
			if(val > 100) then
				return 100;
			elseif(val < 0) then
				return 0;
			else
				return val;
			end
		elseif(val < 0) then
			return 0;
		else
			return val;
		end
	end

	return nil;
end

local function get_valid_range_table(spell_string)
	local res, str = Gnosis:ExtractRegex(spell_string, "<([^>]*)>", nil, true);
	str = string_trim(str);

	local cnt = 1;
	if(res) then
		res = strconcat(res, ",,,");
		local low_val, up_val, low_st, up_st, blow_val_perc, bup_val_perc;
		low_val, up_val, low_st, up_st = string_match(res, "([^,]*),([^,]*),([^,]*),([^,]*)");

		low_st = tonumber(low_st);
		up_st = tonumber(up_st);

		low_val, cnt = string_gsub(low_val, "%%", "");
		if(cnt > 0) then
			blow_val_perc = true;
		end
		up_val, cnt = string_gsub(up_val, "%%", "");
		if(cnt > 0) then
			bup_val_perc = true;
		end

		-- values valid?
		low_val = validate_value(low_val, blow_val_perc);
		up_val = validate_value(up_val, bup_val_perc);
		low_st = validate_value(low_st);
		up_st = validate_value(up_st);

		if(low_val or up_val or low_st or up_st) then
			local t = { low_val, up_val, low_st, up_st, blow_val_perc, bup_val_perc };
			return str, true, t;
		end
	end

	return str, nil, nil;
end

local TimerInfo = {
};

local SelectedTimerInfo = {
};

function Gnosis:CreateSingleTimerTable()
	-- wipe tables
	wipe(self.ti_fl);
	wipe(self.ti_icd);
	wipe(self.counters);
	
	for key, value in pairs(self.castbars) do
		local conf = Gnosis.s.cbconf[key];
		local timer_id = 0;

		if (conf.bEn and conf.bartype == "ti" and conf.spectab[self.iCurSpec]) then
			value.timers = {};
			value.iTimerSort = nil;

			local curline = 1;
			while (curline) do
				-- timer id
				timer_id = timer_id + 1;

				-- copy of timer command string
				local str, cmd_boolop;
				str, curline, cmd_boolop = self:ParseTimer_GetCommand(conf.bnwlist, curline);
				
				if (not str) then
					break;
				end

				local unit, recast, staticdur, zoom, specstr, iconoverride, portraitunit,
					shown, hidden, plays, playm, playf, mcnt, msize, tooltipvalue,
					aurastacks, auraeffect1, auraeffect2, auraeffect3, startcnt, startcntcpy, stopcnt, runetype,
					resource_decimals, chargecnt, spellid;

				-- extract commands from current line
				unit, str = self:ExtractRegex(str, "unit=(%w+)", "unit=\"([^\"]+)\"", true);
				iconoverride, str = self:ExtractRegex(str, "icon=(%w+)", "icon=\"([^\"]+)\"", true);
				shown, str = self:ExtractRegex(str, "shown=(%w+)", "shown=\"([^\"]+)\"", true);
				hidden, str = self:ExtractRegex(str, "hidden=(%w+)", "hidden=\"([^\"]+)\"", true);
				portraitunit, str = self:ExtractRegex(str, "portrait=(%w+)", "portrait=\"([^\"]+)\"", true);
				plays, str = self:ExtractRegex(str, "plays=\"([^\"]+)\"", nil, true);
				playm, str = self:ExtractRegex(str, "playm=\"([^\"]+)\"", nil, true);
				playf, str = self:ExtractRegex(str, "playf=\"([^\"]+)\"", nil, true);
				startcnt, str = self:ExtractRegex(str, "startcnt=(%w+)", "startcnt=\"([^\"]+)\"", true);
				startcntcpy, str = self:ExtractRegex(str, "startcntcpy=(%w+)", "startcntcpy=\"([^\"]+)\"", true);
				stopcnt, str = self:ExtractRegex(str, "stopcnt=(%w+)", "stopcnt=\"([^\"]+)\"", true);
				mcnt, str = self:ExtractRegex(str, "mcnt=(%w+)", "mcnt=\"([^\"]+)\"", true);
				msize, str = self:ExtractRegex(str, "msize=([+-]?[0-9]*%.?[0-9]*)", "msize=\"([+-]?[0-9]*%.?[0-9]*)\""); -- floating point regex
				recast, str = self:ExtractRegex(str, "recast=([+-]?[0-9]*%.?[0-9]*)", "recast=\"([+-]?[0-9]*%.?[0-9]*)\"");
				staticdur, str = self:ExtractRegex(str, "staticdur=([+-]?[0-9]*%.?[0-9]*)", "staticdur=\"([+-]?[0-9]*%.?[0-9]*)\"");
				zoom, str = self:ExtractRegex(str, "zoom=([+-]?[0-9]*%.?[0-9]*)", "zoom=\"([+-]?[0-9]*%.?[0-9]*)\"");
				aurastacks, str = self:ExtractRegex(str, "auravalue=([+-]?[0-9]*%.?[0-9]*)", "auravalue=\"([+-]?[0-9]*%.?[0-9]*)\"");
				if (not aurastacks) then
					aurastacks, str = self:ExtractRegex(str, "aurastacks=([+-]?[0-9]*%.?[0-9]*)", "aurastacks=\"([+-]?[0-9]*%.?[0-9]*)\"");
				end
				auraeffect1, str = self:ExtractRegex(str, "auraeffect1=([+-]?[0-9]*%.?[0-9]*)", "auraeffect1=\"([+-]?[0-9]*%.?[0-9]*)\"");
				if (not auraeffect1) then
					auraeffect1, str = self:ExtractRegex(str, "auraeffect=([+-]?[0-9]*%.?[0-9]*)", "auraeffect=\"([+-]?[0-9]*%.?[0-9]*)\"");
				end
				auraeffect2, str = self:ExtractRegex(str, "auraeffect2=([+-]?[0-9]*%.?[0-9]*)", "auraeffect2=\"([+-]?[0-9]*%.?[0-9]*)\"");
				auraeffect3, str = self:ExtractRegex(str, "auraeffect3=([+-]?[0-9]*%.?[0-9]*)", "auraeffect3=\"([+-]?[0-9]*%.?[0-9]*)\"");
				specstr, str = self:ExtractRegex(str, "spec=([0-4])", "spec=\"([^\"]+)\"");
				runetype, str = self:ExtractRegex(str, "runetype=(%d+)", "runetype=\"(%d+)\"");
				spellid, str = self:ExtractRegex(str, "spellid=(%d+)", "spellid=\"(%d+)\"");
								
				recast, staticdur, zoom, spellid =
					recast and (tonumber(recast) * 1000),
					staticdur and (tonumber(staticdur) * 1000),
					zoom and (tonumber(zoom) * 1000),
					spellid and tonumber(spellid);
				
				local spectab;
				if (specstr) then
					spectab = self:CommaSeparatedNumbersToTable(specstr, 1, 4);
				end
				
				-- stack/effect value display variable
				if (aurastacks and tonumber(aurastacks)) then
					aurastacks = tonumber(aurastacks);
				else
					aurastacks = nil;
				end
				
				if (auraeffect1 and tonumber(auraeffect1)) then
					auraeffect1 = tonumber(auraeffect1);
				else
					auraeffect1 = nil;
				end
				
				if (auraeffect2 and tonumber(auraeffect2)) then
					auraeffect2 = tonumber(auraeffect2);
				else
					auraeffect2 = nil;
				end
				
				if (auraeffect3 and tonumber(auraeffect3)) then
					auraeffect3 = tonumber(auraeffect3);
				else
					auraeffect3 = nil;
				end
				
				-- runetype
				if (runetype and tonumber(runetype) and tonumber(runetype) > 0) then
					runetype = tonumber(runetype);
				else
					runetype = nil;
				end
				
				-- marker count/size (tick markers for power bars)
				if (mcnt and tonumber(mcnt)) then
					mcnt = tonumber(mcnt);
					
					if (mcnt > 10) then
						mcnt = 10;
					elseif (mcnt < 1) then
						mcnt = 1;
					end
					
					if (not msize or not tonumber(msize)) then
						msize = "1.0";
					end
				else
					msize = nil;
				end
				if (msize) then
					msize = tonumber(msize);
					
					if (msize > 1.0 or msize < 0.0) then
						msize = 1.0;
					end
				end
				
				-- get play interval time
				local playinterval;
				if (plays) then
					local s, f;
					s, f, playinterval, plays = string_find(plays, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
					if (playinterval) then playinterval = tonumber(playinterval); end
					playm = nil; playf = nil;
				elseif (playm) then
					s, f, playinterval, playm = string_find(playm, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
					if (playinterval) then playinterval = tonumber(playinterval); end
					plays = nil; playf = nil;
				elseif (playf) then
					s, f, playinterval, playf = string_find(playf, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
					if (playinterval) then playinterval = tonumber(playinterval); end
					plays = nil; playm = nil;
				end
				
				-- check if playinterval is too short or too long
				if (playinterval and (playinterval < 0.5 or playinterval > 600)) then
					playinterval = nil;
				end

				local fplay, tplay, toplay;
				if (playinterval) then
					if (plays) then
						fplay = PlaySound;
						tplay = self.played.s;
						toplay = plays;
					elseif (playm and self.lsm:Fetch("sound", playm)) then
						fplay = PlaySoundFile;
						tplay = self.played.m;
						toplay = self.lsm:Fetch("sound", playm);
					elseif (playf) then
						fplay = PlaySoundFile;
						tplay = self.played.f;
						toplay = playf;
					end
				end
				
				-- start/stop count
				local countstart, countinterval, countstop, countcpy;
				if (startcnt) then
					countinterval, countstart =
						string_match(startcnt, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
						
					if (countstart) then
						countinterval = tonumber(countinterval);
					else
						countinterval = nil;
					end
				end
				if (startcntcpy) then
					countcpy = startcntcpy;
				end
				if (stopcnt) then
					countstop = stopcnt;
				end
								
				-- icon override, portrait unit
				local iconoverride = select(3, GetSpellInfo(iconoverride));
				local ptun = portraitunit;
				
				local nfs, tfs, colstr, tsbcol, tbcol;
				-- name format string
				nfs, str = self:ExtractRegex(str, "nfs=\"([^\"]*)\"", "nfs=(%w+)");
				-- time format string
				tfs, str = self:ExtractRegex(str, "tfs=\"([^\"]*)\"", "tfs=(%w+)");
				-- status bar color
				colstr, str = self:ExtractRegex(str, "sbcol=\"([^\"]+)\"");
				if (colstr) then
					local r,g,b,a = self:GetColorsFromString(colstr);
					if(r) then
						tsbcol = { r, g, b, a };
					end
				end
				-- border color
				colstr, str = self:ExtractRegex(str, "bcol=\"([^\"]+)\"");
				if (colstr) then
					local r,g,b,a = self:GetColorsFromString(colstr);
					if(r) then
						tbcol = { r, g, b, a };
					end
				end
				-- command and spellname
				local tiType, bSelf, bHarm, bHelp, bShowLag, bShowCasttime, iSort, bExists, bNot, bHideSpark, bHideIcon, cfinit, brange, range_tab, icon__;
				local norefresh = false;
				local boolop = cmd_boolop or BOOLOP_NONE;
				local cmd, spell = string_match(str, "(.-):(.+)");
				if(spell) then
					spell, brange, range_tab = get_valid_range_table(spell);
				end
				cmd = cmd and string_trim(cmd);
				if (cmd and string_len(cmd) > 0 and spell and string_len(spell) > 0) then
					for w in string_gmatch(cmd, "%w+") do
						w = string_lower(w);

						if (w == "exit") then
							tiType = -1;
							cfinit = Gnosis.Timers_Exit;
						elseif (w == "cast") then
							tiType = 0;
							cfinit = Gnosis.Timers_Spell;
						elseif (w == "cd") then
							tiType = 1;
							unit = "player";
							cfinit = Gnosis.Timers_SpellCD;
						elseif (w == "dot" or w == "debuff") then
							bHarm = true;
							tiType = 2;
							cfinit = Gnosis.Timers_Aura;
						elseif (w == "hot" or w == "buff") then
							bHelp = true;
							tiType = 2;
							cfinit = Gnosis.Timers_Aura;
						elseif (w == "aura") then
							tiType = 2;
							cfinit = Gnosis.Timers_Aura;
						elseif (w == "itemcd") then
							tiType = 3;
							unit = "player";
							cfinit = Gnosis.Timers_ItemCD;
						elseif (w == "runecd") then
							unit = "player";
							if (tonumber(spell) and tonumber(spell) > 0 and tonumber(spell) <= 6) then
								tiType = 4;
								cfinit = Gnosis.Timers_RuneCD;
							end
						elseif (w == "totemdur") then
							unit = "player";
							if(tonumber(spell) and tonumber(spell) > 0 and tonumber(spell) <= MAX_TOTEMS) then
								tiType = 5;
								cfinit = Gnosis.Timers_TotemDuration;
							end
						elseif (w == "enchmh") then
							tiType = 6;
							unit = "player";
							cfinit = Gnosis.Timers_WeaponEnchantMain;
						elseif (w == "enchoh") then
							tiType = 7;
							unit = "player";
							cfinit = Gnosis.Timers_WeaponEnchantOff;
						elseif (w == "icd" or w == "innercd" or w == "proc") then
							-- valid spell or spell id given? (name of spell passed for icd does not
							-- necessarily have to be a valid spell)
							local spell_, _, icon_ = GetSpellInfo(spell);
							if (spell_) then
								spell = spell_;
								icon__ = icon_;
							end		
							if (spell) then
								tiType = 8;
								cfinit = Gnosis.Timers_InnerCD;
								-- staticdur given? otherwise set duration to 5s
								self.ti_icd[spell] = {
									duration = staticdur or 5.0,
									norefresh = false
								};
							end
							unit = "player";
						elseif (w == "recharge") then
							local spell_, _, icon_ = GetSpellInfo(spell);
							if (spell_) then
								spell = spell_;
								icon__ = icon_;
							end
							if (spell) then
								tiType = 9;
								cfinit = Gnosis.Timers_SpellRecharge;
							end
							unit = "player";
						elseif (w == "fixed") then
							tiType = 10;
							unit = "player";
							cfinit = Gnosis.Timers_Fixed;
						elseif (w == "spellknown") then
							tiType = 11;
							unit = "player";
							cfinit = Gnosis.Timers_SpellKnown;
						elseif (w == "unitname") then
							tiType = 12;
							cfinit = Gnosis.Timers_UnitName;
						elseif (w == "gcd") then
							tiType = 13;
							unit = "player";
							cfinit = Gnosis.Timers_GlobalCD;
						elseif (w == "equipped") then
							tiType = 14;
							unit = "player";
							cfinit = Gnosis.Timers_ItemEquipped;
						elseif (w == "npc") then
							tiType = 15;
							cfinit = Gnosis.Timers_Npc;
						elseif (w == "charspec") then
							tiType = 16;
							unit = "player";
							cfinit = Gnosis.Timers_Charspec;
						elseif (w == "talent") then
							tiType = 17;
							unit = "player";
							cfinit = Gnosis.Timers_Talent;
						elseif (w == "glyph") then
							tiType = 18;
							unit = "player";
							cfinit = Gnosis.Timers_Glyph;
						elseif (w == "groupdot" or w == "groupdebuff") then
							bHarm = true;
							tiType = 21;
							cfinit = Gnosis.Timers_GroupAura;
						elseif (w == "grouphot" or w == "groupbuff") then
							bHelp = true;
							tiType = 21;
							cfinit = Gnosis.Timers_GroupAura;
						elseif (w == "groupaura") then
							tiType = 21;
							cfinit = Gnosis.Timers_GroupAura;
						elseif (w == "counter") then
							tiType = 22;
							cfinit = Gnosis.Timers_Counter;
						elseif (w == "resource") then
							if (spell == "power") then
								tiType = 1000;
								cfinit = Gnosis.Timers_Power;
							elseif (spell == "health") then
								tiType = 1001;
								cfinit = Gnosis.Timers_Health;
							elseif (spell == "altpower") then
								tiType = 1002;
								cfinit = Gnosis.Timers_PowerAlternate;
							elseif (spell == "heal") then
								tiType = 1003;
								cfinit = Gnosis.Timers_IncomingHealth;
							elseif (spell == "threat") then
								tiType = 1004;
								cfinit = Gnosis.Timers_TargetThreat;
							elseif (spell == "range") then
								tiType = 1006;
								cfinit = Gnosis.Timers_Range;
							elseif (spell == "combopoints") then
								tiType = 2004;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "soulshards") then
								tiType = 2007;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "eclipse") then
								tiType = 2008;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "holypower") then
								tiType = 2009;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "chi") then
								tiType = 2012;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "shadoworbs") then
								tiType = 2013;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "burningembers") then
								tiType = 2014;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "burningembers_decimals") then
								tiType = 2014;
								cfinit = Gnosis.Timers_PowerGeneric;
								resource_decimals = true;
							elseif (spell == "demonicfury") then
								tiType = 2015;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "xp" or spell == "experience") then
								tiType = 2016;
								cfinit = Gnosis.Timers_Experience;
							elseif (spell == "rested" or spell == "restedxp") then
								tiType = 2017;
								cfinit = Gnosis.Timers_RestedXP;
							end
						elseif (w == "mine") then
							bSelf = true;
						elseif (w == "helpful" or w == "help") then
							bHelp = true;
						elseif (w == "harmful" or w == "harm") then
							bHarm = true;
						elseif (w == "lag") then
							bShowLag = true;
						elseif (w == "casttime") then
							bShowCasttime = true;
						elseif (w == "exists") then
							bExists = true;
						elseif (w == "not") then
							bNot = true;
						elseif (w == "hidespark" or w == "nospark") then
							bHideSpark = true;
						elseif (w == "hideicon" or w == "noicon") then
							bHideIcon = true;
						elseif (w == "and") then
							if (boolop == BOOLOP_NONE) then
								boolop = BOOLOP_AND;
							end
						elseif (w == "or") then
							if (boolop == BOOLOP_NONE) then
								boolop = BOOLOP_OR;
							end
						elseif (w == "sort") then
							if (spell == "minrem") then
								iSort = 1;
							elseif (spell == "maxrem") then
								iSort = 2;
							elseif (spell == "mindur") then
								iSort = 3;
							elseif (spell == "maxdur") then
								iSort = 4;
							elseif (spell == "first") then
								iSort = 5;
							end
						elseif (w == "norefresh") then
							norefresh = true;
						elseif (w == "chargecnt") then
							chargecnt = true;
						end
					end
				end

				local strFilter = "";
				strFilter = strFilter .. (bSelf and "PLAYER" or "");
				strFilter = strFilter .. (bHarm and (string_len(strFilter) > 0 and "|HARMFUL" or "HARMFUL") or "");
				strFilter = strFilter .. (bHelp and (string_len(strFilter) > 0 and "|HELPFUL" or "HELPFUL") or "");
				
				if (tiType) then
					local tTimer = {
						type = tiType,
						spectab = spectab,
						filter = strFilter,
						spell = spell,
						showlag = bShowLag,
						showcasttime = bShowCasttime,
						nfs = nfs,
						tfs = tfs,
						recast = recast,
						staticdur = staticdur,
						zoom = zoom,
						bExists = bExists,
						bNot = bNot,
						cfinit = cfinit,
						bcolor = tbcol,
						sbcolor = tsbcol,
						cbs = not bHideSpark and conf.bShowCBS or false,
						hideicon = bHideIcon,
						id = timer_id,
						brange = brange,
						range_tab = range_tab,
						boolop = boolop,
						icon = icon__,
						icov = iconoverride,
						ptun = portraitunit,
						shown = shown,
						hidden = hidden,
						playinterval = playinterval,
						fplay = fplay,
						tplay = tplay,
						toplay = toplay,
						mcnt = mcnt,
						msize = msize,
						aurastacks = aurastacks,
						auraeffect1 = auraeffect1,
						auraeffect2 = auraeffect2,
						auraeffect3 = auraeffect3,
						countstart = countstart,
						countinterval = countinterval,
						countcpy = countcpy,
						countstop = countstop,
						runetype = runetype,
						resource_decimals = resource_decimals,
						chargecnt = chargecnt,
						spellid = spellid,
					};
					
					-- targeted unit
					tTimer.unit = unit and unit or conf.unit;

					-- get name and icon if cast/aura and passed as spellid
					if ((tiType <= 2 or tiType == 10 or tiType == 11 or tiType == 21) and tonumber(spell)) then
						local name_, _, icon_, _, _, _, spellid_ = GetSpellInfo(tonumber(spell));
						if(name_ and icon_) then
							tTimer.spell = name_;
							tTimer.icon = icon_;
							tTimer.spellid = spellid_;
						end
					end
					
					-- if itemcd try to get item id and texture
					if (tiType == 3 or tiType == 14) then
						local itemname, link, _, _, _, _, _, _, _, itex = GetItemInfo(spell);
						if(link) then
							tTimer.iid = string.match(link, "|Hitem:(%d+):");
							tTimer.itex = itex;
							tTimer.iname = itemname;
						end
					end
					
					-- inner cooldown/proc (norefresh command)
					if (tiType == 8) then
						self.ti_icd[spell].norefresh = norefresh;
					end
					
					-- special handling for auras with
					-- aurastacks/auraeffect commands
					if (tiType == 2 or tiType == 21) then
						if (aurastacks) then
							tTimer.type = tiType + 5000;
						elseif (auraeffect1 or auraeffect2 or auraeffect3) then
							tTimer.type = tiType + 5001;
						end
					end
					-- special handling for recharge command with
					-- the chargecnt option
					if (tiType == 9 and chargecnt) then
						tTimer.type = 5001;
					end
					
					-- do not check if unit exists for unitname/npc command
					if (not(tiType == 12 or tiType == 15 or tiType == -1)) then
						tTimer.unitexistscheck = true;
					end
					
					-- insert entry
					table_insert(value.timers, tTimer);
				elseif (iSort) then
					-- sorting criterion
					value.iTimerSort = iSort;
				end
			end

			if (#value.timers > 0) then
				table_insert(self.ti_fl, value);
			end
		end
	end
end

function Gnosis:InjectTimer(barname, text, cnt, spell, isCast)
	local fCurTime = GetTime() * 1000;
	if (self.castbars and self.castbars[barname]) then
		local cb = self.castbars[barname];
		local cfg = cb.conf;
		
		-- castbar values
		cb.channel = not isCast;
		cb.icon:SetTexture(nil);
		cb.id = 0;
		
		if (spell) then
			local name, _, icon = GetSpellInfo(spell);
			if (name and icon) then
				cb.castname = name;
				cb.icon:SetTexture(icon);
			end
		end	

		-- show castbar text
		cb.ctext:SetText(text);
		cb.castname = nil;
		
		cb.duration = cnt * 1000;
		cb.endTime = fCurTime + cb.duration;

		-- set statusbar value
		local val = (cb.endTime - fCurTime) / (cb.duration);
		val = (cb.channel and (not cfg.bChanAsNorm)) and val or (1 - val);
		cb.bar:SetValue(val);
		cb:SetAlpha(cfg.alpha);
		cb:Show();
		
		-- castbar spark
		if(cfg.bShowCBS) then
			cb.cbs:SetPoint("CENTER", cb.bar, "LEFT", val * cb.barwidth, 0);
			cb.cbs:Show();
		end
		
		-- pushback (also vital for clipping test)
		cb.pushback = 0;

		-- set bar active
		cb.bActive = true;
		self.activebars[barname] = cb;
	else
		self:Print("bar " .. barname .. " unknown");
	end
end

function Gnosis:CheckCounter(v, ti)
	-- stop counter
	if (v.countstop) then
		if (self.counters) then
			self.counters[v.countstop] = nil;
		end
	end
	
	-- start counter if it's not already running
	if (v.countinterval) then		
		if (self.counters[v.countstart] == nil) then
			self.counters[v.countstart] = { starttime = GetTime(), endtime = GetTime() + v.countinterval };
		elseif (self.counters[v.countstart].endtime < GetTime()) then
			self.counters[v.countstart].starttime = GetTime();
			self.counters[v.countstart].endtime = self.counters[v.countstart].starttime + v.countinterval;
		end
	end
	
	-- start counter (copying timer duration)
	if (v.countcpy and ti) then
		if (self.counters[v.countcpy] == nil) then
			self.counters[v.countcpy] = { starttime = (ti.fin - ti.dur) / 1000, endtime = ti.fin / 1000 };
		elseif (self.counters[v.countcpy].endtime < GetTime()) then
			self.counters[v.countcpy].starttime = (ti.fin - ti.dur) / 1000;
			self.counters[v.countcpy].endtime = ti.fin / 1000;
		end		
	end
end

function Gnosis:ScanTimerbar(bar, fCurTime)
	local bUpdateText = false;
	local bDelayedShow = false;

	-- hide bar in/out of combat
	if (bar.conf.incombatsel == 1 or bar.conf.incombatsel == self.curincombattype or bar.conf.bUnlocked) then
		if (bar.bBarHidden) then
			bDelayedShow = true;
		end
	else
		if (not bar.bBarHidden) then
			bar:Hide();
			bar.bBarHidden = true;
		end
		return;
	end

	-- valid group layout? valid instance type?
	if (not self:CheckGroupLayout(bar.conf) or not self:CheckInstanceType(bar.conf)) then
		if (not bar.bBarHidden) then
			bar:Hide();
			bar.bBarHidden = true;
		end
		return;
	end

	local relaxed_and = nil;
	local boolop_complete = false;
	SelectedTimerInfo.duration = nil;
	for k, v in ipairs(bar.timers) do
		if (boolop_complete) then
			-- unmark relaxed and request
			relaxed_and = nil;
			
			-- search for first timer entry without boolop
			if (v.boolop == BOOLOP_NONE) then
				boolop_complete = false;
			end
		else
			-- compute command?
			local checkentry = true;
			
			-- check current spec
			if (v.spectab and v.spectab[self.iCurSpec] == false) then
				checkentry = false;
			else
				-- selected unit exists?
				if (v.unitexistscheck and (not UnitExists(v.unit))) then
					checkentry = false;
				else
					-- "shown" command? is given bar actually shown?
					if (v.shown and Gnosis.castbars[v.shown] and not Gnosis.castbars[v.shown].bActive) then
						checkentry = false;
					else
						-- "hidden" command? is given bar actually hidden?
						if (v.hidden and Gnosis.castbars[v.hidden] and Gnosis.castbars[v.hidden].bActive) then
							checkentry = false;
						end
					end
				end
			end
						
			-- check entry
			if (checkentry) then
				wipe(TimerInfo);
				
				-- call related timer function (Timers.lua)
				v:cfinit(bar, v, TimerInfo);

				-- related timer info valid
				if (TimerInfo.ok and self:UnitRelationSelect(bar.conf.relationsel, TimerInfo.unit)) then						
					-- start or stop counter?				
					self:CheckCounter(v, TimerInfo);
						
					-- boolop?
					if (v.boolop == BOOLOP_RELAXEDAND) then
						-- '?' (relaxed and, only one match necessary)
						relaxed_and = 2;		-- store as valid
					elseif (v.boolop == BOOLOP_AND) then
						-- timer is condition for next one(s), next please
					elseif (relaxed_and == 1) then
						-- relaxed and requested but no match found
						relaxed_and = nil;
						if (v.boolop == BOOLOP_OR) then
							boolop_complete = true;
						end
					else
						-- exit?
						if (v.type == -1) then
							-- play sound/music/file
							self:PlayBarAudio(v, bar.name);
							-- exit, do not compute further
							break;
						end
				
						if (v.boolop == BOOLOP_OR) then
							boolop_complete = true;
						end

						-- check if cooldown is gcd
						local bTakeover = false;
						if (TimerInfo.bSpecial) then
							bTakeover = true;
							SelectedTimerInfo.bSpecial = TimerInfo.bSpecial;
							SelectedTimerInfo.valIsStatic = TimerInfo.valIsStatic;
						else
							-- sorting
							SelectedTimerInfo.bSpecial = false;
							if (not bar.iTimerSort or not SelectedTimerInfo.duration) then
								bTakeover = true;
							elseif (bar.iTimerSort == 1 and SelectedTimerInfo.endTime > TimerInfo.fin) then		-- min remaining
								bTakeover = true;
							elseif (bar.iTimerSort == 2 and SelectedTimerInfo.endTime < TimerInfo.fin) then		-- max remaining
								bTakeover = true;
							elseif (bar.iTimerSort == 3 and SelectedTimerInfo.duration > TimerInfo.dur) then	-- min duration
								bTakeover = true;
							elseif (bar.iTimerSort == 4 and SelectedTimerInfo.duration < TimerInfo.dur) then	-- max duration
								bTakeover = true;
							end
						end

						if (bTakeover) then
							SelectedTimerInfo.castname = TimerInfo.cname;
							SelectedTimerInfo.endTime = TimerInfo.fin;
							SelectedTimerInfo.duration = TimerInfo.dur;
							SelectedTimerInfo.icon = TimerInfo.icon;
							SelectedTimerInfo.stacks = TimerInfo.stacks;
							SelectedTimerInfo.effect = TimerInfo.effect;
							SelectedTimerInfo.tiunit = TimerInfo.unit;
							SelectedTimerInfo.bChannel = TimerInfo.bChannel;
							SelectedTimerInfo.notInterruptible = TimerInfo.notInterruptible;
							SelectedTimerInfo.curtimer = v;							
						end

						if (SelectedTimerInfo.bSpecial or not bar.iTimerSort) then
							-- break if no sorting criterion given or if bar was durationless,
							-- i.e. it couldn't be sorted anyway
							break;
						end
					end
				elseif (v.boolop == BOOLOP_RELAXEDAND) then
					-- '?' (relaxed and, only one match necessary)
					relaxed_and = relaxed_and or 1;	-- relaxed ok requested
				elseif (v.boolop == BOOLOP_AND) then
					-- "and"/'&' but invalid entry, skip to next combined "and"/"or" block
					boolop_complete = true;
				end
			elseif (v.boolop == BOOLOP_RELAXEDAND) then
				-- '?' (relaxed and, only one match necessary)
				relaxed_and = 1;	-- relaxed ok requested
			elseif (v.boolop == BOOLOP_AND) then
				-- "and"/'&' but invalid entry, skip to next combined "and"/"or" block
				boolop_complete = true;
			else
				relaxed_and = nil;
			end
		end
	end

	if (SelectedTimerInfo.duration) then
		if (bDelayedShow) then
			bar.bBarHidden = nil;
			bar:Show();
		end

		-- play sound/music/file
		self:PlayBarAudio(SelectedTimerInfo.curtimer, bar.name);
		
		-- only minor changes to bar necessary?
		if (bar.bActive and bar.timer_id == SelectedTimerInfo.curtimer.id and
			bar.castname == SelectedTimerInfo.castname and bar.notInterruptible == SelectedTimerInfo.notInterruptible) then
			
			local dur = bar.dur and bar.dur or bar.duration;
			local bRecalcTick = (dur ~= SelectedTimerInfo.duration);

			-- redo name text
				-- stacks; effect value and name of targeted unit (added in 4.01)
			if (bar.stacks ~= SelectedTimerInfo.stacks or bar.effect ~= SelectedTimerInfo.effect or SelectedTimerInfo.tiunit ~= bar.tiUnit or bar.tiUnitName ~= UnitName(bar.tiUnit)) then
				bar.stacks = SelectedTimerInfo.stacks;
				bar.effect = SelectedTimerInfo.effect;
				bar.tiUnit = SelectedTimerInfo.tiunit;
				bar.tiUnitName = UnitName(bar.tiUnit);
				bar.ctext:SetText(self:CreateCastname(bar, bar.conf, SelectedTimerInfo.castname, ""));
			end
			
			if (SelectedTimerInfo.bSpecial) then
				if (not SelectedTimerInfo.valIsStatic) then
					-- power
					self:SetPowerbarValue(bar, SelectedTimerInfo.endTime, SelectedTimerInfo.duration, SelectedTimerInfo.curtimer.cbs);
					
					if (SelectedTimerInfo.curtimer.mcnt) then
						self:SetPowerbarValueMarkers(bar, SelectedTimerInfo.endTime,
							SelectedTimerInfo.duration, SelectedTimerInfo.curtimer.mcnt,
							SelectedTimerInfo.curtimer.msize);
					end
				end

				return;
			end

			-- zoom?
			local bZoom = SelectedTimerInfo.curtimer.zoom and (SelectedTimerInfo.curtimer.zoom >= (SelectedTimerInfo.endTime - fCurTime));
			-- staticdur?
			local bStatic = SelectedTimerInfo.curtimer.staticdur and true;

			bar.dur = (bStatic or bZoom) and SelectedTimerInfo.duration or nil;
			bar.duration = bZoom and SelectedTimerInfo.curtimer.zoom or (bStatic and SelectedTimerInfo.curtimer.staticdur or SelectedTimerInfo.duration);
			bar.endTime = SelectedTimerInfo.endTime;

			if (bar.cbs_check) then
				local bShowCBS = bar.duration >= (bar.endTime - fCurTime);
				if (bShowCBS) then
					if (bar.cbs_hidden) then
						bar.cbs:Show();
						bar.cbs_hidden = false;
					end
				else
					if (not bar.cbs_hidden) then
						bar.cbs:Hide();
						bar.cbs_hidden = true;
					end
				end
			end

			self:SetupTimerLagBox(bar, SelectedTimerInfo.curtimer.showlag,
				SelectedTimerInfo.curtimer.showcasttime, SelectedTimerInfo.castname,
				SelectedTimerInfo.curtimer.recast, bRecalcTick);
		else	-- create bar
			-- id
			bar.timer_id = SelectedTimerInfo.curtimer.id;

			-- name and time format strings
			bar.nfs = SelectedTimerInfo.curtimer.nfs and SelectedTimerInfo.curtimer.nfs or bar.conf.strNameFormat;
			bar.tfs = SelectedTimerInfo.curtimer.tfs and SelectedTimerInfo.curtimer.tfs or bar.conf.strTimeFormat;

			-- not interruptible status for 'cast' command
			bar.notInterruptible = SelectedTimerInfo.notInterruptible; 
			
			if (SelectedTimerInfo.bSpecial) then
				bar.bSpecial = true;
				self:SetupPowerbar(bar, SelectedTimerInfo);
				
				if (SelectedTimerInfo.curtimer.mcnt) then
					self:SetPowerbarValueMarkers(bar, SelectedTimerInfo.endTime,
						SelectedTimerInfo.duration, SelectedTimerInfo.curtimer.mcnt,
						SelectedTimerInfo.curtimer.msize);
				end
			else
				bar.bSpecial = false;
				self:SetupTimerbar(bar, fCurTime, SelectedTimerInfo);
			end
		end
	elseif (self.activebars[bar.name] or bar.forcecleanup) then
		local conf = bar.conf;
		-- bar active, fadeout or cleanup
		if (conf.bUnlocked or conf.bShowWNC or bDelayedShow) then
			self:CleanupCastbar(bar);
			bar.forcecleanup = false;
		else
			self:PrepareCastbarForFadeout(bar, fCurTime, bar.forcecleanup);
			bar.forcecleanup = false;
		end
	end
end

function Gnosis:PlayBarAudio(curtimer, barname)
	local playinterval = curtimer.playinterval;
	if (playinterval) then
		local fplay = curtimer.fplay;
		local tplay = curtimer.tplay;
		local toplay = curtimer.toplay;
		
		if (not tplay[barname]) then
			tplay[barname] = {};
		end
		
		local tp = tplay[barname];
		if ((not tp[toplay]) or tp[toplay].timer <= GetTime()) then
			if (tp[toplay] and tp[toplay].handle) then
				StopSound(tp[toplay].handle);
			end
			
			local willPlay, handle = fplay(toplay, self.s.ct.channel and self.tSoundChannels[self.s.ct.channel] or self.tSoundChannels[1]);
								
			if (willPlay) then
				if (tp[toplay]) then
					tp[toplay].handle = handle;
					tp[toplay].timer = GetTime() + playinterval;
				else
					tp[toplay] = {
						["handle"] = handle,
						["timer"] = GetTime() + playinterval,
					};
				end
			else
				if (tp[toplay]) then
					wipe(tp[toplay]);
				end
				tp[toplay] = nil;
			end
		end
	end
end
