# Test results — 2026-10-01

**FrameCustomizer 0.2.0 / explorer-media-geometry-1** is implemented and packaged. **71 offline scenarios pass: 30 core + 17 existing native-contract + 24 new explorer/media/geometry regression scenarios.** All original scenarios remain; the old requirement that a non-user-placed frame be denied was updated to test the intended broader policy.

The user's first 0.1.0 live run confirmed loading, real-object discovery, player artwork/portrait opacity, combat survival, reload persistence, Pause All + reload recovery and Resume. That evidence is retained. **This pass has not run 0.2.0 in WoW.** It does not certify the new geometry/media behavior, security or rendering from mocks.

## Executed automated commands

Working directory: `D:\dev\FrameCustomizerWowAddon`. The existing `.tools/venv` Python 3.14/Lupa 2.6 environment was reused. No runtime dependency was added to the addon.

| Command | Final result |
| --- | --- |
| `& .tools/venv/Scripts/python.exe scripts/check.py` | PASS throughout development after fixes; the identical final check is invoked by packaging below: 30 core + 17 existing native-contract + 24 regression scenarios. Eleven production Lua modules compile in Lua 5.1; TOC references are exact; transparent TGA header, dimensions, every alpha pixel, runtime path and asset manifest validate. |
| `& .tools/venv/Scripts/python.exe scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'` | PASS — 58 declaration/shared-source contracts. The original supplied ZIP was read without execution or modification; fingerprint unchanged. |
| `& .tools/venv/Scripts/python.exe scripts/package.py` | PASS — reruns all 71 scenarios, then validates exact ZIP member names, unique addon root, integrity and every member against source. |
| `& ./scripts/test-deploy.ps1` | PASS — WhatIf, fresh install, refusal without Update, backup update, unrelated-addon rejection, sibling addon/WTF sentinels unchanged, transparent texture hash preserved. |

Final installable package: **`dist/FrameCustomizer-0.2.0.zip`**, **37,479 bytes**, **14 allowlisted files**, exactly one top-level `FrameCustomizer/` directory: TOC, eleven Lua modules, MIT licence and the addon-owned transparent TGA.

SHA-256: `4e60df1e796273eec09251167a5270f904c34f5c59973c1d2e4cb17198e18719` (also `dist/FrameCustomizer-0.2.0.zip.sha256`).

The deployment test used only `.tools/deployment-test-76993ee727294f9e8397248bb176d928` and its recoverable backup under ignored `dist/deploy-backups/`. **No game-installation or actual account settings were changed.** The supplied Blizzard source is not packaged. No third-party fonts, textures or libraries were bundled.

## New regression coverage

- Local parent-key labels and compact types are separate from verified resolver paths. Anonymous objects remain inspect-only; aliases still fail identity validation.
- Search retains ancestry and depth, collapse/expand works while filtered, clearing the query restores normal expansion, scans feed the same hierarchy, and filtered leaves do not pretend to have matching children.
- Selection reveals ancestors, scrolls into view and highlights a row. Tooltips retain stable paths. Saved entries still render/select after the navigation changes.
- Embedded LibStub detection and all supported media categories; missing/incompatible/failing libraries; inaccessible lists/entries; skipped invalid fetches; late registrations; enumeration cap; explicit built-ins-only fallback.
- Normal editor pickers show source/name, select resolved files, change atlas kind to file, preserve chosen friendly aliases during editing, save/reload declarative values and invoke texture, font and status-bar property setters. Bar values remain untouched.
- Actual on-disk transparent texture validation and allowlisted packaging/deployment. No mock is used to claim the client can decode/display it.
- Native fixture orchestration with LSM absent and a mock provider present; optional font step, built-in fallback, texture/statusbar replacement and sibling/multiple-anchor translation. Repeated runs retain bounded native fixture/hook allocations and cancellation cleans up.
- Nonmovable/non-user-placed objects become eligible when native and manager gates permit; no setter changes those flags. Native denial, inaccessible data, missing checks, known managers and conservative decisions have distinct reasons.
- Edit Mode registration, panel registry/attributes and shared layout ancestry block geometry but leave cosmetics independently eligible.
- Sibling-relative identity capture and multiple-anchor translation without ClearAllPoints; schema round trips; readable verification; undo; legacy single-parent compatibility; multi-anchor size rejection.
- Invalid/duplicate anchors, unsupported relatives, offset ranges, changed anchor count/relationships, relative type changes, relative forbidden layout and native permission changes stop writes. Periodic mode never forces a denied operation. Each primitive geometry setter rechecks permission.
- The editor retains anchor snapshots while editing, recaptures disabled position rules and refuses a new position without readable anchors. Reports contain validated configured relationships without reading live geometry.

The original core coverage of schema validation, secret sentinels, resolver rebinding, per-property isolation, normal/periodic enforcement, shared budgets, hook deduplication, backoff, pause/delete/undo, duplicate targets and diagnostics is preserved. The native recorder still fails unknown methods; it is not a WoW emulator.

During development the suite caught the deliberately obsolete user-placement assertion, a friendly-name ambiguity for duplicate media paths, and a verification assertion that mistakenly expected periodic mode to stop reapplying matching values. Review also found a saved-entry rendering branch that needed a guard after adding filtered-child controls; it now has a regression. These are resolved; final checks pass.

## Native acceptance still required

1. **Upgrade/load/UI:** fully restart with the new Lua module and TGA; confirm 0.2.0 in `/fcu report`. Verify actual editor layout, label truncation/tooltips, indentation, row selection, scrolling, query collapse/clear and Scan search on a large real hierarchy.
2. **Media:** run the new `/fcu test` and copy its native report. In `/fcu playground`, manually replace Decoration with Transparent / blank, change Bar fill and select Label fonts. Confirm native TGA transparency, UV behavior, real asset availability, glyph/locale coverage and continued bar/control behavior. With a real LSM provider, select registered assets; separately restart without any provider and test fallback. The explicit built-ins-only test does not simulate uninstalling a provider or deleting its files.
3. **Geometry:** inspect and translate SiblingAnchor and TwoAnchors; verify spacing, scaling, anchor details, undo and reload. Test unrelated eligible Blizzard panels and known managed panels. Confirm managed Edit Mode/Blizzard layout is left alone and cosmetics still work. Unmarked layout managers may exist; absence of recognized metadata is not proof of exclusive ownership.
4. **Native permissions:** verify combat/context transitions, inaccessible values, forbidden layout, protected permission checks and posthook taint behavior. Denied geometry must remain blocked with no repeated setters/action-blocked errors. Fixture mocks cannot establish native security correctness.
5. **Persistence/enforcement:** repeat ordinary Blizzard refreshes, load-on-demand rebinding, reload persistence, periodic behavior, property/entry disable, delete, Pause All + reload and Resume against this build. The successful 0.1.0 report does not substitute for checking regressions in 0.2.0.

## Assumptions from the supplied export

See [SOURCE_NOTES.md](SOURCE_NOTES.md). The export declares movement/user-placement/resizability flags separately from protected SetPoint/SetSize permissions; removing those flags as proxies is a reasoned interpretation, not native proof. GetPoint/SetPoint support ScriptRegion relatives and multiple anchors. Updating existing named points and translating offsets is explicitly modeled offline, but native replacement semantics and UI-scale/layout effects must be verified. Manager metadata establishes known involvement; some ancestry blocks deliberately remain conservative. All hard native gates remain active. Coordinated multi-anchor writes are not an atomic native transaction.

Known unsupported/policy-blocked cases include secret/unreadable anchors, anonymous relative identities, more than eight anchors, changed relationships pending recapture, multi-anchor size, unready Edit Mode registry, and known/suspected managed ancestry. These are reported as their actual category, not all described as WoW API denials.
