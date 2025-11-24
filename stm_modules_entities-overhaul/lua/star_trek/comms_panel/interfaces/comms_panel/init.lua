---------------------------------------
---------------------------------------
--         Star Trek Modules         --
--                                   --
--            Created by             --
--       Jan 'Oninoni' Ziegler       --
--                                   --
-- This software can be used freely, --
--    but only distributed by me.    --
--                                   --
--    Copyright © 2022 Jan Ziegler   --
---------------------------------------
---------------------------------------

---------------------------------------
--    LCARS Comms Panel | Server    --
---------------------------------------

if not istable(INTERFACE) then Star_Trek:LoadAllModules() return end
local SELF = INTERFACE

SELF.BaseInterface = "base"
SELF.LogType = "Communications Console"

function SELF:Open(ent)
    if game.GetMap() ~= "rp_intrepid_v1" then return false, "Wrong map" end

    -- Create a left-side button matrix like wall panel
    local success, matrixWindow = Star_Trek.LCARS:CreateWindow(
        "button_matrix",
        Vector(19.5, 4, -30.7),
        Angle(0, 110.4, 30.90),
        16,
        720,
        410,
        function(windowData, interfaceData, ply, buttonId)
        end,
        "Communications Console",
        nil,
        true
    )
    if not success then
        return false, matrixWindow
    end

    -- Second rows with the dignostics button and tha repair and shutodwn button
    local lastDiag = 0
    local lastPower = 0
    local DIAG_COOLDOWN = 5
    local POWER_COOLDOWN = 2
    local sRow1 = matrixWindow:CreateSecondaryButtonRow(32)
    matrixWindow:AddButtonToRow(sRow1, "Diagnostics", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorOrange, false, false, function(ply, buttonData)
        if CurTime() < (lastDiag + DIAG_COOLDOWN) then
            if Star_Trek and Star_Trek.Logs then
                Star_Trek.Logs:AddEntry(self.Ent, ply, "Diagnostics cooling down...", Star_Trek.LCARS.ColorBlue)
            end
            return true
        end
        lastDiag = CurTime()
        -- Begin diagnostics
        if Star_Trek and Star_Trek.Logs then
            Star_Trek.Logs:AddEntry(self.Ent, ply, "Communication diagnostics started", Star_Trek.LCARS.ColorBlue)
        end

        local steps = {
            "Checking power fluctuations",
            "Scanning signal integrity",
            "Verifying antenna alignment",
            "Validating subspace channel",
            "Measuring interference levels",
            "Calibrating transceivers",
            "Testing redundancy links",
            "Analyzing waveform stability",
            "Polling comms relays",
            "Finalizing diagnostics"
        }

        for i, msg in ipairs(steps) do
            timer.Simple(0.5 * i, function()
                if Star_Trek and Star_Trek.Logs and IsValid(self.Ent) then
                    Star_Trek.Logs:AddEntry(self.Ent, ply, msg, Star_Trek.LCARS.ColorBlue)
                end
            end)
        end

        timer.Simple(5.2, function()
            if not (Star_Trek and Star_Trek.Logs) then return end
            local hp = 0
            if StarTrekEntities and StarTrekEntities.Comms and StarTrekEntities.Comms.GetHealthPercent then
                hp = math.floor(StarTrekEntities.Comms:GetHealthPercent() or 0)
            end
            local note = (hp < 50) and " - Repair immedate repair required" or " - System within acceptable parameters"
            Star_Trek.Logs:AddEntry(self.Ent, ply, string.format("Diagnostics complete: System integeraty %d%%%s", hp, note), Star_Trek.LCARS.ColorBlue)
        end)
    end)

    local function getCycleTimerId()
        local ent = self.Ent
        return "CommsRepairColorCycle_" .. (IsValid(ent) and ent:EntIndex() or 0)
    end

    local function captureMatrixColors()
        matrixWindow._originalColors = {}
        for idx, btn in ipairs(matrixWindow.Buttons or {}) do
            matrixWindow._originalColors[idx] = btn.Color
        end
    end

    local function restoreMatrixColors()
        local original = matrixWindow._originalColors
        if not original then return end
        for idx, btn in ipairs(matrixWindow.Buttons or {}) do
            btn.Color = original[idx] or btn.Color
        end
        matrixWindow:Update()
        matrixWindow._originalColors = nil
    end

    self._repairSequence = {
        {math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)},
        {math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)},
        {math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)}
    }
    self._repairStep = 1
    local kpPos = Vector(30.8, -25.55, -30.6)
    local kpAng = Angle(-180, -66, 31.5)
    local kpAngHidden = Angle(kpAng.p, kpAng.y, kpAng.r + 180)
    self._keypadWindow = nil

    local function resetRepairSequence()
        self._repairSequence = {
            {math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)},
            {math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)},
            {math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)}
        }
        self._repairStep = 1
    end

    local function keypadCallback(windowData, interfaceData, ply2, values)
        if not self._keypadWindow or self._keypadWindow.Id ~= windowData.Id then
            self._keypadWindow = windowData
        end

        local ok = istable(values) and #values == 5
        if ok then
            for i = 1, 5 do
                if tonumber(values[i]) ~= tonumber(self._repairSequence[self._repairStep][i]) then
                    ok = false
                    break
                end
            end
        end

        if ok and self._repairStep < #self._repairSequence then
            self._repairStep = self._repairStep + 1
            if Star_Trek and Star_Trek.Logs then
                local a = self._repairSequence[self._repairStep]
                Star_Trek.Logs:AddEntry(self.Ent, ply2, string.format("Enter next code: %d %d %d %d %d", a[1], a[2], a[3], a[4], a[5]), Star_Trek.LCARS.ColorBlue)
            end
            if IsValid(self.Ent) then self.Ent:EmitSound("star_trek.lcars_beep2") end
            return true
        end

        if ok then
            if Star_Trek and Star_Trek.Logs then
                Star_Trek.Logs:AddEntry(self.Ent, ply2, "Authorization complete. Beginning automated repair.", Star_Trek.LCARS.ColorBlue)
            end
            if IsValid(self.Ent) then self.Ent:EmitSound("star_trek.lcars_close") end
            if StarTrekEntities and StarTrekEntities.Comms and StarTrekEntities.Comms.RunRepair then
                StarTrekEntities.Comms:RunRepair(self.Ent)
            end
            windowData.WindowAngles = kpAngHidden
            windowData.WVis = false
            Star_Trek.LCARS:UpdateWindow(self.Ent, windowData.Id, windowData)
            local interfaceData = Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[self.Ent]
            if interfaceData and interfaceData.Windows then
                interfaceData.Windows[windowData.Id] = nil
            end
            self._keypadWindow = nil
            resetRepairSequence()
            local cycleTimer = getCycleTimerId()
            if timer.Exists(cycleTimer) then timer.Remove(cycleTimer) end
            restoreMatrixColors()
            return true
        end

        if Star_Trek and Star_Trek.Logs then
            Star_Trek.Logs:AddEntry(self.Ent, ply2, "Invalid code.", Star_Trek.LCARS.ColorRed)
        end
        local cycleTimer = getCycleTimerId()
        if timer.Exists(cycleTimer) then timer.Remove(cycleTimer) end
        restoreMatrixColors()
        if IsValid(self.Ent) then self.Ent:EmitSound("star_trek.lcars_error") end
        return true
    end

    local function ensureKeypadWindow()
        local interfaceData = Star_Trek.LCARS and Star_Trek.LCARS.ActiveInterfaces and Star_Trek.LCARS.ActiveInterfaces[self.Ent]
        if not interfaceData then
            return false, "Interface unavailable."
        end

        if self._keypadWindow and self._keypadWindow.Id then
            local existing = interfaceData.Windows and interfaceData.Windows[self._keypadWindow.Id]
            if existing then
                return true, self._keypadWindow
            end

            local id = self._keypadWindow.Id
            local wins = interfaceData.Windows
            if istable(wins) then
                wins[id] = nil
            end

            if Star_Trek and Star_Trek.LCARS then
                local visAngles = self._keypadWindow.WindowAngles
                self._keypadWindow.WVis = false
                self._keypadWindow.WindowAngles = Angle(visAngles.p, visAngles.y, visAngles.r + 180)
                Star_Trek.LCARS:UpdateWindow(self.Ent, id, self._keypadWindow)
            end

            self._keypadWindow = nil
        end

        local ok, win = Star_Trek.LCARS:CreateWindow(
            "keypad",
            kpPos,
            kpAngHidden,
            16,
            195,
            400,
            keypadCallback,
            "Callibration Keypad",
            "KEYPAD"
        )
        if not ok then
            return false, win
        end

        interfaceData.Windows = interfaceData.Windows or {}
        local newId = table.insert(interfaceData.Windows, win)
        Star_Trek.LCARS:ApplyWindow(interfaceData, newId, win)

        win.WindowAngles = kpAngHidden
        win.WVis = false
        self._keypadWindow = win

        Star_Trek.LCARS:UpdateWindow(self.Ent, newId, win)
        return true, win
    end

    local sRow2 = matrixWindow:CreateSecondaryButtonRow(32)
    matrixWindow:AddButtonToRow(sRow2, "Repair Mode", nil, Star_Trek.LCARS.ColorOrange, Star_Trek.LCARS.ColorLightBlue, false, false, function(ply)
        local hpOk = true
        if StarTrekEntities and StarTrekEntities.Comms and StarTrekEntities.Comms.GetHealthPercent then
            hpOk = (StarTrekEntities.Comms:GetHealthPercent() or 100) < 90
        end
        if not hpOk then
            if Star_Trek and Star_Trek.Logs then
                Star_Trek.Logs:AddEntry(self.Ent, ply, "Repair only available below 90% integrity.", Star_Trek.LCARS.ColorRed)
            end
            if IsValid(self.Ent) then self.Ent:EmitSound("star_trek.lcars_error") end
            return true
        end
        local ok, keypadWin = ensureKeypadWindow()
        if not ok or not keypadWin then
            if Star_Trek and Star_Trek.Logs then
                local err = isstring(keypadWin) and keypadWin or "Unable to initialize calibration keypad."
                Star_Trek.Logs:AddEntry(self.Ent, ply, err, Star_Trek.LCARS.ColorRed)
            end
            if IsValid(self.Ent) then self.Ent:EmitSound("star_trek.lcars_error") end
            return true
        end
        if self._calibrating then return true end
        self._calibrating = true
        local bootMsgs = {
            "Initializing calibration bus...",
            "Syncing modulation lattice...",
            "Verifying quantum isolators...",
            "Loading pattern registry...",
            "Calibration channel ready."
        }
        for i,msg in ipairs(bootMsgs) do
            timer.Simple(0.35 * i, function()
                if Star_Trek and Star_Trek.Logs and IsValid(self.Ent) then
                    Star_Trek.Logs:AddEntry(self.Ent, ply, msg, Star_Trek.LCARS.ColorBlue)
                end
            end)
        end
        timer.Simple(0.35 * (#bootMsgs + 1), function()
            if not IsValid(self.Ent) then return end
            if Star_Trek and Star_Trek.Logs then
                local a=self._repairSequence[self._repairStep];
                Star_Trek.Logs:AddEntry(self.Ent, ply, string.format("Calibration Pattern: %d %d %d %d %d", a[1], a[2], a[3], a[4], a[5]), Star_Trek.LCARS.ColorBlue)
            end
            if IsValid(self.Ent) then self.Ent:EmitSound("star_trek.lcars_alert14") end
            local cycleColors = {Star_Trek.LCARS.ColorBlue, Star_Trek.LCARS.ColorWhite, Star_Trek.LCARS.ColorLightBlue}
            local idx = 1
            local cycleTimer = getCycleTimerId()
            if timer.Exists(cycleTimer) then timer.Remove(cycleTimer) end
            captureMatrixColors()
            local cycleCount = (#cycleColors) * 2
            timer.Create(cycleTimer, 0.5, cycleCount, function()
                if not IsValid(self.Ent) then timer.Remove(cycleTimer) return end
                idx = idx % #cycleColors + 1
                local col = cycleColors[idx]
                for _, b in ipairs(matrixWindow.Buttons or {}) do
                    b.Color = col
                end
                matrixWindow:Update()
            end)
            timer.Simple(0.5 * cycleCount, function()
                if not IsValid(self.Ent) then return end
                if timer.Exists(cycleTimer) then timer.Remove(cycleTimer) end
                restoreMatrixColors()
                keypadWin.WindowAngles = kpAng
                keypadWin.WVis = true
                Star_Trek.LCARS:UpdateWindow(self.Ent, keypadWin.Id, keypadWin)
            end)
        end)
        timer.Simple(0.35 * (#bootMsgs + 2), function()
            if IsValid(self.Ent) then self._calibrating = false end
        end)
        return true
    end)

    local sRow3 = matrixWindow:CreateSecondaryButtonRow(32)
    local powerButton = matrixWindow:AddButtonToRow(sRow3, "System Shutdown", nil, Star_Trek.LCARS.ColorRed, nil, false, false, function(ply, btn)
        if CurTime() < (lastPower + POWER_COOLDOWN) then
            if Star_Trek and Star_Trek.Logs then
                Star_Trek.Logs:AddEntry(self.Ent, ply, "System shutdown on cool down...", Star_Trek.LCARS.ColorBlue)
            end
            return true
        end
        lastPower = CurTime()
        if not (StarTrekEntities and StarTrekEntities.Comms) then return end
        local status = StarTrekEntities.Status and StarTrekEntities.Status.comms or {active = false}
        if status.active then
            if StarTrekEntities.Comms.Shutdown then StarTrekEntities.Comms:Shutdown(self.Ent) end
        else
            if StarTrekEntities.Comms.Enable then StarTrekEntities.Comms:Enable(self.Ent) end
        end

        -- Update Shutdown button color to show if power is on or not power state
        local st = StarTrekEntities.Status and StarTrekEntities.Status.comms or {active = false}
        if st.active then
            btn.Color = Star_Trek.LCARS.ColorLightBlue
        else
            btn.Color = Star_Trek.LCARS.ColorRed
        end
    end)

    -- make the button light blue on start :)
    do
        local st = StarTrekEntities.Status and StarTrekEntities.Status.comms or {active = false}
        if st.active then
            powerButton.Color = Star_Trek.LCARS.ColorLightBlue
        else
            powerButton.Color = Star_Trek.LCARS.ColorRed
        end
    end

    local sRow4 = matrixWindow:CreateSecondaryButtonRow(32)
    matrixWindow:AddButtonToRow(sRow4, "Disable Console", nil, Star_Trek.LCARS.ColorRed, nil, false, false, function(ply)
        if Star_Trek and Star_Trek.Logs then
            Star_Trek.Logs:AddEntry(self.Ent, ply, "Console disabled from communications panel.", Star_Trek.LCARS.ColorRed)
        end
        if Star_Trek and Star_Trek.LCARS and IsValid(self.Ent) then
            Star_Trek.LCARS:CloseInterface(self.Ent)
        end
        return true
    end)

    -- Main log display window on the top panel
    local success2, mainWindow = Star_Trek.LCARS:CreateWindow(
        "log_entry",
        Vector(3, -2, 4),
        Angle(0, 110, 90),
        16,
        730,
        660,
        function(windowData, interfaceData, ply, buttonId)
        end,
        nil
    )

    if not success2 then
        return false, mainWindow
    end

    local windows = {matrixWindow, mainWindow}
    if self._keypadWindow then
        self._keypadWindow = nil
    end

    return true, windows
end
