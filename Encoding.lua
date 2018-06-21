local string_char = string.char;
local string_byte = string.byte;
local string_char = string.char;
local string_sub = string.sub;
local table_concat = table.concat;
local min = min;
local bit_lshift = bit.lshift;
local bit_rshift = bit.rshift;
local bit_band = bit.band;
local bit_bor = bit.bor;

function Gnosis:GenEncTab()
	if (Gnosis.tEnc == nil) then
		Gnosis.tEnc = {};	
		
		-- add 64 entries to tEncoding, '0' .. '9', 'A' .. 'Z', 'a' .. 'z'
		local cnt = 0;		
		--local cnt = 1;
		for i = 48, 57 do
			Gnosis.tEnc[cnt] = string_char(i);
			cnt = cnt + 1;		
		end
		for i = 65, 90 do
			Gnosis.tEnc[cnt] = string_char(i);
			cnt = cnt + 1;
		end
		for i = 97, 122 do
			Gnosis.tEnc[cnt] = string_char(i);
			cnt = cnt + 1;
		end
		Gnosis.tEnc[62] = '#';
		Gnosis.tEnc[63] = '*';
	end
end

function Gnosis:EncStr(str)
	Gnosis:GenEncTab();
	
	local res = {};
	local rembits = 0;
	local rembitcnt = 0;
	local len = string.len(str);	-- do not use utf8 version of len
	
	for i = 1, len do
		-- add current character to bitstream
		local t = bit_lshift(string_byte(str, i), rembitcnt);
		rembits = bit_bor(rembits, t);
		rembitcnt = rembitcnt + 8;
		
		-- generate encoded characters from bitstream
		while (rembitcnt >= 6 or (i == len and rembitcnt > 0)) do
			res[#res+1] = Gnosis.tEnc[bit_band(rembits, 0x3f)];
			rembits = bit_rshift(rembits, 6);
			rembitcnt = rembitcnt - 6;
		end
	end
	
	if (res) then
		return table_concat(res);
	end
end

function Gnosis:GenDecTab()
	Gnosis:GenEncTab();
	
	if (Gnosis.tDec == nil) then
		Gnosis.tDec = {};
	
		for k, v in pairs(Gnosis.tEnc) do
			Gnosis.tDec[v] = k;
		end
	end	
end

-- /run Gnosis:EncStr("Butterbirne")
function Gnosis:DecStr(str, len)
	Gnosis:GenDecTab();
	
	local gtd = Gnosis.tDec;
	local cnt = #str;
	local res = {};
	local bits = 0;
	local bitcnt = 0;
	
	for i = 1, cnt do
		-- decode character
		local dec = gtd[string_sub(str, i, i)];
		if (dec == nil) then
			return;
		end
		
		-- add current decoded character to bitstream
		dec = bit_lshift(dec - 0, bitcnt);
		bits = bit_bor(bits, dec);
		bitcnt = bitcnt + 6;
		
		-- generate result from bitstream
		while (bitcnt >= 8) do
			res[#res+1] = string_char(bit_band(bits, 0xff));
			bits = bit_rshift(bits, 8);
			bitcnt = bitcnt - 8;
		end
	end	
	
	if (res) then
		if (#res > len) then
			table_setn(res, len);
		end
		
		res = table_concat(res);
		return res, string.len(res); -- do not use utf8 version of len
	end
end
