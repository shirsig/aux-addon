Aux.post = {
	orig = {}
}

local state

local post_auction

local DELAY = 0.5

local last_posted = GetTime()

function Aux.post.onupdate()
	if state then
		if state.auctioning then
			if not GetContainerItemInfo(state.auctioning.bag, state.auctioning.bag_slot) then
				state.auctioning = nil
				state.posted = state.posted + 1
			end
		end
		if state.posted < state.count then
			if not state.stacking and not state.auctioning then
				state.stacking = true
				Aux.stack.start(
					state.name,
					state.stack_size,
					function(slot)
						if state and slot then
							post_auction(slot)
						else
							Aux.post.stop()
						end
					end
				)
			end
		else
			Aux.post.stop()
		end
	end
end

function Aux.post.stop()
	if state then
		local callback = state.callback
		local posted = state.posted

		state = nil
		
		if callback then
			callback(posted)
		end
	end
end

function post_auction(slot)
	ClearCursor()
	ClickAuctionSellItemButton()
	ClearCursor()
	PickupContainerItem(slot.bag, slot.bag_slot)
	ClickAuctionSellItemButton()
	ClearCursor()
	StartAuction(state.bid, state.buyout, state.duration)
	state.auctioning = slot
	state.stacking = false
	 -- TODO CHAT_MSG_SYSTEM arg1
end

function Aux.post.start(name, stack_size, duration, bid, buyout, count, callback)
	Aux.post.stop()
	
	ClearCursor()
	ClickAuctionSellItemButton()
	ClearCursor()
	
	state = {
		name = name,
		stack_size = stack_size,
		duration = duration,
		bid = bid,
		buyout = buyout,
		count = count,
		posted = 0,
		callback = callback,
	}
end