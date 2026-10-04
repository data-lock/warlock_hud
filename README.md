# Warlock HUD

A configurable World of Warcraft: Forever beta addon for Warlock auras, buffs,
cooldowns, procs, Soul Shards, and a 20% nameplate marker.

The addon loads from `Interface/AddOns/Warlock_Hud` in the `_classic_beta_`
game folder. Open its settings with `/whub` or `/whud`, or through the game's
AddOns settings. Move the HUD rows in Edit Mode. Settings and profiles are saved
in `WarlockHudDB` by the game.

The `.toc` file holds the addon version and load order. No build step is needed;
after editing the Lua files, use `/reload` in game to load the changes.

The GitHub repository is `git@github.com:arosychuk/warlock_hud.git`. After
connecting the local `origin` remote, use `git push` to publish commits.
