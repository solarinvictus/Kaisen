-- Explicit chat reporting; build an immutable snapshot before queueing lines.
local Engine=require('engine')
local M={}
function M.build(engine,mode,limit)
    local segment=mode=='session' and engine.session or engine.current
    local rows=Engine.rows(segment)
    if #rows==0 or segment.total<=0 then return nil,'No damage recorded for this view.' end
    local seconds=engine:seconds(mode)
    limit=math.min(limit or 6,#rows)
    local lines={('[Kaisen] %s | %.0f damage | %.1fs | Top %d/%d'):format(
        mode=='session' and 'Session' or 'Current fight',segment.total,seconds,limit,#rows)}
    for i=1,limit do
        local a=rows[i]
        local name=(a.name or 'Unknown'):gsub('[^%w%-]',''):sub(1,24)
        local acc=Engine.accuracy(a.melee)
        lines[#lines+1]=('%d. %s: %.0f dmg | %.1f DPS | %.1f%% | Acc %s'):format(
            i,name,a.total,seconds>0 and a.total/seconds or 0,100*a.total/segment.total,
            acc and ('%.1f%%'):format(acc) or '--')
    end
    return lines
end
function M.new()
    return setmetatable({pending={},nextSend=0},{__index=M})
end
function M:cancel() self.pending={} end
function M:start(engine,mode,channel,limit,preview,now)
    if preview then return false,'Turn off Preview before reporting real results.' end
    local prefix=({party='/p ',p='/p ',linkshell='/l ',ls='/l ',l='/l '})[channel]
    if not prefix then return false,'Choose party or linkshell.' end
    if limit and (limit<1 or limit>18 or limit~=math.floor(limit)) then return false,'Report count must be 1 through 18.' end
    if #self.pending>0 then return false,'A report is already sending. Use /kaisen report cancel to stop it.' end
    local lines,err=M.build(engine,mode,limit)
    if not lines then return false,err end
    for _,line in ipairs(lines) do self.pending[#self.pending+1]=prefix..line end
    self.nextSend=now
    return true,'Sending report to '..(prefix=='/p ' and 'party' or 'linkshell')..'.'
end
function M:tick(now,send)
    if #self.pending==0 or now<self.nextSend then return end
    send(table.remove(self.pending,1))
    self.nextSend=now+1.2
end
return M
