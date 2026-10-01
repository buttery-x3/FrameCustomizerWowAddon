# Test results — 2026-10-01

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
