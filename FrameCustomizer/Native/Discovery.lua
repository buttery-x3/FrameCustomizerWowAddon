local _, FC = ...
local D={}; D.__index=D
FC.Discovery=D
function D.new(a) return setmetatable({a=a,nodes={},map={},queue={},head=1,changed=true,query="",filterExpanded={}},D) end
function D:add(o,parent)
    if self.map[o] then return self.map[o] end
    if #self.nodes>=FC.LIMITS.nodes then self.notice="Discovery cap reached (6000). Use picker / exact path or Refresh."; return end
    local target,reason=FC.Resolver.describe(self.a,o)
    local node={object=o,parent=parent,children={},label=self.a:label(o),kind=self.a:kind(o),
        path=target and FC.Util.joinTarget(target),identityReason=reason,depth=parent and parent.depth+1 or 0}
    self.nodes[#self.nodes+1]=node; self.map[o]=node
    if parent then parent.children[#parent.children+1]=node end
    self.changed=true
    return node
end
function D:refresh()
    self.nodes={}; self.map={}; self.queue={}; self.head=1; self.scanIndex=nil; self.notice=nil; self.pending=nil
    self.query=""; self.filterExpanded={}
    local root=self:add(UIParent)
    if root then self:expand(root) end
    self.changed=true
end
function D:isExpanded(node)
    if self.query~="" then
        if self.filterExpanded[node]~=nil then return self.filterExpanded[node] end
        return node.filterHasChildren==true
    end
    return node.expanded==true
end
function D:expand(node)
    local expanded=not self:isExpanded(node)
    if self.query~="" then self.filterExpanded[node]=expanded else node.expanded=expanded end
    if expanded and not node.loaded and not node.queued then
        node.queued=true; self.queue[#self.queue+1]=node
    end
    self.changed=true
end
function D:scan()
    self.scanIndex=1; self.notice="Scanning accessible hierarchy in bounded slices..."
end
function D:tick()
    if not self.pending then
        local node=self.queue[self.head]
        if node then self.queue[self.head]=false; self.head=self.head+1
        elseif self.scanIndex then
            for _=1,24 do
                node=self.nodes[self.scanIndex]; self.scanIndex=self.scanIndex+1
                if not node then self.scanIndex=nil; self.notice="Scan complete (accessible branches, maximum 6000 objects)."; break end
                if not node.loaded then break else node=nil end
            end
        end
        if node and not node.loaded then
            local children,reason=self.a:children(node.object)
            node.reason=reason; node.loaded=true; node.loading=true; node.queued=nil
            self.pending={node=node,children=children,index=1}
        end
    end
    local p=self.pending
    if p then
        for _=1,16 do
            local child=p.children[p.index]; p.index=p.index+1
            if not child then p.node.loading=nil; self.pending=nil; break end
            if self.a:inspectable(child) and not self.a:excluded(child) and self.a:parent(child)==p.node.object then self:add(child,p.node) end
        end
        self.changed=true
    end
    if self.head>128 and self.head>#self.queue then self.queue={}; self.head=1 end
end
function D:reveal(o)
    local chain={}
    local current=o
    for _=0,FC.LIMITS.depth do
        if not current then break end
        table.insert(chain,1,current)
        if self.map[current] or current==UIParent then break end
        current=self.a:parent(current)
    end
    local parent
    for _,object in ipairs(chain) do
        local node=self.map[object] or self:add(object,parent)
        if not node then break end
        if parent then
            if self.query~="" then self.filterExpanded[parent]=true else parent.expanded=true end
        end
        parent=node
    end
    -- A previously discovered node still needs all its ancestors opened.
    local ancestor=parent and parent.parent
    while ancestor do
        if self.query~="" then self.filterExpanded[ancestor]=true else ancestor.expanded=true end
        ancestor=ancestor.parent
    end
    self.changed=true
    return self.map[o]
end
function D:rows(query)
    local out={}; query=(query or ""):lower()
    if query~=self.query then self.filterExpanded={}; self.query=query end
    local included={}
    if query~="" then
        for _,node in ipairs(self.nodes) do
            node.filterHasChildren=false
            local text=node.label.." "..(node.path or "").." "..(node.kind or "")
            node.match=text:lower():find(query,1,true)~=nil
            if node.match then
                local ancestor=node
                while ancestor and not included[ancestor] do included[ancestor]=true; ancestor=ancestor.parent end
            end
        end
        for node in pairs(included) do if node.parent then node.parent.filterHasChildren=true end end
    end
    local seen={}
    local function visit(node)
        if seen[node] or query~="" and not included[node] then return end
        seen[node]=true; out[#out+1]=node
        if self:isExpanded(node) then for _,child in ipairs(node.children) do visit(child) end end
    end
    for _,node in ipairs(self.nodes) do if not node.parent then visit(node) end end
    return out
end
