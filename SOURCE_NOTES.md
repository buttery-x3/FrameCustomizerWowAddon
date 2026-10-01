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
| `Blizzard_SharedXML/LayoutFrame.lua` | Shared layout markers and managed child layout; identify shared layout metadata, with conservative blocks for suspected layout ownership |
| `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua` | `UIPanelWindows[frame:GetName()]`, `UIPanelLayout-defined` and generic manager anchoring; read metadata only, never invoke manager/reset methods |
| `Blizzard_SharedXMLBase/Pools.lua` | Acquire/release can reuse/reset objects; unique anonymous appearance is not stable identity |
| `Blizzard_Dispatcher/Blizzard_Dispatcher.lua` | `hooksecurefunc(functionOwner, functionName, callback)` and unremovable posthook lifecycle |
| `Blizzard_ChatFrameBase/Shared/SlashCommands.lua` | `/reload` invokes `ReloadUI`; this does not establish TOC discovery or asset caching behaviour |

Public secondary reference: [maintainer's LibSharedMedia-3.0 API documentation](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation), for optional `List(mediatype)` and `Fetch(mediatype, key, true)`. No library is bundled, so there is no external-code licence or revision to embed. Built-in asset paths are available without LSM.

The source audit script checks these declarations as text. Existence of declarations is **not** a claim of unrestricted native access. Live permission guards and the outstanding client acceptance checks are required.

## 0.2.0 interpretation and remaining assumptions

The expanded read-only ZIP audit verifies 58 contracts against the same fingerprint above. SetPoint accepts a ScriptRegion relative and the object exposes multiple GetPoint anchors; the declaration does not limit relatives to the parent. ClearPoint, AdjustPointsOffset, SetPointsOffset and ClearPointsOffset are additional protected setter signals. GetAttribute uses the Attributes secret aspect. Editor SetWordWrap exists in this export.

IsMovable, IsUserPlaced and IsResizable are declared as separate Boolean getters. The export does not describe them as SetPoint/SetSize permission predicates or guarantees of layout ownership. Removing those proxy gates is an inference from the separate native operation contracts, **not proof that every unflagged panel can safely be moved**. FrameCustomizer does not change any of these flags. CheckAllowProtectedFunctions(object, true), anchoring secrecy/restriction and forbidden-layout inheritance remain authoritative native gates, rechecked before setters.

For readable anchor sets, the implementation assumes updating an existing named SetPoint replaces that point and that translating all offsets by the same amount preserves relative spacing in the target's UI units. The recorder explicitly models this; only the live client can confirm scale/layout behavior. Stable relative identities are re-resolved and relationship changes block writes. Complex layouts are never cleared. Size remains unsupported for more than one anchor because SetSize may be constrained by those anchors.

Edit Mode registration, shared layout markers and panel metadata identify known manager involvement; the addon conservatively blocks geometry on their ancestry without calling manager methods. Even panel registrations with possible skip-anchoring exceptions are left with the manager. A missing/unready Edit Mode registry is explicitly a FrameCustomizer safety decision. An accessible registry with no recognized manager is now eligible, but custom/unrecognized layout writers may still exist. Cosmetics are independent.

Media enumeration continues to use the maintainer's public List/Fetch contract, including noDefault=true. LibStub detection uses its normal GetLibrary method (and supports a function-form provider). No supplied source or first live-test observation proves a particular library was loaded. New diagnostics establish that at runtime. The addon-owned TGA has a verified on-disk format and path; native decoding, alpha behavior, file discovery and locale font coverage remain unverified for this build.
