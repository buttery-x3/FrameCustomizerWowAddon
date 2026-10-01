local _, FC = ...
local U = FC.Util
local P = { order = {}, byID = {} }
FC.Properties = P
local function num(v, a, b) return U.number(v, a, b) end
local function str(v) return U.string(v, 240) and #v > 0 end
local function fields(v, names, validators)
    if not U.safe(v) or type(v) ~= "table" then return nil, "Expected a value record" end
    local r = {}
    for i, key in ipairs(names) do
        local x = U.field(v, key)
        if not validators[i](x) then return nil, "Invalid " .. key end
        r[key] = x
    end
    return r
end
local function rgba(v)
    local unit = function(x) return num(x, 0, 1) end
    return fields(v, {"r", "g", "b", "a"}, {unit, unit, unit, unit})
end
local function add(d)
    d.repeatable = true
    d.permission = d.permission or "cosmetic"
    P.byID[d.id] = d
    P.order[#P.order + 1] = d
end
local visual = { Frame = true, Button = true, CheckButton = true, StatusBar = true,
    ScrollFrame = true, EditBox = true, Slider = true, Texture = true, FontString = true }
add({id="opacity", label="Opacity / decorative suppression", types=visual,
    help="0 suppresses rendering. It does not Hide(), remove mouse input, or stop Blizzard scripts. Prefer a decorative child region.",
    reads={"GetAlpha"}, writes={"SetAlpha"}, signals={"SetAlpha","SetVertexColor","SetTextColor","SetStatusBarColor"}, aspects={"Alpha"},
    default={alpha=1}, inputs={{"alpha","Opacity (0..1)"}},
    validate=function(v) return fields(v, {"alpha"}, {function(x) return num(x,0,1) end}) end,
    read=function(a,o) local ok,x=a:read(o,"GetAlpha"); if ok then return {alpha=x} end end,
    write=function(a,o,v) a:write(o,"SetAlpha",v.alpha) end})
add({id="texture", label="Texture or atlas", types={Texture=true},
    help="Choose file or atlas. Atlas size is never adopted. File replacement preserves the existing UV coordinates; use an asset suited to that region.",
    reads={"GetAtlas","GetTexture"}, writes={"SetTexture","SetAtlas"},
    signals={"SetTexture","SetAtlas","SetColorTexture"}, aspects={}, permission="texture",
    default={kind="file",asset="Interface\\Buttons\\WHITE8X8"},
    inputs={{"kind","Kind: file / atlas"},{"asset","Path or atlas name","texture"}},
    validate=function(v) return fields(v,{"kind","asset"},{function(x) return x=="file" or x=="atlas" end,str}) end,
    read=function(a,o)
        local ok,atlas=a:read(o,"GetAtlas")
        if not ok then return end
        if type(atlas)=="string" and atlas~="" then return {kind="atlas",asset=atlas} end
        local good,file=a:read(o,"GetTexture")
        if good and type(file)=="string" and file~="" then return {kind="file",asset=file} end
    end,
    write=function(a,o,v)
        if v.kind=="atlas" then a:write(o,"SetAtlas",v.asset,false) else a:write(o,"SetTexture",v.asset) end
    end})
add({id="tint",label="Texture colour",types={Texture=true},reads={"GetVertexColor"},writes={"SetVertexColor"},
    signals={"SetVertexColor","SetAlpha"},aspects={"VertexColor","Alpha"},
    help="Multiplicative RGBA tint; image pixels and parent alpha still affect the result.",
    default={r=1,g=1,b=1,a=1},inputs={{"r","Red (0..1)"},{"g","Green (0..1)"},{"b","Blue (0..1)"},{"a","Alpha (0..1)"}},validate=rgba,
    read=function(a,o) local ok,r,g,b,x=a:read(o,"GetVertexColor"); if ok then return {r=r,g=g,b=b,a=x} end end,
    write=function(a,o,v) a:write(o,"SetVertexColor",v.r,v.g,v.b,v.a) end})
local flags = {[""]=true,OUTLINE=true,THICKOUTLINE=true,MONOCHROME=true,["OUTLINE,MONOCHROME"]=true,["THICKOUTLINE,MONOCHROME"]=true}
add({id="font",label="Font face, size and flags",types={FontString=true},reads={"GetFont"},writes={"SetFont"},
    signals={"SetFont","SetFontObject","CopyFontObject"},aspects={},
    help="Sets this FontString only. Flags: blank, OUTLINE, THICKOUTLINE, MONOCHROME, or outline plus ,MONOCHROME.",
    default={face="Fonts\\FRIZQT__.TTF",size=14,flags=""},inputs={{"face","Font path","font"},{"size","Size (6..96)"},{"flags","Flags"}},
    validate=function(v) return fields(v,{"face","size","flags"},{str,function(x) return num(x,6,96) end,function(x) return U.string(x,48) and flags[x] end}) end,
    read=function(a,o) local ok,f,s,x=a:read(o,"GetFont"); if ok then return {face=f,size=s,flags=x or ""} end end,
    write=function(a,o,v) a:write(o,"SetFont",v.face,v.size,v.flags) end})
add({id="textColor",label="Font colour",types={FontString=true},reads={"GetTextColor"},writes={"SetTextColor"},
    signals={"SetTextColor","SetVertexColor","SetAlpha","SetFontObject","CopyFontObject"},aspects={"VertexColor","Alpha"},
    help="RGBA colour of this FontString. Embedded text colour codes can take precedence.",
    default={r=1,g=1,b=1,a=1},inputs={{"r","Red (0..1)"},{"g","Green (0..1)"},{"b","Blue (0..1)"},{"a","Alpha (0..1)"}},validate=rgba,
    read=function(a,o) local ok,r,g,b,x=a:read(o,"GetTextColor"); if ok then return {r=r,g=g,b=b,a=x} end end,
    write=function(a,o,v) a:write(o,"SetTextColor",v.r,v.g,v.b,v.a) end})
add({id="barTexture",label="Status bar texture",types={StatusBar=true},reads={"GetStatusBarTexture"},writes={},
    signals={"SetStatusBarTexture","SetStatusBarAtlas"},aspects={},permission="barTexture",
    help="Changes the existing fill Texture's file. Keeps the bar, values, fill sizing and scripts. A missing or restricted fill is unavailable.",
    default={asset="Interface\\TargetingFrame\\UI-StatusBar"},inputs={{"asset","Texture path","statusbar"}},
    validate=function(v) return fields(v,{"asset"},{str}) end,
    read=function(a,o)
        local t=a:barRegion(o)
        if t then local ok,f=a:read(t,"GetTexture"); if ok and type(f)=="string" then return {asset=f} end end
    end,
    write=function(a,o,v) local t=a:barRegion(o); if not t then error("Fill region unavailable") end; a:write(t,"SetTexture",v.asset) end})
add({id="barColor",label="Status bar colour",types={StatusBar=true},reads={"GetStatusBarColor"},writes={"SetStatusBarColor"},
    signals={"SetStatusBarColor","SetAlpha"},aspects={"VertexColor","Alpha"},
    help="Changes appearance only. FrameCustomizer never sets the bar's value, range or gameplay data.",
    default={r=0.2,g=0.75,b=1,a=1},inputs={{"r","Red (0..1)"},{"g","Green (0..1)"},{"b","Blue (0..1)"},{"a","Alpha (0..1)"}},validate=rgba,
    read=function(a,o) local ok,r,g,b,x=a:read(o,"GetStatusBarColor"); if ok then return {r=r,g=g,b=b,a=x} end end,
    write=function(a,o,v) a:write(o,"SetStatusBarColor",v.r,v.g,v.b,v.a) end})
add({id="size",label="Size",types=visual,reads={"GetSize"},writes={"SetSize"},
    signals={"SetSize","SetWidth","SetHeight"},aspects={},permission="geometry",setting="size",
    help="Requires native geometry permission and supported anchors. Layout managers are advisory; exposed Edit Mode dimensions use Edit Mode. Multi-anchor size is unsupported.",
    default={width=160,height=32},inputs={{"width","Width (1..4096)"},{"height","Height (1..4096)"}},
    validate=function(v) local n=function(x) return num(x,1,4096) end; return fields(v,{"width","height"},{n,n}) end,
    read=function(a,o) local ok,w,h=a:read(o,"GetSize"); if ok then return {width=w,height=h} end end,
    write=function(a,o,v) if a.prepareGeometry then a:prepareGeometry(o,P.byID.size,v) end; a:write(o,"SetSize",v.width,v.height) end})
add({id="position",label="Position / preserved anchors",types=visual,reads={"GetNumPoints","GetPoint","GetParent"},writes={"SetPoint"},
    signals={"ClearAllPoints","SetPoint","SetAllPoints","ClearPoint","AdjustPointsOffset","SetPointsOffset","ClearPointsOffset"},aspects={},permission="geometry",setting="position",
    help="One parent anchor, or 1..8 preserved anchors to accessible stable relatives. X/Y translates all preserved anchors; their points, relatives and spacing stay fixed. Disable and reselect Position to recapture a changed layout.",
    default={point="CENTER",relativePoint="CENTER",x=0,y=0},inputs={{"point","Anchor point (preserved if multiple)"},{"relativePoint","Relative point"},{"x","X offset (-4096..4096)"},{"y","Y offset (-4096..4096)"}},
    validate=FC.Anchors.validate,read=FC.Anchors.read,write=FC.Anchors.write})
function P.applicable(d, kind) return d.types[kind] == true end
function P.conflict(overrides)
    -- Vertex/text/bar colour alpha and SetAlpha share the Alpha aspect. Do not
    -- create two rules fighting over the same value on a single target.
    local opacity=overrides.opacity
    if opacity and opacity.enabled then
        for _,key in ipairs({"tint","textColor","barColor"}) do
            local c=overrides[key]
            if c and c.enabled and math.abs(c.value.a-opacity.value.alpha)>0.0005 then
                return "Opacity and colour alpha must match when both overrides are enabled"
            end
        end
    end
end

