# Source contracts

Primary input: `D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip` (8,736,708 bytes).

SHA-256: `190d4544587a0aade6b67c6eaba4ba8bd9500e46b261a4cfa3c7553d8c27e2fd`.

Target metadata **supplied by the user**: version 1.60.1, build 70124, build date September 29, 2026, interface 16001. The ZIP is read-only reference material; it was extracted only into ignored `.reference/` for inspection. It is neither executed nor packaged. No substitute retail/Classic branch was used.

Paths below are relative to `BlizzardInterfaceCode/Interface/AddOns/` in that ZIP. Generated declarations are under `Blizzard_APIDocumentationGenerated/`.

| Source | Contract used |
| --- | --- |
| `SimpleFrameScriptObjectAPIDocumentation.lua` | `CanBeAccessedInContext`, `IsForbidden`, `HasSecretAspect`, `HasAnyForbiddenAspects`; guard return values can themselves be inaccessible |
| `FrameScriptDocumentation.lua` | `canaccessvalue`, `canaccesstable`, `issecretvalue`; never hook these or treat pcall as permission |
| `RestrictedActionsDocumentation.lua` | `C_RestrictedActions.CheckAllowProtectedFunctions(object, true)`; restriction-state event occurs before activation/after deactivation, so it only schedules later work |
| `ForbiddenAspectConstantsDocumentation.lua` | Per-operation SetTexture, ScriptBindings and layout restrictions |
| `SimpleObjectAPIDocumentation.lua` | `GetParent`, `GetParentKey`, `GetName` via script-object API; verify actual global table/parent slot equality; debug names only label |
| `SimpleFrameAPIDocumentation.lua` | Children/regions with hierarchy secrecy; opacity; separate placement/movability/resizability flags; secret Attributes getter; editor resize bounds |
| `SimpleRegionAPIDocumentation.lua` | Alpha, vertex colour and scale secrecy; constant cosmetic setters have separate permission from readable state |
| `SimpleTextureBaseAPIDocumentation.lua` | `SetTexture(asset, ...)`, `SetAtlas(atlas, useAtlasSize, ...)`, GetAtlas/GetTexture; SetColorTexture mutation signal; texture aspect gate |
| `SimpleFontStringAPIDocumentation.lua` | `SetFont(fontFile, fontHeight, flags)` and text colour; valid font/height requirements; edit FontString rather than shared Font |
| `SimpleStatusBarAPIDocumentation.lua` | Fill getter returns a Texture; bar colour. `SetStatusBarTexture` includes parent-change checking, so the editor changes the existing accessible fill's texture instead |
| `SimpleScriptRegionResizingAPIDocumentation.lua` | ClearAllPoints/SetPoint/SetSize are protected operations; SetPoint has forbidden-layout inheritance checks; GetPoint/GetSize can be secret |
| `SimpleScriptRegionAPIDocumentation.lua` | Anchoring restriction/secrecy checks, protected frame visibility distinction |
| `InputDocumentation.lua`, `TextureUtilsDocumentation.lua`, `BuildDocumentation.lua` | Mouse foci return a table; atlas existence query; runtime client/build/interface tuple |
| `Blizzard_SharedXML/UI.xsd` | Distinct Frame, Texture, FontString and StatusBar types; `parentKey` vs nonpersistent child-array indices |
| `Blizzard_SharedXML/SecureScrollTemplates.xml` | `UIPanelScrollFrameTemplate` used only by the addon-owned copyable report |
| `Blizzard_EditMode/Shared/EditModeManager.lua`, `EditModeSystemTemplates.lua` | Registered system frames and anchor ownership; query registration data, never invoke system update/reset methods |
| `Blizzard_SharedXML/LayoutFrame.lua` | Shared layout markers and managed child layout; observational evidence of another writer, not operation permission |
| `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua` | `UIPanelWindows[frame:GetName()]`, `UIPanelLayout-defined` and generic manager anchoring; read metadata only, never invoke manager/reset methods |
| `Blizzard_SharedXMLBase/Pools.lua` | Acquire/release can reuse/reset objects; unique anonymous appearance is not stable identity |
| `Blizzard_Dispatcher/Blizzard_Dispatcher.lua` | `hooksecurefunc(functionOwner, functionName, callback)` and unremovable posthook lifecycle |
| `Blizzard_ChatFrameBase/Shared/SlashCommands.lua` | `/reload` invokes `ReloadUI`; this does not establish TOC discovery or asset caching behaviour |

Public secondary reference: [maintainer's LibSharedMedia-3.0 API documentation](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation), for optional `List(mediatype)` and `Fetch(mediatype, key, true)`. No library is bundled, so there is no external-code licence or revision to embed. Built-in asset paths are available without LSM.

The source audit script checks these declarations as text. Existence of declarations is **not** a claim of unrestricted native access. Live permission guards and the outstanding client acceptance checks are required.

## Visual editor and fixed-layer correction (0.4.1)

The audit checks **94 contracts** against the same supplied ZIP and fingerprint. It adds Boolean `HasFixedFrameStrata`/`HasFixedFrameLevel` declarations, `SetMovable`, protected `StopMovingOrSizing` and `SetClampedToScreen`, and the exact fixed-level setter ordering below. The existing `StartMoving` protected declaration remains audited.

`Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua`, `TalentFrameBaseMixin:SetElementFrameLevel` (lines 816–821), explicitly calls `SetFixedFrameLevel(false)`, `SetFrameLevel(frameLevel)`, then `SetFixedFrameLevel(true)`. This is the source basis for temporarily unlocking our own hosts around layer writes instead of assuming fixed setters always take effect. `Blizzard_UnitFrame/Shared/PlayerFrame.lua` also sets casting-bar strata before setting its fixed-strata flag. These are generic operation examples, not production frame-name exceptions. Applying the same unlock/set/relock lifecycle to our strata flag is an implementation inference; generated declarations do not establish all native fixed-flag semantics.

Every unlock, layer write and relock checks native object access and protected permission independently. A denied relock is retried during owned-host configuration, including when the desired layer already matches. Returned layer and lock values pass normal access checks; FrameLevel secrecy is retained. Actual layer readback is required before a created visual becomes ready. This prevents a silent setter refusal from being reported as active, but it does not prove rendered overlap order. Ordinary existing-object edits never clear fixed flags. Title-bar movement only affects the addon editor, with protected permission checks before StartMoving/StopMovingOrSizing and clamping.

The user's initial 0.4.0 test reported immovable visual editing and strata apparently being ignored. It did not establish the selected layer relationship or isolate native fixed-flag behaviour. The fixes cover both the write sequence and the previously ambiguous manual controls in behind mode. Native rendering, actual drag behaviour, combat/taint transitions and overlap ordering still require client retesting.

## Created visuals and layering contracts (0.4.0)

The read-only audit now checks **88 contracts** against the same supplied ZIP and fingerprint. Additional declarations:

- `SimpleFrameAPIDocumentation.lua`: SetFrameStrata, SetFrameLevel, SetFixedFrameStrata, SetFixedFrameLevel, Show and Hide are protected operations. GetFrameLevel has the FrameLevel secret aspect; GetFrameStrata returns FrameStrata. CreateTexture accepts a draw layer and returns SimpleTexture, with secret arguments disallowed.
- `SimpleScriptRegionAPIDocumentation.lua`: EnableMouse is protected. Both this file and SimpleFrame declare IsVisible with the Shown secret aspect. Frame Show/Hide use the stricter Frame declarations, not the unprotected ScriptRegion declarations.
- `SimpleRegionAPIDocumentation.lua`: GetDrawLayer returns layer/sublayer; SetDrawLayer accepts layer/sublevel, defaulting sublevel to zero.

The production adapter rechecks native object access and `CheckAllowProtectedFunctions(object, true)` before each protected layer, host visibility and host-setup setter. Visibility/level reads check their secret aspects and returned values. Created SetPoint/ClearAllPoints/SetSize calls retain the existing per-setter geometry guards, including relative forbidden-layout checks for SetPoint. Registered-system policy is assessed on the object being changed, not transferred from its anchor target.

Hosts use ordinary `CreateFrame("Frame", nil, UIParent)` as already used by the editor, plus one CreateTexture. No Blizzard template or native target parenting is used. The export does not supply a generated declaration for the global CreateFrame; the similarly named C_PingSecure function is unrelated and is not used as evidence. Creation is limited to accessible UIParent with no forbidden layout aspect, and setup/access predicates are checked on the returned host. Native acceptance of creation in each client context remains unverified.

The eight supported strata, level range 0..10000 and sublevel range -8..7 are explicit addon representation limits, not a claim that this export enumerates every native numeric limit. Behind mode means the readable target frame's strata at level minus one; level zero or unrepresentable data produces an explicit reason. This arithmetic is a rendering assumption requiring native validation, particularly at mixed strata, overlapping siblings and restricted hierarchies. It does not promise ordering behind an individual region within the same native frame.

Direct anchors are expected to follow target bounds; fixed dimensions, offsets and padding are in the host's UIParent coordinate units. Native scaling, inherited forbidden aspects, parent-hidden transitions and clipping need inspection. Visibility is sampled from an accessible container instead of inherited from the target; target alpha and scrolling clips are not copied. Successful declaration audits or offline API recording do not establish those behaviours, native taint safety or immediate cleanup under denied permissions.

## Geometry interpretation and remaining assumptions (0.3.0)

The expanded read-only ZIP audit verifies 74 contracts against the same fingerprint above. SetPoint accepts a ScriptRegion relative and the object exposes multiple GetPoint anchors; the declaration does not limit relatives to the parent. ClearPoint, AdjustPointsOffset, SetPointsOffset and ClearPointsOffset are additional protected setter signals. GetAttribute uses the Attributes secret aspect. Editor SetWordWrap exists in this export.

IsMovable, IsUserPlaced and IsResizable are declared as separate Boolean getters. The export does not describe them as SetPoint/SetSize permission predicates or guarantees of layout ownership. Removing those proxy gates is an inference from the separate native operation contracts, **not proof that every unflagged panel can safely be moved**. FrameCustomizer does not change any of these flags. CheckAllowProtectedFunctions(object, true), anchoring secrecy/restriction and forbidden-layout inheritance remain authoritative native gates, rechecked before setters.

For readable anchor sets, the implementation assumes updating an existing named SetPoint replaces that point and that translating all offsets by the same amount preserves relative spacing in the target's UI units. The recorder explicitly models this; only the live client can confirm scale/layout behavior. Stable relative identities are re-resolved and relationship changes block writes. Complex layouts are never cleared. Size remains unsupported for more than one anchor because SetSize may be constrained by those anchors.

Version 0.3.0 replaces the 0.2.0 blanket manager veto. `UIPanelWindows`, `UIPanelLayout-defined`, `IsLayoutFrame`, `systemInfo`, `system`, `layoutIndex`, `Layout` and `SetFixedFrameStrata` are scoped observations only. A parent match is ancestor context, not selected-property ownership. Secret Attributes are checked before GetAttribute; inaccessible optional fields/registrations produce unknown observations without reading/comparing their contents. Missing `layoutInfo`/`overrideLayoutInfo` no longer gates geometry. The registry scan is bounded and does not invoke manager functions. A registry with no match does not prove there are no other writers.

Concrete Edit Mode evidence from `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua` and `EditModeManager.lua` in the supplied ZIP:

- `EditModeManagerFrameMixin:RegisterSystemFrame` (manager lines 224–226) inserts the actual system object into `registeredSystemFrames`. `EditModeSystemMixin:OnSystemLoad` (templates lines 3–29) registers self. Matching a registry name on an ancestor does not transfer this relationship to a descendant.
- `EditModeSystemMixin:OnDragStart` (891–901) calls `CanBeMoved` and `StartMoving` on self; `CanBeMoved` (878–880) uses temporary selection/lock state. `ApplySystemAnchor` (350–383) applies `systemInfo.anchorInfo` to self. FrameCustomizer observes direct registration and equality with the exported `OnDragStart` function, without calling it. This identifies an exposed position control and triggers **product policy**, not native denial. Transient selection/lock state is not used as a native permission check.
- `HasSetting` (455–468) consults `settingMap`. For a directly registered target, dimension policy requires accessible active setting records and function identity matching a supported source handler that changes **self's** dimensions. These contracts are audited explicitly: ChatFrame `UpdateSystemSettingWidth/Height` (2160–2192, paired Hundreds/TensAndOnes settings); DamageMeter `UpdateSystemSettingFrameWidth/Height` (3582–3589); SwingTimer `UpdateSystemSettingWidth/Height` (2715–2722); StatusTrackingBar `UpdateSystemSetting` (2551–2566, Size setting). The production table contains mixin/function/enum contracts, never global frame names or eligibility exceptions. An observed width or height control excludes the combined width/height override.
- Counterexamples matter: unit-frame `UpdateSystemSettingFrameSize` (1547–1558) calls SetScale; unit-frame width/height (1468–1483) update compact child/container settings. Their names are not proof of a selected object's SetSize control. Scale is not an implemented FrameCustomizer property.
- Classification is intentionally explicit and incomplete. Replaced/wrapped handlers, unavailable mixins/settings, global-target update helpers (for example the ObjectiveTracker height route), and custom internal size methods (including the PersonalResourceDisplay one-argument SetSize route) remain **unclassified**, with advisory/unknown evidence. No target identity or equivalence to native width/height is guessed. Additional classifications require source evidence of the same object/property, not a named-frame exemption. This limitation needs native inspection; it is not a claim that Edit Mode exposes no other controls.

Native operation assumptions remain separate. `SimpleScriptRegionResizingAPIDocumentation.lua` declares ClearAllPoints, SetPoint and SetSize as protected; only SetPoint declares `CheckAllowInheritForbiddenLayoutAspects`. `ForbiddenAspectConstantsDocumentation.lua` documents UntrustedLayoutScriptExecution as affecting layout scripts (including OnSizeChanged) and propagating through children/anchors. The existing guarded target/parent layout checks remain, and SetPoint checks each relative. A missing required Boolean/access predicate still denies execution. IsAnchoringRestricted/IsAnchoringSecret are readable only when their returned values are accessible; preserved anchors are never read around secrecy. These preflights are an interpretation of the declarations, not a substitute for final native acceptance.

The writer retains the same native restrictions and removes only the broad management rejection. ClearAllPoints is now mandatory only for an actual single-parent point-name change; preserved named-point updates do not require or call it. A coordinated update resolves the complete plan before any setter, rechecks native access and product policy at each primitive setter, and defers expected permission/topology changes without operation-error backoff. There is no native transaction or rollback guarantee if context changes between setters.

Media enumeration continues to use the maintainer's public List/Fetch contract, including noDefault=true. LibStub detection uses its normal GetLibrary method (and supports a function-form provider). No supplied source or first live-test observation proves a particular library was loaded. New diagnostics establish that at runtime. The addon-owned TGA has a verified on-disk format and path; native decoding, alpha behavior, file discovery and locale font coverage remain unverified for this build.
