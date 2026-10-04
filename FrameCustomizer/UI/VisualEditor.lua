local _,FC=...
local UI,U,V=FC.Editor,FC.Util,FC.Visuals
local W=UI.widgets
local label,button,input,check,at=W.label,W.button,W.input,W.check,W.at
local function path(t) return t and U.joinTarget(t) or "" end
function UI:visualDescriptor(text,previous)
    if previous and text==path(previous) then return U.copy(previous) end
    local parts={}; for s in text:gmatch("[^.]+") do if not U.identifier(s) then return nil,"Use a global name followed by parent keys" end; parts[#parts+1]=s end
    if #parts==0 or #parts>13 or table.concat(parts,".")~=text then return nil,"Invalid target path" end
    local o,why=FC.adapter:global(parts[1])
    for i=2,#parts do if not o then break end; o,why=FC.adapter:keyChild(o,parts[i]) end
    if not o then return nil,why or "Target unavailable" end
    local t,reason=FC.Resolver.describe(FC.adapter,o)
    if not t or t.visual then return nil,reason or "Choose an existing UI object" end
    return t
end
function UI:visualList(target)
    local summary="Select to edit, rename, duplicate, disable or delete. Unavailable attachments stay in this list."
    local function list()
        local items={}
        for id,v in pairs(FC.db.visuals or {}) do
            if not target or v.target and U.equal(v.target,target) then
                local slot=FC.visuals.slots[id]
                items[#items+1]={id.." "..v.name,id,source=v.enabled and "Enabled" or "Disabled",mediaType=v.placement.." / "..v.layout.mode.." / "..(slot and slot.status or "pending")}
            end
        end
        table.sort(items,function(a,b) return a[2]<b[2] end)
        return items,{summary=summary}
    end
    self:showList(target and "Attached visuals" or "Your visuals",list(),function(item) self:editVisual(item[2]) end,summary,list)
    self.listFrame.source:Hide()
end
function UI:buildVisualControls()
    self.yourVisuals=button(self.frame,"Your visuals",115,function() self:visualList() end); at(self.yourVisuals,self.frame,617,54)
    self.addVisual=button(self.frame,"Add visual",108,function() self:editVisual() end); at(self.addVisual,self.frame,740,54)
    self.addAttached=button(self.frame,"Add visual",108,function() self:editVisual(nil,self.target) end); at(self.addAttached,self.frame,802,184)
    self.attachedVisuals=button(self.frame,"Attached visuals",135,function() self:visualList(self.target) end); at(self.attachedVisuals,self.frame,918,184)
end
function UI:buildVisualEditor()
    if self.visualFrame then return end
    local f=CreateFrame("Frame",nil,UIParent); FC.adapter.owned[f]=true; self.visualFrame=f
    f:SetSize(940,780); f:SetScale(math.min(1,(UIParent:GetWidth()-40)/940,(UIParent:GetHeight()-40)/780)); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(100); f:EnableMouse(true)
    f:SetMovable(true)
    if FC.adapter:protected(f) then f:SetClampedToScreen(true) end
    W.panel(f,0.075,0.095,0.13)
    f.title=label(f,"",20); at(f.title,f,20,16); f.title:SetSize(790,32); f.title:SetWordWrap(false)
    f.drag=CreateFrame("Frame",nil,f); FC.adapter.owned[f.drag]=true
    f.drag:SetPoint("TOPLEFT"); f.drag:SetSize(815,48); f.drag:EnableMouse(true); f.drag:RegisterForDrag("LeftButton")
    local function stopMoving()
        f.stopPending=f.moving
        if f.moving and FC.adapter:protected(f) then f:StopMovingOrSizing(); f.moving=nil; f.stopPending=nil end
    end
    f.drag:SetScript("OnDragStart",function()
        if FC.adapter:protected(f) then f:StartMoving(); f.moving=true end
    end)
    f.drag:SetScript("OnDragStop",stopMoving); f:SetScript("OnHide",stopMoving); f:SetScript("OnShow",stopMoving)
    f.close=button(f,"Close",85,function() f:Hide() end); at(f.close,f,830,12)
    local function field(key,title,x,y,width)
        local t=label(f,title,11); at(t,f,x,y); t:SetWidth(width or 275)
        local e=input(f,width or 275); at(e,f,x,y+17); f.fields[key]=e; return e
    end
    local function choice(key,title,values,x,y)
        local t=label(f,title,11); at(t,f,x,y)
        local b=button(f,"",275,function(s)
            local index=1; for i,v in ipairs(values) do if v==s.value then index=i%#values+1 end end
            s.value=values[index]; s.text:SetText(s.value)
            if s.changed then s.changed() end
        end); at(b,f,x,y+17); f.fields[key]=b; b.options=values; return b
    end
    f.fields={}
    field("name","Name",20,57,570)
    f.enabled=check(f,"Visual enabled",function() end); at(f.enabled,f,620,78)
    field("target","Placement: blank = screen; otherwise exact target path",20,108,680)
    f.useSelected=button(f,"Use selected",195,function()
        if UI.target and not UI.target.visual then
            f.fields.target:SetText(path(UI.target)); f.draft.target=U.copy(UI.target)
        else f.status:SetText("Select an existing object in the main editor first.") end
    end); at(f.useSelected,f,718,125)
    field("container","Visibility container: blank = target frame or target region's parent",20,159,680)
    f.screen=button(f,"Independent on screen",195,function()
        f.fields.target:SetText(""); f.fields.container:SetText(""); f.fields.mode.value="fixed"; f.fields.mode.text:SetText("fixed")
        f.fields.layerMode.value="manual"; f.fields.layerMode.text:SetText("manual")
    end); at(f.screen,f,718,176)
    choice("kind","Appearance",{"solid","file","atlas"},20,213)
    field("asset","Texture file path or atlas name",20,262)
    f.media=button(f,"Browse media",130,function()
        local list,info=FC.adapter:media("texture")
        self:showList("Choose visual texture",list,function(item)
            f.fields.asset:SetText(item[2]); f.fields.kind.value="file"; f.fields.kind.text:SetText("file")
        end,info.summary,function() return FC.adapter:media("texture") end)
        self.listFrame:SetFrameLevel(120)
    end); at(f.media,f,20,310)
    for i,pair in ipairs({{"r","Red (0..1)"},{"g","Green (0..1)"},{"b","Blue (0..1)"},{"a","Opacity (0..1)"}}) do field(pair[1],pair[2],20,345+(i-1)*49) end
    choice("mode","Sizing",{"fixed","fill"},325,213)
    field("width","Width (fixed sizing)",325,262); field("height","Height (fixed sizing)",325,311)
    local points={"CENTER","TOPLEFT","TOP","TOPRIGHT","LEFT","RIGHT","BOTTOMLEFT","BOTTOM","BOTTOMRIGHT"}
    choice("point","Visual anchor (fixed sizing)",points,325,360); choice("relativePoint","Target anchor (fixed sizing)",points,325,409)
    field("x","X offset",325,458); field("y","Y offset",325,507)
    choice("layerMode","Layer relationship",{"manual","behind"},630,213)
    local function manualLayers()
        f.fields.layerMode.value="manual"; f.fields.layerMode.text:SetText("manual")
    end
    choice("strata","Frame strata (switches to manual)",{"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG","FULLSCREEN","FULLSCREEN_DIALOG","TOOLTIP"},630,262).changed=manualLayers
    field("level","Frame level (manual, 0..10000)",630,311):SetScript("OnTextChanged",function(_,userInput)
        if userInput then manualLayers() end
    end)
    choice("layer","Texture draw layer",{"BACKGROUND","BORDER","ARTWORK","OVERLAY","HIGHLIGHT"},630,360)
    field("sublevel","Texture sublevel (-8..7)",630,409)
    for i,key in ipairs({"left","right","top","bottom"}) do field(key,"Fill padding: "..key.." (negative expands)",630,458+(i-1)*49) end
    f.hint=label(f,"Drag the title bar to move this editor. Changes apply on Save.\nFill follows target bounds; fixed sizing follows the anchor. Panels stay click-through.\nBehind follows the target frame's strata and level minus one.\nEditing strata or level switches to manual layering; Save applies the change.",11)
    at(f.hint,f,20,572); f.hint:SetSize(590,76)
    f.status=label(f,"",12); at(f.status,f,20,660); f.status:SetSize(895,42)
    f.save=button(f,"Create",115,function() self:saveVisual() end); at(f.save,f,20,720)
    f.duplicate=button(f,"Duplicate",115,function()
        if FC.readOnlyData then return end
        local id,why=FC.visuals:duplicate(f.id)
        if id then FC.engine:sync(); self:editVisual(id) else f.status:SetText(why) end
    end); at(f.duplicate,f,150,720)
    f.delete=button(f,"Delete",115,function()
        if FC.readOnlyData or not f.id then return end
        FC.visuals:delete(f.id); FC.engine:sync(); FC.visuals:tick(); f:Hide(); self:message("Visual deleted. Any restricted cleanup remains pending; see Report.")
    end); at(f.delete,f,280,720)
    f:SetScript("OnUpdate",function(_,dt)
        if f.stopPending then stopMoving() end
        f.elapsed=(f.elapsed or 0)+dt
        if f.elapsed>=0.5 then
            f.elapsed=0
            if not f.notice then
                local slot=f.id and FC.visuals.slots[f.id]
                f.status:SetText(FC.readOnlyData and "Saved data is read-only." or slot and slot.status or FC.db.paused and "Pause All is active." or "Edit values, then Save. Missing targets wait without losing settings.")
            end
        end
    end)
end
function UI:editVisual(id,target)
    self:buildVisualEditor()
    local f=self.visualFrame; local v=id and FC.db.visuals[id] or V.default(target)
    if not v then self:message("Visual no longer exists."); return end
    f.id=id; f.draft=U.copy(v); f.notice=nil
    f.title:SetText(id and ("Edit visual - "..U.cleanLabel(v.name)) or "Add visual")
    local values={name=v.name,target=path(v.target),container=path(v.container),layerMode=v.layerMode,
        kind=v.style.texture.asset==V.white and v.style.texture.kind=="file" and "solid" or v.style.texture.kind,asset=v.style.texture.asset}
    for key,value in pairs(v.layout) do values[key]=value end
    for _,part in ipairs({"tint","frameLayer","drawLayer"}) do for key,value in pairs(v.style[part]) do values[key]=value end end
    for key,e in pairs(f.fields) do
        if e.options then e.value=values[key]; e.text:SetText(e.value) else e:SetText(tostring(values[key] or "")) end
    end
    f.enabled:SetChecked(v.enabled); f.save.text:SetText(id and "Save" or "Create")
    W.show(f.duplicate,id~=nil and not FC.readOnlyData); W.show(f.delete,id~=nil and not FC.readOnlyData); W.show(f.save,not FC.readOnlyData)
    f.status:SetText("Changes apply on Save. Close leaves unsaved edits unapplied."); f:Show()
end
function UI:saveVisual()
    if FC.readOnlyData then return end
    local f=self.visualFrame; local v=U.copy(f.draft); local values={}
    local function fail(why) f.notice=why; f.status:SetText(why) end
    for key,e in pairs(f.fields) do values[key]=e.options and e.value or e:GetText() end
    v.name=values.name; v.enabled=f.enabled:GetChecked()==true; v.layerMode=values.layerMode
    v.placement=values.target=="" and "screen" or "target"
    if v.placement=="target" then
        local why; v.target,why=self:visualDescriptor(values.target,v.target); if not v.target then fail(why); return end
        if values.container~="" then v.container,why=self:visualDescriptor(values.container,v.container); if not v.container then fail(why); return end else v.container=nil end
    else v.target=nil; v.container=nil end
    for key in pairs(v.layout) do v.layout[key]=type(v.layout[key])=="number" and tonumber(values[key]) or values[key] end
    v.style.texture={kind=values.kind=="solid" and "file" or values.kind,asset=values.kind=="solid" and V.white or values.asset}
    v.style.tint={r=tonumber(values.r),g=tonumber(values.g),b=tonumber(values.b),a=tonumber(values.a)}
    v.style.frameLayer={strata=values.strata,level=tonumber(values.level)}
    v.style.drawLayer={layer=values.layer,sublevel=tonumber(values.sublevel)}
    local id,why=FC.visuals:save(f.id,v)
    if not id then fail(why); return end
    FC.engine:sync(); FC.visuals:tick(); self:editVisual(id); f.notice=nil
    self.dirty=true
end
