local _,FC=...
local U,P,S=FC.Util,FC.Properties,FC.Schema
local V={}; V.__index=V; FC.Visuals=V
V.white="Interface\\Buttons\\WHITE8X8"
function V.target(id,part) return {visual=id,part=part,types={part=="frame" and "Frame" or "Texture"}} end
function V.default(target)
    return {name="Background",enabled=true,placement=target and "target" or "screen",target=U.copy(target),
        layerMode=target and "behind" or "manual",
        layout={mode=target and "fill" or "fixed",point="CENTER",relativePoint="CENTER",x=0,y=0,width=300,height=100,left=0,right=0,top=0,bottom=0},
        style={texture={kind="file",asset=V.white},tint={r=0,g=0,b=0,a=1},
            frameLayer={strata="LOW",level=1},drawLayer={layer="BACKGROUND",sublevel=0}}}
end
function V.validate(raw)
    local name,enabled,placement=U.field(raw,"name"),U.field(raw,"enabled"),U.field(raw,"placement")
    if not U.string(name,80) or name=="" or type(enabled)~="boolean" or placement~="screen" and placement~="target" then return nil,"Invalid name, enabled state or placement" end
    local out={name=name,enabled=enabled,placement=placement,layout={},style={}}
    if placement=="target" then
        out.target=S.target(U.field(raw,"target")); if not out.target then return nil,"Attachment requires a stable existing-object identity" end
        if not P.applicable(P.byID.position,out.target.types[#out.target.types]) then return nil,"Attachment type is not a supported anchor region" end
        if U.field(raw,"container") then
            out.container=S.target(raw.container)
            if not out.container then return nil,"Visibility container requires a stable existing-object identity" end
            if not P.applicable(P.byID.frameLayer,out.container.types[#out.container.types]) then return nil,"Visibility container must be a supported frame" end
        end
    end
    local mode=U.field(raw,"layerMode")
    if mode~="manual" and mode~="behind" or mode=="behind" and placement~="target" then return nil,"Behind target requires an attachment" end
    out.layerMode=mode
    local layout=U.field(raw,"layout")
    local lm=U.field(layout,"mode")
    if lm~="fixed" and lm~="fill" or lm=="fill" and placement~="target" then return nil,"Fill sizing requires an attachment" end
    out.layout.mode=lm
    for _,key in ipairs({"point","relativePoint"}) do
        local value=U.field(layout,key)
        if not U.string(value,16) or not FC.Anchors.points[value] then return nil,"Invalid anchor point" end
        out.layout[key]=value
    end
    for _,key in ipairs({"x","y","width","height","left","right","top","bottom"}) do
        local value=U.field(layout,key); local dimension=key=="width" or key=="height"
        if not U.number(value,dimension and 1 or -4096,4096) then return nil,"Invalid layout "..key end
        out.layout[key]=value
    end
    for _,key in ipairs({"texture","tint","frameLayer","drawLayer"}) do
        local value,why=P.byID[key].validate(U.field(U.field(raw,"style"),key))
        if not value then return nil,key..": "..(why or "invalid value") end
        out.style[key]=value
    end
    return out
end
function V.rules(db)
    local rules={}
    for id,v in pairs(db.visuals or {}) do
        local function rule(part,keys)
            local r={target=V.target(id,part),enabled=v.enabled,periodic=false,interval=2,overrides={}}
            for _,key in ipairs(keys) do r.overrides[key]={enabled=true,value=v.style[key]} end
            rules[id..":"..part]=r
        end
        rule("texture",{"texture","tint","drawLayer"})
        if v.layerMode=="manual" then rule("frame",{"frameLayer"}) end
    end
    return rules
end
function V.new(a,db)
    local self=setmetatable({a=a,db=db,slots={},pool={},allocated=0,cursor=0},V)
    a.visualObjects=self.slots; a.visualIdentity=setmetatable({},{__mode="k"})
    return self
end
function V:changed()
    for _,slot in pairs(self.slots) do slot.due=0 end
end
function V:save(id,raw)
    local clean,why=V.validate(raw); if not clean then return nil,why end
    if not id then
        local count=0; for _ in pairs(self.db.visuals) do count=count+1 end
        if count>=FC.LIMITS.visuals then return nil,"64-visual limit reached" end
        if self.db.nextVisualID>1000000000 then return nil,"Visual identity space exhausted" end
        id="v"..self.db.nextVisualID; self.db.nextVisualID=self.db.nextVisualID+1
    elseif not self.db.visuals[id] then return nil,"Visual no longer exists" end
    self.db.visuals[id]=clean
    if self.slots[id] then self.slots[id].errors=0; self.slots[id].suspended=nil end
    self:changed(); return id
end
function V:delete(id) self.db.visuals[id]=nil; self:changed() end
function V:duplicate(id)
    local v=U.copy(self.db.visuals[id]); if not v then return nil,"Visual no longer exists" end
    v.name=v.name:sub(1,73).." (copy)"; return self:save(nil,v)
end
function V:retire(id,slot)
    slot.ready=false
    if slot.frame then
        local ok,why=self.a:retireVisual(slot)
        if not ok then slot.status="pending removal: "..why; return false end
        self.a.visualIdentity[slot.frame]=nil
        if slot.texture then self.a.visualIdentity[slot.texture]=nil end
        slot.config=nil; slot.target=nil; slot.container=nil; slot.layer=nil
        self.pool[#self.pool+1]=slot
    elseif slot.reserved then
        self.allocated=self.allocated-1
    end
    self.slots[id]=nil; return true
end
function V:process(id,slot,now)
    local v=self.db.visuals[id]
    if not v or not v.enabled or self.db.paused then
        slot.due=now+0.2; self:retire(id,slot); return
    end
    if slot.suspended then
        local hidden,why=self.a:showVisual(slot,false)
        slot.status="failed: suspended; save to retry"..(hidden and "" or "; pending removal: "..why)
        slot.due=now+0.2; return
    end
    local plan,why=self.a:visualPlan(v)
    if not plan then
        slot.ready=false; slot.config=nil; slot.status=why
        if slot.frame then
            local hidden,reason=self.a:showVisual(slot,false)
            if not hidden then slot.status=why.."; pending removal: "..reason end
        end
        slot.due=now+0.2; return
    end
    if not slot.frame then
        local recycled=table.remove(self.pool)
        if recycled then
            slot.frame,slot.texture=recycled.frame,recycled.texture
        else
            if not slot.reserved and self.allocated>=FC.LIMITS.visuals then slot.status="pending: allocation limit; release blocked objects or reload"; slot.due=now+1; return end
            -- Reserve before creation, including unexpected partial failures.
            if not slot.reserved then self.allocated=self.allocated+1; slot.reserved=true end
            local created,reason=self.a:createVisual(slot)
            if not slot.frame then self.allocated=self.allocated-1; slot.reserved=nil end
            if not created then slot.status=reason; slot.due=now+1; return end
        end
    end
    self.a.visualIdentity[slot.frame]=V.target(id,"frame")
    if slot.texture then self.a.visualIdentity[slot.texture]=V.target(id,"texture") end
    local changed=not U.equal(slot.config,v) or slot.target~=plan.target or slot.container~=plan.container or not U.equal(slot.layer,plan.layer)
    if changed or not slot.ready or now>=(slot.verify or 0) then
        slot.ready=false
        local ok,reason=self.a:configureVisual(slot,v,plan,changed)
        if not ok then
            slot.config=nil; slot.status=reason
            local hidden,hideWhy=self.a:showVisual(slot,false)
            if not hidden then slot.status=reason.."; pending removal: "..hideWhy end
            slot.due=now+0.2; return
        end
        slot.config=U.copy(v); slot.target=plan.target; slot.container=plan.container; slot.layer=U.copy(plan.layer); slot.verify=now+2; slot.ready=true
    end
    local ok,reason=self.a:showVisual(slot,plan.visible)
    if ok then slot.errors=0 end
    slot.status=ok and (plan.visible and "active (rendering unverified)" or "following hidden container") or "pending visibility: "..reason
    slot.due=now+0.2
end
function V:tick()
    local ids={}; for id in pairs(self.slots) do ids[id]=true end
    if not self.db.paused then for id,v in pairs(self.db.visuals or {}) do if v.enabled then ids[id]=true end end end
    local order={}; for id in pairs(ids) do order[#order+1]=id end; table.sort(order)
    if #order==0 then return 0 end
    local now=self.a:now(); local work=0
    for _=1,math.min(#order,FC.LIMITS.scan) do
        self.cursor=self.cursor%#order+1; local id=order[self.cursor]
        local slot=self.slots[id] or {due=0}; self.slots[id]=slot
        if now>=(slot.due or 0) then
            local ok,err=pcall(self.process,self,id,slot,now)
            if not ok then
                slot.ready=false; slot.config=nil
                if U.isGeometryDeferred(err) then slot.status="pending: "..err.reason; slot.due=now+0.2
                else
                    self.a:onError(err); slot.errors=(slot.errors or 0)+1; slot.suspended=slot.errors>=3
                    slot.status=slot.suspended and "failed: suspended; save to retry" or "failed: operation error; retrying"
                    slot.due=now+math.min(30,2^slot.errors)
                end
                if slot.frame then
                    local cleaned,hidden,why=pcall(self.a.showVisual,self.a,slot,false)
                    if not cleaned or not hidden then slot.status=slot.status.."; pending removal"..(cleaned and (": "..why) or "") end
                end
            end
            work=work+1; if work>=4 then break end
        end
    end
    return work
end
function V:diagnostics()
    local lines={"Created visuals: allocated="..self.allocated.." pooled="..#self.pool}
    local ids={}; for id in pairs(self.db.visuals or {}) do ids[#ids+1]=id end; table.sort(ids)
    for i=1,math.min(64,#ids) do
        local id=ids[i]; local v=self.db.visuals[id]; local s=self.slots[id]
        lines[#lines+1]=id.." "..U.cleanLabel(v.name).." | "..v.placement.." / "..v.layout.mode.." | "..(s and s.status or (self.db.paused and "paused" or not v.enabled and "disabled" or "pending"))
    end
    for id,s in pairs(self.slots) do if not self.db.visuals[id] then lines[#lines+1]=id.." deleted | "..(s.status or "pending removal") end end
    return table.concat(lines,"\n")
end
