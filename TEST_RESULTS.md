# Test results

## Visual editor and layer fixes — 2026-10-04

**FrameCustomizer 0.4.1 / visual-editor-layer-fix** addresses the user's initial 0.4.0 client report: the visual editor could not be moved, strata appeared ineffective, and the dismissal button said Cancel. The editor now has a clamped title-bar drag region, retains session placement across Save/reopen, and uses **Close**. Editing strata or frame level selects manual layering so behind mode cannot silently replace those edits.

Owned panel layer writes now unlock, set, and relock with a fresh native permission check at every step. A denied relock is retried even if the layer value already matches. Configuration requires readable matching strata/level before reporting readiness; silent refusal or inaccessible readback remains visible as a pending/inaccessible status. Existing-object fixed flags and saved schema are unchanged.

| Validation | Result |
| --- | --- |
| `scripts/check.py` | PASS: 114 offline scenarios (30 core, 17 native-contract, 24 regression, 18 geometry-policy, 25 visual), including five new regression scenarios. All fourteen shipped Lua modules compile under Lua 5.1. |
| `scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'` | PASS: 94 contracts; original ZIP SHA-256 unchanged. Includes fixed-flag getters, movement/clamping methods, and Blizzard's unlock/set/relock frame-level ordering. |
| `scripts/package.py` | PASS: final full suite, manifest, archive integrity and every member compared with source; 17 allowlisted files. |
| Deployment tests | Not rerun: packaging/deployment logic and the file manifest are unchanged. No game deployment performed. |
| `git diff --check` | PASS. |

Package: `dist/FrameCustomizer-0.4.1.zip`, 54,476 bytes. SHA-256: `a9963c300830ac42d05a25802263b31334eda42c4c8ae484194e47d7d0d81c55`, also recorded in the adjacent `.sha256` file. No real game installation or account data was modified.

New regression coverage includes explicit layer changes on fixed hosts, engine-only correction after missed notifications, target-relative behind changes, denials before a setter and before relocking, lock restoration after an injected error, ignored setters, secret layer readback, guarded title dragging/stopping, Close without saving, retained editor position, and automatic manual selection without changing saved behind mode during form loading. The recorder's fixed-setter refusal is an opt-in fault model, not native WoW emulation.

**Client retesting remains required:** drag the editor off an obscured visual, save/reopen and confirm position; close with unsaved edits; change manual strata/level and inspect overlapping frames; switch back to behind and verify target-relative ordering. Repeat at the user's UI scale and across combat/restriction changes. The reported strata failure did not establish whether behind mode or fixed flags caused that particular observation. Offline checks and the source pattern do not establish actual rendering, taint safety or native drag behaviour.

## Created visuals and layering — 2026-10-04

**FrameCustomizer 0.4.0 / created-visuals-1** is implemented and packaged. **109 offline scenarios pass: 30 core, 17 native-contract, 24 explorer/media/geometry, 18 geometry-policy, and 20 created-visual scenarios.** All fourteen shipped Lua modules compile under Lua 5.1 and match the TOC manifest. Earlier client observations about existing edits remain useful, but **none of this release's new behaviour has been executed in the WoW client during this task**.

Delivered: independent and selected-target Add visual entry points using the same form; solid/file/atlas panels and media selection; fixed or fill sizing with padding; explicit visibility containers; manual and behind-target layering; all/attached visual lists with rename/duplicate/disable/delete; schema 1 to 2 migration; registered component identities; bounded allocation/reuse/retirement; shared property enforcement; frame strata/level and region draw layer/sublevel controls on existing supported objects.

| Validation | Result |
| --- | --- |
| `scripts/check.py` | PASS during development; final suite also executed by packaging. Existing 89 scenarios retained and 20 focused scenarios added. |
| `scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'` | PASS, 88 source contracts; same SHA-256 `190d4544587a0aade6b67c6eaba4ba8bd9500e46b261a4cfa3c7553d8c27e2fd`. No alternate client export used. |
| `scripts/package.py` | PASS, deterministic archive with one addon root and 17 allowlisted files; every member compared with local source. |
| `scripts/test-deploy.ps1` | PASS, including new module copies, backups, preservation and all existing path/config cases. Only isolated `.tools/deployment-test-a60f648f6def4f848fc26fab1922eda6` fixtures and ignored backup outputs used. |
| `git diff --check` | PASS. |

Package: `dist/FrameCustomizer-0.4.0.zip`, 53,627 bytes. SHA-256: `5dcdf19b173135036da02a42a4b92ca897a8a2b6ec795bc985816112104ce5a4`, also recorded in the adjacent `.sha256` file. No real game installation or account data was modified.

The new scenarios exercise schema migration and malformed-data preservation, monotonic identities, round trips, creation defaults/cancellation, fixed/fill attachment changes, independent placement, existing Edit Mode targets used only as relatives, visibility containers, secret visibility/levels, target disappearance and replacement, permission denial and per-setter checks, deferred deletion, pause/resume, duplicate identities, pooled reuse/hook bounds, allocation/work limits, read-free diagnostics, and partial creation denial/errors without allocation escape. Deliberately injected errors are checked and consumed only by their owning test.

The opt-in `/fcu test` now includes independent panel creation, status-bar-bound attachment, container visibility, explicit dimensions and pause retirement. It retains/reuses the fixture controller and engine across runs, continues pending retirement after cancellation, and exposes skips/denials in its copyable report. Its orchestration passes offline; this is **not an executed native run**.

Still required in client: actual editor layout and text readability, media decoding, full health-bar bounds while its fill changes, the plain quest-window background with working controls, independent action-bar backdrops, behind ordering with overlapping frames, DPI/UI scale, clipping boundaries, alpha behaviour, late loading, reload migration, combat/secret transitions, taint and cleanup under restricted access. Panels do not inherit target alpha or clipping. Visibility uses bounded 0.2s-minimum samples; layout/appearance checks use a 2s minimum, so transitions and contention can delay updates. Behind mode blocks at target level zero instead of guessing another strata. Source declarations and recorder success do not establish native rendering or safety.

## Geometry policy — 2026-10-01

**FrameCustomizer 0.3.0 / geometry-policy-1** is implemented and packaged. **89 offline scenarios pass: 30 core + 17 native-contract + 24 explorer/media/geometry regressions + 18 geometry-policy scenarios.** The old blanket management-denial assertions were intentionally replaced. Native/access/secret, identity, anchor representation, persistence, explorer, media and cosmetic enforcement regressions remain.

The user's 0.1.0 client report confirmed loading, real-object discovery, player artwork/portrait opacity, combat survival, reload persistence, Pause All + reload recovery and Resume. That evidence is retained. **Neither the 0.2.0 changes nor this 0.3.0 pass have been tested in the WoW client.** Recorder success does not establish native taint safety, rendered appearance, or compatibility with real managed panels.

## Executed validation

Working directory: `D:\dev\FrameCustomizerWowAddon`; existing `.tools/venv` Python 3.14/Lupa 2.6. No addon runtime dependency was added.

| Command | Result |
| --- | --- |
| `& .tools/venv/Scripts/python.exe scripts/check.py` | PASS during implementation. Final identical check was run by packaging: 89 scenarios, eleven shipped Lua modules compiled in Lua 5.1, exact TOC manifest and transparent TGA validation. |
| `& .tools/venv/Scripts/python.exe scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'` | PASS: 74 declaration/shared-source contracts. Original fingerprint unchanged; ZIP read only, no Blizzard Lua executed or packaged. New assertions cover concrete Edit Mode movement/dimension handlers and scale/child-layout counterexamples. |
| `& .tools/venv/Scripts/python.exe scripts/package.py` | PASS: all 89 scenarios, deterministic allowlisted ZIP, one addon root, integrity and every member compared with source. |
| `& ./scripts/test-deploy.ps1` | PASS: WhatIf, fresh install, refusal without Update, backup update, unrelated-addon rejection, sibling-addon/WTF sentinels and transparent texture preserved. |
| `git diff --check` | PASS after normalizing documentation line endings. |

Installable package: **`dist/FrameCustomizer-0.3.0.zip`**, **42,033 bytes**, **14 allowlisted files** (TOC, eleven Lua modules, licence, transparent texture).

SHA-256: `98ae75b8cd3e65409a5948c7b157e17bf7e5e56b92b1a0fa14e5cc2913e99a0b`, also recorded in `dist/FrameCustomizer-0.3.0.zip.sha256`.

Deployment tests used only `.tools/deployment-test-9e2140cbf9444c069a3bf252772a3c7f` and a recoverable backup under ignored `dist/deploy-backups/`. No game installation, live registry, or actual account settings were modified.

## Policy decisions exercised through production modules

| Case, with native/access and representation checks passing | Previous policy | Delivered policy |
| --- | --- | --- |
| Ordinary registered UI-panel target | Manager veto in eligibility and writer | Scoped advisory; editor commit reaches the setter, verification and session undo |
| Descendant of an Edit Mode system | Ancestor veto | Local position/size eligible; ancestor evidence reported separately |
| Direct system's exposed Edit Mode position | Broad geometry veto | Explicit position product policy: use Edit Mode; independent cosmetics/size assessed separately |
| Shared layout/heuristic markers | Manager/safety veto | Observations and persistent advisory; no arbitrary layout methods called |
| Optional missing/secret management data | Conservative veto | Unknown observation; required checks still decide the operation |
| Exposed same-object Edit Mode dimensions | Broad registration veto | Direct registration, supported handler identity and active dimension settings required for Size policy |

These rows describe policy/logic tests, not verified native panel behavior. Existing enabled rules blocked only by the obsolete policy may start applying on upgrade. Disabled entries/properties, per-property strategies, schema 1 data and global pause state are retained without migration.

The eighteen new scenarios use ordinary targets, without fixture-policy exemptions. They exercise editor enable/commit, scheduling, actual adapter setters, readable verification, cached diagnostic reports and supported session undo. Coverage includes direct/ancestor matching, verified or absent observation identities, optional secret attributes skipped before calling GetAttribute, missing registry readiness, property-specific Edit Mode controls, and independent native/representation failures alongside warnings.

Normal posthooks correct delayed/repeated offset resets; missed notifications recover through readable verification and separately through opted-in periodic application. Multiple-anchor translation preserves relationships without ClearAllPoints or drift. Self-writes do not recurse, jobs remain bounded, and pause/entry-disable/property-disable/delete stop queued geometry. Reports retain advisories after matched checks and expected execution-time denials without live reads.

Required denial and execution-time permission changes make zero prohibited calls and do not accrue operation-error backoff. A simulated denial after one allowed anchor setter stops the next setter and recovers later: coordinated native calls are not atomic. Unresolved relatives are detected before any mutation; changed counts/relationships, inaccessible anchors, missing mandatory checks/setters and multi-anchor size retain stable, distinct reason codes. Genuine operation failures still follow the existing error/backoff behavior.

The opt-in `/fcu test` suite now includes delayed/repeated geometry resets and missed geometry notifications under periodic enforcement, using the same production path and addon-owned objects. It neither mutates Blizzard registries nor certifies real manager compatibility. Offline orchestration, cleanup, repeated-run hook bounds and combat cancellation pass. The unchanged tree/filtering, media, schema and cosmetic suites also pass.

## Small client check still required

1. Install 0.3.0 and confirm its version in `/fcu report`; fully restart if upgrading from 0.1.0. Inspect an affected target's **Eligibility report**: native/access, representation, policy and scoped observations should explain the decision. Run `/fcu test` outside combat if desired and retain its native PASS/FAIL/SKIPPED report.
2. Enable a permitted position/size edit, reopen or refresh the panel, and compare normal enforcement with optional periodic mode. Verify actual offsets/size, multi-anchor relationships, rendering/scale, interactions and any flicker. QuestFrame, WorldMapFrame and PlayerFrame are manual examples only, never production exceptions.
3. Confirm the direct system's exposed Edit Mode position remains a product-policy exclusion, while a permitted descendant can edit local geometry. Inspect unclassified dimension controls rather than assuming every size/scale/internal setting has been mapped. Supported handler evidence and unresolved classifications are documented in [SOURCE_NOTES.md](SOURCE_NOTES.md).
4. Check denied combat/context transitions produce no prohibited writes/action-blocked errors; then confirm pause + reload recovery, resume, saved disabled flags and session undo on a supported target. Repeat relevant media/explorer checks if upgrading from 0.1.0.

Any blocker should be reported by its stable code and evidence: native/access denial/unavailability, anchor representation, direct Edit Mode policy, unresolved target/relative, or advisory/unknown management. Client restrictions, hook taint, same-object Edit Mode classification and lasting appearance remain unverified. No global enforcement cadence was changed and flicker-free rendering is not promised.

## Deployment configuration follow-up — 2026-10-01

The development deployment script now reads the literal `FRAMECUSTOMIZER_ADDONS_PATH` setting from repository-root `.env` when `-AddOnsPath` is omitted. `.env` is Git-ignored; `.env.example` documents the setting without a local installation path. Explicit `-AddOnsPath` takes precedence. Existing destination validation, WhatIf, Update/backup and unrelated-addon protections still apply.

`& ./scripts/test-deploy.ps1` passes both the original deployment checks and isolated config scenarios: missing/empty settings, duplicate assignments, unmatched quotes, nonexistent/wrong destination, unquoted/single-quoted/double-quoted paths, literal spaces/brackets/#/$(), invocation from another directory, relative configured paths, explicit override, fresh install, update backup and unrelated-addon refusal. Configuration is read as data and left unchanged. Fixtures are under `.tools/deployment-test-a7580aed3a1d49e1b86f5a0fac50c67e`; no game deployment occurred. `git diff --check` passes and `git check-ignore -v .env` confirms the ignore rule.

This follow-up changes development tooling/documentation only. Addon source and its 0.3.0 package are unchanged; the Lua suite, source-reference audit and packaging were not unnecessarily rerun.
