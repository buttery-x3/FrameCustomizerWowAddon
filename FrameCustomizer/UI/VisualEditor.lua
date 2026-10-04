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
    self:showList(target and "Attached visuals" or "Your visuals",list(),function(item) self:editVisual(item[2]) end,summary,list,"visuals")
end
function UI:buildVisualControls()
    self.yourVisuals=button(self.frame,"Your visuals",134,function() self:visualList() end); at(self.yourVisuals,self.frame,428,64)
    self.addVisual=button(self.frame,"Add visual",108,function() self:editVisual() end); at(self.addVisual,self.frame,574,64)
    self.addAttached=button(self.selectedPanel,"Add visual",110,function() self:editVisual(nil,self.target) end); at(self.addAttached,self.selectedPanel,459,112)
    self.attachedVisuals=button(self.selectedPanel,"Attached visuals",186,function() self:visualList(self.target) end); at(self.attachedVisuals,self.selectedPanel,579,112)
end
function UI:buildVisualEditor()
    if self.visualFrame then return end
    local f=W.window("Add visual",1040,854); self.visualFrame=f; f.fields={}; f.fieldLabels={}
    local identity=W.section(f,"Name and attachment",16,64,1008,204)
    local appearance=W.section(f,"Appearance",16,284,320,402)
    local geometry=W.section(f,"Size and placement",360,284,320,402)
    local layers=W.section(f,"Layering",704,284,320,402)
    local function field(key,title,p,x,y,width)
        local t=label(p,title,11); at(t,p,x,y); t:SetSize(width or 292,16); f.fieldLabels[key]=t
        local e=input(p,width or 292); at(e,p,x,y+18); f.fields[key]=e; return e
    end
    local function choice(key,title,values,p,x,y,width,changed)
        local t=label(p,title,11); at(t,p,x,y); t:SetSize(width or 292,16); f.fieldLabels[key]=t
        local b=W.dropdown(p,width or 292,values,changed); at(b,p,x,y+18); f.fields[key]=b; return b
    end
    field("name","Name",identity,14,38,714)
    f.enabled=check(identity,"Visual enabled",function() end); at(f.enabled,identity,754,60)
    field("target","Target path - leave blank for an independent screen panel",identity,14,91,714)
    f.useSelected=button(identity,"Use selected object",240,function()
        if UI.target and not UI.target.visual then f.fields.target:SetText(path(UI.target)); f.draft.target=U.copy(UI.target)
        else f.notice="Select an existing object in the main editor first."; f.status:SetText(f.notice) end
    end); at(f.useSelected,identity,754,109)
    field("container","Visibility container - blank follows the target's containing frame",identity,14,144,714)
    f.screen=button(identity,"Independent on screen",240,function()
        f.fields.target:SetText(""); f.fields.container:SetText(""); W.setChoice(f.fields.mode,"fixed"); W.setChoice(f.fields.layerMode,"manual"); self:visualFieldVisibility()
    end); at(f.screen,identity,754,162)
    choice("kind","Appearance",{{"solid","Solid colour"},{"file","Texture file"},{"atlas","Atlas"}},appearance,14,40,nil,function() self:visualFieldVisibility() end)
    field("asset","Texture file path or atlas name",appearance,14,98)
    f.media=button(appearance,"Browse media",292,function()
        local list,info=FC.adapter:media("texture")
        self:showList("Choose visual texture",list,function(item)
            f.fields.asset:SetText(item[2]); W.setChoice(f.fields.kind,"file"); self:visualFieldVisibility()
        end,info.summary,function() return FC.adapter:media("texture") end)
    end); at(f.media,appearance,14,156)
    for i,pair in ipairs({{"r","Red (0..1)"},{"g","Green (0..1)"},{"b","Blue (0..1)"},{"a","Opacity (0..1)"}}) do
        field(pair[1],pair[2],appearance,14+(i-1)%2*152,206+math.floor((i-1)/2)*58,140)
    end
    f.appearanceHint=label(appearance,"Solid colour uses your tint and opacity. Choose Texture file or Atlas for an image.",11); at(f.appearanceHint,appearance,14,334); f.appearanceHint:SetSize(292,52)
    choice("mode","Sizing",{{"fixed","Fixed dimensions"},{"fill","Fill target bounds"}},geometry,14,40,nil,function() self:visualFieldVisibility() end)
    field("width","Width",geometry,14,98,140); field("height","Height",geometry,166,98,140)
    choice("point","Visual anchor",W.points,geometry,14,148,140); choice("relativePoint","Target anchor",W.points,geometry,166,148,140)
    field("x","X offset",geometry,14,206,140); field("y","Y offset",geometry,166,206,140)
    f.fillHint=label(geometry,"Fill follows all target edges. Positive padding insets; negative padding expands.",11); at(f.fillHint,geometry,14,104); f.fillHint:SetSize(292,90)
    for i,key in ipairs({"left","right","top","bottom"}) do field(key,"Padding: "..key,geometry,14+(i-1)%2*152,264+math.floor((i-1)/2)*58,140) end
    local function manualLayers() W.setChoice(f.fields.layerMode,"manual") end
    choice("layerMode","Layer relationship",{{"manual","Manual strata / level"},{"behind","Behind target"}},layers,14,40)
    choice("strata","Frame strata - selects manual",W.strata,layers,14,98,nil,manualLayers)
    field("level","Frame level (0..10000)",layers,14,156):SetScript("OnTextChanged",function(_,userInput) if userInput then manualLayers() end end)
    choice("layer","Texture draw layer",W.layers,layers,14,214)
    field("sublevel","Texture sublevel (-8..7)",layers,14,272)
    local layerHint=label(layers,"Behind follows the target's strata and level minus one. Draw layer orders this panel's texture.",11); at(layerHint,layers,14,334); layerHint:SetSize(292,54)
    f.hint=label(f,"Drag the title bar to move this window. Panels stay click-through and use screen UI units.\nSave applies changes. Close discards unsaved edits. Target clipping and alpha are not inherited.",11); at(f.hint,f,18,708); f.hint:SetSize(1000,36)
    f.status=label(f,"",12); at(f.status,f,18,756); f.status:SetSize(1000,36)
    f.save=button(f,"Create",130,function() self:saveVisual() end); at(f.save,f,894,808); W.tone(f.save,"primary")
    f.duplicate=button(f,"Duplicate",120,function()
        if FC.readOnlyData then return end
        local id,why=FC.visuals:duplicate(f.id)
        if id then FC.engine:sync(); self:editVisual(id) else f.notice=why; f.status:SetText(why) end
    end); at(f.duplicate,f,16,808)
    f.delete=button(f,"Delete",100,function()
        if FC.readOnlyData or not f.id then return end
        FC.visuals:delete(f.id); FC.engine:sync(); FC.visuals:tick(); f:Hide(); self:message("Visual deleted. Restricted cleanup remains pending until permitted; see Report.")
    end); at(f.delete,f,148,808); W.tone(f.delete,"danger")
    f:SetScript("OnUpdate",function(_,dt)
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
function UI:visualFieldVisibility()
    local f=self.visualFrame; local fixed=f.fields.mode.value=="fixed"
    for _,key in ipairs({"width","height","point","relativePoint"}) do W.show(f.fields[key],fixed); W.show(f.fieldLabels[key],fixed) end
    for _,key in ipairs({"left","right","top","bottom"}) do W.show(f.fields[key],not fixed); W.show(f.fieldLabels[key],not fixed) end
    W.show(f.fillHint,not fixed)
    local asset=f.fields.kind.value~="solid"
    W.show(f.fields.asset,asset); W.show(f.fieldLabels.asset,asset)
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
        if e.options then W.setChoice(e,values[key]) else e:SetText(tostring(values[key] or "")) end
    end
    f.enabled:SetChecked(v.enabled); f.save.text:SetText(id and "Save" or "Create")
    W.show(f.duplicate,id~=nil and not FC.readOnlyData); W.show(f.delete,id~=nil and not FC.readOnlyData); W.show(f.save,not FC.readOnlyData)
    self:visualFieldVisibility(); f.status:SetText("Changes apply on Save. Close leaves unsaved edits unapplied."); f:Show(); W.focus(f)
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
