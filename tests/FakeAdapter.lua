local _,FC=...
local F={}; F.__index=F
FC.FakeAdapter=F
local allowedReads={GetAlpha=true,GetAtlas=true,GetTexture=true,GetVertexColor=true,GetTextColor=true,
    GetFont=true,GetStatusBarColor=true,GetStatusBarTexture=true,GetSize=true,GetNumPoints=true,GetPoint=true,GetParent=true,GetFrameStrata=true,GetFrameLevel=true,GetDrawLayer=true}
local allowedWrites={SetAlpha=true,SetTexture=true,SetAtlas=true,SetVertexColor=true,SetFont=true,SetTextColor=true,
    SetStatusBarColor=true,SetSize=true,ClearAllPoints=true,SetPoint=true,SetFrameStrata=true,SetFrameLevel=true,SetDrawLayer=true}
local signals={SetAlpha=true,SetTexture=true,SetAtlas=true,SetColorTexture=true,SetVertexColor=true,
    SetTextColor=true,SetFont=true,SetFontObject=true,CopyFontObject=true,SetStatusBarColor=true,SetStatusBarTexture=true,
    SetStatusBarAtlas=true,SetSize=true,SetWidth=true,SetHeight=true,ClearAllPoints=true,SetPoint=true,SetAllPoints=true,
    ClearPoint=true,AdjustPointsOffset=true,SetPointsOffset=true,ClearPointsOffset=true,SetFrameStrata=true,SetFrameLevel=true,SetDrawLayer=true,SetFixedFrameLevel=true,SetFixedFrameStrata=true}
function F.new() return setmetatable({globals={},time=0,hookCount=0,errorCount=0,writeLog={},readCount=0},F) end
function F:object(name,kind,parent,key)
    local o={name=name,kind=kind or "Texture",parent=parent,key=key,children={},hooks={},missing={},values={
        alpha=1,texture="Interface\\Buttons\\WHITE8X8",atlas="",color={1,1,1,1},font={"Fonts\\FRIZQT__.TTF",14,""},
        size={100,20},point={"CENTER",parent,"CENTER",0,0}},writeCount=0}
    if name then self.globals[name]=o end
    if parent and key then parent.children[key]=o end
    return o
end
function F:now() return self.time end
function F:inspectable(o) return o~=nil and not o.forbidden, "blocked: inaccessible object" end
function F:kind(o) return o.kind end
function F:name(o) return o.name end
function F:parent(o) return o.parent end
function F:parentKey(o) return o.key end
function F:excluded(o) return o and o.excluded or false end
function F:global(name)
    local o=self.globals[name]
    if o and o.ambiguous then return nil,"ambiguous: global identity mismatch" end
    if o and o.name~=name then return nil,"ambiguous: global alias not verified" end
    return o
end
function F:keyChild(parent,key)
    local o=parent.children[key]
    if o and (o.parent~=parent or o.key~=key) then return nil,"ambiguous: parent-key mismatch" end
    return o
end
function F:canWrite(o,d)
    if o.denied then return false,"Denied operation",o.transient end
    for _,name in ipairs(d.writes) do if o.missing[name] then return false,"Missing method "..name,false end end
    return self:inspectable(o)
end
function F:canRead(o,d)
    if o.unreadable then return false end
    for _,key in ipairs(d.reads) do if o.missing[key] then return false end end
    return true
end
function F:barRegion(o) return o.fill end
function F:read(o,key)
    assert(allowedReads[key],"Unknown fake read: "..tostring(key))
    assert(not o.unreadable,"Inaccessible fake value was consumed")
    assert(not o.missing[key],"Missing fake method was called")
    self.readCount=self.readCount+1
    if o.readError then error("injected read error") end
    local v=o.values
    if key=="GetFrameStrata" then return true,v.strata or "MEDIUM"
    elseif key=="GetFrameLevel" then return true,v.level or 1
    elseif key=="GetDrawLayer" then return true,v.layer or "ARTWORK",v.sublevel or 0
    elseif key=="GetAlpha" then return true,v.alpha
    elseif key=="GetAtlas" then return true,v.atlas
    elseif key=="GetTexture" then return true,v.texture
    elseif key=="GetVertexColor" or key=="GetTextColor" or key=="GetStatusBarColor" then return true,unpack(v.color)
    elseif key=="GetFont" then return true,unpack(v.font)
    elseif key=="GetSize" then return true,unpack(v.size)
    elseif key=="GetParent" then return true,o.parent
    elseif key=="GetNumPoints" then return true,1
    elseif key=="GetPoint" then return true,unpack(v.point)
    elseif key=="GetStatusBarTexture" then return true,o.fill end
end
function F:fire(o,key)
    for _,f in ipairs(o.hooks[key] or {}) do f("arguments must not be inspected") end
end
function F:write(o,key,...)
    assert(allowedWrites[key],"Unknown fake write: "..tostring(key))
    assert(not o.denied,"Denied fake setter was called")
    assert(not o.missing[key],"Missing fake setter was called")
    if o.failures and o.failures>0 then o.failures=o.failures-1; self:fire(o,key); error("injected setter error") end
    local x={...}; local v=o.values
    if key=="SetFrameStrata" then v.strata=x[1]
    elseif key=="SetFrameLevel" then v.level=x[1]
    elseif key=="SetDrawLayer" then v.layer=x[1]; v.sublevel=x[2]
    elseif key=="SetAlpha" then v.alpha=x[1]
    elseif key=="SetTexture" then v.texture=x[1]; v.atlas=""
    elseif key=="SetAtlas" then v.atlas=x[1]
    elseif key=="SetVertexColor" or key=="SetTextColor" or key=="SetStatusBarColor" then v.color=x; v.alpha=x[4]
    elseif key=="SetFont" then v.font=x
    elseif key=="SetSize" then v.size=x
    elseif key=="ClearAllPoints" then v.point={}
    elseif key=="SetPoint" then v.point=x end
    self.writeLog[#self.writeLog+1]=key; o.writeCount=o.writeCount+1
    self:fire(o,key)
end
function F:hook(o,key,f)
    assert(signals[key],"Unknown fake hook "..key)
    if o.noHooks or o.missing[key] then return false end
    o.hooks[key]=o.hooks[key] or {}; table.insert(o.hooks[key],f); self.hookCount=self.hookCount+1; return true
end
function F:onError() self.errorCount=self.errorCount+1 end
function F:advance(e,seconds)
    local steps=math.ceil(seconds/0.05)
    for _=1,steps do self.time=self.time+0.05; e:tick() end
end

