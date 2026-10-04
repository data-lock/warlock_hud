# Warlock HUD agent notes

## Project

Warlock HUD is a World of Warcraft: Forever beta addon. The `.toc` file defines the interface version, addon version, saved variable, and Lua load order. There is no build step. Use `/reload` in game to test edits.

## Preserve the working HUD

- Keep the secure/native aura mechanism for target DoTs and player buffs.
- Do not scan target auras in Lua during combat, read restricted aura values, or calculate countdowns from protected aura data.
- Keep Blizzard-native cooldown rendering and the guarded rebuild path. Do not rebuild protected UI in combat or while the client reports secret auras.
- Do not replace Edit Mode, add external dependencies, or add Ace3.
- Avoid changing internal profile keys or saved-variable shape for user-facing label changes.

## Settings UX work

- Work through settings improvements one reviewable item at a time. After each item, state what changed and give the user a focused in-game check before starting the next item.
- Save settings immediately as the current implementation does. A visual rebuild may wait until it is safe. Keep that distinction clear in the UI.
- Keep destructive Soul Shard behavior clearly explained. Do not alter deletion logic as part of copy or layout work.
- Notification descriptions must match `Warlock_Hud_Notifications.lua`. The revised Soulstone announcement still needs in-game verification.
- Update the `.toc` version for an in-game review build so the user can identify which files loaded.

## Local plan and verification

- `SETTINGS_UX_PLAN.md` is a local working checklist. It is ignored by Git and must not be committed.
- Inspect `git status` before committing. Never force-add the local plan.
- Verify source changes where possible, then ask for `/reload` and an in-game check of the affected page. Do not claim in-game verification from a source check.
