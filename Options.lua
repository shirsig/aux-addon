local BoolToString, BoolToNum, NumToBool

function Auctionator_ShowDescriptionFrame()
	AuctionatorDescriptionFrame:Show()
	
	AuctionatorDescriptionHTML:SetText("<html><body>"
			.."<h1>What is Auctionator?</h1><br/>"
			.."<p>"
			.."Figuring out a good buyout price when posting auctions can be tedious and time-consuming.  If you're like most people, you first browse the current "
			.."auctions to get a sense of how much your item is currently selling for.  Then you undercut the lowest price by a bit.  If you're creating multiple auctions "
			.."you're bouncing back and forth between the Browse tab and the Auctions tab, doing lots of division in "
			.."your head, and doing lots of clicking and typing."
			.."</p><br/><h1>How it works</h1><br/><p>"
			.."Auctionator makes this whole process easy and streamlined.  When you select an item to auction, Auctionator displays a summary of all the current auctions for "
			.."that item sorted by per-item price.  Auctionator also calculates a recommended buyout price based on the cheapest per-item price for your item.  If you're "
			.."selling a stack rather than a single item, Auctionator bases its recommended buyout price on the cheapest stack of the same size."
			.."</p><br/><p>"
			.."If you don't like Auctionator's recommendation, you can click on any line in the summary and Auctionator will recalculate the recommended buyout price based "
			.."on that auction.  Of course, you can always override Auctionator's recommendation by just typing in your own buyout price."
			.."</p><br/><p>"
			.."With Auctionator, creating an auction is usually just a matter of picking an item to auction and clicking the Create Auction button."
			.."</p>"
			.."</body></html>")
			
	AuctionatorDescriptionHTML:SetSpacing(3)
	
	AuctionatorAuthorText:SetText("Author: "..AuctionatorAuthor)
end

-----------------------------------------

function Auctionator_ShowOptionsFrame()

	AuctionatorOptionsFrame:Show()
	AuctionatorOptionsFrame:SetBackdropColor(0,0,0,100)
	
	AuctionatorConfigFrameTitle:SetText("Auctionator Options for "..UnitName("player"))

	AuctionatorExplanation:SetText("Auctionator is an addon designed to make it easier and faster to setup your auctions at the auction house.")


	AuctionatorVersionText:SetText("Version: "..AuctionatorVersion)
	
	AuctionatorOption_Enable_Alt:SetChecked(AUCTIONATOR_ENABLE_ALT)
	AuctionatorOption_Open_First:SetChecked(AUCTIONATOR_OPEN_FIRST)
	AuctionatorOption_Instant_Buyout:SetChecked(AUCTIONATOR_INSTANT_BUYOUT)
end

-----------------------------------------

function AuctionatorOptionsSave()

	AUCTIONATOR_ENABLE_ALT = AuctionatorOption_Enable_Alt:GetChecked()
	AUCTIONATOR_OPEN_FIRST = AuctionatorOption_Open_First:GetChecked()
	AUCTIONATOR_INSTANT_BUYOUT = AuctionatorOption_Instant_Buyout:GetChecked()
	
end

-----------------------------------------

function Auctionator_ShowTooltip_EnableAlt()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Enable alt-key shortcut", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, holding the Alt key down while clicking an item in your bags will switch to the Auctionator panel, place the item in the Auction Item area, and start the scan.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Auctionator_ShowTooltip_OpenFirst()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Automatically open Auctionator panel", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, the Auctionator panel will display first whenever you open the Auction House window.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Auctionator_ShowTooltip_InstantBuyout()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Enable right-click instant buyout", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, right-clicking on an auction in the Browse tab will instantly buy it out", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end
