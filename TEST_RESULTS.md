# Test results — 2026-09-30

**FrameCustomizer 0.1.0 / first-build-1** is implemented and packaged. **47 offline scenarios passed: 30 production-core scenarios and 17 adapter/bootstrap/editor contract scenarios.** The addon has **not been launched in the user's WoW client**. The native `/fcu test` report must still be run there by the user.

## Executed commands and outcomes

Working directory: `D:\dev\FrameCustomizerWowAddon`. Commands used the Python 3.14 installation exposed by `py`; the default `python` command was a Windows Store alias and was not used for checks. Standalone `lua`/`luac` were not installed; Lupa's actual Lua 5.1 runtime supplied compilation/execution.

| Exact command | Result |
| --- | --- |
| `py -3.14 -m venv .tools/venv` | PASS — isolated development environment created |
| `& '.tools/venv/Scripts/python.exe' -m pip install lupa==2.6` | PASS — pinned Lupa 2.6 installed, no runtime dependency added to the addon |
| `& '.tools/venv/Scripts/python.exe' scripts/check.py` | PASS — production Lua syntax, TOC, core and strict native-contract harness; final suite also rerun by package command below |
| `& '.tools/venv/Scripts/python.exe' scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'` | PASS — 48 declaration/shared-source contracts; ZIP read-only; no exported Lua executed |
| `& '.tools/venv/Scripts/python.exe' scripts/package.py` | PASS — final 30/30 core + 17/17 native-contract scenarios, then exact ZIP member/content validation |
| `& './scripts/test-deploy.ps1'` | PASS — WhatIf, fresh install, refusal without Update, backup update, unrelated-addon rejection, sibling addon and WTF sentinels unchanged |
| `Get-FileHash -LiteralPath 'D:\Games\World of Warcraft\_classic_beta_\BlizzardInterfaceCode.zip' -Algorithm SHA256` | PASS — fingerprint matches the independently read source-audit hash recorded in SOURCE_NOTES |

Final package: **`dist/FrameCustomizer-0.1.0.zip`**, **30,187 bytes**, **12 files**, exactly one top-level `FrameCustomizer/` folder.

SHA-256: `563d993ffb98667bf2efbe452abdcf4d93ba077b4f03abb6c13094ed41e04c56` (also in `dist/FrameCustomizer-0.1.0.zip.sha256`).

Ten addon Lua files compile with Lua 5.1 `loadstring`; every TOC source reference exists, is unique, and exactly matches the runtime Lua file set. The addon ships no XML, so there are no addon XML references to validate. The native-only `UIPanelScrollFrameTemplate` is present in the supplied source, but its rendering is untested. The ZIP contains only the TOC, ten Lua modules and the addon licence. All byte contents match the source files. No Blizzard export, docs, tests, cache, Python interpreter or third-party library is bundled.

The deployment test operated only inside a newly generated `.tools/deployment-test-*` tree and made a recoverable backup under ignored `dist/deploy-backups/`. **No files were deployed to the game installation, and no actual account settings were accessed or changed.**

## What was tested

Production core:

- Versioned validation/round trips; independent malformed entries/properties; unknown schema preservation; interval/number validation; inaccessible fake data excluded from saved output.
- Delayed targets; differently named nested fixtures; verified parent keys; ambiguous aliases and changed object types failing closed; anonymous objects rejected; identity surviving appearance changes.
- Selected-property isolation; all nine actual property definitions executing; existing status-bar fill changed without owning bar values.
- Normal hooked correction, deduplication, ignored self-writes, missed-notification recovery and permission-independent constant writes without reading an inaccessible baseline.
- Object and property periodic strategy overrides; interval bounds; bounded/fair scheduler progress over 100 rules; intended periodic writes not counted as failures.
- Denied and permitted sides of guards, deferred vs permanent denials, missing getters/setters, actual error backoff/suspension and guard cleanup after errors.
- Repeated enable/disable cycles; rebinding and fresh baseline; old callbacks becoming inactive; Pause All, entry disable, property disable and delete stopping queued/periodic/hooked work.
- Read-free diagnostics; best-effort undo; conflict validation and duplicate enabled targets prevented from racing.

Strict native adapter / UI call recorder:

- Full TOC loading in order, ADDON_LOADED and login initialization, slash recovery, persistent independent safe-mode flag.
- Access/forbidden/required-check guards, secret-aspect preflight, inaccessible return discarded, inaccessible object type rejected as persistent identity, texture-specific permissions and atlas validation.
- Operation-level protected/layout checks, geometry permitted on eligible fixtures and a recorded user-placed frame, Edit Mode geometry ownership without blocking cosmetics.
- Actual production editor construction; browsing/refreshing without target setters; rule/value/strategy controls; lazy discovery; exact paths; built-in media; picker key flow; copyable report setup.
- Runtime fixture scenario orchestration twice; cleanup and hook count stable on repeat; cancellation on combat entry.

The recorder's offline PASS results for the fixture sequence validate **orchestration only**. They are not native fixture results and are not presented as evidence of native secrets, security, taint, layout or rendering. Unknown fake methods fail. The test environment contains explicit narrow contracts, not a permissive whole-client simulator.

## Corrections made during verification/review

- Equality helper now short-circuits identical references/numbers before recursive comparison (initial test caught a stack overflow on cyclic fixture objects).
- Inspector anchors align corresponding edges; initial scaling fits the available UIParent area. This is code-level layout review, not native visual QA.
- Source-backed scale/shown secret-aspect checks and unreadable object-type identity rejection were added.
- Discovery performs costly per-object eligibility checks in 16-reference slices after bounded native enumeration.
- Safe pause has its own persisted flag, independent of database-schema compatibility.
- Duplicate target entries are paused on load; explicitly reenabling conflicting duplicates cannot create competing writes.
- Native fixture objects and installed posthooks are reused across repeated test runs; late textures are first allocated in their delayed/rebinding steps.

## Not run / still required in the actual client

- Native WoW addon load, template/font/asset rendering, minimum-size/UI-scale behaviour and keyboard picker interaction.
- The actual `/fcu test` command and its user-copyable PASS/FAIL/SKIPPED report. It runs only when explicitly requested in game and modifies only its isolated addon-owned fixtures.
- Editing unrelated Blizzard objects; ordinary refresh behaviour; late Blizzard addon loading and reload persistence against real UI objects.
- Native secret values and inaccessible tables, taint, protected restrictions, combat transitions and native hook safety. Offline sentinels are deliberately not claimed to simulate these perfectly.
- File/TOC recognition across client restart vs `/reload`, performance on a large live UI, and actual LibSharedMedia installed-library integration. Built-in media fallback is offline tested.

Known intentionally unavailable cases: unverified anonymous/pool identities; unknown/managed/Edit Mode geometry; root/editor infrastructure; inaccessible or forbidden operations; unsupported object types; logical parent hiding; arbitrary scripts; gameplay triggers; shared Font mutation. The first build supports only a single parent-relative geometry anchor and does not normalize texture UVs. It does not promise universal hook coverage, exact baseline restoration or flicker-free rendering.

Start with `/fcu`, `/fcu test`, and `/fcu report`. Use `/fcu pause` for recovery. Follow the five-step real-UI checklist in [README.md](README.md); deployment and module boundaries are in [DEVELOPMENT.md](DEVELOPMENT.md).
