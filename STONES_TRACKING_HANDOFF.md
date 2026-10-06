# Stones tracking handoff (unfinished review build v0.29.2)

The Soulstone and Healthstone work remains on `feature/stones-tracking`.
The branch includes the v0.28.0 changes from `main`; its current review
version is v0.29.2. The Stones work has not been released.

## Implemented

- Per-character addon enable setting: on by default for Warlocks, off by
  default for other classes, with a manual switch on General.
- Stones settings page with Soulstone options, Healthstone distribution list,
  reset control, and optional group-only automatic Healthstone placement.
- Soulstone cast/recipient tracking and safe out-of-combat aura observation.
  The recipient label is centered below the Utility row only while the aura
  has been confirmed active. The existing Soulstone icon continues to show
  item readiness and its native cooldown.
- Healthstone distribution records are committed only after a Healthstone was
  observed in a group trade when the player accepted and the client reports
  `UI_INFO_MESSAGE` trade completion. The record means a completed trade was
  observed, not that the recipient still has the item.
- `/whub trace` opens one copyable trace window with Trade and Soulstone
  recording switches. `/whub stones` prints the distribution list.
- Soulstone use is not claimed without a reliable Forever signal. The
  unverified self-resurrection observer was removed in v0.29.2; aura loss
  around self-death becomes `LOST / UNKNOWN`.

## Confirmed in game by the user

- The Druid default-off path and General switch worked after v0.27.31.
- Forever emitted `TRADE_CLOSED` before `UI_INFO_MESSAGE id=251 message=Trade
  complete.` in a completed trade.
- A Soulstone self-cast fired `UNIT_SPELLCAST_SENT` and
  `UNIT_SPELLCAST_SUCCEEDED` for spell 20707. The recipient matched `player`,
  and the aura was found with `source=player`.
- The active-only Soulstone label became visible and was centered at the
  user's request. No READY/UNKNOWN text is shown on the HUD.
- A new self-applied Soulstone was tracked and its HUD label cleared on death.
  This confirms the active-only display behavior, not whether the stone was used.
- On a death test, the Soulstone aura disappeared at `PLAYER_DEAD` and
  `PLAYER_ALIVE` occurred seven seconds later. No post-death player cast was
  recorded. That sequence alone does not prove Soulstone use.
- A manual Healthstone trade showed item 5512, player acceptance `1/0`, then
  `TRADE_CLOSED`, and `UI_INFO_MESSAGE id=251`. v0.29.1 announced success and
  logged `DISTRIBUTION recorded Rigged-Elections`. A separate cancelled trade
  emitted `TRADE_REQUEST_CANCEL` and `UI_INFO_MESSAGE id=250`; it did not
  announce or record a distribution.
- With automatic placement enabled, the user reported success in an empty
  group trade. The detailed placement trace was not supplied.

## Still needs in-game verification

1. Verify `/whub stones` lists only the completed trade after the confirmed
   success and cancellation sequence.
2. Test auto-placement safety with an outsider, an occupied trade, and
   stacked/multiple Healthstone ranks. Confirm one item is placed and Accept
   remains manual. Auto-placement is off by default.
3. Check Soulstone expiry and loss outside combat, reload recovery, and the
   Stones page options. The Soulstone group announcement also still needs a
   live cast check.

## Constraints

Keep the existing native aura and cooldown rendering, guarded protected UI
rebuilds, and no in-combat aura scans. Do not infer a Soulstone use merely
from death, aura disappearance, or `PLAYER_ALIVE`. Do not auto-accept trades.
Settings save immediately; protected visual rebuilds can wait. Bump the TOC
version for each in-game review build.

Source changes passed `git diff --check`. There is no build step and no Lua
compiler was available in the workspace. Use `/reload` for client testing.
