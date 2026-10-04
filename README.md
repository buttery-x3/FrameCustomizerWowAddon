# FrameCustomizer 0.5.0

A frame-agnostic authoring tool for **existing Blizzard UI objects and addon-created presentation panels**, targeting the supplied WoW Forever beta snapshot: **1.60.1, build 70124, interface 16001**, dated September 29, 2026. It customises existing widgets without replacing their values, scripts, events or interactions.

The installable build is `dist/FrameCustomizer-0.5.0.zip`. The editor now uses shared movable windows, automatic stacking, bordered controls and dropdowns. This addresses dialog controls overlapping other windows and extends movement to the media/visual lists, reports, picker and playground. **Offline validation and approximate layout previews pass; native rendering and interaction still need client retesting.** See [TEST_RESULTS.md](TEST_RESULTS.md).

## Install and open

Extract the ZIP into the client's `Interface\AddOns` directory, producing:

```text
Interface\AddOns\FrameCustomizer\FrameCustomizer.toc
```

There is exactly one addon folder in the ZIP. No external library is required. **Fully restart the client when upgrading to 0.5.0:** the TOC adds `UI/Widgets.lua`. Check `/fcu report` for version `0.5.0 / managed-editor-windows`. Later edits to already-listed Lua files can use `/reload`; automatic hot reload or TOC/file-cache refresh is not assumed.

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
| `/fcu test` | Run opt-in native fixture scenarios outside combat (~30 seconds) |
| `/fcu test stop` | Cancel and clean up the fixture test |

This development pass packages the addon without deploying to the game folder. The Windows deployment script can remember your AddOns path in a Git-ignored `.env` file; see [DEVELOPMENT.md](DEVELOPMENT.md).

## Editor windows and controls

Drag any tool window by its title bar. Opening or clicking a window brings its entire contents forward; its background, buttons, fields and labels move together in the stacking order. The main editor, visual editor, media/visual lists, reports, picker and interactive playground share bordered headers, Close buttons and screen clamping. Positions last for the session. The main editor remains resizable, with a minimum layout size and automatic fitting to the screen. Passive tooltips and selection outlines follow their subjects; authored presentation panels keep their own saved layer settings and click-through behaviour.

The main editor groups browsing, selection, properties and editing in separate sections. **Hierarchy / Saved entries** is a dropdown. Finite choices such as texture type, font flags, anchor points, strata, draw layer, media source and enforcement strategy use dropdowns instead of cycling buttons or free-text constants. Click an option, or use Up/Down then Enter. Escape or an outside click dismisses the menu without changing the value; an outside click is consumed by the menu. Checkboxes include their text in the click area.

The visual form groups name/attachment, appearance, size/placement and layering. Fixed sizing shows dimensions/anchors; fill sizing shows padding, preserving hidden values when switching. Solid colour hides the asset-path input; Browse media can still select a texture. Lists provide search, Previous/Next and wheel scrolling, with labels appropriate to assets or visuals. The object picker temporarily hides the other tool windows and restores those that were open when selection finishes or is cancelled.

## Edit an object

1. Expand `UIParent` or use **Pick object**. Rows prominently show the parent key/local label and compact object type. A `?` beside the type means inspect-only; hover for the reason and full stable resolver path. **Copy path** opens selectable text. **Exact global path → Find** accepts a global name followed by verified parent keys. The picker identifies mouse-focus frames; expand them to reach textures and FontStrings.
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
- Frame strata and level on supported frame types, subject to native protected-operation checks. Level reads respect the FrameLevel secret aspect; permitted constant writes do not require a readable baseline.
- Draw layer and sublevel on textures and FontStrings. These order regions within their containing frame, not across the entire UI.
- Size on objects with zero or one existing anchor, after native, representation and property-specific Edit Mode checks. Multiple anchors can constrain dimensions, so size on those layouts is explicitly unsupported.
- Position using a single parent anchor or **1..8 preserved anchors**, including sibling/other stable relatives. X/Y are the primary anchor's absolute offsets in UI units; editing them translates all anchors and preserves spacing, point names and relative objects. The primary anchor is the first point alphabetically. A sole parent anchor retains the original editable point/relative-point behavior. **Anchor details** shows readable current and configured relationships.

Position and size do not require `IsUserPlaced`, `IsMovable` or `IsResizable` flags. Required access, protected-operation, anchoring and forbidden-layout checks run before application and each geometry setter. **A UI-panel registry/attribute, shared-layout marker or Edit Mode ancestor is advisory evidence of another writer.** When the actual native and representation requirements pass, an explicitly enabled override reaches the writer through the existing normal or optional periodic enforcement. No extra unlock is needed.

FrameCustomizer deliberately leaves **the selected object's exposed Edit Mode position** to Edit Mode. Direct registration plus the exported movement-handler identity identifies that control. Size is assessed separately: direct registration, a supported same-object dimension handler and its active settings identify a duplicate size control. Scale or internal/child size settings alone do not block native width/height. Size writes both dimensions, so a proven width or height control excludes the combined Size override. Unknown/missing optional metadata and unclassified Edit Mode controls are reported honestly; they do not imply native denial. See [SOURCE_NOTES.md](SOURCE_NOTES.md) for supported evidence and classification limits. No individual frame-name exceptions or manager reset hooks exist.

Multiple-anchor layouts are never cleared. Ordinary offset resets can be corrected without accumulating drift. A changed count, point name, relative point or unresolved relative identity prevents an unsafe write. To recapture after a legitimate relationship change: disable Position, select it again, inspect Anchor details, edit X/Y and commit. Anonymous relatives without stable identity, secret/inaccessible required anchors and sets beyond eight remain unsupported. Primary offsets use `-4096..4096`; preserved relative deltas and resulting offsets are bounded to `-8192..8192`. The complete intended anchor update is prepared before mutation; permission is rechecked for every setter. Coordinated calls are not atomic: a mid-update denial can leave a partial update until a later permitted retry or normal UI refresh.

**Eligibility report** beside Commit value shows target/property, native/access preflight, representation support, product policy and management observations separately, with stable reason codes. Observations distinguish the target from an ancestor, confirmed property controls from heuristic hints, and unknown scans from known matches. An identity is printed only when verified. The persistent inspector advisory remains alongside pending/applied/matched enforcement; `/fcu report` includes the last engine findings without reading live values. Passed preflight or a successful setter does not prove lasting rendered appearance.

| Logic case (native/access and representation checks pass) | 0.2.0 | 0.3.0 |
| --- | --- | --- |
| Ordinary UI-panel target | Broad manager block | Eligible with scoped advisory; setter executes |
| Descendant of an Edit Mode system | Inherited manager block | Local position/size eligible with ancestor context |
| System's own exposed Edit Mode position | Broad manager block | Explicit product policy: use Edit Mode |

These are policy decisions and offline logic results, not claims of native compatibility. **Existing enabled rules that were blocked only by the old management policy may begin applying after this upgrade.** Disabled flags, per-property strategies and global pause state are preserved; there is no saved-data migration.

## Media selection

**Browse media** opens a searchable picker with friendly names, source/type columns, All/SharedMedia/Built-ins filters, Refresh, full-path tooltips and detection counts. Fonts use registered `font` assets; status bars use `statusbar`; texture replacement offers `background` and `statusbar` assets. The editor and `/fcu report` state whether LibSharedMedia-3.0 is available. Opening/refreshing the picker enumerates current registrations, including libraries/assets loaded later. Enumeration is bounded to 1000 entries per media type.

LibSharedMedia was already optional in 0.1.0. That editor provided little detection/provenance feedback, and choosing a file did not reset a texture's manual `atlas` kind. Version 0.2.0 fixes both. The first live report did not establish which provider/library was loaded; use the new diagnostics to verify that. No third-party library or font is bundled. The adapter follows the maintainer's [List / Fetch API](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation), using `Fetch(type, name, true)` so failed fetches do not silently substitute defaults.

The picker displays friendly names but saves the resolved file path. Commit applies that constant using the existing property setters. Saved values do not depend on library keys remaining registered; the actual asset/provider files must still exist. Aliases for the same path may display the first matching name after reload: names are presentation, not saved identity. Manual file paths and atlas names remain editable. Choosing a texture file sets Kind to `file`. Missing/malformed libraries fall back to built-ins/manual entry; unavailable saved files are not silently replaced.

**Transparent / blank** is an addon-owned 8x8, 32-bit uncompressed TGA with zero alpha in every pixel, shipped as `FrameCustomizer/Media/Transparent.tga` under the addon MIT licence. Packaging and deployment include it through TOC asset metadata; tests validate its header, pixels and copies. It can suppress artwork when alpha/tint is modulated, but later texture/atlas resets still need enforcement. Native loading/rendering of this new asset remains a client check.

## Create independent and attached visuals

The top toolbar **Add visual** opens the creation form with screen placement and fixed dimensions. **Add visual** beside a selected stable object opens the same form with that attachment, fill sizing and behind-target ordering. No override rule on the selected object is required. Drag the editor's title bar to reveal visuals underneath it; its position is retained while saving or reopening during the session and kept on screen. **Close** leaves unsaved edits unapplied; **Create/Save** validates and commits them. The editor remains usable when an existing saved attachment is temporarily unavailable.

- **Appearance:** solid colour, file texture or atlas, RGBA colour, and the existing searchable media picker. Solid colour uses the built-in white texture and the normal tint property. Atlas size is not adopted.
- **Placement:** blank target means screen placement. Enter an exact verified target path or choose **Use selected**. **Independent on screen** changes placement to the screen, fixed sizing and manual layering. The identity and other settings survive changing placement.
- **Sizing:** fixed width/height with independent anchor points and X/Y offsets; or fill the target with four padding values and X/Y translation. Positive padding insets, negative padding expands. Width/height apply only in fixed mode. Inputs use UIParent's UI units. Native anchors follow the target's bounds; scale behaviour needs client inspection.
- **Visibility:** independent panels follow UIParent. Attachments follow the target frame, or the containing frame for a selected Texture/FontString. An optional exact frame path chooses a separate visibility container. Zero alpha is not treated as logical hiding.
- **Layering:** manual strata/level, or **behind**, which uses the target's containing frame's readable strata and one lower frame level. Editing strata or typing a level switches the relationship to **manual**; Save applies it. Select **behind** again to follow the target automatically. A level of zero, unavailable layer data or unsupported strata explicitly blocks behind mode. Texture draw layer/sublevel remain independently editable. Supported representation: eight named strata, levels 0..10000, five draw layers and sublevels -8..7. Owned panels unlock around layer writes and restore their fixed flags; unreadable or mismatched layer readback leaves the visual pending instead of reporting it active.

**Your visuals** lists all saved panels. **Attached visuals** lists those associated with the selected target. Select one to rename, duplicate, change attachment, enable/disable or delete it. Duplicate creates a new identity. Disabled and unresolved entries stay accessible. Panels remain click-through; use the editor list or hierarchy to select them.

Each panel is a plain addon-owned frame parented to UIParent with one texture. Neither the host nor texture is inserted into the target's native hierarchy. Consequently panels do **not inherit target alpha or clipping**, including scrolling clips. This makes them suitable for backgrounds around window/container bounds; it does not promise clipped decoration inside scrolling content. Behind mode orders relative to the containing frame, not individual regions or all overlapping windows. Native rendering must verify the player health-bar and quest-window examples.

Visibility and attachment readiness are sampled at a minimum 0.2-second cadence; layout/appearance verification runs at a minimum two-second cadence. Changes to readable target layers schedule configuration on the next sample. Both use bounded work, so load can delay them and transitions may flicker. Native geometry, secret values and access checks still apply to our own objects and their relatives. Denial never enables a bypass.

There are at most 64 saved visuals and 64 allocated hosts per controller/session, with hidden, detached objects reused after permitted retirement. Deleting or disabling a visual, or Pause All, removes its visible contribution when native access permits. Denied cleanup is reported as **pending removal** and retried, including while paused. No native object destruction is claimed. `/fcu pause`, then `/reload`, prevents recreation and completes recovery. Resume restores enabled definitions. No standalone scripts, gameplay triggers, grouping, static text or dedicated borders are provided in 0.4.0.

## Persistence, enforcement and recovery

The account-wide SavedVariables table now uses **schema 2**. A validated copy migrates schema 1, preserving existing rule IDs, values, enable flags, intervals, anchor semantics and pause state. Separate visual definitions and monotonically advancing IDs are added; native objects and baselines are never saved. Unknown versions or malformed top-level tables preserve the original variable and start paused/read-only. Individual invalid entries are reported and skipped; duplicate existing-object targets are paused. The independent `FrameCustomizerSafeMode` flag survives unsupported data. Older releases recognise schema 2 as unsupported and preserve it read-only; they cannot edit it. Back up SavedVariables before deliberately downgrading.

Normal enforcement uses permitted setter posthooks plus **2-second readable verification**. Optional periodic reapplication sends configured constants at **0.25–60 seconds**, including when cosmetic reads are unavailable. Geometry never bypasses current permission/representation checks. Lower intervals cost more. The shared work budget makes these minimum cadences, not guaranteed deadlines under load. Unresolved targets retry every three seconds, with earlier generic load/combat/restriction notifications. Hooks ignore obsolete/disabled rules. Three actual operation errors suspend a property with backoff; fix the cause and Apply Now to retry.

Status distinguishes disabled, pending, unresolved/ambiguous, blocked, failed, matched at last readable check, and constant applied with inaccessible current value. A successful setter does not prove rendered appearance. Native changes, animations and cached method references can bypass hooks; verification/periodic writes may allow flicker.

For existing-object rules, Pause All, disabling/deleting rules and disabling properties stop future enforcement and pending work. They do not restore Blizzard's current intended appearance. Created visuals instead retire as described above. **Undo session** on an existing-object entry disables it and attempts to restore accessible per-property session values for the same object. It is approximate and may be blocked. For recovery: `/fcu pause`, then `/reload`; resume when ready. If the addon cannot load, disable FrameCustomizer in the AddOns list.

## Limits and client acceptance

No arbitrary scripts, gameplay triggers, replacement gameplay UI, logical Blizzard-parent hiding, shared-font mutation, anonymous/pool fingerprints, child-index identities, or duplication of supported same-object Edit Mode controls. Existing-object identities use verified global names and actual parent-key chains; created components use the explicit visual registry. Rules identify widgets/slots, not the gameplay entity displayed. Changed identities are never replaced by guessed matches.

Discovery is capped at 6000 objects, 16 reference inspections per slice, and 256 children/regions per ordinary object (4096 for the initial UI root). Closed branches are lazy. Inaccessible, huge or detached hierarchies may need Pick or an exact path. Search is not an exhaustive global scan. Native secrets, taint, template layout, fonts/assets, scale, combat transitions and rendering need client verification.

1. Install 0.5.0, fully restart, and check `/fcu report`. Open the main editor, visual form, texture picker, visual list and report together. Bring each forward using a visible control, drag it, close/reopen it, and check that lower windows' text/buttons never show through its background. Exercise dropdown click/keyboard/dismissal, report scrolling, narrow screens/UI scale, and picker cancellation/restoration. Run `/fcu test` outside combat and retain PASS/FAIL/SKIPPED results. These are addon-owned fixtures; successful calls do not certify rendered appearance or protected Blizzard behavior.
2. Browse a deep real hierarchy: check local labels/types, tooltip/copy path, highlight and scrolling. Search a name, full path and type; collapse an ancestor, scan, then clear search and verify previous expansion state returns.
3. Open `/fcu playground`, expand **Art**, and use the editor: **Decoration** → Texture → Transparent / blank; **Bar** → Status bar texture; **Label** → Font. With a provider loaded, choose SharedMedia assets by name and inspect rendering. Check bar values/buttons. Restart with all LSM providers disabled and verify built-ins/manual entry still work. `/fcu test` also exercises an explicit built-ins-only fallback without changing installed libraries.
4. Use **SiblingAnchor** and **TwoAnchors**: inspect Anchor details, change X/Y, verify relationships/spacing, enforcement, undo and reload persistence. Use an affected real panel: inspect Eligibility report, enable a permitted edit, then reopen/refresh it. Compare normal enforcement and optional periodic mode, then confirm pause + reload recovery. Check that the selected system's exposed Edit Mode position uses Edit Mode, while an eligible descendant can edit its local geometry. Multi-anchor size must remain unsupported even with an advisory. QuestFrame, WorldMapFrame and PlayerFrame are manual examples only; eligibility is never keyed by these names.
5. On unrelated Blizzard decorations, test refresh, periodic enforcement, late loading, reload persistence, disable/delete, Pause All + reload and Resume. Reconfirm combat transitions: denied geometry must produce no writes/action-blocked errors, while permitted cosmetics should retain the previously observed behavior. Copy `/fcu report` for affected entries.
6. Select the full health StatusBar, then **Add visual**: confirm the background stays full length as health changes. Try a quest-window background and an independent panel behind several action bars. Check readable content, working buttons, movement, resize, reopen, UI scale, alpha, overlap and clipping limits. Verify both creation defaults, Close, media choice, rename, duplicate, screen/attachment changes, disable/delete, pause/resume and reload persistence. Drag the visual editor away from the panel being edited and check that Save retains the editor position. Change strata/level, verify the relationship switches to manual, Save and inspect actual overlapping frames; then switch back to behind and inspect target-relative ordering. Test targets that load late and native combat/restriction transitions. Rendering, timing, editor layout and taint remain manual checks.
