-- Für Ben zum bearbeiten

local addon, ns = ...	-- addon ist der Name des Addons, ns ist der 'namespace' (ns.lootliste z.B. kann somit auch aus anderen Dateien des Addons abgerufen werden)

local eventFrameEvent = function(self, event, ...) -- ... sind die restlichen Parameter
	if event == "PLAYER_STARTED_MOVING" then
		-- code
	end
end

-- Ein Frame, um Events registrieren zu können:
ns.eventFrame = CreateFrame("Frame", addon .. "EventFrame", UIParent)
-- Registrieren eines Events:
ns.eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
-- Füttern der Funktion, wenn das Event passiert:
ns.eventFrame:SetScript("OnEvent", eventFrameEvent)
