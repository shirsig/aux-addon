AuctionatorLoaded = false

-----------------------------------------

function Auctionator_Log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end
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