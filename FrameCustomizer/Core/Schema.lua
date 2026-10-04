local _, FC = ...
local U,P = FC.Util,FC.Properties
local S = {version=2}
FC.Schema=S
function S.target(t)
    local root,keys,types=U.field(t,"root"),U.field(t,"keys"),U.field(t,"types")
    if not U.identifier(root) or type(keys)~="table" or type(types)~="table" then return nil,"No stable target identity" end
    local out={root=root,keys={},types={}}
    if #keys>FC.LIMITS.depth or #types~=#keys+1 then return nil,"Invalid target depth/types" end
    for i=1,#keys do
        if not U.identifier(U.field(keys,i)) then return nil,"Invalid parent key" end
        out.keys[i]=keys[i]
    end
    for i=1,#types do
        if not U.identifier(U.field(types,i)) then return nil,"Invalid object type" end
        out.types[i]=types[i]
    end
    return out
end
function S.interval(x) return U.number(x,FC.LIMITS.minInterval,FC.LIMITS.maxInterval) end
function S.rule(raw)
    local t,why=S.target(U.field(raw,"target")); if not t then return nil,why end
    local enabled,periodic=U.field(raw,"enabled"),U.field(raw,"periodic")
    if type(enabled)~="boolean" or type(periodic)~="boolean" or not S.interval(U.field(raw,"interval")) then return nil,"Invalid enable/periodic/interval setting" end
    local r={target=t,enabled=enabled,periodic=periodic,interval=raw.interval,overrides={}}
    local o=U.field(raw,"overrides"); if type(o)~="table" then return nil,"Invalid overrides" end
    local warnings={}
    for _,d in ipairs(P.order) do
        local entry=U.field(o,d.id)
        if entry then
            local value,reason=d.validate(U.field(entry,"value"))
            local on=U.field(entry,"enabled")
            local per,interval=U.field(entry,"periodic"),U.field(entry,"interval")
            if value and type(on)=="boolean" and (per==nil or type(per)=="boolean") and (interval==nil or S.interval(interval)) and P.applicable(d,t.types[#t.types]) then
                r.overrides[d.id]={enabled=on,value=value,periodic=per,interval=interval}
            else warnings[#warnings+1]=d.id..": "..(reason or "invalid settings or object type") end
        end
    end
    local conflict=P.conflict(r.overrides)
    if conflict then return nil,conflict end
    return r,nil,warnings
end
function S.load(raw)
    local db={version=S.version,paused=false,nextID=1,rules={},visuals={},nextVisualID=1}
    local warnings={}
    if U.safe(raw) and raw==nil then return db,warnings end
    if U.field(raw,"version")~=S.version and U.field(raw,"version")~=1 then
        db.paused=true
        return db,{"Unknown or malformed schema: original saved variable preserved; editor is read-only"},true
    end
    db.paused=U.field(raw,"paused")~=false
    local rules=U.field(raw,"rules")
    if type(rules)~="table" then db.paused=true; return db,{"Rules table missing; original saved variable preserved"},true end
    local count,seen=0,{}
    for id,r in pairs(rules) do
        count=count+1
        if count>FC.LIMITS.rules then warnings[#warnings+1]="Rule limit reached (128)"; break end
        if U.string(id,16) and id:match("^r%d+$") then
            local valid,reason,notes=S.rule(r)
            if valid then
                local key=U.joinTarget(valid.target)
                if seen[key] then
                    valid.enabled=false; db.rules[seen[key]].enabled=false
                    warnings[#warnings+1]=id..": all entries sharing this target paused"
                end
                seen[key]=id; db.rules[id]=valid
                db.nextID=math.max(db.nextID,math.min(1000000000,tonumber(id:sub(2)) or 0)+1)
                for _,note in ipairs(notes) do warnings[#warnings+1]=id..": "..note end
            else warnings[#warnings+1]=id..": skipped ("..reason..")" end
        else warnings[#warnings+1]="Skipped entry with invalid rule id" end
    end
    local visuals=U.field(raw,"visuals")
    if U.field(raw,"version")==2 and visuals~=nil then
        if type(visuals)~="table" then db.paused=true; return db,{"Malformed visuals table: original saved variable preserved"},true end
        local count=0
        for id,v in pairs(visuals) do
            count=count+1
            if count>FC.LIMITS.visuals then warnings[#warnings+1]="Visual limit reached (64)"; break end
            if U.string(id,16) and id:match("^v%d+$") then
                local valid,why=FC.Visuals.validate(v)
                if valid then
                    db.visuals[id]=valid
                    db.nextVisualID=math.max(db.nextVisualID,math.min(1000000000,tonumber(id:sub(2)) or 0)+1)
                else warnings[#warnings+1]=id..": skipped ("..why..")" end
            else warnings[#warnings+1]="Skipped invalid visual ID" end
        end
    end
    -- Never reuse deleted identities on reload. Version 1 settings stay intact.
    for _,key in ipairs({"nextID","nextVisualID"}) do
        local n=U.field(raw,key)
        if U.number(n,1,1000000001) and n%1==0 then db[key]=math.max(db[key],n) end
    end
    return db,warnings
end
function S.export(db) local clean=S.load(db); return clean end

