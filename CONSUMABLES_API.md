# Consumes tracking in Forever beta

The Consumes row tracks active effects. New categories are disabled by default;
Well Fed keeps its existing setting and reminder default. Missing reminders for
new categories are off until selected. Absence is never inferred from an
unreadable or secret aura result.

The aura slots use Blizzard's `CustomAuraContainerTemplate`, with known Forever
**effect** IDs in `candidateFilters.includeSpellIDs`. Out of combat, the addon
can learn Greater Mageblood's active effect ID by name and retain it for later native
rendering. New categories do not read aura durations or scan auras in combat;
their reminder state becomes unknown while combat prevents a safe read.

| Category | Forever effect IDs | Effect names |
| --- | --- | --- |
| Well Fed | 19705 plus learned variants | Well Fed |
| Flask | 17628 | Supreme Power |
| Spell Damage Elixir | 1250971, 439959, 11390, 16889 | Lesser, regular, and Greater Arcane Elixir |
| Shadow Damage Elixir | 11474 | Shadow Power |
| Fire Damage Elixir | 7844, 26276 | Fire Power, Greater Firepower |
| Mana Regeneration | 1250942, 1250944, 24363 plus learned variants | Minor/Lesser Mageblood Elixir, Mana Regeneration, Greater Mageblood Elixir |

Forever effect data: [Supreme Power](https://www.wowhead.com/forever/spell=17628),
[Greater Arcane Elixir](https://www.wowhead.com/forever/spell=16889),
[Lesser Arcane Elixir](https://www.wowhead.com/forever/spell=1250971),
[Shadow Power](https://www.wowhead.com/forever/spell=11474),
[Fire Power](https://www.wowhead.com/forever/spell=7844),
[Greater Firepower](https://www.wowhead.com/forever/spell=26276),
[Mana Regeneration](https://www.wowhead.com/forever/spell=24363), and
[Lesser Mageblood Elixir](https://www.wowhead.com/forever/spell=1250944).
The Greater Mageblood effect ID has not been verified, so its native button
appears after the addon observes that effect out of combat.

Wizard Oils are temporary weapon enchants, not ordinary player auras. The addon
uses Forever's `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)` (slot 0)
outside combat. It matches enchant IDs 2623, 2626, 2627, and 2628 for Minor,
Lesser, regular, and Brilliant Wizard Oil. The API can report an unknown state
or secret fields; these never trigger a missing reminder. The row shows no oil
countdown because a supported native duration display for this custom slot has
not been verified. The addon does not calculate or estimate protected weapon
enchant time.

API and effect references: [Forever weapon enchant API](https://warcraft.wiki.gg/wiki/API:C_Item.GetWeaponEnchantInfo),
[Minor Wizard Oil](https://www.wowhead.com/forever/spell=25117),
[Lesser Wizard Oil](https://www.wowhead.com/forever/spell=25119),
[Wizard Oil](https://www.wowhead.com/forever/spell=25121), and
[Brilliant Wizard Oil](https://www.wowhead.com/forever/spell=25122).

Inventory consumables such as potions, runes, and bandages remain outside this
active-effect row. The consumable trackers were checked in game for this
release. Flask and elixir stacking rules are determined by Forever; this addon
does not infer them.
