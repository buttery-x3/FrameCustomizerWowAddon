local _, FC = ...
local U=FC.Util
local A={}; A.__index=A
FC.NativeAdapter=A
local unpack=unpack
local function safe(v)
    if type(canaccessvalue)~="function" or type(issecretvalue)~="function" or type(canaccesstable)~="function" then return false end
    if not canaccessvalue(v) or issecretvalue(v) then return false end
    return type(v)~="table" or canaccesstable(v)
end
U.access=safe
local function method(o,key)
    if not safe(o) or type(o)~="table" then return nil end
    local f=o[key]
    if safe(f) and type(f)=="function" then return f end
end
local function boolCall(o,key)
    local f=method(o,key); if not f then return nil end
    local value=f(o)
    if not safe(value) then return nil,"inaccessible" end
    if type(value)=="boolean" then return value end
end
local aspects={GetAlpha={"Alpha"},GetVertexColor={"VertexColor","Alpha"},GetTextColor={"VertexColor","Alpha"},
    GetStatusBarColor={"VertexColor","Alpha"},GetName={"ObjectName"},GetObjectType={"ObjectType"},
    GetParent={"Hierarchy"},GetNumChildren={"Hierarchy"},GetNumRegions={"Hierarchy"},GetChildren={"Hierarchy"},GetRegions={"Hierarchy"},
    GetEffectiveScale={"Scale"},IsShown={"Shown"},GetAttribute={"Attributes"}}
local readable={GetAlpha=true,GetAtlas=true,GetTexture=true,GetVertexColor=true,GetTextColor=true,GetFont=true,
    GetStatusBarColor=true,GetStatusBarTexture=true,GetSize=true,GetNumPoints=true,GetPoint=true,GetParent=true,
    GetName=true,GetObjectType=true,GetParentKey=true,GetDebugName=true,GetNumChildren=true,GetNumRegions=true,
    GetAttribute=true,GetRect=true,GetEffectiveScale=true,IsShown=true,IsUserPlaced=true,IsMovable=true,IsResizable=true}
local geometryRead={GetSize=true,GetPoint=true,GetRect=true,GetEffectiveScale=true}
local writable={SetAlpha=true,SetTexture=true,SetAtlas=true,SetVertexColor=true,SetFont=true,SetTextColor=true,
    SetStatusBarColor=true,SetSize=true,ClearAllPoints=true,SetPoint=true}
function A.new()
    return setmetatable({owned=setmetatable({},{__mode="k"}),fixtures=setmetatable({},{__mode="k"}),lastError=-100},A)
end
function A:now() return GetTime() end
function A:inspectable(o)
    if not safe(o) or type(o)~="table" then return false,"blocked: object value inaccessible" end
    if boolCall(o,"IsForbidden")~=false then return false,"blocked: forbidden / missing IsForbidden check" end
    if boolCall(o,"CanBeAccessedInContext")~=true then return false,"blocked: current context cannot access object" end
    return true
end
function A:aspectReadable(o,list)
    local f=method(o,"HasSecretAspect")
    if #list>0 and (not f or not Enum or not Enum.SecretAspect) then return false end
    for _,name in ipairs(list) do
        local aspect=Enum.SecretAspect[name]; if aspect==nil then return false end
        local value=f(o,aspect)
        if not safe(value) or value~=false then return false end
    end
    return true
end
function A:noForbidden(o,name)
    local f=method(o,"HasAnyForbiddenAspects")
    local aspect=Enum and Enum.ForbiddenAspect and Enum.ForbiddenAspect[name]
    if not f or not aspect then return false end
    local v=f(o,aspect)
    return safe(v) and v==false
end
function A:read(o,key,...)
    if not readable[key] or not self:inspectable(o) or not self:aspectReadable(o,aspects[key] or {}) then return false end
    if geometryRead[key] and boolCall(o,"IsAnchoringSecret")~=false then return false end
    local f=method(o,key); if not f then return false end
    local function collect(...) return {n=select("#",...),...} end
    local values=collect(f(o,...))
    for i=1,values.n do if not safe(values[i]) then return false end end
    return true,unpack(values,1,values.n)
end
function A:kind(o) local ok,v=self:read(o,"GetObjectType"); if ok and U.identifier(v) then return v end end
function A:name(o) local ok,v=self:read(o,"GetName"); if ok and U.identifier(v) then return v end end
function A:parent(o) local ok,v=self:read(o,"GetParent"); if ok and v and self:inspectable(v) then return v end end
function A:parentKey(o) local ok,v=self:read(o,"GetParentKey"); if ok and U.identifier(v) then return v end end
function A:global(name)
    if not U.identifier(name) then return nil,"ambiguous: invalid global name" end
    local o=rawget(_G,name)
    if not safe(o) then return nil,"blocked: global inaccessible" end
    if o==nil then return nil,"unresolved: global not created" end
    local ok,reason=self:inspectable(o); if not ok then return nil,reason end
    if self:name(o)~=name then return nil,"ambiguous: global does not verify its name" end
    return o
end
function A:keyChild(parent,key)
    if not self:inspectable(parent) then return nil,"blocked: parent inaccessible" end
    local o=rawget(parent,key)
    if not safe(o) then return nil,"blocked: parent key inaccessible" end
    if o==nil then return nil,"unresolved: parent key not created" end
    if not self:inspectable(o) then return nil,"blocked: child inaccessible" end
    if self:parent(o)~=parent or self:parentKey(o)~=key then return nil,"ambiguous: parent/key relationship no longer verified" end
    return o
end
function A:excluded(o)
    if o==UIParent or o==WorldFrame then return true end
    for _=0,FC.LIMITS.depth do
        if not o then return false end
        if not self:inspectable(o) then return true end
        if self.fixtures[o] then return false end
        if self.owned[o] then return true end
        if o==UIParent then return false end
        o=self:parent(o)
    end
    return true
end
function A:isFixture(o)
    for _=0,FC.LIMITS.depth do
        if not o or not self:inspectable(o) then return false end
        if self.fixtures[o] then return true end
        if o==UIParent then return false end
        o=self:parent(o)
    end
    return false
end
function A:barRegion(o)
    local ok,t=self:read(o,"GetStatusBarTexture")
    if ok and t and self:inspectable(t) and self:kind(t)=="Texture" then return t end
end
-- Native gates, known managers, and representation policy are separate. None
-- of the movement/persistence flags establishes permission for SetPoint/SetSize.
function A:geometryNative(o,relative)
    local accessible,reason=self:inspectable(o)
    if not accessible then return false,reason,true,"object_access","inaccessible" end
    for _,key in ipairs({"IsAnchoringRestricted","IsAnchoringSecret"}) do
        local v,unavailable=boolCall(o,key)
        if unavailable then return false,"Inaccessible: native "..key.." result",true,"native_result_inaccessible","inaccessible" end
        if v==nil then return false,"Required check unavailable: "..key,true,"native_check_unavailable","unavailable" end
        if v then return false,(key=="IsAnchoringSecret" and "Inaccessible: secret anchoring" or "Native restriction: anchoring restricted"),true,key=="IsAnchoringSecret" and "anchoring_secret" or "anchoring_restricted",key=="IsAnchoringSecret" and "inaccessible" or "denied" end
    end
    local parent=self:parent(o)
    if not parent then return false,"Inaccessible: geometry requires an accessible parent",true,"parent_inaccessible","inaccessible" end
    for _,object in ipairs({o,parent,relative or parent}) do
        local f=method(object,"HasAnyForbiddenAspects")
        local aspect=Enum and Enum.ForbiddenAspect and Enum.ForbiddenAspect.UntrustedLayoutScriptExecution
        if not self:inspectable(object) or not f or not aspect then return false,"Required check unavailable: forbidden layout permission",true,"layout_check_unavailable","unavailable" end
        local forbidden=f(object,aspect)
        if not safe(forbidden) then return false,"Inaccessible: layout permission result",true,"layout_result_inaccessible","inaccessible" end
        if type(forbidden)~="boolean" then return false,"Required check unavailable: layout permission returned no boolean",true,"layout_result_unavailable","unavailable" end
        if forbidden then return false,"Native restriction: forbidden layout inheritance",true,"layout_forbidden","denied" end
    end
    if not C_RestrictedActions or type(C_RestrictedActions.CheckAllowProtectedFunctions)~="function" then return false,"Required check unavailable: protected-operation permission API",true,"protected_check_unavailable","unavailable" end
    local allowed=C_RestrictedActions.CheckAllowProtectedFunctions(o,true)
    if not safe(allowed) then return false,"Inaccessible: protected-operation permission result",true,"protected_result_inaccessible","inaccessible" end
    if type(allowed)~="boolean" then return false,"Required check unavailable: protected permission returned no boolean",true,"protected_result_unavailable","unavailable" end
    if allowed~=true then return false,"Native restriction: protected operation denied in current context",true,"protected_denied","denied" end
    return true
end
-- Optional observations never establish native permission or inherited policy.
-- Inspect data/function identities only; never call Layout, reset, or Edit Mode
-- methods. A partial scan is unknown, not a reason to deny an unrelated edit.
local function optional(t,key)
    if not safe(t) or type(t)~="table" then return nil,false end
    local v=rawget(t,key)
    if not safe(v) then return nil,false end
    return v,true
end
local function sameMethod(o,mixin,key)
    local source=optional(rawget(_G,mixin),key)
    return type(source)=="function" and method(o,key)==source
end
-- Source-backed contracts, keyed by mixin functions, NOT frame names. These
-- handlers change self's dimensions, unlike scale/child/internal-size settings.
local dimensionControls={
    {"EditModeChatFrameSystemMixin","UpdateSystemSettingWidth","EditModeChatFrameSetting","WidthHundreds","WidthTensAndOnes"},
    {"EditModeChatFrameSystemMixin","UpdateSystemSettingHeight","EditModeChatFrameSetting","HeightHundreds","HeightTensAndOnes"},
    {"EditModeDamageMeterSystemMixin","UpdateSystemSettingFrameWidth","EditModeDamageMeterSetting","FrameWidth"},
    {"EditModeDamageMeterSystemMixin","UpdateSystemSettingFrameHeight","EditModeDamageMeterSetting","FrameHeight"},
    {"EditModeSwingTimerSystemMixin","UpdateSystemSettingWidth","EditModeSwingTimerSetting","Width"},
    {"EditModeSwingTimerSystemMixin","UpdateSystemSettingHeight","EditModeSwingTimerSetting","Height"},
    {"EditModeStatusTrackingBarSystemMixin","UpdateSystemSetting","EditModeStatusTrackingBarSetting","Size"},
}
function A:geometryManagement(o,setting)
    local m={state="none_observed",observations={},scanned=true}
    local policy=U.finding("allowed","no_edit_mode_control_observed","No matching Edit Mode control observed; classification is not exhaustive")
    local unknown,involved=false,false
    local function observe(code,scope,object,detail,isUnknown)
        -- Resolve a real identity or leave it absent; never invent ancestry paths.
        local target=object and FC.Resolver.describe(self,object)
        m.observations[#m.observations+1]={code=code,scope=scope,object=target and U.joinTarget(target) or nil,detail=detail}
        if isUnknown then unknown=true else involved=true end
    end
    local manager=rawget(_G,"EditModeManagerFrame")
    local registry=self:inspectable(manager) and optional(manager,"registeredSystemFrames") or nil
    local registered={}; local unknownEntry=false
    if type(registry)~="table" or #registry>256 then
        observe("edit_mode_registry_unknown","registry",nil,"Edit Mode registration unavailable or beyond inspection bound",true)
    else
        for i=1,#registry do
            local object,ok=optional(registry,i)
            if not ok or not self:inspectable(object) then
                if not unknownEntry then observe("edit_mode_entry_unknown","registry",nil,"An Edit Mode registration is inaccessible",true); unknownEntry=true end
            else registered[object]=true end
        end
    end
    local panels=rawget(_G,"UIPanelWindows")
    if not safe(panels) or type(panels)~="table" then
        panels=nil; observe("panel_registry_unknown","registry",nil,"UI-panel registry unavailable or inaccessible",true)
    end
    local chain=o
    for depth=0,FC.LIMITS.depth do
        if chain==UIParent then break end
        local scope=depth==0 and "target" or "ancestor"
        if not chain or not self:inspectable(chain) then
            observe("ancestry_unknown",scope,nil,"Optional layout ancestry unavailable",true); break
        end
        if registered[chain] then
            observe("edit_mode_registration",scope,chain,"Direct registry match on this object; ancestry alone does not identify the selected property's control")
            if depth==0 then
                if setting=="position" then
                    -- Registration plus the exported generic movement handler
                    -- proves this system exposes position. Selection/lock state
                    -- is temporary and is not an operation permission predicate.
                    if sameMethod(chain,"EditModeSystemMixin","OnDragStart") then
                        policy=U.finding("blocked","edit_mode_position","Use Blizzard Edit Mode for this object's position")
                        observe("edit_mode_position_control",scope,chain,"Property-specific evidence: registered system uses the exported Edit Mode movement handler")
                    else
                        observe("edit_mode_position_unclassified",scope,chain,"Registered system's position control could not be classified",true)
                    end
                else
                    local matched=false
                    local settings=optional(chain,"settingMap")
                    for _,control in ipairs(dimensionControls) do
                        if sameMethod(chain,control[1],control[2]) then
                            local enum=optional(Enum,control[3]); local present=true
                            for i=4,#control do
                                local key=optional(enum,control[i])
                                local entry=key~=nil and optional(settings,key) or nil
                                if type(entry)~="table" then present=false end
                            end
                            if present then matched=true; break end
                        end
                    end
                    if matched then
                        policy=U.finding("blocked","edit_mode_size","Use Blizzard Edit Mode for this object's dimensions (Size writes both width and height)")
                        observe("edit_mode_size_control",scope,chain,"Property-specific evidence: active setting and exported handler for this object's dimensions")
                    else
                        observe("edit_mode_size_unclassified",scope,chain,"No supported same-object dimension control identified; scale and internal/child settings are not SetSize evidence",true)
                    end
                end
            end
        end
        local name=self:name(chain)
        if panels and name then
            local entry,ok=optional(panels,name)
            if not ok then observe("panel_entry_unknown",scope,chain,"UI-panel entry inaccessible",true)
            elseif entry~=nil then observe("ui_panel_registry",scope,chain,"UI-panel registry match") end
        end
        if method(chain,"GetAttribute") then
            local ok,defined=self:read(chain,"GetAttribute","UIPanelLayout-defined")
            if not ok then observe("panel_attributes_unknown",scope,chain,"Optional UI-panel attributes inaccessible",true)
            elseif defined then observe("ui_panel_attribute",scope,chain,"UIPanelLayout-defined attribute") end
        end
        for _,key in ipairs({"IsLayoutFrame","systemInfo","system","layoutIndex","Layout","SetFixedFrameStrata"}) do
            local v,ok=optional(chain,key)
            if not ok then observe("layout_hint_unknown",scope,chain,"Optional "..key.." hint inaccessible",true)
            elseif v~=nil and v~=false then
                observe(key=="IsLayoutFrame" and "shared_layout_marker" or "layout_hint",scope,chain,
                    (key=="IsLayoutFrame" and "Shared layout marker: " or "Heuristic hint: ")..key.." (not property ownership proof)")
            end
        end
        if depth==FC.LIMITS.depth then observe("ancestry_bound",scope,chain,"Optional ancestry scan reached its bound",true); break end
        chain=self:parent(chain)
    end
    m.state=unknown and (involved and "observed_and_unknown" or "unknown") or (involved and "observed" or "none_observed")
    if involved then m.advisory="Blizzard may reset this "..setting.."; enforcement remains enabled for eligible overrides."
    elseif unknown then m.advisory="Management is partly unknown; required operation checks still apply." end
    return m,policy
end
function A:geometryRepresentation(o,d,value,r)
    value=value or d.default
    if d.setting=="size" then
        local ok,n=self:read(o,"GetNumPoints")
        if not ok then return U.finding("inaccessible","anchor_count_inaccessible","Inaccessible: size anchor count") end
        if not U.number(n,0,8) or n%1~=0 then return U.finding("unsupported","anchor_count_invalid","Unsupported layout: invalid anchor count") end
        if n>1 then return U.finding("unsupported","size_multiple_anchors","Unsupported layout: multiple anchors may constrain size; preserved-anchor translation remains available") end
    else
        local anchors,reason,code,state=FC.Anchors.snapshot(self,o)
        if not anchors then return U.finding(state,code,reason) end
        for _,anchor in ipairs(anchors) do
            local ok,err,_,nativeCode,nativeState=self:geometryNative(o,anchor.relative)
            if not ok then r.native=U.finding(nativeState,nativeCode,err) end
        end
        local compatible,err,why,category=FC.Anchors.compatible(self,o,value or d.default,anchors)
        if not compatible then return U.finding(category,why,err) end
        if not value.anchors and anchors[1].point~=value.point and not method(o,"ClearAllPoints") then
            r.native=U.finding("unavailable","setter_missing","Native capability unavailable: sole-point change requires ClearAllPoints")
        end
    end
    return U.finding("supported","representation_supported",d.setting=="size" and "Zero or one anchor" or "Readable, compatible anchors; relationships preserved")
end
function A:geometryPermission(o,d,value)
    local r=U.geometryResult(d.setting)
    r.management,r.policy=self:geometryManagement(o,d.setting)
    local allowed,why,_,code,state=self:geometryNative(o)
    r.native=allowed and U.finding("passed","native_passed","Passed at last preflight; rechecked at execution") or U.finding(state,code,why)
    r.representation=self:geometryRepresentation(o,d,value,r)
    for _,field in ipairs({"native","representation","policy"}) do
        local f=r[field]
        if f.state~="passed" and f.state~="supported" and f.state~="allowed" then return false,f.detail,true,r end
    end
    return true,nil,nil,r
end
function A:prepareGeometry(o,d,value)
    local ok,why,_,result=self:canWrite(o,d,value)
    if not ok then U.deferGeometry(result,why) end
end
function A:canWrite(o,d,value)
    local function deny(field,state,code,why,retry)
        local result
        if d.permission=="geometry" then result=U.geometryResult(d.setting); result[field]=U.finding(state,code,why) end
        return false,why,retry,result
    end
    local ok,why=self:inspectable(o); if not ok then return deny("native","inaccessible","object_access",why,true) end
    if self:excluded(o) then return deny("policy","blocked","infrastructure","Editor/root infrastructure is not editable",false) end
    if not FC.Properties.applicable(d,self:kind(o)) then return deny("representation","unsupported","object_type","Unsupported object type",false) end
    for _,key in ipairs(d.writes) do
        if not method(o,key) then return deny("native","unavailable","setter_missing","Native capability unavailable: missing method "..key,false) end
    end
    if d.permission=="geometry" then return self:geometryPermission(o,d,value) end
    if d.permission=="texture" then
        if not self:noForbidden(o,"SetTexture") then return false,"Texture changes forbidden or permission check unavailable",true end
        if value.kind=="atlas" then
            if not C_Texture or type(C_Texture.GetAtlasInfo)~="function" then return false,"Atlas validation unavailable",false end
            local info=C_Texture.GetAtlasInfo(value.asset)
            if not safe(info) or info==nil then return false,"Atlas name not found",false end
        end
    elseif d.permission=="barTexture" then
        local t=self:barRegion(o)
        if not t or not method(t,"SetTexture") or not self:noForbidden(t,"SetTexture") then return false,"Status bar fill unavailable / texture changes forbidden",true end
    end
    return true
end
function A:canRead(o,d)
    if not self:inspectable(o) or not self:aspectReadable(o,d.aspects) then return false end
    for _,key in ipairs(d.reads) do if not method(o,key) then return false end end
    if d.permission=="geometry" and boolCall(o,"IsAnchoringSecret")~=false then return false end
    return true
end
function A:write(o,key,...)
    -- Called only after definition-level permission checks. Recheck object
    -- access for coordinated setters and the status bar's current fill.
    local geometry=key=="SetPoint" or key=="ClearAllPoints" or key=="SetSize"
    if not writable[key] or not geometry and not self:inspectable(o) then error("FrameCustomizer: operation no longer accessible") end
    if key=="SetTexture" or key=="SetAtlas" then
        if not self:noForbidden(o,"SetTexture") then error("FrameCustomizer: texture permission changed") end
    end
    if geometry then
        local _,relative=...
        local result=U.geometryResult(key=="SetSize" and "size" or "position")
        result.management,result.policy=self:geometryManagement(o,result.property)
        local allowed,why,_,code,state=self:geometryNative(o,key=="SetPoint" and relative or nil)
        result.native=allowed and U.finding("passed","native_passed","Passed at setter preflight") or U.finding(state,code,why)
        if not allowed then U.deferGeometry(result,why) end
        if result.policy.state=="blocked" then U.deferGeometry(result,result.policy.detail) end
        if not method(o,key) then
            result.native=U.finding("unavailable","setter_missing","Native capability unavailable: missing method "..key)
            U.deferGeometry(result,result.native.detail)
        end
    end
    local f=method(o,key); if not f then error("FrameCustomizer: method unavailable") end
    local success=f(o,...)
    if not safe(success) then return end
    if success==false then error("FrameCustomizer: native setter rejected configured value") end
end
function A:hook(o,key,callback)
    if not self:inspectable(o) or not method(o,key) or not self:noForbidden(o,"ScriptBindings") or type(hooksecurefunc)~="function" then return false end
    -- This protects the scheduler from an unexpected hook-install error; it is
    -- not used to attempt calls after a permission denial.
    local ok,err=pcall(hooksecurefunc,o,key,callback)
    if not ok then self:onError(err) end
    return ok
end
function A:onError(err)
    if self:now()-self.lastError<5 then return end
    self.lastError=self:now()
    local detail="inaccessible error details omitted"
    if safe(err) and type(err)=="string" then detail=err:sub(1,500) end
    if type(geterrorhandler)=="function" then geterrorhandler()("FrameCustomizer: "..detail) end
end
function A:label(o)
    local key=self:parentKey(o)
    if key then return U.cleanLabel(key) end
    local name=self:name(o)
    if name then return U.cleanLabel(name) end
    local ok,name=self:read(o,"GetDebugName",true)
    if ok and U.string(name,512) and name~="" then return U.cleanLabel(name:match("([^.]+)$") or name):sub(1,80) end
    return "anonymous"
end
function A:children(o)
    local out={}
    if not self:inspectable(o) or not self:aspectReadable(o,{"Hierarchy"}) then return out,"Hierarchy inaccessible" end
    for _,pair in ipairs({{"GetNumRegions","GetRegions"},{"GetNumChildren","GetChildren"}}) do
        if method(o,pair[1]) and method(o,pair[2]) then
            local ok,n=self:read(o,pair[1])
            local limit=o==UIParent and 4096 or FC.LIMITS.children
            if not ok or not U.number(n,0,limit) then return out,"Too many children/regions or inaccessible count (limit "..limit.." per kind)" end
            local values={method(o,pair[2])(o)}
            for i=1,n do
                local child=values[i]
                -- Native enumeration has no offset API. Snapshot a bounded
                -- batch of references; expensive inspection happens 16 at a
                -- time in Discovery, not once per child in this call.
                if safe(child) then out[#out+1]=child end
            end
        end
    end
    return out
end
function A:rect(o)
    local ok,l,b,w,h=self:read(o,"GetRect")
    if not ok or not U.number(l,-100000,100000) or not U.number(b,-100000,100000) or not U.number(w,0.1,100000) or not U.number(h,0.1,100000) then return end
    local good,scale=self:read(o,"GetEffectiveScale")
    if not good or not U.number(scale,0.01,100) then
        local parent=self:parent(o); good,scale=self:read(parent,"GetEffectiveScale")
    end
    if good and U.number(scale,0.01,100) then return l,b,w,h,scale end
end
function A:media(mediaType,builtinsOnly)
    local builtins={font={{"Friz Quadrata","Fonts\\FRIZQT__.TTF"},{"Arial Narrow","Fonts\\ARIALN.TTF"}},
        statusbar={{"Blizzard fill","Interface\\TargetingFrame\\UI-StatusBar"},{"Solid white","Interface\\Buttons\\WHITE8X8"}},
        background={{"Solid white","Interface\\Buttons\\WHITE8X8"},{"Dialog background","Interface\\DialogFrame\\UI-DialogBox-Background"}}}
    local types=mediaType=="texture" and {"background","statusbar"} or {mediaType}
    local result={}; local info={available=false,count=0,skipped=0,capped=false}
    for _,kind in ipairs(types) do
        for _,item in ipairs(builtins[kind] or {}) do result[#result+1]={item[1],item[2],source="Blizzard",mediaType=kind} end
    end
    if mediaType~="font" then result[#result+1]={"Transparent / blank",FC.BLANK_TEXTURE,source="FrameCustomizer",mediaType="texture"} end
    local stub=rawget(_G,"LibStub")
    local lib,minor
    if builtinsOnly then info.reason="Built-ins only (fallback test; installed library unchanged)"
    elseif not safe(stub) or stub==nil then info.reason="LibSharedMedia unavailable: LibStub not loaded"
    else
        local ok
        if type(stub)=="table" and method(stub,"GetLibrary") then ok,lib,minor=pcall(stub.GetLibrary,stub,"LibSharedMedia-3.0",true)
        elseif type(stub)=="function" then ok,lib,minor=pcall(stub,"LibSharedMedia-3.0",true) end
        if not ok or not safe(lib) or type(lib)~="table" or not method(lib,"List") or not method(lib,"Fetch") then
            lib=nil; info.reason="LibSharedMedia unavailable or incompatible; built-ins and manual paths available"
        end
    end
    if lib then
        info.available=true; info.reason="LibSharedMedia detected"
        if U.number(minor,0,1000000) then info.revision=minor end
        for _,kind in ipairs(types) do
            local ok,list=pcall(lib.List,lib,kind)
            if not ok or not safe(list) or type(list)~="table" then info.reason="LibSharedMedia detected; enumeration failed for "..kind
            else
                if #list>1000 then info.capped=true end
                for i=1,math.min(#list,1000) do
                    local name=list[i]
                    if U.string(name,240) and name~="" then
                        local fetched,path=pcall(lib.Fetch,lib,kind,name,true)
                        if fetched and U.string(path,240) and path~="" then
                            result[#result+1]={name,path,source="SharedMedia",mediaType=kind}; info.count=info.count+1
                        else info.skipped=info.skipped+1 end
                    else info.skipped=info.skipped+1 end
                end
            end
        end
    end
    info.summary=info.reason.."; "..info.count.." SharedMedia assets"..(info.skipped>0 and ("; "..info.skipped.." invalid/unavailable skipped") or "")..(info.capped and "; capped at 1000 per type" or "")
    return result,info
end
function A:mediaDiagnostics()
    local out={}
    for _,kind in ipairs({"font","statusbar","texture"}) do
        local _,info=self:media(kind)
        out[#out+1]=kind..": "..info.summary..(info.revision and ("; library revision="..info.revision) or "")
    end
    return table.concat(out,"\n")
end
