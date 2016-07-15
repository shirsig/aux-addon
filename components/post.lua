local m, public, private = Aux.module'post'

private.state = nil

function private.process()
	if m.state.posted < m.state.count then

		local stacking_complete, target_slot

		Aux.stack.start(
			m.state.item_key,
			m.state.stack_size,
			function(slot)
				stacking_complete = true
				target_slot = slot
			end
		)

		return Aux.control.wait_until(function() return stacking_complete end, function()
			if target_slot then
				return m.post_auction(target_slot, m.process)
			else
				return m.stop()
			end
		end)
	end

	return m.stop()
end

function private.post_auction(slot, k)
	local item_info = Aux.info.container_item(unpack(slot))
	if item_info.item_key == m.state.item_key and Aux.info.auctionable(item_info.tooltip) and item_info.aux_quantity == m.state.stack_size then

		ClearCursor()
		ClickAuctionSellItemButton()
		ClearCursor()
		PickupContainerItem(unpack(slot))
		ClickAuctionSellItemButton()
		ClearCursor()

		StartAuction(max(1, Aux.round(m.state.unit_start_price * item_info.aux_quantity)), Aux.round(m.state.unit_buyout_price * item_info.aux_quantity), m.state.duration)

		local posted
		local listener = Aux.control.event_listener('CHAT_MSG_SYSTEM')
		listener:set_action(function()
			if arg1 == ERR_AUCTION_STARTED then
				posted = true
				listener:stop()
			end
		end)
		listener:start()
		Aux.control.wait_until(function() return posted end, function()
			m.state.posted = m.state.posted + 1
			return k()
		end)

	else
		return m.stop()
	end
end

function public.stop()
	if m.state then
		Aux.control.kill_thread(m.state.thread_id)

		local callback = m.state.callback
		local posted = m.state.posted

		m.state = nil

		if callback then
			callback(posted)
		end
	end
end

function public.start(item_key, stack_size, duration, unit_start_price, unit_buyout_price, count, callback)
	m.stop()

	local thread_id = Aux.control.new_thread(m.process)

	m.state = {
		thread_id = thread_id,
		item_key = item_key,
		stack_size = stack_size,
		duration = duration,
		unit_start_price = unit_start_price,
		unit_buyout_price = unit_buyout_price,
		count = count,
		posted = 0,
		callback = callback,
	}
end