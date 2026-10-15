-- Shared target-effect catalog. Slot numbers and profile keys are persistent;
-- keep them stable when changing labels or adding new effects.
WarlockHudEffects = {
    Spells = {
        { name = "Corruption", slot = 1, ids = { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
        { name = "Immolate", slot = 5, ids = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
        { name = "Bane of Agony", slot = 2, ids = { 980, 1014, 6217, 11711, 11712, 11713 } },
        { name = "Bane of Doom", slot = 2, ids = { 603 } },
        { name = "Bane of Havoc", slot = 2, ids = { 1225228, 1243339 } },
        { name = "Curse of the Elements", slot = 3, ids = { 440892, 440982, 1311676, 1311677, 1311680, 1490, 11721, 11722 } },
        { name = "Curse of Weakness", slot = 3, ids = { 702, 1108, 6205, 7646, 11707, 11708 } },
        { name = "Curse of Recklessness", slot = 3, ids = { 704, 7658, 7659, 11717 } },
        { name = "Curse of Tongues", slot = 3, ids = { 1714, 11719 } },
        { name = "Curse of Exhaustion", slot = 3, ids = { 18223 } },
        { name = "Drain Soul", slot = 4, ids = { 1120, 8288, 8289, 11675 } },
        { name = "Drain Life", slot = 4, ids = { 689, 699, 709, 7651, 11699, 11700 } },
        { name = "Drain Mana", slot = 4, ids = { 5138, 6226, 11703, 11704 } },
        { name = "Siphon Life", slot = 6, ids = { 18265, 18879, 18880, 18881 } },
        -- Brand is a target effect, not periodic damage. The aura ID differs
        -- from the talent spell and the pet's consumption effect.
        { name = "Demonic Brand", slot = 7, ids = { 1293696 }, talentEffect = true },
        { name = "Fear", group = 2, slot = 3, ids = { 5782, 6213, 6215 } },
    },
    MainKeys = { "corruption", "bane", "curse", "drain", "immolate", "siphonlife", "demonicbrand" },
    DefaultSlots = { bane = 2, curse = 3, drain = 4 },
    PreviewSpellIDs = {
        corruption = 6222, bane = 1014, drain = 1120, immolate = 348,
        siphonlife = 18265, demonicbrand = 1293696,
    },
}
