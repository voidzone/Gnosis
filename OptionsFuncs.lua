-- local functions
local pairs = pairs;
local ipairs = ipairs;
local type = type;
local unpack = unpack;
local setmetatable = setmetatable;
local getmetatable = getmetatable;
local next = next;
local wipe = wipe;
local string_len = strlenutf8;
local string_trim = strtrim;
local string_gmatch = string.gmatch;
local table_insert = table.insert;
local table_sort = table.sort;

-- local variables
local _;

function Gnosis:OptColor_Entry(key, idx, namestr, variable, cfgtab, bartab)
	cfgtab = cfgtab or "cbconf";
	bartab = bartab or "castbars";

	return {
		order = idx,
		name = namestr,
		type = "color",
		get = function(info) return unpack(Gnosis.s[cfgtab][key][variable]); end,
		set = function(info,r,g,b,a) Gnosis.s[cfgtab][key][variable] = { r, g, b, a }; Gnosis:SetBarParams(key, cfgtab, bartab); end,
		hasAlpha = true,
	};
end

function Gnosis:OptColorText_Entry(key, idx, namestr, variable, cfgtab, bartab)
	cfgtab = cfgtab or "cbconf";
	bartab = bartab or "castbars";

	return {
		order = idx,
		name = namestr,
		type = "input",
		get = function(info) return Gnosis:CreateColorString(unpack(Gnosis.s[cfgtab][key][variable])) end,
		set = function(info,val)
			local r, g, b, a = Gnosis:GetColorsFromString(val);
			if(r) then
				Gnosis.s[cfgtab][key][variable] = { r, g, b, a };
				Gnosis:SetBarParams(key, cfgtab, bartab);
			end
		end,
	};
end

function Gnosis:OptColorGroup_Entry(key, idx, namestr, variable, cfgtab, bartab)
	cfgtab = cfgtab or "cbconf";
	bartab = bartab or "castbars";

	return {
		name = "",
		order = idx,
		type = "group",
		inline = true,
		args = {
			colentry = self:OptColor_Entry(key, 1, namestr, variable, cfgtab, bartab),
			coltextentry = self:OptColorText_Entry(key, 2, "", variable, cfgtab, bartab),
		}
	};
end

function Gnosis:OptToggle_Entry(key, idx, namestr, descstr, variable, cfgtab, bartab)
	cfgtab = cfgtab or "cbconf";
	bartab = bartab or "castbars";

	local t = {
		order = self:GetNextTableIndexInner(),
		name = namestr,
		desc = descstr,
		type = "toggle",
		get = function(info) return Gnosis.s[cfgtab][key][variable]; end,
		set = function(info,val) Gnosis.s[cfgtab][key][variable] = val; Gnosis:SetBarParams(key, cfgtab, bartab); end,
	}

	return t;
end

function Gnosis:OptSimpleToggle(key, idx, namestr, descstr, variable, cfgtab)
	cfgtab = cfgtab or "cbconf";

	return {
		order = idx,
		name = namestr,
		desc = descstr,
		type = "toggle",
		get = function(info) return Gnosis.s[cfgtab][key][variable]; end,
		set = function(info,val) Gnosis.s[cfgtab][key][variable] = val; end,
	};
end

function Gnosis:CommaSeparatedNumbersToTable(inputString, minNum, maxNum)
	if (type(inputString) ~= "string") then
		return {};
	end
	
	local retTab = {};
	
	-- fill table with minNum to maxNum
	for num=minNum,maxNum do
		retTab[num] = false;
	end
	
	-- set table entries true for matched numbers
	for num in string_gmatch(inputString, ".-(%d+).-") do
		if (num) then
			local number = tonumber(num);
			
			if (number and number >= minNum and number <= maxNum) then
				retTab[number] = true;
			end
		end
	end
	
	return retTab;
end

function Gnosis:TableToCommaSeparatedNumbers(tabNumbers)
	if (type(tabNumbers) ~= "table" or next(tabNumbers) == nil) then
		return "";
	end
	-- create ordered array
	local unordererd_tab = {};
	for idx in pairs(tabNumbers) do
		if (tabNumbers[idx]) then
			table_insert(unordererd_tab, idx);
		end
	end
	table_sort(unordererd_tab);
	
	-- create ordered, comma separated, string
	local first = true;
	local str = "";
	for idx, val in ipairs(unordererd_tab) do
		str = (first and "" or (str .. ",")) .. val;
		first = nil;
	end
	
	return str;
end

function Gnosis:MultilineFromTable(t)
	local str = "";
	local i = 1;

	for k, v in ipairs(t) do
		str = str .. v .. "\n";
	end

	str = string_trim(str);
	return str;
end

function Gnosis:MultilineToTable(str, t)
	wipe(t);

	if(str and string_len(str) > 0) then
		for line in string_gmatch(str, "%s*([^\r\n]+)") do
			line = string_trim(line);
			table_insert(t, line);
		end
	end
end

function Gnosis:deepcopy(object)
    local lookup_table = {};
    local function _copy(object)
        if(type(object) ~= "table") then
            return object;
        elseif(lookup_table[object]) then
            return lookup_table[object];
        end
        local new_table = {};
        lookup_table[object] = new_table;
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value);
        end
        return setmetatable(new_table, _copy(getmetatable(object)));
    end
    return _copy(object);
end
