local NUM_MATCHES = 5

local item_names = {}
for item_id=1,100 do
	local name = GetItemInfo(item_id)
	tinsert(item_names, name)
end

function leven(s,t)
    if s == '' then return strlen(t) end
    if t == '' then return strlen(s) end
 
    local s1 = string.sub(s, 2, -1)
    local t1 = string.sub(t, 2, -1)
 
    if string.sub(s, 0, 1) == string.sub(t, 0, 1) then
        return leven(s1, t1)
    end
 
    return 1 + math.min(
        leven(s1, t1),
        leven(s, t1),
        leven(s1, t)
      )
end

function get_matches(input)
	local closest = {}
	for _, name in pairs(item_names) do
		local edit_distance = leven(input, name)
		if getn(closest) < NUM_MATCHES then
			tinsert(closest, { name=name, edit_distance=edit_distance })
		else
			sort(closest, function(a, b) return a.edit_distance > b.edit_distance end)
			if closest[1].edit_distance > edit_distance then
				closest[1] = { name=name, edit_distance=edit_distance }
			end
		end
	end
	
	for _, winner in ipairs(closest) do
		Aux.log(winner.name)
	end
end