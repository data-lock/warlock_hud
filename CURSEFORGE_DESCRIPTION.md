# Warlock HUD

A lightweight, configurable HUD for Warlocks in **World of Warcraft: Forever beta**. Keep your target effects, buffs, procs, cooldowns, and Soul Shards in view while you play.

![Warlock HUD in play](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/warlock_hud_overview.png)

## What it shows

- **Target effects:** Corruption, Immolate, Siphon Life, Banes, Curses, and Drains. Active effects use the game's native aura countdowns. Choose whether active icons appear colored or grey.
- **Utility:** Healthstone, Soulstone, Fear, and available racial abilities.
- **Buffs and procs:** Armor and group buff reminders, plus Power Infusion and Nightfall while active. Arrange the bars and choose which slots to show.
- **Soul Shards:** A separate count icon with configurable red low-shard and yellow high-shard warnings. The default warnings are 4 or fewer and 18 or more. An optional warning detects shards in regular bags when you have an equipped Soul Bag. Click the icon to destroy one shard from a regular bag, subject to your configured reserve; destruction is unavailable in combat.
- **Nameplates:** An optional 20% health marker on attackable enemies.
- **Stones:** Track a confirmed active Soulstone recipient and record group members who completed a Healthstone trade with you. Optionally place one Healthstone into an empty trade with a current group member. **You must press Accept yourself.** A completed-trade record does not prove that the recipient still carries the stone.

![All HUD bars in demo mode](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/warlock_hud_overview_demo.png)

## Make it yours

Type **`/whub`** or **`/whud`** to open settings. Use **General → Demo all HUD bars** to preview every bar, including normally hidden icons and procs. Move the bars and Soul Shard icon with Edit Mode. Adjust icon sizes and order, choose tracked effects and notifications, and save layouts in profiles. Profiles can switch with your active talent spec.

Warlock HUD is enabled by default for Warlocks. Other classes can enable it manually from General. Settings save immediately; visual changes that require a protected rebuild take effect when the game allows it, such as after combat.

See the [README and settings screenshots](https://github.com/data-lock/warlock_hud#readme) for a full tour. Source code and releases are on [GitHub](https://github.com/data-lock/warlock_hud).
