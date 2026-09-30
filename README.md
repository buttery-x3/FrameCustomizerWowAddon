# FrameCustomizer 0.1.0

An authoring tool for **existing UI objects**, targeting the supplied WoW Forever beta snapshot: **1.60.1, build 70124, interface 16001**, dated September 29, 2026. It does not replace Blizzard widgets, bar values, scripts, events or interactions.

The installable first build is `dist/FrameCustomizer-0.1.0.zip`. Offline verification has passed; it has **not been run in your WoW client**. See [TEST_RESULTS.md](TEST_RESULTS.md) for coverage and remaining checks.

## Install and open

Extract the ZIP into your chosen client's `Interface\AddOns` directory. The result must be:

```text
Interface\AddOns\FrameCustomizer\FrameCustomizer.toc
```

There is exactly one addon folder in the ZIP. No external library is required. Fully exit and relaunch the client for the first install, or when adding/changing TOC entries, files or assets. This is the conservative installation procedure; this export alone does not establish the client's file-discovery/cache behaviour. For edits to already-listed Lua files, use `/reload` and verify the new version with `/fcu report`. The supplied slash-command implementation calls `ReloadUI()`; no automatic hot reload is claimed.

Enable **FrameCustomizer** in the AddOns list, enter the game, then use:

| Command | Action |
| --- | --- |
| `/fcu` | Open/close the movable, resizable editor |
| `/fcu pick` | Hover a frame, then Enter to select; Escape cancels; start outside combat |
| `/fcu pause` or `/fcu safe` | Persistently pause every override, independently of the main editor |
| `/fcu resume` | Resume enabled entries |
| `/fcu report` | Open a bounded, copyable diagnostic bundle |
| `/fcu playground` | Create/show editable addon-owned fixtures |
| `/fcu playground reset` | Reset their accessible cosmetics through ordinary setters |
| `/fcu playground hide` | Hide the development playground |
| `/fcu test` | Run the opt-in native fixture scenarios outside combat (~21 seconds) |
| `/fcu test stop` | Cancel and clean up the fixture test |

Nothing has been deployed to your actual game folder. A parameterized Windows deployment script is available; see [DEVELOPMENT.md](DEVELOPMENT.md).

## Edit an object

1. Expand `UIParent` and its children, or use **Pick** and expand the selected frame to reach its textures and font strings. The picker identifies mouse-focus frames; individual layered regions may not be mouse-pickable. **Find path** accepts an exact global name followed by verified parent keys.
2. Search filters discovered paths, types and labels. **Scan search** incrementally explores additional accessible branches. **Refresh** rebuilds the discovery snapshot. Scans do not force-load Blizzard addons.
3. Selection is inspection only. An independent outline is drawn from accessible screen coordinates; it does not alter or anchor to the target. Anonymous objects without a verified persistent identity remain read-only.
4. Click **Create customisation**, choose a property, edit its values, then **Enable this property override** or **Commit value**. Only explicitly enabled properties are enforced. Values are also valid when their baseline cannot be read, if the separate write operation is permitted.
5. Use **Saved entries** to select rules, toggle **Entry enabled**, **Delete**, **Apply Now**, or change enforcement settings. A property's strategy can inherit the entry, use normal enforcement, or use its own periodic interval. **Commit value** saves that property strategy.

Colour components and opacity use `0..1`. Setting opacity to zero is **visual suppression**: it does not logically hide a frame or remove its mouse hit area. Prefer decorative child regions over interactive parents. When opacity and a colour alpha override are both enabled on the same target, this first build requires equal alpha constants to avoid conflicting ownership.

## Supported property families

- Opacity/decorative suppression on supported frames, textures and font strings.
- File texture or atlas replacement and RGBA texture tint. Atlas replacement does not resize the object. File replacement preserves UV coordinates, which can crop a replacement image.
- Font face, size, flags and colour on individual FontStrings. Shared Blizzard Font objects are never mutated. Embedded text colour codes may override colour styling.
- Status-bar fill texture and colour. The existing fill region is used; values, ranges, scripts and events remain Blizzard's responsibility.
- Size and one anchor relative to the existing parent **only when geometry ownership and API permissions are established**. Ordinary targets must be movable, user-placed frames (also resizable for size), have one parent anchor, have a ready Edit Mode registry, and have no identified managed-layout/Edit Mode ancestry. Fixtures have explicit ownership. Most Blizzard geometry will correctly be unavailable. Cosmetic eligibility is independent of Edit Mode position ownership.

Asset buttons offer built-in files and optional LibSharedMedia-3.0 assets already provided by another addon. No library or font is bundled. The integration uses the library's documented [`List` and `Fetch` API](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation). You can also type an existing file path or known atlas name. Unavailable assets can be blocked/rejected; no substitute file is invented.

## Persistence, enforcement and recovery

Rules and their strategies use a versioned, account-wide SavedVariables table. Only validated declarative values are persisted, plus pause state; live object references and baselines are never saved. The independent `FrameCustomizerSafeMode` flag survives an unsupported database schema. Malformed rules/properties are rejected independently and reported. Conflicting duplicate target entries are all paused. Unknown database versions are preserved and opened read-only.

Normal enforcement uses permitted setter posthooks plus a **2-second readable verification** cadence. **Periodically reapply customisations** explicitly enables repeated constant writes at **0.25–60 seconds**, including when reads are unavailable. Lower intervals cost more. Both strategies use a shared work budget; their times are minimum cadences, not hard deadlines under load. Unresolved targets retry every 3 seconds, with earlier generic load/combat/restriction notifications. Installed hooks ignore obsolete and disabled rules. Three actual operation errors suspend a property with backoff; fix its cause and use **Apply Now** to retry.

Status distinguishes disabled, pending, unresolved/ambiguous, blocked, failed, matched at last readable check, and constant applied with an inaccessible current value. A successful setter call does not prove the rendered appearance stays correct. Native changes, animations and saved method references can bypass hooks; verification/periodic writes can still allow visible flicker.

**Pause All**, disabling an entry/property and deleting a rule stop future enforcement, including pending work. They do not claim to restore current Blizzard intent. **Undo session** disables that entry and attempts to restore accessible per-property values captured in this session for the same object. It is approximate, can be blocked, and is not a whole-frame reset. Use an ordinary UI refresh or `/reload` if appropriate. For recovery: `/fcu pause`, then `/reload`; resume only when ready. If the addon cannot load at all, disable FrameCustomizer in the AddOns list.

## Known limits and client acceptance

No arbitrary scripts, gameplay triggers, combat-data analysis, replacement UI, logical parent hiding, shared-font mutation, anonymous/pool fingerprints, child-index identities, or automatic Edit Mode takeover. Only verified global names and actual parent-key chains persist. Rules address UI widgets/slots, not the identity of the gameplay entity they display. Unavailable types and permissions remain read-only/blocked. A structurally changed target is never replaced by a guessed match.

Discovery is intentionally capped at 6000 objects, 16 reference inspections per slice and 256 children/regions per ordinary object (4096 for the initial UI root snapshot). Closed branches are lazy. Some inaccessible, huge, or detached hierarchies require the picker or a known exact path. Normal search is not an exhaustive global object search. Native secrets, taint, real template layout, fonts/assets, combat transitions and rendering remain **client-only verification**.

Small acceptance checklist:

1. Run `/fcu test` outside combat and copy its PASS/FAIL/SKIPPED report. These are addon-owned native fixtures, not certification of protected Blizzard widgets.
2. Through the normal editor, choose decorations on two unrelated Blizzard windows: suppress one, replace a texture, and change a FontString. Exercise each window's ordinary refresh and confirm its original controls still work.
3. Enable periodic reapplication on one entry, then `/reload`; confirm values, toggles and intervals persist. Save a rule for a load-on-demand window and confirm it resolves when that window loads after reload.
4. Enter/leave combat normally. Confirm denied operations stay blocked, permitted cosmetics behave as intended, and no action-blocked errors appear. Do not force protected violations.
5. Check per-property and per-entry disable, Delete, `/fcu pause`, reload while paused, and `/fcu resume`. Use `/fcu report` with the affected entry selected (editor **Report**) to provide reproduction details.
