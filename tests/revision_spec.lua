-- Regression tests against production modules. The native recorder is not WoW.
local _,FC=...
local A,P,G,U,N=FC.adapter,FC.Properties,FC.Anchors,FC.Util,FC.TestNative
local count=0
local function test(name,fn)
    local ok,err=pcall(fn); if not ok then error("FAIL REGRESSION "..name..": "..tostring(err),0) end
    count=count+1; print("PASS REGRESSION "..name)
end
local function frame(name,parent,key)
    local f=CreateFrame("Frame",name,parent or UIParent)
    if key then f:SetParentKey(key) end
    f:SetPoint("CENTER",parent or UIParent,"CENTER",0,0); return f
end
local function texture(parent,key)
    local t=parent:CreateTexture(nil,"ARTWORK"); if key then t:SetParentKey(key) end
    t:SetTexture("old"); t:SetPoint("CENTER",parent,"CENTER",0,0); return t
end
local function permission(o,d,value,prefix)
    local ok,why=A:canWrite(o,d,value or d.default)
    assert(not ok and why:find(prefix,1,true),tostring(why)); return why
end
local function rule(o,id,value)
    return {target=assert(FC.Resolver.describe(A,o)),enabled=true,periodic=true,interval=0.25,overrides={[id]={enabled=true,value=value}}}
end
local function engine(o,id,value)
    local db={version=1,paused=false,nextID=2,rules={r1=rule(o,id,value)}}
    return FC.Engine.new(A,db),db
end
test("local labels never replace verified persistent paths",function()
    local root=frame("RegressionLongGlobalRoot")
    local child=frame(nil,root,"Content"); local art=texture(child,"Portrait")
    assert(A:label(art)=="Portrait")
    local t=assert(FC.Resolver.describe(A,art)); assert(U.joinTarget(t)=="RegressionLongGlobalRoot.Content.Portrait")
    root.Content.Alias=art; assert(not A:keyChild(child,"Alias"))
    local d=FC.Discovery.new(A); local node=d:reveal(art)
    assert(node.label=="Portrait" and node.path==U.joinTarget(t) and node.kind=="Texture")
    local anonymous=texture(child); local anon=d:reveal(anonymous)
    assert(not anon.path and anon.identityReason and anon.label~="")
end)
test("search prunes a tree, retains ancestry and meaningful collapse",function()
    local root=frame("RegressionExplorer"); local a=frame(nil,root,"Left"); local b=frame(nil,root,"Right")
    local t=texture(a,"Needle"); local unrelated=texture(b,"Other")
    local d=FC.Discovery.new(A); local rn=d:add(root); local an=d:add(a,rn); local bn=d:add(b,rn)
    local tn=d:add(t,an); d:add(unrelated,bn); rn.expanded=true; an.expanded=false; bn.expanded=true
    local rows=d:rows("needle"); assert(#rows==3 and rows[1]==rn and rows[2]==an and rows[3]==tn)
    d:expand(an); rows=d:rows("needle"); assert(#rows==2 and not d:isExpanded(an))
    d:expand(an); assert(#d:rows("needle")==3)
    d:expand(rn); assert(#d:rows("needle")==1)
    rows=d:rows(""); assert(rn.expanded and not an.expanded and bn.expanded and #rows==4)
    assert(#d:rows("RegressionExplorer.Left.Needle")==3)
    assert(#d:rows("Texture")==5)
end)
test("scan discoveries stay beneath their ancestors without mutating normal expansion",function()
    local root=frame("RegressionScan"); local branch=frame(nil,root,"Branch"); local t=texture(branch,"DeepNeedle")
    local d=FC.Discovery.new(A); local rn=d:add(root); rn.expanded=false
    assert(#d:rows("deepneedle")==0); d:scan()
    for _=1,20 do d:tick() end
    local rows=d:rows("deepneedle"); assert(#rows==3 and rows[3].object==t and rows[3].parent.object==branch)
    d:expand(rows[2]); assert(#d:rows("deepneedle")==2)
    assert(#d:rows("")==1 and not rn.expanded)
end)
test("filtered leaf results do not pretend to have expandable matching children",function()
    local root=frame("RegressionLeafSearch"); local branch=frame(nil,root,"DistinctBranch"); texture(branch,"Other")
    local d=FC.Discovery.new(A); d:add(root); d:scan(); for _=1,20 do d:tick() end
    local rows=d:rows("Frame"); assert(#rows==2 and rows[2].object==branch)
    assert(rows[2].loaded and not rows[2].filterHasChildren and not d:isExpanded(rows[2]))
end)
test("selection reveals discovered ancestors, scrolls into view and exposes copy path",function()
    local root=frame("RegressionSelection"); local d=FC.discovery
    local node=d:reveal(root); node.expanded=false
    local last
    for i=1,45 do last=texture(root,"Item"..i); d:add(last,node) end
    local ui=FC.Editor; ui.saved=false; ui.search:SetText(""); ui.offset=0; ui:select(last); ui:renderRows()
    assert(node.expanded and ui.offset>0)
    local selected
    for _,b in ipairs(ui.rowsPool) do if b.node and b.node.object==last and b:IsShown() then selected=b end end
    assert(selected and selected.selected:IsShown() and selected.text:GetText()=="Item45")
    selected.scripts.OnEnter(); assert(ui.tip.text:GetText():find("RegressionSelection.Item45",1,true)); selected.scripts.OnLeave()
    ui.search:SetText("does not match anything"); ui:renderRows(); assert(ui.count:GetText():find("0 / 0",1,true)); ui.search:SetText("")
end)

local paths={font="Fonts\\ARIALN.TTF",statusbar="Interface\\Buttons\\WHITE8X8",background="Interface\\DialogFrame\\UI-DialogBox-Background"}
local function installMedia()
    local lib={}
    function lib:List(kind) return {"Friendly "..kind} end
    function lib:Fetch(kind,name,noDefault) assert(noDefault==true and name=="Friendly "..kind); return paths[kind] end
    LibStub={GetLibrary=function(_,name,silent) assert(name=="LibSharedMedia-3.0" and silent); return lib,123 end}
    return lib
end
test("media detection supports embedded LibStub and resolves each appropriate media type",function()
    installMedia()
    for _,kind in ipairs({"font","statusbar","texture"}) do
        local list,info=A:media(kind); assert(info.available and info.revision==123)
        assert(info.count==(kind=="texture" and 2 or 1))
        for _,item in ipairs(list) do if item.source=="SharedMedia" then assert(item[2]==paths[item.mediaType]) end end
    end
    LibStub=nil; local _,info=A:media("font"); assert(not info.available and info.summary:find("LibStub not loaded",1,true))
end)
test("media gracefully handles absent, malformed and failing libraries and inaccessible entries",function()
    local function builtinOnly(stub)
        LibStub=stub; local list,info=A:media("font"); assert(#list==2 and not info.available)
    end
    builtinOnly(nil); builtinOnly({}); builtinOnly(function() error("external error") end); builtinOnly(function() return nil end)
    local lib=installMedia(); lib.List=function() return N.inaccessibleTable end
    local list,info=A:media("font"); assert(#list==2 and info.summary:find("enumeration failed",1,true))
    lib.List=function() return {N.inaccessible,"bad","missing","good"} end
    lib.Fetch=function(_,_,key) if key=="bad" then error("bad asset") elseif key=="good" then return paths.font end end
    list,info=A:media("font"); assert(info.count==1 and info.skipped==3 and #list==3)
    LibStub=nil
end)
test("media enumerates on demand for late registrations and has bounded lists",function()
    local lib=installMedia(); local list,info=A:media("font"); assert(info.count==1)
    lib.List=function() local out={}; for i=1,1005 do out[i]="asset"..i end; return out end
    lib.Fetch=function() return paths.font end
    list,info=A:media("font"); assert(info.count==1000 and info.capped and #list==1002)
    local fallback,off=A:media("font",true); assert(#fallback==2 and not off.available and LibStub)
    LibStub=nil
end)
test("media picker displays sources, searches paths, resets atlas kind and saves actual files",function()
    installMedia(); local root=frame("RegressionMediaEditor"); local t=texture(root,"Art")
    local ui=FC.Editor; ui:select(t); ui:createRule(); ui:chooseProperty(P.byID.texture)
    ui.fields[1].edit:SetText("atlas"); ui:media(ui.fields[2])
    local picker=ui.listFrame; assert(picker.summary:GetText():find("detected",1,true))
    picker.source.scripts.OnClick(); assert(picker.sourceIndex==2)
    picker.search:SetText("Friendly background"); assert(picker.rows[1].item.source=="SharedMedia")
    picker.rows[1].scripts.OnClick(picker.rows[1]); assert(ui.fields[1].edit:GetText()=="file")
    assert(ui.fields[2].edit:GetText()==paths.background and ui.fields[2].label:GetText():find("SharedMedia",1,true))
    ui:saveProperty(true); N.advance(0.3)
    assert(ui:rule().overrides.texture.value.asset==paths.background and t.texture==paths.background)
    ui:media(ui.fields[2]); picker.search:SetText("Transparent"); assert(picker.rows[1].item[2]==FC.BLANK_TEXTURE)
    picker.rows[1].scripts.OnClick(picker.rows[1]); ui:saveProperty(true); N.advance(0.3); assert(t.texture==FC.BLANK_TEXTURE)
    ui:saveProperty(false); LibStub=nil
end)
test("font and statusbar pickers route their resolved media through persistence and application",function()
    installMedia(); local root=frame("RegressionMediaTypes"); local text=root:CreateFontString(nil,"OVERLAY"); text:SetParentKey("Text")
    local bar=CreateFrame("StatusBar",nil,root); bar:SetParentKey("Bar"); bar:SetStatusBarTexture("old"); bar:SetValue(75)
    local ui=FC.Editor
    for _,pair in ipairs({{text,"font",1},{bar,"barTexture",1}}) do
        ui:select(pair[1]); ui:createRule(); ui:chooseProperty(P.byID[pair[2]]); ui:media(ui.fields[pair[3]])
        local picker=ui.listFrame; picker.search:SetText("Friendly"); picker.rows[1].scripts.OnClick(picker.rows[1]); ui:saveProperty(true)
        local exported=FC.Schema.export(FC.db); assert(exported.rules[ui.id])
        N.advance(0.3)
        if pair[2]=="font" then assert(text.font[1]==paths.font) else assert(bar.fill.texture==paths.statusbar and bar.value==75) end
        ui:saveProperty(false)
    end
    LibStub=nil
end)
test("native fixture suite exercises real media path with optional LSM and fallback orchestration",function()
    installMedia(); FC.Playground:startTests(); N.advance(25)
    local report=FC.Playground.lastReport; assert(not report:find("FAIL",1,true),report)
    assert(report:find("PASS SharedMedia font selection",1,true))
    assert(report:find("PASS Unavailable-library fallback",1,true))
    assert(report:find("PASS Sibling and multiple anchor translation",1,true)); LibStub=nil
end)

test("geometry accepts non-user-placed nonmovable objects when native and ownership gates pass",function()
    local f=frame("RegressionOrdinaryPanel"); assert(not f:IsMovable() and not f:IsUserPlaced())
    assert(A:canWrite(f,P.byID.position,P.byID.position.default)); assert(A:canWrite(f,P.byID.size,P.byID.size.default))
    local t=texture(f,"Decoration"); assert(A:canWrite(t,P.byID.size,P.byID.size.default))
    f.GetNumPoints=function() return 0 end; assert(A:canWrite(f,P.byID.size,P.byID.size.default))
    permission(f,P.byID.position,nil,"Unsupported layout:")
end)
test("geometry distinguishes native denial, secret/inaccessible checks and conservative policy",function()
    local f=frame("RegressionReasons")
    f.protectedAllowed=false; permission(f,P.byID.position,nil,"Native restriction:"); f.protectedAllowed=true
    f.anchorSecret=true; permission(f,P.byID.position,nil,"Inaccessible:"); f.anchorSecret=false
    f.IsAnchoringRestricted=false; permission(f,P.byID.position,nil,"Safety policy:"); f.IsAnchoringRestricted=nil
    local manager=EditModeManagerFrame; EditModeManagerFrame=nil; permission(f,P.byID.position,nil,"Safety policy:"); EditModeManagerFrame=manager
    f.layoutIndex=1; permission(f,P.byID.position,nil,"Safety policy:"); f.layoutIndex=nil
    f.secretAspects.Attributes=true; permission(f,P.byID.position,nil,"Inaccessible:"); f.secretAspects.Attributes=nil
    assert(A:canWrite(f,P.byID.opacity,{alpha=0.2}))
    f.HasAnyForbiddenAspects=function() return nil end; permission(f,P.byID.position,nil,"Safety policy:"); f.HasAnyForbiddenAspects=nil
end)
test("Edit Mode and generic panel/shared layout metadata block geometry independently of cosmetics",function()
    local root=frame("RegressionManagers"); local t=texture(root,"Art")
    EditModeManagerFrame.registeredSystemFrames={root}
    permission(t,P.byID.position,nil,"Managed layout: Edit Mode"); assert(A:canWrite(t,P.byID.opacity,{alpha=0.2}))
    EditModeManagerFrame.registeredSystemFrames={}; UIPanelWindows={RegressionManagers={area="left"}}
    permission(root,P.byID.position,nil,"Managed layout: Blizzard UI panel registry")
    UIPanelWindows=nil; root.attributes={["UIPanelLayout-defined"]=true}; permission(root,P.byID.size,nil,"Managed layout:")
    root.attributes=nil; root.IsLayoutFrame=function() error("Do not call arbitrary layout methods") end
    permission(t,P.byID.position,nil,"Managed layout:"); root.IsLayoutFrame=nil
end)
test("sibling-relative single anchor persists identity and applies without clearing points",function()
    local root=frame("RegressionSibling"); local relative=texture(root,"Reference"); local t=texture(root,"Target")
    t:ClearAllPoints(); t:SetPoint("TOPLEFT",relative,"TOPRIGHT",12,5)
    local v=assert(G.read(A,t)); assert(v.anchors and v.anchors[1].relative.keys[1]=="Reference")
    v.x=28; local clears=t.calls.ClearAllPoints
    assert(A:canWrite(t,P.byID.position,v)); G.write(A,t,v)
    assert(t.calls.ClearAllPoints==clears and t:GetNumPoints()==1 and t.points[1][2]==relative and t.points[1][4]==28)
end)
test("multiple anchors translate together, preserve spacing and survive schema round trip",function()
    local root=frame("RegressionMulti"); local t=texture(root,"Stretch"); t:SetAllPoints(root)
    local v=assert(G.read(A,t)); assert(#v.anchors==2); v.x=30; v.y=-15
    local e,db=engine(t,"position",v); db.rules.r1.periodic=false; db=FC.Schema.export(db); assert(U.equal(db.rules.r1.overrides.position.value,v))
    local before=t.calls.ClearAllPoints; e:tick(); assert(t.calls.ClearAllPoints==before and #t.points==2)
    assert(U.equal(G.read(A,t),v)); N.time=N.time+2.1; e:tick(); assert(e.states.r1.jobs.position.status=="readable value matched at last check")
    local restored=e:undo("r1"); assert(restored==1); local current=G.read(A,t); assert(current.x==0 and current.y==0 and #current.anchors==2)
    permission(t,P.byID.size,nil,"Unsupported layout:")
end)
test("legacy position values retain parent semantics and never flatten a complex layout",function()
    local root=frame("RegressionLegacy"); local t=texture(root,"Target"); local v={point="TOP",relativePoint="TOP",x=12,y=-5}
    assert(not G.validate(v).anchors); assert(A:canWrite(t,P.byID.position,v)); G.write(A,t,v)
    assert(t:GetNumPoints()==1 and U.equal(G.read(A,t),v))
    t:SetAllPoints(root); permission(t,P.byID.position,v,"Unsupported layout: legacy")
end)
test("unsupported relatives, malformed anchors, duplicate points and ranges fail explicitly",function()
    local root=frame("RegressionUnsupported"); local relative=texture(root); local t=texture(root,"Target")
    t:ClearAllPoints(); t:SetPoint("CENTER",relative,"CENTER",0,0)
    local v,why=G.read(A,t); assert(not v and why:find("no stable identity",1,true))
    t:SetAllPoints(root); v=assert(G.read(A,t)); local bad=U.copy(v); bad.anchors[2].point=bad.anchors[1].point; assert(not G.validate(bad))
    bad=U.copy(v); bad.anchors[2].relative={root="bad path",keys={},types={"Texture"}}; assert(not G.validate(bad))
    bad=U.copy(v); bad.anchors[2].dx=9000; assert(not G.validate(bad))
    bad=U.copy(v); bad.point="TOP"; assert(not G.validate(bad))
    t.GetPoint=function() return N.inaccessible end; local _,reason=G.snapshot(A,t); assert(reason:find("Inaccessible",1,true))
end)
test("changed anchor topology and relative type block periodic writes without brute force",function()
    local root=frame("RegressionTopology"); local relative=texture(root,"Reference"); local t=texture(root,"Target")
    t:ClearAllPoints(); t:SetPoint("LEFT",relative,"RIGHT",10,0)
    local v=assert(G.read(A,t)); v.x=20; local e=engine(t,"position",v); e:tick()
    relative.kind="FontString"; local writes=t.calls.SetPoint
    for _=1,20 do N.time=N.time+1; e:tick() end
    assert(t.calls.SetPoint==writes and e.states.r1.jobs.position.reason:find("Unsupported layout:",1,true))
    relative.kind="Texture"; e:apply("r1"); e:tick(); assert(t.calls.SetPoint>writes)
    t:SetAllPoints(root); writes=t.calls.SetPoint; N.time=N.time+4; e:tick(); assert(t.calls.SetPoint==writes)
    e:pause(true)
end)
test("relative forbidden layout, current protected permission and per-setter rechecks stop writes",function()
    local root=frame("RegressionNativeGates"); local relative=texture(root,"Reference"); local t=texture(root,"Target")
    t:ClearAllPoints(); t:SetPoint("LEFT",relative,"RIGHT",10,0); local v=assert(G.read(A,t)); v.x=20
    relative.forbiddenAspects.UntrustedLayoutScriptExecution=true; permission(t,P.byID.position,v,"Native restriction:")
    relative.forbiddenAspects.UntrustedLayoutScriptExecution=nil
    local e=engine(t,"position",v); t.protectedAllowed=false; local writes=t.calls.SetPoint
    for _=1,10 do N.time=N.time+1; e:tick() end
    assert(t.calls.SetPoint==writes and e.stats.errors==0)
    t.protectedAllowed=true; e:lifecycle(); N.time=N.time+0.2; e:tick(); assert(t.calls.SetPoint>writes)
    e:pause(true); t.protectedAllowed=false
    assert(not pcall(A.write,A,t,"SetPoint","LEFT",relative,"RIGHT",50,0)); assert(t.points[1][4]==20)
end)
test("editor retains anchor snapshots while editing and recaptures only disabled positions",function()
    local root=frame("RegressionGeometryEditor"); local t=texture(root,"Target"); t:SetAllPoints(root)
    local ui=FC.Editor; ui:select(t); ui:createRule(); ui:chooseProperty(P.byID.position)
    assert(ui.positionAnchors and #ui.positionAnchors==2)
    ui.anchorDetails.scripts.OnClick(); assert(ui.reportFrame.edit:GetText():find("parent.BOTTOMRIGHT",1,true)); ui.reportFrame:Hide()
    ui.fields[3].edit:SetText("18"); ui:saveProperty(true); N.advance(0.3)
    assert(ui:rule().overrides.position.value.anchors and G.read(A,t).x==18)
    ui:saveProperty(false); t:ClearAllPoints(); t:SetPoint("LEFT",root,"LEFT",5,0); ui:chooseProperty(P.byID.position)
    assert(not ui.positionAnchors and ui.fields[3].edit:GetText()=="5")
end)
test("editor refuses uncaptured secret position but still permits configured cosmetics",function()
    local root=frame("RegressionSecretPosition"); local t=texture(root,"Target"); t.anchorSecret=true
    local ui=FC.Editor; ui:select(t); ui:createRule(); ui:chooseProperty(P.byID.position); ui:saveProperty(true)
    assert(not ui:rule().overrides.position and ui.messageText:find("readable anchor snapshot",1,true))
    ui:chooseProperty(P.byID.opacity); ui.fields[1].edit:SetText("0.5"); ui:saveProperty(true); N.advance(0.3); assert(t.alpha==0.5)
    ui:saveProperty(false)
end)
test("diagnostics report media detection and validated anchors without reading live geometry",function()
    local root=frame("RegressionDiagnostics"); local t=texture(root,"Target"); t:SetAllPoints(root)
    local e=engine(t,"position",assert(G.read(A,t))); t.GetPoint=function() error("No diagnostic live read") end
    local report=e:diagnostics(); assert(report:find("preserved",1,true))
    assert(A:mediaDiagnostics():find("LibSharedMedia unavailable",1,true)); e:pause(true)
end)
test("saved entries still render and select with the hierarchy navigation changes",function()
    local ui=FC.Editor; ui.saved=true; ui.search:SetText(""); ui.offset=0; ui:renderRows()
    local b=ui.rowsPool[1]; assert(b.node.id and b:IsShown() and not b.arrow:IsShown())
    b.scripts.OnClick(b); ui:renderRows(); assert(ui.id==b.node.id)
    b.scripts.OnEnter(); assert(ui.tip:IsShown()); b.scripts.OnLeave(); ui.saved=false
end)
assert(#N.errors==0,"Regression recorder errors: "..table.concat(N.errors,"; "))
print("REGRESSION: "..count.." passed (NOT a native WoW run)")
return count
