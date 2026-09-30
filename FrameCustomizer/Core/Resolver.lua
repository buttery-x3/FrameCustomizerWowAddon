local _, FC = ...
local R={}
FC.Resolver=R
function R.resolve(a,t)
    local o,why=a:global(t.root)
    if not o then return nil,why or "unresolved" end
    for i=1,#t.types do
        local ok,reason=a:inspectable(o)
        if not ok then return nil,reason or "blocked" end
        if a:kind(o)~=t.types[i] then return nil,"ambiguous: object type changed" end
        if i<=#t.keys then
            local child,err=a:keyChild(o,t.keys[i])
            if not child then return nil,err or "unresolved parent key" end
            o=child
        end
    end
    local excluded=a:excluded(o)
    if excluded then return nil,"blocked: editor infrastructure" end
    return o
end
function R.describe(a,o)
    local keys,types,seen={},{},{}
    if a:excluded(o) then return nil,"Editor/root infrastructure is not an editable target" end
    for _=0,FC.LIMITS.depth do
        if not a:inspectable(o) or seen[o] then return nil,"Restricted or unsupported ancestry" end
        seen[o]=true
        local kind=a:kind(o)
        if not kind then return nil,"Object type inaccessible; stable identity cannot be verified" end
        table.insert(types,1,kind)
        local name=a:name(o)
        if name and a:global(name)==o then return {root=name,keys=keys,types=types} end
        local key=a:parentKey(o); local parent=a:parent(o)
        if not key or not parent or a:keyChild(parent,key)~=o then return nil,"No verified global name / parent-key path; anonymous and pooled matches are read-only" end
        table.insert(keys,1,key); o=parent
    end
    return nil,"Target ancestry exceeds 12 levels"
end
