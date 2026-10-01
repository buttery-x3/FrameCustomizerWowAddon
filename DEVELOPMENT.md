# Development

## Layout

| Module | Responsibility |
| --- | --- |
| `FrameCustomizer/Core/Util.lua` | Small data helpers and injected value-access predicate |
| `Core/Anchors.lua` | Validated anchor snapshots, stable relative identities, relationship checks and translation without clearing complex layouts |
| `Core/Properties.lua` | Explicit applicability, reads, validation, coordinated writes, signals and repeatability for nine properties |
| `Core/Schema.lua` | Version 1 validation, bounded rules, declarative round trips |
| `Core/Resolver.lua` | Verified global/parent-key identity and type revalidation |
| `Core/Engine.lua` | Shared scheduler, hook subscriptions, verification, periodic writes, backoff, baseline undo, read-free diagnostics |
| `Native/Adapter.lua` | WoW permissions, explicit read/write methods, assets and safe inspection |
| `Native/Discovery.lua` | Lazy hierarchy, bounded search exploration and reference processing |
| `UI/Editor.lua` | Reusable hierarchy rows, inspector, picker, assets and copyable reports |
| `Native/Playground.lua` | Opt-in editable fixtures and isolated native scenario engine |
| `Bootstrap.lua` | SavedVariables, independent slash recovery, one update driver and lifecycle notifications |
| `tests/` | Narrow fake adapter and strict native-API/UI call recorder; not a WoW emulator |
| `scripts/` | Offline checks, read-only source audit, packaging and non-destructive deployment |

Only the `FrameCustomizer/` folder ships. `.reference/`, `.tools/` and `dist/` are ignored. This is an existing Git repository. Follow [AGENTS.md](AGENTS.md): completed repository changes must be validated, committed, pushed to GitHub and merged into `main`, then local `main` synchronized. A local package or unmerged branch alone is not completed delivery.

## Offline commands (PowerShell, workspace root)

```powershell
py -3.14 -m venv .tools/venv
& .tools/venv/Scripts/python.exe -m pip install -r scripts/requirements-dev.txt
& .tools/venv/Scripts/python.exe scripts/check.py
& .tools/venv/Scripts/python.exe scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'
& .tools/venv/Scripts/python.exe scripts/package.py
& ./scripts/test-deploy.ps1
```

Python is tooling only. Lupa **2.6**, specifically `lupa.lua51`, runs the exact production core in **Lua 5.1** (`_VERSION` and `LUA_VERSION` verified). It also compiles every shipped Lua source, validates the TOC manifest, loads all files in TOC order, and exercises the native adapter/editor against an explicit call recorder. Unknown fake calls fail. Neither the export nor a second enforcement implementation is executed. `package.py` runs checks before creating a deterministic allowlisted ZIP and SHA-256 file; it compares every ZIP member to source. The `X-FrameCustomizer-Assets` TOC metadata is the shared asset manifest for checks, packaging and deployment. The transparent TGA is addon-owned; tests validate its pixels and manifest/path. No test-only files or external libraries are bundled.

The reference audit reads declarations and shared implementations directly from the supplied ZIP. It asserts contracts but cannot certify that a C++ API accepts calls in every native execution context. The maintained LSM API documentation is used only for optional integration; no downloaded library code is copied into the addon.

## Deploy

Pass your chosen client's actual existing AddOns path. No destination is inferred. Examples use a placeholder you must replace:

```powershell
& ./scripts/deploy.ps1 -AddOnsPath 'X:/your-client/Interface/AddOns' -WhatIf
& ./scripts/deploy.ps1 -AddOnsPath 'X:/your-client/Interface/AddOns'
# For an existing recognized FrameCustomizer installation:
& ./scripts/deploy.ps1 -AddOnsPath 'X:/your-client/Interface/AddOns' -Update
```

Updates first copy a backup to `dist/deploy-backups/`. The script writes only allowlisted FrameCustomizer files, preserves extra files, rejects reparse-point paths and unrelated destination addons, and never deletes/moves installed files or touches WTF. Close WoW before changing metadata or adding files. Existing Lua edits can be tested with `/reload`; first installation/new metadata/assets should use a full restart. Runtime reload/file-discovery behaviour still needs confirmation in the supplied client.

## Test/report loop

1. Install this package and open `/fcu`. `/fcu playground` provides a frame hierarchy, texture, font label, status bar, sibling-relative and two-anchor textures, and a working value-change button through the normal editor.
2. `/fcu test` runs only when explicitly requested, outside combat. It uses a separate native adapter and the same production resolver, definitions and engine with fixture-only rules. It tests setters, deferred resets, repeated updates, show/hide, an alternate setter route, a method reference cached before hooks, delayed creation/rebinding, ambiguous alias rejection, transparent texture replacement, status-bar media, optional SharedMedia font selection, explicit built-ins-only fallback, anchor translation, delayed/repeated geometry resets, missed geometry notifications under periodic enforcement, and pause. Geometry uses the ordinary management policy path even on these fixtures; no live Blizzard registry is changed. Media operations report availability/skips; rendering remains manual. The fallback bypasses enumeration for that adapter call and never removes or patches another addon's library. It cancels on combat entry or `/fcu test stop`.
3. Copy the report. Fixtures are hidden, test rules/subscriptions cleared, and pending actions removed at completion/cancellation. Native objects and unremovable hooks are reused across runs; allocations remain bounded. Editor-owned test infrastructure is excluded from normal targets. The separately opened development playground is intentionally editable.
4. Follow the five expanded real-UI acceptance steps in README. If an issue occurs, select the saved entry and use **Report**, or `/fcu report` for up to 24 entries. Copy with Ctrl+A/Ctrl+C. No clipboard or arbitrary file-write API is claimed.

Diagnostic reports contain version/revision, runtime build, selected stable target paths, validated configured values/strategies, state/reason, saved anchor relationships and counters. `/fcu report` adds read-only library detection/counts and cached native/access, representation, product-policy and management findings with stable reason codes. The geometry inspector adds an Eligibility report for its most recent preflight; manager advisories persist beside enforcement states. These reports do not read live property values. The explicitly opened editor Anchor details panel separately reads only accessible anchor data. Reporting is limited to once per 2 seconds; unexpected errors go to the normal Lua error handler at most once per 5 seconds. No error-handler replacement or suppression of unrelated errors is installed.

## Implementation boundaries / assumptions to confirm

- Native permission predicates and secret-aspect reporting must behave as declared for ordinary addon code on build 70124. Missing checks deny the affected operation; protected cosmetics are not indiscriminately blocked.
- Verify that permitted `hooksecurefunc(object, name, callback)` calls do not introduce unexpected taint. The source Dispatcher confirms table-member hooks and unremovable hooks; it does not promise interception of cached/native/animation paths.
- Native rendering, DPI/UI scale, the supplied scroll template, keyboard picker, asset existence and locale font coverage need actual client inspection. The recorder has no renderer.
- Geometry separates native gates, manager inspection and representation compatibility. Movement/user-placement/resizability flags are not permission or ownership proof and are no longer eligibility gates. Panel metadata, shared-layout hints and Edit Mode ancestry produce scoped observations, never blanket vetoes. Missing optional metadata is unknown and does not block. Direct Edit Mode policy requires supported property-specific evidence: movement-handler identity for position, or a same-object dimension handler plus active settings for Size. Unclassified controls are reported without guessing. No per-panel exceptions or reset hooks exist. See SOURCE_NOTES for source contracts and classification limits.
- Position extends schema 1 additively with optional sorted `anchors` records. Records contain point, relativePoint, a parent/UIParent role or verified resolver descriptor, and spacing relative to the primary anchor. No native object is persisted. Old parent-anchor values remain valid. Only a single legacy parent-anchor point change requires/uses ClearAllPoints. The whole anchor plan is resolved before mutation; anticipated execution-time denials defer via a private structured result, without error backoff. Genuine unexpected setter failures still count as errors. Multiple-anchor updates use existing SetPoint names and recheck native permission per setter; coordinated calls are not a native transaction. Size on more than one anchor stays explicitly unsupported.
- Discovery stores `label`, `kind` and full `path` separately. Search computes ancestry inclusion and a transient expansion map without touching normal expansion flags. Scan updates the same node graph; undiscovered branches are not implied to have been searched.
- Media lists are enumerated on picker open/refresh, not cached at startup. External library errors produce bounded status text and built-in fallback, never raw external values/errors in diagnostics. Stored values remain resolved file paths, not LSM keys. The 8x8 transparent TGA still needs native decode/render verification.
- A saved target path identifies the named widget/parent slot, not displayed gameplay content. Anonymous or unverified pool objects remain read-only. Every write resolves again, rechecks type and current permissions, and rebinding discards the old session baseline.
- Eligibility adds an optional fourth `canWrite` return containing independent findings; existing resolver/property/enforcement responsibilities and saved schema stay intact. Engine diagnostics format cached findings only. Each scan is bounded to 256 Edit Mode registrations and the existing 12-level ancestry limit.
- One scheduler ticks no faster than 0.05s, checks at most 24 jobs and processes at most 12 jobs per tick. Up to 128 rules are allowed. A job is its own deduplicated pending record; callbacks only mark it dirty. A property job may coordinate several native setters. Hook count caps at 1024 per engine, after which readable verification and periodic enforcement remain available.

See [SOURCE_NOTES.md](SOURCE_NOTES.md) for the exact input fingerprint and source contracts, and [TEST_RESULTS.md](TEST_RESULTS.md) for executed checks versus untested native behaviour.
