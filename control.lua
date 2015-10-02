Aux.control = {}

local event_listeners = {}

local update_listeners = {}

function Aux.control.on_event()
	for listener, _ in pairs(event_listeners) do
		if event == listener.event then
			listener.action()
		end
	end
end

function Aux.control.on_update()
	for listener, _ in pairs(update_listeners) do
		listener.action()
	end
end

function Aux.control.event_listener(event, action)
	local listener = { event=event, action=action }
	local self = {}
	
	function self:set_action(self, action)
		listener.action = action
	end
	
	function self:start(self)
		Aux.util.set_add(event_listeners, listener)
		if not Aux.util.any(event_listeners, function(l) l.event == event end then
			AuxControlFrame:RegisterEvent(event)
		end
		return self
	end
	
	function self:stop(self)
		Aux.util.set_remove(event_listeners, listener)
		if not Aux.util.any(event_listeners, function(l) l.event == event end then
			AuxControlFrame:UnregisterEvent(event)
		end
		return self
	end
	
	return self
end

function Aux.control.update_listener(action)
	local listener = { action=action }
	
	local self = {}

	function self:set_action(self, action)
		listener.action = action
	end
	
	function self:start(self)
		Aux.util.set_add(update_listeners, listener)
		return self
	end
	
	function self:stop(self)
		Aux.util.set_remove(update_listeners, listener)
		return self
	end
	
	return self
end

function Aux.control.on_next_event(event, action)
	local listener = Aux.control.event_listener(event)
	listener.set_action(function()
		listener.stop()
		action()
	end
	listener.start()
end

function Aux.control.on_next_update(action)
	local listener = Aux.control.update_listener()
	listener.set_action(function()
		listener.stop()
		action()
	end
	listener.start()
end

function Aux.control.controller()
	local state
	local self = {}
	
	local listener = Aux.control.update_listener(function()
		if state then
			local continue, continuation = state.continue, state.continuation
			if continue() then
				state = nil
				continuation()
			end
		end
	end)()
	
	function self:cleanup(self)
		listener.stop()
	end
	
	function self:wait(self, p, k)
		state = {
			continuation = k
			continue = p
		}
	end
	
	function self:wait_for_event(self, event, k)
		self:wait(function()
	end
	
	return self
end
