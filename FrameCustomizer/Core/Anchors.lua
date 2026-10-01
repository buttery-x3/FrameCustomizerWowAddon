local _,FC=...
local U=FC.Util
local G={}; FC.Anchors=G
G.points={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
local function point(v) return U.string(v,16) and G.points[v]==true end
local function offset(v) return U.number(v,-8192,8192) end
function G.validate(v)
    local p,rp,x,y=U.field(v,"point"),U.field(v,"relativePoint"),U.field(v,"x"),U.field(v,"y")
    if not point(p) or not point(rp) or not U.number(x,-4096,4096) or not U.number(y,-4096,4096) then return nil,"Invalid anchor point or offset" end
    local out={point=p,relativePoint=rp,x=x,y=y}
    local anchors=U.field(v,"anchors")
    if anchors==nil then return out end -- v1 parent-anchor rules retain their meaning.
    if type(anchors)~="table" or #anchors<1 or #anchors>8 then return nil,"Unsupported layout: require 1..8 anchors" end
    out.anchors={}; local seen={}
    for i=1,#anchors do
        local a=U.field(anchors,i)
        local ap,ar,dx,dy=U.field(a,"point"),U.field(a,"relativePoint"),U.field(a,"dx"),U.field(a,"dy")
        local relative=U.field(a,"relative")
        if not point(ap) or not point(ar) or seen[ap] or not offset(dx) or not offset(dy) or not offset(x+dx) or not offset(y+dy) then return nil,"Unsupported layout: invalid or duplicate anchor" end
        if i>1 and ap<out.anchors[i-1].point then return nil,"Unsupported layout: preserved anchors must be sorted by point" end
        if relative~="parent" and relative~="UIParent" then
            relative=FC.Schema.target(relative)
            if not relative then return nil,"Unsupported layout: anchor needs a stable relative identity" end
        end
        seen[ap]=true; out.anchors[i]={point=ap,relativePoint=ar,relative=relative,dx=dx,dy=dy}
    end
    local first=out.anchors[1]
    if p~=first.point or rp~=first.relativePoint or first.dx~=0 or first.dy~=0 then return nil,"Preserved anchors: edit X/Y only; anchor points stay unchanged" end
    return out
end
function G.snapshot(a,o)
    local ok,n=a:read(o,"GetNumPoints")
    if not ok then return nil,"Inaccessible: anchor count unavailable","anchor_count_inaccessible","inaccessible" end
    if not U.number(n,1,8) or n%1~=0 then return nil,"Unsupported layout: require 1..8 existing anchors","anchor_count_unsupported","unsupported" end
    local anchors,seen={},{}
    for i=1,n do
        local good,p,relative,rp,x,y=a:read(o,"GetPoint",i)
        if not good then return nil,"Inaccessible: anchor values unavailable or secret","anchor_values_inaccessible","inaccessible" end
        if not point(p) or not point(rp) or seen[p] or not offset(x) or not offset(y) then return nil,"Unsupported layout: anchor format, duplicate point or offset range","anchor_format_unsupported","unsupported" end
        if not relative or relative==o or not a:inspectable(relative) then return nil,"Inaccessible: anchor relative object unavailable","anchor_relative_inaccessible","inaccessible" end
        seen[p]=true; anchors[#anchors+1]={point=p,relative=relative,relativePoint=rp,x=x,y=y}
    end
    table.sort(anchors,function(l,r) return l.point<r.point end)
    return anchors
end
function G.relativeIdentity(a,o,relative)
    if relative==a:parent(o) then return "parent" end
    if relative==UIParent then return "UIParent" end
    return FC.Resolver.describe(a,relative)
end
function G.relativeObject(a,o,identity)
    if identity=="parent" then return a:parent(o) end
    if identity=="UIParent" then return UIParent end
    return FC.Resolver.resolve(a,identity)
end
function G.read(a,o)
    local anchors,why,code,state=G.snapshot(a,o); if not anchors then return nil,why,code,state end
    local first=anchors[1]
    local value={point=first.point,relativePoint=first.relativePoint,x=first.x,y=first.y}
    if #anchors==1 and first.relative==a:parent(o) then return G.validate(value) end
    value.anchors={}
    for i,anchor in ipairs(anchors) do
        local relative=G.relativeIdentity(a,o,anchor.relative)
        if not relative then return nil,"Unsupported layout: anchor relative has no stable identity","anchor_identity_unsupported","unsupported" end
        value.anchors[i]={point=anchor.point,relativePoint=anchor.relativePoint,relative=relative,dx=anchor.x-first.x,dy=anchor.y-first.y}
    end
    return G.validate(value)
end
function G.compatible(a,o,value,anchors)
    if not value.anchors then
        if #anchors~=1 or anchors[1].relative~=a:parent(o) then return false,"Unsupported layout: legacy position needs one parent anchor; disable it and recapture Position","legacy_anchor_mismatch","unsupported" end
        return true
    end
    if #anchors~=#value.anchors then return false,"Unsupported layout: anchor count changed; disable Position and recapture","anchor_count_changed","unsupported" end
    for _,saved in ipairs(value.anchors) do
        local relative=G.relativeObject(a,o,saved.relative)
        if not relative then return false,"Unsupported layout: saved anchor relative identity unresolved","anchor_relative_unresolved","pending" end
        local found=false
        for _,live in ipairs(anchors) do
            if live.point==saved.point and live.relativePoint==saved.relativePoint and live.relative==relative then found=true; break end
        end
        if not found then return false,"Unsupported layout: anchor relationship changed; disable Position and recapture","anchor_relationship_changed","unsupported" end
    end
    return true
end
function G.write(a,o,value)
    local function stop(reason,code,state)
        local result=U.geometryResult("position")
        result.representation=U.finding(state,code,reason); U.deferGeometry(result,reason)
    end
    local anchors,why,code,state=G.snapshot(a,o); if not anchors then stop(why,code,state) end
    local compatible,reason,whyCode,category=G.compatible(a,o,value,anchors)
    if not compatible then stop(reason,whyCode,category) end
    local plan={}
    if value.anchors then
        -- Resolve the COMPLETE update before any mutation. Never clear a complex
        -- arrangement or repeatedly add deltas to the live offsets.
        for _,anchor in ipairs(value.anchors) do
            local relative=G.relativeObject(a,o,anchor.relative)
            if not relative then stop("Unsupported layout: saved anchor relative identity unresolved","anchor_relative_unresolved","pending") end
            plan[#plan+1]={anchor.point,relative,anchor.relativePoint,value.x+anchor.dx,value.y+anchor.dy}
        end
    else
        local parent=a:parent(o)
        if not parent then stop("Inaccessible: anchor parent unavailable","anchor_relative_inaccessible","inaccessible") end
        plan[1]={value.point,parent,value.relativePoint,value.x,value.y}
    end
    if a.prepareGeometry then a:prepareGeometry(o,FC.Properties.byID.position,value) end
    -- Native checks are also repeated by the adapter before EVERY setter.
    if not value.anchors and anchors[1].point~=value.point then a:write(o,"ClearAllPoints") end
    for _,args in ipairs(plan) do a:write(o,"SetPoint",unpack(args)) end
end
function G.details(value)
    local valid,why=G.validate(value); if not valid then return why end
    local lines={"Primary offsets: X="..valid.x..", Y="..valid.y}
    if valid.anchors then
        for _,anchor in ipairs(valid.anchors) do
            local relative=type(anchor.relative)=="table" and U.joinTarget(anchor.relative) or anchor.relative
            lines[#lines+1]=anchor.point.." -> "..relative.."."..anchor.relativePoint.."; X="..(valid.x+anchor.dx)..", Y="..(valid.y+anchor.dy)
        end
    else lines[#lines+1]=valid.point.." -> existing parent."..valid.relativePoint.." (single parent anchor)" end
    return table.concat(lines,"\n")
end
