local private, public = {}, {}
Aux.post = public

local controller = (function()
	local controller
	return function()
		controller = controller or Aux.control.controller()
		return controller
	end
end)()

local state

function private.process()
	if state.posted < state.count or state.partial then
		if state.posted == state.count then
			state.partial = false
		end

		local stacking_complete
		local stack_slot
		
		Aux.stack.start(
			state.item_key,
			state.stack_size,
			function(slot)
				stacking_complete = true
				stack_slot = slot
			end
		)
		
		controller().wait(function() return stacking_complete end, function()

			if stack_slot and Aux.info.container_item(stack_slot.bag, stack_slot.bag_slot).aux_quantity <= state.stack_size then
				private.post_auction(stack_slot, function()
					state.posted = state.posted + 1
					return private.process()
				end)
			else
				return private.stop()
			end

		end)
	else
		return private.stop()
	end
end

function public.stop(k)
	Aux.control.on_next_update(function()
		private.stop()
		
		if k then
			return k()
		end
	end)
end

function private.stop()
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

function private.post_auction(slot, k)
	ClearCursor()
	ClickAuctionSellItemButton()
	ClearCursor()
	PickupContainerItem(slot.bag, slot.bag_slot)
	ClickAuctionSellItemButton()
	ClearCursor()
	local stack_size = Aux.info.container_item(slot.bag, slot.bag_slot).aux_quantity
	StartAuction(max(1, state.unit_start_price * stack_size), state.unit_buyout_price * stack_size, state.duration)
	controller().wait(function() return not GetContainerItemInfo(slot.bag, slot.bag_slot) end, k)
end

function public.start(item_key, stack_size, duration, unit_start_price, unit_buyout_price, count, allow_partial, callback)
	Aux.control.on_next_update(function()
		private.stop()
		
		state = {
            item_key = item_key,
			stack_size = stack_size,
			duration = duration,
			unit_start_price = unit_start_price,
			unit_buyout_price = unit_buyout_price,
			count = count,
			partial = allow_partial,
			posted = 0,
			callback = callback,
		}
		
		return private.process()
	end)
end