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
| Buff row | Demon Armor / Demon Skin, Well Fed, Fortitude, Mark or Gift of the Wild, Intellect, Spirit, Kings, Salvation, Thorns, and Unending Breath. Active buffs show grey icons with countdowns. Thorns follows the same Druid-aware missing-buff reminder and active-buff formatting as Mark of the Wild. Unending Breath appears at the right end only while active. Visible buffs pack left to right. |
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

For a packaged download, use the ZIP attached to the latest GitHub Release.
It already contains the `Warlock_Hud` folder. Pushes to `main` also produce a
downloadable ZIP in the repository's Actions artifacts.

## Configure

Open the AddOns settings or type **`/whub`** (also **`/whud`**). Settings include
icon-size sliders with one-pixel step buttons, icon visibility, drag-to-reorder controls, notification choices,
Soul Shard minimum, and profiles. Move each row and the Soul Shards icon in Edit
Mode; they snap to the grid. Profiles save the layout and can switch with your
active talent spec. The Profiles page validates names as you type and confirms
deletion of a profile.

Settings save as soon as they change. Layout changes update the HUD immediately
when the client allows a rebuild; otherwise the HUD updates after combat or can
be retried from the settings footer when safe.
Row and page reset actions restore the current profile's settings while keeping
its Edit Mode positions. Page resets ask for confirmation.

The addon prints its version and the settings command in chat when it loads.
For a one-time diagnostic snapshot, use `/whub debug`. It prints the active
profile, configured rows and tracked spell IDs, target/range status when safe,
and aura-tracker initialization without reading aura data.

## Development

The `.toc` file defines the addon version and Lua load order. Edit the Lua files
directly and use `/reload` in game to test changes. The game stores profiles in
`WarlockHudDB` as a SavedVariable.

See [LICENSE](LICENSE) for the license.
