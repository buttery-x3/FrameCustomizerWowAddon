local _, FC = ...
local U,P,R=FC.Util,FC.Properties,FC.Resolver
local E={}; E.__index=E
FC.Engine=E
function E.new(adapter,db)
    local e=setmetatable({a=adapter,db=db,states={},jobs={},cursor=0,hooks=setmetatable({},{__mode="k"}),
        writing=setmetatable({},{__mode="k"}),stats={writes=0,checks=0,errors=0,hooks=0,steps=0},hookLimit=1024},E)
    e:sync(); return e
end
function E:active(j)
    return not self.db.paused and self.states[j.id]==j.state and not j.state.conflict and j.state.rule.enabled and j.entry.enabled
end
function E:unwatch(j)
    if j.slots then for _,slot in ipairs(j.slots) do slot.listeners[j]=nil end end
    j.slots={}
end
function E:watch(j,o)
    self:unwatch(j)
    local byMethod=self.hooks[o]
    if not byMethod then byMethod={}; self.hooks[o]=byMethod end
    for _,method in ipairs(j.def.signals) do
        local slot=byMethod[method]
        if not slot and self.stats.hooks<self.hookLimit then
            slot={listeners={}}
            local function changed()
                -- Intentionally ignore all incoming hook arguments.
                for job in pairs(slot.listeners) do
                    if self:active(job) and not self.writing[job.object] and not job.suspended then
                        job.dirty=true
                        job.due=math.min(job.due or math.huge,self.a:now()+0.05)
                    end
                end
            end
            local ok=self.a:hook(o,method,changed)
            if ok then byMethod[method]=slot; self.stats.hooks=self.stats.hooks+1 else slot=nil end
        end
        if slot then slot.listeners[j]=true; j.slots[#j.slots+1]=slot end
    end
end
function E:sync()
    -- Rebuild bounded job records; installed posthooks survive but subscriptions
    -- never retain obsolete rules. Baselines are session-only and property-only.
    local old=self.states
    for _,j in ipairs(self.jobs) do self:unwatch(j) end
    self.states={}; self.jobs={}; self.cursor=0
    local ids={}; for id in pairs(self.db.rules) do ids[#ids+1]=id end; table.sort(ids)
    local targetCounts={}
    for _,id in ipairs(ids) do
        local rule=self.db.rules[id]
        if rule.enabled then local key=U.joinTarget(rule.target); targetCounts[key]=(targetCounts[key] or 0)+1 end
    end
    for _,id in ipairs(ids) do
        local rule=self.db.rules[id]
        local state={rule=rule,jobs={},status=rule.enabled and "pending" or "disabled",conflict=(targetCounts[U.joinTarget(rule.target)] or 0)>1}
        self.states[id]=state
        for _,d in ipairs(P.order) do
            local entry=rule.overrides[d.id]
            if entry and entry.enabled then
                local previous=old[id] and old[id].jobs[d.id]
                local same=previous and U.equal(old[id].rule.target,rule.target)
                local j={id=id,state=state,entry=entry,def=d,due=self.a:now(),dirty=true,errors=0,status="pending",
                    baseline=same and previous.baseline or nil,baselineObject=same and previous.baselineObject or nil,
                    writes=same and previous.writes or 0,checks=same and previous.checks or 0}
                state.jobs[d.id]=j; self.jobs[#self.jobs+1]=j
                if not self:active(j) then j.status="disabled" end
                if state.conflict then j.status="blocked"; j.reason="Multiple enabled entries share this target; disable the duplicate entries." end
            end
        end
    end
end
function E:pause(paused)
    self.db.paused=paused==true
    for _,j in ipairs(self.jobs) do
        if paused then self:unwatch(j); j.object=nil; j.status="disabled"
        elseif j.state.rule.enabled then j.due=self.a:now(); j.dirty=true; j.status="pending" end
    end
end
function E:apply(id)
    local state=self.states[id]; if not state then return end
    for _,j in pairs(state.jobs) do
        if self:active(j) then j.suspended=nil; j.errors=0; j.due=self.a:now(); j.dirty=true; j.status="pending" end
    end
end
function E:lifecycle()
    -- Called after load/show/combat lifecycle notifications, never during an
    -- event's transient permission window. Tick still guards each operation.
    for _,j in ipairs(self.jobs) do
        if self:active(j) and not j.suspended then j.due=math.min(j.due,self.a:now()+0.1); j.dirty=true end
    end
end
function E:failure(j)
    j.errors=j.errors+1; self.stats.errors=self.stats.errors+1
    j.status="failed"; j.reason="Operation error (see Lua error display); retry backoff"
    if j.errors>=3 then j.suspended=true; j.reason="Suspended after 3 operation errors. Fix the cause, then Apply Now." end
    j.due=self.a:now()+math.min(30,2^(j.errors-1))
end
function E:process(j,now)
    local o,why=R.resolve(self.a,j.state.rule.target)
    if not o then
        self:unwatch(j); j.object=nil; j.status=why and why:find("ambiguous",1,true) and "ambiguous" or (why and why:find("blocked",1,true) and "blocked" or "unresolved")
        j.reason=why; j.due=now+FC.LIMITS.resolve; return
    end
    if o~=j.object then
        j.object=o; j.dirty=true
        if j.baselineObject~=o then j.baseline=nil; j.baselineObject=nil end
        self:watch(j,o)
    end
    if not P.applicable(j.def,self.a:kind(o)) then j.status="blocked"; j.reason="Object type no longer supports property"; j.due=now+FC.LIMITS.resolve; return end
    local permitted,reason,retry=self.a:canWrite(o,j.def,j.entry.value)
    if not permitted then
        j.status="blocked"; j.reason=reason; j.due=retry and now+FC.LIMITS.resolve or math.huge
        return
    end
    local readable=self.a:canRead(o,j.def)
    local current
    if readable then
        current=j.def.read(self.a,o)
        if current then current=j.def.validate(current) end
        j.checks=j.checks+1; self.stats.checks=self.stats.checks+1
    end
    if current and not j.baseline then j.baseline=U.copy(current); j.baselineObject=o end
    local periodic=j.entry.periodic
    if periodic==nil then periodic=j.state.rule.periodic end
    local interval=j.entry.interval or j.state.rule.interval
    local periodDue=periodic and (not j.lastPeriodic or now-j.lastPeriodic>=interval)
    local matches=current and U.equal(current,j.entry.value)
    local write=(j.dirty and not matches) or (current and not matches) or periodDue
    if write then
        if not j.def.repeatable and j.writes>0 then j.status="blocked"; j.reason="Property does not support repeat application"; j.due=math.huge; return end
        self.writing[o]=true
        local ok,err=pcall(j.def.write,self.a,o,j.entry.value)
        self.writing[o]=nil
        if not ok then self.a:onError(err); self:failure(j); return end
        j.writes=j.writes+1; self.stats.writes=self.stats.writes+1
        -- A successful write does not establish a matched or rendered value.
        j.status=current and "pending" or "constant applied but current value inaccessible"
        j.reason=current and "Write sent; waiting for readable verification" or "No readable comparison; hooks/optional periodic writes only"
        if periodic then j.lastPeriodic=now end
    else
        j.status=matches and "readable value matched at last check" or "constant applied but current value inaccessible"
        j.reason=matches and "Rendering / future changes are not guaranteed" or "No readable comparison; hooks/optional periodic writes only"
    end
    j.errors=0; j.dirty=false
    j.due=now+FC.LIMITS.verify
    if periodic then j.due=math.min(j.due,(j.lastPeriodic or now)+interval) end
end
function E:tick()
    if self.db.paused then return 0 end
    local n=#self.jobs; if n==0 then return 0 end
    local now=self.a:now(); local work=0
    for _=1,math.min(n,FC.LIMITS.scan) do
        self.cursor=self.cursor%n+1
        local j=self.jobs[self.cursor]
        self.stats.steps=self.stats.steps+1
        if self:active(j) and not j.suspended and now>=j.due then
            local ok,err=pcall(self.process,self,j,now)
            -- An unexpected read/adapter error must not leave a guard set.
            if j.object then self.writing[j.object]=nil end
            if not ok then self.a:onError(err); self:failure(j) end
            work=work+1
            if work>=FC.LIMITS.jobs then break end
        end
    end
    return work
end
function E:undo(id)
    local state=self.states[id]; if not state then return 0,"No rule" end
    -- Stop enforcement first, even if restoration is blocked or errors.
    state.rule.enabled=false
    local count=0
    for _,j in pairs(state.jobs) do
        self:unwatch(j)
        local o=R.resolve(self.a,state.rule.target)
        if j.baseline and o==j.baselineObject and self.a:canWrite(o,j.def,j.baseline) then
            self.writing[o]=true
            local ok,err=pcall(j.def.write,self.a,o,j.baseline)
            self.writing[o]=nil
            if ok then count=count+1 else self.a:onError(err) end
        end
    end
    self:sync()
    return count,"Best-effort session baseline only; use normal UI refresh or /reload for Blizzard's current intended state."
end
function E:diagnostics(id)
    local out={"FrameCustomizer "..FC.VERSION.." / "..FC.REVISION,
        "Pause All="..tostring(self.db.paused).."; jobs="..#self.jobs.."; budget="..FC.LIMITS.jobs.." per 0.05s tick",
        "writes="..self.stats.writes.." checks="..self.stats.checks.." errors="..self.stats.errors.." hooks="..self.stats.hooks}
    local ids={}; for key in pairs(self.states) do if not id or key==id then ids[#ids+1]=key end end; table.sort(ids)
    for index=1,math.min(#ids,24) do
        local key=ids[index]; local s=self.states[key]
        out[#out+1]=key.." "..U.joinTarget(s.rule.target).." enabled="..tostring(s.rule.enabled).." periodic="..tostring(s.rule.periodic).." interval="..s.rule.interval
        for _,d in ipairs(P.order) do
            local j=s.jobs[d.id]
            if j then
                local mode=j.entry.periodic
                if mode==nil then mode=s.rule.periodic end
                out[#out+1]="  "..d.id..": "..j.status.."; periodic="..tostring(mode).." interval="..(j.entry.interval or s.rule.interval).." writes="..j.writes.." checks="..j.checks..(j.reason and ("; "..j.reason) or "")
                local values={}
                for _,field in ipairs(d.inputs) do
                    local value=j.entry.value[field[1]]
                    -- Only already validated user constants, never live reads.
                    values[#values+1]=field[1].."="..tostring(value):gsub("|","||"):sub(1,160)
                end
                out[#out+1]="    configured "..table.concat(values," ")
                if j.entry.value.anchors then
                    for _,anchor in ipairs(j.entry.value.anchors) do
                        local relative=type(anchor.relative)=="table" and U.joinTarget(anchor.relative) or anchor.relative
                        out[#out+1]="    preserved "..anchor.point.." -> "..relative.."."..anchor.relativePoint.." delta="..anchor.dx..","..anchor.dy
                    end
                end
            end
        end
    end
    if #ids>24 then out[#out+1]="Additional rules omitted; select a rule for a focused report." end
    return table.concat(out,"\n"):sub(1,24000)
end
