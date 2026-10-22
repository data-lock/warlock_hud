# Warlock HUD

**Your Warlock. Your HUD. Your raid, organized.**

Warlock HUD is an all-in-one combat HUD and utility toolkit built specifically for **World of Warcraft: Forever**.

From tracking DoTs across multiple enemies to coordinating raid assignments, managing summons, and keeping your buffs and consumables in check, Warlock HUD brings the tools you need into one customizable addon.

**Less time managing your UI. More time playing your Warlock.**

![Warlock HUD in action](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/whud-ui-1-slim.jpg)

## Welcome to 1.0!

After an extensive beta and plenty of feedback from fellow Warlocks, Warlock HUD is ready for its first major release!

Getting started is easier than ever with a new welcome experience:

- **Basic** — A clean, ready-to-play HUD with essential DoTs, buffs, procs, cooldowns, consumables, and Soul Shards.
- **Advanced** — Everything in Basic, plus Multi-Target DoTs, predictive damage, threat awareness, and summon tools.

All features remain available in Settings, and existing profiles are preserved unless you choose to apply a preset.

![Choose your setup](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/whud_options_0_welcome.png)

## Multi-Target DoT Tracking

**Spread the DoTs. Keep track of the chaos.**

Track up to **16 enemies** in a compact, customizable window featuring:

- Blizzard-native DoT icons and countdowns.
- Enemy health, portraits, raid markers, and 20% execute indicators.
- Predicted remaining damage from Corruption, Immolate, Siphon Life, and Bane of Agony.
- A red portrait warning when estimated DoT damage exceeds a mob's remaining health.
- Personal threat awareness: LOW, MED, or HIGH.
- Last-seen enemies that retain estimated DoT information when they leave your view.
- Demonic Brand tracking, including native stacks and countdowns.

![Multi-Target DoTs in action](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/warlock_hud_mtd.gif)

Predicted damage is an estimate, not a guaranteed kill. Forever's protected combat APIs can also limit enemy discovery and available information. The window is view-only; target enemies through normal game controls.

## Your Complete Warlock HUD

Track everything important without cluttering your screen.

**Combat & DoTs**
- Corruption, Immolate, Siphon Life, Banes, Curses, Drains, and Demonic Brand.
- Blizzard-native aura countdowns, including decimal timing where supported.
- Conflagrate, Fear, Healthstone, Soulstone, and racial cooldowns.
- Nightfall, Power Infusion, and other important effects.

**Buffs & Consumables**
- Demon Armor, Soul Link, Demonic Sacrifice, and group buffs.
- Well Fed, Wizard Oils, Firestone, flasks, elixirs, and mana-regeneration effects.
- Optional reminders when important buffs are confirmed missing.

**Warlock Utilities**
- Soul Shard counts, reserve thresholds, and overflow warnings.
- Healthstone distribution and Soulstone recipient tracking.
- Demon status and pet grimoire tracking.
- Outdated spell-rank warnings and Drain channel tick markers.

![Warlock HUD bars](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/whud-ui-2-demo-all.jpg)

## Raid Assignments — PallyPower for Warlocks!

Coordinate your Warlocks without juggling spreadsheets or raid chat.

Assign and synchronize:

- **Curses** — Who casts which Curse.
- **Banes** — Which Bane each Warlock uses.
- **Control** — Fear and Banish assignments using raid markers.
- **Soulstones** — Who is responsible for each recipient.

Assignments synchronize between Warlock HUD users, can be announced to your group, and integrate with your HUD to highlight incorrect Curse or Bane casts.

## Summon Request Queue

**No more hunting through raid chat for "123"!**

Warlock HUD automatically collects summon requests from party, raid, instance chat, and group-member whispers.

Manage requests through a movable queue with waiting timers, summon buttons, pending indicators, and automatic removal when players arrive nearby.

Keywords and request sources are configurable. Summoning still requires your interaction.

![Summon request queue](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/whud_summon_window.png)

## Make It Yours

Your HUD should work the way you play.

- Move, resize, reorder, and customize your HUD rows.
- Choose tracked spells, buffs, consumables, and reminders.
- Customize fonts, icons, visibility, and colors.
- Create profiles for different playstyles and specializations.
- Automatically switch profiles with dual spec.
- Export and import configurations to share with other Warlocks.

Open settings with **`/whud`** or **`/whub`**.

![Warlock HUD settings](https://raw.githubusercontent.com/data-lock/warlock_hud/main/screenshots/whud_options_3_rows_and_layouts.png)

## Built for WoW Forever

Warlock HUD is developed specifically for **World of Warcraft: Forever (1.60.1)**.

It uses Blizzard-native aura rendering wherever supported and respects Forever's combat API restrictions. Some information may be unavailable or estimated rather than directly readable during combat.

## Feedback & Community

Warlock HUD started as a personal project and grew into something much bigger thanks to feedback from fellow Warlocks.

Have an idea, found a bug, or want to help shape what comes next?

**Leave a CurseForge comment or open an issue on [GitHub](https://github.com/data-lock/warlock_hud).**

### Thank You!

A huge thank you to my guildmates in **Tabula Rasa [EU]** for helping test and improve Warlock HUD, especially **Tiny** and **Wheat**.

And thank you to **stevegeoffmcgeofforington**, **GamaKatsu**, **Drugnanov**, and **devast** for their feature suggestions and feedback.

Special acknowledgement to the developer of [DoesItDie](https://www.curseforge.com/wow/addons/does-it-die), whose approach to Forever's protected health values helped inspire Warlock HUD's lethal DoT indicator.

Most of all, thanks to everyone who has downloaded, tested, reported bugs, or suggested improvements throughout the beta.

**See you in Forever! 💜**
