select(2, ...) 'aux.util.money'

local aux = require 'aux'

M.GOLD_TEXT = '|cffffd70ag|r'
M.SILVER_TEXT = '|cffc7c7cfs|r'
M.COPPER_TEXT = '|cffeda55fc|r'

local COPPER_PER_GOLD = 10000
local COPPER_PER_SILVER = 100

function M.to_gsc(money)
	local gold = floor(money / COPPER_PER_GOLD)
	local silver = floor(mod(money, COPPER_PER_GOLD) / COPPER_PER_SILVER)
	local copper = mod(money, COPPER_PER_SILVER)
	return gold, silver, copper
end

function M.from_gsc(gold, silver, copper)
	return gold * COPPER_PER_GOLD + silver * COPPER_PER_SILVER + copper
end

function M.to_string2(money, exact, color)
	color = color or FONT_COLOR_CODE_CLOSE

	local TEXT_NONE = '0'

	local GOLD = 'ffd100'
	local SILVER = 'e6e6e6'
	local COPPER = 'c8602c'
	local START = '|cff%s%d' .. FONT_COLOR_CODE_CLOSE
	local PART = color .. '.|cff%s%02d' .. FONT_COLOR_CODE_CLOSE
	local NONE = '|cffa0a0a0' .. TEXT_NONE .. FONT_COLOR_CODE_CLOSE

	if not exact and money >= COPPER_PER_GOLD then
		money = aux.round(money / COPPER_PER_SILVER) * COPPER_PER_SILVER
	end
	local g, s, c = to_gsc(money)

	local str = ''

	local fmt = START
	if g > 0 then
		str = str .. format(fmt, GOLD, g)
		fmt = PART
	end
	if s > 0 or c > 0 then
		str = str .. format(fmt, SILVER, s)
		fmt = PART
	end
	if c > 0 then
		str = str .. format(fmt, COPPER, c)
	end
	if str == '' then
		str = NONE
	end
	return str
end

function M.to_string(money, pad, trim, color, no_color)
	local is_negative = money < 0
	money = abs(money)
	local gold, silver, copper = to_gsc(money)

	local gold_text, silver_text, copper_text
	if no_color then
		gold_text, silver_text, copper_text = 'g', 's', 'c'
	else
		gold_text, silver_text, copper_text = GOLD_TEXT, SILVER_TEXT, COPPER_TEXT
	end

	local text
	if trim then
		local parts = {}
		if gold > 0 then
			tinsert(parts, format_number(gold, false, color) .. gold_text)
		end
		if silver > 0 then
			tinsert(parts, format_number(silver, pad, color) .. silver_text)
		end
		if copper > 0 or gold == 0 and silver == 0 then
			tinsert(parts, format_number(copper, pad, color) .. copper_text)
		end
		text = aux.join(parts, ' ')
	else
		if gold > 0 then
			text = format_number(gold, false, color) .. gold_text .. ' ' .. format_number(silver, pad, color) .. silver_text .. ' ' .. format_number(copper, pad, color) .. copper_text
		elseif silver > 0 then
			text = format_number(silver, false, color) .. silver_text .. ' ' .. format_number(copper, pad, color) .. copper_text
		else
			text = format_number(copper, false, color) .. copper_text
		end
	end

	if is_negative then
		text = (color and color'-' or '-') .. text
	end

	return text
end

function M.from_string(value)
	local number = tonumber(value)
	if number and number >= 0 then
		return number * COPPER_PER_GOLD
	end

	value = gsub(gsub(strlower(value), '|c%x%x%x%x%x%x%x%x', ''), FONT_COLOR_CODE_CLOSE, '')

	local gold = tonumber(select(3, strfind(value, '(%d*%.?%d+)g')) or nil)
	local silver = tonumber(select(3, strfind(value, '(%d*%.?%d+)s')) or nil)
	local copper = tonumber(select(3, strfind(value, '(%d*%.?%d+)c')) or nil)
	if not gold and not silver and not copper then return end

	value = gsub(value, '%d*%.?%d+g', '', 1)
	value = gsub(value, '%d*%.?%d+s', '', 1)
	value = gsub(value, '%d*%.?%d+c', '', 1)
	if strfind(value, '%S') then return end

	return from_gsc(gold or 0, silver or 0, copper or 0)
end

function M.format_number(num, pad, color)
	num = format('%0' .. (pad and 2 or 0) .. 'd', num)
	if color then
		return color .. num .. FONT_COLOR_CODE_CLOSE
	else
		return num
	end
end