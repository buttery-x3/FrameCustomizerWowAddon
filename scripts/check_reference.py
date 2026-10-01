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
    method("SimpleScriptRegionResizingAPIDocumentation", "GetNumPoints", 'Type = "number"')
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
        "Blizzard_APIDocumentationGenerated/ForbiddenAspectConstantsDocumentation.lua": ['Name = "UntrustedLayoutScriptExecution"', "Propagates to any children of this object, and anything anchored to to this object"],
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

    # Audit the exact observational policy evidence, not just manager names.
    templates = source("Blizzard_EditMode/Shared/EditModeSystemTemplates.lua")

    def implementation(owner, name, *fragments):
        global checks
        start = templates.index(f"function {owner}:{name}(")
        end = templates.find("\nfunction ", start + 1)
        body = templates[start:end if end != -1 else len(templates)]
        for fragment in fragments:
            assert fragment in body, (owner, name, fragment)
        checks += 1

    implementation("EditModeSystemMixin", "OnSystemLoad", "RegisterSystemFrame(self)")
    implementation("EditModeSystemMixin", "OnDragStart", "self:CanBeMoved()", "self:StartMoving()")
    implementation("EditModeSystemMixin", "CanBeMoved", "self.isSelected and not self.isLocked")
    implementation("EditModeSystemMixin", "HasSetting", "self.settingMap[setting] ~= nil")
    implementation("EditModeSystemMixin", "ApplySystemAnchor", "self:SetPoint(self.systemInfo.anchorInfo.point")
    for axis in ("Width", "Height"):
        implementation("EditModeChatFrameSystemMixin", "UpdateSystemSetting" + axis,
                       f"self:HasSetting(Enum.EditModeChatFrameSetting.{axis}Hundreds)",
                       f"self:HasSetting(Enum.EditModeChatFrameSetting.{axis}TensAndOnes)", "self:SetSize(")
        implementation("EditModeDamageMeterSystemMixin", "UpdateSystemSettingFrame" + axis,
                       f"self:GetSettingValue(Enum.EditModeDamageMeterSetting.Frame{axis})", "self:SetSize(")
        implementation("EditModeSwingTimerSystemMixin", "UpdateSystemSetting" + axis,
                       f"self:Set{axis}(self:GetSettingValue(Enum.EditModeSwingTimerSetting.{axis}))")
    implementation("EditModeStatusTrackingBarSystemMixin", "UpdateSystemSetting",
                   "self:HasSetting(Enum.EditModeStatusTrackingBarSetting.Size)", "self:SetSize(")
    # Counterexamples: a 'size' label or unit-frame width setting alone is NOT
    # evidence of a same-object native SetSize control.
    implementation("EditModeUnitFrameSystemMixin", "UpdateSystemSettingFrameSize", "self:SetScale(")
    implementation("EditModeUnitFrameSystemMixin", "UpdateSystemSettingFrameWidth", "self:UpdateCompactRaidFrameContainerSetting(")
print(f"REFERENCE PASS: {checks} declaration/shared-source contracts; ZIP read-only; no exported Lua executed")
print("SHA256 " + hashlib.sha256(args.zip.read_bytes()).hexdigest())

