local _,FC=...
local PG={}
FC.Playground=PG
local function fixtures(name)
    local root=CreateFrame("Frame",name,UIParent)
    root:SetSize(280,180); root:SetPoint("CENTER",UIParent,"CENTER",0,140)
    local bg=root:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.07,0.1,0.16,0.95)
    local art=CreateFrame("Frame",nil,root); art:SetParentKey("Art"); art:SetSize(250,140); art:SetPoint("CENTER",root,"CENTER",0,0)
    local border=art:CreateTexture(nil,"ARTWORK"); border:SetParentKey("Decoration"); border:SetTexture("Interface\\Buttons\\WHITE8X8"); border:SetSize(60,60); border:SetPoint("LEFT",art,"LEFT",8,0); border:SetVertexColor(0.15,0.65,1,1)
    local text=art:CreateFontString(nil,"OVERLAY"); text:SetParentKey("Label"); text:SetFont("Fonts\\FRIZQT__.TTF",14,""); text:SetPoint("TOP",art,"TOP",0,-10); text:SetText("FrameCustomizer playground")
    local bar=CreateFrame("StatusBar",nil,art); bar:SetParentKey("Bar"); bar:SetSize(150,20); bar:SetPoint("RIGHT",art,"RIGHT",-4,-10); bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetMinMaxValues(0,100); bar:SetValue(60); bar:SetStatusBarColor(0.3,0.8,0.5,1)
    local button=CreateFrame("Button",nil,art); button:SetParentKey("Control"); button:SetSize(140,25); button:SetPoint("BOTTOM",art,"BOTTOM",0,8)
    local title=button:CreateFontString(nil,"OVERLAY"); title:SetFont("Fonts\\FRIZQT__.TTF",12,""); title:SetPoint("CENTER"); title:SetText("Click: bar + 10")
    button:SetScript("OnClick",function() bar:SetValue((bar:GetValue()+10)%101) end)
    local sibling=art:CreateTexture(nil,"ARTWORK"); sibling:SetParentKey("SiblingAnchor")
    sibling:SetTexture("Interface\\Buttons\\WHITE8X8"); sibling:SetSize(18,18); sibling:SetPoint("TOPLEFT",border,"TOPRIGHT",8,0); sibling:SetVertexColor(1,0.6,0.2,1)
    local stretch=art:CreateTexture(nil,"ARTWORK"); stretch:SetParentKey("TwoAnchors")
    stretch:SetTexture("Interface\\Buttons\\WHITE8X8"); stretch:SetVertexColor(0.8,0.3,0.9,1)
    stretch:SetPoint("TOPLEFT",art,"BOTTOMLEFT",12,-6); stretch:SetPoint("BOTTOMRIGHT",art,"BOTTOMRIGHT",-12,-14)
    return {root=root,art=art,texture=border,text=text,bar=bar,sibling=sibling,stretch=stretch}
end
function PG:show()
    if InCombatLockdown() then FC.Print("Open playground outside combat."); return end
    if not self.dev then self.dev=fixtures("FrameCustomizerPlayground"); FC.adapter.fixtures[self.dev.root]=true end
    self.dev.root:Show(); FC.Editor:build(); FC.Editor.frame:Show(); FC.Editor.opened=true
    FC.Editor.saved=false; FC.Editor.search:SetText("")
    FC.discovery:reveal(self.dev.root); FC.Editor:select(self.dev.root)
    local node=FC.discovery.map[self.dev.root]; if node and not node.expanded then FC.discovery:expand(node) end
    FC.Print("Expand Art: Decoration = texture/blank, Label = fonts, Bar = fill media, SiblingAnchor / TwoAnchors = preserved position. Browse media shows library detection. /fcu playground reset resets cosmetics.")
end
function PG:reset()
    local f=self.dev; if not f then return end
    f.texture:SetAlpha(1); f.texture:SetTexture("Interface\\Buttons\\WHITE8X8"); f.texture:SetVertexColor(0.15,0.65,1,1)
    f.text:SetFont("Fonts\\FRIZQT__.TTF",14,""); f.text:SetTextColor(1,1,1,1); f.bar:SetStatusBarColor(0.3,0.8,0.5,1)
    f.bar:GetStatusBarTexture():SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
end
local function rule(target,property,value)
    return {target=target,enabled=true,periodic=false,interval=0.25,overrides={[property]={enabled=true,value=value}}}
end
function PG:finish(note)
    local run=self.run; if not run then return end
    run.engine:pause(true); run.engine.db.rules={}; run.engine:sync(); run.f.root:Hide()
    run.f.root.Late=nil; run.f.root.Alias=nil
    run.report[#run.report+1]="Engine totals: writes="..run.engine.stats.writes.." checks="..run.engine.stats.checks.." errors="..run.engine.stats.errors.." installed hooks="..run.engine.stats.hooks
    self.lastReport=table.concat(run.report,"\n").."\n"..(note or "Finished; fixture enforcement stopped and fixtures hidden.")
    self.run=nil
    FC.Editor:report(self.lastReport,"FrameCustomizer native fixture test report")
    FC.Print("Native fixture test finished. Copy the report; these results do not certify protected Blizzard widgets.")
end
function PG:startTests()
    if InCombatLockdown() then FC.Print("SKIPPED: /fcu test requires out-of-combat context."); return end
    if self.run then FC.Print("A fixture test is already running. /fcu test stop cancels it."); return end
    if not self.testFixtures then
        self.testFixtures=fixtures("FrameCustomizerTestFixtures"); FC.adapter.owned[self.testFixtures.root]=true
        self.testAdapter=FC.NativeAdapter.new(); self.testAdapter.fixtures[self.testFixtures.root]=true
        -- Cache before installing hooks to exercise missed-notification recovery.
        self.savedAlpha=self.testFixtures.texture.SetAlpha
    end
    local f=self.testFixtures; f.root:Show(); f.root.Late=nil; f.root.Alias=nil
    f.sibling:SetPoint("TOPLEFT",f.texture,"TOPRIGHT",8,0)
    f.stretch:SetPoint("TOPLEFT",f.art,"BOTTOMLEFT",12,-6); f.stretch:SetPoint("BOTTOMRIGHT",f.art,"BOTTOMRIGHT",-12,-14)
    f.texture:SetAlpha(1); f.texture:SetTexture("Interface\\Buttons\\WHITE8X8"); f.text:SetAlpha(1); f.text:SetFont("Fonts\\FRIZQT__.TTF",14,""); f.bar:SetStatusBarColor(0.3,0.8,0.5,1); f.bar:SetValue(60)
    f.bar:GetStatusBarTexture():SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local a=self.testAdapter; local target=FC.Resolver.describe(a,f.texture)
    if not target then FC.Editor:report("SKIPPED: native access/identity APIs unavailable. No fixture tests executed."); f.root:Hide(); return end
    local db={version=1,paused=false,nextID=4,rules={
        r1=rule(target,"opacity",{alpha=0.25}),
        r2=rule(FC.Resolver.describe(a,f.text),"font",{face="Fonts\\FRIZQT__.TTF",size=19,flags="OUTLINE"}),
        r3=rule(FC.Resolver.describe(a,f.bar),"barColor",{r=0.8,g=0.2,b=0.4,a=1})}}
    -- Reuse the engine's hook registry across runs: native posthooks cannot be
    -- removed. Replacing an engine here would accumulate hooks each run.
    local e=self.testEngine
    if e then e.db=db; e:sync() else e=FC.Engine.new(a,db); self.testEngine=e end
    local function alpha(o,value) local ok,n=a:read(o,"GetAlpha"); return ok and math.abs(n-value)<0.001 end
    local steps={}
    local function step(name,delay,act,check) steps[#steps+1]={name=name,delay=delay,act=act,check=check} end
    step("Initial selected opacity, font and bar colour; bar value untouched",0.3,nil,function()
        local ok,_,size=a:read(f.text,"GetFont"); local good,r=a:read(f.bar,"GetStatusBarColor")
        return alpha(f.texture,0.25) and ok and size==19 and good and math.abs(r-0.8)<0.001 and f.bar:GetValue()==60
    end)
    step("Direct setter posthook correction",0.35,function() f.texture:SetAlpha(0.9) end,function()
        if e.stats.hooks==0 then return nil,"posthooks unavailable; verification remains active" end
        return alpha(f.texture,0.25)
    end)
    step("Deferred setter correction",0.35,function() f.texture:SetAlpha(0.8) end,function() return alpha(f.texture,0.25) end)
    step("Saved method reference / bounded verification recovery",2.5,function() self.savedAlpha(f.texture,0.7) end,function() return alpha(f.texture,0.25) end)
    step("Periodic constant reapplication",0.6,function() db.rules.r1.periodic=true; e:sync(); self.savedAlpha(f.texture,0.6) end,function() return alpha(f.texture,0.25) end)
    step("Repeated external updates (settled after updates stop)",1.5,function() self.run.repeatUntil=GetTime()+0.8 end,function() return alpha(f.texture,0.25) end)
    step("Show/hide transition retains native scripts",0.5,function() f.root:Hide(); f.texture:SetAlpha(0.9); f.root:Show() end,function() return alpha(f.texture,0.25) end)
    step("Alternate setter route (vertex alpha)",2.5,function() db.rules.r1.periodic=false; e:sync(); f.texture:SetVertexColor(1,1,1,0.8) end,function() return alpha(f.texture,0.25) end)
    local lateTarget={root="FrameCustomizerTestFixtures",keys={"Late"},types={"Frame","Texture"}}
    step("Missing target stays unresolved",0.3,function() db.rules.r4=rule(lateTarget,"opacity",{alpha=0.4}); e:sync() end,function() return e.states.r4.jobs.opacity.status=="unresolved" end)
    local function lateRegion(index)
        local key="late"..index
        if not f[key] then
            local t=f.root:CreateTexture(nil,"ARTWORK"); t:SetSize(15,15); t:SetPoint("CENTER",f.root,"CENTER",index*20,50); t:SetTexture("Interface\\Buttons\\WHITE8X8")
            f[key]=t
        end
        return f[key]
    end
    step("Late-created / reactivated target resolves",3.5,function() lateRegion(1):SetParentKey("Late",true); e:lifecycle() end,function() return alpha(f.late1,0.4) end)
    step("Rebound parent key revalidates; old object no longer enforced",3.5,function()
        lateRegion(2):SetParentKey("Late",true); f.root.Late=f.late2; e:lifecycle(); f.late1:SetAlpha(0.9)
    end,function() return alpha(f.late2,0.4) and alpha(f.late1,0.9) end)
    step("Unverified / ambiguous alias is not guessed",0.3,function()
        f.root.Alias=f.late1
        db.rules.r5=rule({root="FrameCustomizerTestFixtures",keys={"Alias"},types={"Frame","Texture"}},"opacity",{alpha=0.1}); e:sync()
    end,function() return e.states.r5.jobs.opacity.status=="ambiguous" and alpha(f.late1,0.9) end)
    local function applied(id,property)
        local job=e.states[id] and e.states[id].jobs[property]
        if not job then return nil,"fixture representation unavailable" end
        if job.status=="blocked" then return nil,job.reason end
        return job.writes>0 and job.errors==0
    end
    step("Addon-owned transparent texture replacement (rendering needs visual inspection)",0.4,function()
        db.rules.r1.overrides.texture={enabled=true,value={kind="file",asset=FC.BLANK_TEXTURE}}; e:sync()
    end,function() return applied("r1","texture") end)
    step("Status-bar media replacement preserves value and native fill",0.4,function()
        local assets=a:media("statusbar",true)
        db.rules.r3.overrides.barTexture={enabled=true,value={asset=assets[2][2]}}; e:sync()
    end,function() local ok,why=applied("r3","barTexture"); if not ok then return ok,why end; return f.bar:GetValue()==60 end)
    local sharedFont,mediaInfo
    step("SharedMedia font selection / resolved file application",0.4,function()
        local assets; assets,mediaInfo=a:media("font")
        for _,item in ipairs(assets) do if item.source=="SharedMedia" then sharedFont=item; break end end
        if sharedFont then db.rules.r2.overrides.font.value={face=sharedFont[2],size=18,flags=""}; e:sync() end
    end,function()
        if not sharedFont then return nil,mediaInfo.summary end
        local ok,face,size=a:read(f.text,"GetFont")
        if not ok then return nil,"font read inaccessible; inspect visually" end
        return size==18 and type(face)=="string" and face:lower():gsub("/","\\")==sharedFont[2]:lower():gsub("/","\\")
    end)
    step("Unavailable-library fallback (explicit built-ins-only adapter test)",0.4,function()
        local assets=a:media("font",true)
        db.rules.r2.overrides.font.value={face=assets[1][2],size=17,flags=""}; e:sync()
    end,function()
        local assets,info=a:media("font",true)
        if info.available or #assets<2 then return false end
        local ok,_,size=a:read(f.text,"GetFont"); return ok and size==17
    end)
    step("Sibling and multiple anchor translation preserves relationships",0.5,function()
        for i,object in ipairs({f.sibling,f.stretch}) do
            local value=FC.Anchors.read(a,object)
                if value then value.x=value.x+4; db.rules["r"..(i+5)]=rule(FC.Resolver.describe(a,object),"position",value) end
        end
        e:sync()
    end,function()
        for i,object in ipairs({f.sibling,f.stretch}) do
            local id="r"..(i+5); local ok,why=applied(id,"position"); if not ok then return ok,why end
            local current=FC.Anchors.read(a,object)
            if not current then return nil,"anchor read unavailable" end
            if not FC.Util.equal(current,db.rules[id].overrides.position.value) then return false end
        end
        return true
    end)
    step("Pause All stops queued and periodic writes",0.6,function() db.rules.r1.periodic=true; e:sync(); f.texture:SetAlpha(0.9); e:pause(true) end,function() return alpha(f.texture,0.9) end)
    local version,build,date,interface=GetBuildInfo()
    self.run={f=f,engine=e,steps=steps,index=0,report={"FrameCustomizer "..FC.VERSION.." / "..FC.REVISION,
        "Client "..version.." build "..build.." ("..date..") interface "..interface,
        "Native addon-owned fixtures ONLY; no protected Blizzard compatibility claim.",
        a:mediaDiagnostics(),
        "Secret values, protected operations, combat and rendering: SKIPPED (manual acceptance required)."}}
    FC.Print("Running native fixture scenarios (~24 seconds). /fcu test stop cancels. Entering combat cancels.")
end
function PG:tick()
    local run=self.run; if not run then return end
    if InCombatLockdown() then self:finish("SKIPPED remaining scenarios: entered combat."); return end
    local now=GetTime()
    local ok,err=pcall(function()
        if run.repeatUntil and now<run.repeatUntil and (not run.lastReset or now-run.lastReset>0.15) then run.f.texture:SetAlpha(0.8); run.lastReset=now end
        run.engine:tick()
        if not run.deadline or now>=run.deadline then
            if run.index>0 then
                local previous=run.steps[run.index]; local passed,reason=previous.check()
                run.report[#run.report+1]=(passed==nil and "SKIPPED " or passed and "PASS " or "FAIL ")..previous.name..(reason and ": "..reason or "")
            end
            run.index=run.index+1; local current=run.steps[run.index]
            if not current then self:finish(); return end
            if current.act then current.act() end
            run.deadline=now+current.delay
        end
    end)
    if not ok then FC.adapter:onError(err); self:finish("FAIL: unexpected native test error; see Lua error display.") end
end
