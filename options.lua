Aux.options = {}

AUX_SELL_SHORTCUT = true
AUX_BUY_SHORTCUT = true
AUX_OPEN_SELL = false
AUX_OPEN_BUY = false
AUX_INSTANT_BUYOUT = false

AUX_AUCTION_DURATION = 'long'

function Aux.options.show_description()

	AuxAboutFrame:Show()
	
	AuxAboutDescriptionHTML:SetText("<html><body>"
			.."<h1>What is Aux?</h1><br/>"
			.."<p>"
			.."Aux adds two tabs to the traditional auction house layout, Aux Sell and  Aux Buy, which make selling and buying respectively a much more streamlined experience by automating a lot of the annoying little tasks involved in managing your auctions and providing you with much better information to base decisions on."
			.."</p><br/><h1>Aux Sell</h1><br/><p>"
			.."The Aux Sell panel gives you pricing suggestions based on existing auctions (undercutting by 1 copper) when you put an item in the auction slot. Aux will cache search results so that you don't have to wait several seconds to minutes between auctions. If you need to update the information there's a refresh button. You can further select a specific entry from the list to base the pricing suggestion on if you don't like its default choice."
			.."</p><br/><h1>Aux Buy</h1><br/><p>"
			.."The Aux Buy panel makes a multi-page search for you and lists all items with the most relevant information sorted by unit price. From that list you can select all the auctions you want to buy and after your confirmation Aux then makes another multi-page search, picking up all the selected auctions in the process. At the end you're presented with a report about what has been purchased."
			.."</p>"
			.."</body></html>")			
	AuxAboutDescriptionHTML:SetSpacing(3)
	AuxAboutAuthorText:SetText("Authors: "..AuxAuthors)
	
end

-----------------------------------------

function Aux.options.show()

	AuxOptionsFrame:Show()
	AuxOptionsFrame:SetBackdropColor(0,0,0,100)
	
	AuxOptionsConfigTitleText:SetText("Aux Options for "..UnitName("player"))
	AuxOptionsSummary:SetText("Aux is an addon designed to make it easier and faster to setup your auctions and find the best deals at the auction house.")
	AuxOptionsVersionText:SetText("Version: "..AuxVersion)
	
	AuxOptionsSellShortcut:SetChecked(AUX_SELL_SHORTCUT)
	AuxOptionsBuyShortcut:SetChecked(AUX_BUY_SHORTCUT)
	AuxOptionsOpenSell:SetChecked(AUX_OPEN_SELL)
	AuxOptionsOpenBuy:SetChecked(AUX_OPEN_BUY)
	AuxOptionsInstantBuyout:SetChecked(AUX_INSTANT_BUYOUT)
	
end

-----------------------------------------

function Aux.options.save()

	AUX_SELL_SHORTCUT = AuxOptionsSellShortcut:GetChecked()
	AUX_BUY_SHORTCUT = AuxOptionsBuyShortcut:GetChecked()
	AUX_OPEN_SELL = AuxOptionsOpenSell:GetChecked()
	AUX_OPEN_BUY = AuxOptionsOpenBuy:GetChecked()
	AUX_INSTANT_BUYOUT = AuxOptionsInstantBuyout:GetChecked()
	
end

-----------------------------------------

function Aux.options.show_sell_shortcut_tooltip()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Aux Sell shortcut", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, holding the Alt key down while clicking an item in your bags will switch to the Aux Sell panel, place the item in the Auction Item area and suggest a price.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Aux.options.show_buy_shortcut_tooltip()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Aux Buy Shortcut", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, holding the Control key down while clicking an item in your bags will switch to the Aux Buy panel and start a search.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Aux.options.show_open_sell_tooltip()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Start on Aux Sell panel", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, the Aux Sell panel will display first whenever you open the Auction House window.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Aux.options.show_open_buy_tooltip()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Start on Aux Buy panel", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, the Aux Buy panel will display first whenever you open the Auction House window.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Aux.options.show_instant_buyout_tooltip()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Instant buyout", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, right-clicking on an auction in the Browse tab will instantly buy it out.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end
