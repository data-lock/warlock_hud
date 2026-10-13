# Multi-target DoT window: secure targeting feasibility

Research status: 13 October 2026. The fixed-token display architecture is
implemented as an opt-in 0.40.0 review build. Combat targeting was tested in
game and did not work through the custom nameplate buttons.

## Decision

**The custom combat click requirement failed.** The normal secure-button API
supports `type="target"` and a `unit` attribute, but `nameplateN` tokens cannot
be targeted by `/target nameplate1` or used as action targets. The in-game
secure-button probe did not select the named mob. The window is now view-only;
use Blizzard's world nameplates or Tab for target selection. Do not call
`TargetUnit`, use `/tar` by name, or change a secure button's unit attribute
from an insecure combat callback. Name search is ambiguous when enemies share
a name.

The review window now brightens only rows with readable group threat or a
verified player DoT. It dims other fixed-token rows. DoT presence checks run
only when aura access is unrestricted; during secret aura states, an unreadable
DoT is unknown and cannot by itself brighten a row.

## Findings and limits

| Question | Finding | Confidence |
| --- | --- | --- |
| Discover visible units | `NAME_PLATE_UNIT_ADDED/REMOVED` provide `nameplateN`; `C_NamePlate.GetNamePlates()` exposes visible plates. Nameplates outside the player's visible set cannot be listed reliably. | Documented |
| Secure combat click | `SecureActionButtonTemplate` supports `type="target"` with `unit`, but nameplate tokens are excluded as action targets. The Forever click test failed. | Rejected |
| Token or GUID | The documented secure target action takes a **unit token**, not a GUID. A GUID is unsuitable as a secure action unit attribute. | Documented |
| Preconfiguration | Create all protected buttons and set their fixed unit attributes before combat. Do not reparent, reposition, resize, show/hide, or set protected attributes in combat from addon Lua. Whether these fixed buttons continue resolving `nameplateN` correctly is unverified. | Partly documented; needs client test |
| Token reuse | Blizzard's nameplate driver sets a token on add and clears it on removal. A token denotes the *current* occupant, not an enemy identity. A row whose old name remains visible may target a different enemy after reuse. | Documented mechanism; consequence is an inference |
| Native auras | `AuraContainer:SetUnit(unitToken)` and `AddAuraSlot` exist, and the current HUD uses one native container per unit. One container per fixed nameplate token is plausible. In-combat unit rebinding, creation, and pooled aura-frame behavior need a Forever test. | Needs client test |
| Group engagement | `UnitThreatSituation(groupMember, nameplateN)` may confirm that a member has threat without requiring player threat, but nil does not prove the enemy is idle. Secret or unavailable results are unknown. `UnitAffectingCombat` alone does not establish combat with this group. | Partial signal only |
| Names and markers | `UnitName` and `GetRaidTargetIndex` can return secret values for enemy units. Any secret value must be treated as unreadable; never compare, concatenate, index a texture table, or cache it as an identity. | Documented |
| Current target | `UnitIsUnit(nameplateN, "target")` is the right comparison to probe; some client restrictions permit comparisons involving `target`. Guard any secret result. | Needs client test |

## Original candidate architecture (rejected for clicks)

1. Allocate eight **fixed token rows** outside combat: row 1 is always
   `nameplate1`, row 2 is always `nameplate2`, and so on. Each row gets a
   preconfigured secure button with `type="target"` and its fixed `unit`.
   Compare `SecureUnitButtonTemplate` with a minimal
   `SecureActionButtonTemplate`; use whichever passes the combat probe without
   extra interactions. Never assign a visible enemy to a different click row
   during combat. Physical slot order is intentional, not a sorted enemy list.
2. Keep the visible row label and aura container bound to the **same fixed
   token**. On removal, immediately invalidate any addon-owned cached name,
   marker, or GUID for that token. On add, regard it as a new occupant. Do not
   persist a combat label merely because it was last known; a stale label is
   worse than an empty or generic token label.
3. Use a separate Blizzard-native `CustomAuraContainerTemplate` for each
   token, with `HARMFUL|PLAYER` slots for Corruption, Immolate, Siphon Life,
   and Bane candidates. Configure slots before combat and let Blizzard handle
   aura selection and countdowns. Preserve the current Target DoTs container
   and behavior. Keep native aura buttons outside the targeting hit rectangle
   unless their click behavior is verified; do not attach script handlers to
   Blizzard's pooled aura buttons.
4. Treat engagement as a three-state property: confirmed group engagement,
   unknown, or confirmed excluded only when a supported non-secret signal
   truly proves exclusion. Prefer confirmed rows visually. Do not compact or
   sort clickable rows in combat, and do not hide an otherwise valid fixed row
   solely because engagement is unknown. A strictly engaged-only list may be
   impossible under restricted combat APIs.
5. Drive current-target highlight and text/marker display through native
   unit-aware widgets where possible. Otherwise update only from safe,
   non-secret values. A hidden or generic label is required when identity
   cannot be safely read; it must not display the previous occupant's name.

## Original in-game probe

Run with four visible hostile enemies, including duplicate names if possible,
then eight. Test both open world and an instance/raid with addon restrictions.

- Before combat, create fixed `nameplate1` through `nameplate8` secure buttons
  and native containers. Confirm which tokens are occupied using the nameplate
  add/remove events. Record whether any protected call is rejected.
- In combat, click row 2 and another occupied row. Confirm each selected mob
  by its **world/nameplate identity**, not just its name. Repeat after a plate
  disappears, a new enemy gets the same token, and two same-name enemies trade
  visibility. An absent token must not target an unrelated unit.
- Verify each row's native aura slot tracks only its token and the player's
  effect, and that countdowns continue without Lua aura scans. Confirm
  Corruption, Immolate, Siphon Life, and shared Bane behavior.
- Confirm name, marker, target highlight, and engagement handling under secret
  results. No stale label may remain on a reassigned token.
- Repeat with the existing Target DoTs HUD enabled; check taint and blocked
  actions, including after `/reload` during combat and when combat ends.

**Release gate:** all rows and clicks must stay associated with their fixed
tokens, no stale identity may be displayed on token reuse, no blocked actions
may occur, and existing native countdowns must remain correct. If any gate
fails, keep the multi-target window non-clickable and retain native nameplates
as the combat-safe target selector.

## Sources

- [SecureActionButtonTemplate](https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate)
  and [UnitToken nameplate restrictions](https://warcraft.wiki.gg/wiki/UnitToken)
- [Nameplate add event](https://warcraft.wiki.gg/wiki/Event:NAME_PLATE_UNIT_ADDED),
  [visible nameplates](https://warcraft.wiki.gg/wiki/API:C_NamePlate.GetNamePlates),
  and [Blizzard nameplate driver](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua)
- [AuraContainer:SetUnit](https://warcraft.wiki.gg/wiki/API:AuraContainer_SetUnit)
  and [AuraContainer:AddAuraSlot](https://warcraft.wiki.gg/wiki/API:AuraContainer_AddAuraSlot)
- [UnitThreatSituation](https://warcraft.wiki.gg/wiki/API:UnitThreatSituation),
  [UnitName](https://warcraft.wiki.gg/wiki/API:UnitName),
  [GetRaidTargetIndex](https://warcraft.wiki.gg/wiki/API:GetRaidTargetIndex),
  and [secret-value restrictions](https://warcraft.wiki.gg/wiki/Secret_Values)
