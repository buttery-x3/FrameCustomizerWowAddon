local _,FC=...
local U=FC.Util
local W={windows={},nodes={},roots={},pending=false}
FC.UIKit=W
W.font="Fonts\\FRIZQT__.TTF"
W.points={"CENTER","TOPLEFT","TOP","TOPRIGHT","LEFT","RIGHT","BOTTOMLEFT","BOTTOM","BOTTOMRIGHT"}
W.strata={"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG","FULLSCREEN","FULLSCREEN_DIALOG","TOOLTIP"}
W.layers={"BACKGROUND","BORDER","ARTWORK","OVERLAY","HIGHLIGHT"}
function W.at(o,p,x,y) o:ClearAllPoints(); o:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y) end
function W.show(o,on) if on then o:Show() else o:Hide() end end
local function protected(o,key,...)
    if not FC.adapter:protected(o) then W.pending=true; return false end
    local fn=o[key]; if not U.safe(fn) or type(fn)~="function" then W.pending=true; return false end
    fn(o,...); return true
end
function W.hook(f,event,fn)
    -- These are exclusively our own UI scripts; never wrap a target's scripts.
    if not FC.adapter:inspectable(f) or not FC.adapter:noForbidden(f,"ScriptBindings") then return false end
    local old=f:GetScript(event)
    if not U.safe(old) or old~=nil and type(old)~="function" then return false end
    if not FC.adapter:inspectable(f) or not FC.adapter:noForbidden(f,"ScriptBindings") then return false end
    f:SetScript(event,function(...) if old then old(...) end; fn(...) end)
    return true
end
local function layer(node,base,strata)
    local level=base+node.depth*4
    if node.level==level and node.strata==strata then return end
    local f=node.frame
    if not protected(f,"SetFixedFrameStrata",false) or not protected(f,"SetFixedFrameLevel",false)
        or not protected(f,"SetFrameStrata",strata) or not protected(f,"SetFrameLevel",level)
        or not protected(f,"SetFixedFrameStrata",true) or not protected(f,"SetFixedFrameLevel",true) then
        node.level=nil; return
    end
    node.level=level; node.strata=strata
end
function W.restack()
    W.pending=false
    local active
    for _,f in ipairs(W.windows) do local ok,shown=FC.adapter:read(f,"IsShown"); if ok and shown then active=f end end
    -- Bounded, separated level bands keep every known child below the next
    -- window's opaque background. Native auto-raise cannot escape the band.
    for i,f in ipairs(W.windows) do
        f.windowBase=100+(i-1)*128
        for _,node in ipairs(W.nodes[f]) do layer(node,f.windowBase,"DIALOG") end
        if f.header then
            if f==active then f.header:SetColorTexture(0.08,0.2,0.27,1) else f.header:SetColorTexture(0.09,0.14,0.2,1) end
        end
    end
    if W.menu then for _,node in ipairs(W.nodes[W.menu]) do layer(node,2000,"FULLSCREEN_DIALOG") end end
end
function W.closeMenu()
    if W.menu then W.menu:Hide(); W.menu.owner=nil end
end
function W.focus(f)
    local root=W.roots[f]; if not root or root==W.menu then return end
    if W.menu and W.menu.owner and W.roots[W.menu.owner]~=root then W.closeMenu() end
    for i,w in ipairs(W.windows) do if w==root then table.remove(W.windows,i); break end end
    W.windows[#W.windows+1]=root; W.restack()
end
function W.track(f,parent)
    FC.adapter.owned[f]=true
    local root=W.roots[parent]
    if root then
        W.roots[f]=root
        local depth=(parent.uiDepth or 0)+1; f.uiDepth=depth
        assert(depth<24,"Editor nesting exceeds its window level band")
        local node={frame=f,depth=depth}; W.nodes[root][#W.nodes[root]+1]=node
        layer(node,root.windowBase or 2000,root==W.menu and "FULLSCREEN_DIALOG" or "DIALOG")
        W.hook(f,"OnMouseDown",function() W.focus(f) end)
    end
    return f
end
function W.adoptChildren(parent)
    if (parent.uiDepth or 0)>=22 then return end
    -- Only descend into controls instantiated by our own template. Never
    -- enumerate or change the selected game object's hierarchy here.
    local children=FC.adapter:children(parent)
    for _,child in ipairs(children) do
        if FC.Properties.applicable(FC.Properties.byID.frameLayer,FC.adapter:kind(child)) and not W.roots[child] then
            W.track(child,parent); W.adoptChildren(child)
        end
    end
end
function W.frame(parent,kind,template)
    local f=W.track(CreateFrame(kind or "Frame",nil,parent,template),parent)
    if template then W.adoptChildren(f) end
    return f
end
function W.label(parent,text,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(W.font,size or 12,""); f:SetTextColor(0.88,0.91,0.95); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetText(text or "")
    return f
end
function W.panel(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
function W.border(parent,r,g,b)
    local edges={}
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local t=parent:CreateTexture(nil,"BORDER"); t:SetColorTexture(r or 0.29,g or 0.37,b or 0.46,1)
        if side=="TOP" or side=="BOTTOM" then t:SetPoint(side.."LEFT"); t:SetPoint(side.."RIGHT"); t:SetHeight(1)
        else t:SetPoint("TOP"..side); t:SetPoint("BOTTOM"..side); t:SetWidth(1) end
        edges[#edges+1]=t
    end
    parent.uiBorder=edges; return edges
end
function W.button(parent,text,width,callback)
    local b=W.frame(parent,"Button"); b:SetSize(width or 100,28)
    b.background=W.panel(b,0.13,0.18,0.24); W.border(b)
    local h=b:CreateTexture(nil,"HIGHLIGHT"); h:SetAllPoints(); h:SetColorTexture(0.3,0.65,0.85,0.2)
    b.text=W.label(b,text,12); b.text:SetPoint("LEFT",8,0); b.text:SetPoint("RIGHT",-8,0); b.text:SetHeight(18); b.text:SetJustifyH("CENTER"); b.text:SetJustifyV("MIDDLE"); b.text:SetWordWrap(false)
    b:SetScript("OnClick",function(s,...) W.focus(b); if callback then callback(s,...) end end)
    return b
end
function W.tone(b,tone)
    if tone=="primary" then b.background:SetColorTexture(0.08,0.34,0.4,1)
    elseif tone=="danger" then b.background:SetColorTexture(0.29,0.12,0.16,1) end
end
function W.input(parent,width)
    local e=W.frame(parent,"EditBox"); e:SetSize(width or 230,28); e:SetFont(W.font,12,""); e:SetAutoFocus(false)
    e:SetMaxLetters(240); e:SetTextInsets(8,8,0,0); e:SetTextColor(1,1,1); W.panel(e,0.035,0.05,0.075); W.border(e)
    e:SetScript("OnEscapePressed",function(s) s:ClearFocus(); W.closeMenu() end)
    e:SetScript("OnEnterPressed",function(s) s:ClearFocus() end)
    W.hook(e,"OnEditFocusGained",function() W.focus(e) end)
    return e
end
function W.check(parent,text,callback)
    local b=W.frame(parent,"CheckButton"); b:SetSize(28+#text*7,20)
    local bg=W.panel(b,0.035,0.05,0.075); bg:ClearAllPoints(); bg:SetPoint("LEFT"); bg:SetSize(20,20)
    for i,t in ipairs(W.border(b)) do
        t:ClearAllPoints()
        if i<=2 then t:SetPoint("TOPLEFT",0,i==1 and 0 or -19); t:SetSize(20,1)
        else t:SetPoint("TOPLEFT",i==3 and 0 or 19,0); t:SetSize(1,20) end
    end
    local t=b:CreateTexture(nil,"ARTWORK"); t:SetPoint("LEFT",4,0); t:SetSize(12,12); t:SetColorTexture(0.25,0.8,0.7,1); b:SetCheckedTexture(t)
    b.text=W.label(b,text,12); b.text:SetPoint("LEFT",28,0); b.text:SetSize(#text*7,18); b.text:SetWordWrap(false); b.text:SetJustifyV("MIDDLE")
    b:SetScript("OnClick",function(s) W.focus(b); callback(s:GetChecked()==true) end); return b
end
function W.section(parent,title,x,y,width,height)
    local f=W.frame(parent); W.at(f,parent,x,y); f:SetSize(width,height)
    W.panel(f,0.065,0.085,0.115); W.border(f,0.2,0.27,0.34)
    local t=W.label(f,title,13); W.at(t,f,14,12); t:SetSize(width-28,20)
    return f
end
function W.stop(f)
    f.stopPending=f.moving
    if f.moving and protected(f,"StopMovingOrSizing") then f.moving=nil; f.stopPending=nil end
end
function W.decorate(f,title,fixture)
    if W.roots[f] then return f end
    if not fixture then FC.adapter.owned[f]=true end
    W.roots[f]=f; W.nodes[f]={{frame=f,depth=0}}; W.windows[#W.windows+1]=f
    f.uiDepth=0; f:SetMovable(true); protected(f,"SetClampedToScreen",true); f:EnableMouse(true)
    W.panel(f,0.045,0.06,0.085); W.border(f,0.36,0.46,0.56)
    local header=f:CreateTexture(nil,"ARTWORK"); f.header=header; header:SetPoint("TOPLEFT",1,-1); header:SetPoint("TOPRIGHT",-1,-1); header:SetHeight(48); header:SetColorTexture(0.09,0.14,0.2,1)
    f.title=W.label(f,title,18); W.at(f.title,f,18,15); f.title:SetPoint("TOPRIGHT",f,"TOPRIGHT",-110,-15); f.title:SetHeight(24); f.title:SetWordWrap(false)
    f.drag=W.frame(f); f.drag:SetPoint("TOPLEFT",1,-1); f.drag:SetPoint("TOPRIGHT",-104,-1); f.drag:SetHeight(47); f.drag:EnableMouse(true); f.drag:RegisterForDrag("LeftButton")
    f.drag:SetScript("OnDragStart",function() W.focus(f); W.closeMenu(); if protected(f,"StartMoving") then f.moving=true end end)
    f.drag:SetScript("OnDragStop",function() W.stop(f) end)
    f.close=W.button(f,"Close",80,function() f:Hide() end); f.close:SetPoint("TOPRIGHT",-12,-10)
    W.hook(f,"OnMouseDown",function() W.focus(f) end)
    W.hook(f,"OnShow",function() W.stop(f); W.focus(f) end)
    W.hook(f,"OnHide",function()
        W.stop(f)
        if W.menu and W.menu.owner and W.roots[W.menu.owner]==f then W.closeMenu() end
        for _,node in ipairs(W.nodes[f]) do if node.frame.ClearFocus then node.frame:ClearFocus() end end
        if FC.Editor then FC.Editor:hideTooltip() end
        W.restack()
    end)
    W.restack(); return f
end
function W.window(title,width,height,name)
    local f=CreateFrame("Frame",name,UIParent)
    f:SetSize(width,height); f:SetScale(math.min(1,(UIParent:GetWidth()-40)/width,(UIParent:GetHeight()-40)/height)); f:SetPoint("CENTER")
    W.decorate(f,title); return f
end
function W.tick()
    if W.pending and GetTime()>=(W.retryAt or 0) then W.retryAt=GetTime()+0.5; W.restack() end
    for _,f in ipairs(W.windows) do if f.stopPending then W.stop(f) end end
end
local function option(v) if type(v)=="table" then return v[1],v[2] end; return v,v end
function W.setChoice(b,value)
    b.value=value
    local text=tostring(value or "")
    for _,v in ipairs(b.options) do local key,label=option(v); if key==value then text=label; break end end
    b.text:SetText(text)
end
function W.choose(b,value)
    for _,v in ipairs(b.options) do
        local key=option(v)
        if key==value then W.closeMenu(); W.setChoice(b,value); if b.changed then b.changed(value) end; return true end
    end
    return false
end
function W.menuHighlight()
    local m=W.menu
    for i,row in ipairs(m.rows) do
        if i==m.cursor then row.background:SetColorTexture(0.09,0.31,0.38,1)
        else row.background:SetColorTexture(0.1,0.15,0.21,1) end
    end
end
function W.openMenu(b)
    if W.menu and W.menu:IsShown() and W.menu.owner==b then W.closeMenu(); return end
    W.closeMenu(); W.focus(b)
    if not W.menu then
        local m=CreateFrame("Frame",nil,UIParent); W.menu=m; FC.adapter.owned[m]=true
        W.roots[m]=m; W.nodes[m]={{frame=m,depth=0}}; m.uiDepth=0
        m:SetAllPoints(UIParent); m:EnableMouse(true); m:EnableKeyboard(true)
        -- Keep the catcher through mouse-up so dismissal cannot also click
        -- a control underneath the menu.
        m:SetScript("OnMouseUp",W.closeMenu)
        m:SetScript("OnKeyDown",function(_,key)
            local handled=key=="ESCAPE" or key=="ENTER" or key=="UP" or key=="DOWN"
            m:SetPropagateKeyboardInput(not handled)
            if key=="ESCAPE" then W.closeMenu()
            elseif m.owner and key=="ENTER" then W.choose(m.owner,m.rows[m.cursor].value)
            elseif m.owner and (key=="UP" or key=="DOWN") then
                m.cursor=(m.cursor-1+(key=="DOWN" and 1 or -1))%#m.owner.options+1; W.menuHighlight()
            end
        end)
        m.box=W.frame(m); m.box:EnableMouse(true); protected(m.box,"SetClampedToScreen",true)
        W.panel(m.box,0.04,0.065,0.095); W.border(m.box,0.4,0.6,0.7); m.rows={}
        for i=1,12 do
            local row=W.button(m.box,"",200,function(s) local owner=m.owner; if owner then W.choose(owner,s.value) end end)
            row:SetScript("OnEnter",function() m.cursor=i; W.menuHighlight() end)
            row.text:SetJustifyH("LEFT"); m.rows[i]=row
        end
    end
    local m=W.menu; m.owner=b; m.cursor=1
    local good,scale=FC.adapter:read(b,"GetEffectiveScale"); if good and U.number(scale,0.01,100) then m.box:SetScale(scale/UIParent:GetEffectiveScale()) end
    m.box:ClearAllPoints(); m.box:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-3); m.box:SetSize(b:GetWidth(),#b.options*30+8)
    for i,row in ipairs(m.rows) do
        local v=b.options[i]; W.show(row,v~=nil)
        if v then local key,text=option(v); if key==b.value then m.cursor=i end; row.value=key; row.text:SetText((key==b.value and "* " or "  ")..text); row:SetWidth(b:GetWidth()-8); W.at(row,m.box,4,4+(i-1)*30) end
    end
    W.menuHighlight(); m:Show(); W.restack()
end
function W.dropdown(parent,width,options,changed)
    assert(#options<=12,"Dropdown option limit")
    local b=W.button(parent,"",width,function(s) W.openMenu(s) end); b.options=options; b.changed=changed
    b.text:SetJustifyH("LEFT"); b.text:ClearAllPoints(); b.text:SetPoint("LEFT",10,0); b.text:SetPoint("RIGHT",-27,0); b.text:SetHeight(18)
    b.arrow=W.label(b,"v",11); b.arrow:SetPoint("RIGHT",-9,0); b.arrow:SetSize(12,18)
    W.setChoice(b,option(options[1])); return b
end
