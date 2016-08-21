aux.module 'post'

state = nil

function process()
	if m.state.posted < m.state.count then

		local stacking_complete

		local send_signal, signal_received = signal()
		control.when(signal_received, function()
			local slot = signal_received()[1]
			if slot then
				return m.post_auction(slot, m.process)
			else
				return m.stop()
			end
		end)

		return stack.start(m.state.item_key, m.state.stack_size, send_signal)
	end

	return m.stop()
end

function post_auction(slot, k)
	local item_info = info.container_item(unpack(slot))
	if item_info.item_key == m.state.item_key and info.auctionable(item_info.tooltip) and item_info.aux_quantity == m.state.stack_size then

		ClearCursor()
		ClickAuctionSellItemButton()
		ClearCursor()
		PickupContainerItem(unpack(slot))
		ClickAuctionSellItemButton()
		ClearCursor()

		StartAuction(max(1, round(m.state.unit_start_price * item_info.aux_quantity)), round(m.state.unit_buyout_price * item_info.aux_quantity), m.state.duration)

		local send_signal, signal_received = signal()
		control.when(signal_received, function()
			m.state.posted = m.state.posted + 1
			return k()
		end)

		local posted
		control.event_listener('CHAT_MSG_SYSTEM', function(kill)
			if arg1 == ERR_AUCTION_STARTED then
				send_signal()
				kill()
			end
		end)
	else
		return m.stop()
	end
end

function public.stop()
	if m.state then
		control.kill_thread(m.state.thread_id)

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

	local thread_id = control.thread(m.process)

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