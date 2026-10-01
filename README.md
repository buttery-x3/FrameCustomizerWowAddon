# FrameCustomizer 0.2.0

A frame-agnostic authoring tool for **existing Blizzard UI objects**, targeting the supplied WoW Forever beta snapshot: **1.60.1, build 70124, interface 16001**, dated September 29, 2026. It customises existing widgets without replacing their values, scripts, events or interactions.

The installable build is `dist/FrameCustomizer-0.2.0.zip`. The user reported successful 0.1.0 loading, discovery, cosmetic opacity through combat/reload, pause-and-reload recovery and resume. **The changes in 0.2.0 have been verified offline only.** See [TEST_RESULTS.md](TEST_RESULTS.md) for executed checks and remaining client verification.

## Install and open

Extract the ZIP into the client's `Interface\AddOns` directory, producing:

```text
Interface\AddOns\FrameCustomizer\FrameCustomizer.toc
```

There is exactly one addon folder in the ZIP. No external library is required. **Fully restart the client after installing 0.2.0**, which adds a Lua module and a texture asset. For subsequent edits to already-listed Lua files, use `/reload` and check `/fcu report`. The supplied slash implementation calls `ReloadUI()`; this does not establish TOC/file/asset cache behavior or automatic hot reload.

Enable FrameCustomizer in the AddOns list and enter the game:

| Command | Action |
| --- | --- |
| `/fcu` | Open/close the movable, resizable editor |
| `/fcu pick` | Hover a frame, then Enter to select; Escape cancels; start outside combat |
| `/fcu pause` or `/fcu safe` | Persistently pause all overrides, independently of the editor |
| `/fcu resume` | Resume enabled entries |
| `/fcu report` | Open bounded, copyable diagnostics, including media detection |
| `/fcu playground` | Show editable addon-owned fixtures |
| `/fcu playground reset` | Reset fixture cosmetics through ordinary setters |
| `/fcu playground hide` | Hide the development playground |
| `/fcu test` | Run opt-in native fixture scenarios outside combat (~24 seconds) |
| `/fcu test stop` | Cancel and clean up the fixture test |

This development pass packages the addon without deploying to the game folder. A parameterized Windows deployment script is available; see [DEVELOPMENT.md](DEVELOPMENT.md).

## Edit an object

1. Expand `UIParent` or use **Pick**. Rows prominently show the parent key/local label and compact object type. A `?` beside the type means inspect-only; hover for the reason and full stable resolver path. **Copy path** opens selectable text. **Find path** accepts an exact global name followed by verified parent keys. The picker identifies mouse-focus frames; expand them to reach textures and FontStrings.
2. Search matches local labels, full paths and types. Results remain a pruned hierarchy containing matches and their ancestors. Relevant ancestors open automatically; collapse/expand applies only to the current query. Clearing search restores normal expansion state. **Scan search** feeds discoveries into the same tree. Undiscovered branches require expansion or scanning. **Refresh** clears search and rebuilds the snapshot. Scans do not force-load Blizzard addons.
3. Selection is inspection only, with a row highlight and automatic scrolling into view. The independent outline uses accessible screen coordinates; it does not alter or anchor to the target. Anonymous objects without verified persistent identity remain read-only.
4. Click **Create customisation**, choose a property, edit values, then **Enable this property override** or **Commit value**. Only enabled properties are enforced. Permitted cosmetic constants can work without a readable baseline. Position needs readable anchors to preserve their relationships.
5. **Saved entries** provides entry enable/disable, Delete, Apply Now and enforcement controls. Each property can inherit the entry strategy, use normal enforcement, or use its own periodic interval. Commit saves that property's strategy.

Opacity and colour components use `0..1`. Opacity zero is visual suppression: it does not logically hide a frame or remove its mouse hit area. Prefer decorative regions over interactive parents. Simultaneous opacity and colour-alpha overrides on the same object must use equal alpha constants to avoid conflicting ownership.

## Supported property families

- Opacity/decorative suppression on supported frames, textures and FontStrings.
- File texture/atlas replacement and RGBA tint. Atlas replacement does not adopt atlas size; file replacement preserves existing UV coordinates, which can crop an image.
- Font face, size, flags and colour on individual FontStrings. Shared Font objects are never mutated. Embedded text colour codes may take precedence.
- Status-bar fill texture and colour. The existing fill region is used; bar values, ranges, scripts and events remain unchanged by these properties.
- Size on objects with zero or one existing anchor, after native and manager checks. Multiple anchors can constrain dimensions, so size on those layouts is explicitly unsupported.
- Position using a single parent anchor or **1..8 preserved anchors**, including sibling/other stable relatives. X/Y are the primary anchor's absolute offsets in UI units; editing them translates all anchors and preserves spacing, point names and relative objects. The primary anchor is the first point alphabetically. A sole parent anchor retains the original editable point/relative-point behavior. **Anchor details** shows readable current and configured relationships.

Position and size no longer require `IsUserPlaced`, `IsMovable` or `IsResizable` flags. Native permission checks run before application and each geometry setter. Ordinary objects still need an accessible, ready Edit Mode registry and ancestry without identified managers. Registered Edit Mode systems, Blizzard UI panel registry/attributes and shared layout markers block geometry on the object/ancestors. Suspected ownership and unavailable metadata are conservative safety blocks. Cosmetics remain independently eligible. There are no individual Blizzard frame exceptions or manager-reset hooks.

Multiple-anchor layouts are never cleared. A changed anchor count, point name, relative point or relative identity blocks application rather than rebuilding an unexpected layout. To recapture after a legitimate change: disable Position, select it again, inspect Anchor details, edit X/Y and commit. Anonymous relatives without stable identity, secret/inaccessible anchors and sets beyond eight are unsupported. Primary offsets use `-4096..4096`; preserved relative deltas and resulting offsets are bounded to `-8192..8192`.

Geometry reasons distinguish **Native restriction**, **Inaccessible**, **Unsupported layout**, **Managed layout**, and **Safety policy**. A representation/safety block does not claim WoW denied the operation. A ready registry with no known manager metadata does not prove no other code will reposition an object. This broader eligibility still needs real-client testing.

## Media selection

**Browse media** opens a searchable picker with friendly names, source/type columns, All/SharedMedia/Built-ins filters, Refresh, full-path tooltips and detection counts. Fonts use registered `font` assets; status bars use `statusbar`; texture replacement offers `background` and `statusbar` assets. The editor and `/fcu report` state whether LibSharedMedia-3.0 is available. Opening/refreshing the picker enumerates current registrations, including libraries/assets loaded later. Enumeration is bounded to 1000 entries per media type.

LibSharedMedia was already optional in 0.1.0. That editor provided little detection/provenance feedback, and choosing a file did not reset a texture's manual `atlas` kind. Version 0.2.0 fixes both. The first live report did not establish which provider/library was loaded; use the new diagnostics to verify that. No third-party library or font is bundled. The adapter follows the maintainer's [List / Fetch API](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation), using `Fetch(type, name, true)` so failed fetches do not silently substitute defaults.

The picker displays friendly names but saves the resolved file path. Commit applies that constant using the existing property setters. Saved values do not depend on library keys remaining registered; the actual asset/provider files must still exist. Aliases for the same path may display the first matching name after reload: names are presentation, not saved identity. Manual file paths and atlas names remain editable. Choosing a texture file sets Kind to `file`. Missing/malformed libraries fall back to built-ins/manual entry; unavailable saved files are not silently replaced.

**Transparent / blank** is an addon-owned 8x8, 32-bit uncompressed TGA with zero alpha in every pixel, shipped as `FrameCustomizer/Media/Transparent.tga` under the addon MIT licence. Packaging and deployment include it through TOC asset metadata; tests validate its header, pixels and copies. It can suppress artwork when alpha/tint is modulated, but later texture/atlas resets still need enforcement. Native loading/rendering of this new asset remains a client check.

## Persistence, enforcement and recovery

Rules use the existing version-1 account-wide SavedVariables table. The optional validated `position.anchors` extension leaves old four-field parent-position values and cosmetic rules intact; no destructive migration is needed. Only validated declarative values, strategies and pause state are saved, never live objects or session baselines. The independent `FrameCustomizerSafeMode` flag survives an unsupported database schema. Malformed properties/rules are rejected independently and reported; duplicate-target entries are paused. Unknown database versions are preserved and opened read-only.

Normal enforcement uses permitted setter posthooks plus **2-second readable verification**. Optional periodic reapplication sends configured constants at **0.25–60 seconds**, including when cosmetic reads are unavailable. Geometry never bypasses current permission/representation checks. Lower intervals cost more. The shared work budget makes these minimum cadences, not guaranteed deadlines under load. Unresolved targets retry every three seconds, with earlier generic load/combat/restriction notifications. Hooks ignore obsolete/disabled rules. Three actual operation errors suspend a property with backoff; fix the cause and Apply Now to retry.

Status distinguishes disabled, pending, unresolved/ambiguous, blocked, failed, matched at last readable check, and constant applied with inaccessible current value. A successful setter does not prove rendered appearance. Native changes, animations and cached method references can bypass hooks; verification/periodic writes may allow flicker.

Pause All, disabling/deleting rules and disabling properties stop future enforcement and pending work. They do not restore Blizzard's current intended appearance. **Undo session** disables the entry and attempts to restore accessible per-property session values for the same object. It is approximate and may be blocked. For recovery: `/fcu pause`, then `/reload`; resume when ready. If the addon cannot load, disable FrameCustomizer in the AddOns list.

## Limits and client acceptance

No arbitrary scripts, gameplay triggers, replacement UI, logical parent hiding, shared-font mutation, anonymous/pool fingerprints, child-index identities, or Edit Mode takeover. Only verified global names and actual parent-key chains persist. Rules identify widgets/slots, not the gameplay entity displayed. Changed identities are never replaced by guessed matches.

Discovery is capped at 6000 objects, 16 reference inspections per slice, and 256 children/regions per ordinary object (4096 for the initial UI root). Closed branches are lazy. Inaccessible, huge or detached hierarchies may need Pick or an exact path. Search is not an exhaustive global scan. Native secrets, taint, template layout, fonts/assets, scale, combat transitions and rendering need client verification.

1. Install 0.2.0 with a full restart; check `/fcu report`. Run `/fcu test` outside combat and copy PASS/FAIL/SKIPPED results. These are addon-owned fixtures; successful calls do not certify rendered appearance or protected Blizzard behavior.
2. Browse a deep real hierarchy: check local labels/types, tooltip/copy path, highlight and scrolling. Search a name, full path and type; collapse an ancestor, scan, then clear search and verify previous expansion state returns.
3. Open `/fcu playground`, expand **Art**, and use the editor: **Decoration** → Texture → Transparent / blank; **Bar** → Status bar texture; **Label** → Font. With a provider loaded, choose SharedMedia assets by name and inspect rendering. Check bar values/buttons. Restart with all LSM providers disabled and verify built-ins/manual entry still work. `/fcu test` also exercises an explicit built-ins-only fallback without changing installed libraries.
4. Use **SiblingAnchor** and **TwoAnchors**: inspect Anchor details, change X/Y, verify relationships/spacing, enforcement, undo and reload persistence. Test eligible unrelated Blizzard panels. Confirm Edit Mode/shared/UI-panel geometry is blocked with a manager reason while cosmetics work. Multi-anchor size should report unsupported, not API-denied.
5. On unrelated Blizzard decorations, test refresh, periodic enforcement, late loading, reload persistence, disable/delete, Pause All + reload and Resume. Reconfirm combat transitions: denied geometry must produce no writes/action-blocked errors, while permitted cosmetics should retain the previously observed behavior. Copy `/fcu report` for affected entries.
