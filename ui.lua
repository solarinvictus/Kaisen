-- Kaisen UI. GPL-3.0-or-later.
local imgui=require('imgui')
local theme=require('theme')
local Engine=require('engine')
local Icons=require('jobicons')
local M={selected=nil,settings=false,confirm=false,preview=false,mode='current',position=true,size=true}
local gold={0.96,0.84,0.55,1}
local quiet={0.66,0.76,0.92,1}
local job_names={'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN'}
local job_colors={
    [1]={0.95,0.38,0.33,1},[2]={1,0.90,0.12,1},[3]={1,1,1,1},[4]={0.72,0.50,0.98,1},
    [5]={0.98,0.50,0.63,1},[6]={0.42,0.89,0.52,1},[7]={0.72,0.74,0.77,1},[8]={0,0,0,1},
    [9]={0.79,0.65,0.40,1},[10]={0.98,0.89,0.43,1},[11]={0.70,0.94,0.43,1},[12]={0.95,0.12,0.10,1},
    [13]={0.68,0.79,0.91,1},[14]={0.77,0.66,1,1},[15]={0.39,0.90,0.88,1},[16]={0.39,0.67,1,1},
    [17]={0.98,0.79,0.49,1},[18]={0.91,0.85,0.63,1},[19]={1,0.42,0.63,1},[20]={0.83,0.69,0.53,1},
    [21]={0.48,0.76,0.30,1},[22]={0.35,0.80,0.98,1}}
local function number(n)
    local s=tostring(math.floor(n+0.5))
    -- gsub returns text AND replacement count; return only text to callers.
    return (s:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))
end
local function percent(n) return n and ('%.1f%%'):format(n) or '--' end
local function tooltip(s)
    if imgui.IsItemHovered() then imgui.BeginTooltip();imgui.Text(s);imgui.EndTooltip() end
end
local function col(text,color,right,height)
    imgui.TableNextColumn()
    if right then
        local available=imgui.GetContentRegionAvail()
        local textWidth=imgui.CalcTextSize(text)
        imgui.SetCursorPosX(imgui.GetCursorPosX()+math.max(0,available-textWidth-2))
    end
    if height then
        imgui.SetCursorPosY(imgui.GetCursorPosY()+math.max(0,(height-imgui.GetTextLineHeight())/2))
    end
    if color then imgui.TextColored(color,text) else imgui.Text(text) end
end
local function control(label,active,width,scale)
    local modern=(IMGUI_VERSION_NUM or 0)>=19200
    if modern then imgui.PushFont(imgui.GetFont(),imgui.GetFontSize()*0.85)
    else imgui.SetWindowFontScale(scale*0.85) end
    imgui.PushStyleColor(ImGuiCol_Button,active and {0.18,0.32,0.56,1} or {0.12,0.23,0.48,1})
    imgui.PushStyleColor(ImGuiCol_Text,active and gold or quiet)
    local clicked=imgui.Button(label,{width*scale*0.85,26*scale*0.85})
    imgui.PopStyleColor(2)
    if modern then imgui.PopFont() else imgui.SetWindowFontScale(scale) end
    return clicked
end
local function packed(color,alpha,strength)
    return bit.bor(bit.lshift(alpha,24),bit.lshift(math.floor(color[3]*strength*255),16),
        bit.lshift(math.floor(color[2]*strength*255),8),math.floor(color[1]*strength*255)) % 4294967296
end
local function child(id,height)
    if (IMGUI_VERSION_NUM or 0)>=19000 then return imgui.BeginChild(id,{0,height},0,0) end
    return imgui.BeginChild(id,{0,height},false,0)
end
local function table_begin(id,columns,scale)
    if not imgui.BeginTable(id,#columns,bit.bor(ImGuiTableFlags_SizingStretchProp,ImGuiTableFlags_RowBg)) then return false end
    for _,v in ipairs(columns) do
        imgui.TableSetupColumn(v[1],v[2] and ImGuiTableColumnFlags_WidthFixed or ImGuiTableColumnFlags_WidthStretch,v[2] and v[2]*scale or 1)
    end
    imgui.PushStyleColor(ImGuiCol_Text,quiet)
    imgui.TableHeadersRow()
    imgui.PopStyleColor()
    return true
end
-- Smooth only the visual fill; live damage/DPS values remain immediate.
local barSegment,barTime,barValues=nil,nil,{}
local function animateBars(segment,rows,now)
    if barSegment~=segment then barSegment=segment;barTime=nil;barValues={} end
    local dt=barTime and math.max(0,now-barTime) or 0
    barTime=now
    local blend=1-math.exp(-dt/0.09)
    local nextValues={}
    local leader=rows[1] and rows[1].total or 0
    for _,actor in ipairs(rows) do
        local target=leader>0 and math.max(0,math.min(1,actor.total/leader)) or 0
        local previous=barValues[actor.id]
        local value=previous and previous+(target-previous)*blend or target
        if math.abs(value-target)<0.0005 then value=target end
        nextValues[actor.id]=value
    end
    barValues=nextValues
    return nextValues
end

-- Draw each combatant as one cell: a full-height bar, centered icon and name.
local function drawCombatant(actor,leader,theme,scale,color,animatedFraction)
    local x,y=imgui.GetCursorScreenPos()
    local availableWidth=imgui.GetContentRegionAvail()
    local width=math.max(1,availableWidth)
    local iconSize=18*scale
    local textHeight=imgui.GetTextLineHeight()
    local height=math.max(iconSize,textHeight)+6*scale
    local clicked=imgui.InvisibleButton('##combatant'..actor.id,{width,height})
    if clicked then M.selected=M.selected==actor.id and nil or actor.id end
    local hovered=imgui.IsItemHovered()
    tooltip(actor.name..' / '..(job_names[actor.job] or 'Unknown job'))
    local nextX,nextY=imgui.GetCursorScreenPos()
    local dl=imgui.GetWindowDrawList()
    dl:AddRectFilled({x,y},{x+width,y+height},0x3048200F,0)
    local fraction=animatedFraction or (leader>0 and math.max(0,math.min(1,actor.total/leader)) or 0)
    if fraction>0 then
        local left,right=packed(color,165,0.74),packed(color,90,0.48)
        dl:AddRectFilledMultiColor({x,y},{x+width*fraction,y+height},left,right,right,left)
        local accent=actor.job==8 and {0.46,0.48,0.52,1} or color
        dl:AddRectFilled({x,y},{x+2*scale,y+height},packed(accent,225,1),0)
    end
    if hovered then dl:AddRectFilled({x,y},{x+width,y+height},0x16FFFFFF,3) end
    if M.selected==actor.id then dl:AddRect({x,y},{x+width,y+height},0x90B8DCFA,3,0,1) end
    -- Draw the icon's native alpha directly over the damage bar.
    imgui.SetCursorScreenPos({x+3*scale,y+(height-iconSize)/2})
    local icon=Icons.get(actor.job,theme)
    if icon then
        imgui.Image(icon,{iconSize,iconSize},{0,0},{1,1},{1,1,1,1},{0,0,0,0})
    else
        imgui.SetCursorScreenPos({x+7*scale,y+(height-textHeight)/2})
        imgui.TextColored(quiet,'?')
    end
    imgui.SetCursorScreenPos({x+iconSize+7*scale,y+(height-textHeight)/2})
    imgui.TextColored({0.96,0.97,1,1},actor.name)
    imgui.SetCursorScreenPos({nextX,nextY})
    -- Register the restored position with ImGui before leaving this table cell.
    -- A cursor move alone cannot extend layout bounds in newer ImGui versions.
    imgui.Dummy({0,0})
end
local function details(actor,scale)
    imgui.Spacing()
    imgui.TextColored(gold,actor.name..' / DAMAGE BREAKDOWN')
    imgui.SameLine()
    if imgui.SmallButton('Close details') then M.selected=nil end
    imgui.Text(('Melee: %s  (%d hit / %d miss)   Crit: %s'):format(percent(Engine.accuracy(actor.melee)),actor.melee.hits,actor.melee.misses,percent(Engine.critical(actor.melee))))
    imgui.Text(('Ranged: %s  (%d hit / %d miss)'):format(percent(Engine.accuracy(actor.ranged)),actor.ranged.hits,actor.ranged.misses))
    imgui.TextColored(quiet,('Avoided: %d melee / %d ranged'):format(actor.melee.avoided,actor.ranged.avoided))
    imgui.TextColored(quiet,('Pet: %s   |   Skillchain: %s'):format(number(actor.pet),number(actor.skillchain)))
    local rows={};for _,v in pairs(actor.sources) do rows[#rows+1]=v end
    table.sort(rows,function(a,b) if a.total==b.total then return a.name<b.name end return a.total>b.total end)
    if child('source_scroll',195*scale) then
        if table_begin('sources',{{'Action / source'},{'Damage',67},{'Hits',30},{'Miss',30},{'Avg',45},{'Max',48}},scale) then
            for _,v in ipairs(rows) do
                imgui.TableNextRow()
                col(v.name);tooltip(('%s / %s | Crits: %d | Bursts: %d | Avoided: %d'):format(v.name,v.category,v.crits,v.bursts,v.avoided))
                col(number(v.total));col(tostring(v.hits));col(tostring(v.misses))
                col(v.hits>0 and number(v.total/v.hits) or '--');col(number(v.max))
            end
            imgui.EndTable()
        end
    end
    imgui.EndChild()
    imgui.TextColored(quiet,'Hits = outcomes; multi-hit WS hits are combined.')
end
local function demo()
    local e=Engine.new()
    for job,name in ipairs(job_names) do
        local owner={id=100+job,name=name,job=job}
        local total=24000-(job-1)*700
        for i=1,20 do e:record(owner,1,{name='Melee',category='Melee',key='melee',accuracy='melee',amount=total/20,result='hit',crit=i%5==0},i*2,'Training Crab') end
        e:record(owner,1,{name='Melee',category='Melee',key='melee',accuracy='melee',amount=0,result='miss'},40,'Training Crab')
    end
    e:finish();return e
end
local preview_engine,previewStarted
local function animatePreview(e,elapsed)
    local phase=math.floor(elapsed/1.4)%2
    if e.previewPhase==phase then return end
    e.previewPhase=phase
    local factor=phase==0 and 1 or 0.55
    for _,segment in ipairs({e.current,e.session}) do
        segment.total=0
        for _,actor in pairs(segment.actors) do
            local base=24000-(actor.job-1)*700
            actor.total=math.floor(base*(actor.job==1 and 1 or factor))
            segment.total=segment.total+actor.total
            for _,source in pairs(actor.sources) do
                source.total=actor.total
                source.max=actor.total/20
            end
        end
    end
end
function M.draw(engine,cfg,save,reset)
    if not cfg.visible then return end
    local scale=cfg.scale
    theme.push()
    local modern=(IMGUI_VERSION_NUM or 0)>=19200
    if modern then imgui.PushFont(imgui.GetFont(),imgui.GetFontSize()*scale) end
    if M.size or M.lastScale~=scale then
        imgui.SetNextWindowSize({(cfg.width or 520)*scale,(cfg.height or 340)*scale},ImGuiCond_Always)
        M.size=false;M.lastScale=scale
    end
    imgui.SetNextWindowSizeConstraints({440*scale,180*scale},{10000,10000})
    if M.position then imgui.SetNextWindowPos({cfg.x,cfg.y},ImGuiCond_Always);M.position=false end
    local flags=bit.bor(ImGuiWindowFlags_NoTitleBar,ImGuiWindowFlags_NoSavedSettings,ImGuiWindowFlags_NoFocusOnAppearing)
    if cfg.locked then flags=bit.bor(flags,ImGuiWindowFlags_NoMove,ImGuiWindowFlags_NoResize) end
    if imgui.Begin('Kaisen##parser',true,flags) then
        if not modern then imgui.SetWindowFontScale(scale) end
        theme.frame()
        imgui.TextColored(gold,'K A I S E N')
        imgui.SameLine();imgui.TextColored(quiet,M.preview and ' /  PREVIEW' or ' /  BATTLE PARSER')
        imgui.SameLine(math.max(0,imgui.GetWindowWidth()-88*scale))
        if imgui.SmallButton('Settings') then M.settings=not M.settings end
        imgui.Separator()
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing,{8*0.85,6*0.85})
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding,{8*0.85,5*0.85})
        if control('Current fight',M.mode=='current',116,scale) then M.mode='current';M.selected=nil end
        imgui.SameLine()
        if control('Session',M.mode=='session',96,scale) then M.mode='session';M.selected=nil end
        imgui.SameLine()
        if control(engine.paused and 'Resume' or 'Pause',engine.paused,88,scale) then engine:pause(not engine.paused) end
        imgui.SameLine()
        if control('Reset',M.confirm,72,scale) then M.confirm=not M.confirm end
        imgui.PopStyleVar(2)
        if M.confirm then
            imgui.TextColored(gold,'Clear fight and session data?')
            imgui.SameLine();if imgui.SmallButton('Clear') then reset();M.confirm=false;M.selected=nil end
            imgui.SameLine();if imgui.SmallButton('Cancel') then M.confirm=false end
        end
        if M.settings then
            local locked={cfg.locked}
            if imgui.Checkbox('Lock position / size',locked) then cfg.locked=locked[1];save() end
            imgui.SameLine()
            local preview={M.preview}
            if imgui.Checkbox('Preview',preview) then M.preview=preview[1];M.selected=nil end
            imgui.Text('Job icons:')
            for _,choice in ipairs({'FFXI','Classic','FFXIV-1'}) do
                imgui.SameLine()
                local label=cfg.icon_theme==choice and ('['..choice..']') or choice
                if imgui.SmallButton(label..'##icon_theme') then cfg.icon_theme=choice;save() end
            end
            local value={cfg.scale}
            if imgui.SliderFloat('Scale',value,0.7,1.8,'%.1f') then cfg.scale=value[1] end
            if imgui.IsItemDeactivatedAfterEdit() then save() end
            local timeout={cfg.timeout}
            if imgui.SliderInt('Idle timeout (s)',timeout,5,60) then cfg.timeout=timeout[1];engine.timeout=timeout[1] end
            if imgui.IsItemDeactivatedAfterEdit() then save() end
            imgui.TextColored(quiet,'Drag background to move; bottom-right corner to resize.')
            imgui.Separator()
        end
        local showing=engine
        if M.preview then
            if not previewStarted then preview_engine=demo();previewStarted=imgui.GetTime() end
            animatePreview(preview_engine,imgui.GetTime()-previewStarted)
            showing=preview_engine
        else
            previewStarted=nil
        end
        local segment=M.mode=='session' and showing.session or showing.current
        local seconds=showing:seconds(M.mode)
        local rows=Engine.rows(segment)
        local fills=animateBars(segment,rows,imgui.GetTime())
        imgui.Separator()
        local rowHeight=math.max(18*scale,imgui.GetTextLineHeight())+6*scale
        -- Adjacent combatants share an edge: no cell padding or item gap.
        imgui.PushStyleVar(ImGuiStyleVar_CellPadding,{4,0})
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing,{8,0})
        local _,availableHeight=imgui.GetContentRegionAvail()
        local reserve=32*scale+(#rows==0 and 24*scale or 0)
        if M.selected and segment.actors[M.selected] then reserve=reserve+340*scale end
        local rosterHeight=math.max(rowHeight+24*scale,availableHeight-reserve)
        if child('roster_scroll',rosterHeight) then
            if table_begin('damage',{{'COMBATANT'},{'DAMAGE',74},{'DPS',53},{'SHARE',48},{'M.ACC',50}},scale) then
                for _,a in ipairs(rows) do
                    imgui.TableNextRow(0,rowHeight);imgui.TableNextColumn()
                    local c=job_colors[a.job] or quiet
                    drawCombatant(a,rows[1].total,cfg.icon_theme,scale,c,fills[a.id])
                    col(number(a.total),{0.96,0.97,1,1},true,rowHeight)
                    col(seconds>0 and ('%.1f'):format(a.total/seconds) or '0.0',gold,true,rowHeight)
                    col(percent(segment.total>0 and 100*a.total/segment.total or 0),quiet,true,rowHeight)
                    col(percent(Engine.accuracy(a.melee)),quiet,true,rowHeight)
                end
                imgui.EndTable()
            end
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        if #rows==0 then imgui.TextColored(quiet,'Attack a monster, or enable Preview in Settings.') end
        if M.selected and segment.actors[M.selected] then details(segment.actors[M.selected],scale) end
        imgui.Separator()
        imgui.TextColored(quiet,'Click a combatant to inspect damage')
        tooltip('M.Acc = melee hits / (hits + misses). Excludes WS, spells, pet attacks and special avoidance.')
        local x,y=imgui.GetWindowPos()
        local w,h=imgui.GetWindowSize()
        if not cfg.locked then
            local dl=imgui.GetWindowDrawList()
            dl:AddLine({x+w-13,y+h-5},{x+w-5,y+h-13},0xFFB8A48D,1)
            dl:AddLine({x+w-8,y+h-5},{x+w-5,y+h-8},0xFFB8A48D,1)
        end
        if math.abs(w/scale-(cfg.width or 520))>0.5 or math.abs(h/scale-(cfg.height or 340))>0.5 then
            cfg.width=w/scale;cfg.height=h/scale;M.moved=true
        end
        if x~=cfg.x or y~=cfg.y then cfg.x=x;cfg.y=y;M.moved=true end
        if M.moved and not imgui.IsMouseDown(0) then save();M.moved=false end
    end
    imgui.End()
    if modern then imgui.PopFont() end
    theme.pop()
end
return M
