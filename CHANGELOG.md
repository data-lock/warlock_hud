# Changelog

## v0.27.43 (in-game review build)

- Added guarded self-resurrection option diagnostics and a confirmed-use path.
- A self-applied Soulstone lost at death stays pending until resurrection resolves.

## v0.27.42 (in-game review build)

- Added death, return, nearby player cast, and deferred aura events to Soulstone trace.

## v0.27.41 (in-game review build)

- Centered the active Soulstone recipient label beneath the Utility row.

## v0.27.40 (in-game review build)

- Show the Soulstone recipient below its icon only while its aura is confirmed active.

## v0.27.39 (in-game review build)

- Added Trade and Soulstone recording buttons to the shared trace window.
- Added `/whub trace` to open the window without changing recording settings.

## v0.27.38 (in-game review build)

- Added opt-in Soulstone cast and safe aura diagnostics to the copyable debug window.

## v0.27.37 (in-game review build)

- Show Soulstone status on the Stones page only after its aura is confirmed active.

## v0.27.36 (in-game review build)

- Improved self-target Soulstone matching and retried safe aura observation after application.

## v0.27.35 (in-game review build)

- Removed Soulstone status text from the HUD; the Stones page retains the status.

## v0.27.34 (in-game review build)

- Anchored the Soulstone status below its icon and labeled it explicitly.

## v0.27.33 (in-game review build)

- Moved the opt-in trade trace into a separate window with Select All and Clear.

## v0.27.32 (in-game review build)

- Added per-character enable defaults: on for Warlocks, off for other classes.
- Added a Stones page, compact Soulstone status, completed-trade distribution
  records, reset control, and optional group-only Healthstone auto-placement.
- Kept trade acceptance manual and labeled uncertain Soulstone outcomes.
- Added `/whub stones` and opt-in `/whub tradedebug` diagnostics.

Stones behavior still needs in-game verification on Forever.

## v0.27.27

- Reorganized settings pages and grouped tracked auras by icon slot.
- Added bounded icon-size sliders, scoped resets, clearer save status, and safer profile controls.
- Added Thorns and active-only Unending Breath tracking to the Buffs row.
- Improved tooltips, notification descriptions, Soul Shard safety text, and the About page.
- Fixed the Curses settings icon and added one-time `/whub debug` diagnostics.

The revised Soulstone group announcement still needs a live cast check.
