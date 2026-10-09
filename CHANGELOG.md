# Changelog

## v0.32.11

- Replace the small inner glow square with purple glow strips around the Curse
  and Bane icon borders.

## v0.32.10

- Make the purple wrong-assignment fill the full HUD icon again.
- Open Assignments in compact mode when the player has an active Curse or Bane
  assignment, including after restoring it on reload.

## v0.32.9

- Place the Compact button in the full window footer and give Expand its own
  row below the compact title, clear of the title and column headers.

## v0.32.8

- Save Curse and Bane assignments for the current character and restore them
  after reload. Group assignments still clear when the group disbands.

## v0.32.7

- Inset the persistent purple assignment highlight so its fill follows the
  visible spell artwork more closely.

## v0.32.6

- Move the Compact/Expand button into the Assignments title bar so it does not
  cover the Curse and Bane column headers.

## v0.32.5

- Keep separate purple highlights on wrong Curse and Bane slots until each
  assigned spell is cast, the target changes, or assignments change.

## v0.32.4

- Let the full Assignments window resize by dragging its lower-right corner.
- Add a Compact toggle with one name, Curse icon, and Bane icon per Warlock.
  The compact window follows the roster size; expanding restores the full
  window's saved dimensions.

## v0.32.3

- Label the assignment announcement button with its party, raid, or instance
  destination and add `/whud announceassignments` for the same explicit action.

## v0.32.2

- Remove the Assignments scrollbar and size the window for its Warlock rows.
- Show full assigned-by names beneath each row and use a space between player
  and realm in display text.
- Keep a wrong-cast slot red until a correct cast, target change, or assignment
  change clears it.

## v0.32.1

- Let any group member using Warlock HUD edit Curse and Bane assignments.
- Allow solo Warlocks to assign themselves without requiring a party or raid.
- Clear group assignments on disband while preserving later solo choices until
  reload.

## v0.32.0

- Add a movable group Curse and Bane assignment window with separate choices for
  every Warlock, including group members without the addon.
- Synchronize temporary assignments and editing policy through validated addon
  messages. Request a snapshot after reload; disband clears assignments.
- Use the local assignment for the HUD's idle icon and range spell. A different
  successful Curse or Bane cast gives a brief local warning.
- Add an opt-in `/whud assignprobe` command for Forever API checks. Group behavior
  and cast events still need in-game verification.

## v0.31.1

- Choose the idle image for the shared Bane, Curse, and Drain slots on Tracked
  Auras. Choices are saved per profile; Automatic keeps the previous behavior.
- Check range using the spell chosen for each shared slot. For example, a Drain
  Life image uses Drain Life range rather than Drain Soul range.
- Keep active aura icons and countdowns on Blizzard's native aura display.
- Allow a comma-separated list of exact summon request words. The defaults are
  `123`, `sum`, and `summ`; existing custom words are preserved.
- Add a 15-request summon window preview with varied wait times and Pending
  labels. Demo buttons do not cast or announce.
- Keep the queue's X buttons aligned with the scrollbar when it first opens.

## v0.31.0

- Add a movable summon request queue for grouped players who send the configured
  keyword (default `123`) in party, raid, instance chat, or whisper.
- Add secure Summon buttons, wait timers, manual removal, nearby removal, and a
  pending summon label when Forever reports an incoming summon.
- Add an Announce button and include the current Soul Shard count in summon
  announcements when the count is available.
- Add Summons settings for the keyword, accepted channels, and nearby removal.
- Keep HUD borders, glows, and native buff icons at the player frame's layer so
  a map opened over the HUD covers them correctly.

## v0.30.0

- Add per-profile Soul Shard warnings: red at 4 or fewer shards and yellow at
  18 or more by default. A shard in a regular bag alongside an equipped Soul
  Bag can also trigger yellow. Warning and deletion thresholds are separate.
- Use sliders for the shard reserve and warning thresholds, and fix the shard
  visibility checkbox.
- Add an on-screen demo of every HUD icon slot and label each bar. The demo
  includes disabled slots and inactive buffs and procs.
- Add Siphon Life as a native Target DoT slot and remove the passive Soul
  Siphon icon from Utility.
- Keep the Buffs row fixed at its left edge as icons appear or disappear.
- Move the Profiles summary clear of its dropdown.

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
