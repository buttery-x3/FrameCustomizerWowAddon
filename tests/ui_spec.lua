local _,FC=...
local UI,W,N,U=FC.Editor,FC.UIKit,FC.TestNative,FC.Util
local count=0
local function test(name,fn)
    local ok,why=pcall(fn); if not ok then error("FAIL EDITOR UI "..name..": "..tostring(why),0) end
    count=count+1; print("PASS EDITOR UI "..name)
end
local function bands()
    for i,root in ipairs(W.windows) do
        local upper=W.windows[i+1] and W.windows[i+1].windowBase or root.windowBase+128
        for _,node in ipairs(W.nodes[root]) do
            local f=node.frame
            assert(f.strata=="DIALOG" and f.fixedLevel and f.fixedStrata)
            assert(f.level>=root.windowBase and f.level<upper,"child escaped its window band")
        end
    end
end
test("every interactive tool window has independent dragging borders and Close",function()
    UI:build(); UI:editVisual(); UI:visualList(); UI:report("Example","Report")
    FC.Playground:show(); UI:startPick(); UI:finishPick(false)
    for _,f in ipairs({UI.frame,UI.visualFrame,UI.listFrame,UI.reportFrame,UI.pickFrame,FC.Playground.dev.root}) do
        assert(W.roots[f]==f and f.movable and f.drag and #f.uiBorder==4 and f.close.text:GetText()=="Close")
        assert(f.presentation.SetClampedToScreen[1])
        f.drag.scripts.OnDragStart(); assert(f.moving); f.drag.scripts.OnDragStop(); assert(not f.moving)
    end
    bands()
end)
test("opening secondary windows and focusing nested controls raises complete bounded bands",function()
    UI:editVisual(); UI.visualFrame.media.scripts.OnClick(UI.visualFrame.media)
    assert(W.windows[#W.windows]==UI.listFrame and UI.listFrame.level>UI.visualFrame.level); bands()
    UI:report("Example"); assert(W.windows[#W.windows]==UI.reportFrame); bands()
    UI.search.scripts.OnEditFocusGained(UI.search); assert(W.windows[#W.windows]==UI.frame); bands()
    local windows=#W.windows; local nodes=#W.nodes[UI.listFrame]
    for _=1,50 do W.focus(UI.visualFrame); W.focus(UI.listFrame); W.focus(UI.frame) end
    assert(#W.windows==windows and #W.nodes[UI.listFrame]==nodes and UI.frame.level<1200); bands()
end)
test("window layer setters stop on native denial and retry without changing game objects",function()
    W.focus(UI.frame); local f=UI.visualFrame; local original=f.SetFrameLevel
    f.SetFrameLevel=function(o,n) original(o,n); o.protectedAllowed=false end
    W.focus(f); assert(W.pending and not f.fixedLevel)
    local calls=f.calls.SetFrameLevel; W.restack(); assert(f.calls.SetFrameLevel==calls)
    f.SetFrameLevel=original; f.protectedAllowed=true; N.time=N.time+1; W.tick()
    assert(not W.pending and f.fixedLevel); bands()
    assert(FC.adapter:excluded(UI.listFrame) and FC.adapter:excluded(UI.fields[1].choice))
end)
test("owned template descendants join the same band without replacing their click scripts",function()
    local parent=W.frame(UI.reportFrame); local child=CreateFrame("Button",nil,parent); local clicks=0
    child:SetScript("OnMouseDown",function() clicks=clicks+1 end)
    W.adoptChildren(parent); assert(W.roots[child]==UI.reportFrame)
    child.scripts.OnMouseDown(child); assert(clicks==1 and W.windows[#W.windows]==UI.reportFrame); bands()
end)
test("script composition refuses inaccessible or forbidden bindings",function()
    local f=UI.frame; local original=f.GetScript; local calls=0
    f.GetScript=function() calls=calls+1; return N.inaccessible end
    assert(not W.hook(f,"OnShow",function() error("must not attach") end) and calls==1)
    f.forbiddenAspects.ScriptBindings=true
    assert(not W.hook(f,"OnShow",function() end) and calls==1)
    f.forbiddenAspects.ScriptBindings=nil; f.GetScript=original
end)
test("dropdowns support direct choice keyboard navigation escape and outside dismissal",function()
    UI:editVisual(); local b=UI.visualFrame.fields.kind; W.setChoice(b,"solid")
    b.scripts.OnClick(b); local menu=W.menu; assert(menu:IsShown() and menu.owner==b)
    assert(menu.strata=="FULLSCREEN_DIALOG" and menu.box.level>menu.level)
    menu.scripts.OnKeyDown(menu,"DOWN"); menu.scripts.OnKeyDown(menu,"ENTER")
    assert(b.value=="file" and not menu:IsShown() and UI.visualFrame.fields.asset:IsShown())
    b.scripts.OnClick(b); menu.scripts.OnKeyDown(menu,"DOWN"); menu.scripts.OnKeyDown(menu,"ESCAPE")
    assert(b.value=="file" and not menu:IsShown())
    b.scripts.OnClick(b); menu.scripts.OnMouseUp(); assert(not menu:IsShown())
    local nodes=#W.nodes[menu]
    for _=1,20 do W.openMenu(b); W.closeMenu() end
    assert(#W.nodes[menu]==nodes)
end)
test("dropdowns close with their owner or when another window gains focus",function()
    UI:editVisual(); local f=UI.visualFrame; W.openMenu(f.fields.strata); f:Hide(); assert(not W.menu:IsShown())
    f:Show(); W.openMenu(f.fields.strata); W.focus(UI.frame); assert(not W.menu:IsShown())
    W.openMenu(f.fields.strata); f.drag.scripts.OnDragStart(); assert(not W.menu:IsShown()); f.drag.scripts.OnDragStop()
end)
test("picker hides secondary windows and restores only previously visible windows",function()
    UI.frame:Show(); UI.visualFrame:Show(); UI.listFrame:Show(); UI.reportFrame:Hide()
    UI:startPick()
    assert(not UI.frame:IsShown() and not UI.visualFrame:IsShown() and not UI.listFrame:IsShown() and UI.pickFrame:IsShown())
    UI.pickFrame.close.scripts.OnClick(); assert(not UI.picking and not UI.pickFrame:IsShown())
    assert(UI.frame:IsShown() and UI.visualFrame:IsShown() and UI.listFrame:IsShown() and not UI.reportFrame:IsShown()); bands()
end)
test("visual sizing shows relevant controls and preserves hidden values",function()
    UI:editVisual(); local f=UI.visualFrame
    f.fields.width:SetText("456"); assert(f.fields.width:IsShown() and not f.fields.left:IsShown())
    W.choose(f.fields.mode,"fill"); assert(not f.fields.width:IsShown() and f.fields.left:IsShown() and f.fillHint:IsShown())
    f.fields.left:SetText("-8"); W.choose(f.fields.mode,"fixed")
    assert(f.fields.width:GetText()=="456" and f.fields.left:GetText()=="-8" and not f.fillHint:IsShown())
    W.choose(f.fields.kind,"solid"); assert(not f.fields.asset:IsShown())
    W.choose(f.fields.kind,"atlas"); assert(f.fields.asset:IsShown())
end)
test("property enum dropdowns save existing values and enforcement strategies",function()
    local f=FC.Playground.dev.texture; UI:select(f); if not UI:rule() then UI:createRule() end
    UI:chooseProperty(FC.Properties.byID.drawLayer)
    local row=UI.fields[1]; assert(row.choice:IsShown() and not row.edit:IsShown())
    W.choose(row.choice,"BORDER"); W.choose(UI.modeButton,3); UI.propInterval:SetText("3"); UI.fields[2].edit:SetText("-2"); UI:saveProperty(true)
    local entry=UI:rule().overrides.drawLayer
    assert(entry.value.layer=="BORDER" and entry.value.sublevel==-2 and entry.periodic and entry.interval==3)
    UI:chooseProperty(FC.Properties.byID.opacity); assert(UI.fields[1].edit:IsShown() and not UI.fields[1].choice:IsShown())
end)
test("visual list and media filters stay distinct with reusable paging",function()
    UI:visualList(); local f=UI.listFrame; assert(f.contentKind=="visuals" and not f.source:IsShown())
    local items={}; for i=1,30 do items[i]={"Asset "..i,"path"..i,source="Blizzard",mediaType="texture"} end
    UI:showList("Media",items,function() end,"Example")
    assert(f.contentKind=="assets" and f.source:IsShown()); f.next.scripts.OnClick(f.next); assert(f.offset==13)
    f.previous.scripts.OnClick(f.previous); assert(f.offset==0)
    W.choose(f.source,2); assert(not f.rows[1]:IsShown()); W.choose(f.source,1); assert(f.rows[1]:IsShown())
end)
print("EDITOR UI: "..count.." passed (NOT a native WoW run)")
assert(#N.errors==0,"Unexpected UI recorder errors")
return count
