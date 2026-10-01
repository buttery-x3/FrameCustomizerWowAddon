local _,FC=...
local U,P=FC.Util,FC.Properties
local UI={}
FC.Editor=UI
local FONT="Fonts\\FRIZQT__.TTF"
local function label(parent,text,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(FONT,size or 12,""); f:SetTextColor(0.87,0.9,0.94); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetText(text or "")
    return f
end
local function panel(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
local function button(parent,text,w,callback)
    local b=CreateFrame("Button",nil,parent); b:SetSize(w or 100,26)
    panel(b,0.16,0.2,0.26); local h=b:CreateTexture(nil,"HIGHLIGHT"); h:SetAllPoints(); h:SetColorTexture(0.35,0.6,0.8,0.3)
    b.text=label(b,text,12); b.text:SetPoint("CENTER"); b.text:SetJustifyH("CENTER")
    b:SetScript("OnClick",callback); return b
end
local function input(parent,width)
    local e=CreateFrame("EditBox",nil,parent); e:SetSize(width or 230,26); e:SetFont(FONT,12,""); e:SetAutoFocus(false)
    e:SetMaxLetters(240); e:SetTextInsets(7,7,0,0); e:SetTextColor(1,1,1); panel(e,0.06,0.08,0.11)
    e:SetScript("OnEscapePressed",function(s) s:ClearFocus() end)
    e:SetScript("OnEnterPressed",function(s) s:ClearFocus() end)
    return e
end
local function check(parent,text,callback)
    local b=CreateFrame("CheckButton",nil,parent); b:SetSize(20,20); panel(b,0.06,0.08,0.11)
    local t=b:CreateTexture(nil,"ARTWORK"); t:SetPoint("TOPLEFT",3,-3); t:SetPoint("BOTTOMRIGHT",-3,3); t:SetColorTexture(0.25,0.8,0.7,1); b:SetCheckedTexture(t)
    b.text=label(b,text,12); b.text:SetPoint("LEFT",b,"RIGHT",7,0)
    b:SetScript("OnClick",function(s) callback(s:GetChecked()==true) end); return b
end
local function at(o,p,x,y) o:ClearAllPoints(); o:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y) end
local function show(o,on) if on then o:Show() else o:Hide() end end
function UI:tooltip(owner,text)
    if not self.tip then
        local f=CreateFrame("Frame",nil,UIParent); FC.adapter.owned[f]=true; self.tip=f
        f:SetFrameStrata("TOOLTIP"); f:EnableMouse(false); panel(f,0.035,0.05,0.07)
        f.text=label(f,"",12); at(f.text,f,10,10); f.text:SetWidth(500)
    end
    local f=self.tip; f:ClearAllPoints(); f:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-2)
    f.text:SetText(text); f:SetSize(520,150); f.text:SetHeight(130); f:Show()
end
function UI:hideTooltip() if self.tip then self.tip:Hide() end end
function UI:message(text) self.messageText=text; if self.notice then self.notice:SetText(text or "") end end
function UI:rule() return self.id and FC.db.rules[self.id] end
function UI:changed()
    FC.engine:sync(); self:renderInspector(); self.dirty=true
end
function UI:findRule(target)
    local key=U.joinTarget(target)
    for id,r in pairs(FC.db.rules) do if U.joinTarget(r.target)==key then return id end end
end
function UI:select(o,id)
    if o and FC.adapter:excluded(o) then return end
    self.object=o; self.id=id; self.property=nil; self.target=nil; self.identityReason=nil
    if o then
        self.target,self.identityReason=FC.Resolver.describe(FC.adapter,o)
        if self.target then self.id=self:findRule(self.target) end
        FC.discovery:reveal(o)
    end
    self.ensureSelection=true
    self:renderInspector(); self.dirty=true
end
function UI:createRule()
    if not self.target or FC.readOnlyData then self:message("No writable stable identity / saved-data schema unsupported."); return end
    local count=0; for _ in pairs(FC.db.rules) do count=count+1 end
    if count>=FC.LIMITS.rules then self:message("128-entry limit reached."); return end
    local id="r"..FC.db.nextID
    while FC.db.rules[id] do FC.db.nextID=FC.db.nextID+1; id="r"..FC.db.nextID end
    FC.db.nextID=FC.db.nextID+1
    FC.db.rules[id]={target=U.copy(self.target),enabled=true,periodic=false,interval=2,overrides={}}
    self.id=id; self:changed(); self:message("Entry created. Enable individual property overrides to change this object.")
end
function UI:saveProperty(enabled)
    local rule=self:rule(); local d=self.property
    if not rule or not d or FC.readOnlyData then return end
    if enabled==false then
        local old=rule.overrides[d.id]
        if old then old.enabled=false end
        self:changed(); self:message("Override disabled. Existing appearance may need a normal refresh or /reload."); return
    end
    local value={}
    if d.id=="position" and self.positionReason then self:message(self.positionReason); self.override:SetChecked(false); return end
    if d.id=="position" and self.positionAnchors then value.anchors=U.copy(self.positionAnchors) end
    for i,field in ipairs(d.inputs) do
        local text=self.fields[i].edit:GetText()
        value[field[1]]=type(d.default[field[1]])=="number" and tonumber(text) or text
    end
    local valid,why=d.validate(value)
    local interval=tonumber(self.propInterval:GetText())
    if not valid or not FC.Schema.interval(interval) then self:message(why or "Interval must be 0.25 to 60 seconds."); self.override:SetChecked(rule.overrides[d.id] and rule.overrides[d.id].enabled or false); return end
    local overrides=U.copy(rule.overrides)
    local per=nil; if self.mode==2 then per=false elseif self.mode==3 then per=true end
    overrides[d.id]={value=valid,enabled=true,periodic=per,interval=per~=nil and interval or nil}
    local conflict=P.conflict(overrides)
    if conflict then self:message(conflict); self.override:SetChecked(rule.overrides[d.id] and rule.overrides[d.id].enabled or false); return end
    rule.overrides=overrides; self:changed(); self:message("Saved enabled override. The status below reflects current permission and verification.")
end
function UI:entrySettings()
    local rule=self:rule(); if not rule or FC.readOnlyData then return end
    local n=tonumber(self.interval:GetText())
    if not FC.Schema.interval(n) then self:message("Interval must be 0.25 to 60 seconds."); return end
    rule.periodic=self.periodic:GetChecked()==true; rule.interval=n
    self:changed(); self:message("Entry enforcement settings saved.")
end
function UI:chooseProperty(d)
    self.property=d
    local rule=self:rule(); local entry=rule and rule.overrides[d.id]
    if rule then self.object=FC.Resolver.resolve(FC.adapter,rule.target) end
    local value=entry and entry.value or U.copy(d.default)
    self.positionReason=d.id=="position" and (not entry or not entry.enabled) and "Inaccessible: creating Position requires a readable anchor snapshot" or nil
    if (not entry or d.id=="position" and not entry.enabled) and self.object and FC.adapter:canRead(self.object,d) then
        local ok,current,reason=pcall(d.read,FC.adapter,self.object)
        if ok and current then local valid=d.validate(current); if valid then value=valid; self.positionReason=nil end end
        if d.id=="position" and not current then self.positionReason=ok and reason or "Inaccessible: could not capture anchor layout" end
    end
    self.positionAnchors=d.id=="position" and U.copy(value.anchors) or nil
    self.draftValue=U.copy(value)
    self.propertyTitle:SetText(d.label); self.help:SetText(d.help)
    self.override:SetChecked(entry and entry.enabled or false)
    self.mode=(not entry or entry.periodic==nil) and 1 or (entry.periodic and 3 or 2)
    self.modeButton.text:SetText(({"Inherit entry","Normal only","Periodic"})[self.mode])
    self.propInterval:SetText(tostring(entry and entry.interval or rule and rule.interval or 2))
    for i,row in ipairs(self.fields) do
        local field=d.inputs[i]; show(row.edit,field~=nil); show(row.label,field~=nil); show(row.media,field and field[3]~=nil)
        row.mediaType=field and field[3]
        if field then row.label:SetText(field[2]); row.edit:SetText(tostring(value[field[1]] or "")) end
    end
    self:updateMediaLabels()
    show(self.anchorDetails,d.id=="position")
    show(self.form,true)
    self:status()
end
function UI:renderInspector()
    if not self.frame then return end
    local rule=self:rule()
    if rule then
        self.target=rule.target
        local o,why=FC.Resolver.resolve(FC.adapter,rule.target); self.object=o; self.identityReason=why
    end
    local kind=self.object and FC.adapter:kind(self.object) or (rule and rule.target.types[#rule.target.types])
    self.selection:SetText(self.object and FC.adapter:label(self.object).." ["..(kind or "?").."]" or self.target and U.joinTarget(self.target) or "Select an object in the hierarchy or use Pick")
    self.identity:SetText(self.identityReason or (rule and "Saved entry "..self.id.."  |  "..(kind or "unknown") or self.target and "Inspection only. Create an entry to enable overrides." or "Browse without modifying UI objects. Pick selects a frame; expand it to reach its regions."))
    show(self.create,self.target and not rule and not FC.readOnlyData)
    show(self.enabled,rule~=nil); show(self.remove,rule~=nil); show(self.apply,rule~=nil); show(self.undo,rule~=nil)
    show(self.periodic,rule~=nil); show(self.interval,rule~=nil); show(self.enforcementSave,rule~=nil)
    if rule then self.enabled:SetChecked(rule.enabled); self.periodic:SetChecked(rule.periodic); self.interval:SetText(tostring(rule.interval)) end
    local index=0
    for _,d in ipairs(P.order) do
        local b=self.propertyButtons[d.id]
        if kind and P.applicable(d,kind) then
            at(b,self.frame,365,248+index*34); b:Show(); index=index+1
            local e=rule and rule.overrides[d.id]
            b.text:SetText((e and e.enabled and "[x] " or "[ ] ")..d.label)
        else b:Hide() end
    end
    if index==0 then
        self.create:Hide(); self.help:SetText("")
        if kind then self:message("No property definitions for "..kind.." in version "..FC.VERSION.."; this object is inspect-only.") end
    end
    if self.property and kind and P.applicable(self.property,kind) then self:chooseProperty(self.property)
    else
        self.property=nil; self.form:Hide()
        for _,d in ipairs(P.order) do if kind and P.applicable(d,kind) then self:chooseProperty(d); break end end
    end
    self:status()
end
function UI:status()
    if not self.frame then return end
    self.pause.text:SetText(FC.db.paused and "Resume All" or "Pause All")
    self.globalStatus:SetText(FC.db.paused and "ALL ENFORCEMENT PAUSED  |  /fcu resume to resume" or "Normal: setter posthooks + 2s readable verification. Periodic writes: 0.25..60s; lower intervals cost more.")
    local d=self.property; if not d then return end
    local rule=self:rule(); local entry=rule and rule.overrides[d.id]
    if rule then self.object=FC.Resolver.resolve(FC.adapter,rule.target) end
    local lines={}
    if self.object then
        local allowed,why=FC.adapter:canWrite(self.object,d,entry and entry.enabled and entry.value or self.draftValue or d.default)
        if d.id=="position" and self.positionReason and (allowed or why and why:find("Unsupported layout:",1,true)) then allowed=false; why=self.positionReason end
        lines[#lines+1]=allowed and "Operation available (rechecked at application)." or "Unavailable: "..(why or "unknown permission")
        if FC.adapter:canRead(self.object,d) then
            local ok,value=pcall(d.read,FC.adapter,self.object)
            local current=ok and value and d.validate(value)
            if current then
                local s={}; for _,f in ipairs(d.inputs) do s[#s+1]=f[1].."="..tostring(current[f[1]]):gsub("|","||") end
                lines[#lines+1]="Accessible current value: "..table.concat(s,"  ")
                if current.anchors then lines[#lines+1]=#current.anchors.." anchors preserved. Edit X/Y to translate; points and relatives stay fixed." end
            else lines[#lines+1]="Current value unavailable / outside the supported format." end
        else lines[#lines+1]=d.id=="position" and "Current anchors inaccessible; position needs a readable layout." or "Current value inaccessible; a permitted constant write does not require a baseline." end
    else lines[#lines+1]="Target unresolved / not currently accessible." end
    local state=self.id and FC.engine.states[self.id]; local job=state and state.jobs[d.id]
    if job then lines[#lines+1]="State: "..job.status; if job.reason then lines[#lines+1]=job.reason end
    else lines[#lines+1]="Inspection only: this property has no enabled override." end
    if FC.db.paused or rule and not rule.enabled then lines[#lines+1]="Paused: no queued, hooked, or periodic writes run." end
    if not rule then lines[#lines+1]="Create an entry before enabling overrides." end
    self.readout:SetText(table.concat(lines,"\n\n"))
    show(self.override,rule~=nil and not FC.readOnlyData); show(self.commit,rule~=nil and not FC.readOnlyData)
end
function UI:rows()
    local query=self.search:GetText():lower()
    if self.saved then
        local out={}; local ids={}; for id in pairs(FC.db.rules) do ids[#ids+1]=id end; table.sort(ids)
        for _,id in ipairs(ids) do
            local r=FC.db.rules[id]; local text=id.." "..U.joinTarget(r.target)
            if text:lower():find(query,1,true) then out[#out+1]={id=id,label=(r.enabled and "[on] " or "[paused] ")..text,depth=0} end
        end
        return out
    end
    return FC.discovery:rows(query)
end
function UI:renderRows()
    local rows=self:rows(); local count=math.min(36,math.floor((self.frame:GetHeight()-245)/20))
    self.offset=U.clamp(self.offset or 0,0,math.max(0,#rows-count))
    if self.ensureSelection then
        for index,node in ipairs(rows) do
            if node.object and node.object==self.object or node.id and node.id==self.id then
                if index<=self.offset then self.offset=index-1 elseif index>self.offset+count then self.offset=index-count end
                break
            end
        end
        self.ensureSelection=nil
    end
    for i,b in ipairs(self.rowsPool) do
        local node=rows[self.offset+i]; show(b,i<=count and node~=nil)
        if i<=count and node then
            b.node=node
            local indent=self.saved and 0 or math.min(node.depth,12)*9
            b.text:ClearAllPoints()
            b.text:SetPoint("LEFT",b,"LEFT",27+indent,0)
            b.text:SetWidth((self.saved and 295 or 222)-indent)
            b.text:SetText(node.label)
            b.kind:SetText(node.id and "" or (node.path and "" or "? ")..(node.kind or "?"))
            b.text:SetTextColor((node.id or node.path) and 0.87 or 0.62,0.9,0.94)
            local selected=node.id and node.id==self.id or node.object and node.object==self.object
            show(b.selected,selected)
            b.arrow:ClearAllPoints(); b.arrow:SetPoint("LEFT",b,"LEFT",indent,0)
            b.arrow.text:SetText(FC.discovery:isExpanded(node) and "-" or "+")
            local hasChildren=not node.id and (FC.discovery.query~="" and node.filterHasChildren or FC.discovery.query=="" and #node.children>0)
            show(b.arrow,not node.id and (not node.loaded or node.loading or hasChildren))
        end
    end
    self.count:SetText((#rows==0 and "0" or (self.offset+1).."-"..math.min(#rows,self.offset+count)).." / "..#rows.." rows; "..#FC.discovery.nodes.." discovered. Wheel scrolls.")
    self.dirty=false; FC.discovery.changed=false
end
function UI:selectPath(path)
    local parts={}; for part in path:gmatch("[^.]+") do if not U.identifier(part) then self:message("Use an exact global name and dot-separated parent keys."); return end; parts[#parts+1]=part end
    if #parts<1 or #parts>13 then self:message("Invalid target path."); return end
    local o,why=FC.adapter:global(parts[1])
    for i=2,#parts do if not o then break end; o,why=FC.adapter:keyChild(o,parts[i]) end
    if o then self.saved=false; self.search:SetText(""); self:select(o); self:message("Selected verified path.") else self:message(why or "Path unavailable.") end
end
function UI:updateMediaLabels()
    if not self.property then return end
    local summary=""
    for i,row in ipairs(self.fields) do
        if row.mediaType then
            local list,info=FC.adapter:media(row.mediaType)
            local name="Manual value"
            if self.property.id=="texture" and self.fields[1].edit:GetText()=="atlas" then name="Manual atlas"
            else
                for _,item in ipairs(list) do
                    if item[2]==row.edit:GetText() then name=item.source..": "..U.cleanLabel(item[1]); break end
                end
                if row.mediaChoice and row.mediaChoice[2]==row.edit:GetText() then
                    name=row.mediaChoice.source..": "..U.cleanLabel(row.mediaChoice[1])
                end
            end
            row.label:SetText(name)
            summary=info.available and ("SharedMedia detected - Browse media to choose assets") or "SharedMedia unavailable - built-ins / manual values available"
        end
    end
    if self.mediaSummary then self.mediaSummary:SetText(summary) end
end
function UI:media(row)
    local list,info=FC.adapter:media(row.mediaType)
    self:showList("Choose "..row.mediaType,list,function(item)
        row.mediaChoice=item
        row.edit:SetText(item[2])
        if self.property.id=="texture" then self.fields[1].edit:SetText("file") end
        self:updateMediaLabels()
        self:message(item.source..": "..U.cleanLabel(item[1]).." selected. Commit value to save the resolved file path.")
    end,info.summary,function() return FC.adapter:media(row.mediaType) end)
end
function UI:showList(title,items,onSelect,summary,refresh)
    if not self.listFrame then
        local f=CreateFrame("Frame",nil,UIParent); FC.adapter.owned[f]=true; self.listFrame=f
        f:SetSize(650,555); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); panel(f,0.08,0.11,0.15)
        f.title=label(f,"",14); at(f.title,f,16,14); f.title:SetWidth(490)
        local close=button(f,"Close",65,function() f:Hide() end); at(close,f,568,8)
        f.summary=label(f,"",11); at(f.summary,f,18,44); f.summary:SetSize(610,38)
        f.search=input(f,345); at(f.search,f,18,87)
        f.source=button(f,"All sources",140,function()
            f.sourceIndex=f.sourceIndex%3+1
            f.source.text:SetText(({"All sources","SharedMedia only","Built-ins only"})[f.sourceIndex]); f.offset=0; self:renderList()
        end); at(f.source,f,373,87)
        local reload=button(f,"Refresh",105,function()
            if f.refresh then local new,info=f.refresh(); f.items=new; f.summary:SetText(info.summary); self:renderList() end
        end); at(reload,f,523,87)
        f.rows={}
        for i=1,13 do
            local b=button(f,"",610,function(s) if s.item then f.onSelect(s.item); f:Hide() end end)
            at(b,f,18,126+(i-1)*28); b.text:SetJustifyH("LEFT"); b.text:ClearAllPoints(); b.text:SetPoint("LEFT",8,0); b.text:SetSize(375,16); b.text:SetWordWrap(false)
            b.source=label(b,"",10); b.source:SetPoint("RIGHT",-8,0); b.source:SetWidth(215); b.source:SetJustifyH("RIGHT")
            b:SetScript("OnEnter",function() if b.item then self:tooltip(b,U.cleanLabel(b.item[1]).."\n"..b.item.source.." / "..b.item.mediaType.."\n"..b.item[2]:gsub("|","||")) end end)
            b:SetScript("OnLeave",function() self:hideTooltip() end); f.rows[i]=b
        end
        f.count=label(f,"",11); at(f.count,f,18,498)
        local tip=label(f,"Search names, sources or paths. Hover for full path. Manual path / atlas entry stays in the editor.",11); at(tip,f,18,520); tip:SetWidth(610)
        f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,delta) f.offset=math.max(0,f.offset-delta*3); self:renderList() end)
        f.search:SetScript("OnTextChanged",function() f.offset=0; self:renderList() end)
        f:SetScript("OnHide",function() self:hideTooltip() end)
    end
    local f=self.listFrame; f.items=items; f.onSelect=onSelect; f.refresh=refresh; f.offset=0; f.sourceIndex=1
    f.source.text:SetText("All sources"); f.title:SetText(title); f.summary:SetText(summary or ""); f.search:SetText(""); f:Show(); self:renderList()
end
function UI:renderList()
    local f=self.listFrame; if not f.items then return end
    local filtered={}; local q=f.search:GetText():lower()
    for _,item in ipairs(f.items) do
        local sourceOK=f.sourceIndex==1 or f.sourceIndex==2 and item.source=="SharedMedia" or f.sourceIndex==3 and item.source~="SharedMedia"
        if sourceOK and (item[1].." "..item[2].." "..item.source.." "..item.mediaType):lower():find(q,1,true) then filtered[#filtered+1]=item end
    end
    f.offset=math.min(f.offset,math.max(0,#filtered-13))
    for i,b in ipairs(f.rows) do
        b.item=filtered[f.offset+i]; show(b,b.item~=nil)
        if b.item then b.text:SetText(U.cleanLabel(b.item[1])); b.source:SetText(b.item.source.." / "..b.item.mediaType) end
    end
    f.count:SetText(#filtered==0 and "No matching assets. Try All sources, Refresh, or a manual value." or (f.offset+1).."-"..math.min(f.offset+13,#filtered).." of "..#filtered.." assets. Mouse wheel scrolls.")
end
function UI:highlight(o)
    if not self.outline then
        local f=CreateFrame("Frame",nil,UIParent); FC.adapter.owned[f]=true; self.outline=f
        f:SetFrameStrata("TOOLTIP"); f:EnableMouse(false)
        local top=f:CreateTexture(nil,"OVERLAY"); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(2); top:SetColorTexture(0.2,0.9,0.8,0.8)
        local bot=f:CreateTexture(nil,"OVERLAY"); bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(2); bot:SetColorTexture(0.2,0.9,0.8,0.8)
        local left=f:CreateTexture(nil,"OVERLAY"); left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(2); left:SetColorTexture(0.2,0.9,0.8,0.8)
        local right=f:CreateTexture(nil,"OVERLAY"); right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(2); right:SetColorTexture(0.2,0.9,0.8,0.8)
    end
    local l,b,w,h,scale
    if o and FC.adapter:inspectable(o) then l,b,w,h,scale=FC.adapter:rect(o) end
    if l then
        local s=scale/UIParent:GetEffectiveScale(); self.outline:ClearAllPoints(); self.outline:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",l*s,b*s); self.outline:SetSize(w*s,h*s); self.outline:Show()
    else self.outline:Hide() end
end
function UI:startPick()
    if type(GetMouseFoci)~="function" then self:message("GetMouseFoci unavailable in this client."); return end
    self.picking=true; self.pickCandidate=nil; self.frame:Hide()
    if not self.pickFrame then
        local f=CreateFrame("Frame",nil,UIParent); self.pickFrame=f; FC.adapter.owned[f]=true
        f:SetSize(660,38); f:SetPoint("TOP",UIParent,"TOP",0,-55); f:SetFrameStrata("TOOLTIP"); panel(f,0.05,0.1,0.12,0.95)
        f.text=label(f,"",13); f.text:SetPoint("CENTER"); f.text:SetSize(630,32)
        -- Keyboard selection leaves mouse focus on the target. No clicks or
        -- scripts are forwarded to Blizzard controls.
        f:EnableKeyboard(true); f:SetPropagateKeyboardInput(false)
        f:SetScript("OnKeyDown",function(_,key)
            if key=="ESCAPE" or key=="ENTER" then
                self.picking=false; f:Hide(); self.frame:Show()
                if key=="ENTER" and self.pickCandidate then self.saved=false; self.search:SetText(""); self:select(self.pickCandidate) end
            end
        end)
    end
    self.pickFrame:Show(); self.pickFrame.text:SetText("Hover a frame. Enter selects; Escape cancels. Regions: expand after selection.")
end
function UI:tick()
    if self.picking then
        if InCombatLockdown() then self.picking=false; self.pickFrame:Hide(); self.frame:Show(); self:message("Picker closed on entering combat."); return end
        local foci=GetMouseFoci()
        if U.safe(foci) and type(foci)=="table" then
            self.pickCandidate=nil
            for i=1,math.min(#foci,16) do
                local o=foci[i]
                if FC.adapter:inspectable(o) and not FC.adapter:excluded(o) then self.pickCandidate=o; break end
            end
        end
        self.pickFrame.text:SetText(self.pickCandidate and FC.adapter:label(self.pickCandidate).."  |  Enter / Esc" or "Hover an accessible frame. Enter selects; Escape cancels.")
        self:highlight(self.pickCandidate)
    elseif self.frame and self.frame:IsShown() then
        FC.discovery:tick()
        if FC.discovery.notice and FC.discovery.notice~=self.scanNotice then self.scanNotice=FC.discovery.notice; self:message(self.scanNotice) end
        if self.dirty or FC.discovery.changed then self:renderRows() end
        if not self.lastStatus or GetTime()-self.lastStatus>=0.5 then self.lastStatus=GetTime(); self:status() end
        self:highlight(self.object)
    elseif self.outline then self.outline:Hide() end
end
function UI:report(text,title)
    if not self.reportFrame then
        local f=CreateFrame("Frame",nil,UIParent); self.reportFrame=f; FC.adapter.owned[f]=true
        f:SetSize(820,560); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); panel(f,0.06,0.09,0.13)
        f.title=label(f,"",15); at(f.title,f,18,15)
        local close=button(f,"Close",65,function() f:Hide() end); at(close,f,738,8)
        local tip=label(f,"Click text, Ctrl+A, Ctrl+C to copy. This panel does not access the clipboard or write files.",12); at(tip,f,18,45)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); at(scroll,f,18,78); scroll:SetSize(755,460)
        local edit=input(scroll,735); edit:SetMultiLine(true); edit:SetMaxLetters(30000); edit:SetHeight(440); edit:SetAutoFocus(false)
        edit:SetScript("OnTextChanged",function(s) s:SetHeight(math.max(440,s:GetNumLines()*16+30)) end)
        scroll:SetScrollChild(edit); f.edit=edit
    end
    local f=self.reportFrame; f.title:SetText(title or "FrameCustomizer diagnostic report"); f.edit:SetText(text:sub(1,29000)); f:Show(); f.edit:SetFocus(); f.edit:HighlightText()
end
function UI:build()
    if self.frame then return end
    local f=CreateFrame("Frame","FrameCustomizerEditor",UIParent); FC.adapter.owned[f]=true; self.frame=f
    f:SetSize(1120,820); f:SetScale(math.min(1,(UIParent:GetWidth()-40)/1120,(UIParent:GetHeight()-40)/820)); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true); f:SetResizeBounds(1000,800,1600,1100)
    panel(f,0.075,0.095,0.13)
    local title=label(f,"FrameCustomizer",22); at(title,f,16,12)
    local subtitle=label(f,"Existing UI objects / declarative visual overrides",12); at(subtitle,f,245,20)
    local drag=CreateFrame("Frame",nil,f); drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT",-70,0); drag:SetHeight(45); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() f:StartMoving() end); drag:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    local close=button(f,"Close",62,function() f:Hide() end); close:SetPoint("TOPRIGHT",-12,-10)
    local refresh=button(f,"Refresh",90,function() FC.discovery:refresh(); self.search:SetText(""); self.offset=0; self.dirty=true end); at(refresh,f,16,54)
    local pick=button(f,"Pick",70,function() if not InCombatLockdown() then self:startPick() else self:message("Start the keyboard picker outside combat.") end end); at(pick,f,114,54)
    local hierarchy=button(f,"Hierarchy",88,function()
        self.saved=false; self.offset=0; self.dirty=true; self.ensureSelection=true
        if self.object then FC.discovery:reveal(self.object) end
    end); at(hierarchy,f,192,54)
    local saved=button(f,"Saved entries",110,function() self.saved=true; self.offset=0; self.dirty=true end); at(saved,f,288,54)
    self.pause=button(f,"Pause All",110,function() FC.SetPaused(not FC.db.paused); self:status(); self:message("Pause changes enforcement only. Existing visuals may require refresh /reload.") end); at(self.pause,f,406,54)
    local report=button(f,"Report",85,function() FC.ShowReport(self.id) end); at(report,f,524,54)
    self.search=input(f,235); at(self.search,f,16,99); self.search:SetScript("OnTextChanged",function() self.offset=0; FC.discovery:rows(self.search:GetText()); self.dirty=true end)
    self.search:SetScript("OnEditFocusGained",function() self:message("Search filters discovered labels, paths and types. Scan search explores more accessible branches.") end)
    local scan=button(f,"Scan search",94,function() FC.discovery:scan(); self:message("Scanning bounded accessible branches. Search results may be incomplete; exact paths and the picker also work.") end); at(scan,f,257,99)
    self.rowsPool={}
    local list=CreateFrame("Frame",nil,f); at(list,f,16,139); list:SetWidth(335); list:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",16,115); list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel",function(_,delta) self.offset=math.max(0,(self.offset or 0)-delta*3); self.dirty=true end)
    for i=1,36 do
        local b=button(list,"",335,function(s)
            if s.node.id then self:select(nil,s.node.id) else self:select(s.node.object); self:message(s.node.reason or "Inspection does not modify the selected object.") end
        end)
        b:SetHeight(19); at(b,list,0,(i-1)*20); b.text:SetHeight(16); b.text:SetWordWrap(false); b.text:SetJustifyH("LEFT"); b.text:ClearAllPoints(); b.text:SetPoint("LEFT",28,0)
        b.arrow=button(b,"+",22,function() if b.node then FC.discovery:expand(b.node) end end); b.arrow:SetHeight(18); b.arrow:SetPoint("LEFT")
        b.selected=panel(b,0.13,0.38,0.42,0.7); b.selected:Hide()
        b.kind=label(b,"",10); b.kind:SetPoint("RIGHT",-4,0); b.kind:SetWidth(78); b.kind:SetJustifyH("RIGHT")
        b:SetScript("OnEnter",function()
            local node=b.node; if not node then return end
            local saved=node.id and FC.db.rules[node.id]
            local path=saved and FC.Util.joinTarget(saved.target) or node.path
            self:tooltip(b,node.label.." ["..(node.kind or "saved entry").."]\n"..(path or "Inspect only: "..(node.identityReason or "no stable identity"))..(node.reason and ("\n"..node.reason) or ""))
        end)
        b:SetScript("OnLeave",function() self:hideTooltip() end)
        self.rowsPool[i]=b
    end
    self.count=label(f,"",10); self.count:SetPoint("BOTTOMLEFT",16,95)
    self.path=input(f,250); self.path:SetPoint("BOTTOMLEFT",16,57)
    local find=button(f,"Find path",79,function() self:selectPath(self.path:GetText()) end); find:SetPoint("LEFT",self.path,"RIGHT",6,0)
    self.selection=label(f,"",16); at(self.selection,f,365,100); self.selection:SetPoint("TOPRIGHT",f,"TOPRIGHT",-125,-100); self.selection:SetHeight(24)
    local copyPath=button(f,"Copy path",95,function()
        if self.target then self:report(U.joinTarget(self.target),"Stable resolver path - Ctrl+A / Ctrl+C")
        else self:message(self.identityReason or "No stable resolver path for this inspect-only object.") end
    end); copyPath:SetPoint("TOPRIGHT",f,"TOPRIGHT",-18,-97)
    self.identity=label(f,"",12); at(self.identity,f,365,132); self.identity:SetPoint("TOPRIGHT",f,"TOPRIGHT",-18,-132); self.identity:SetHeight(48)
    self.create=button(f,"Create customisation",175,function() self:createRule() end); at(self.create,f,365,185)
    self.enabled=check(f,"Entry enabled",function(on) local r=self:rule(); if r and not FC.readOnlyData then r.enabled=on; self:changed() end end); at(self.enabled,f,365,188)
    self.apply=button(f,"Apply Now",90,function() if self.id then FC.engine:apply(self.id); self:message("Queued enabled properties. Apply Now also resets error suspension; paused entries remain paused.") end end); at(self.apply,f,515,184)
    self.undo=button(f,"Undo session",100,function() if self.id then local n,why=FC.engine:undo(self.id); self:renderInspector(); self:message(n.." properties restored. "..why) end end); at(self.undo,f,613,184)
    self.remove=button(f,"Delete",72,function() if self.id and not FC.readOnlyData then FC.db.rules[self.id]=nil; self.id=nil; self:changed(); self:message("Deleted. Enforcement stopped; use normal refresh /reload to refresh appearance.") end end); at(self.remove,f,721,184)
    self.periodic=check(f,"Periodically reapply customisations",function() self:entrySettings() end); at(self.periodic,f,365,222)
    self.interval=input(f,60); at(self.interval,f,660,216)
    self.enforcementSave=button(f,"Save seconds",105,function() self:entrySettings() end); at(self.enforcementSave,f,728,216)
    self.propertyButtons={}
    for _,d in ipairs(P.order) do self.propertyButtons[d.id]=button(f,d.label,218,function() self:chooseProperty(d) end); self.propertyButtons[d.id]:Hide() end
    self.form=CreateFrame("Frame",nil,f); at(self.form,f,598,255); self.form:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-18,110)
    self.propertyTitle=label(self.form,"",15); at(self.propertyTitle,self.form,0,0)
    self.override=check(self.form,"Enable this property override",function(on) self:saveProperty(on) end); at(self.override,self.form,0,28)
    self.fields={}
    for i=1,4 do
        local row={label=label(self.form,"",11),edit=input(self.form,260)}
        at(row.label,self.form,0,59+(i-1)*42); at(row.edit,self.form,0,75+(i-1)*42)
        row.media=button(self.form,"Browse media",105,function() self:media(row) end); at(row.media,self.form,268,75+(i-1)*42)
        row.label:SetWidth(385); row.label:SetHeight(15)
        row.edit:SetScript("OnTextChanged",function(_,userInput) if userInput then self:updateMediaLabels() end end)
        self.fields[i]=row
    end
    self.mediaSummary=label(self.form,"",10); at(self.mediaSummary,self.form,0,224); self.mediaSummary:SetSize(390,16)
    self.modeButton=button(self.form,"Inherit entry",125,function() self.mode=self.mode%3+1; self.modeButton.text:SetText(({"Inherit entry","Normal only","Periodic"})[self.mode]); self:message("Commit value to save this property's strategy override.") end); at(self.modeButton,self.form,0,242)
    self.propInterval=input(self.form,55); at(self.propInterval,self.form,134,242)
    local seconds=label(self.form,"seconds",11); at(seconds,self.form,197,249)
    self.commit=button(self.form,"Commit value",120,function() self:saveProperty(true) end); at(self.commit,self.form,0,276)
    self.anchorDetails=button(self.form,"Anchor details",120,function()
        local value,why
        if self.object and FC.adapter:canRead(self.object,P.byID.position) then value,why=FC.Anchors.read(FC.adapter,self.object) end
        local text="Current readable anchors:\n"..(value and FC.Anchors.details(value) or why or "Inaccessible / unavailable")
        local entry=self:rule() and self:rule().overrides.position
        if entry then text=text.."\n\nConfigured anchors (enabled="..tostring(entry.enabled).."):\n"..FC.Anchors.details(entry.value) end
        self:report(text,"Position anchor details")
    end); at(self.anchorDetails,self.form,130,276)
    self.help=label(f,"",11); at(self.help,f,365,576); self.help:SetWidth(220); self.help:SetHeight(90)
    self.readout=label(self.form,"",11); at(self.readout,self.form,0,310); self.readout:SetPoint("TOPRIGHT",self.form,"TOPRIGHT",0,-310); self.readout:SetHeight(130)
    self.notice=label(f,"",11); self.notice:SetPoint("BOTTOMLEFT",365,62); self.notice:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-25,62); self.notice:SetHeight(42)
    self.globalStatus=label(f,"",11); self.globalStatus:SetPoint("BOTTOMLEFT",16,22); self.globalStatus:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-30,22); self.globalStatus:SetHeight(22)
    local resize=button(f,"/",22); resize:SetPoint("BOTTOMRIGHT",-3,3); resize:SetScript("OnMouseDown",function() f:StartSizing("BOTTOMRIGHT") end); resize:SetScript("OnMouseUp",function() f:StopMovingOrSizing(); self.dirty=true end)
    f:SetScript("OnSizeChanged",function() self.dirty=true end)
    f:SetScript("OnHide",function() if not self.picking and self.outline then self.outline:Hide() end; self:hideTooltip() end)
    FC.discovery:refresh(); self:renderInspector(); self:renderRows()
end
function UI:toggle()
    self:build()
    if self.opened and self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self.opened=true end
end
