local m = {}
Aux.money = m

local GOLD_TEXT = '|cffffd70ag|r'
local SILVER_TEXT = '|cffc7c7cfs|r'
local COPPER_TEXT = '|cffeda55fc|r'
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000

function m.to_string(money, pad, trim, color, no_color)

	local is_negative = money < 0
	money = abs(money)
	local gold = floor(money / COPPER_PER_GOLD)
	local silver = floor(mod(money, COPPER_PER_GOLD) / COPPER_PER_SILVER)
	local copper = Aux.round(mod(money, COPPER_PER_SILVER))
	local gold_text, silver_text, copper_text
	if no_color then
		gold_text, silver_text, copper_text = 'g', 's', 'c'
	else
		gold_text, silver_text, copper_text = GOLD_TEXT, SILVER_TEXT, COPPER_TEXT
	end
	
	if money == 0 then
		return m.format_number(0, false, color)..copper_text
	end
	
	local text
	if trim then
		local parts = {}
		if gold > 0 then
			tinsert(parts, private:format_number(gold, false, color)..gold_text)
		end
		if silver > 0 then
			tinsert(parts, private:format_number(silver, pad, color)..silver_text)
		end
		if copper > 0 then
			tinsert(parts, private:format_number(copper, pad, color)..copper_text)
		end
		text = Aux.util.join(parts, ' ')
	else
		if gold > 0 then
			text = m.format_number(gold, false, color)..gold_text..' '..m.format_number(silver, pad, color)..silver_text..' '..m.format_number(copper, pad, color)..copper_text
		elseif silver > 0 then
			text = m.format_number(silver, false, color)..silver_text..' '..m.format_number(copper, pad, color)..copper_text
		else
			text = m.format_number(copper, false, color)..copper_text
		end
	end
	
	if is_negative then
		if color then
			text = color..'-|r'..text
		else
			text = '-'..text
		end
	end

	return text
end

function m.from_string(value)
	-- remove any colors
	value = gsub(gsub(value, '\124c([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])', ''), '\124r', '')

	-- extract gold/silver/copper values
	local gold = tonumber(({strfind(value, '(%d*%.?%d+)g')})[3])
	local silver = tonumber(({strfind(value, '(%d*%.?%d+)s')})[3])
	local copper = tonumber(({strfind(value, '(%d*%.?%d+)c')})[3])
--	if not gold and not silver and not copper then return end

	-- test that there are no extra characters (other than spaces)
	value = gsub(value, '%d*%.?%d+g', '', 1)
	value = gsub(value, '%d*%.?%d+s', '', 1)
	value = gsub(value, '%d*%.?%d+c', '', 1)
	if strfind(value, '%S') then return 0 end
	
	return ((gold or 0) * COPPER_PER_GOLD) + ((silver or 0) * COPPER_PER_SILVER) + (copper or 0)
end

function m.format_number(num, pad, color)
	if num < 10 and pad then
		num = '0'..num
	end
	
	if color then
		return color..num..'|r'
	else
		return num
	end
end