AuctionatorVersion = "1.2.0-Vanilla"
AuctionatorAuthors = "Zirco (Original); Nimeral (Backport); shirsig, Zerf (Update)"

AuctionatorLoaded = false

local val2gsc

-----------------------------------------

function Auctionator_Log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
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

function Auctionator_AddToSet(set, key)
    set[key] = true
end

function Auctionator_RemoveFromSet(set, key)
    set[key] = nil
end

function Auctionator_SetContains(set, key)
    return set[key] ~= nil
end

function Auctionator_SetSize(set)
    local size = 0
	for _,_ in pairs(set) do
		size = size + 1
	end
	return size
end

-----------------------------------------

function Auctionator_OnLoad()
	Auctionator_Log("Auctionator v"..AuctionatorVersion.." loaded")
	AuctionatorLoaded = true
end

-----------------------------------------

function Auctionator_Core_OnEvent()
	if event == "VARIABLES_LOADED" then
		Auctionator_OnLoad()
	end
end