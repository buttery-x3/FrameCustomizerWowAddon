local _,FC=...
local N,A,P=FC.TestNative,FC.adapter,FC.Properties
local count=0
local function test(name,fn)
    local ok,err=pcall(fn); if not ok then error("FAIL NATIVE-CONTRACT "..name..": "..tostring(err),0) end
    count=count+1; print("PASS NATIVE-CONTRACT "..name)
end
local function texture(name,parent)
    parent=parent or UIParent
    local t=parent:CreateTexture(name,"ARTWORK"); t:SetTexture("Interface\\Buttons\\WHITE8X8"); t:SetPoint("CENTER",parent,"CENTER",0,0); return t
end
test("strict TOC bootstrap and addon initialization",function()
    assert(SlashCmdList.FRAMECUSTOMIZER); assert(not FC.engine)
    N.event("ADDON_LOADED","FrameCustomizer"); assert(FC.engine and FrameCustomizerDB.version==1)
    N.event("PLAYER_LOGIN"); N.advance(0.2); assert(#N.errors==0)
end)
test("object access, forbidden and missing guard fail closed",function()
    local t=texture("NativeGuard"); assert(A:canWrite(t,P.byID.opacity,{alpha=0.2}))
    t.forbidden=true; assert(not A:canWrite(t,P.byID.opacity,{alpha=0.2})); t.forbidden=false
    t.access=false; assert(not A:inspectable(t)); t.access=true
    t.CanBeAccessedInContext=false; assert(not A:inspectable(t)); t.CanBeAccessedInContext=nil
    local saved=canaccessvalue; canaccessvalue=nil; assert(not A:inspectable(t)); canaccessvalue=saved
end)
test("secret-aspect read skipped; cosmetic constant can still write",function()
    local t=texture("NativeSecret"); t.secretAspects.Alpha=true
    assert(not A:canRead(t,P.byID.opacity)); assert(A:canWrite(t,P.byID.opacity,{alpha=0.2}))
    A:write(t,"SetAlpha",0.2); assert(t.alpha==0.2 and not t.calls.GetAlpha)
end)
test("unexpected inaccessible return is discarded before comparison",function()
    local t=texture("NativeReturn"); t.returnSecretAlpha=true
    local ok=A:read(t,"GetAlpha"); assert(not ok)
    local rule={target=FC.Resolver.describe(A,t),enabled=true,periodic=true,interval=1,overrides={opacity={enabled=true,value={alpha=0.2}}}}
    local e=FC.Engine.new(A,{paused=false,rules={r1=rule}}); e:tick(); assert(t.alpha==0.2); assert(not e.states.r1.jobs.opacity.baseline)
    assert(not e:diagnostics():find("testOnly",1,true)); e:pause(true)
end)
test("inaccessible object type cannot become a saved identity",function()
    local t=texture("NativeHiddenType"); t.secretAspects.ObjectType=true
    local target,reason=FC.Resolver.describe(A,t); assert(not target and reason:find("Object type inaccessible",1,true))
end)
test("texture-specific restriction does not block unrelated opacity",function()
    local t=texture("NativeTexture"); t.forbiddenAspects.SetTexture=true
    assert(not A:canWrite(t,P.byID.texture,{kind="file",asset="x"})); assert(A:canWrite(t,P.byID.opacity,{alpha=0.5}))
    t.forbiddenAspects.SetTexture=nil; assert(A:canWrite(t,P.byID.texture,{kind="atlas",asset="KnownAtlas"})); assert(not A:canWrite(t,P.byID.texture,{kind="atlas",asset="UnknownAtlas"}))
end)
test("geometry protects exact operation; unrelated cosmetics remain usable",function()
    local frame=CreateFrame("Frame","GeometryFixture",UIParent); frame:SetPoint("CENTER",UIParent,"CENTER",0,0); A.fixtures[frame]=true
    frame.protectedAllowed=false; assert(not A:canWrite(frame,P.byID.position,P.byID.position.default)); assert(A:canWrite(frame,P.byID.opacity,{alpha=0.5}))
    frame.protectedAllowed=true; assert(A:canWrite(frame,P.byID.position,P.byID.position.default))
    frame.anchorRestricted=true; assert(not A:canWrite(frame,P.byID.position,P.byID.position.default)); frame.anchorRestricted=false
    frame.forbiddenAspects.UntrustedLayoutScriptExecution=true; assert(not A:canWrite(frame,P.byID.size,P.byID.size.default))
end)
test("Edit Mode position policy and advisory metadata leave other properties eligible",function()
    local f=CreateFrame("Frame","ManagedNative",UIParent); f:SetPoint("CENTER",UIParent,"CENTER",0,0); f.userPlaced=true; f.movable=true; f.resizable=true
    assert(A:canWrite(f,P.byID.position,P.byID.position.default))
    f.OnDragStart=EditModeSystemMixin.OnDragStart
    EditModeManagerFrame=CreateFrame("Frame","EditModeManagerFrame",UIParent); EditModeManagerFrame.layoutInfo={}; EditModeManagerFrame.registeredSystemFrames={f}
    assert(not A:canWrite(f,P.byID.position,P.byID.position.default)); assert(A:canWrite(f,P.byID.opacity,{alpha=0.5}))
    EditModeManagerFrame.registeredSystemFrames={}; assert(A:canWrite(f,P.byID.position,P.byID.position.default))
    f.layoutIndex=1; assert(A:canWrite(f,P.byID.size,P.byID.size.default)); f.layoutIndex=nil
    f.userPlaced=false; f.movable=false; f.resizable=false
    assert(A:canWrite(f,P.byID.position,P.byID.position.default)); assert(A:canWrite(f,P.byID.size,P.byID.size.default))
end)
test("statusbar texture changes existing fill without calling bar value APIs",function()
    local b=CreateFrame("StatusBar","NativeBar",UIParent); b:SetStatusBarTexture("old"); b:SetValue(75)
    local count=b.calls.SetStatusBarTexture
    assert(A:canWrite(b,P.byID.barTexture,{asset="new"})); P.byID.barTexture.write(A,b,{asset="new"})
    assert(b.fill.texture=="new" and b.value==75 and b.calls.SetStatusBarTexture==count)
    b.fill.forbiddenAspects.SetTexture=true; assert(not A:canWrite(b,P.byID.barTexture,{asset="new"}))
end)
test("missing native methods fail rather than pretending success",function()
    local t=texture("NativeMissing"); t.SetAlpha=false; assert(not A:canWrite(t,P.byID.opacity,{alpha=0.4}))
    assert(not pcall(function() t:InventedMethod() end))
end)
test("editor construction, selection and refresh do not mutate target",function()
    local t=texture("NativeSelected"); local before=FC.Util.copy(t.calls)
    SlashCmdList.FRAMECUSTOMIZER(""); assert(FC.Editor.frame:IsShown())
    FC.Editor:select(t); FC.Editor:chooseProperty(P.byID.texture); FC.discovery:refresh(); N.advance(0.3)
    for key,n in pairs(t.calls) do if key:sub(1,3)=="Set" then assert(before[key]==n,key.." changed on inspection") end end
    assert(A:excluded(FC.Editor.frame)); assert(not FC.Resolver.describe(A,FC.Editor.frame))
end)
test("editor saves selected values, strategy and per-entry controls",function()
    local ui=FC.Editor; ui:createRule(); assert(ui.id); ui:chooseProperty(P.byID.opacity)
    ui.fields[1].edit:SetText("0.45"); ui:saveProperty(true); N.advance(0.3); assert(ui.object.alpha==0.45)
    ui.mode=3; ui.propInterval:SetText("0.5"); ui:saveProperty(true); assert(ui:rule().overrides.opacity.periodic)
    ui:saveProperty(false); ui.object:SetAlpha(0.9); N.advance(3); assert(ui.object.alpha==0.9)
    SlashCmdList.FRAMECUSTOMIZER("pause"); assert(FrameCustomizerDB.paused); SlashCmdList.FRAMECUSTOMIZER("resume"); assert(not FrameCustomizerDB.paused)
end)
test("discovery bounded slices, lazy expansion and alias failure",function()
    FC.discovery:refresh(); assert(#FC.discovery.nodes==1); FC.discovery:tick(); assert(#FC.discovery.nodes<=17)
    local parent=CreateFrame("Frame","NativeHierarchy",UIParent); local t=texture(nil,parent); t:SetParentKey("Decoration")
    local descriptor=assert(FC.Resolver.describe(A,t)); assert(FC.Resolver.resolve(A,descriptor)==t)
    parent.Alias=t; local bad,why=A:keyChild(parent,"Alias"); assert(not bad and why:find("ambiguous"))
    FC.discovery:reveal(t); assert(FC.discovery.map[t]); FC.Editor:selectPath("NativeHierarchy.Decoration"); assert(FC.Editor.object==t)
end)
test("media fallback, copyable diagnostics and picker event path",function()
    assert(#A:media("font")>=2)
    local t=texture("NativePick"); N.foci={t}; SlashCmdList.FRAMECUSTOMIZER("pick"); FC.Editor:tick()
    assert(FC.Editor.pickCandidate==t); FC.Editor.pickFrame.scripts.OnKeyDown(FC.Editor.pickFrame,"ENTER"); assert(FC.Editor.object==t)
    SlashCmdList.FRAMECUSTOMIZER("report"); assert(FC.Editor.reportFrame:IsShown()); assert(FC.Editor.reportFrame.edit:GetText():find("70124",1,true))
end)
test("native scenario orchestrator uses same engine, cleans up and bounds hooks",function()
    -- This checks the orchestration offline, NOT the truth of native results.
    SlashCmdList.FRAMECUSTOMIZER("test"); N.advance(30); assert(not FC.Playground.run)
    assert(FC.Playground.lastReport and not FC.Playground.lastReport:find("FAIL",1,true),FC.Playground.lastReport)
    local first=N.hooks
    SlashCmdList.FRAMECUSTOMIZER("test"); N.advance(30); assert(not FC.Playground.run)
    assert(not FC.Playground.lastReport:find("FAIL",1,true),FC.Playground.lastReport)
    assert(N.hooks==first,"Repeated test run accumulated hooks")
    assert(not FC.Playground.testFixtures.root:IsShown())
end)
test("native test cancellation during combat cleans up",function()
    SlashCmdList.FRAMECUSTOMIZER("test"); N.combat=true; N.advance(0.1); N.combat=false
    assert(not FC.Playground.run and not FC.Playground.testFixtures.root:IsShown())
end)
test("safe-mode flag persists independently of the editor and schema",function()
    SlashCmdList.FRAMECUSTOMIZER("safe"); assert(FrameCustomizerSafeMode==true and FC.db.paused)
    FC.SetPaused(false); assert(FrameCustomizerSafeMode==false and not FC.db.paused)
end)
assert(#N.errors==0,"Native-contract recorder captured errors: "..table.concat(N.errors,"; "))
print("NATIVE-CONTRACT: "..count.." passed (NOT a native WoW run)")
return count
