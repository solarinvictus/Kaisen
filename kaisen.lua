-- Kaisen: FFXI-themed party damage parser. GPL-3.0-or-later.
addon.name='kaisen'
addon.author='OpenAI'
addon.version='1.0.21'
addon.desc='Party damage, DPS and accuracy with an FFXI-themed UI.'
require('common')
local imgui=require('imgui')
local settings=require('settings')
local Packet=require('packet')
local Engine=require('engine')
local UI=require('ui')
local Icons=require('jobicons')
local reporter=require('report').new()
local defaults=T{visible=true,locked=false,x=100,y=160,width=520,height=340,scale=1.0,timeout=15,include_skillchains=false,icon_theme='FFXI'}
local cfg=settings.load(defaults)
local engine=Engine.new(cfg.timeout)
local identity=nil
local names={}
local function save() settings.save() end
local function say(s) print('[Kaisen] '..s) end
local function sanitize()
    for k,v in pairs(defaults) do if cfg[k]==nil then cfg[k]=v end end
    cfg.scale=math.max(0.7,math.min(1.8,tonumber(cfg.scale) or 1))
    cfg.width=math.max(440,tonumber(cfg.width) or 520)
    cfg.height=math.max(180,tonumber(cfg.height) or 340)
    cfg.timeout=math.max(5,math.min(60,tonumber(cfg.timeout) or 15))
    cfg.x=tonumber(cfg.x) or 100;cfg.y=tonumber(cfg.y) or 160
    cfg.icon_theme=Icons.normalize(cfg.icon_theme)
    cfg.include_skillchains=cfg.include_skillchains==true
    engine:set_skillchains(cfg.include_skillchains)
    engine.timeout=cfg.timeout
end
sanitize()
settings.register('settings','kaisen_settings',function(s)
    if s then cfg=s end
    sanitize();UI.position=true;UI.size=true
end)
local function reset() reporter:cancel();engine:reset();UI.selected=nil end
local function report(channel,limit)
    local ok,message=reporter:start(engine,UI.mode,channel,limit,UI.preview,imgui.GetTime())
    say(message)
    return ok
end
local function roster()
    local mm=AshitaCore:GetMemoryManager()
    local party,entity=mm:GetParty(),mm:GetEntity()
    local members={}
    for i=0,17 do
        local active=party:GetMemberIsActive(i)
        local id=party:GetMemberServerId(i)
        if active and active~=0 and id and id~=0 then
            local owner={id=id,name=party:GetMemberName(i) or ('Player '..id),job=party:GetMemberMainJob(i) or 0}
            members[id]=owner
            local index=party:GetMemberTargetIndex(i)
            if index and index>0 then
                local pi=entity:GetPetTargetIndex(index)
                if pi and pi>0 then
                    local pid=entity:GetServerId(pi)
                    if pid and pid~=0 then
                        members[pid]={id=id,name=owner.name,job=owner.job,pet=entity:GetName(pi) or 'Pet'}
                    end
                end
            end
        end
    end
    return members
end
local function target_name(id)
    local entity=AshitaCore:GetMemoryManager():GetEntity()
    local index=bit.band(id,0xFFF)
    if id>=0x1000000 and index<0x900 and entity:GetServerId(index)==id then
        local name=entity:GetName(index)
        if name and name~='' then return name end
    end
    return ('Target %X'):format(id)
end
local function resource(kind,id)
    local key=kind..':'..id
    if names[key] then return names[key] end
    local rm=AshitaCore:GetResourceManager()
    local value
    if kind=='spell' then value=rm:GetSpellById(id)
    elseif kind=='ws' then value=rm:GetAbilityById(id)
    elseif kind=='ability' then value=rm:GetAbilityById(id+512)
    end
    local label=value and value.Name and value.Name[1]
    if not label or label=='' then
        label=(kind=='pet' and 'Pet ability #' or (kind=='spell' and 'Spell #' or 'Ability #'))..id
    end
    names[key]=label
    return label
end
local function u16(data,pos)
    local a,b=data:byte(pos+1,pos+2)
    return a+b*256
end
local function u32(data,pos)
    local a,b,c,d=data:byte(pos+1,pos+4)
    return a+b*256+c*65536+d*16777216
end
ashita.events.register('packet_in','kaisen_packets',function(e)
    if e.injected then return end
    if e.id==0x00A or e.id==0x00B then
        reporter:cancel();engine:finish();names={};return
    end
    if e.id==0x029 and #e.data>=26 then
        local message=bit.band(u16(e.data,24),0x7FFF)
        if message==6 or message==20 then engine:death(u32(e.data,8)) end
        return
    end
    if e.id~=0x028 or engine.paused then return end
    local now=imgui.GetTime()
    if engine:duplicate(e.data,now) then return end
    local packet=Packet.decode(e.data,function(pos,len) return ashita.bits.unpack_be(e.data_raw,0,pos,len) end)
    if not packet then return end
    local members=roster()
    engine:process(packet,now,function(id) return members[id] end,resource,target_name)
end)
ashita.events.register('d3d_present','kaisen_render',function()
    local id=AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)
    if id and id~=0 then
        if identity and identity~=id then reset() end
        identity=id
    end
    engine:tick(imgui.GetTime())
    reporter:tick(imgui.GetTime(),function(command)
        AshitaCore:GetChatManager():QueueCommand(-1,command)
    end)
    UI.draw(engine,cfg,save,reset,report)
end)
ashita.events.register('unload','kaisen_unload',save)
ashita.events.register('command','kaisen_command',function(e)
    local args=e.command:args()
    if #args==0 or args[1]:lower()~='/kaisen' then return end
    e.blocked=true
    local command=(args[2] or ''):lower()
    if command=='' or command=='settings' then cfg.visible=true;UI.settings=not UI.settings
    elseif command=='show' then cfg.visible=true
    elseif command=='hide' then cfg.visible=false
    elseif command=='preview' then cfg.visible=true;UI.preview=not UI.preview;UI.selected=nil
    elseif command=='current' or command=='session' then UI.mode=command;UI.selected=nil;cfg.visible=true
    elseif command=='pause' then engine:pause(true)
    elseif command=='resume' then engine:pause(false)
    elseif command=='report' then
        local channel=(args[3] or ''):lower()
        if channel=='cancel' then reporter:cancel();say('Report cancelled.');return end
        local limit=args[4] and tonumber(args[4]) or 6
        if (args[4] and not tonumber(args[4])) or #args>4 then
            say('Usage: /kaisen report party|linkshell [1-18]');return
        end
        report(channel,limit);return
    elseif command=='reset' then reset();say('Current fight and session cleared.')
    elseif command=='lock' then cfg.locked=not cfg.locked
    elseif command=='icons' then
        local theme=(args[3] or ''):lower()
        if theme~='ffxi' and theme~='classic' and theme~='ffxiv' and theme~='ffxiv-1' then
            say('Usage: /kaisen icons ffxi | classic | ffxiv');return
        end
        cfg.icon_theme=Icons.normalize(theme)
    elseif command=='scale' then
        local n=tonumber(args[3])
        if not n or n<0.7 or n>1.8 then say('Usage: /kaisen scale 0.7 through 1.8');return end
        cfg.scale=n
    elseif command=='idle' then
        local n=tonumber(args[3])
        if not n or n<5 or n>60 then say('Usage: /kaisen idle 5 through 60');return end
        cfg.timeout=n;engine.timeout=n
    elseif command=='move' then
        local x,y=tonumber(args[3]),tonumber(args[4])
        if not x or not y then say('Usage: /kaisen move 100 160');return end
        cfg.x=x;cfg.y=y;UI.position=true
    else
        say('/kaisen: settings | preview | show | hide | current | session | pause | resume')
        say('/kaisen reset | lock | scale <0.7-1.8> | idle <5-60> | move <x> <y>')
        say('/kaisen icons ffxi | classic | ffxiv')
        say('/kaisen report party|linkshell [1-18] | /kaisen report cancel')
    end
    save()
end)
