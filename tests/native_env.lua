-- A strict call recorder for adapter contracts and bootstrap/UI construction.
-- It does not simulate WoW security, secret values, taint, layout or rendering.
local _,FC=...
local N={time=0,frames={},errors={},messages={},hooks=0,combat=false}
FC.TestNative=N
N.inaccessible={testOnly="inaccessible sentinel, NOT a native secret"}
N.inaccessibleTable={testOnly="inaccessible table sentinel"}
function canaccessvalue(v) return v~=N.inaccessible end
function issecretvalue(v) return v==N.inaccessible end
function canaccesstable(v) return v~=N.inaccessibleTable end
Enum={SecretAspect={},ForbiddenAspect={}}
for _,key in ipairs({"Alpha","VertexColor","Hierarchy","ObjectName","ObjectType","Scale","Shown","Attributes","FrameLevel"}) do Enum.SecretAspect[key]=key end
for _,key in ipairs({"SetTexture","ScriptBindings","UntrustedLayoutScriptExecution"}) do Enum.ForbiddenAspect[key]=key end
C_RestrictedActions={CheckAllowProtectedFunctions=function(o,silent) assert(silent==true); return o.protectedAllowed~=false end}
C_Texture={GetAtlasInfo=function(name) if name=="KnownAtlas" then return {width=16,height=16} end end}
function GetTime() return N.time end
function InCombatLockdown() return N.combat end
function GetBuildInfo() return "1.60.1","70124","Sep 29 2026",16001 end
function geterrorhandler() return function(err) N.errors[#N.errors+1]=err end end
function GetMouseFoci() return N.foci or {} end
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) N.messages[#N.messages+1]=s end}
SlashCmdList={}
local M={}
local function changed(o,key) o.calls[key]=(o.calls[key] or 0)+1 end
function M:IsForbidden() return self.forbidden==true end
function M:CanBeAccessedInContext() return self.access~=false end
function M:HasSecretAspect(aspect) assert(aspect); return self.secretAspects[aspect]==true end
function M:HasAnyForbiddenAspects(aspect) assert(aspect); return self.forbiddenAspects[aspect]==true end
function M:GetName() return self.name end
function M:GetObjectType() return self.kind end
function M:GetParent() return self.parent end
function M:GetParentKey() return self.parentKey end
function M:GetAttribute(key) assert(not self.secretAspects.Attributes,"Optional secret attributes must not be read"); return self.attributes and self.attributes[key] end
function M:GetDebugName() return self.name or self.parentKey or "anonymous label" end
function M:GetAlpha()
    assert(not self.secretAspects.Alpha,"A getter was invoked despite inaccessible aspect")
    changed(self,"GetAlpha")
    if self.returnSecretAlpha then return N.inaccessible end
    return self.alpha
end
function M:SetAlpha(a) changed(self,"SetAlpha"); self.alpha=a end
function M:GetAtlas() return self.atlas end
function M:GetTexture() return self.texture end
function M:SetTexture(v) changed(self,"SetTexture"); self.texture=v; self.atlas=""; return true end
function M:SetAtlas(v,useSize) assert(useSize==false); changed(self,"SetAtlas"); self.atlas=v end
function M:SetColorTexture(r,g,b,a) self.texture="colour"; self.color={r,g,b,a or 1} end
function M:SetVertexColor(r,g,b,a) changed(self,"SetVertexColor"); self.color={r,g,b,a or 1}; self.alpha=a or 1 end
function M:GetVertexColor() return unpack(self.color) end
function M:SetTextColor(...) changed(self,"SetTextColor"); self.color={...} end
function M:GetTextColor() return unpack(self.color) end
function M:SetFont(f,s,x) changed(self,"SetFont"); self.font={f,s,x or ""}; return true end
function M:GetFont() return unpack(self.font) end
function M:SetText(s) self.text=tostring(s or ""); if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function M:GetText() return self.text or "" end
function M:SetSize(w,h) changed(self,"SetSize"); self.width=w; self.height=h; if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end end
function M:GetSize() return self.width,self.height end
function M:SetWidth(w) self.width=w end
function M:SetHeight(h) self.height=h end
function M:GetWidth() return self.width end
function M:GetHeight() return self.height end
function M:ClearAllPoints() changed(self,"ClearAllPoints"); self.points={} end
function M:SetPoint(...)
    changed(self,"SetPoint"); local args={...}
    for i,p in ipairs(self.points) do if p[1]==args[1] then self.points[i]=args; return end end
    self.points[#self.points+1]=args
end
function M:GetNumPoints() return #self.points end
function M:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function M:SetAllPoints(o) self.points={{"TOPLEFT",o or self.parent,"TOPLEFT",0,0},{"BOTTOMRIGHT",o or self.parent,"BOTTOMRIGHT",0,0}} end
function M:GetRect() return 100,100,self.width,self.height end
function M:SetScale(s) self.scale=s end
function M:GetEffectiveScale() return self.scale end
function M:IsAnchoringRestricted() return self.anchorRestricted==true end
function M:IsAnchoringSecret() return self.anchorSecret==true end
function M:IsUserPlaced() return self.userPlaced==true end
function M:IsMovable() return self.movable==true end
function M:IsResizable() return self.resizable==true end
function M:SetMovable(v) self.movable=v end
function M:SetResizable(v) self.resizable=v end
function M:SetParentKey(key,clear)
    if clear and self.parentKey then self.parent[self.parentKey]=nil end
    self.parentKey=key; self.parent[key]=self
end
function M:GetNumChildren() return #self.children end
function M:GetNumRegions() return #self.regions end
function M:GetChildren() return unpack(self.children) end
function M:GetRegions() return unpack(self.regions) end
function M:SetScript(name,f) assert(type(f)=="function" or f==nil); self.scripts[name]=f end
function M:RegisterEvent(name) self.events[name]=true end
function M:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function M:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function M:IsShown() return self.shown end
function M:IsVisible()
    assert(not self.secretAspects.Shown,"Secret visibility must not be read")
    return self.shown and (not self.parent or self.parent:IsVisible())
end
function M:SetFrameStrata(s)
    changed(self,"SetFrameStrata")
    if not (self.ignoreFixedLayerWrites and self.fixedStrata) then self.strata=s end
end
function M:GetFrameStrata() return self.strata or "MEDIUM" end
function M:SetFrameLevel(n)
    changed(self,"SetFrameLevel")
    if not (self.ignoreFixedLayerWrites and self.fixedLevel) then self.level=n end
end
function M:GetFrameLevel() assert(not self.secretAspects.FrameLevel,"Secret level must not be read"); return self.level or 1 end
function M:SetFixedFrameStrata(v) self.fixedStrata=v end
function M:SetFixedFrameLevel(v) self.fixedLevel=v end
function M:HasFixedFrameStrata() return self.fixedStrata==true end
function M:HasFixedFrameLevel() return self.fixedLevel==true end
function M:SetDrawLayer(l,s) changed(self,"SetDrawLayer"); self.layer=l; self.sublevel=s end
function M:GetDrawLayer() return self.layer or "ARTWORK",self.sublevel or 0 end
function M:SetChecked(on) self.checked=on end
function M:GetChecked() return self.checked or false end
function M:SetCheckedTexture(t) self.checkedTexture=t end
function M:SetScrollChild(o) self.scrollChild=o end
function M:SetStatusBarTexture(path)
    changed(self,"SetStatusBarTexture")
    if not self.fill then self.fill=self:CreateTexture(nil,"ARTWORK") end
    self.fill:SetTexture(path); return true
end
function M:SetStatusBarAtlas(name) self.fill:SetAtlas(name,false) end
function M:GetStatusBarTexture() return self.fill end
function M:SetStatusBarColor(...) changed(self,"SetStatusBarColor"); self.color={...} end
function M:GetStatusBarColor() return unpack(self.color) end
function M:SetMinMaxValues(lo,hi) self.min=lo; self.max=hi end
function M:SetValue(v) self.value=v end
function M:GetValue() return self.value end
function M:GetNumLines() local _,n=self:GetText():gsub("\n",""); return n+1 end
-- Explicitly accepted editor-only presentation calls. Unknown method names
-- return nil and therefore fail when called; no catch-all successful stub.
for _,key in ipairs({"EnableMouse","SetJustifyH","SetJustifyV","SetAutoFocus","SetMaxLetters",
    "SetTextInsets","ClearFocus","SetFocus","HighlightText","EnableMouseWheel","RegisterForDrag","SetResizeBounds",
    "EnableKeyboard","SetPropagateKeyboardInput","StartMoving","StopMovingOrSizing","SetClampedToScreen","StartSizing","SetMultiLine","SetWordWrap"}) do
    M[key]=function(o,...) o.presentation[key]={...} end
end
local function object(kind,name,parent)
    local o=setmetatable({kind=kind,name=name,parent=parent,children={},regions={},scripts={},events={},calls={},presentation={},
        secretAspects={},forbiddenAspects={},alpha=1,color={1,1,1,1},font={"Fonts\\FRIZQT__.TTF",14,""},texture="",atlas="",width=100,height=30,scale=1,shown=true,points={}}, {__index=M})
    if name then _G[name]=o end
    if parent then local list=(kind=="Texture" or kind=="FontString") and parent.regions or parent.children; list[#list+1]=o end
    N.frames[#N.frames+1]=o
    return o
end
function CreateFrame(kind,name,parent,template)
    assert(({Frame=true,Button=true,CheckButton=true,EditBox=true,ScrollFrame=true,StatusBar=true})[kind],"Unknown fake frame type")
    assert(template==nil or template=="UIPanelScrollFrameTemplate","Unknown fake template")
    return object(kind,name,parent)
end
function M:CreateTexture(name,layer) assert(type(layer)=="string"); return object("Texture",name,self) end
function M:CreateFontString(name,layer) assert(type(layer)=="string"); return object("FontString",name,self) end
function hooksecurefunc(o,key,callback)
    assert(type(o[key])=="function","Missing method in posthook")
    local original=o[key]
    -- Test harness only: models a posthook that saved method references bypass.
    -- The production addon never replaces target methods.
    o[key]=function(...)
        local result={original(...)}; callback(...); return unpack(result)
    end
    N.hooks=N.hooks+1
end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetSize(1920,1080)
WorldFrame=CreateFrame("Frame","WorldFrame")
function N.event(name,...)
    local copy={}; for _,f in ipairs(N.frames) do copy[#copy+1]=f end
    for _,f in ipairs(copy) do if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name,...) end end
end
function N.advance(seconds)
    for _=1,math.ceil(seconds/0.05) do
        N.time=N.time+0.05
        local copy={}; for _,f in ipairs(N.frames) do copy[#copy+1]=f end
        for _,f in ipairs(copy) do if f.scripts.OnUpdate and f.shown then f.scripts.OnUpdate(f,0.05) end end
    end
end


-- Metadata identities only; never execute exported Blizzard implementations.
EditModeSystemMixin={OnDragStart=function() error("Do not invoke Edit Mode during inspection") end}
