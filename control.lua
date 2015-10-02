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



function Aux.control.event_listener(event, action) -- async!
	local self = {}
	
	local listener = { event=event, action=action }
	
	function self:set_action(self, action)
		listener.action = action
	end
	
	function self:start(self)
		Aux.util.set_add(event_listeners, listener)
		if not Aux.util.any(event_listeners, function(l) return l.event == event end) then
			AuxControlFrame:RegisterEvent(event)
		end
		return self
	end
	
	function self:stop(self)
		Aux.util.set_remove(event_listeners, listener)
		if not Aux.util.any(event_listeners, function(l) return l.event == event end) then
			AuxControlFrame:UnregisterEvent(event)
		end
		return self
	end
	
	return self
end

function Aux.control.update_listener(action)
	local self = {}
	
	local listener = { action=action }

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



function Aux.control.on_next_update(callback)
	local listener = Aux.control.update_listener()
	
	listener:set_action(function()
		listener:stop()
		callback()
	end)
	
	listener:start()
end

function Aux.control.as_soon_as(p, callback)
	local listener = Aux.control.update_listener()	
	
	listener:set_action(function()
		if p() then
			callback()
			listener:stop()
		end
	end)
	
	listener:start()
end

function Aux.control.on_next_event(event, callback)
	local ok
	
	local listener = Aux.control.event_listener(event)
	
	listener:set_action(function()
		listener:stop()
		ok = true
	end)
	
	listener:start()
	
	Aux.control.as_soon_as(function() return ok end, callback)
end



function Aux.control.timer()
	local self = {}
	
	local t_0
	
	function self:start(self)
		t_0 = GetTime()
	end
	
	function self:after(self, t, callback)
		Aux.util.as_soon_as(function() return t_0 and GetTime() - t_0 > t end, callback)
	end
	
	return self
end

function Aux.control.after_time(t, callback)
	local timer = Aux.control.timer()
	timer:start()
	timer:after(t, callback)
end
