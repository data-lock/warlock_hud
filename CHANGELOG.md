# Changelog

## v0.29.2 (in-game review build)

- Removed the unverified Soulstone self-resurrection observer and `USED` claim.
  A Soulstone lost around self-death is reported as `LOST / UNKNOWN`.

## v0.29.1 (in-game review build)

- Confirm Healthstone distribution and its notification after Forever reports
  trade completion, including when trade slots clear before `TRADE_CLOSED`.
- Add trace reasons for skipped automatic placement and select an unlocked
  Healthstone without requiring it to be consumable at the player's health.

## v0.29.0 (in-game review build)

- Added Soulstone recipient tracking with an active-only HUD label and a
  guarded self-resurrection observer. Unconfirmed outcomes remain unknown.
- Added a Stones page, completed Healthstone trade records, and optional
  group-only Healthstone placement. Trade acceptance remains manual.
- Added a copyable trace window with Trade and Soulstone recording controls.
- Added per-character enable defaults: on for Warlocks, off for other classes.

Stones behavior still needs in-game verification on Forever.

## v0.28.0

- Added a Target DoT color toggle under Tracked Auras. Active effects are
  colored and missing effects are grey by default; the previous appearance
  remains available by turning the toggle off.
- Kept the color choice scoped to the Target DoTs row and the active profile.

Thanks to Tiny for the suggestion.

## v0.27.27

- Reorganized settings pages and grouped tracked auras by icon slot.
- Added bounded icon-size sliders, scoped resets, clearer save status, and safer profile controls.
- Added Thorns and active-only Unending Breath tracking to the Buffs row.
- Improved tooltips, notification descriptions, Soul Shard safety text, and the About page.
- Fixed the Curses settings icon and added one-time `/whub debug` diagnostics.

The revised Soulstone group announcement still needs a live cast check.
