local addonName,FC=...
function FC.Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff54d7bcFrameCustomizer:|r "..text) end
end
FC.adapter=FC.NativeAdapter.new()
FC.discovery=FC.Discovery.new(FC.adapter)
function FC.SetPaused(paused)
    FrameCustomizerSafeMode=paused==true
    if FC.engine then FC.engine:pause(paused) end
end
local lastReport=-100
function FC.ShowReport(id)
    if GetTime()-lastReport<2 then FC.Print("Report is rate limited to once every 2 seconds."); return end
    lastReport=GetTime()
    local version,build,date,interface=GetBuildInfo()
    local report=FC.engine:diagnostics(id).."\nRuntime: "..version.." build "..build.." date "..date.." interface "..interface.."\nReference target: 1.60.1 / 70124 / 16001\n"
    report=report.."No live property values, hook arguments, gameplay information or account/character data included.\n"
    report=report.."Media detection (library metadata only):\n"..FC.adapter:mediaDiagnostics().."\n"
    report=report.."Geometry findings: required native/access checks, anchor representation, FrameCustomizer Edit Mode policy, and scoped external-layout observations. Ordinary managers are advisory; successful preflight/setters do not prove lasting appearance.\n"
    if FC.loadWarnings then for i=1,math.min(20,#FC.loadWarnings) do report=report.."Load: "..FC.loadWarnings[i].."\n" end end
    if FC.Editor.target then report=report.."Selected: "..FC.Util.joinTarget(FC.Editor.target).."\n" end
    FC.Editor:report(report)
end
-- Recovery command is registered independently of the editor and before load.
SLASH_FRAMECUSTOMIZER1="/fcu"
SLASH_FRAMECUSTOMIZER2="/framecustomizer"
SlashCmdList.FRAMECUSTOMIZER=function(text)
    local command,arg=(text or ""):match("^(%S*)%s*(.-)$")
    command=command:lower()
    if command=="pause" or command=="safe" then
        FrameCustomizerSafeMode=true
        if FC.engine then FC.SetPaused(true)
        elseif FC.Util.safe(FrameCustomizerDB) and type(FrameCustomizerDB)=="table" then FrameCustomizerDB.paused=true end
        FC.Print("Paused persistently. Existing visuals may need /reload. /fcu resume reenables saved rules."); return
    end
    if not FC.engine then FC.Print("Initialization incomplete; /fcu pause remains available. Check Lua errors."); return end
    if command=="resume" then FC.SetPaused(false); FC.Print("Enabled entries resumed.")
    elseif command=="report" then FC.ShowReport()
    elseif command=="test" then
        if arg=="stop" then FC.Playground:finish("SKIPPED remaining scenarios: cancelled by user.") else FC.Playground:startTests() end
    elseif command=="playground" then
        if arg=="hide" then if FC.Playground.dev then FC.Playground.dev.root:Hide() end
        elseif arg=="reset" then FC.Playground:reset()
        else FC.Playground:show() end
    elseif command=="pick" then FC.Editor:build(); FC.Editor.opened=true; if not InCombatLockdown() then FC.Editor:startPick() else FC.Print("Start picker outside combat.") end
    elseif command=="" then FC.Editor:toggle()
    else FC.Print("/fcu | pick | pause | resume | report | playground [reset|hide] | test [stop]") end
end
local driver=CreateFrame("Frame")
FC.adapter.owned[driver]=true
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
driver:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name==addonName and not FC.engine then
        FC.db,FC.loadWarnings,FC.readOnlyData=FC.Schema.load(FrameCustomizerDB)
        if FrameCustomizerSafeMode==true then FC.db.paused=true end
        if not FC.readOnlyData then FrameCustomizerDB=FC.db end
        FC.engine=FC.Engine.new(FC.adapter,FC.db)
        local _,build,_,interface=GetBuildInfo()
        if tostring(build)~="70124" or interface~=16001 then
            FC.SetPaused(true); FC.Print("Different client snapshot detected; rules start paused. Reference build: 70124 / interface 16001.")
        end
        if #FC.loadWarnings>0 then FC.Print(#FC.loadWarnings.." saved-data notices; /fcu report for details.") end
    elseif FC.engine then FC.engine:lifecycle() end
end)
local elapsed=0
driver:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<0.05 then return end
    elapsed=0
    if FC.engine then FC.engine:tick(); FC.Playground:tick(); FC.Editor:tick() end
end)
