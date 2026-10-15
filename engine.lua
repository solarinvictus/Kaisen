-- Kaisen combat accounting. Original implementation, GPL-3.0-or-later.
local M = {}
local function set(values) local t={}; for _,v in ipairs(values) do t[v]=true end; return t end
local damage = set{1,2,67,77,110,157,185,187,197,227,252,264,265,274,281,317,352,353,379,413,522,576,577,802}
local crit = set{67,353}
local burst = set{252,265,274,379}
local miss = set{15,63,158,188,245,282,324,354}
local avoid = set{14,30,31,32,33,69,70,189,248,283,323,355}
local extra_damage = set{161,163,229}
local parsed = set{1,2,3,4,5,6,11,13,14,15}
local chains = {'Light','Darkness','Gravitation','Fragmentation','Distortion','Fusion','Compression','Liquefaction','Induration','Reverberation','Transfixion','Scission','Detonation','Impaction','Cosmic Elucidation'}
local reverse = {[33]='Counter',[44]='Spikes',[132]='Dread Spikes',[536]='Retaliation'}

local function segment()
    return {actors={}, total=0, first=nil, last=nil, targets={}, count=0}
end
function M.new(timeout)
    return setmetatable({session=segment(), current=segment(), active=false, paused=false,
        elapsed=0, fights=0, timeout=timeout or 15, seen={}, seen_order={}}, {__index=M})
end
function M:reset()
    self.session, self.current = segment(), segment()
    self.active, self.elapsed, self.fights = false, 0, 0
    -- Keep recent packet fingerprints across a reset to reject retransmits.
end
function M.duration(s)
    return s.first and math.max(1, s.last-s.first) or 0
end
function M:seconds(mode)
    return mode=='session' and (self.elapsed+M.duration(self.current)) or M.duration(self.current)
end
function M:finish() self.active=false end
function M:tick(now)
    if self.active and now-self.current.last >= self.timeout then self:finish() end
end
function M:pause(value)
    if self.paused~=value then self:finish() end
    self.paused=value
end
function M:death(id)
    local t=self.current.targets[id]
    if not t or not self.active then return end
    t.dead=true
    for _,v in pairs(self.current.targets) do if not v.dead then return end end
    self:finish()
end
function M:duplicate(data, now)
    -- Includes the server packet sequence/header. Do not compare damage payloads alone.
    while self.seen_order[1] and (now-self.seen_order[1].ts>3 or #self.seen_order>=256) do
        local old=table.remove(self.seen_order,1)
        if self.seen[old.data]==old.ts then self.seen[old.data]=nil end
    end
    if self.seen[data] then return true end
    self.seen[data]=now
    self.seen_order[#self.seen_order+1]={data=data,ts=now}
    return false
end
local function fresh_actor(owner)
    return {id=owner.id,name=owner.name,job=owner.job or 0,total=0,pet=0,skillchain=0,
        melee={hits=0,misses=0,crits=0,avoided=0},ranged={hits=0,misses=0,crits=0,avoided=0},sources={}}
end
local function accumulate(s, owner, event, now)
    s.first=s.first or now; s.last=now; s.count=s.count+1
    local a=s.actors[owner.id]
    if not a then a=fresh_actor(owner);s.actors[owner.id]=a end
    a.name, a.job=owner.name,owner.job or a.job
    local n=event.amount or 0
    a.total=a.total+n; s.total=s.total+n
    if owner.pet then a.pet=a.pet+n end
    if event.category=='Skillchain' then a.skillchain=a.skillchain+n end
    if not owner.pet and event.accuracy then
        local accuracy=a[event.accuracy]
        if event.result=='hit' then accuracy.hits=accuracy.hits+1
            if event.crit then accuracy.crits=accuracy.crits+1 end
        elseif event.result=='miss' then accuracy.misses=accuracy.misses+1
        else accuracy.avoided=accuracy.avoided+1 end
    end
    local key=(owner.pet and ('pet:'..owner.pet..':') or '')..event.key
    local src=a.sources[key]
    if not src then
        src={name=(owner.pet and (owner.pet..' / ') or '')..event.name,
            category=owner.pet and 'Pet' or event.category,total=0,hits=0,misses=0,avoided=0,crits=0,bursts=0,max=0}
        a.sources[key]=src
    end
    src.total=src.total+n;src.max=math.max(src.max,n)
    if event.result=='hit' then src.hits=src.hits+1
    elseif event.result=='miss' then src.misses=src.misses+1
    else src.avoided=src.avoided+1 end
    if event.crit then src.crits=src.crits+1 end
    if event.burst then src.bursts=src.bursts+1 end
end
function M:record(owner, target, event, now, target_name)
    if self.paused then return end
    self:tick(now)
    if not self.active then
        self.elapsed=self.elapsed+M.duration(self.current)
        self.current=segment();self.active=true;self.fights=self.fights+1
    end
    self.current.targets[target]={name=target_name or ('Target '..target),dead=false}
    accumulate(self.current,owner,event,now)
    accumulate(self.session,owner,event,now)
end
local function source(category,id,message,animation,resource)
    if category==1 and animation~=4 then return 'Melee','Melee','melee','melee' end
    if category==2 or (category==1 and animation==4) then return 'Ranged','Ranged','ranged','ranged' end
    if category==3 and message~=110 and message~=158 then return resource('ws',id),'Weapon skill','ws:'..id end
    if category==4 then return resource('spell',id),'Magic','spell:'..id end
    if category==11 or category==13 then return resource('pet',id),'Pet ability','petability:'..id end
    if category==5 then return 'Item damage','Item','item:'..id end
    return resource('ability',id),'Ability','ability:'..id
end
function M:process(packet,now,resolve,resource,target_name)
    if self.paused or not parsed[packet.category] then return end
    local owner=resolve(packet.actor)
    for _,target in ipairs(packet.targets) do
        local defender=resolve(target.id)
        for _,a in ipairs(target.actions) do
            if owner and not defender then
                local landed=damage[a.message]
                if landed or miss[a.message] or avoid[a.message] then
                    local name,kind,key,accuracy=source(packet.category,packet.id,a.message,a.animation,resource)
                    self:record(owner,target.id,{name=name,category=kind,key=key,accuracy=accuracy,
                        amount=landed and a.value or 0,result=landed and 'hit' or (miss[a.message] and 'miss' or 'avoided'),
                        crit=crit[a.message],burst=burst[a.message]},now,target_name(target.id))
                end
                if a.extra then
                    local sc=chains[a.extra.message-287]
                    if sc or extra_damage[a.extra.message] then
                        self:record(owner,target.id,{name=sc or 'Additional effect',category=sc and 'Skillchain' or 'Additional',
                            key=sc and ('sc:'..sc) or 'additional',amount=a.extra.value,result='hit'},now,target_name(target.id))
                    end
                end
            end
            -- Counter/spike values belong to the DEFENDER. Never charge them to the attacker.
            if defender and not owner then
                local effect=a.spike and reverse[a.spike.message] and a.spike or (reverse[a.message] and a or nil)
                if effect then
                    local name=reverse[effect.message]
                    self:record(defender,packet.actor,{name=name,category='Counter / spikes',key='reverse:'..name,
                        amount=effect.value,result='hit'},now,target_name(packet.actor))
                end
            end
        end
    end
end
function M.rows(s)
    local rows={};for _,v in pairs(s.actors) do rows[#rows+1]=v end
    table.sort(rows,function(a,b) if a.total==b.total then return a.name<b.name end return a.total>b.total end)
    return rows
end
function M.accuracy(a)
    local n=a.hits+a.misses
    return n>0 and (100*a.hits/n) or nil
end
function M.critical(a) return a.hits>0 and (100*a.crits/a.hits) or nil end
return M
