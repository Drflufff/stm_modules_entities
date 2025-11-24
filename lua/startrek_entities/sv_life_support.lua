StarTrekEntities = StarTrekEntities or {}
StarTrekEntities.LifeSupport = StarTrekEntities.LifeSupport or {}

local LifeSupport = StarTrekEntities.LifeSupport
LifeSupport.AutoRepairTimerId = "StarTrekEntities.LifeSupport.AutoRepair"

LifeSupport.DisabledDecks = LifeSupport.DisabledDecks or {}
LifeSupport.DisabledSections = LifeSupport.DisabledSections or {}
LifeSupport.DisruptorIndex = LifeSupport.DisruptorIndex or {}
LifeSupport.AlertSelection = LifeSupport.AlertSelection or "blue"
LifeSupport.AlertPriorities = LifeSupport.AlertPriorities or {
    none = 0,
    blue = 1,
    yellow = 2,
    intruder = 3,
    red = 4,
}
LifeSupport.AlertActive = LifeSupport.AlertActive or nil
LifeSupport.AlertEnabled = LifeSupport.AlertEnabled ~= false

local function isTableEmpty(t)
    return not (istable(t) and next(t) ~= nil)
end

local function resolveSectionName(deck, section)
    if Star_Trek and Star_Trek.Sections and Star_Trek.Sections.GetSectionName then
        local name = Star_Trek.Sections:GetSectionName(deck, section)
        if isstring(name) and name ~= "" then
            return string.format("Deck %d - %s", deck, name)
        end
    end

    return string.format("Deck %d - Section %s", deck, tostring(section))
end

function LifeSupport:GetSectionDescriptor(deck, section)
    if section == nil then
        return string.format("Deck %d", deck)
    end

    return resolveSectionName(deck, section)
end

function LifeSupport:GetZoneLabel(map, fallback)
    if not istable(map) then
        return fallback
    end

    for ent in pairs(map) do
        if IsValid(ent) and ent.GetTargetDescription then
            local desc = ent:GetTargetDescription()
            if isstring(desc) and desc ~= "" then
                return desc
            end
        end
    end

    return fallback
end

function LifeSupport:GetAlertPriority(alert)
    if not isstring(alert) or alert == "" then
        return 0
    end

    local key = string.lower(alert)
    if self.AlertPriorities[key] then
        return self.AlertPriorities[key]
    end

    if Star_Trek and Star_Trek.Alert and Star_Trek.Alert.AlertTypes and Star_Trek.Alert.AlertTypes[key] then
        return 1
    end

    return 0
end

function LifeSupport:NormalizeAlertName(alert)
    if not isstring(alert) then
        return nil
    end

    local trimmed = string.Trim(string.lower(alert))
    if trimmed == "" then
        return nil
    end

    if trimmed == "none" then
        return "none"
    end

    if Star_Trek and Star_Trek.Alert and Star_Trek.Alert.AlertTypes then
        if Star_Trek.Alert.AlertTypes[trimmed] then
            return trimmed
        end
    else
        return trimmed
    end

    return nil
end

function LifeSupport:GetAvailableAlerts()
    local options = {"none"}

    if Star_Trek and Star_Trek.Alert and Star_Trek.Alert.AlertTypes then
        for name in pairs(Star_Trek.Alert.AlertTypes) do
            table.insert(options, name)
        end
    else
        table.insert(options, "blue")
    end

    table.sort(options, function(a, b)
        local pa = self:GetAlertPriority(a)
        local pb = self:GetAlertPriority(b)
        if pa == pb then
            return a < b
        end
        return pa < pb
    end)

    local dedup = {}
    local unique = {}
    for _, name in ipairs(options) do
        if not dedup[name] then
            dedup[name] = true
            table.insert(unique, name)
        end
    end

    return unique
end

function LifeSupport:SetAlertSelection(alert)
    local normalized = self:NormalizeAlertName(alert)
    if not normalized then
        normalized = self:NormalizeAlertName(self.AlertSelection) or "blue"
    end

    self.AlertSelection = normalized

    local core = self:GetCore()
    if IsValid(core) and core.SetOutageAlert then
        local current = core.GetOutageAlert and self:NormalizeAlertName(core:GetOutageAlert()) or nil
        if current ~= normalized then
            core:SetOutageAlert(normalized)
        end
    end

    self:UpdateAlertState()
end

function LifeSupport:GetAlertSelection()
    local core = self:GetCore()
    if IsValid(core) and core.GetOutageAlert then
        local alert = self:NormalizeAlertName(core:GetOutageAlert())
        if alert then
            return alert
        end
    end

    return self.AlertSelection or "blue"
end

function LifeSupport:GetAlertFriendlyName(alert)
    if not alert or alert == "" then
        return "Unknown Alert"
    end

    local key = string.lower(alert)
    if key == "none" then
        return "No Alert"
    end

    return string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2) .. " Alert"
end

function LifeSupport:GetAlertSelectionLabel()
    return self:GetAlertFriendlyName(self:GetAlertSelection())
end

function LifeSupport:IsAlertEnabled()
    local core = self:GetCore()
    if IsValid(core) and core.GetOutageAlertsEnabled then
        return core:GetOutageAlertsEnabled() ~= false
    end

    if self.AlertEnabled ~= nil then
        return self.AlertEnabled ~= false
    end

    return true
end

function LifeSupport:SetAlertEnabled(state)
    local enabled = state ~= false
    self.AlertEnabled = enabled

    local core = self:GetCore()
    if IsValid(core) and core.SetOutageAlertsEnabled then
        if core:GetOutageAlertsEnabled() ~= enabled then
            core:SetOutageAlertsEnabled(enabled)
        end
    end

    self:UpdateAlertState()
end

function LifeSupport:OnCoreAlertToggleChanged(core, enabled)
    if self:GetCore() ~= core then return end
    self.AlertEnabled = enabled ~= false
    self:UpdateAlertState()
end

function LifeSupport:OnCoreAlertModeChanged(core, mode)
    if self:GetCore() ~= core then return end
    local normalized = self:NormalizeAlertName(mode)
    if normalized then
        self.AlertSelection = normalized
    end
    self:UpdateAlertState()
end

function LifeSupport:SyncAlertConfiguration()
    local core = self:GetCore()
    if IsValid(core) then
        if core.GetOutageAlert then
            local alert = self:NormalizeAlertName(core:GetOutageAlert())
            if alert then
                self.AlertSelection = alert
            end
        end

        if core.GetOutageAlertsEnabled then
            self.AlertEnabled = core:GetOutageAlertsEnabled() ~= false
        end
    else
        self.AlertSelection = self:NormalizeAlertName(self.AlertSelection) or "blue"
    end

    self:UpdateAlertState()
end

function LifeSupport:CycleAlertSelection(direction)
    direction = direction or 1
    local options = self:GetAvailableAlerts()
    if #options == 0 then
        return self:GetAlertSelection()
    end

    local current = self:GetAlertSelection()
    local index = 1
    for i, name in ipairs(options) do
        if name == current then
            index = i
            break
        end
    end

    local newIndex = ((index - 1 + direction) % #options) + 1
    local newAlert = options[newIndex]
    self:SetAlertSelection(newAlert)
    return newAlert
end

function LifeSupport:HasActiveDisruptions()
    for _, map in pairs(self.DisabledDecks) do
        if not isTableEmpty(map) then
            return true
        end
    end

    for _, deckSections in pairs(self.DisabledSections) do
        for _, map in pairs(deckSections) do
            if not isTableEmpty(map) then
                return true
            end
        end
    end

    return false
end

function LifeSupport:GetDisruptionSummary()
    local summary = {}

    for deck, map in pairs(self.DisabledDecks) do
        if not isTableEmpty(map) then
            local label = self:GetZoneLabel(map, self:GetSectionDescriptor(deck))
            table.insert(summary, {
                deck = deck,
                deckWide = true,
                label = label,
                message = string.format("%s environmental controls offline.", label),
            })
        end
    end

    for deck, sections in pairs(self.DisabledSections) do
        for sectionId, map in pairs(sections) do
            if not isTableEmpty(map) then
                local fallback = self:GetSectionDescriptor(deck, sectionId)
                local label = self:GetZoneLabel(map, fallback)
                table.insert(summary, {
                    deck = deck,
                    section = sectionId,
                    deckWide = false,
                    label = label,
                    message = string.format("%s environmental controls offline.", label),
                })
            end
        end
    end

    table.sort(summary, function(a, b)
        if a.deck == b.deck then
            local ap = a.deckWide and 0 or 1
            local bp = b.deckWide and 0 or 1
            if ap == bp then
                return (a.section or 0) < (b.section or 0)
            end
            return ap < bp
        end
        return a.deck < b.deck
    end)

    return summary
end

function LifeSupport:DetermineAlertToTrigger()
    if not self:IsAlertEnabled() then
        return nil
    end

    if not self:HasActiveDisruptions() then
        return nil
    end

    local selection = self:GetAlertSelection()
    if selection == "none" then
        return nil
    end

    if Star_Trek and Star_Trek.Alert and Star_Trek.Alert.AlertTypes then
        if not Star_Trek.Alert.AlertTypes[selection] then
            return nil
        end
    end

    return selection
end

function LifeSupport:UpdateAlertState()
    local desired = self:DetermineAlertToTrigger()
    if not (Star_Trek and Star_Trek.Alert and Star_Trek.Alert.Enable and Star_Trek.Alert.Disable) then
        self.AlertActive = nil
        return
    end

    local alertSystem = Star_Trek.Alert
    local current = alertSystem.ActiveAlert

    if desired then
        if self.AlertActive and self.AlertActive ~= desired then
            local ok = alertSystem:Enable(desired)
            if ok then
                self.AlertActive = desired
            end
            return
        end

        local currentPriority = self:GetAlertPriority(current)
        local desiredPriority = self:GetAlertPriority(desired)

        if not self.AlertActive then
            if not current or desiredPriority > currentPriority then
                local ok = alertSystem:Enable(desired)
                if ok then
                    self.AlertActive = desired
                end
            elseif current == desired then
                self.AlertActive = desired
            end
        else
            if current ~= desired then
                local ok = alertSystem:Enable(desired)
                if ok then
                    self.AlertActive = desired
                end
            end
        end
    else
        if self.AlertActive and current == self.AlertActive then
            alertSystem:Disable()
        end
        self.AlertActive = nil
    end

    if self.AlertActive and alertSystem.ActiveAlert ~= self.AlertActive then
        self.AlertActive = nil
    end
end

function LifeSupport:ClearDisruptions()
    self.DisabledDecks = {}
    self.DisabledSections = {}
    self.DisruptorIndex = {}
    self:UpdateAlertState()
end

local function registerDisruption(ent, deck, section)
    if not IsValid(ent) then return end
    deck = tonumber(deck)
    if not deck then return end

    LifeSupport.DisruptorIndex[ent] = {deck = deck, section = section}

    if section == nil then
        LifeSupport.DisabledDecks[deck] = LifeSupport.DisabledDecks[deck] or {}
        LifeSupport.DisabledDecks[deck][ent] = true
    else
        section = tonumber(section)
        if not section then return end
        LifeSupport.DisabledSections[deck] = LifeSupport.DisabledSections[deck] or {}
        LifeSupport.DisabledSections[deck][section] = LifeSupport.DisabledSections[deck][section] or {}
        LifeSupport.DisabledSections[deck][section][ent] = true
    end

    LifeSupport:UpdateAlertState()
end

local function unregisterDisruption(ent)
    local info = LifeSupport.DisruptorIndex[ent]
    if not info then return end

    local deck = info.deck
    local section = info.section

    if section == nil then
        local deckMap = LifeSupport.DisabledDecks[deck]
        if deckMap then
            deckMap[ent] = nil
            if isTableEmpty(deckMap) then
                LifeSupport.DisabledDecks[deck] = nil
            end
        end
    else
        local deckSections = LifeSupport.DisabledSections[deck]
        if deckSections then
            local sectionMap = deckSections[section]
            if sectionMap then
                sectionMap[ent] = nil
                if isTableEmpty(sectionMap) then
                    deckSections[section] = nil
                    if isTableEmpty(deckSections) then
                        LifeSupport.DisabledSections[deck] = nil
                    end
                end
            end
        end
    end

    LifeSupport.DisruptorIndex[ent] = nil
    LifeSupport:UpdateAlertState()
end

hook.Add("OnDisableLifeSupportSectionCreated", "StarTrekEntities.LifeSupport.TrackSections", function(ent)
    if not ent or ent.Deck == nil or ent.Section == nil then return end
    registerDisruption(ent, ent.Deck, ent.Section)
end)

hook.Add("OnDisableLifeSupportSectionRemoved", "StarTrekEntities.LifeSupport.TrackSections", function(ent)
    unregisterDisruption(ent)
end)

hook.Add("OnDisableLifeSupportDeckCreated", "StarTrekEntities.LifeSupport.TrackDecks", function(ent)
    if not ent or ent.Deck == nil then return end
    registerDisruption(ent, ent.Deck, nil)
end)

hook.Add("OnDisableLifeSupportDeckRemoved", "StarTrekEntities.LifeSupport.TrackDecks", function(ent)
    unregisterDisruption(ent)
end)

hook.Add("PostCleanupMap", "StarTrekEntities.LifeSupport.ResetDisruptions", function()
    LifeSupport:ClearDisruptions()
end)

local function updateStatus(source)
    if not StarTrekEntities or not StarTrekEntities.SetStatus then return end
    local online = LifeSupport:IsOnline()
    StarTrekEntities:SetStatus("lifesupport", "active", online)
    hook.Run("StarTrekEntities.LifeSupportPowerChanged", source, online)
end

function LifeSupport:SetCore(ent)
    if IsValid(ent) then
        self.Core = ent
    else
        self.Core = nil
    end
    self:SyncAlertConfiguration()
    updateStatus(ent)
end

function LifeSupport:GetCore()
    if IsValid(self.Core) then
        return self.Core
    end
    return nil
end

function LifeSupport:IsOnline()
    local core = self:GetCore()
    if not IsValid(core) then
        return false
    end

    return core:IsOperational()
end

function LifeSupport:GetHealthPercent()
    local core = self:GetCore()
    if not IsValid(core) or not core.GetHealthPercent then
        return 0
    end

    return core:GetHealthPercent()
end

function LifeSupport:SetManualOverride(state, source)
    self.ManualOverride = state
    local core = self:GetCore()
    if IsValid(core) and core.SetManualOverride then
        core:SetManualOverride(state)
    end
    updateStatus(source or core)
end

function LifeSupport:ClearManualOverride(source)
    self.ManualOverride = nil
    local core = self:GetCore()
    if IsValid(core) and core.SetManualOverride then
        core:SetManualOverride(nil)
    end
    updateStatus(source or core)
end

function LifeSupport:SetPower(on, source)
    self:SetManualOverride(on and true or false, source)
end

function LifeSupport:Shutdown(source)
    self:SetManualOverride(false, source)
end

function LifeSupport:Enable(source)
    self:SetManualOverride(true, source)
end

function LifeSupport:IsAutoRepairRunning()
    return timer.Exists(self.AutoRepairTimerId)
end

function LifeSupport:RunRepair(panelEnt, ply)
    local core = self:GetCore()
    if not IsValid(core) then
        return false, "Life support core not found."
    end

    if core.GetLifeSupportHealth and core.GetLifeSupportMaxHealth then
        local hp = core:GetLifeSupportHealth()
        local maxhp = core:GetLifeSupportMaxHealth()
        if hp >= maxhp then
            return false, "Life support core already at full integrity."
        end
    end

    if self:IsAutoRepairRunning() then
        return false, "Automated repair cycle already in progress."
    end

    local timerId = self.AutoRepairTimerId
    local RUN_SECONDS = 60
    local function completeCycle(reason)
        if timer.Exists(timerId) then
            timer.Remove(timerId)
        end
        if IsValid(core) then
            core.AutoRepairActive = nil
        end
        if reason and Star_Trek and Star_Trek.Logs and IsValid(panelEnt) and IsValid(ply) then
            Star_Trek.Logs:AddEntry(panelEnt, ply, reason, Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil)
        end
    end

    core.AutoRepairActive = true

    timer.Create(timerId, 1, RUN_SECONDS, function()
        if not IsValid(core) then
            completeCycle()
            return
        end

        local hp = core:GetLifeSupportHealth() or 0
        local maxhp = core:GetLifeSupportMaxHealth() or 0
        if maxhp <= 0 then
            completeCycle()
            return
        end

        if hp >= maxhp then
            completeCycle("Automated repair cycle complete. Life support nominal.")
            return
        end

        local add = math.max(1, math.floor(maxhp * 0.02))
        if core.RepairAmount then
            core:RepairAmount(add)
        else
            core:SetHealth(math.Clamp(hp + add, 0, maxhp))
        end
    end)

    timer.Simple(RUN_SECONDS, function()
        if not IsValid(core) then return end
        if not core.AutoRepairActive then return end
        completeCycle("Automated repair cycle finished. Further maintenance recommended.")
    end)

    if Star_Trek and Star_Trek.Logs and IsValid(panelEnt) and IsValid(ply) then
        Star_Trek.Logs:AddEntry(panelEnt, ply, "Automated repair drones deployed. Running 60 second cycle.", Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil)
    end

    return true
end

function LifeSupport:BroadcastStatusChange(panelEnt, ply, message, color)
    if Star_Trek and Star_Trek.Logs and IsValid(panelEnt) then
        Star_Trek.Logs:AddEntry(panelEnt, ply, message, color or (Star_Trek.LCARS and Star_Trek.LCARS.ColorBlue or nil))
    end
end

hook.Add("OnLifeSupportCreated", "StarTrekEntities.LifeSupport.Track", function(ent)
    if not IsValid(ent) then return end
    LifeSupport:SetCore(ent)
end)

hook.Add("OnLifeSupportRemoved", "StarTrekEntities.LifeSupport.Track", function(ent)
    if LifeSupport:GetCore() == ent then
        LifeSupport:SetCore(nil)
    end
end)

hook.Add("OnLifeSupportDestroyed", "StarTrekEntities.LifeSupport.Destroyed", function(ent)
    if LifeSupport:GetCore() == ent then
        LifeSupport:SetManualOverride(false, ent)
    else
        updateStatus(ent)
    end
end)

hook.Add("OnLifeSupportRepaired", "StarTrekEntities.LifeSupport.Repaired", function(ent)
    if LifeSupport:GetCore() == ent then
        if LifeSupport.ManualOverride == true then
            LifeSupport:Enable(ent)
        else
            updateStatus(ent)
        end
    else
        updateStatus(ent)
    end
end)
