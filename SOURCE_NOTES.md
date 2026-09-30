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
| `SimpleFrameAPIDocumentation.lua` | Children/regions with hierarchy secrecy; opacity; user placement/movability/resizability; editor resize bounds |
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
| `Blizzard_SharedXML/LayoutFrame.lua` | Shared layout markers and managed child layout; conservatively deny unknown geometry ownership |
| `Blizzard_SharedXMLBase/Pools.lua` | Acquire/release can reuse/reset objects; unique anonymous appearance is not stable identity |
| `Blizzard_Dispatcher/Blizzard_Dispatcher.lua` | `hooksecurefunc(functionOwner, functionName, callback)` and unremovable posthook lifecycle |
| `Blizzard_ChatFrameBase/Shared/SlashCommands.lua` | `/reload` invokes `ReloadUI`; this does not establish TOC discovery or asset caching behaviour |

Public secondary reference: [maintainer's LibSharedMedia-3.0 API documentation](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation), for optional `List(mediatype)` and `Fetch(mediatype, key, true)`. No library is bundled, so there is no external-code licence or revision to embed. Built-in asset paths are available without LSM.

The source audit script checks these declarations as text. Existence of declarations is **not** a claim of unrestricted native access. Live permission guards and the outstanding client acceptance checks are required.
