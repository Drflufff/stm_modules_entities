if CLIENT then return end

-- Bridge control (life support / gravity) wiring
local CONTROL_NAME_LIFE = "life_support"
local CONTROL_NAME_GRAV = "gravity"

local setupComplete = false
local waitingTimer = "STM.ControlBridge.Wait"

local lifeShipStatus
local lifeDeckState = {}
local lifeSectionState = {}

local gravShipStatus
local gravDeckState = {}
local gravSectionState = {}

local function clearState(stateTable, clearFn)
    for key, data in pairs(stateTable) do
        clearFn(key, data)
    end
end

local function resetLifeSupportStatuses(ctrl)
    if lifeShipStatus ~= nil then
        ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.ACTIVE)
        lifeShipStatus = nil
    end

    clearState(lifeDeckState, function(deck)
        ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.ACTIVE, deck)
    end)
    lifeDeckState = {}

    clearState(lifeSectionState, function(_, data)
        ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.ACTIVE, data.deck, data.section)
    end)
    lifeSectionState = {}
end

local function resetGravityStatuses(ctrl)
    if gravShipStatus ~= nil then
        ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.ACTIVE)
        gravShipStatus = nil
    end

    clearState(gravDeckState, function(deck)
        ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.ACTIVE, deck)
    end)
    gravDeckState = {}

    clearState(gravSectionState, function(_, data)
        ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.ACTIVE, data.deck, data.section)
    end)
    gravSectionState = {}
end

local function collectActiveMap(source)
    local active = {}
    for key, map in pairs(source or {}) do
        if istable(map) and next(map) then
            active[key] = true
        end
    end
    return active
end

local function syncLifeSupportStatus()
    if not setupComplete then return end
    if not Star_Trek or not Star_Trek.Control then return end

    local ctrl = Star_Trek.Control
    local life = StarTrekEntities and StarTrekEntities.LifeSupport
    if not life then
        resetLifeSupportStatuses(ctrl)
        return
    end

    local shipOnline = true
    if life.IsOnline then
        shipOnline = life:IsOnline()
    end

    local desiredShip = shipOnline and ctrl.ACTIVE or ctrl.INOPERATIVE
    if desiredShip ~= lifeShipStatus then
        ctrl:SetStatus(CONTROL_NAME_LIFE, desiredShip)
        lifeShipStatus = desiredShip
    end

    local deckDisabled = collectActiveMap(life.DisabledDecks)

    for deck in pairs(deckDisabled) do
        ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.INOPERATIVE, deck)
    end

    for deck in pairs(lifeDeckState) do
        if not deckDisabled[deck] then
            ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.ACTIVE, deck)
        end
    end
    lifeDeckState = deckDisabled

    local sectionDisabled = {}
    for deck, sections in pairs(life.DisabledSections or {}) do
        if istable(sections) then
            for sectionId, map in pairs(sections) do
                if istable(map) and next(map) then
                    local key = string.format("%d:%d", deck, sectionId)
                    sectionDisabled[key] = {deck = deck, section = sectionId}
                    ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.INOPERATIVE, deck, sectionId)
                end
            end
        end
    end

    for key, data in pairs(lifeSectionState) do
        if not sectionDisabled[key] then
            ctrl:SetStatus(CONTROL_NAME_LIFE, ctrl.ACTIVE, data.deck, data.section)
        end
    end
    lifeSectionState = sectionDisabled
end

local lifeSyncQueued = false
local function queueLifeSync()
    if lifeSyncQueued then return end
    lifeSyncQueued = true
    timer.Simple(0, function()
        lifeSyncQueued = false
        syncLifeSupportStatus()
    end)
end

local function syncGravityStatus()
    if not setupComplete then return end
    if not Star_Trek or not Star_Trek.Control then return end

    local ctrl = Star_Trek.Control
    local gravity = StarTrekEntities and StarTrekEntities.Gravity
    if not gravity then
        resetGravityStatuses(ctrl)
        return
    end

    local shipOnline = true
    if gravity.IsOnline then
        shipOnline = gravity:IsOnline()
    end

    local desiredShip = shipOnline and ctrl.ACTIVE or ctrl.INOPERATIVE
    if desiredShip ~= gravShipStatus then
        ctrl:SetStatus(CONTROL_NAME_GRAV, desiredShip)
        gravShipStatus = desiredShip
    end

    local deckDisabled = collectActiveMap(gravity.DisabledDecks)

    for deck in pairs(deckDisabled) do
        ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.INOPERATIVE, deck)
    end

    for deck in pairs(gravDeckState) do
        if not deckDisabled[deck] then
            ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.ACTIVE, deck)
        end
    end
    gravDeckState = deckDisabled

    local sectionDisabled = {}
    for deck, sections in pairs(gravity.DisabledSections or {}) do
        if istable(sections) then
            for sectionId, map in pairs(sections) do
                if istable(map) and next(map) then
                    local key = string.format("%d:%d", deck, sectionId)
                    sectionDisabled[key] = {deck = deck, section = sectionId}
                    ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.INOPERATIVE, deck, sectionId)
                end
            end
        end
    end

    for key, data in pairs(gravSectionState) do
        if not sectionDisabled[key] then
            ctrl:SetStatus(CONTROL_NAME_GRAV, ctrl.ACTIVE, data.deck, data.section)
        end
    end
    gravSectionState = sectionDisabled
end

local gravSyncQueued = false
local function queueGravSync()
    if gravSyncQueued then return end
    gravSyncQueued = true
    timer.Simple(0, function()
        gravSyncQueued = false
        syncGravityStatus()
    end)
end

local function registerControlTypes()
    if setupComplete then return end
    if not Star_Trek or not Star_Trek.Control or not Star_Trek.Control.Register then return end

    Star_Trek.Control.Types = Star_Trek.Control.Types or {}

    if not Star_Trek.Control.Types[CONTROL_NAME_LIFE] then
        Star_Trek.Control:Register(CONTROL_NAME_LIFE, "Life Support")
    end

    if not Star_Trek.Control.Types[CONTROL_NAME_GRAV] then
        Star_Trek.Control:Register(CONTROL_NAME_GRAV, "Gravity Field Generators")
    end

    setupComplete = true

    hook.Add("OnDisableLifeSupportSectionCreated", "STM.ControlBridge.LifeSectionCreated", queueLifeSync)
    hook.Add("OnDisableLifeSupportSectionRemoved", "STM.ControlBridge.LifeSectionRemoved", queueLifeSync)
    hook.Add("OnDisableLifeSupportDeckCreated", "STM.ControlBridge.LifeDeckCreated", queueLifeSync)
    hook.Add("OnDisableLifeSupportDeckRemoved", "STM.ControlBridge.LifeDeckRemoved", queueLifeSync)
    hook.Add("OnLifeSupportDestroyed", "STM.ControlBridge.LifeDestroyed", queueLifeSync)
    hook.Add("OnLifeSupportRepaired", "STM.ControlBridge.LifeRepaired", queueLifeSync)
    hook.Add("StarTrekEntities.LifeSupportPowerChanged", "STM.ControlBridge.LifePower", queueLifeSync)
    hook.Add("PostCleanupMap", "STM.ControlBridge.LifeCleanup", function()
        resetLifeSupportStatuses(Star_Trek.Control)
        queueLifeSync()
    end)

    hook.Add("OnDisableGravitySectionCreated", "STM.ControlBridge.GravSectionCreated", queueGravSync)
    hook.Add("OnDisableGravitySectionRemoved", "STM.ControlBridge.GravSectionRemoved", queueGravSync)
    hook.Add("OnDisableGravityDeckCreated", "STM.ControlBridge.GravDeckCreated", queueGravSync)
    hook.Add("OnDisableGravityDeckRemoved", "STM.ControlBridge.GravDeckRemoved", queueGravSync)
    hook.Add("OnGravGenDestroyed", "STM.ControlBridge.GravDestroyed", queueGravSync)
    hook.Add("OnGravGenRepaired", "STM.ControlBridge.GravRepaired", queueGravSync)
    hook.Add("StarTrekEntities.GravityPowerChanged", "STM.ControlBridge.GravPower", queueGravSync)
    hook.Add("OnGravGenRemoved", "STM.ControlBridge.GravRemoved", queueGravSync)
    hook.Add("PostCleanupMap", "STM.ControlBridge.GravCleanup", function()
        resetGravityStatuses(Star_Trek.Control)
        queueGravSync()
    end)

    queueLifeSync()
    queueGravSync()
end

hook.Add("InitPostEntity", "STM.ControlBridge.Init", function()
    timer.Create(waitingTimer, 1, 0, function()
        if setupComplete then
            timer.Remove(waitingTimer)
            return
        end

        registerControlTypes()

        if setupComplete then
            timer.Remove(waitingTimer)
        end
    end)
end)
