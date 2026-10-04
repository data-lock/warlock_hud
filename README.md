# Warlock HUD

A configurable HUD for Warlocks in **World of Warcraft: Forever beta**. It keeps
target effects, cooldowns, buffs, procs, and Soul Shards visible without opening
other panels.

![Warlock HUD in game](screenshots/warlock_hud_overview.png)

## Features

| Display | What it tracks |
| --- | --- |
| Main row | Corruption, Immolate, Banes, Curses, and Drain spells. Spells of the same type share an icon slot. Active target effects show a countdown, including milliseconds. |
| Cooldown row | Healthstone, Soulstone, Fear, available racial abilities, and Soul Siphon when the talent is known. |
| Buff row | Demon Armor / Demon Skin, Well Fed, Fortitude, Mark or Gift of the Wild, Intellect, Spirit, Kings, and Salvation. Active buffs show grey icons with countdowns. Missing group buffs appear when someone in your group can provide them; visible buffs pack left to right. |
| Proc row | Power Infusion and Nightfall appear only while active, with a pulsing glow and countdown. |
| Soul Shards | A separate icon near the Player Frame shows your shard count. Each click destroys one shard from a regular bag, stopping when those bags are clear or your configured minimum remains. The default minimum is 8. Shards cannot be destroyed in combat. |
| Nameplates | A copper tick marks 20% health on attackable enemies' health bars. |

Main row icons fade when there is no attackable target and turn red when the target
is out of range. Demon Armor / Demon Skin and Well Fed have missing-buff reminders.
The HUD checks known spells and talents when deciding which icons to show.

The addon can announce Ritual of Summoning, a Soulstone cast, and an accepted
Healthstone trade. Soulstone announcements go to party, raid, or instance chat
when grouped. Summon and trade notices can be sent to group chat or shown only
in your own chat window.

## Install

Place the files in this folder, keeping the folder name **`Warlock_Hud`** so it
matches `Warlock_Hud.toc`:

```text
World of Warcraft/_classic_beta_/Interface/AddOns/Warlock_Hud/
```

Enable **Warlock HUD** in the game's AddOns list, then enter the game or use
`/reload` after updating the files. There is no build step.

## Configure

Open the AddOns settings or type **`/whub`** (also **`/whud`**). Settings include
icon sizes, icon visibility, drag-to-reorder controls, notification choices,
Soul Shard minimum, and profiles. Move each row and the Soul Shards icon in Edit
Mode; they snap to the grid. Profiles save the layout and can switch with your
active talent spec.

The addon prints its version and the settings command in chat when it loads.

## Development

The `.toc` file defines the addon version and Lua load order. Edit the Lua files
directly and use `/reload` in game to test changes. The game stores profiles in
`WarlockHudDB` as a SavedVariable.

See [LICENSE](LICENSE) for the license.
