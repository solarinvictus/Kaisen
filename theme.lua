-- Kaisen FFXI-inspired theme, based on the Renkei UI. GPL-3.0-or-later.
local imgui = require('imgui');
local M = {};
local gold = {0.95, 0.84, 0.57, 1};
local muted = {0.66, 0.75, 0.90, 1};

function M.push()
    local colors = {
        {ImGuiCol_WindowBg, {0.025, 0.055, 0.22, 0.97}},
        {ImGuiCol_Border, {0.70, 0.77, 0.91, 1}},
        {ImGuiCol_Text, {0.94, 0.96, 1, 1}},
        {ImGuiCol_Separator, {0.48, 0.59, 0.81, 0.70}},
        {ImGuiCol_FrameBg, {0.015, 0.028, 0.10, 1}},
        {ImGuiCol_TitleBg, {0.06, 0.12, 0.34, 1}},
        {ImGuiCol_TitleBgActive, {0.10, 0.20, 0.47, 1}},
        {ImGuiCol_Button, {0.12, 0.23, 0.48, 1}},
        {ImGuiCol_ButtonHovered, {0.22, 0.39, 0.67, 1}},
        {ImGuiCol_ButtonActive, {0.18, 0.32, 0.56, 1}},
        {ImGuiCol_CheckMark, gold},
        {ImGuiCol_SliderGrab, gold},
        {ImGuiCol_ChildBg, {0, 0, 0, 0}},
        {ImGuiCol_TableHeaderBg, {0.06, 0.12, 0.34, 0.35}},
        {ImGuiCol_TableRowBg, {0, 0, 0, 0}},
        {ImGuiCol_TableRowBgAlt, {0.12, 0.23, 0.48, 0.14}},
        {ImGuiCol_ScrollbarBg, {0.02, 0.03, 0.07, 0.50}},
        {ImGuiCol_ScrollbarGrab, {0.29, 0.37, 0.51, 0.75}},
        {ImGuiCol_ScrollbarGrabHovered, {0.41, 0.51, 0.67, 0.9}},
        {ImGuiCol_ScrollbarGrabActive, {0.51, 0.61, 0.77, 1}},
    };
    for _, v in ipairs(colors) do imgui.PushStyleColor(v[1], v[2]); end
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6);
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 2);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {16, 12});
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {8, 6});
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 3);
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, {8, 5});
    imgui.PushStyleVar(ImGuiStyleVar_CellPadding, {4, 3});
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, 8);
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarRounding, 4);
end

function M.pop()
    imgui.PopStyleVar(9);
    imgui.PopStyleColor(20);
end

function M.frame()
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();
    local dl = imgui.GetWindowDrawList();
    -- ImGui packed colors use AABBGGRR. Draw before content, inside the border.
    dl:AddRectFilledMultiColor({x+4,y+4}, {x+w-4,y+h-4},
        0xFA6B3516, 0xFA55250C, 0xFA220A03, 0xFA300E04);
    dl:AddRect({x+4,y+4}, {x+w-4,y+h-4}, 0xFF8D7561, 3, 0, 1);
end

return M
