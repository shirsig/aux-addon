local private, public = {}, {}
Aux.post = public

local state

function private.process()
	if state.posted < state.count or state.allow_partial then
		if state.posted == state.count then
			state.allow_partial = false
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

		Aux.control.wait_until(function() return stacking_complete end, function()

			if stack_slot and Aux.info.container_item(stack_slot.bag, stack_slot.bag_slot).aux_quantity <= state.stack_size then
				private.post_auction(stack_slot, function(stack_size)
					if state.posted == state.count then
						state.partial_stack = stack_size
					end
					state.posted = state.posted + 1
					return private.process()
				end)
			else
				return public.stop()
			end

		end)
	else
		return public.stop()
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
	StartAuction(max(1, Aux.round(state.unit_start_price * stack_size)), Aux.round(state.unit_buyout_price * stack_size), state.duration)
	Aux.control.wait_until(function() return not GetContainerItemInfo(slot.bag, slot.bag_slot) end, function()
		return k(stack_size)
	end)
end

function public.stop()
	if state then
		Aux.control.kill_thread(state.thread_id)

		local callback = state.callback
		local posted = state.posted
		local partial_stack = state.partial_stack

		state = nil

		if callback then
			callback(posted, partial_stack)
		end
	end
end

function public.start(item_key, stack_size, duration, unit_start_price, unit_buyout_price, count, allow_partial, callback)
	public.stop()

	local thread_id = Aux.control.new_thread(private.process)

	state = {
		thread_id = thread_id,
		item_key = item_key,
		stack_size = stack_size,
		duration = duration,
		unit_start_price = unit_start_price,
		unit_buyout_price = unit_buyout_price,
		count = count,
		allow_partial = allow_partial,
		posted = 0,
		callback = callback,
	}

end