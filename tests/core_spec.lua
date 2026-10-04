local _,FC=...
local F,U,S,P,R,E=FC.FakeAdapter,FC.Util,FC.Schema,FC.Properties,FC.Resolver,FC.Engine
local tests,passed=0,0
local function test(name,fn)
    tests=tests+1; local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err),0) end
    passed=passed+1; print("PASS "..name)
end
local function eq(a,b) assert(U.equal(a,b),"values differ: "..tostring(a).." / "..tostring(b)) end
local function target(root,kind) return {root=root,keys={},types={kind or "Texture"}} end
local function rule(t,props) return {target=t,enabled=true,periodic=false,interval=1,overrides=props or {opacity={enabled=true,value={alpha=0.3}}}} end
local function setup(name)
    local a=F.new(); local o=a:object(name or "Example"); local db={version=1,paused=false,nextID=2,rules={r1=rule(target(o.name))}}
    return a,o,db,E.new(a,db)
end
test("schema round-trip keeps only declarative known fields",function()
    local _,_,db=setup(); db.rules.r1.snapshot={bogus=true}; db.rules.r1.fn=function() end
    local clean,w=S.load(db); eq(#w,0); eq(S.export(clean),clean); assert(not clean.rules.r1.fn and not clean.rules.r1.snapshot)
end)
test("malformed entries and properties are independently rejected",function()
    local _,_,db=setup(); db.rules.r2={target={}}; db.rules.r1.overrides.texture={enabled=true,value={kind="magic",asset="x"}}
    local clean,w=S.load(db); assert(clean.rules.r1 and not clean.rules.r2); assert(not clean.rules.r1.overrides.texture); assert(#w==2)
end)
test("unknown schema preserves source and starts read-only paused",function()
    local raw={version=99,keep="unchanged"}; local clean,_,readonly=S.load(raw); assert(readonly and clean.paused); eq(raw.keep,"unchanged")
end)
test("validation rejects nonfinite, out-of-range and executable data",function()
    for _,v in ipairs({-1,1.1,math.huge}) do assert(not P.byID.opacity.validate({alpha=v})) end
    assert(not P.byID.opacity.validate({alpha=0/0})); assert(not S.target({root="a[1]",keys={},types={"Texture"}}))
    for _,v in ipairs({0,0.1,61,math.huge}) do assert(not S.interval(v)) end
    assert(S.interval(0.25) and S.interval(60)); assert(not P.byID.font.validate({face="x",size=12,flags="RUN_CODE"}))
end)
test("inaccessible saved values never serialize",function()
    local secret={marker=true}; U.access=function(v) return v~=secret end
    local _,_,db=setup(); db.rules.r1.overrides.opacity.value.alpha=secret
    local clean=S.load(db); assert(not clean.rules.r1.overrides.opacity); assert(U.copy(secret)==nil)
    U.access=function() return true end
end)
test("late global unresolved then resolves without a UI scan",function()
    local a,o,_,e=setup(); a.globals.Example=nil; e:tick(); eq(e.states.r1.jobs.opacity.status,"unresolved"); eq(o.writeCount,0)
    a.globals.Example=o; a:advance(e,3.2); eq(o.values.alpha,0.3)
end)
test("generic different names and parent-key structures",function()
    local a=F.new(); local root=a:object("UnrelatedWindow","Frame"); local inner=a:object(nil,"Frame",root,"Art"); local region=a:object(nil,"Texture",inner,"Border")
    local t=assert(R.describe(a,region)); eq(t.keys,{"Art","Border"}); eq(R.resolve(a,t),region)
    local db={rules={r1=rule(t)},paused=false}; local e=E.new(a,db); e:tick(); eq(region.values.alpha,0.3); eq(root.writeCount,0); eq(inner.writeCount,0)
end)
test("ambiguous alias and type change fail closed",function()
    local a,o,_,e=setup(); o.ambiguous=true; e:tick(); eq(o.writeCount,0); eq(e.states.r1.jobs.opacity.status,"ambiguous")
    o.ambiguous=nil; o.kind="FontString"; e:lifecycle(); a:advance(e,0.2); eq(o.writeCount,0); eq(e.states.r1.jobs.opacity.status,"ambiguous")
end)
test("anonymous appearances are never stable identities",function()
    local a=F.new(); local root=a:object("Root","Frame"); local t=a:object(nil,"Texture",root); local other=a:object(nil,"Texture",root)
    assert(not R.describe(a,t)); assert(not R.describe(a,other)); root.children.Alias=t
    local o,why=R.resolve(a,{root="Root",keys={"Alias"},types={"Frame","Texture"}}); assert(not o and why:find("ambiguous"))
end)
test("only selected properties are written",function()
    local a,o,db,e=setup(); db.rules.r1.overrides.texture={enabled=false,value={kind="file",asset="other"}}; e:sync(); e:tick()
    eq(a.writeLog,{"SetAlpha"}); eq(o.values.texture,"Interface\\Buttons\\WHITE8X8"); eq(o.values.color,{1,1,1,1})
end)
test("normal hook invalidation is deduplicated and self-writes do not recurse",function()
    local a,o,_,e=setup(); e:tick(); local writes=o.writeCount
    for _=1,40 do o.values.alpha=0.9; a:fire(o,"SetAlpha") end
    a:advance(e,0.2); eq(o.values.alpha,0.3); eq(o.writeCount,writes+1); eq(e.writing[o],nil)
    a:advance(e,0.5); eq(o.writeCount,writes+1)
end)
test("missed hook / saved method reference recovered by verification",function()
    local a,o,_,e=setup(); e:tick(); o.values.alpha=0.8; a:advance(e,2.2); eq(o.values.alpha,0.3)
end)
test("inaccessible read is never consumed; allowed constant write works",function()
    local a,o,db,e=setup(); o.unreadable=true; e:tick(); eq(o.values.alpha,0.3); eq(a.readCount,0)
    eq(e.states.r1.jobs.opacity.status,"constant applied but current value inaccessible"); assert(not e.states.r1.jobs.opacity.baseline)
    db.rules.r1.periodic=true; e:sync(); a:advance(e,2.2); assert(o.writeCount>=3); eq(a.readCount,0); eq(e.stats.errors,0)
end)
test("per-property periodic override can enable or disable entry default",function()
    local a,o,db,e=setup(); db.rules.r1.periodic=true; db.rules.r1.overrides.opacity.periodic=false; e:sync(); e:tick(); a:advance(e,2.2); eq(o.writeCount,1)
    db.rules.r1.periodic=false; db.rules.r1.overrides.opacity.periodic=true; db.rules.r1.overrides.opacity.interval=0.25; e:sync(); a:advance(e,1); assert(o.writeCount>=4)
end)
test("bounded scheduler work and fair progress under load",function()
    local a=F.new(); local db={paused=false,rules={}}
    for i=1,100 do a:object("Object"..i); db.rules["r"..i]=rule(target("Object"..i)) end
    local e=E.new(a,db); assert(e:tick()<=FC.LIMITS.jobs); assert(#a.writeLog<=FC.LIMITS.jobs)
    a:advance(e,1); eq(#a.writeLog,100); assert(e.stats.steps<=24*21)
end)
test("denied writes skipped while ordinary permitted writes apply",function()
    local a,o,db,e=setup(); o.denied=true; o.transient=true; local allowed=a:object("Allowed"); db.rules.r2=rule(target("Allowed")); e:sync(); e:tick()
    eq(o.writeCount,0); eq(allowed.values.alpha,0.3); eq(e.states.r1.jobs.opacity.status,"blocked")
    o.denied=false; a:advance(e,3.1); eq(o.values.alpha,0.3)
end)
test("permanent denial does not retry absent lifecycle or explicit apply",function()
    local a,o,_,e=setup(); o.denied=true; e:tick(); local j=e.states.r1.jobs.opacity; eq(j.due,math.huge)
    o.denied=false; a:advance(e,10); eq(o.writeCount,0); e:apply("r1"); e:tick(); eq(o.writeCount,1)
end)
test("missing setter and missing getter have separate eligibility",function()
    local a,o,_,e=setup(); o.missing.SetAlpha=true; e:tick(); eq(o.writeCount,0)
    o.missing.SetAlpha=nil; o.missing.GetAlpha=true; e:apply("r1"); e:tick(); eq(o.writeCount,1); eq(a.readCount,0)
end)
test("real errors back off and suspend, periodic writes do not count as errors",function()
    local a,o,db,e=setup(); o.failures=10; db.rules.r1.periodic=true; e:sync(); e:tick(); local j=e.states.r1.jobs.opacity
    eq(j.errors,1); eq(e.writing[o],nil); a:advance(e,0.5); eq(j.errors,1); a:advance(e,6); assert(j.suspended); eq(a.errorCount,3)
    local count=a.errorCount; a:advance(e,20); eq(a.errorCount,count)
    o.failures=0; e:apply("r1"); e:tick(); eq(o.values.alpha,0.3); eq(e.writing[o],nil)
end)
test("unexpected read error clears guards and can recover",function()
    local a,o,_,e=setup(); o.readError=true; e:tick(); assert(not e.writing[o]); o.readError=nil; a:advance(e,1.2); eq(o.values.alpha,0.3)
end)
test("repeated enable/disable cycles install one hook per method",function()
    local a,o,db,e=setup(); e:tick(); local n=a.hookCount
    for _=1,20 do db.rules.r1.enabled=false; e:sync(); a:fire(o,"SetAlpha"); db.rules.r1.enabled=true; e:sync(); e:tick() end
    eq(a.hookCount,n); db.rules.r1.enabled=false; e:sync(); o.values.alpha=0.9; a:fire(o,"SetAlpha"); a:advance(e,5); eq(o.values.alpha,0.9)
end)
test("rebinding removes old subscriptions and captures a fresh baseline",function()
    local a,old,_,e=setup(); e:tick(); local replacement=a:object("Example"); replacement.values.alpha=0.8; a:advance(e,2.2); eq(replacement.values.alpha,0.3)
    old.values.alpha=0.9; a:fire(old,"SetAlpha"); a:advance(e,0.3); eq(old.values.alpha,0.9)
    local j=e.states.r1.jobs.opacity; eq(j.baseline.alpha,0.8); eq(j.baselineObject,replacement)
end)
test("pause/delete/property toggle cancel all pending writes",function()
    for _,mode in ipairs({"all","entry","delete","property"}) do
        local a,o,db,e=setup(); db.rules.r1.periodic=true; e:sync(); e:tick(); o.values.alpha=0.9; a:fire(o,"SetAlpha")
        if mode=="all" then e:pause(true) elseif mode=="entry" then db.rules.r1.enabled=false; e:sync()
        elseif mode=="delete" then db.rules.r1=nil; e:sync() else db.rules.r1.overrides.opacity.enabled=false; e:sync() end
        a:advance(e,10); eq(o.values.alpha,0.9)
    end
end)
test("identity does not depend on changed appearance",function()
    local a,o,db,e=setup(); local before=R.describe(a,o); e:tick(); eq(R.describe(a,o),before); eq(R.resolve(a,db.rules.r1.target),o)
end)
test("diagnostics read no target values and never change decisions",function()
    local a,o,_,e=setup(); o.unreadable=true; e:tick(); local reads,writes=a.readCount,o.writeCount
    local report=e:diagnostics(); assert(report:find("inaccessible",1,true)); eq(a.readCount,reads); eq(o.writeCount,writes); eq(e.stats.errors,0)
end)
test("all implemented property families execute production definitions",function()
    for _,d in ipairs(P.order) do
        local a=F.new(); local kind
        if d.id=="frameLayer" then kind="Frame" elseif d.id=="font" or d.id=="textColor" then kind="FontString" elseif d.id=="barTexture" or d.id=="barColor" then kind="StatusBar" else kind="Texture" end
        local parent=a:object("Parent","Frame"); local o=a:object("Child",kind,parent); o.fill=a:object(nil,"Texture",o)
        local value=U.copy(d.default)
        if d.id=="opacity" then value.alpha=0.4 elseif d.id=="font" then value.size=22 elseif d.id=="texture" then value.asset="different"
        elseif d.id=="barTexture" then value.asset="different" elseif value.r then value.r=0.1 elseif d.id=="position" then value.x=22 elseif d.id=="frameLayer" then value.level=3 end
        local db={paused=false,rules={r1=rule(target("Child",kind),{[d.id]={enabled=true,value=value}})}}
        local e=E.new(a,db); e:tick(); assert(#a.writeLog>0,d.id.." never applied"); assert(not e.states.r1.jobs[d.id].suspended)
        if d.id=="barTexture" then eq(o.writeCount,0); eq(o.fill.values.texture,"different") end
    end
end)
test("undo disables enforcement before best-effort property restoration",function()
    local a,o,_,e=setup(); e:tick(); local n=e:undo("r1"); eq(n,1); eq(o.values.alpha,1); a:advance(e,5); eq(o.values.alpha,1)
end)
test("unknown fake operations fail explicitly",function()
    local a,o=setup(); assert(not pcall(a.read,a,o,"InventedGetter")); assert(not pcall(a.write,a,o,"InventedSetter",1))
end)
test("conflicting alpha owners rejected and duplicate target entries paused",function()
    local _,_,db=setup(); db.rules.r1.overrides.tint={enabled=true,value={r=1,g=1,b=1,a=1}}; assert(not S.rule(db.rules.r1))
    db.rules.r1.overrides.tint=nil; db.rules.r2=U.copy(db.rules.r1); local clean,w=S.load(db)
    assert(#w>0); assert(not clean.rules.r1.enabled and not clean.rules.r2.enabled)
end)
test("manually reenabled duplicate targets cannot race",function()
    local a,o,db,e=setup(); db.rules.r2=U.copy(db.rules.r1); db.rules.r2.overrides.opacity.value.alpha=0.7
    e:sync(); e:tick(); eq(o.writeCount,0); eq(e.states.r1.jobs.opacity.status,"blocked")
    db.rules.r2.enabled=false; e:sync(); e:tick(); eq(o.values.alpha,0.3)
end)
print(string.format("CORE: %d/%d passed (Lua %s)",passed,tests,_VERSION))
return tests
