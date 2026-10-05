# Stones tracking handoff (unfinished review build v0.29.0)

The Soulstone and Healthstone work remains on `feature/stones-tracking`.
The branch includes the v0.28.0 changes from `main`; its current review
version is v0.29.0. The Stones work has not been released.

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
  observed in a group trade at both-sided acceptance and the client reports
  `UI_INFO_MESSAGE` trade completion. The record means a completed trade was
  observed, not that the recipient still has the item.
- `/whub trace` opens one copyable trace window with Trade and Soulstone
  recording switches. `/whub stones` prints the distribution list.
- The guarded, passive observer for
  `C_DeathInfo.UseSelfResurrectOption` to distinguish confirmed Soulstone use
  from an aura lost on death. It does not invoke the protected action.

## Confirmed in game by the user

- The Druid default-off path and General switch worked after v0.27.31.
- Forever emitted `UI_INFO_MESSAGE id=251 message=Trade complete.` followed
  by `TRADE_CLOSED` in a completed trade.
- A Soulstone self-cast fired `UNIT_SPELLCAST_SENT` and
  `UNIT_SPELLCAST_SUCCEEDED` for spell 20707. The recipient matched `player`,
  and the aura was found with `source=player`.
- The active-only Soulstone label became visible and was centered at the
  user's request. No READY/UNKNOWN text is shown on the HUD.
- On a death test, the Soulstone aura disappeared at `PLAYER_DEAD` and
  `PLAYER_ALIVE` occurred seven seconds later. No post-death player cast was
  recorded. That sequence alone does not prove Soulstone use.

## Still needs in-game verification

1. v0.27.43 self-resurrection observer: determine whether Forever exposes
   `C_DeathInfo.GetSelfResurrectOptions` and calls
   `C_DeathInfo.UseSelfResurrectOption` for Soulstone. Confirm that `USED` is
   recorded only after the Soulstone choice and a return to life. If those
   APIs are unavailable, retain `LOST / UNKNOWN`.
2. Complete and cancel a Healthstone group trade; verify `/whub stones` adds
   only the completed trade. The completion event itself was observed, but the
   distribution state has not been confirmed in game.
3. Enable auto-placement and test one empty group trade, an outsider, an
   occupied trade, stacked/multiple ranks, and manual Accept. Auto-placement
   is off by default. The placement API path has not been confirmed in game.
4. Check Soulstone expiry and loss outside combat, reload recovery, and the
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
