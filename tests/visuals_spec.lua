local _,FC=...
local U,V,S,P,R,N,UI=FC.Util,FC.Visuals,FC.Schema,FC.Properties,FC.Resolver,FC.TestNative,FC.Editor
local count=0
local function test(name,fn)
    local ok,why=pcall(fn); if not ok then error("FAIL VISUALS "..name..": "..tostring(why),0) end
    count=count+1; print("PASS VISUALS "..name)
end
local function equal(a,b) assert(U.equal(a,b),"values differ") end
local function setup()
    local a=FC.NativeAdapter.new(); local db=S.load(nil); local c=V.new(a,db); local e=FC.Engine.new(a,db)
    return a,db,c,e
end
local function advance(c,e,seconds)
    for _=1,math.ceil((seconds or 0.4)/0.05) do N.time=N.time+0.05; local work=c:tick(); e:tick(FC.LIMITS.jobs-work) end
end
local function save(c,e,v) local id=assert(c:save(nil,v or V.default())); e:sync(); advance(c,e); return id,assert(c.slots[id]) end
local function frame(name)
    local f=CreateFrame("Frame",name,UIParent); f:SetSize(240,60); f:SetPoint("CENTER",UIParent,"CENTER",0,0); f:SetFrameLevel(5); return f
end
test("version 1 migrates without altering saved values or pause flags",function()
    local raw={version=1,nextID=71,paused=true,rules={r2={target={root="Example",keys={},types={"Texture"}},enabled=false,periodic=true,interval=4,
        overrides={opacity={enabled=false,value={alpha=0.4},periodic=false,interval=7}}}}}
    local before=U.copy(raw); local db,w,readonly=S.load(raw)
    assert(db.version==2 and not readonly and #w==0 and db.paused and db.nextID==71)
    equal(db.rules,raw.rules); equal(raw,before); equal(S.export(db),db)
end)
test("schema round trip validates visuals and never reuses deleted IDs",function()
    local _,db,c=setup(); local id=assert(c:save(nil,V.default())); c:delete(id)
    local new=S.load(db); assert(new.nextVisualID==2)
    db.visuals.v4=V.default(); db.visuals.v5=V.default(); db.visuals.v5.layout.width=0/0
    local out,w=S.load(db); assert(out.visuals.v4 and not out.visuals.v5 and #w==1)
    local future={version=3,visuals={untouched=true}}; local _,_,readonly=S.load(future); assert(readonly and future.visuals.untouched)
end)
test("malformed structure preserves original database read-only",function()
    local raw={version=2,paused=false,rules={},visuals="broken"}; local db,_,readonly=S.load(raw); assert(readonly and db.paused and raw.visuals=="broken")
    local failed,_,locked=S.load({version=1,paused=false}); assert(locked and failed.paused)
    local v=V.default(); v.target=V.target("v1","frame"); v.placement="target"; assert(not V.validate(v))
    v=V.default(); v.layout.mode="fill"; assert(not V.validate(v)); v=V.default(); v.layerMode="behind"; assert(not V.validate(v))
end)
test("independent panel creates click-through components with stable owned identities",function()
    local a,db,c,e=setup(); local id,s=save(c,e)
    assert(s.ready,s.status); assert(s.frame:IsShown()); assert(s.frame:GetParent()==UIParent)
    assert(s.frame.presentation.EnableMouse[1]==false and s.frame.fixedLevel and s.frame.fixedStrata)
    equal({s.frame:GetSize()},{300,100}); equal({s.texture:GetVertexColor()},{0,0,0,1})
    equal(R.describe(a,s.frame),V.target(id,"frame")); assert(R.resolve(a,V.target(id,"texture"))==s.texture)
    local infrastructure=CreateFrame("Frame",nil,UIParent); a.owned[infrastructure]=true
    assert(not a:excluded(s.texture) and a:excluded(infrastructure)); assert(not S.target(V.target(id,"frame")))
    local copy=S.load(db); equal(copy.visuals,db.visuals); assert(not copy.visuals[id].frame)
    e:pause(true)
end)
test("fill and fixed attachment modes preserve target geometry and avoid its alpha",function()
    local a,_,c,e=setup(); local f=frame("VisualTargetA"); f:SetAlpha(0)
    local before=U.copy(f.calls); local v=V.default(R.describe(a,f)); v.layout.left=-2; v.layout.right=4
    local id,s=save(c,e,v); assert(s.ready,s.status); assert(s.frame:GetParent()==UIParent)
    equal(s.frame.points[1],{"TOPLEFT",f,"TOPLEFT",-2,0}); equal(s.frame.points[2],{"BOTTOMRIGHT",f,"BOTTOMRIGHT",-4,0})
    assert(s.frame.level==4 and s.frame.strata==f:GetFrameStrata()); equal(f.calls,before)
    v.layout.mode="fixed"; v.layout.width=500; v.layout.height=60
    assert(c:save(id,v)); e:sync(); advance(c,e); equal({s.frame:GetSize()},{500,60}); assert(#s.frame.points==1)
    f:SetFrameLevel(9); advance(c,e); assert(s.frame.level==8)
    e:pause(true)
end)
test("region attachment follows its containing frame and optional distinct visibility container",function()
    local a,_,c,e=setup(); local f=frame("VisualRegionRoot"); local t=f:CreateTexture(nil,"ARTWORK"); t:SetParentKey("Art")
    local v=V.default(R.describe(a,t)); local id,s=save(c,e,v); assert(s.ready,s.status)
    assert(s.target==t and s.container==f); f:Hide(); advance(c,e); assert(not s.frame:IsShown()); f:Show(); advance(c,e); assert(s.frame:IsShown())
    local other=frame("VisualVisibility"); v.container=R.describe(a,other); assert(c:save(id,v)); e:sync(); advance(c,e)
    f:Hide(); advance(c,e); assert(s.frame:IsShown()); other:Hide(); advance(c,e); assert(not s.frame:IsShown())
    e:pause(true)
end)
test("missing and replaced attachment slots hide then rebind without duplicates",function()
    local a,_,c,e=setup(); local f=frame("VisualLate"); local v=V.default(R.describe(a,f)); _G.VisualLate=nil
    local id,s=save(c,e,v); assert(not s.frame and s.status:find("unresolved"))
    _G.VisualLate=f; advance(c,e); assert(s.ready,s.status); local owned=s.frame
    _G.VisualLate=nil; advance(c,e); assert(not s.ready and not owned:IsShown())
    local replacement=frame("VisualLate"); advance(c,e); assert(s.ready and s.frame==owned and s.target==replacement and c.allocated==1)
    e:pause(true)
end)
test("secret visibility and levels are never read around their aspect checks",function()
    local a,_,c,e=setup(); local f=frame("VisualSecrets"); local v=V.default(R.describe(a,f))
    local id,s=save(c,e,v); assert(s.ready)
    f.secretAspects.Shown=true; advance(c,e); assert(not s.frame:IsShown() and s.status:find("visibility")); f.secretAspects.Shown=nil
    f.secretAspects.FrameLevel=true; advance(c,e); assert(not s.frame:IsShown() and s.status:find("level")); f.secretAspects.FrameLevel=nil
    f:SetFrameLevel(0); advance(c,e); assert(s.status:find("no lower level"))
    v.layerMode="manual"; assert(c:save(id,v)); e:sync(); advance(c,e); assert(s.ready and s.frame:IsShown())
    e:pause(true)
end)
test("native relative denial blocks geometry without treating Edit Mode ancestry as a veto",function()
    local a,_,c,e=setup(); local f=frame("VisualPolicy"); f.OnDragStart=EditModeSystemMixin.OnDragStart
    local old=EditModeManagerFrame; EditModeManagerFrame={registeredSystemFrames={f}}
    local v=V.default(R.describe(a,f)); local id,s=save(c,e,v); assert(s.ready,s.status)
    f.forbiddenAspects.UntrustedLayoutScriptExecution=true
    local writes=s.frame.calls.SetPoint; c:changed(); s.verify=0; advance(c,e)
    assert(not s.ready and not s.frame:IsShown()); assert(s.frame.calls.SetPoint==writes)
    f.forbiddenAspects.UntrustedLayoutScriptExecution=nil; advance(c,e); assert(s.ready)
    EditModeManagerFrame=old; e:pause(true)
end)
test("pause deletion and disabled visuals retire with pending cleanup and safe reuse",function()
    local _,db,c,e=setup(); local id,s=save(c,e); local f=s.frame
    f.protectedAllowed=false; c:delete(id); e:sync(); advance(c,e)
    assert(c.slots[id] and c.slots[id].status:find("pending removal") and not s.ready and f:IsShown())
    f.protectedAllowed=true; advance(c,e); assert(not c.slots[id] and not f:IsShown() and #f.points==0)
    local id2,s2=save(c,e); assert(s2.frame==f and c.allocated==1)
    db.paused=true; e:pause(true); c:changed(); advance(c,e); assert(not c.slots[id2] and not f:IsShown())
    db.paused=false; e:pause(false); c:changed(); advance(c,e); assert(c.slots[id2].ready and c.allocated==1)
    db.visuals[id2].enabled=false; c:changed(); e:sync(); advance(c,e); assert(not c.slots[id2])
    e:pause(true)
end)
test("duplicate and repeated add delete cycles bound allocations and subscriptions",function()
    local _,_,c,e=setup(); local id=save(c,e); local dup=assert(c:duplicate(id)); e:sync(); advance(c,e)
    assert(dup~=id and c.slots[dup].frame~=c.slots[id].frame)
    c:delete(dup); c:delete(id); e:sync(); advance(c,e)
    local hooks=N.hooks
    for _=1,12 do local nextID=save(c,e); c:delete(nextID); e:sync(); advance(c,e) end
    assert(c.allocated==2 and #c.pool==2 and N.hooks==hooks)
    e:pause(true)
end)
test("shared layer properties enforce constants and recheck every protected setter",function()
    local a=FC.NativeAdapter.new(); local f=frame("VisualLayerProperty")
    local v={strata="HIGH",level=17}; assert(a:canWrite(f,P.byID.frameLayer,v)); P.byID.frameLayer.write(a,f,v)
    equal(P.byID.frameLayer.read(a,f),v)
    f.secretAspects.FrameLevel=true; assert(not a:canRead(f,P.byID.frameLayer)); assert(a:canWrite(f,P.byID.frameLayer,v)); f.secretAspects.FrameLevel=nil
    local setter=f.SetFrameStrata
    f.SetFrameStrata=function(o,x) setter(o,x); o.protectedAllowed=false end
    local level=f.level; local ok,err=pcall(P.byID.frameLayer.write,a,f,{strata="LOW",level=21})
    assert(not ok and U.isGeometryDeferred(err) and f.level==level)
    f.SetFrameStrata=setter; f.protectedAllowed=true
    local t=f:CreateTexture(nil,"ARTWORK"); P.byID.drawLayer.write(a,t,{layer="BORDER",sublevel=-2}); equal(P.byID.drawLayer.read(a,t),{layer="BORDER",sublevel=-2})
end)
test("owned layers unlock for saved changes and shared enforcement then restore locks",function()
    local a,db,c,e=setup(); local id,s=save(c,e); local f=s.frame
    -- Opt-in refusal models a setter being ignored while fixed; not a claim
    -- that the recorder implements the client's native layering semantics.
    f.ignoreFixedLayerWrites=true
    local v=U.copy(db.visuals[id]); v.style.frameLayer={strata="HIGH",level=37}
    assert(c:save(id,v)); e:sync(); advance(c,e)
    equal(P.byID.frameLayer.read(a,f),v.style.frameLayer); assert(s.ready and f.fixedStrata and f.fixedLevel)
    -- An external writer bypasses hooks; shared readable verification repairs it.
    f.strata="LOW"; f.level=2
    for _=1,60 do N.time=N.time+0.05; e:tick() end
    equal(P.byID.frameLayer.read(a,f),v.style.frameLayer); assert(f.fixedStrata and f.fixedLevel)
    local target=frame("VisualFixedBehind"); v=V.default(R.describe(a,target)); assert(c:save(id,v)); e:sync(); advance(c,e)
    target:SetFrameStrata("DIALOG"); target:SetFrameLevel(19); advance(c,e)
    assert(s.ready and f.strata=="DIALOG" and f.level==18 and f.fixedStrata and f.fixedLevel)
    assert(not target.fixedStrata and not target.fixedLevel)
    e:pause(true)
end)

test("owned layer writes stop on mid-sequence denial and recover a pending lock",function()
    local a,db,c,e=setup(); local id,s=save(c,e); local f=s.frame
    local fixed,level=f.SetFixedFrameLevel,f.SetFrameLevel
    f.SetFixedFrameLevel=function(o,v) fixed(o,v); if not v then o.protectedAllowed=false end end
    local old=f.level; local calls=f.calls.SetFrameLevel
    local ok,err=pcall(a.write,a,f,"SetFrameLevel",42)
    assert(not ok and U.isGeometryDeferred(err) and f.level==old and f.calls.SetFrameLevel==calls and not f.fixedLevel)
    f.SetFixedFrameLevel=fixed; f.protectedAllowed=true; c:changed(); s.verify=0; advance(c,e)
    assert(s.ready and f.fixedLevel)
    -- Permission can also change after the value lands, before the relock.
    f.SetFrameLevel=function(o,v) level(o,v); o.protectedAllowed=false end
    ok,err=pcall(a.write,a,f,"SetFrameLevel",old)
    assert(not ok and U.isGeometryDeferred(err) and not f.fixedLevel)
    f.SetFrameLevel=level; f.protectedAllowed=true; c:changed(); s.verify=0; advance(c,e)
    assert(s.ready and f.fixedLevel and (s.errors or 0)==0)
    f.SetFrameLevel=function() error("injected layer write error") end
    ok,err=pcall(a.write,a,f,"SetFrameLevel",old)
    assert(not ok and tostring(err):find("injected layer write error") and f.fixedLevel)
    f.SetFrameLevel=level
    e:pause(true)
end)

test("visual layer readback exposes ignored setters instead of reporting active",function()
    local _,db,c,e=setup(); local id,s=save(c,e); local f=s.frame; local setter=f.SetFrameStrata
    f.SetFrameStrata=function() end
    local v=U.copy(db.visuals[id]); v.style.frameLayer.strata="HIGH"; assert(c:save(id,v)); e:sync(); advance(c,e)
    assert(not s.ready and not f:IsShown() and s.status:find("did not match") and (s.errors or 0)==0)
    f.SetFrameStrata=setter; advance(c,e); assert(s.ready and f:IsShown() and f.strata=="HIGH")
    f.secretAspects.FrameLevel=true; s.verify=0; c:changed(); advance(c,e)
    assert(not s.ready and s.status:find("verification") and not f:IsShown())
    f.secretAspects.FrameLevel=nil; advance(c,e); assert(s.ready)
    e:pause(true)
end)

test("saved visual diagnostics inspect no live values",function()
    local _,_,c,e=setup(); local id,s=save(c,e)
    s.frame.GetFrameLevel=function() error("diagnostics must not read") end
    s.frame.IsVisible=function() error("diagnostics must not read") end
    assert(c:diagnostics():find(id)); assert(e:diagnostics():find("visual:"..id))
    e:pause(true)
end)
test("partial creation denial retains one allocation and safely finishes or retires",function()
    local a,_,c,e=setup(); local original=CreateFrame
    CreateFrame=function(...)
        local f=original(...); f.protectedAllowed=false; return f
    end
    local id,s=save(c,e); CreateFrame=original
    assert(s.frame and not s.texture and not s.ready and c.allocated==1)
    local f=s.frame; advance(c,e,2); assert(c.allocated==1 and s.frame==f)
    f.protectedAllowed=true; advance(c,e,1.2); assert(s.ready and s.texture and c.allocated==1,s.status)
    c:delete(id); e:sync(); advance(c,e); assert(#c.pool==1 and not f:IsShown())
    local second,s2=save(c,e); assert(s2.frame==f and c.allocated==1)
    c:delete(second); e:sync(); advance(c,e)
end)
test("a partial native creation error backs off without allocating around the failed object",function()
    local a,_,c,e=setup(); local original=CreateFrame; local priorErrors=#N.errors
    CreateFrame=function(...)
        local f=original(...); f.CreateTexture=function() error("injected creation error") end; return f
    end
    local id=assert(c:save(nil,V.default())); e:sync(); advance(c,e,0.1); CreateFrame=original
    local s=assert(c.slots[id]); assert(s.frame and not s.texture and not s.ready and c.allocated==1)
    advance(c,e,7); assert(c.allocated==1 and s.suspended)
    c:delete(id); e:sync(); advance(c,e); assert(not c.slots[id] and #c.pool==1)
    -- The recorder's deliberate error handler invocation is consumed here.
    assert(#N.errors>priorErrors)
    while #N.errors>priorErrors do assert(N.errors[#N.errors]:find("injected creation error",1,true)); table.remove(N.errors) end
end)
test("suspended visual keeps retrying denied cleanup without restarting configuration",function()
    local a,_,c,e=setup(); local id,s=save(c,e)
    s.suspended=true; s.frame.protectedAllowed=false; c:changed(); advance(c,e)
    assert(s.suspended and s.frame:IsShown() and s.status:find("pending removal"))
    s.frame.protectedAllowed=true; advance(c,e); assert(s.suspended and not s.frame:IsShown())
    local writes=s.frame.calls.SetPoint; advance(c,e,3); assert(s.frame.calls.SetPoint==writes)
    assert(c:save(id,c.db.visuals[id])); e:sync(); advance(c,e); assert(s.ready and s.frame:IsShown() and not s.suspended)
    e:pause(true)
end)
test("missing required native predicates deny new layer and visibility operations",function()
    local a,_,c,e=setup(); local _,s=save(c,e); local original=C_RestrictedActions.CheckAllowProtectedFunctions
    C_RestrictedActions.CheckAllowProtectedFunctions=nil
    local old=s.frame.level; assert(not a:canWrite(s.frame,P.byID.frameLayer,{strata="HIGH",level=8}))
    local ok=a:showVisual(s,false); assert(not ok and s.frame.level==old and s.frame:IsShown())
    C_RestrictedActions.CheckAllowProtectedFunctions=original; e:pause(true)
end)
test("both Add visual entry points share an editor with safe closing and independent defaults",function()
    FC.SetPaused(false); UI:build(); local f=frame("VisualEditorTarget"); UI:select(f)
    local before=U.copy(FC.db.visuals); UI.addVisual.scripts.OnClick(UI.addVisual)
    local form=UI.visualFrame; assert(form.fields.target:GetText()=="" and form.fields.mode.value=="fixed")
    form.close.scripts.OnClick(); equal(before,FC.db.visuals)
    UI.addAttached.scripts.OnClick(UI.addAttached); assert(form.fields.target:GetText()=="VisualEditorTarget" and form.fields.mode.value=="fill")
    form.fields.name:SetText("My background"); UI:saveVisual(); assert(form.id and FC.db.visuals[form.id].name=="My background")
    local id=form.id; N.advance(0.6); assert(FC.visuals.slots[id].ready,FC.visuals.slots[id].status)
    form.fields.name:SetText("Renamed"); form.fields.width:SetText("555"); form.fields.mode.value="fixed"; UI:saveVisual()
    assert(FC.db.visuals[id].layout.width==555 and FC.db.visuals[id].name=="Renamed")
    form.screen.scripts.OnClick(); UI:saveVisual(); assert(FC.db.visuals[id].placement=="screen" and form.id==id)
    form.fields.width:SetText("NaN"); UI:saveVisual(); assert(FC.db.visuals[id].layout.width==555 and form.notice)
    UI:editVisual(id); form.enabled:SetChecked(false); UI:saveVisual(); N.advance(0.4); assert(not FC.visuals.slots[id])
    UI:visualList(); assert(#UI.listFrame.items>=1)
    UI:editVisual(id); form.delete.scripts.OnClick(); assert(not FC.db.visuals[id])
end)

test("visual editor drags by its title and preserves placement without saving draft edits",function()
    UI:editVisual(); local f=UI.visualFrame; local before=U.copy(FC.db.visuals)
    assert(f.movable and f.presentation.SetClampedToScreen[1] and f.close.text:GetText()=="Close")
    assert(f.drag.presentation.RegisterForDrag[1]=="LeftButton")
    f.presentation.StartMoving=nil; f.protectedAllowed=false; f.drag.scripts.OnDragStart()
    assert(not f.presentation.StartMoving)
    f.protectedAllowed=true; f.drag.scripts.OnDragStart(); assert(f.moving and f.presentation.StartMoving)
    f.presentation.StopMovingOrSizing=nil; f.protectedAllowed=false; f.drag.scripts.OnDragStop()
    assert(f.stopPending and f.moving and not f.presentation.StopMovingOrSizing)
    f.protectedAllowed=true; FC.UIKit.tick(); assert(not f.moving and not f.stopPending)
    f.drag.scripts.OnDragStart()
    -- Native dragging supplies the new anchor; the recorder only verifies the
    -- handler wiring and that reopening/saving never re-centres the editor.
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-40)
    f.drag.scripts.OnDragStop(); assert(not f.moving and f.presentation.StopMovingOrSizing)
    local points={{"TOPLEFT",UIParent,"TOPLEFT",30,-40}}; f.fields.name:SetText("Unsaved draft")
    f.drag.scripts.OnDragStart(); f.close.scripts.OnClick(); assert(not f.moving and not f:IsShown())
    equal(before,FC.db.visuals); UI:editVisual(); equal(points,f.points)
    UI:saveVisual(); equal(points,f.points); f.delete.scripts.OnClick()
end)

test("editing manual layer values changes the relationship while loading preserves behind mode",function()
    local target=frame("VisualLayerEditor"); UI:editVisual(nil,R.describe(FC.adapter,target)); local f=UI.visualFrame
    assert(f.fields.layerMode.value=="behind")
    f.fields.strata.scripts.OnClick(f.fields.strata); FC.UIKit.choose(f.fields.strata,"HIGH"); assert(f.fields.layerMode.value=="manual")
    UI:saveVisual(); local id=f.id; assert(FC.db.visuals[id].layerMode=="manual")
    f.fields.layerMode.scripts.OnClick(f.fields.layerMode); FC.UIKit.choose(f.fields.layerMode,"behind"); assert(f.fields.layerMode.value=="behind")
    UI:saveVisual(); assert(f.fields.layerMode.value=="behind" and FC.db.visuals[id].layerMode=="behind")
    f.fields.level:SetText("23"); f.fields.level.scripts.OnTextChanged(f.fields.level,true)
    assert(f.fields.layerMode.value=="manual"); UI:saveVisual(); N.advance(0.5)
    assert(FC.db.visuals[id].style.frameLayer.level==23 and FC.visuals.slots[id].frame.level==23)
    f.delete.scripts.OnClick()
end)
test("unavailable saved attachment stays editable without guessing its replacement",function()
    local f=frame("VisualEditorMissing"); local target=R.describe(FC.adapter,f)
    UI:editVisual(nil,target); UI:saveVisual(); local id=UI.visualFrame.id; _G.VisualEditorMissing=nil
    UI:editVisual(id); UI.visualFrame.fields.name:SetText("Waiting background"); UI:saveVisual()
    assert(FC.db.visuals[id].name=="Waiting background"); N.advance(0.4); assert(FC.visuals.slots[id].status:find("unresolved"))
    UI.visualFrame.delete.scripts.OnClick()
end)
test("shared scheduler caps combined jobs and visual allocations",function()
    local _,db,c,e=setup()
    for _=1,64 do assert(c:save(nil,V.default())) end
    assert(not c:save(nil,V.default())); e:sync()
    for _=1,35 do N.time=N.time+0.05; local work=c:tick(); local other=e:tick(FC.LIMITS.jobs-work); assert(work+other<=FC.LIMITS.jobs) end
    assert(c.allocated==64)
    db.paused=true; e:pause(true); c:changed(); advance(c,e,1); assert(#c.pool==64)
end)
print("VISUALS: "..count.." passed (NOT a native WoW run)")
assert(#N.errors==0,"Unexpected visual recorder errors: "..table.concat(N.errors,"; "))
return count
