Aux.post = {
	orig = {}
}

local controller = (function()
	local controller
	return function()
		controller = controller or Aux.control.controller()
		return controller
	end
end)()

local state

local post_auction, stop, process

function process()
	if state.posted < state.count then
		local stacking_complete
		local stack_slot
		
		Aux.stack.start(
			state.name,
			state.stack_size,
			function(slot)
				stacking_complete = true
				stack_slot = slot
			end
		)
		
		controller().wait(function() return stacking_complete end, function()
		if stack_slot then
			post_auction(stack_slot, function()
				state.posted = state.posted + 1
				return process()
			end)
		else
			return stop()
		end
		end)
	else
		return stop()
	end
end

function Aux.post.stop(k)
	Aux.control.on_next_update(function()
		stop()
		
		if k then
			return k()
		end
	end)
end

function stop()
	controller().reset()
	if state then
		local callback = state.callback
		local posted = state.posted

		state = nil
		
		if callback then
			callback(posted)
		end
	end
end

function post_auction(slot, k)
	ClearCursor()
	ClickAuctionSellItemButton()
	ClearCursor()
	PickupContainerItem(slot.bag, slot.bag_slot)
	ClickAuctionSellItemButton()
	ClearCursor()
	StartAuction(state.bid, state.buyout, state.duration)
	controller().wait(function() return not GetContainerItemInfo(slot.bag, slot.bag_slot) end, k)
end

function Aux.post.start(name, stack_size, duration, bid, buyout, count, callback)
	Aux.control.on_next_update(function()
		stop()
		
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
		
		return process()
	end)
end