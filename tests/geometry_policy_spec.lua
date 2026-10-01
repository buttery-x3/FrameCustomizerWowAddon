-- Ordinary production-policy objects: no fixtures / isFixture exemptions.
local _,FC=...
local A,P,G,U,N=FC.adapter,FC.Properties,FC.Anchors,FC.Util,FC.TestNative
local count=0
local function test(name,fn)
    local ok,err=pcall(fn); if not ok then error("FAIL GEOMETRY POLICY "..name..": "..tostring(err),0) end
    count=count+1; print("PASS GEOMETRY POLICY "..name)
end
local function frame(name,parent,key)
    local o=CreateFrame("Frame",name,parent or UIParent)
    if key then o:SetParentKey(key) end
    o:SetPoint("CENTER",parent or UIParent,"CENTER",0,0)
    assert(not A:isFixture(o)); return o
end
local function result(o,id,value)
    local ok,why,_,r=A:canWrite(o,P.byID[id],value or P.byID[id].default)
    assert(r and r.native and r.representation and r.policy and r.management)
    return r,ok,why
end
local function observation(r,code,scope)
    for _,f in ipairs(r.management.observations) do if f.code==code and (not scope or f.scope==scope) then return f end end
end
local function engine(o,id,value,periodic)
    local db={version=1,paused=false,nextID=2,rules={r1={target=assert(FC.Resolver.describe(A,o)),enabled=true,
        periodic=periodic==true,interval=0.25,overrides={[id]={enabled=true,value=value}}}}}
    return FC.Engine.new(A,db),db
end
local function tick(e,delay) N.time=N.time+(delay or 0.1); e:tick() end

test("registered UI panel reaches editor commit, writer, verification, report and undo",function()
    local o=frame("PolicyPanel"); UIPanelWindows={PolicyPanel={area="left"}}
    local ui=FC.Editor; ui:select(o); ui:createRule(); ui:chooseProperty(P.byID.position)
    assert(observation(ui.geometryResult,"ui_panel_registry","target").object=="PolicyPanel")
    ui.fields[3].edit:SetText("27"); ui:saveProperty(true); N.advance(0.3)
    local j=FC.engine.states[ui.id].jobs.position
    assert(o.points[1][4]==27 and j.writes>0 and j.errors==0 and j.eligibility.management.advisory)
    N.advance(2.1); assert(j.status=="readable value matched at last check")
    assert(j.eligibility.management.advisory and not j.suspended)
    ui:status(); assert(ui.readout:GetText():find("Advisory:",1,true))
    ui.eligibilityReport.scripts.OnClick()
    local report=ui.reportFrame.edit:GetText()
    assert(report:find("ui_panel_registry",1,true) and report:find("native_passed",1,true) and report:find("Representation: supported",1,true))
    ui.reportFrame:Hide()
    local restores=FC.engine:undo(ui.id); assert(restores==1 and o.points[1][4]==0 and not ui:rule().enabled)
    UIPanelWindows=nil
end)

test("panel and Edit Mode ancestors allow descendant local position and size writes",function()
    local parent=frame("PolicyParent"); local child=frame(nil,parent,"Child")
    parent.OnDragStart=EditModeSystemMixin.OnDragStart
    UIPanelWindows={PolicyParent={}}; EditModeManagerFrame.registeredSystemFrames={parent}
    for _,id in ipairs({"position","size"}) do
        local value=U.copy(P.byID[id].default); if id=="position" then value.x=18 end
        local r,ok=result(child,id,value); assert(ok)
        assert(observation(r,"edit_mode_registration","ancestor").object=="PolicyParent")
        assert(observation(r,"ui_panel_registry","ancestor") and not observation(r,"edit_mode_position_control"))
        local e=engine(child,id,value); e:tick(); assert(e.stats.writes==1 and e.stats.errors==0); e:pause(true)
    end
    assert(child.points[1][4]==18 and child.width==160)
    UIPanelWindows=nil; EditModeManagerFrame.registeredSystemFrames={}
end)

test("direct exposed Edit Mode position is policy, with zero position setters and independent cosmetics",function()
    local o=frame("PolicyDirect"); o.OnDragStart=EditModeSystemMixin.OnDragStart
    EditModeManagerFrame.registeredSystemFrames={o}
    local r,ok=result(o,"position"); assert(not ok and r.native.state=="passed" and r.representation.state=="supported")
    assert(r.policy.code=="edit_mode_position" and observation(r,"edit_mode_position_control","target"))
    local value=U.copy(P.byID.position.default); value.x=40
    local e,db=engine(o,"position",value,true); db.rules.r1.overrides.opacity={enabled=true,value={alpha=0.4}}; e:sync()
    local writes=o.calls.SetPoint; for _=1,5 do tick(e,3.1) end
    assert(o.calls.SetPoint==writes and o.alpha==0.4 and e.stats.errors==0)
    local allowedSize,yes=result(o,"size"); assert(yes and allowedSize.policy.state=="allowed")
    assert(observation(allowedSize,"edit_mode_size_unclassified","target"))
    assert(not pcall(A.write,A,o,"SetPoint","CENTER",UIParent,"CENTER",40,0) and o.calls.SetPoint==writes)
    e:pause(true); EditModeManagerFrame.registeredSystemFrames={}
end)

test("same-object Edit Mode dimension evidence differs from scale, inactive settings and names",function()
    local o=frame("PolicyDimensions"); EditModeManagerFrame.registeredSystemFrames={o}
    local handler=function() error("Inspection must not call a setting handler") end
    EditModeSwingTimerSystemMixin={UpdateSystemSettingWidth=handler}
    Enum.EditModeSwingTimerSetting={Width=1,Height=2,Scale=3}
    o.UpdateSystemSettingWidth=handler; o.settingMap={[3]={value=100}}
    local r,ok=result(o,"size"); assert(ok and observation(r,"edit_mode_size_unclassified"))
    o.settingMap[1]={value=120}; r,ok=result(o,"size"); assert(not ok and r.policy.code=="edit_mode_size")
    local writes=o.calls.SetSize or 0; local e=engine(o,"size",{width=120,height=60},true); e:tick()
    assert((o.calls.SetSize or 0)==writes and e.stats.errors==0); e:pause(true)
    o.UpdateSystemSettingWidth=function() error("Merely having a similar method name is not proof") end
    r,ok=result(o,"size"); assert(ok)
    local e2=engine(o,"size",{width=120,height=60}); e2:tick(); assert(o.width==120 and o.height==60); e2:pause(true)
    o.UpdateSystemSettingWidth=handler; o.settingMap=N.inaccessibleTable
    r,ok=result(o,"size"); assert(ok and observation(r,"edit_mode_size_unclassified"))
    EditModeManagerFrame.registeredSystemFrames={}; EditModeSwingTimerSystemMixin=nil; Enum.EditModeSwingTimerSetting=nil
end)

test("shared markers and heuristics are scoped observations and never invoked",function()
    local parent=frame("PolicyShared"); local o=frame(nil,parent,"Child")
    local function never() error("Do not call optional management methods") end
    parent.IsLayoutFrame=never; parent.Layout=never; o.layoutIndex=2; o.systemInfo={}
    o.SetFixedFrameStrata=never; o.attributes={["UIPanelLayout-defined"]=true}
    local r,ok=result(o,"position"); assert(ok)
    assert(observation(r,"shared_layout_marker","ancestor") and observation(r,"layout_hint","target") and observation(r,"ui_panel_attribute","target"))
    local value=U.copy(P.byID.position.default); value.x=23
    local e=engine(o,"position",value); e:tick(); assert(o.points[1][4]==23 and e.stats.writes==1); e:pause(true)
end)

test("unknown optional metadata never reads secrets or vetoes a permitted setter",function()
    local o=frame("PolicyUnknown"); o.secretAspects.Attributes=true; o.Layout=N.inaccessible; o.systemInfo=N.inaccessibleTable
    local manager=EditModeManagerFrame; EditModeManagerFrame=nil; UIPanelWindows=N.inaccessibleTable
    local r,ok=result(o,"position"); assert(ok and r.management.state=="unknown")
    assert(observation(r,"panel_attributes_unknown","target") and observation(r,"layout_hint_unknown") and observation(r,"edit_mode_registry_unknown"))
    local value=U.copy(P.byID.position.default); value.x=19
    local e=engine(o,"position",value); e:tick(); assert(o.points[1][4]==19 and e.stats.errors==0)
    local text=e:diagnostics(); assert(not text:find("testOnly",1,true)); e:pause(true)
    EditModeManagerFrame=manager; UIPanelWindows=nil
    -- An unknown sibling registration cannot hide an accessible direct match.
    manager.registeredSystemFrames={N.inaccessible,o}; o.OnDragStart=EditModeSystemMixin.OnDragStart
    r,ok=result(o,"position"); assert(not ok and r.policy.code=="edit_mode_position" and observation(r,"edit_mode_entry_unknown"))
    manager.registeredSystemFrames={}
end)

test("unidentified ancestor observation has no fabricated persistent path",function()
    local parent=frame(nil); parent.Layout=function() error("never") end
    local o=frame("PolicyNamedChild",parent)
    local r,ok=result(o,"position"); assert(ok)
    local hint=observation(r,"layout_hint","ancestor"); assert(hint and not hint.object)
    assert(table.concat(U.geometryLines(r),"\n"):find("identity unavailable",1,true))
end)

test("advisory cannot conceal genuine multi-anchor size denial or anchor secrecy",function()
    local o=frame("PolicyMulti"); UIPanelWindows={PolicyMulti={}}; o:SetAllPoints(UIParent)
    local r,ok=result(o,"size"); assert(not ok and r.native.state=="passed" and r.representation.code=="size_multiple_anchors")
    assert(observation(r,"ui_panel_registry") and r.management.advisory)
    local e=engine(o,"size",P.byID.size.default,true); local writes=o.calls.SetSize or 0
    for _=1,4 do tick(e,3.1) end; assert((o.calls.SetSize or 0)==writes and e.stats.errors==0); e:pause(true)
    local value=assert(G.read(A,o)); value.x=12; local e2=engine(o,"position",value,true)
    local clears=o.calls.ClearAllPoints; e2:tick(); assert(G.read(A,o).x==12 and o.calls.ClearAllPoints==clears)
    o.anchorSecret=true; o.GetPoint=function() error("Never read secret anchors") end
    r,ok=result(o,"position",value); assert(not ok and r.native.code=="anchoring_secret" and r.representation.code=="anchor_values_inaccessible")
    local points=o.calls.SetPoint; tick(e2,3.1); assert(o.calls.SetPoint==points and e2.stats.errors==0); e2:pause(true); UIPanelWindows=nil
end)

test("normal hooks and missed-hook verification correct repeated resets without drift",function()
    local o=frame("PolicyNormal"); o:SetAllPoints(UIParent); local cached=o.SetPoint
    UIPanelWindows={PolicyNormal={}}
    local value=assert(G.read(A,o)); value.x=31; value.y=-11
    local e=engine(o,"position",value); local clears=o.calls.ClearAllPoints; e:tick()
    for _=1,5 do
        o:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",0,0); o:SetPoint("TOPLEFT",UIParent,"TOPLEFT",0,0)
        local resetWrites=o.calls.SetPoint; assert(G.read(A,o).x==0)
        tick(e); assert(U.equal(G.read(A,o),value) and o.calls.SetPoint==resetWrites+2)
        assert(not e.states.r1.jobs.position.dirty and e.stats.errors==0)
    end
    cached(o,"BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",0,0); cached(o,"TOPLEFT",UIParent,"TOPLEFT",0,0)
    tick(e,0.2); assert(G.read(A,o).x==0); tick(e,2.1); assert(U.equal(G.read(A,o),value))
    tick(e,2.1); assert(e.states.r1.jobs.position.status=="readable value matched at last check")
    assert(e.states.r1.jobs.position.eligibility.management.advisory and o.calls.ClearAllPoints==clears)
    e:pause(true); UIPanelWindows=nil
end)

test("opted-in periodic application repairs missed notifications and stays bounded",function()
    local o=frame("PolicyPeriodic"); local cached=o.SetPoint; o.layoutIndex=1
    local value=U.copy(P.byID.position.default); value.x=29
    local e=engine(o,"position",value,true); e:tick()
    for _=1,6 do
        cached(o,"CENTER",UIParent,"CENTER",0,0); tick(e,0.3)
        assert(o.points[1][4]==29 and e.stats.errors==0 and not e.states.r1.jobs.position.suspended)
    end
    assert(e.stats.writes==7 and e.states.r1.jobs.position.eligibility.management.advisory)
    e:pause(true)
end)

test("execution-time permission change defers without setter errors or periodic brute force",function()
    local o=frame("PolicyPermissionRace"); o.layoutIndex=1
    local value=U.copy(P.byID.position.default); value.x=33
    -- Definition preflight passes, then the baseline read changes the context.
    local get=o.GetPoint; local reads=0
    o.GetPoint=function(self,...)
        reads=reads+1; if reads==2 then self.protectedAllowed=false end
        return get(self,...)
    end
    local e=engine(o,"position",value,true); local writes=o.calls.SetPoint; e:tick()
    local j=e.states.r1.jobs.position
    assert(o.calls.SetPoint==writes and j.status=="blocked" and j.eligibility.native.code=="protected_denied" and e.stats.errors==0)
    for _=1,5 do tick(e,3.1) end; assert(o.calls.SetPoint==writes and not j.suspended)
    o.GetPoint=get; o.protectedAllowed=true; e:lifecycle(); tick(e,0.2); assert(o.points[1][4]==33)
    e:pause(true)
end)

test("each coordinated setter rechecks permission and prepares all relatives first",function()
    local o=frame("PolicyCoordinated"); o:SetAllPoints(UIParent)
    local value=assert(G.read(A,o)); value.x=20
    local setter=o.SetPoint; local deny=true
    o.SetPoint=function(self,...)
        setter(self,...); if deny then self.protectedAllowed=false end
    end
    local e=engine(o,"position",value,true); local writes=o.calls.SetPoint; e:tick()
    assert(o.calls.SetPoint==writes+1 and e.stats.errors==0 and e.states.r1.jobs.position.status=="blocked")
    deny=false; o.protectedAllowed=true; e:apply("r1"); e:tick(); assert(U.equal(G.read(A,o),value)); e:pause(true)
    -- Unsupported/unresolved later anchors cause ZERO initial mutations.
    local other=frame("PolicyRelative"); o:ClearAllPoints()
    o:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",0,0); o:SetPoint("TOPLEFT",other,"TOPLEFT",0,0)
    value=assert(G.read(A,o)); value.x=10; _G.PolicyRelative=nil
    writes=o.calls.SetPoint
    local ok,err=pcall(G.write,A,o,value)
    assert(not ok and U.isGeometryDeferred(err) and err.eligibility.representation.code=="anchor_relative_unresolved" and o.calls.SetPoint==writes)
    _G.PolicyRelative=other
end)

test("missing required checks and setters stay closed with precise result codes",function()
    local o=frame("PolicyRequired"); o.secretAspects.Attributes=true
    o.IsAnchoringRestricted=false
    local r,ok=result(o,"position"); assert(not ok and r.native.code=="native_check_unavailable")
    o.IsAnchoringRestricted=function() return N.inaccessible end
    r,ok=result(o,"position"); assert(not ok and r.native.state=="inaccessible")
    o.IsAnchoringRestricted=nil; local permissions=C_RestrictedActions; C_RestrictedActions=nil
    r,ok=result(o,"size"); assert(not ok and r.native.code=="protected_check_unavailable"); C_RestrictedActions=permissions
    o.GetNumPoints=function() return N.inaccessible end
    r,ok=result(o,"size"); assert(not ok and r.representation.code=="anchor_count_inaccessible"); o.GetNumPoints=nil
    o.SetSize=false; r,ok=result(o,"size"); assert(not ok and r.native.code=="setter_missing"); o.SetSize=nil
    o.ClearAllPoints=false
    r,ok=result(o,"position"); assert(ok) -- unused setter is not mandatory
    local value=U.copy(P.byID.position.default); value.point="TOP"
    r,ok=result(o,"position",value); assert(not ok and r.native.code=="setter_missing")
end)

test("topology, inaccessible anchors and unresolved relatives retain independent reasons",function()
    local o=frame("PolicyTopology"); o:SetAllPoints(UIParent); local value=assert(G.read(A,o))
    o:SetPoint("LEFT",UIParent,"LEFT",0,0)
    local r,ok=result(o,"position",value); assert(not ok and r.representation.code=="anchor_count_changed")
    o:SetAllPoints(UIParent); o:SetPoint("TOPLEFT",UIParent,"TOP",0,0)
    r,ok=result(o,"position",value); assert(not ok and r.representation.code=="anchor_relationship_changed")
    o.GetPoint=function() return N.inaccessible end
    r,ok=result(o,"position",value); assert(not ok and r.representation.code=="anchor_values_inaccessible")
end)

test("pause, disabled entry/property and deletion stop queued geometry; saved flags survive",function()
    for _,mode in ipairs({"pause","entry","property","delete"}) do
        local o=frame("PolicyStop"..mode); o.layoutIndex=1
        local value=U.copy(P.byID.position.default); value.x=13
        local e,db=engine(o,"position",value,true); e:tick(); o:SetPoint("CENTER",UIParent,"CENTER",0,0)
        if mode=="pause" then e:pause(true)
        elseif mode=="entry" then db.rules.r1.enabled=false; e:sync()
        elseif mode=="property" then db.rules.r1.overrides.position.enabled=false; e:sync()
        else db.rules.r1=nil; e:sync() end
        local writes=o.calls.SetPoint; for _=1,4 do tick(e,3.1) end
        assert(o.calls.SetPoint==writes)
        local saved=FC.Schema.export(db)
        assert(saved.paused==db.paused and U.equal(saved.rules,db.rules)); e:pause(true)
    end
end)

test("reports retain advisory while denied or matched and never reread optional/live data",function()
    local o=frame("PolicyReport"); o.layoutIndex=1
    local value=U.copy(P.byID.position.default); value.x=12
    local e=engine(o,"position",value); e:tick(); tick(e,2.1)
    o.GetPoint=function() error("Report must use cached preflight") end
    o.GetAttribute=function() error("Report must not scan optional metadata") end
    local text=e:diagnostics()
    assert(text:find("Advisory:",1,true) and text:find("readable value matched at last check",1,true) and text:find("layout_hint",1,true))
    o.GetPoint=nil; o.GetAttribute=nil; o.protectedAllowed=false; e:apply("r1"); e:tick()
    text=e:diagnostics(); assert(text:find("protected_denied",1,true) and text:find("Advisory:",1,true) and e.stats.errors==0)
    e:pause(true)
end)

test("execution-time topology change preserves the advisory alongside its representation finding",function()
    local o=frame("PolicyTopologyRace"); o.layoutIndex=1; o:SetAllPoints(UIParent)
    local value=assert(G.read(A,o)); value.x=18
    local get=o.GetPoint; local reads=0
    o.GetPoint=function(self,...)
        reads=reads+1
        local values={get(self,...)}
        if reads==4 then self.points[2][3]="TOP" end -- after baseline read, before writer preparation
        return unpack(values)
    end
    local e=engine(o,"position",value,true); local writes=o.calls.SetPoint; e:tick()
    local j=e.states.r1.jobs.position
    assert(o.calls.SetPoint==writes and j.status=="blocked" and e.stats.errors==0)
    assert(j.eligibility.representation.code=="anchor_relationship_changed" and j.eligibility.management.advisory)
    assert(e:diagnostics():find("layout_hint",1,true)); e:pause(true)
end)

test("missing global layout readiness does not block a known position policy or ordinary edit",function()
    local manager=EditModeManagerFrame; local layout,override=manager.layoutInfo,manager.overrideLayoutInfo
    manager.layoutInfo=nil; manager.overrideLayoutInfo=N.inaccessible
    local o=frame("PolicyUnready"); o.OnDragStart=EditModeSystemMixin.OnDragStart
    manager.registeredSystemFrames={o}
    local r,ok=result(o,"position"); assert(not ok and r.policy.code=="edit_mode_position")
    local child=frame(nil,o,"Child"); local value=U.copy(P.byID.position.default); value.x=16
    local e=engine(child,"position",value); e:tick(); assert(child.points[1][4]==16); e:pause(true)
    manager.registeredSystemFrames={}; manager.layoutInfo=layout; manager.overrideLayoutInfo=override
end)

assert(#N.errors==0,"Unexpected recorder errors: "..table.concat(N.errors,"; "))
print("GEOMETRY POLICY: "..count.." passed (NOT a native WoW run)")
return count
