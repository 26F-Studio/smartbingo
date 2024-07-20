--------------------------------------------------------------
-- Smart Bingo
-- Game by MrZ, 26F-Studio
-- Original idea from an image of QQ grounp, it has no credit
--------------------------------------------------------------

require 'Zenitha'

SCR.setSize(500, 1000)

ZENITHA.setMaxFPS(100)
ZENITHA.setUpdateFreq(100)
ZENITHA.setDrawFreq(26)
ZENITHA.setVersionText('')
ZENITHA.globalEvent.drawCursor = NULL

LANG.add {
    zh = 'lang_zh.lua',
    en = 'lang_en.lua',
}
LANG.setDefault('zh')

local DATA = {
    zh = true,
    sound = true,

    win = 0,
    passDate = false,
    tickMat = {},
    maxTick = false,
    minTick = false,
}
for i = 1, 5 do DATA.tickMat[i] = TABLE.new(0, 5) end
local suc, res = pcall(FILE.load, 'data.json', '-json')
if suc then TABLE.update(DATA, res) end

BGM.load('naive', 'naive.ogg')
TASK.new(function()
    DEBUG.yieldT(0.626)
    if DATA.sound then
        BGM.play('naive')
    end
end)

SFX.load('tick', 'tick.ogg')
SFX.load('untick', 'untick.ogg')
SFX.load('solve', 'solve.ogg')

FONT.load('unifont', 'unifont.otf')
FONT.setDefaultFont('unifont')

BG.set('color')
BG.send('color', COLOR.HEX 'EDEDED')





local rnd = math.random
local ins, rem = table.insert, table.remove
local gc = love.graphics

local ruleColor = {
    COLOR.R,
    COLOR.B,
    { 0,  0,  0 },
    COLOR.G,
    { .9, .7, 0 },
    COLOR.O,
    COLOR.V,
    COLOR.lR,
    COLOR.C,
}
local cellColor = {
    [false] = { COLOR.HEX 'EDEDED' },
    { 1,  0, .26 },
    COLOR.B,
    COLOR.D,
    COLOR.G,
    { .9, 1, 0 },
    COLOR.O,
    { .8, 0,   1 },
    { 1,  .62, .82 },
    { 0,  .8,  .8 },
}
local cellColorHard = TABLE.copyAll(cellColor)
for _, v in next, cellColorHard do
    v[1] = v[1] * .7023
    v[2] = v[2] * .7023
    v[3] = v[3] * .7023
end
local board = {
    X = 20,
    Y = 50,
    W = 460,
    H = 800,
    titleW = 226,
    infoH = 300,
    CW = 92,
    CH = 100,
}

local titleColor = { 0, 0, 0 }
-- local debugColor
local dailyMode ---@type boolean only save on today
local date = os.date('!%y%m%d')
local correct
local saveTimer
local activeRules = {}
local ruleMat = {}
local activeRuleTexts = {}
local targetText = gc.newText(FONT.get(15))
local versionText = gc.newText(FONT.get(20))
versionText:set(require 'version'.string)

local egg = {
    AD_BC = false,
    back_to_future = false,
    bingo_clicker = 0,
    bingo_target = 1,
}

local function freshRuleText()
    activeRuleTexts = {}
    for i = 1, #activeRules do
        activeRuleTexts[i] = gc.newText(FONT.get(20))
        activeRuleTexts[i]:setf(Text.rules[activeRules[i]], board.W - board.titleW - 10, 'left')
    end
    targetText:setf(Text.target, board.W - board.titleW - 10, 'left')
end

local function setLang(zh)
    local l = zh and 'zh' or 'en'
    Text = LANG.set(l)
    freshRuleText()
    WIDGET._reset()
end

local function safeGet(t, x, y)
    if t[y] then return t[y][x] end
    return 0
end
local function checkLine()
    for y = 1, 5 do
        if TABLE.count(DATA.tickMat[y], 1) == 5 then
            return true
        end
    end
    for x = 1, 5 do
        local count = 0
        for y = 1, 5 do
            if DATA.tickMat[y][x] == 1 then count = count + 1 end
        end
        if count == 5 then
            return true
        end
    end
    local count1, count2 = 0, 0
    for i = 1, 5 do
        if DATA.tickMat[i][i] == 1 then count1 = count1 + 1 end
        if DATA.tickMat[i][6 - i] == 1 then count2 = count2 + 1 end
    end
    return count1 == 5 or count2 == 5
end
local function checkCell(rule, tickMat, x, y)
    if rule == 1 or rule == 2 or rule == 6 or rule == 7 then
        local count = 0
        for _x = x - 1, x + 1 do
            for _y = y - 1, y + 1 do
                if (_x ~= x or _y ~= y) and safeGet(tickMat, _x, _y) == 1 then count = count + 1 end
            end
        end
        if rule == 1 then
            return count >= 1
        elseif rule == 2 then
            return count <= 2
        elseif rule == 6 then
            return count % 2 == 0
        elseif rule == 7 then
            return count % 2 == 1
        end
    elseif rule == 3 then
        return tickMat[y][x] == 1
    elseif rule == 4 then
        local xCount, yCount = 0, 0
        for _x = 1, 5 do if tickMat[y][_x] == 1 then yCount = yCount + 1 end end
        for _y = 1, 5 do if tickMat[_y][x] == 1 then xCount = xCount + 1 end end
        return xCount == yCount
    elseif rule == 5 then
        local count1, count2 = 0, 0
        for d = -4, 4 do if safeGet(tickMat, x + d, y + d) == 1 then count1 = count1 + 1 end end
        for d = -4, 4 do if safeGet(tickMat, x + d, y - d) == 1 then count2 = count2 + 1 end end
        return count1 == count2
    elseif rule == 8 then
        return
            tickMat[y][x] ~= 1 or (
                safeGet(tickMat, x - 1, y) ~= 1 and
                safeGet(tickMat, x + 1, y) ~= 1 and
                safeGet(tickMat, x, y - 1) ~= 1 and
                safeGet(tickMat, x, y + 1) ~= 1
            )
    elseif rule == 9 then
        return
            tickMat[y][x] ~= 1 or (
                safeGet(tickMat, x - 1, y) == 1 or
                safeGet(tickMat, x + 1, y) == 1 or
                safeGet(tickMat, x, y - 1) == 1 or
                safeGet(tickMat, x, y + 1) == 1
            )
    end
end
local function checkAnswer()
    correct = false

    -- Find Line

    if not checkLine() then return end

    -- Check Rules
    for y = 1, 5 do
        for x = 1, 5 do
            if ruleMat[y][x] and not checkCell(ruleMat[y][x], DATA.tickMat, x, y) then
                return
            end
        end
    end

    correct = true

    -- Count ticks
    local count = 0
    for y = 1, 5 do
        count = count + TABLE.count(DATA.tickMat[y], 1)
    end

    -- Win
    local needSave
    if DATA.passDate ~= date then
        if dailyMode then
            DATA.win = DATA.win + 1
            MSG.new('check', Text.winDaily, 2.6)
        else
            MSG.new('check', Text.winAny, 2.6)
        end
        DATA.passDate = date
        needSave = true
        DATA.maxTick = count
        DATA.minTick = count
    end
    if count > (DATA.maxTick or 0) then
        DATA.maxTick = count
        MSG.new('check', Text.winMax, 2.6)
        needSave = true
    end
    if count < (DATA.minTick or 6e26) then
        DATA.minTick = count
        MSG.new('check', Text.winMin, 2.6)
        needSave = true
    end
    if needSave then
        SFX.play('solve')
        saveTimer = 0
    end
end
local function dumpGrid(t)
    local n = 0
    for y = 1, 5 do
        for x = 1, 5 do
            if t[y][x] == 1 then
                n = n + 2 ^ (5 * (y - 1) + x - 1)
            end
        end
    end
    return n
end
local gridConst = {
    left = dumpGrid {
        { 0, 0, 1, 0, 0 },
        { 0, 1, 0, 0, 0 },
        { 1, 1, 1, 1, 1 },
        { 0, 1, 0, 0, 0 },
        { 0, 0, 1, 0, 0 },
    },
    right = dumpGrid {
        { 0, 0, 1, 0, 0 },
        { 0, 0, 0, 1, 0 },
        { 1, 1, 1, 1, 1 },
        { 0, 0, 0, 1, 0 },
        { 0, 0, 1, 0, 0 },
    },
    N = dumpGrid {
        { 1, 0, 0, 0, 1 },
        { 1, 1, 0, 0, 1 },
        { 1, 0, 1, 0, 1 },
        { 1, 0, 0, 1, 1 },
        { 1, 0, 0, 0, 1 },
    },
    R = {
        dumpGrid {
            { 1, 1, 1, 1, 0 },
            { 1, 0, 0, 0, 1 },
            { 1, 1, 1, 1, 0 },
            { 1, 0, 0, 0, 1 },
            { 1, 0, 0, 0, 1 },
        },
        dumpGrid {
            { 1, 1, 1, 1, 0 },
            { 1, 0, 0, 0, 1 },
            { 1, 1, 1, 1, 0 },
            { 1, 0, 0, 1, 0 },
            { 1, 0, 0, 0, 1 },
        },
        dumpGrid {
            { 1, 1, 1, 1, 1 },
            { 1, 0, 0, 0, 1 },
            { 1, 1, 1, 1, 1 },
            { 1, 0, 0, 1, 0 },
            { 1, 0, 0, 0, 1 },
        },
        dumpGrid {
            { 1, 1, 1, 0, 0 },
            { 1, 0, 0, 1, 0 },
            { 1, 1, 1, 0, 0 },
            { 1, 0, 0, 1, 0 },
            { 1, 0, 0, 1, 0 },
        },
        dumpGrid {
            { 0, 1, 1, 1, 0 },
            { 0, 1, 0, 0, 1 },
            { 0, 1, 1, 1, 0 },
            { 0, 1, 0, 0, 1 },
            { 0, 1, 0, 0, 1 },
        },
    },
    up = dumpGrid {
        { 0, 0, 1, 0, 0 },
        { 0, 1, 1, 1, 0 },
        { 1, 0, 1, 0, 1 },
        { 0, 0, 1, 0, 0 },
        { 0, 0, 1, 0, 0 },
    },
    down = dumpGrid {
        { 0, 0, 1, 0, 0 },
        { 0, 0, 1, 0, 0 },
        { 1, 0, 1, 0, 1 },
        { 0, 1, 1, 1, 0 },
        { 0, 0, 1, 0, 0 },
    },
    Z = dumpGrid {
        { 1, 1, 1, 1, 1 },
        { 0, 0, 0, 1, 0 },
        { 0, 0, 1, 0, 0 },
        { 0, 1, 0, 0, 0 },
        { 1, 1, 1, 1, 1 },
    },
    T = dumpGrid {
        { 1, 1, 1, 1, 1 },
        { 0, 0, 1, 0, 0 },
        { 0, 0, 1, 0, 0 },
        { 0, 0, 1, 0, 0 },
        { 0, 0, 1, 0, 0 },
        { 0, 0, 1, 0, 0 },
    },
    full = dumpGrid {
        { 1, 1, 1, 1, 1 },
        { 1, 1, 1, 1, 1 },
        { 1, 1, 1, 1, 1 },
        { 1, 1, 1, 1, 1 },
        { 1, 1, 1, 1, 1 },
        { 1, 1, 1, 1, 1 },
    },
}
local function selectDate(option)
    if option == 'prev' then
        local y, m, d = date:match('(%d%d)(%d%d)(%d%d)')
        d = d - 1
        if d == 0 then d, m = 31, m - 1 end
        if m == 0 then m, y = 12, y - 1 end
        if y == -1 then
            y = 99
            if not egg.AD_BC then
                MSG.new('check', "We can travel to AD, to BC", 4.2)
                egg.AD_BC = true
            end
        end
        SCN.swapTo('main', 'swipeR', ('%02d%02d%02d'):format(y, m, d))
    elseif option == 'next' then
        local y, m, d = date:match('(%d%d)(%d%d)(%d%d)')
        d = d + 1
        if d == 32 then d, m = 1, m + 1 end
        if m == 13 then m, y = 1, y + 1 end
        if y == 100 then
            y = 0
            if not egg.AD_BC then
                MSG.new('check', "We can travel to AD, to BC", 4.2)
                egg.AD_BC = true
            end
        end
        if ('%02d%02d%02d'):format(y, m, d) <= os.date('!%y%m%d') then
            SCN.swapTo('main', 'swipeL', ('%02d%02d%02d'):format(y, m, d))
        else
            if not egg.back_to_future then
                MSG.new('check', "Back To The Future", 4.2)
                egg.back_to_future = true
            end
        end
    elseif option == 'now' then
        SCN.swapTo('main', 'swipeD', os.date('!%y%m%d'))
    elseif option == 'random' then
        math.randomseed(math.floor(os.time() + love.timer.getTime() * 100))
        local y
        repeat
            y = rnd(0, 99)
        until not MATH.between(y, 24, 35.5)
        local m, d = rnd(12), rnd(31)
        SCN.swapTo('main', 'fade', ('%02d%02d%02d'):format(y, m, d))
    end
end

local function showText(text)
    for textDX = -4, 4, 8 do
        for textDY = -4, 4, 8 do
            TEXT:add {
                text = text,
                x = 250 + textDX,
                y = 580 + textDY,
                k = 4,
                fontSize = 65,
                color = 'D',
                duration = 2.6,
                style = 'score',
                inPoint = .026,
                outPoint = .042,
            }
        end
    end
    TEXT:add {
        text = text,
        x = 250,
        y = 580,
        k = 4,
        fontSize = 65,
        color = 'L',
        duration = 2.6,
        style = 'score',
        inPoint = .026,
        outPoint = .042,
    }
end
local function triggerHint()
    TEXT:clear()

    -- Check Rules
    local fault
    for cy = 1, 5 do
        for cx = 1, 5 do
            if ruleMat[cy][cx] and not checkCell(ruleMat[cy][cx], DATA.tickMat, cx, cy) then
                fault = true
                SYSFX.rect(.4, board.X + (cx - 1) * board.CW + 6, board.Y + board.infoH + (cy - 1) * board.CH + 6,
                    board.CW - 12,
                    board.CH - 12, 0, hardMode and .942 or 1, hardMode and .942 or 1, 1.626)
            end
        end
    end
    if fault then return end

    -- Check line
    if checkLine() then return end
    TWEEN.new():setOnRepeat(function(n)
        local x0, y0 = board.X, board.Y + board.infoH
        local dx, dy = board.CW, board.CH
        if n <= 5 then
            SYSFX.line(.4, x0 + dx * .2, y0 + dy * (n - .5), x0 + dx * 4.8, y0 + dy * (n - .5), 26, 0, 0, 0, .626)
            SYSFX.line(.42, x0 + dx * .2 + 3, y0 + dy * (n - .5), x0 + dx * 4.8 - 3, y0 + dy * (n - .5), 20)
        elseif n <= 10 then
            n = n - 5
            SYSFX.line(.4, x0 + dx * (n - .5), y0 + dy * .2, x0 + dx * (n - .5), y0 + dy * 4.8, 26, 0, 0, 0, .626)
            SYSFX.line(.42, x0 + dx * (n - .5), y0 + dy * .2 + 3, x0 + dx * (n - .5), y0 + dy * 4.8 - 3, 20)
        elseif n == 11 then
            SYSFX.line(.4, x0 + dx * .2, y0 + dy * .2, x0 + dx * 4.8, y0 + dy * 4.8, 26, 0, 0, 0, .626)
            SYSFX.line(.42, x0 + dx * .2 + 2, y0 + dy * .2 + 2, x0 + dx * 4.8 - 2, y0 + dy * 4.8 - 2, 20)
        elseif n == 12 then
            SYSFX.line(.4, x0 + dx * 4.8, y0 + dy * .2, x0 + dx * .2, y0 + dy * 4.8, 26, 0, 0, 0, .626)
            SYSFX.line(.42, x0 + dx * 4.8 - 2, y0 + dy * .2 + 2, x0 + dx * .2 + 2, y0 + dy * 4.8 - 2, 20)
        elseif n == 13 then
            showText("?")
        end
        SFX.play(n < 13 and 'untick' or 'tick', .42)
    end):setDuration(0.0626):setLoop('repeat', 14):setUnique('hint_noLine'):run()
end

---@type Zenitha.Scene
local scene = {}

local function seed(n)
    math.randomseed(date + 0)
    for _ = 1, n do rnd() end
end
function scene.load()
    if SCN.args[1] then
        date = SCN.args[1]
    end
    -- Check new day
    dailyMode = not hardMode and date == os.date('!%y%m%d')
    if dailyMode then
        if DATA.passDate ~= date then
            DATA.passDate = false
            DATA.maxTick = false
            DATA.minTick = false
            for i = 1, 5 do
                DATA.tickMat[i] = TABLE.new(0, 5)
            end
        end
    else
        DATA.passDate = false
        DATA.maxTick = false
        DATA.minTick = false
    end

    -- Rules
    seed(26)
    if hardMode then
        activeRules = { 1, 4, 5, 6, 7 }
        ins(activeRules, ({ 2, 8, 9 })[rnd(3)])
    else
        activeRules = { 1, 2, 3, 4 }
        local extraRules = { 5, 6, 7, 8, 9 }
        for _ = 1, MATH.randFreq { 60, 30, 10 } do
            ins(activeRules, rem(extraRules, rnd(1, #extraRules)))
        end
        if #activeRules >= 7 then
            rem(activeRules, ({ 1, 2, 4 })[rnd(3)])
        end
    end
    table.sort(activeRules)

    -- Tick matrix
    seed(35.5)
    local tickMat = {}
    for i = 1, 5 do tickMat[i] = TABLE.new(0, 5) end
    local lineNo = rnd(1, 12) -- Target Line
    if lineNo <= 5 then
        for i = 1, 5 do tickMat[lineNo][i] = 1 end
    elseif lineNo <= 10 then
        for i = 1, 5 do tickMat[i][lineNo - 5] = 1 end
    elseif lineNo == 11 then
        for i = 1, 5 do tickMat[i][i] = 1 end
    elseif lineNo == 12 then
        for i = 1, 5 do tickMat[i][6 - i] = 1 end
    end
    for _ = 1, rnd(3, 6) do -- Random
        local rx, ry
        repeat
            rx, ry = rnd(1, 5), rnd(1, 5)
        until tickMat[ry][rx] == 0
        tickMat[ry][rx] = 1
    end
    -- for y=1,5 do
    --     local s=""
    --     for x=1,5 do
    --         s=s..(tickMat[y][x] and "O " or ". ")
    --     end
    --     print(s)
    -- end
    -- DATA.tickMat = tickMat

    local ruleCount = TABLE.new(0, 9)
    local pbMat = {}
    for i = 1, 5 do pbMat[i] = TABLE.new({}, 5) end
    for y = 1, 5 do
        for x = 1, 5 do
            pbMat[y][x] = {}
            for r = 1, #activeRules do
                local rule = activeRules[r]
                if checkCell(rule, tickMat, x, y) then
                    ins(pbMat[y][x], rule)
                    ruleCount[rule] = ruleCount[rule] + 1
                end
            end
            -- printf("(%d,%d):%s", x, y, table.concat(pbMat[y][x], ' '))
        end
    end

    -- Remove useless rule
    for i = 1, #ruleCount do
        if ruleCount[i] == 0 then
            TABLE.delete(activeRules, i)
        end
    end
    freshRuleText()
    local existRule = {}
    for i = 1, #ruleCount do
        if ruleCount[i] > 0 then
            ins(existRule, i)
        end
    end

    -- Color
    seed(42)
    ruleMat = {}
    for i = 1, 5 do ruleMat[i] = TABLE.new(false, 5) end
    -- for y = 1, 5 do
    --     for x = 1, 5 do
    --         ruleMat[y][x] = pbMat[y][x]
    --     end
    -- end
    for i = 1, hardMode and rnd(20, 26) or rnd(8, 15) do
        local rule = existRule[i % #existRule + 1]
        local pbBlankCells = {}
        local pbCells = {}
        for y = 1, 5 do
            for x = 1, 5 do
                if pbMat[y][x] and TABLE.find(pbMat[y][x], rule) then
                    ins(pbCells, { x, y })
                    if not ruleMat[y][x] then
                        ins(pbBlankCells, { x, y })
                    end
                end
            end
        end
        local targetCell
        if #pbBlankCells > 0 then
            targetCell = pbBlankCells[rnd(#pbBlankCells)]
        else
            targetCell = pbCells[rnd(#pbCells)]
        end
        if targetCell then
            ruleMat[targetCell[2]][targetCell[1]] = rule
        end
    end

    checkAnswer()
    if DATA.sound and not hardMode then
        BGM.set('naive', 'pitch', 1, 0)
    end
    if hardMode then
        BG.send('color', COLOR.HEX '444040')
    else
        BG.send('color', COLOR.HEX 'EDEDED')
    end
end

function scene.keyDown(k, rep)
    if rep then return end
    -- if tonumber(k) then debugColor = tonumber(k) end
    if k == 'escape' then
        saveTimer = 0
        ZENITHA._quit('fade')
    elseif k == 'backspace' or k == 'delete' then
        for y = 1, 5 do
            for x = 1, 5 do
                DATA.tickMat[y][x] = 0
            end
        end
    elseif k == 'h' then
        triggerHint()
    end
    return true
end

local function getBoardPos(x, y)
    local cx = math.floor((x - board.X) / board.CW + 1)
    local cy = math.floor((y - (board.Y + board.infoH)) / board.CH + 1)
    return MATH.clamp(cx, 1, 5), MATH.clamp(cy, 1, 5)
end

local holdTimer
local dragging
local dragStart
function scene.mouseDown(x, y, k)
    if MATH.between(x, board.X, board.X + board.titleW) and MATH.between(y, board.Y, board.Y + board.infoH) then
        local origColor
        repeat
            origColor = ruleColor[activeRules[rnd(#activeRules)]]
        until origColor[1] ~= 0
        titleColor = TABLE.copy(origColor)
        TWEEN.new(function(t)
            titleColor[1] = MATH.lerp(origColor[1], 0, t)
            titleColor[2] = MATH.lerp(origColor[2], 0, t)
            titleColor[3] = MATH.lerp(origColor[3], 0, t)
        end):setDuration(0.26):setUnique('titleColorTransition'):run()

        local pattern = dumpGrid(DATA.tickMat)
        if pattern == gridConst.left then
            selectDate('prev')
        elseif pattern == gridConst.right then
            selectDate('next')
        elseif pattern == gridConst.N then
            selectDate('now')
        elseif TABLE.find(gridConst.R, pattern) then
            selectDate('random')
        elseif pattern == gridConst.up then
            local y0 = board.Y
            TWEEN.new(function(t)
                board.Y = y0 - 12 * t
            end):setEase('Linear'):setDuration(0.26):setUnique('egg_moveUp'):run()
        elseif pattern == gridConst.down then
            local y0 = board.Y
            TWEEN.new(function(t)
                board.Y = y0 + 12 * t
            end):setEase('Linear'):setDuration(0.26):setUnique('egg_moveDown'):run()
        elseif pattern == gridConst.T then
            MSG.new('check', "Techmino is fun!", 4.2)
        elseif pattern == gridConst.Z then
            MSG.new('check', "By MrZ", 4.2)
        elseif pattern == gridConst.full then
            hardMode = not hardMode
            if hardMode then
                if DATA.sound then
                    BGM.set('naive', 'pitch', 0.626, 0)
                end
                MSG.new('warn', Text.hardMode, 2.6)
            else
                MSG.new('info', Text.easyMode, 2.6)
            end
            SCN.swapTo('main', 'flash', date)
        else
            egg.bingo_clicker = egg.bingo_clicker + 1
            if egg.bingo_clicker == 10 * egg.bingo_target then
                egg.bingo_target = egg.bingo_target + 1
                MSG.new('check', "[username]'s Bingo Card\n" .. egg.bingo_clicker .. " bingos\n ", 2.6)
            end
        end
    elseif MATH.between(x, board.X + board.titleW, board.X + board.W) and MATH.between(y, board.Y, board.Y + board.infoH) then
        triggerHint()
    else
        if k == 1 then
            holdTimer = 0
            dragging = {}
            scene.mouseMove(x, y)
        elseif k == 2 then
            if dragging then
                for xy in next, dragging do
                    local cx, cy = xy:match('(%d)(%d)')
                    cx, cy = tonumber(cx), tonumber(cy)
                    DATA.tickMat[cy][cx] = dragStart
                end
            elseif MATH.between(x, board.X, board.X + board.W) and MATH.between(y, board.Y + board.infoH, board.Y + board.H) then
                local cx, cy = getBoardPos(x, y)
                DATA.tickMat[cy][cx] = DATA.tickMat[cy][cx] == 0 and 2 or 0
            end
        end
    end
end

function scene.mouseMove(x, y)
    if dragging and MATH.between(x, board.X, board.X + board.W) and MATH.between(y, board.Y + board.infoH, board.Y + board.H) then
        local cx, cy = getBoardPos(x, y)
        if not dragStart and DATA.tickMat[cy][cx] == 2 then
            dragStart = 2
            dragging[cx .. cy] = true
        elseif not dragging[cx .. cy] and dragStart ~= 2 and (dragStart == nil or dragStart == DATA.tickMat[cy][cx]) then
            if not dragStart then
                dragStart = DATA.tickMat[cy][cx]
            else
                holdTimer = false
            end
            dragging[cx .. cy] = true
            DATA.tickMat[cy][cx] = 1 - DATA.tickMat[cy][cx]
            if DATA.sound then
                SFX.play(DATA.tickMat[cy][cx] == 1 and 'tick' or 'untick')
            end
        end
    end
end

function scene.mouseUp(_, _, k)
    if k == 1 then
        holdTimer = nil
        dragging = nil
        dragStart = nil
        checkAnswer()
    end
    saveTimer = 2.6
end

local firstTouchID
function scene.touchDown(x, y, id)
    if not firstTouchID then
        firstTouchID = id
        scene.mouseDown(x, y, 1)
    end
end

function scene.touchMove(x, y, _, _, id)
    if id == firstTouchID then
        scene.mouseMove(x, y)
    end
end

function scene.touchUp(x, y, id)
    if id == firstTouchID then
        scene.mouseUp(x, y, 1)
        firstTouchID = nil
    end
end

function scene.update(dt)
    if holdTimer then
        holdTimer = holdTimer + dt
        if holdTimer > 0.442 then
            if next(dragging) then
                local cx, cy = next(dragging):match('(%d)(%d)')
                cx, cy = tonumber(cx), tonumber(cy)
                scene.mouseUp(0, 0, 1)
                DATA.tickMat[cy][cx] = DATA.tickMat[cy][cx] ~= 2 and 2 or 0
            end
        end
    end
    if saveTimer then
        saveTimer = saveTimer - dt
        if saveTimer <= 0 then
            if dailyMode then
                pcall(FILE.save, DATA, 'data.json', '-json')
            end
            saveTimer = nil
        end
    end
end

local tick = GC.load { 62, 62,
    { 'move',  4,      4 },
    { 'setLW', 10 },
    { 'setCL', 0,      0,  0 },
    { 'line',  0,      26, 26, 48, 52, 0 },
    { 'setLW', 4 },
    { 'setCL', COLOR.L },
    { 'line',  2,      28, 26, 48, 50, 3 },
}
local cross = GC.load { 62, 62,
    { 'move',  4,   4 },
    { 'setLW', 8 },
    { 'setCL', 0,   0,   0 },
    { 'line',  0,   0,   52, 52 },
    { 'line',  0,   52,  52, 0 },
    { 'setLW', 4 },
    { 'setCL', .62, .62, .62 },
    { 'line',  2,   2,   50, 50 },
    { 'line',  2,   50,  50, 2 },
}
function scene.draw()
    gc.translate(board.X, board.Y)

    -- Board & Separator
    gc.setColor(hardMode and COLOR.R or COLOR.D)
    gc.setLineWidth(4)
    gc.rectangle('line', 0, 0, board.W, board.H)
    gc.line(board.titleW, 0, board.titleW, board.infoH)
    gc.line(0, board.infoH, board.W, board.infoH)
    gc.setLineWidth(2)
    gc.rectangle('line', board.W - 7, 8, -73, 32)
    FONT.set(25)
    GC.mStr(Text.check, board.W - 42, 12)

    -- Title
    FONT.set(65)
    gc.setColor(titleColor)
    GC.mStr(Text.title1, board.titleW / 2, 60)
    GC.mStr(Text.title2, board.titleW / 2, 170)
    FONT.set(20)
    gc.setColor(correct and COLOR.G or COLOR.D)
    gc.print(date, 10, board.infoH - 30)
    if DATA.passDate then
        gc.setColor(hardMode and COLOR.R or dailyMode and COLOR.G or COLOR.O)
        gc.print(Text.pass:format(DATA.minTick, DATA.maxTick), 80, board.infoH - 30)
    end
    if DATA.win > 0 then
        gc.setColor(COLOR.DL)
        gc.printf(DATA.win, 0, board.infoH - 30, board.titleW - 10, 'right')
    end

    -- Rule
    gc.translate(board.titleW, 0)
    FONT.set(40)
    gc.print(Text.rule, 10, DATA.zh and 10 or 5)
    FONT.set(20)
    local ruleY = DATA.zh and 62 or 42
    local extraY = DATA.zh and 5 or 0
    for i = 1, #activeRules do
        gc.setColor(ruleColor[activeRules[i]])
        gc.draw(activeRuleTexts[i], 10, ruleY)
        ruleY = ruleY + extraY + activeRuleTexts[i]:getHeight()
    end
    FONT.set(15)
    gc.setColor(COLOR.D)
    gc.draw(targetText, 10, board.infoH - targetText:getHeight() - 10)

    -- Bingo
    gc.translate(-board.titleW, board.infoH)
    gc.setLineWidth(2)
    local colorSet = hardMode and cellColorHard or cellColor
    for y = 1, 5 do
        for x = 1, 5 do
            local x0, y0 = (x - 1) * board.CW, (y - 1) * board.CH
            local color = ruleMat[y][x]
            -- if type(color) == 'table' then
            --     color = TABLE.find(color, debugColor) and debugColor
            -- end
            gc.setColor(colorSet[color])
            gc.rectangle('fill', x0, y0, board.CW, board.CH)
            gc.setColor(COLOR.D)
            gc.rectangle('line', x0, y0, board.CW, board.CH)

            -- Draw Tick/Cross
            if DATA.tickMat[y][x] > 0 then
                gc.setColor(COLOR.L)
                GC.mDraw(DATA.tickMat[y][x] == 1 and tick or cross, x0 + board.CW / 2, y0 + board.CH / 2)
            end
        end
    end

    gc.translate(0, 5 * board.CH) -- Credit
    gc.setColor(0, 0, 0, .26)
    gc.print(Text.credits, 0, 12)
    gc.setColor(0, 0, 0, .62)
    gc.draw(versionText, board.W, 8, nil, nil, nil, versionText:getWidth(), 0)
end

scene.widgetList = {
    WIDGET.new {
        type = 'checkBox',
        pos = { 1, 1 }, x = -250, y = -80, w = 40,
        color = 'D',
        cornerR = 0,
        text = LANG 'language',
        disp = TABLE.func_getVal(DATA, 'zh'),
        code = function()
            DATA.zh = not DATA.zh
            setLang(DATA.zh)
            saveTimer = 1.26
        end,
    },
    WIDGET.new {
        type = 'checkBox',
        pos = { 1, 1 }, x = -80, y = -80, w = 40,
        color = 'D',
        cornerR = 0,
        text = LANG 'sound',
        disp = TABLE.func_getVal(DATA, 'sound'),
        code = function()
            DATA.sound = not DATA.sound
            if DATA.sound then
                BGM.play('naive')
                if hardMode then
                    BGM.set('naive', 'pitch', 0.626, 0)
                end
            else
                BGM.stop()
            end
            saveTimer = 1.26
        end,
    },
}
SCN.add('main', scene)

ZENITHA.setFirstScene('main')

setLang(DATA.zh)
