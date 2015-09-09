AuctionatorLoaded = false

local val2gsc

-----------------------------------------

function Auctionator_Log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end
end

-----------------------------------------

function Auctionator_PluralizeIf(word, count)

	if count and count == 1 then
		return word
	else
		return word.."s"
	end
end

-----------------------------------------

function Auctionator_Round(v)
	return math.floor(v + 0.5)
end

-----------------------------------------

function Auctionator_PriceToString(val)

	local gold, silver, copper  = val2gsc(val)

	local st = ""
	
	if gold ~= 0 then
		st = gold.."g "
	end

	if st ~= "" then
		st = st..format("%02is ", silver)
	elseif silver ~= 0 then
		st = st..silver.."s "
	end
		
	if st ~= "" then
		st = st..format("%02ic", copper)
	elseif copper ~= 0 then
		st = st..copper.."c"
	end
	
	return st
end

-----------------------------------------

function val2gsc(v)
	local rv = Auctionator_Round(v)
	
	local g = math.floor(rv/10000)
	
	rv = rv - g * 10000
	
	local s = math.floor(rv/100)
	
	rv = rv - s * 100
	
	local c = rv
			
	return g, s, c
end

-----------------------------------------

function Auctionator_AddToSet(set, key)
    set[key] = true
end

function Auctionator_RemoveFromSet(set, key)
    set[key] = nil
end

function Auctionator_SetContains(set, key)
    return set[key] ~= nil
end

-----------------------------------------

function Auctionator_OnLoad()
	Auctionator_Log("Auctionator Loaded")
	AuctionatorLoaded = true
end

-----------------------------------------

function Auctionator_Core_OnEvent()
	if event == "VARIABLES_LOADED" then
		Auctionator_OnLoad()
	end
end