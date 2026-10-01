"""Audit explicit API contracts against the user's ZIP without executing it."""
import argparse
import hashlib
import re
from pathlib import Path
from zipfile import ZipFile

parser = argparse.ArgumentParser()
parser.add_argument("--zip", type=Path, required=True)
args = parser.parse_args()
prefix = "BlizzardInterfaceCode/Interface/AddOns/"
checks = 0
with ZipFile(args.zip) as archive:
    def source(name):
        return archive.read(prefix + name).decode("utf-8-sig")

    def method(file, name, *fragments):
        global checks
        text = source("Blizzard_APIDocumentationGenerated/" + file + ".lua")
        blocks = re.split(r"\n\t\t\{\n", text)
        block = next((s for s in blocks if s.startswith(f'\t\t\tName = "{name}"')), None)
        assert block, f"{file}.{name} missing"
        for fragment in fragments:
            assert fragment in block, f"{file}.{name}: missing contract {fragment}"
        checks += 1

    method("SimpleFrameScriptObjectAPIDocumentation", "CanBeAccessedInContext", "ObjectSecurity")
    method("SimpleFrameScriptObjectAPIDocumentation", "IsForbidden", "ObjectSecurity")
    method("SimpleFrameScriptObjectAPIDocumentation", "HasSecretAspect", "ObjectSecrets")
    method("SimpleFrameScriptObjectAPIDocumentation", "HasAnyForbiddenAspects", "ForbiddenAspect")
    method("RestrictedActionsDocumentation", "CheckAllowProtectedFunctions", 'Name = "silent"', "SecureHooksAllowed = false")
    for name in ("canaccessvalue", "canaccesstable", "issecretvalue"):
        method("FrameScriptDocumentation", name, "SecureHooksAllowed = false")
    for name in ("GetParent", "GetParentKey", "GetDebugName", "SetParentKey"):
        method("SimpleObjectAPIDocumentation", name)
    method("SimpleRegionAPIDocumentation", "SetAlpha", 'SecretArguments = "AllowedWhenTainted"')
    method("SimpleRegionAPIDocumentation", "GetAlpha", "SecretReturnsForAspect")
    method("SimpleRegionAPIDocumentation", "SetVertexColor", 'Name = "colorR"', 'Name = "a"')
    method("SimpleRegionAPIDocumentation", "GetEffectiveScale", "SecretAspect.Scale")
    method("SimpleTextureBaseAPIDocumentation", "SetTexture", 'Name = "textureAsset"', 'Name = "success"')
    method("SimpleTextureBaseAPIDocumentation", "SetAtlas", 'Name = "useAtlasSize"', 'Default = false')
    method("SimpleTextureBaseAPIDocumentation", "SetColorTexture", "ForbiddenAspect.SetTexture")
    method("TextureUtilsDocumentation", "GetAtlasInfo", "MayReturnNothing = true")
    method("SimpleFontStringAPIDocumentation", "SetFont", "RequiresValidFontAsset", 'Name = "fontHeight"', 'Name = "flags"')
    method("SimpleFontStringAPIDocumentation", "SetTextColor", 'Name = "a"')
    method("SimpleFontStringAPIDocumentation", "SetWordWrap", 'Name = "wrap"')
    method("SimpleStatusBarAPIDocumentation", "GetStatusBarTexture", 'Type = "SimpleTexture"')
    method("SimpleStatusBarAPIDocumentation", "SetStatusBarTexture", "CheckAllowChangeParent = true")
    method("SimpleStatusBarAPIDocumentation", "SetStatusBarColor", 'Name = "a"')
    for name in ("SetSize", "SetPoint", "ClearAllPoints"):
        method("SimpleScriptRegionResizingAPIDocumentation", name, "IsProtectedFunction = true")
    method("SimpleScriptRegionResizingAPIDocumentation", "GetPoint", "SecretWhenAnchoringSecret = true")
    method("SimpleScriptRegionResizingAPIDocumentation", "SetPoint", "CheckAllowInheritForbiddenLayoutAspects = true", 'Type = "ScriptRegion"')
    for name in ("ClearPoint", "AdjustPointsOffset", "SetPointsOffset", "ClearPointsOffset"):
        method("SimpleScriptRegionResizingAPIDocumentation", name, "IsProtectedFunction = true")
    method("SimpleScriptRegionAPIDocumentation", "IsAnchoringRestricted")
    method("SimpleScriptRegionAPIDocumentation", "IsAnchoringSecret")
    method("InputDocumentation", "GetMouseFoci", 'Type = "table"')
    for name in ("GetChildren", "GetRegions", "GetNumChildren", "GetNumRegions"):
        method("SimpleFrameAPIDocumentation", name, "SecretAspect.Hierarchy")
    for name in ("IsUserPlaced", "IsMovable", "IsResizable", "SetResizeBounds"):
        method("SimpleFrameAPIDocumentation", name)
    method("SimpleFrameAPIDocumentation", "GetAttribute", "SecretReturnsForAspect", "SecretAspect.Attributes")
    method("SimpleFrameAPIDocumentation", "SetUserPlaced", 'Name = "userPlaced"')
    method("SimpleFrameAPIDocumentation", "StartMoving", "IsProtectedFunction = true")
    for file, fragments in {
        "Blizzard_SharedXML/UI.xsd": ['name="parentKey"', 'name="StatusBar"', 'name="FontString"'],
        "Blizzard_SharedXML/SecureScrollTemplates.xml": ['name="UIPanelScrollFrameTemplate"'],
        "Blizzard_EditMode/Shared/EditModeManager.lua": ["registeredSystemFrames", "RegisterSystemFrame", "GetActiveLayoutInfo"],
        "Blizzard_EditMode/Shared/EditModeSystemTemplates.lua": ["RegisterSystemFrame(self)", "systemInfo.anchorInfo"],
        "Blizzard_SharedXML/LayoutFrame.lua": ["IsLayoutFrame", "layoutIndex", "ignoreInLayout"],
        "Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua": ['UIPanelWindows[frame:GetName()]', 'UIPanelLayout-defined', 'centerFrameSkipAnchoring'],
        "Blizzard_SharedXMLBase/Pools.lua": ["function ObjectPoolBaseMixin:Acquire()", "function ObjectPoolBaseMixin:Release("],
        "Blizzard_Dispatcher/Blizzard_Dispatcher.lua": ["hooksecurefunc(functionOwner, functionName", "securehooks can not be removed"],
        "Blizzard_ChatFrameBase/Shared/SlashCommands.lua": ["ReloadUI();"],
    }.items():
        text = source(file)
        for fragment in fragments:
            assert fragment in text, (file, fragment)
        checks += 1
print(f"REFERENCE PASS: {checks} declaration/shared-source contracts; ZIP read-only; no exported Lua executed")
print("SHA256 " + hashlib.sha256(args.zip.read_bytes()).hexdigest())

