local m = {}
Aux.money = m

local private =  {textMoneyParts={} }

local GOLD_TEXT = '|cffffd70ag|r'
local SILVER_TEXT = '|cffc7c7cfs|r'
local COPPER_TEXT = '|cffeda55fc|r'
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000


-- ============================================================================
-- TSMAPI Functions
-- ============================================================================

function m:MoneyToString(money) -- ,...)
	money = tonumber(money)
	if not money then return end
	local color, pad, trim, disabled
--	for i=1, select('#', ...) do
--		local opt = select(i, ...)
--		if type(opt) == 'string' then
--			if opt == 'OPT_PAD' then -- left-pad all but the highest denomination with zeros (i.e. "1g 00s 02c" instead of "1g 0s 2c")
--				pad = true
--			elseif opt == 'OPT_TRIM' then -- removes any 0 valued denominations (i.e. "1g" instead of "1g 0s 0c") - 0 will still be represented as "0c"
--				trim = true
--			elseif opt == 'OPT_DISABLE' then -- removes color from denomination text
--				disabled = true
--			elseif strmatch(strlower(opt), '^|c[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$') then -- color the numbers
--				color = opt
--			end
--		end
--	end
	
	local isNegative = money < 0
	money = abs(money)
	local gold = floor(money / COPPER_PER_GOLD)
	local silver = floor(mod(money, COPPER_PER_GOLD) / COPPER_PER_SILVER)
	local copper = floor(mod(money, COPPER_PER_SILVER))
	local goldText, silverText, copperText = nil, nil, nil
	if disabled then
		goldText, silverText, copperText = "g", "s", "c"
	else
		goldText, silverText, copperText = TSM.GOLD_TEXT, TSM.SILVER_TEXT, TSM.COPPER_TEXT
	end
	
	if money == 0 then
		return private:FormatNumber(0, false, color)..copperText
	end
	
	local text = nil
	local shouldPad = false
	if trim then
		wipe(private.textMoneyParts) -- avoid creating a new table every time
		-- add gold
		if gold > 0 then
			tinsert(private.textMoneyParts, private:FormatNumber(gold, false, color)..goldText)
			shouldPad = pad
		end
		-- add silver
		if silver > 0 then
			tinsert(private.textMoneyParts, private:FormatNumber(silver, shouldPad, color)..silverText)
			shouldPad = pad
		end
		-- add copper
		if copper > 0 then
			tinsert(private.textMoneyParts, private:FormatNumber(copper, shouldPad, color)..copperText)
			shouldPad = pad
		end
		text = table.concat(private.textMoneyParts, " ")
	else
		if gold > 0 then
			text = private:FormatNumber(gold, false, color)..goldText.." "..private:FormatNumber(silver, pad, color)..silverText.." "..private:FormatNumber(copper, pad, color)..copperText
		elseif silver > 0 then
			text = private:FormatNumber(silver, false, color)..silverText.." "..private:FormatNumber(copper, pad, color)..copperText
		else
			text = private:FormatNumber(copper, false, color)..copperText
		end
	end
	
	if isNegative then
		if color then
			return color..'-|r'..text
		else
			return '-'..text
		end
	else
		return text
	end
end

function m:MoneyFromString(value)
	-- remove any colors
	value = gsub(gsub(value:trim(), '\124c([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])', ''), '\124r', '')
	
	-- extract gold/silver/copper values
	local gold = tonumber(strmatch(value, '([0-9]+)g'))
	local silver = tonumber(strmatch(value, '([0-9]+)s'))
	local copper = tonumber(strmatch(value, '([0-9]+)c'))
	if not gold and not silver and not copper then return end
	
	-- test that there are no extra characters (other than spaces)
	value = gsub(value, '[0-9]+g', '', 1)
	value = gsub(value, '[0-9]+s', '', 1)
	value = gsub(value, '[0-9]+c', '', 1)
	if value:trim() ~= '' then return end
	
	return ((gold or 0) * COPPER_PER_GOLD) + ((silver or 0) * COPPER_PER_SILVER) + (copper or 0)
end

function m:format_number(num, pad, color)
	if num < 10 and pad then
		num = '0'..num
	end
	
	if color then
		return color..num..'|r'
	else
		return num
	end
end