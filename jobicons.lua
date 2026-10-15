-- Job artwork and D3D loading conventions from XIUI (tirem/XIUI).
-- See NOTICE.md and assets/jobs/*/credits.txt. GPL-3.0-or-later.
local imgui=require('imgui')
local ffi=require('ffi')
local ok,d3d=pcall(require,'d3d8')
local M={}
local jobs={'war','mnk','whm','blm','rdm','thf','pld','drk','bst','brd','rng','sam','nin','drg','smn','blu','cor','pup','dnc','sch','geo','run'}
local themes={ffxi='FFXI',classic='Classic',ffxiv='FFXIV-1',['ffxiv-1']='FFXIV-1'}
local cache,retry={},{}
local warned=false
function M.normalize(theme) return themes[tostring(theme or ''):lower()] or 'FFXI' end
local function load(job,theme)
    if not ok then return nil end
    local device=d3d.get_device()
    if device==nil then return nil end
    local texture=ffi.new('IDirect3DTexture8*[1]')
    local path=addon.path..'/assets/jobs/'..theme..'/'..jobs[job]..'.png'
    local result=ffi.C.D3DXCreateTextureFromFileA(device,path,texture)
    if result~=0 or texture[0]==nil then return nil end
    return d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*',texture[0]))
end
function M.get(job,theme)
    if not jobs[job] then return nil end
    theme=M.normalize(theme)
    local key=theme..':'..job
    if cache[key] then return tonumber(ffi.cast('uint32_t',cache[key])) end
    local now=imgui.GetTime()
    if retry[key] and now<retry[key] then return nil end
    local success,texture=pcall(load,job,theme)
    if success and texture then
        -- Keep COM references for all loaded sets until addon unload. Never release
        -- a texture while ImGui may still have it queued in a draw list.
        cache[key]=texture
        retry[key]=nil
        return tonumber(ffi.cast('uint32_t',texture))
    end
    retry[key]=now+5
    if not warned then
        print('[Kaisen] Job icon unavailable; using job text. Check that the assets folder was extracted.')
        warned=true
    end
    return nil
end
function M.draw(job,theme,size)
    local pointer=M.get(job,theme)
    if pointer then
        imgui.Image(pointer,{size,size},{0,0},{1,1},{1,1,1,1},{0,0,0,0})
    else
        imgui.TextColored({0.66,0.76,0.92,1},jobs[job] and jobs[job]:upper() or '?')
    end
end
return M
