# Changelog

## v0.42.44 (in-game review)

- Shorten and narrow the Multi-Target 20% health marker.

## v0.42.43 (in-game review)

- Abbreviate Multi-Target mob HP and remaining DoT damage. Values of at least
  1,000 use two decimal places, such as `9.00k` and `1.00M`. Protected HP uses
  the client's native abbreviation API during combat.

## v0.42.42 (in-game review)

- Restore current mob HP to the left of health percent and `(DoT X)` on each
  Multi-Target row, with room for the wider label.

## v0.42.41 (in-game review)

- Replace numeric mob HP with health percent and `(DoT X)` on the row's top
  line. Remove the separate damage badge from the health bar and keep enough
  minimum width for the name and new label.

## v0.42.40 (in-game review)

- Align the Multi-Target HP/percent text's right edge with the health bar's
  right edge while keeping the text on the row's top line.

## v0.42.39 (in-game review)

- Show each mob's remaining DoT damage by default in a clearer badge on its
  health bar. The trace-window DoT Ratios button can hide or restore it.

## v0.42.38 (in-game review)

- Show the remaining estimated DoT damage on each Multi-Target mob's health
  bar while DoT Ratios is enabled. Restore the window header's engaged/dotted
  target count.

## v0.42.37 (in-game review)

- Keep a cast DoT estimate through its expected duration even when nearby
  Shadow ticks cannot be matched to a specific spell. Use observed ticks only
  when no description-based estimate was available, avoiding sudden refills.
- Remove a duplicate prefix from the empty DoT snapshot trace.

## v0.42.36 (in-game review)

- Keep Bane of Agony's remaining damage on its spell-description average.
  Late ramped ticks no longer inflate every remaining tick and suddenly refill
  the Multi-Target damage bar.

## v0.42.35 (in-game review)

- Add DoT Ratios and DoT Snapshot buttons to the debug trace window, with the
  toggle button showing its current state.

## v0.42.34 (in-game review)

- Add `/whub dotdebug` to show the selected mob's native HP, max HP,
  percentage, and total remaining DoT estimate in the Multi-Target header.
  `/whub dotsnapshot` writes each spell estimate to the copyable trace at any
  point. The trace includes percent of max HP when the client exposes max HP
  to Lua.

## v0.42.33 (in-game review)

- Draw Multi-Target DoT damage as end-to-end per-spell fills. Casting Immolate
  now adds only its own red segment instead of extending a cumulative fill
  beneath all the existing colors.

## v0.42.32 (in-game review)

- Apply an estimated Curse of the Elements bonus to remaining Multi-Target DoT
  damage as soon as the player's Curse is cast. Use the spell description's
  percentage when available and a conservative 4% fallback otherwise. Avoid
  applying the bonus twice after an observed tick already includes it.

## v0.42.31 (in-game review)

- Increase the Multi-Target portrait warning's red tint and pulse contrast.

## v0.42.30 (in-game review)

- Flash a red-tinted copy of the mob portrait instead of a flat red layer in
  the Multi-Target lethal DoT warning.

## v0.42.29 (in-game review)

- Keep the last Multi-Target DoT icon six pixels inside the scroll viewport
  and extend the HP bar into the space before the icons.

## v0.42.28 (in-game review)

- Move the Multi-Target DoT icon group to the scroll window's right gutter.
  The group remains aligned there as the window width changes.

## v0.42.27 (in-game review)

- Nudge the Multi-Target HP and health-percent label 10 pixels right while
  retaining its wider text field.

## v0.42.26 (in-game review)

- Give the Multi-Target health label more room and show current HP with health
  percent, so the percent does not truncate at the minimum window width.

## v0.42.25 (in-game review)

- Move the Multi-Target health and health-percent text 20 pixels left and
  shorten the adjacent name field by the same amount.

## v0.42.24 (in-game review)

- Pulse the Multi-Target portrait red when the estimated remaining DoT damage
  exceeds current health. A native portrait cover receives protected health
  directly, so Lua does not read or compare that value.

## v0.42.23 (in-game review)

- Add a white current-health edge and a gold estimated-DoT edge to each
  Multi-Target bar. Both follow native status-bar fills, letting players
  compare their positions visually without reading protected geometry.

## v0.42.22

- Release the Multi-Target DoT damage estimate and layout changes from the
  0.42 review builds. See `releases/v0.42.22.md` for details and test status.

## v0.42.21 (in-game review)

- Center the visible proc icons on the saved proc anchor by using native aura
  groups that resize with the active count. Preserve the configured proc order
  and Blizzard-owned aura visibility and cooldowns.

## v0.42.20 (in-game review)

- Remove the unfinished portrait-flash warning and its diagnostic code after
  it failed in-game testing with protected nameplate health. Record it as
  future work in README. Keep the green-to-red health bar gradient.

## v0.42.19 (in-game review)

- Cache readable maximum health as soon as a nameplate is seen, before it
  qualifies for a visible Multi-Target row. Keep the cache tied to the mob's
  GUID for the portrait warning during protected combat.

## v0.42.18 (in-game review)

- Report the portrait-warning path from whichever Multi-Target row owns an
  estimate, including nameplate rows. The earlier diagnostic only watched the
  separate target row and could miss the displayed mob.

## v0.42.17 (in-game review)

- Try a native curve against protected current health when maximum health is
  also unavailable. Its step threshold is the estimated remaining DoT damage.

## v0.42.16 (in-game review)

- Let the portrait warning use a native health-percent curve when current
  health is protected but maximum health was readable. Cache readable maximum
  health for the same row identity so the warning can continue in combat.

## v0.42.15 (in-game review)

- Shade Multi-Target health bars from green at high health through yellow to
  red near death using a native health color curve.
- Flash a red highlight over a mob portrait when readable current health is
  at or below the estimated remaining DoT damage. Suppress that comparison
  while health is protected by the client.

## v0.42.14 (in-game review)

- Move Multi-Target health text into the top right of each row, above the
  health bar. Reserve space beside the mob name at every window width.

## v0.42.13 (in-game review)

- Stop tinting Demonic Brand's native aura textures, which are protected in
  combat. Keep Searing Pain range coloring on the HUD-owned idle icon.

## v0.42.12 (in-game review)

- Use Searing Pain's range for the Demonic Brand target icon. Tint both its
  idle image and active native aura image red when the target is out of range.

## v0.42.11 (in-game review)

- Increase the colored Multi-Target damage line from 2 to 4 pixels high.
  Draw the 20% tick in a higher frame layer and extend it slightly so it
  remains clear where it crosses the thicker line.

## v0.42.10 (in-game review)

- Add Siphon Life and Immolate periodic damage to the Multi-Target estimate.
  They use teal and flame red segments after Corruption's amber and Bane's
  violet. Immolate's direct impact is excluded.
- Use a readable spell description for their cast-time estimate when possible.
  If unavailable, wait for a matching noncritical tick rather than draw a
  misleading rank-one fallback. Reuse a previously observed noncritical tick
  for later casts of the same rank during that session. This behavior needs
  in-game verification.

## v0.42.9 (in-game review)

- Adjust the Multi-Target estimate from observed noncritical Shadow ticks at
  each spell's expected tick time. Corruption uses the observed tick size for
  its remaining ticks; Bane of Agony keeps at least its initial average while
  using larger later ticks as its damage ramps. These observations include
  gear, consumables, and target damage modifiers such as Curse of the Elements
  when they affect the actual hit. Critical ticks do not set the estimate.
- Keep the cast-time rank estimate until a usable tick arrives. Ambiguous
  simultaneous Shadow hits are ignored rather than assigned to a spell.

## v0.42.8 (in-game review)

- Use the player's observed tooltip totals, 223 for Corruption rank 6223 and
  214 for Bane of Agony rank 1014, when descriptions cannot be parsed. This
  review calibration replaces the undersized 40/84 fallbacks for those exact
  spell IDs. Readable tooltip totals still take priority.

## v0.42.7 (in-game review)

- Read cast spell totals from the spell tooltip when the plain description
  does not parse, and cache those totals outside combat. This targets the
  undersized bars caused by the low fallback amounts. The trace now records
  each cast's total and whether it came from the description, tooltip, or
  fallback. Colored bars remain anchored to the full health bar width.

## v0.42.6 (in-game review)

- Parent the colored damage bars to the full Multi-Target row while keeping
  their anchors on the full health bar, so the fill cannot clip them.
- Cache spell description totals outside combat and reuse the cast rank's
  cached total in combat. Trace the selected total for troubleshooting when
  the display is shorter than the spell tooltip implies.

## v0.42.5 (in-game review)

- Restore the estimated damage line to the left edge and scale it against
  maximum health. Use the full described damage of both Corruption and Bane
  of Agony at cast. First ticks confirm the casts but no longer shrink their
  described totals; critical tick amounts therefore cannot inflate them.
- Trace when a spell description cannot be read and the low fallback is used.

## v0.42.4 (in-game review)

- Use the full described Corruption damage as the starting estimate instead
  of 75%. Keep the first observed tick as a downward-only correction.
- Anchor estimated damage to the current health fill and draw it leftward
  from the health edge. Secret current health goes directly to native status
  bars; Lua does not calculate with it. This geometry needs in-game review.

## v0.42.3 (in-game review)

- Color the Multi-Target estimated damage line by spell: amber for Corruption
  and violet for Bane of Agony. When both are present, show their cumulative
  estimate as adjacent colored portions on the same health scale.

## v0.42.2 (in-game review)

- Show the Corruption and Bane damage line as soon as the cast succeeds.
  Start from 75% of Corruption's or 60% of Bane's described total damage;
  use a low rank-one fallback if the description cannot be read. A first
  observed tick may lower the estimate but cannot raise it, avoiding inflated
  estimates from a critical tick. Clear unconfirmed casts after the expected
  first tick window. The estimate still needs in-game verification.

## v0.42.1 (in-game review)

- Include Bane of Agony in the Multi-Target orange damage estimate after its
  first observed tick. Add its estimate to Corruption on the same mob. Agony's
  increasing tick damage makes this initial estimate deliberately conservative.
- The existing tracker can lose a mob when its nameplate leaves range; retain
  this as a future Multi-Target identity issue.

## v0.42 (in-game review)

- Add an original, conservative Corruption damage estimate to Multi-Target
  health bars. An orange line appears only after a matching first damage tick
  and when the mob has a readable GUID. It clears after the expected duration
  or when the row changes identity. This needs in-game verification.

## v0.41.2

- Remove the separate Multi-Target Demonic Brand checkbox. The Target DoTs
  tracking settings now control Brand in both displays.
- Older profiles retain their Target DoTs preference; the retired Multi-Target
  Brand preference is ignored.
- Add a per-profile Tracked Auras toggle for native decimal countdowns on
  Target DoTs and Multi-Target DoTs. The choice is included in profile sharing.
- Save the choice immediately and rebuild native timers when combat and aura
  protection allow it.

## v0.41.0

- Add Demonic Brand as a tracked target effect when the talent is learned.
  The Target DoTs row and Multi-Target tracker use Blizzard-native aura
  countdowns and application-count text; the count was observed in game.
- Add independent visibility choices for the main row and Multi-Target
  tracker. Profile sharing preserves the Multi-Target choice, including its
  enabled default.
- Keep each tracked enemy's Brand count and countdown separate. This was
  checked with two enemies in game.
- Refresh the Multi-Target native slots after a safe talent, spellbook, spec,
  or setting change. The setting toggle was checked in game; respec remains
  untested.
- Brand's debuff ID comes from beta client data and still needs confirmation
  against the running client's aura ID. Same-target two-Warlock filtering and
  reused-nameplate combat behavior remain untested in game.
- Thanks to **stevegeoffmcgeofforington** for recommending Demonic Brand tracking.

## v0.40.0

- Add the opt-in Multi-Target DoT tracker with up to 16 view-only enemy rows,
  Blizzard-native DoT countdowns, health bars, portraits, raid markers, and a
  20% health indicator. Include enemies exposed through nameplates and player,
  party, or raid target tokens when combat or player-DoT evidence is available.
- Keep the tracker off by default. Open it with `/whud mtd` outside combat;
  configure its size, position, transparency, and optional combat-only display
  in settings. Short windows scroll. Toggling and adjustments require leaving
  combat; target enemies through the game world or Tab.

## v0.40.0-review.41

- Keep the Multi-Target window disabled for new profiles and explain that
  `/whud mtd` opens it outside combat. Limit command and X toggling to outside
  combat, alongside window movement and resizing.

## v0.40.0-review.40

- Extend the Multi-Target row viewport to within seven pixels of the window
  bottom, removing the unused black strip below the list.

## v0.40.0-review.39

- Reduce the Multi-Target window's minimum height to 150 pixels, enough for
  two target rows; additional targets remain accessible through scrolling.

## v0.40.0-review.38

- Confirm from the in-game trace that the Multi-Target window is protected in
  combat. Keep moving and resizing outside combat, and remove the ineffective
  combat drag paths. The shorter window and scroll bar remain available.

## v0.40.0-review.37

- Let the Multi-Target title drag move the window during combat when its
  frame permits repositioning, saving the new position immediately.
- Keep vertical resizing available even when a protected DoT row prevents
  width changes. Report the blocked frame in the copyable trace.

## v0.40.0-review.36

- Move the hide-outside-combat state driver from the resizable window to a
  separate secure controller, so the driver does not protect window geometry.
- Identify the blocking frame in the copyable trace if combat resizing is
  still rejected by the client.

## v0.40.0-review.35

- Let the Multi-Target window shrink vertically while rows keep their fixed
  spacing. Show a scroll bar only when the visible mobs exceed the window.
- Use a visibility state driver for the hide-outside-combat option so the
  window appears when combat starts without an insecure show call.

## v0.40.0-review.34

- Prebuild 16 nameplate rows and allow up to 16 distinct visible mobs, while
  retaining group-target sources and the existing DoT filters.
- Anchor the Multi-Target window at its top-left corner and allow resizing
  during combat when the client permits changes to the prebuilt frames.
- Add `/whud mtd`, a hide-outside-combat setting, and a transparency slider.

## v0.40.0-review.33

- Widen the selected-target accent and move portraits right for clearer
  spacing. Keep name, health bar, and 20% marker aligned with the portrait.

## v0.40.0-review.32

- Add the nameplate-style 20% copper tick to Multi-Target health bars. It
  follows the existing execute-marker setting and stays aligned when resized.

## v0.40.0-review.31

- Give Multi-Target rows a dark surface, a slim gold selected-target accent,
  and separate white name and health labels above a dark-backed health bar.
- Dim inactive DoT icons and improve native countdown contrast and spacing.
  Keep the existing target detection, native aura slots, and view-only controls.

## v0.40.0-review.30

- Prebuild native aura rows for the player's target, `party1target` through
  `party4target`, and `raid1target` through `raid40target`. Group-targeted mobs
  can now appear without a nameplate. Deduplicate matching units by GUID or
  `UnitIsUnit` and keep the visible window capped at eight rows. Refresh native
  auras when a target token changes occupants.

## v0.40.0-review.29

- Add threat, mob-target, group-target, combat, and row-visibility signals to
  nameplate entries in the copyable Unit Probe trace.

## v0.40.0-review.28

- Include a visible mob when a party or raid member (or the player's pet)
  targets it. Refresh all rows when a group member's `UNIT_TARGET` changes.

## v0.40.0-review.27

- Pass a restricted raid-marker index directly to Blizzard's native
  `SetRaidTargetIconTexture` renderer when Lua cannot read the index. Keep
  arithmetic and comparisons away from the restricted value, and report the
  render path in `/whud targets`.

## v0.40.0-review.26

- Include the current target's GUID and marker result, plus each displayed
  row's GUID and direct marker result, in `/whud targets` trace output.

## v0.40.0-review.25

- Try a mob's readable GUID for its raid marker when unit-token lookups do
  not yield an index. Report the GUID source in `/whud targets` trace output.

## v0.40.0-review.24

- Include a visible mob when its unit target is the player, pet, or a group
  member. Refresh on `UNIT_TARGET` so adds can appear before threat or a DoT
  becomes readable.

## v0.40.0-review.23

- Resolve Multi-Target raid markers through a matching target, focus, pet
  target, or group target when the nameplate token does not yield the marker.
  Include the marker source in `/whud targets` trace output.

## v0.40.0-review.22

- Move the Unit Probe toggle from the Multi-Target window into the copyable
  debug trace window. Keep its label in sync with `/whud unitprobe`.

## v0.40.0-review.21

- Add a Probe on/off button to the Multi-Target window. It opens the copyable
  trace window and controls the same unit probe as `/whud unitprobe`.

## v0.40.0-review.20

- Add `/whud unitprobe` to log hostile target, focus, pet/group target,
  boss, and nameplate token changes to the copyable trace window during a pull.
  Use `/whud unitprobe off` to stop sampling.

## v0.40.0-review.19

- Send `/whud targets` output to the copyable trace window and open it
  automatically. Keep multi-target debug output in that window.

## v0.40.0-review.18

- Add `/whud targets` to print each visible multi-target row's nameplate token
  and readable mob name in chat. Include the same mapping in `/whud debug`.

## v0.40.0-review.17

- Compact surviving Multi-Target rows when a mob dies or its nameplate is
  removed, including during combat when the existing display parent can be
  moved safely. Defer geometry if the client marks a row protected.

## v0.40.0-review.16

- Keep each mob portrait in place across routine health, target, threat, and
  marker updates so it does not flash. Reanchor rows only when their compact
  position changes, including after a confirmed death.
- Retain previously confirmed DoT rows during restricted combat reads, then
  recheck them when combat ends.
- Refresh an existing portrait when the client reports new portrait imagery.

## v0.40.0-review.15

- Add each shown mob's 2D target portrait beside its health bar and place its
  raid marker over the portrait. Clear both when a nameplate token is reused.

## v0.40.0-review.14

- Show Multi-Target rows only when group threat confirms engagement or a
  tracked player DoT is safely readable. Hide unrelated and unknown rows and
  recheck them when combat ends.

## v0.40.0-review.9

- Add a health bar to each live Multi-Target row and show
  `Target Name (current/max) percent%` in its label.
- Pass potentially protected health values directly to native status bar and
  font string APIs. Expand older narrow window layouts once to fit the text.

## v0.40.0-review.8

- Remove the nonworking secure nameplate target buttons and hover cue after
  in-game testing confirmed that clicking does not select their units.
- Mark the Multi-Target DoTs window as view-only. Target enemies through the
  native world nameplates or Tab; the native aura display remains available.

## v0.40.0-review.7

- Make each fixed nameplate row's name area an explicit left-click secure
  target button, independent of the click-on-key-down setting.
- Show a hover highlight when the secure button is active. `/whud debug`
  reports each live row's secure click visibility in the trace window.

## v0.40.0-review.6

- Clear a fixed row's name, marker, and highlight when its nameplate token is
  absent or the unit is confirmed dead. Update on health and flag changes.
- Remove the "nameplateN (waiting)" labels from empty slots.

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
