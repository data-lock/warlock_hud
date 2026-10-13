# Changelog

## v0.40.0-review.5

- Highlight nameplate rows only when group threat confirms engagement or a
  tracked player DoT is safely verified. Dim unrelated and unknown rows while
  retaining their fixed secure click targets.
- Check DoT presence only while aura access is unrestricted. Native aura
  widgets continue rendering effects in combat.

## v0.40.0-review.4

- Resize the Multi-Target window's width and height independently with the
  lower-right grip. Save both dimensions per profile and in share codes.
- Migrate existing scale settings to equivalent initial dimensions.

## v0.40.0-review.3

- Keep the eight token labels visible while their secure target buttons are
  hidden. Show a waiting message when no enemy nameplate tokens are available.
- Place native aura containers beside the secure click targets so a hidden
  target button cannot blank the entire row.
- Use a secure X action to close the protected window during combat. Moving
  and resizing still require leaving combat.

## v0.40.0-review.2

- Drag the Multi-Target window title to move it and its lower-right grip to
  resize it. Both settings save per profile. X closes the window and clears
  its enabled setting; settings can reopen it. Visual changes wait until
  combat ends when protected frames cannot be changed.

## v0.40.0-review.1

- Add an opt-in Multi-Target DoTs review window with eight fixed nameplate
  token rows, secure target actions, native DoT countdowns, target highlighting,
  safe identity clearing on token reuse, and per-profile position.
- Keep group engagement as a confirmed indicator when group-member threat is
  readable. Unknown threat does not remove a visible hostile row.
- Keep the existing Target DoTs HUD unchanged. Combat targeting and native
  nameplate aura behavior require in-game verification before release.

## v0.39.0

- Add opt-in trackers and per-category reminders for Supreme Power flask,
  Arcane Elixirs, Shadow Power, Greater Firepower, Mageblood effects, and
  Wizard Oils. Aura effects keep native countdowns; oils use temporary weapon
  enchant state without a fabricated timer.
- Explain in General settings and installation notes that a combat `/reload`
  delays HUD loading until combat ends.
- Show `/whub debug` diagnostics in the copyable trace window.
- Initialize the saved profile when an early aura or roster event arrives,
  preventing a startup error without blocking HUD loading.
- Retry HUD creation after login if native aura protection deferred the first
  build.
- Pulse all group-buff reminders (Fortitude, Mark/Gift of the Wild,
  Intellect/Brilliance, Spirit, Kings, Salvation, and Thorns) only when a
  present caster's buff is confirmed missing. An unreadable aura state keeps
  the placeholder visible without flashing.

## v0.38.4

- Add selected-section profile sharing with versioned import validation and a confirmation preview, plus a confirmed reset to defaults.
- Add an independent Consumes row and move Well Fed from Buffs, preserving existing profile preferences and native aura countdowns and reminders.
- Show the cast spell image over active Target DoT auras when Forever supplies a question-mark aura image.
- Avoid script handlers on Blizzard's pooled aura buttons, fixing a protected `SetShown` error reported by another player.

## v0.36.2

- Add Conflagrate to the Utility row when learned, with its native spell
  cooldown and per-profile icon ordering and visibility.
- Color and pulse the Conflagrate icon while the existing native Immolate
  tracker shows your Immolate on the current target. It returns to grey when
  that effect expires, is consumed, or the target changes.

## v0.36.0

- Add a red flashing Sense Demons reminder to the Utility row when no living
  demon and no active Demonic Sacrifice are confirmed. The row repacks when the
  reminder appears or clears.
- Track active Demonic Sacrifice effects in the Buff row with native aura
  rendering and countdowns, including when a demon is also present.
- Add a Soul Link reminder for Warlocks who know the spell and have a demon.
  It flashes only when the buff is confirmed missing and uses a native pet aura
  display when active.
- Fix Armor and Well Fed reminder glows so they pulse only when the buffs are
  confirmed missing. Their idle icon colors now follow the active-buff color
  setting.
- Add `/whud petbuffs` for a one-time, out-of-combat pet buff diagnostic.

## v0.35.1

- Keep a group-buff reminder icon visible when combat hides aura status, so a
  dropped buff such as Mark of the Wild cannot leave an empty bordered square.

## v0.35.0

- Add a Control assignment before Soulstone for each Warlock. Choose one raid
  icon for that Warlock's Fear or Banish target, and see it in compact view.
- Include Control in group sync, announcements, and Clear Assignments. The
  assignment does not place a raid marker on an enemy.


## v0.34.3 (review build)

- Center the compact Control heading over its raid marker icon and spell out
  the heading instead of using CC.

## v0.34.2 (review build)

- Simplify Fear/Banish assignments to one shared raid icon choice per Warlock.
  Convert choices from the previous review build to the same icon.

## v0.34.1 (review build)

- Assign each Warlock a Fear or Banish raid icon before the Soulstone target.
  Show the marker in compact view and sync the assignment with the group.

## v0.34.0

- Warn when a direct action-bar spell is lower rank than the highest rank you
  know, and warn after every successful lower-rank cast, including macros and
  spellbook casts.
- Remember each summoned demon's spell ranks per character. At demon trainers,
  grimoire icons are red when known, green when unlearned and available, yellow
  when a higher usable rank is for sale, and grey for an unscanned pet when
  your character meets the item's level requirement. Tooltips explain status.


## v0.33.8 (review build)

- Repeat the lower-rank warning after every successful cast instead of only
  the first cast of each mismatch.

## v0.33.7 (review build)

- Warn after a successful lower-rank cast, including casts from macros or the
  spellbook, once per rank mismatch per session.

## v0.33.6 (review build)

- Mark an unlearned grimoire yellow when the merchant also sells a higher
  usable rank of the same pet spell, and name that rank in its tooltip.

## v0.33.5 (review build)

- Show the grey unscanned grimoire outline only when the character meets the
  item's required level.

## v0.33.4 (review build)

- Replace grimoire merchant row text with colored icon outlines: red for known,
  green for missing and available, grey when the pet has not been scanned.
- Normalize pet spell names that include rank text before comparing grimoires.

## v0.33.3 (review build)

- Raise grimoire status labels to clear the merchant cost text.

## v0.33.2 (review build)

- Move grimoire status labels down and right within merchant rows.
- Refresh labels from each visible merchant item's actual index after changing
  pages, and hide them on the buyback tab.

## v0.33.1 (review build)

- Warn in chat when a direct spell action-bar button uses a lower rank than
  the highest rank in your spellbook. Recheck after spell training and button
  changes; repeat only when the mismatch changes.
- Remember each summoned demon's spell ranks per character and mark grimoires
  already known by that demon in the merchant window and tooltip. Summon each
  demon once to build its initial record.

## v0.33.0

- Add Soulstone targets to group assignments and a Clear Assignments button.
  Solo login starts with assignments unset. Your Soulstone icon pulses red when
  your assigned target is confirmed missing the buff and your stone is ready.
- Add four interior tick markers to the native player castbar for Drain Life,
  Drain Mana, and Drain Soul channels.
- Add a Buffs color option and separate out-of-combat visibility switches for
  Target DoTs, Utility, Buffs, Procs, and Soul Shards.
- Add Shift+Right-click wand attack for a living enemy under the cursor while
  a wand is equipped. Use `/whwand` for binding diagnostics.

## v0.32.32 (review build)

- Activate the wand click binding through a secure state driver only while
  Shift is held over a living enemy. Detect the equipped wand in the ranged
  slot and add `/whwand` binding diagnostics.

## v0.32.31 (review build)

- Bind Shift+Right-click to target the enemy under the cursor and start wand
  Shoot while a wand is equipped. Remove the temporary binding when the wand
  is unequipped or the HUD is disabled.

## v0.32.30 (review build)

- Put native aura buttons in row-specific containers so out-of-combat
  visibility no longer calls SetAlpha on protected Blizzard buttons.

## v0.32.29 (review build)

- Fix the Lua upvalue limit error that prevented the HUD from loading in the
  out-of-combat visibility review build.

## v0.32.28 (review build)

- Add separate out-of-combat visibility switches for Target DoTs, Utility,
  Buffs, Procs, and Soul Shards. Hidden rows remain visible in combat and
  Edit Mode.

## v0.32.27 (review build)

- Remove the right-edge marker from drain channels; keep four interior tick
  markers.

## v0.32.26 (review build)

- Draw channel tick markers above Blizzard castbar effects, and include marker
  position and opacity in channel trace output.

## v0.32.25 (review build)

- Keep drain tick markers above Blizzard's castbar when its drawing level
  changes between casts.

## v0.32.24 (review build)

- Give channel ticks their own trace category and toggle. Record channel start
  and castbar visibility automatically for diagnosis after a cast.

## v0.32.23 (review build)

- Attach channel tick markers to whichever Blizzard player castbar frame is
  present. Use the player channel event when timing data is unavailable.
- Add castbar and channel details to the trace window's Sync State output.

## v0.32.22 (review build)

- Add five tick markers to the native player castbar while channeling Drain
  Life, Drain Mana, or Drain Soul. Markers follow the live channel length and
  clear when the channel stops.

## v0.32.21 (review build)

- Add an independent Buffs color option. By default, active buffs are colored
  and missing buffs are grey; unchecking it reverses those colors.
- Keep missing-buff reminder pulses red in either color mode.

## v0.32.20 (review build)

- Start a solo login with Curse, Bane, and Soulstone assignments unset. Group
  logins still restore the current roster's saved assignments.

## v0.32.19 (review build)

- Treat an uncreated Soulstone as ready when its item cooldown cannot be
  reported. Accept either available aura lookup API for assignment status.
- Include Soulstone aura and cooldown inputs in the trace window's Sync State
  output to diagnose a warning that still does not pulse.

## v0.32.18 (review build)

- Show the missing Soulstone assignment pulse when no Soulstone item has been
  created and its item cooldown is ready. Keep the icon colored while pulsing.

## v0.32.17 (review build)

- Add Soulstone targets to group assignments, including solo self assignment,
  group sync, and a status check for any caster's Soulstone on the recipient.
- Pulse the Soulstone cooldown icon red when your assigned recipient was
  observed without Soulstone and your own Soulstone is ready. Aura checks wait
  until the client permits them; an unknown status does not trigger the pulse.
- Clear Soulstone targets with Clear Assignments.

## v0.32.16 (review build)

- Add Clear Assignments to the full and compact assignment windows. It clears
  current Curse and Bane choices and sends None for each Warlock to the group.

## v0.32.15

- Give the nonsecure Assignments and debug trace windows direct X handlers so
  they can be dismissed during combat without relying on panel close behavior.

## v0.32.14

- Fix an assignment trace error when a sync request runs without a group
  channel, such as just after leaving a group.

## v0.32.13

- Match Forever addon-message sender names when the client uses spaces where
  roster names contain hyphens. This fixes received assignment and snapshot
  messages being rejected as unknown senders.

## v0.32.12 (diagnostic build)

- Add an Assignments recording toggle and Sync State button to the copyable
  `/whud trace` window. They capture sends, receives, roster changes, snapshot
  validation, and revision state to investigate intermittent synchronization.

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
