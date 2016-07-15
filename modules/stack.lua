local m, private, public = Aux.module'stack'

local state

function private.stack_size(slot)
    local container_item_info = Aux.info.container_item(unpack(slot))
    return container_item_info and container_item_info.count or 0
end

function private.charges(slot)
    local container_item_info = Aux.info.container_item(unpack(slot))
	return container_item_info and container_item_info.charges
end

function private.max_stack(slot)
	local container_item_info = Aux.info.container_item(unpack(slot))
	return container_item_info and container_item_info.max_stack
end

function private.locked(slot)
	local container_item_info = Aux.info.container_item(unpack(slot))
	return container_item_info and container_item_info.locked
end

function private.find_item_slot(partial)
	for slot in Aux.util.inventory() do
		if m.matching_item(slot, partial) and not Aux.util.table_eq(slot, state.target_slot) then
			return slot
		end
	end
end

function private.matching_item(slot, partial)
	local item_info = Aux.info.container_item(unpack(slot))
	return item_info and item_info.item_key == state.item_key and Aux.info.auctionable(item_info.tooltip) and (not partial or item_info.count < item_info.max_stack)
end

function private.find_empty_slot()
	for slot, type in Aux.util.inventory() do
		if type == 1 and not GetContainerItemInfo(unpack(slot)) then
			return slot
		end
	end
end

function private.find_charge_item_slot()
	for slot in Aux.util.inventory() do
		if m.matching_item(slot) and m.charges(slot) == state.target_size then
			return slot
		end
	end
end

function private.move_item(from_slot, to_slot, amount, k)

	if m.locked(from_slot) or m.locked(to_slot) then
		return Aux.control.wait(k)
	end

	amount = min(m.max_stack(from_slot) - m.stack_size(to_slot), m.stack_size(from_slot), amount)
	local expected_size = m.stack_size(to_slot) + amount

	ClearCursor()
	SplitContainerItem(from_slot[1], from_slot[2], amount)
	PickupContainerItem(unpack(to_slot))

	return Aux.control.wait_until(function() return m.stack_size(to_slot) == expected_size end, k)
end

function private.process()

	if not state.target_slot or not m.matching_item(state.target_slot) then
		state.target_slot = m.find_item_slot()
		if not state.target_slot then
			return m.stop()
		end
	end

	if m.charges(state.target_slot) then
		state.target_slot = m.find_charge_item_slot()
		return m.stop()
	end

	if m.stack_size(state.target_slot) > state.target_size then
		local slot = m.find_item_slot(true) or m.find_empty_slot()
		if slot then
			return m.move_item(
				state.target_slot,
				slot,
				m.stack_size(state.target_slot) - state.target_size,
				m.process
			)
		end
	elseif m.stack_size(state.target_slot) < state.target_size then
		local slot = m.find_item_slot()
		if slot then
			return m.move_item(
				slot,
				state.target_slot,
				state.target_size - m.stack_size(state.target_slot),
				m.process
			)
		end
	end
		
	return m.stop()
end

function public.stop()
	if state then
		Aux.control.kill_thread(state.thread_id)

		local callback, slot = state.callback, state.target_slot
		if slot and not m.matching_item(slot) then
			slot = nil
		end
		
		state = nil
		
		if callback then
			callback(slot)
		end
	end
end

function public.start(item_key, size, callback)
	m.stop()

	local thread_id = Aux.control.new_thread(m.process)

	state = {
		thread_id = thread_id,
		item_key = item_key,
		target_size = size,
		callback = callback,
	}
end