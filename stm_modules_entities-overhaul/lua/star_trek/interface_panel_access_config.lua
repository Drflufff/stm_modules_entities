-- Shared configuration for LCARS panel access control.
-- Edit the codes or per-interface overrides here to change security behaviour.
return {
    -- Panels listed in interfaceLocks use their interface LogType as the key.
    -- Set to false to disable locking for a specific console.
    -- Any console not listed here follows the defaultLocked flag.
    interfaceLocks = {
        ["Medical Status"] = false, -- Crew monitor stays open access.
    },

    -- Set to false to ship with panels unlocked by default.
    defaultLocked = true,

    -- Authorization codes. Each entry requires an uppercase alphanumeric code.
    -- Duplicate or empty codes are ignored at runtime.
    codes = {
        captain = {
            code = "FAFO3053",
            label = "Captain",
        },
        engineering = {
            code = "ENGI1914",
            label = "Chief of Engineering",
        },
        commander = {
            code = "HAMR8416",
            label = "Commander",
        },
    },

    -- Optional limits on code length or keypad capacity; tweak when adding new codes.
    maxCodeLength = 12,
}
