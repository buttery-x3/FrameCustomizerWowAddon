local _,FC=...
local U,P=FC.Util,FC.Properties
local UI={}
FC.Editor=UI
local W=FC.UIKit
local label,panel,button,input,check,at,show=W.label,W.panel,W.button,W.input,W.check,W.at,W.show
UI.widgets=W
function UI:tooltip(owner,text)
    if not self.tip then
        local f=CreateFrame("Frame",nil,UIParent); FC.adapter.owned[f]=true; self.tip=f
        f:SetFrameStrata("TOOLTIP"); f:EnableMouse(false); panel(f,0.035,0.05,0.07); W.border(f)
        if FC.adapter:protected(f) then f:SetClampedToScreen(true) end
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
    local visual=o and FC.adapter.visualIdentity and FC.adapter.visualIdentity[o]
    if visual then self:editVisual(visual.visual); return end
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
    self.positionFinding=self.positionReason and U.finding("inaccessible","anchor_snapshot_required",self.positionReason) or nil
    if (not entry or d.id=="position" and not entry.enabled) and self.object and FC.adapter:canRead(self.object,d) then
        local ok,current,reason,code,category=pcall(d.read,FC.adapter,self.object)
        if ok and current then local valid=d.validate(current); if valid then value=valid; self.positionReason=nil end end
        if d.id=="position" and not current then
            self.positionReason=ok and reason or "Inaccessible: could not capture anchor layout"
            self.positionFinding=U.finding(category or "inaccessible",code or "anchor_capture_failed",self.positionReason)
        end
    end
    self.positionAnchors=d.id=="position" and U.copy(value.anchors) or nil
    self.draftValue=U.copy(value)
    self.propertyTitle:SetText(d.label); self.help:SetText(d.help)
    self.override:SetChecked(entry and entry.enabled or false)
    self.mode=(not entry or entry.periodic==nil) and 1 or (entry.periodic and 3 or 2)
    W.setChoice(self.modeButton,self.mode)
    self.propInterval:SetText(tostring(entry and entry.interval or rule and rule.interval or 2))
    for i,row in ipairs(self.fields) do
        local field=d.inputs[i]; local options=field and self:fieldOptions(d.id,field[1])
        show(row.edit,field~=nil and not options); show(row.choice,options~=nil); show(row.label,field~=nil); show(row.media,field and field[3]~=nil)
        row.mediaType=field and field[3]
        if field then
            row.label:SetText(field[2]); row.edit:SetText(tostring(value[field[1]] or ""))
            if options then row.choice.options=options; W.setChoice(row.choice,value[field[1]]) end
        end
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
    if self.addAttached then show(self.addAttached,self.target~=nil and not self.target.visual and not FC.readOnlyData); show(self.attachedVisuals,self.target~=nil and not self.target.visual) end
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
            at(b,self.propertiesPanel,14,40+index*34); b:Show(); index=index+1
            local e=rule and rule.overrides[d.id]
            b.text:SetText((e and e.enabled and "[x] " or "[ ] ")..(b.shortName or d.label))
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
    self.globalStatus:SetText(FC.db.paused and "ALL ENFORCEMENT PAUSED  |  /fcu resume to resume" or "Drag a window title to move it. Click a window to bring it forward. Changes apply only when saved.")
    local d=self.property; if not d then return end
    local rule=self:rule(); local entry=rule and rule.overrides[d.id]
    if rule then self.object=FC.Resolver.resolve(FC.adapter,rule.target) end
    local lines={}
    if self.object then
        local allowed,why,_,result=FC.adapter:canWrite(self.object,d,entry and entry.enabled and entry.value or self.draftValue or d.default)
        self.geometryResult=result
        if d.id=="position" and self.positionReason then
            if result then result.representation=self.positionFinding end
            if allowed or result and result.native.state=="passed" then why=self.positionReason end
            allowed=false
        end
        lines[#lines+1]=allowed and "Operation available (rechecked at application)." or "Unavailable: "..(why or "unknown permission")
        if result then
            lines[#lines+1]="Native/access: "..result.native.state.."; representation: "..result.representation.state.."; policy: "..result.policy.state
            if result.management.advisory then lines[#lines+1]="Advisory: "..result.management.advisory end
            lines[#lines+1]="External layout: "..result.management.state..". Eligibility report shows evidence and scope."
        elseif FC.adapter:canRead(self.object,d) then
            local ok,value=pcall(d.read,FC.adapter,self.object)
            local current=ok and value and d.validate(value)
            if current then
                local s={}; for _,f in ipairs(d.inputs) do s[#s+1]=f[1].."="..tostring(current[f[1]]):gsub("|","||") end
                lines[#lines+1]="Accessible current value: "..table.concat(s,"  ")
                if current.anchors then lines[#lines+1]=#current.anchors.." anchors preserved. Edit X/Y to translate; points and relatives stay fixed." end
            else lines[#lines+1]="Current value unavailable / outside the supported format." end
        else lines[#lines+1]=d.id=="position" and "Current anchors inaccessible; position needs a readable layout." or "Current value inaccessible; a permitted constant write does not require a baseline." end
    else self.geometryResult=nil; lines[#lines+1]="Target unresolved / not currently accessible." end
    local state=self.id and FC.engine.states[self.id]; local job=state and state.jobs[d.id]
    if job then lines[#lines+1]="State: "..job.status; if job.reason then lines[#lines+1]=job.reason end
    else lines[#lines+1]="Inspection only: this property has no enabled override." end
    if FC.db.paused or rule and not rule.enabled then lines[#lines+1]="Paused: no queued, hooked, or periodic writes run." end
    if not rule then lines[#lines+1]="Create an entry before enabling overrides." end
    self.readout:SetText(table.concat(lines,d.permission=="geometry" and "\n" or "\n\n"))
    show(self.eligibilityReport,d.permission=="geometry")
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
    W.setChoice(self.view,self.saved==true)
    local rows=self:rows(); local count=math.min(36,math.floor((self.frame:GetHeight()-372)/22))
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
function UI:showList(title,items,onSelect,summary,refresh,kind)
    if not self.listFrame then
        local f=W.window(title,760,634); self.listFrame=f
        f.summary=label(f,"",11); at(f.summary,f,18,64); f.summary:SetSize(724,40)
        local searchLabel=label(f,"Search names, sources or paths",11); at(searchLabel,f,18,110); searchLabel:SetSize(346,16)
        f.search=input(f,346); at(f.search,f,18,128)
        f.source=W.dropdown(f,228,{{1,"All sources"},{2,"SharedMedia only"},{3,"Built-ins only"}},function(value)
            f.sourceIndex=value; f.offset=0; self:renderList()
        end); at(f.source,f,376,128)
        local reload=button(f,"Refresh",124,function()
            if f.refresh then local new,info=f.refresh(); f.items=new; f.summary:SetText(info.summary); self:renderList() end
        end); at(reload,f,616,128)
        local names=label(f,"NAME",10); at(names,f,26,170); names:SetSize(400,16)
        f.column=label(f,"SOURCE / TYPE",10); at(f.column,f,446,170); f.column:SetSize(296,16)
        f.rows={}
        for i=1,13 do
            local b=button(f,"",724,function(s) if s.item then f:Hide(); f.onSelect(s.item) end end)
            at(b,f,18,190+(i-1)*28); b:SetHeight(27); b.text:SetJustifyH("LEFT"); b.text:ClearAllPoints(); b.text:SetPoint("LEFT",8,0); b.text:SetSize(405,18)
            b.source=label(b,"",10); b.source:SetPoint("RIGHT",-8,0); b.source:SetSize(290,18); b.source:SetWordWrap(false); b.source:SetJustifyH("RIGHT")
            b:SetScript("OnEnter",function() if b.item then self:tooltip(b,U.cleanLabel(b.item[1]).."\n"..b.item.source.." / "..b.item.mediaType.."\n"..b.item[2]:gsub("|","||")) end end)
            b:SetScript("OnLeave",function() self:hideTooltip() end); f.rows[i]=b
        end
        f.count=label(f,"",11); at(f.count,f,18,574); f.count:SetSize(490,20)
        f.tip=label(f,"",11); at(f.tip,f,18,604); f.tip:SetWidth(724)
        f.previous=button(f,"Previous",95,function() f.offset=math.max(0,f.offset-13); self:renderList() end); at(f.previous,f,540,568)
        f.next=button(f,"Next",95,function() f.offset=f.offset+13; self:renderList() end); at(f.next,f,647,568)
        f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,delta) f.offset=math.max(0,f.offset-delta*3); self:renderList() end)
        f.search:SetScript("OnTextChanged",function() f.offset=0; self:renderList() end)
        W.hook(f,"OnHide",function() self:hideTooltip() end)
    end
    local f=self.listFrame; f.items=items; f.onSelect=onSelect; f.refresh=refresh; f.offset=0; f.sourceIndex=1
    f.contentKind=kind or "assets"; show(f.source,f.contentKind=="assets")
    f.column:SetText(f.contentKind=="assets" and "SOURCE / TYPE" or "STATE / PLACEMENT")
    f.tip:SetText(f.contentKind=="assets" and "Select an asset to use it. Hover for its full path. Save in the editor to apply." or "Select a visual to edit it. Disabled and unavailable visuals remain in this list.")
    W.setChoice(f.source,1); f.title:SetText(title); f.summary:SetText(summary or ""); f.search:SetText(""); f:Show(); W.focus(f); self:renderList()
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
    f.count:SetText(#filtered==0 and ("No matching "..f.contentKind..". Try another search or Refresh.") or (f.offset+1).."-"..math.min(f.offset+13,#filtered).." of "..#filtered.." "..f.contentKind..". Mouse wheel scrolls.")
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
    self.picking=true; self.pickCandidate=nil; self.pickRestore={}; W.closeMenu()
    for _,window in ipairs(W.windows) do
        if window~=self.pickFrame and window:IsShown() then self.pickRestore[#self.pickRestore+1]=window; window:Hide() end
    end
    if not self.pickFrame then
        local f=W.window("Pick an existing object",760,128); self.pickFrame=f
        f:ClearAllPoints(); f:SetPoint("TOP",UIParent,"TOP",0,-40)
        f.text=label(f,"",13); at(f.text,f,18,66); f.text:SetSize(724,44)
        f.close:SetScript("OnClick",function() self:finishPick(false) end)
        -- Keyboard selection leaves mouse focus on the target. No clicks or
        -- scripts are forwarded to Blizzard controls.
        f:EnableKeyboard(true); f:SetPropagateKeyboardInput(false)
        f:SetScript("OnKeyDown",function(_,key)
            if key=="ESCAPE" or key=="ENTER" then
                self:finishPick(key=="ENTER")
            end
        end)
    end
    self.pickFrame:Show(); W.focus(self.pickFrame); self.pickFrame.text:SetText("Hover a frame. Enter selects; Escape cancels. Expand the selected frame to reach its regions.")
end
function UI:finishPick(accept)
    self.picking=false; self.pickFrame:Hide()
    for _,f in ipairs(self.pickRestore or {}) do f:Show(); W.focus(f) end
    self.pickRestore=nil
    if accept and self.pickCandidate then self.saved=false; self.search:SetText(""); self:select(self.pickCandidate); W.focus(self.frame) end
end
function UI:tick()
    W.tick()
    if self.picking then
        if InCombatLockdown() then self:finishPick(false); self:message("Picker closed on entering combat."); return end
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
        local f=W.window("Report",860,620); self.reportFrame=f
        local tip=label(f,"Click the text, then Ctrl+A and Ctrl+C to copy.",12); at(tip,f,18,66); tip:SetSize(824,20)
        local scroll=W.frame(f,"ScrollFrame","UIPanelScrollFrameTemplate"); at(scroll,f,18,98); scroll:SetSize(795,498)
        local edit=input(scroll,775); at(edit,scroll,0,0); edit:SetMultiLine(true); edit:SetJustifyV("TOP"); edit:SetMaxLetters(30000); edit:SetHeight(478); edit:SetAutoFocus(false)
        edit:SetScript("OnTextChanged",function(s) s:SetHeight(math.max(478,s:GetNumLines()*16+30)) end)
        scroll:SetScrollChild(edit); f.edit=edit
    end
    local f=self.reportFrame; f.title:SetText(title or "FrameCustomizer diagnostic report"); f.edit:SetText(text:sub(1,29000)); f:Show(); W.focus(f); f.edit:SetFocus(); f.edit:HighlightText()
end
function UI:fieldOptions(property,key)
    if key=="point" or key=="relativePoint" then return W.points end
    if key=="strata" then return W.strata end
    if key=="layer" then return W.layers end
    if property=="texture" and key=="kind" then return {{"file","Texture file"},{"atlas","Atlas"}} end
    if property=="font" and key=="flags" then return {{"","None"},"OUTLINE","THICKOUTLINE","MONOCHROME","OUTLINE,MONOCHROME","THICKOUTLINE,MONOCHROME"} end
end
function UI:build()
    if self.frame then return end
    local f=W.window("FrameCustomizer",1180,900,"FrameCustomizerEditor"); self.frame=f
    f:SetResizable(true); f:SetResizeBounds(1180,900,1600,1100)
    self.view=W.dropdown(f,180,{{false,"Hierarchy"},{true,"Saved entries"}},function(value)
        self.saved=value; self.offset=0; self.dirty=true; self.ensureSelection=true
        if not value and self.object then FC.discovery:reveal(self.object) end
    end); at(self.view,f,16,64)
    local pick=button(f,"Pick object",100,function() if not InCombatLockdown() then self:startPick() else self:message("Start the picker outside combat.") end end); at(pick,f,208,64)
    local refresh=button(f,"Refresh",84,function() FC.discovery:refresh(); self.search:SetText(""); self.offset=0; self.dirty=true end); at(refresh,f,320,64)
    self.pause=button(f,"Pause All",105,function() FC.SetPaused(not FC.db.paused); self:status(); self:message("Paused overrides stop writing; created visuals retire when permitted. /reload completes recovery.") end); self.pause:SetPoint("TOPRIGHT",-16,-64)
    local report=button(f,"Report",84,function() FC.ShowReport(self.id) end); report:SetPoint("RIGHT",self.pause,"LEFT",-12,0)
    self.browserPanel=W.section(f,"Browse objects",16,112,351,718); self.browserPanel:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",16,70)
    local browser=self.browserPanel
    self.search=input(browser,209); at(self.search,browser,14,42)
    self.search:SetScript("OnTextChanged",function() self.offset=0; FC.discovery:rows(self.search:GetText()); self.dirty=true end)
    W.hook(self.search,"OnEditFocusGained",function() self:message("Search names, paths or types. Scan search discovers more accessible objects.") end)
    local scan=button(browser,"Scan search",100,function() FC.discovery:scan(); self:message("Scanning accessible branches. Expand objects or use an exact path for undiscovered results.") end); at(scan,browser,235,42)
    self.rowsPool={}
    local list=W.frame(browser); self.hierarchyList=list; at(list,browser,8,84); list:SetWidth(335); list:SetPoint("BOTTOMLEFT",browser,"BOTTOMLEFT",8,106); list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel",function(_,delta) self.offset=math.max(0,(self.offset or 0)-delta*3); self.dirty=true end)
    for i=1,36 do
        local b=button(list,"",335,function(s)
            if s.node.id then self:select(nil,s.node.id) else self:select(s.node.object); self:message(s.node.reason or "Inspection does not modify the selected object.") end
        end)
        b:SetHeight(21); at(b,list,0,(i-1)*22); b.text:SetHeight(17); b.text:SetJustifyH("LEFT")
        b.arrow=button(b,"+",22,function() if b.node then FC.discovery:expand(b.node) end end); b.arrow:SetHeight(20); b.arrow:SetPoint("LEFT")
        b.selected=panel(b,0.1,0.32,0.36,1); b.selected:Hide()
        b.kind=label(b,"",10); b.kind:SetPoint("RIGHT",-4,0); b.kind:SetSize(78,16); b.kind:SetWordWrap(false); b.kind:SetJustifyH("RIGHT"); b.kind:SetJustifyV("MIDDLE")
        b:SetScript("OnEnter",function()
            local node=b.node; if not node then return end
            local saved=node.id and FC.db.rules[node.id]; local path=saved and U.joinTarget(saved.target) or node.path
            self:tooltip(b,node.label.." ["..(node.kind or "saved entry").."]\n"..(path or "Inspect only: "..(node.identityReason or "no stable identity"))..(node.reason and ("\n"..node.reason) or ""))
        end)
        b:SetScript("OnLeave",function() self:hideTooltip() end); self.rowsPool[i]=b
    end
    self.count=label(browser,"",10); self.count:SetPoint("BOTTOMLEFT",14,76); self.count:SetSize(323,26)
    local pathLabel=label(browser,"Exact global path",11); pathLabel:SetPoint("BOTTOMLEFT",14,57)
    self.path=input(browser,230); self.path:SetPoint("BOTTOMLEFT",14,18)
    local find=button(browser,"Find",80,function() self:selectPath(self.path:GetText()) end); find:SetPoint("LEFT",self.path,"RIGHT",10,0)
    local selected=W.section(f,"Selected object",383,112,781,154); self.selectedPanel=selected; selected:SetPoint("TOPRIGHT",f,"TOPRIGHT",-16,-112)
    self.selection=label(selected,"",16); at(self.selection,selected,14,40); self.selection:SetPoint("TOPRIGHT",selected,"TOPRIGHT",-125,-40); self.selection:SetHeight(22); self.selection:SetWordWrap(false)
    local copyPath=button(selected,"Copy path",95,function()
        if self.target then self:report(U.joinTarget(self.target),"Stable resolver path") else self:message(self.identityReason or "No stable path for this object.") end
    end); copyPath:SetPoint("TOPRIGHT",-14,-36)
    self.identity=label(selected,"",11); at(self.identity,selected,14,70); self.identity:SetPoint("TOPRIGHT",selected,"TOPRIGHT",-14,-70); self.identity:SetHeight(32)
    self.create=button(selected,"Create customisation",175,function() self:createRule() end); at(self.create,selected,14,112); W.tone(self.create,"primary")
    self.enabled=check(selected,"Entry enabled",function(on) local r=self:rule(); if r and not FC.readOnlyData then r.enabled=on; self:changed() end end); at(self.enabled,selected,14,116)
    self.apply=button(selected,"Apply now",88,function() if self.id then FC.engine:apply(self.id); self:message("Queued enabled properties; paused entries remain paused.") end end); at(self.apply,selected,167,112)
    self.undo=button(selected,"Undo session",100,function() if self.id then local n,why=FC.engine:undo(self.id); self:renderInspector(); self:message(n.." properties restored. "..why) end end); at(self.undo,selected,265,112)
    self.remove=button(selected,"Delete",72,function() if self.id and not FC.readOnlyData then FC.db.rules[self.id]=nil; self.id=nil; self:changed(); self:message("Entry deleted. Use normal refresh or /reload to restore appearance.") end end); at(self.remove,selected,375,112); W.tone(self.remove,"danger")
    self.propertiesPanel=W.section(f,"Properties",383,282,232,548); self.propertiesPanel:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",383,70)
    local props=self.propertiesPanel
    self.propertyButtons={}
    local names={opacity="Opacity",position="Position / anchors",barTexture="Status bar texture",barColor="Status bar colour",frameLayer="Frame strata / level",drawLayer="Draw layer",font="Font"}
    for _,d in ipairs(P.order) do
        local b=button(props,d.label,204,function() self:chooseProperty(d) end); b.shortName=names[d.id] or d.label
        b:SetScript("OnEnter",function() self:tooltip(b,d.label.."\n\n"..d.help) end); b:SetScript("OnLeave",function() self:hideTooltip() end)
        self.propertyButtons[d.id]=b; b:Hide()
    end
    self.help=label(props,"",11); at(self.help,props,14,264); self.help:SetSize(204,100)
    self.periodic=check(props,"Periodic entry",function() self:entrySettings() end); at(self.periodic,props,14,390)
    self.interval=input(props,70); at(self.interval,props,14,423)
    self.enforcementSave=button(props,"Save seconds",124,function() self:entrySettings() end); at(self.enforcementSave,props,94,423)
    local entryHint=label(props,"Entry interval in seconds. Individual properties can override this strategy.",10); at(entryHint,props,14,462); entryHint:SetSize(204,56)
    self.form=W.section(f,"Property editor",631,282,533,548); self.form:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-16,70)
    local form=self.form
    self.propertyTitle=label(form,"",15); at(self.propertyTitle,form,14,40); self.propertyTitle:SetSize(490,20)
    self.override=check(form,"Enable this property override",function(on) self:saveProperty(on) end); at(self.override,form,14,70)
    self.fields={}
    for i=1,4 do
        local row={label=label(form,"",11),edit=input(form,342)}
        at(row.label,form,14,103+(i-1)*46); at(row.edit,form,14,119+(i-1)*46)
        row.choice=W.dropdown(form,342,{""},function(value) row.edit:SetText(value) end); at(row.choice,form,14,119+(i-1)*46); row.choice:Hide()
        row.media=button(form,"Browse media",145,function() self:media(row) end); at(row.media,form,368,119+(i-1)*46)
        row.label:SetSize(499,15)
        row.edit:SetScript("OnTextChanged",function(_,userInput)
            if row.choice and row.choice:IsShown() then W.setChoice(row.choice,row.edit:GetText()) end
            if userInput then self:updateMediaLabels() end
        end); self.fields[i]=row
    end
    self.mediaSummary=label(form,"",10); at(self.mediaSummary,form,14,294); self.mediaSummary:SetSize(499,18)
    self.modeButton=W.dropdown(form,220,{{1,"Inherit entry"},{2,"Normal only"},{3,"Periodic"}},function(value) self.mode=value; self:message("Commit value to save the property strategy.") end); at(self.modeButton,form,14,322)
    self.propInterval=input(form,65); at(self.propInterval,form,246,322)
    local seconds=label(form,"seconds",11); at(seconds,form,321,330)
    self.commit=button(form,"Commit value",130,function() self:saveProperty(true) end); at(self.commit,form,14,362); W.tone(self.commit,"primary")
    self.anchorDetails=button(form,"Anchor details",130,function()
        local value,why
        if self.object and FC.adapter:canRead(self.object,P.byID.position) then value,why=FC.Anchors.read(FC.adapter,self.object) end
        local text="Current readable anchors:\n"..(value and FC.Anchors.details(value) or why or "Inaccessible / unavailable")
        local entry=self:rule() and self:rule().overrides.position
        if entry then text=text.."\n\nConfigured anchors (enabled="..tostring(entry.enabled).."):\n"..FC.Anchors.details(entry.value) end
        self:report(text,"Position anchor details")
    end); at(self.anchorDetails,form,156,362)
    self.eligibilityReport=button(form,"Eligibility report",145,function()
        local d=self.property; if not d then return end; local entry=self:rule() and self:rule().overrides[d.id]
        local text="Target: "..U.joinTarget(self.target or self:rule() and self:rule().target).."\n"..d.id.." override: "..(entry and entry.enabled and "enabled" or "disabled")
        text=text.."\nLast inspector preflight:\n"..table.concat(U.geometryLines(self.geometryResult),"\n")
        if self.id then text=text.."\n\n"..FC.engine:diagnostics(self.id) end
        self:report(text,"Geometry eligibility and enforcement")
    end); at(self.eligibilityReport,form,298,362)
    self.readout=label(form,"",11); at(self.readout,form,14,404); self.readout:SetPoint("BOTTOMRIGHT",form,"BOTTOMRIGHT",-14,14)
    self.notice=label(f,"",11); self.notice:SetPoint("BOTTOMLEFT",383,32); self.notice:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-24,32); self.notice:SetHeight(32)
    self.globalStatus=label(f,"",10); self.globalStatus:SetPoint("BOTTOMLEFT",16,10); self.globalStatus:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-30,10); self.globalStatus:SetHeight(18)
    local resize=button(f,"/",22); resize:SetPoint("BOTTOMRIGHT",-3,3)
    W.hook(resize,"OnMouseDown",function() if FC.adapter:protected(f) then f:StartSizing("BOTTOMRIGHT"); f.moving=true end end)
    resize:SetScript("OnMouseUp",function() W.stop(f); self.dirty=true end)
    f:SetScript("OnSizeChanged",function()
        f:SetScale(math.min(1,(UIParent:GetWidth()-40)/f:GetWidth(),(UIParent:GetHeight()-40)/f:GetHeight())); self.dirty=true
    end)
    W.hook(f,"OnHide",function() if not self.picking and self.outline then self.outline:Hide() end; self:hideTooltip() end)
    self:buildVisualControls(); FC.discovery:refresh(); self:renderInspector(); self:renderRows()
end
function UI:toggle()
    self:build()
    if self.opened and self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self.opened=true end
end
