# Refactor baseline — v0.41.0

This records the behavior to preserve while extracting tracked-effect
definitions. Baseline commit: `d058aa2`. The user has exported their profile;
the share code is held by the user and is not stored in this repository.

## Source contracts

- `Warlock_Hud.toc` loads `Warlock_Hud.lua` before Multi-Target, Sharing, and
  Options. `WarlockHudAPI` supplies their spell, order, profile, and rebuild
  functions. Keep this dependency order explicit when adding a definitions file.
- Main Target DoTs default order is `corruption`, `bane`, `curse`, `drain`,
  `immolate`, `siphonlife`, `demonicbrand`. Existing saved `mainOrder` entries
  must keep their relative order; normalization may append missing keys.
- Keep spell IDs, shared slots for Banes/Curses/Drains, and existing profile
  keys unchanged. Demonic Brand uses aura ID `1293696` and talent ID `1293695`
  in the current source.
- The main HUD and Multi-Target window use native `AuraContainer` slots,
  native duration cooldowns, and native Brand application-count text. No
  Lua-side target countdown or stack calculation is part of this baseline.
- Multi-Target uses the existing 16 nameplate tokens plus target and group
  target tokens. Nameplate add/remove events clear identity and refresh the
  native container. Rebuilds wait until combat and secret-aura guards allow.
- Profile sharing format remains `WHUD1`; default-enabled Multi-Target Brand
  exports explicitly as `true` so importing over `false` restores it.

## Visual references

- `screenshots/warlock_hud_overview.png`: main HUD layout reference.
- `screenshots/whud_multi_target_dots.png`: multi-target row layout reference.
  This image predates the Brand icon; use live v0.41 behavior for Brand layout.
- `screenshots/whud_options_2_tracked_auras.png`: Tracked Auras page reference.
  This image also predates the Brand setting.

## Source check baseline

Run from the addon directory:

```text
uv run --with lupa python tests/compile_lua.py
uv run --with lupa python tests/cast_icon_smoke.py
uv run --with lupa python tests/consumes_migration_smoke.py
uv run --with lupa python tests/sharing_smoke.py
uv run --with lupa python tests/consumables_smoke.py
uv run --with lupa python tests/multitarget_smoke.py
```

All six passed on 2026-10-15. `tests/assignment_smoke.lua` is run by the
GitHub workflow with Lua 5.1; no local Lua executable was available for this
baseline. Source checks do not establish in-game or combat behavior.

## Focused in-game baseline

After `/reload`, confirm the Target DoTs row and Multi-Target window appear
with the saved profile's order and visibility. On a branded target, check the
native countdown and count. With two branded enemies, check that each row has
its own countdown and count. This check should be repeated after the
tracked-effect definition extraction.
