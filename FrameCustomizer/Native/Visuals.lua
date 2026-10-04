local _,FC=...
local A,U,P,R=FC.NativeAdapter,FC.Util,FC.Properties,FC.Resolver
local function call(a,o,key,...)
    local ok,why=a:protected(o); if not ok then return false,why end
    local f=o[key]
    if not U.safe(f) or type(f)~="function" then return false,"Required visual operation missing: "..key end
    f(o,...); return true
end
local function frameFor(a,o)
    if P.applicable(P.byID.frameLayer,a:kind(o)) then return o end
    local p=a:parent(o)
    if p and P.applicable(P.byID.frameLayer,a:kind(p)) then return p end
end
function A:visualPlan(v)
    local target,container=UIParent,UIParent
    if v.placement=="target" then
        local why; target,why=R.resolve(self,v.target)
        if not target then return nil,"unresolved attachment: "..(why or "unavailable") end
        if v.container then container,why=R.resolve(self,v.container) else container=frameFor(self,target) end
        if not container or not P.applicable(P.byID.frameLayer,self:kind(container)) then return nil,"unavailable visibility container: "..(why or "select a stable frame") end
    end
    local ok,visible=self:read(container,"IsVisible")
    if not ok or type(visible)~="boolean" then return nil,"inaccessible: container visibility" end
    local layer=v.style.frameLayer
    if v.layerMode=="behind" then
        local owner=frameFor(self,target)
        if not owner then return nil,"unsupported: attachment has no containing frame" end
        layer=P.byID.frameLayer.read(self,owner)
        layer=layer and P.byID.frameLayer.validate(layer)
        if not layer then return nil,"inaccessible: target strata / frame level; choose manual layering" end
        if layer.level==0 then return nil,"unsupported: no lower level in target strata; choose manual layering" end
        layer.level=layer.level-1
    end
    return {target=target,container=container,visible=visible,layer=layer}
end
function A:createVisual(slot)
    if not self:inspectable(UIParent) or not self:noForbidden(UIParent,"UntrustedLayoutScriptExecution") then return false,"pending: UI root inaccessible / forbidden layout" end
    -- Create only a plain addon-owned frame under the UI root. Never instantiate
    -- a Blizzard template or attach native children to the selected object.
    if not slot.frame then
        if type(CreateFrame)~="function" then return false,"Frame creation unavailable" end
        slot.frame=CreateFrame("Frame",nil,UIParent); self.owned[slot.frame]=true
    end
    local f=slot.frame
    local ok,why=call(self,f,"Hide"); if not ok then return false,why end
    ok,why=call(self,f,"EnableMouse",false); if not ok then return false,why end
    ok,why=call(self,f,"SetFixedFrameStrata",true); if not ok then return false,why end
    ok,why=call(self,f,"SetFixedFrameLevel",true); if not ok then return false,why end
    if not slot.texture then
        if not self:inspectable(f) or not U.safe(f.CreateTexture) or type(f.CreateTexture)~="function" then return false,"Texture creation unavailable" end
        slot.texture=f:CreateTexture(nil,"BACKGROUND"); self.owned[slot.texture]=true
    end
    return true
end
function A:showVisual(slot,visible)
    local f=slot.frame; if not f then return true end
    local ok,current=self:read(f,"IsShown")
    if ok and current==visible then return true end
    return call(self,f,visible and "Show" or "Hide")
end
function A:retireVisual(slot)
    local ok,why=self:showVisual(slot,false); if not ok then return false,why end
    -- Detach every external anchor before reuse. Native denial retains the
    -- slot in the bounded retirement queue, never allocates a replacement.
    local allowed,reason=self:geometryNative(slot.frame)
    if not allowed then return false,reason end
    self:write(slot.frame,"ClearAllPoints")
    return true
end
local function property(a,o,key,value)
    local d=P.byID[key]; local ok,why=a:canWrite(o,d,value)
    if not ok then return false,why end
    local current=a:canRead(o,d) and d.read(a,o)
    if not current or not U.equal(d.validate(current),value) then d.write(a,o,value) end
    return true
end
function A:configureVisual(slot,v,plan,changed)
    -- Finish a partially created slot in place after a permission transition.
    if not slot.texture then local ok,why=self:createVisual(slot); if not ok then return false,why end end
    self.visualIdentity[slot.texture]=FC.Visuals.target(self.visualIdentity[slot.frame].visual,"texture")
    local f,t=slot.frame,slot.texture
    local ok,why=self:geometryNative(f,plan.target); if not ok then return false,why end
    ok,why=self:geometryNative(t,f); if not ok then return false,why end
    local l=v.layout
    local points=l.mode=="fill" and {{"TOPLEFT",plan.target,"TOPLEFT",l.left+l.x,-l.top+l.y},{"BOTTOMRIGHT",plan.target,"BOTTOMRIGHT",-l.right+l.x,l.bottom+l.y}}
        or {{l.point,plan.target,l.relativePoint,l.x,l.y}}
    -- Compare exact owned topology, not existing-object preservation policy.
    local function layout(o,wanted,width,height)
        local snapshot=FC.Anchors.snapshot(self,o)
        local matches=snapshot and #snapshot==#wanted
        if matches then
            for _,p in ipairs(wanted) do
                local found=false
                for _,q in ipairs(snapshot) do if q.point==p[1] and q.relative==p[2] and q.relativePoint==p[3] and q.x==p[4] and q.y==p[5] then found=true end end
                if not found then matches=false end
            end
        end
        if not matches then
            self:write(o,"ClearAllPoints")
            for _,p in ipairs(wanted) do self:write(o,"SetPoint",unpack(p)) end
        end
        if width then
            local good,w,h=self:read(o,"GetSize")
            if not good or w~=width or h~=height then self:write(o,"SetSize",width,height) end
        end
    end
    if changed then local hidden,reason=self:showVisual(slot,false); if not hidden then return false,reason end end
    layout(f,points,l.mode=="fixed" and l.width or nil,l.height)
    layout(t,{{"TOPLEFT",f,"TOPLEFT",0,0},{"BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0}})
    ok,why=property(self,f,"frameLayer",plan.layer); if not ok then return false,why end
    for _,key in ipairs({"texture","tint","drawLayer"}) do
        ok,why=property(self,t,key,v.style[key]); if not ok then return false,why end
    end
    return true
end
