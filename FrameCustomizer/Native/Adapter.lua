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
    if safe(value) and type(value)=="boolean" then return value end
end
local aspects={GetAlpha={"Alpha"},GetVertexColor={"VertexColor","Alpha"},GetTextColor={"VertexColor","Alpha"},
    GetStatusBarColor={"VertexColor","Alpha"},GetName={"ObjectName"},GetObjectType={"ObjectType"},
    GetParent={"Hierarchy"},GetNumChildren={"Hierarchy"},GetNumRegions={"Hierarchy"},GetChildren={"Hierarchy"},GetRegions={"Hierarchy"},
    GetEffectiveScale={"Scale"},IsShown={"Shown"}}
local readable={GetAlpha=true,GetAtlas=true,GetTexture=true,GetVertexColor=true,GetTextColor=true,GetFont=true,
    GetStatusBarColor=true,GetStatusBarTexture=true,GetSize=true,GetNumPoints=true,GetPoint=true,GetParent=true,
    GetName=true,GetObjectType=true,GetParentKey=true,GetDebugName=true,GetNumChildren=true,GetNumRegions=true,
    GetRect=true,GetEffectiveScale=true,IsShown=true,IsUserPlaced=true,IsMovable=true,IsResizable=true}
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
function A:geometryPermission(o,d)
    if boolCall(o,"IsAnchoringRestricted")~=false or boolCall(o,"IsAnchoringSecret")~=false then return false,"Anchoring restricted, secret, or checks unavailable",true end
    local parent=self:parent(o)
    if not parent then return false,"Accessible parent required",true end
    if not self:noForbidden(o,"UntrustedLayoutScriptExecution") or not self:noForbidden(parent,"UntrustedLayoutScriptExecution") then return false,"Forbidden layout inheritance or missing layout check",true end
    if not C_RestrictedActions or type(C_RestrictedActions.CheckAllowProtectedFunctions)~="function" then return false,"Protected-operation permission API unavailable",false end
    local allowed=C_RestrictedActions.CheckAllowProtectedFunctions(o,true)
    if not safe(allowed) or allowed~=true then return false,"Protected operation denied in current context",true end
    local one,n=self:read(o,"GetNumPoints")
    local ok,_,relative=self:read(o,"GetPoint",1)
    if not one or n~=1 or not ok or relative~=parent then return false,"Geometry requires one existing anchor to its parent",true end
    if self:isFixture(o) then return true end
    -- A positive native user-placement marker is required; mere absence of a
    -- recognized manager is not evidence of ownership. Recheck on every write.
    local userPlaced,u=self:read(o,"IsUserPlaced")
    local movable,m=self:read(o,"IsMovable")
    if not userPlaced or u~=true or not movable or m~=true then return false,"Layout ownership unknown: requires a movable, user-placed frame",false end
    if d.setting=="size" then
        local resizable,r=self:read(o,"IsResizable")
        if not resizable or r~=true then return false,"Size ownership unknown: frame is not user-resizable",false end
    end
    local manager=rawget(_G,"EditModeManagerFrame")
    if not self:inspectable(manager) then return false,"Edit Mode registry unavailable; ownership unknown",true end
    local registry=U.field(manager,"registeredSystemFrames")
    local loaded=U.field(manager,"layoutInfo") or U.field(manager,"overrideLayoutInfo")
    if type(registry)~="table" or type(loaded)~="table" or #registry>256 then return false,"Edit Mode registry not ready / exceeds inspection bound",true end
    local chain=o
    for _=0,FC.LIMITS.depth do
        if chain==UIParent then return true end
        if not chain or not self:inspectable(chain) then return false,"Unknown layout ancestry",true end
        for i=1,#registry do
            local v=registry[i]
            if not safe(v) then return false,"Edit Mode registry inaccessible",true end
            if v==chain then return false,"Geometry is owned by Edit Mode on this object or an ancestor",true end
        end
        for _,key in ipairs({"system","systemInfo","layoutIndex","IsLayoutFrame","Layout","SetFixedFrameStrata"}) do
            local v=rawget(chain,key)
            if not safe(v) then return false,"Layout metadata inaccessible",true end
            if v~=nil then return false,"Managed or unverified layout ("..key.."); geometry unavailable",false end
        end
        chain=self:parent(chain)
    end
    return false,"Layout ancestry exceeds inspection bound",false
end
function A:canWrite(o,d,value)
    local ok,why=self:inspectable(o); if not ok then return false,why,true end
    if self:excluded(o) then return false,"Editor/root infrastructure is not editable",false end
    if not FC.Properties.applicable(d,self:kind(o)) then return false,"Unsupported object type",false end
    for _,key in ipairs(d.writes) do if not method(o,key) then return false,"Missing native method "..key,false end end
    if d.permission=="geometry" then return self:geometryPermission(o,d) end
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
    if not writable[key] or not self:inspectable(o) then error("FrameCustomizer: operation no longer accessible") end
    if key=="SetTexture" or key=="SetAtlas" then
        if not self:noForbidden(o,"SetTexture") then error("FrameCustomizer: texture permission changed") end
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
    local kind=self:kind(o) or "unavailable"
    local t=FC.Resolver.describe(self,o)
    if t then return U.joinTarget(t).." ["..kind.."]" end
    local ok,name=self:read(o,"GetDebugName",true)
    return (ok and U.cleanLabel(name) or "anonymous").." ["..kind.."; inspect only]"
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
function A:media(mediaType)
    local builtins={font={{"Friz Quadrata","Fonts\\FRIZQT__.TTF"},{"Arial Narrow","Fonts\\ARIALN.TTF"}},
        statusbar={{"Blizzard","Interface\\TargetingFrame\\UI-StatusBar"},{"Solid","Interface\\Buttons\\WHITE8X8"}},
        background={{"Solid","Interface\\Buttons\\WHITE8X8"},{"Dialog","Interface\\DialogFrame\\UI-DialogBox-Background"}}}
    local result=U.copy(builtins[mediaType] or {})
    local stub=rawget(_G,"LibStub")
    if stub and safe(stub) then
        local lib=stub("LibSharedMedia-3.0",true)
        if lib and type(lib.List)=="function" and type(lib.Fetch)=="function" then
            local list=lib:List(mediaType)
            for i=1,math.min(#list,300) do
                local name=list[i]; local path=lib:Fetch(mediaType,name,true)
                if U.string(name,120) and U.string(path,240) then result[#result+1]={name,path} end
            end
        end
    end
    return result
end
