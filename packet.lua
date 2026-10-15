-- Kaisen, GPL-3.0-or-later. 0x028 layout: atom0s/XiPackets.
-- Reader injection keeps host-specific bit access outside this module.
local M = {}
function M.decode(data, unpack_bits)
    if type(data) ~= 'string' or #data < 19 then return nil, 'short header' end
    local pos, failed, limit = 40, false, #data * 8
    local function take(n)
        if pos + n > limit then failed = true; return 0 end
        local value = unpack_bits(pos, n)
        pos = pos + n
        return value
    end
    local p = {actor=take(32), targets={}}
    local count = take(6)
    take(4)
    p.category = take(4)
    p.id = take(32) % 65536
    take(32)
    for _=1,count do
        local t = {id=take(32), actions={}}
        local results = take(4)
        for _=1,results do
            local a = {reaction=take(5), animation=take(12)}
            take(7); take(3)
            a.value, a.message = take(17), take(10)
            take(31)
            if take(1) == 1 then
                a.extra = {effect=take(10), value=take(17), message=take(10)}
            end
            if take(1) == 1 then
                a.spike = {effect=take(10), value=take(14), message=take(10)}
            end
            if failed then return nil, 'truncated result' end
            t.actions[#t.actions+1] = a
        end
        if failed then return nil, 'truncated target' end
        p.targets[#p.targets+1] = t
    end
    if p.actor == 0 or count == 0 then return nil, 'empty action' end
    return p
end
return M
