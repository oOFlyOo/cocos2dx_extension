--[[
    箭头
--]]


require "LuaScript/commons/debug"
require "LuaScript/commons/class"
require "LuaScript/commons/register"
require "LuaScript/commons/object"


--[[
    一些参数
--]]
ARROW_PARAM =
{
    arrowTargetZ = 5,

    arrowZ = 10,
    arrowAP = ccp(0.5, 1),
    arrowR = 0,

    arrowBodyZ = 15,
    -- 开始显示需要的高度
    arrowBodySH = 80,
    arrowBodyW = 100,
    arrowBodyAP = ccp(0.5, 0),

    cellSH = 30,
    cellAP = ccp(0.5, 1),
    -- 大于260会出bug
    cellSpeed = 160,
    cellSpace = 10,
}


--[[
    属性
--]]
Arrow =
{
    startPos = nil,
    endPos = nil,

    arrowTarget = nil,
    arrow = nil,
    arrowBody = nil,
    arrowCells = {},
}


--[[
    类，继承于CCNode
--]]
Arrow = class("Arrow", register(CCNode, CCNode.create))


--[[
    创建
--]]
function Arrow:create()
    local instance = self:new()
    if (instance and instance:init()) then
        return instance
    else
        error("创建Arrow失败！")

        return nil
    end
end


--[[
    初始化
--]]
function Arrow:init()
    self:scheduleUpdateWithPriorityLua(register(self, self.updateArrow), 0)

    self:setStartPos(ccp(0, 0))
    self:initArrow()

    return true
end


--[[
    初始化箭头
--]]
function Arrow:initArrow()
    local arrowPlist = IMAGES.foreground.arrow
    CCSpriteFrameCache:sharedSpriteFrameCache():addSpriteFramesWithFile(arrowPlist.plist)

    local arrowTarget = ImageView:create()
    arrowTarget:loadTexture(arrowPlist.arrowTarget, UI_TEX_TYPE_PLIST)
    arrowTarget:setPosition(ccp(0, 0))
    arrowTarget:setZOrder(ARROW_PARAM.arrowTargetZ)
    self:addChild(arrowTarget)
    self.arrowTarget = arrowTarget

    local arrow = ImageView:create()
    arrow:loadTexture(arrowPlist.arrow, UI_TEX_TYPE_PLIST)
    arrow:setPosition(ccp(0, 0))
    arrow:setAnchorPoint(ARROW_PARAM.arrowAP)
    arrow:setRotation(ARROW_PARAM.arrowR)
    arrow:setZOrder(ARROW_PARAM.arrowZ)
    self:addChild(arrow)
    self.arrow = arrow

    local body = Layout:create()
    body:setSize(CCSizeMake(ARROW_PARAM.arrowBodyW, 0))
    body:setAnchorPoint(ARROW_PARAM.arrowBodyAP)
    body:setZOrder(ARROW_PARAM.arrowBodyZ)
    self:addChild(body)
    self.arrowBody = body
    self.arrowCells = {}

    body:setClippingEnabled(true)
    -- body:setBackGroundColorType(LAYOUT_COLOR_SOLID)
    -- body:setBackGroundColor(ccc3(127, 127, 127))

    return true
end


--[[
    设置起始点
--]]
function Arrow:setStartPos(pos)
    if (not pos) then
        error("参数错误！")

        return false
    end

    self.startPos = pos
    -- 把结束点也记下来
    self:setEndPos(pos)

    return true
end


--[[
    设置结束点
--]]
function Arrow:setEndPos(pos)
    if (not pos) then
        error("参数错误！")

        return false
    end

    self.endPos = pos

    self:setPosition(pos)

    return true
end


--[[
    更新箭头
--]]
function Arrow:updateArrow(delta)
    startPos = self.startPos
    endPos = self.endPos
    local angle = nil
    if (startPos.x == endPos.x and startPos.y == startPos.y) then
        angle = 0
    else
        angle = math.atan(math.abs((endPos.y - startPos.y) / (endPos.x - startPos.x))) * 180 / math.pi;
        --第一象限
        if (endPos.y > startPos.y and endPos.x > startPos.x) then
            angle = - angle;
        --第二象限
        elseif (endPos.y <= startPos.y and endPos.x > startPos.x) then
            angle = angle;
        --第三象限
        elseif (endPos.y > startPos.y and endPos.x <= startPos.x) then
            angle = angle - 180;
        --第四象限
        elseif (endPos.y <= startPos.y and endPos.x <= startPos.x) then
            angle = 180 - angle;
        end
        angle = angle + 90
    end
    self.arrow:setRotation(angle + ARROW_PARAM.arrowR)

    local distance = ccpDistance(endPos, startPos);
    local length = math.max(0, distance - ARROW_PARAM.arrowBodySH)
    self.arrowBody:setSize(CCSizeMake(ARROW_PARAM.arrowBodyW, length))
    self.arrowBody:setRotation(angle)
    self.arrowBody:setPosition(self:convertToNodeSpace(self.startPos))

    self:updateArrowBodies(delta)

    return true
end


--[[
    更新条形位置大小等
--]]
function Arrow:updateArrowBodies(delta)
    local body = self.arrowBody
    local cells = self.arrowCells
    local num = #cells
    local bSize = body:getSize()
    if (bSize.height <= ARROW_PARAM.cellSH) then
        if (num > 0) then
            self.arrowCells = {}
            body:removeAllChildrenWithCleanup(true)
        end

        return false
    end

    local arrowPlist = IMAGES.foreground.arrow
    CCSpriteFrameCache:sharedSpriteFrameCache():addSpriteFramesWithFile(arrowPlist.plist)
    local cells = self.arrowCells

    -- 看看是否一个都没有
    if (num == 0) then
        local cell = ImageView:create()
        cell:loadTexture(arrowPlist.arrowBody, UI_TEX_TYPE_PLIST)
        cell:setAnchorPoint(ARROW_PARAM.cellAP)
        cell:setPosition(ccp(bSize.width / 2, 0))
        cell:setScaleY(0)
        body:addChild(cell)
        table.insert(cells, 1, cell)
        num = #cells
    end

    local cell = cells[num]
    local size = cell:getSize()
    local n = num

    -- 调位置
    while (true) do
        local pos = ccp(cell:getPosition())
        local scaleY = cell:getScaleY()
        local newPos = ccpAdd(pos, ccp(0, ARROW_PARAM.cellSpeed * delta))

        -- 减去1是因为精确度问题
        if (pos.y - size.height * scaleY - 1 > 0) then
            pos = ccpAdd(pos, ccp(0, size.height * (1 - scaleY)))
            scaleY = 1
            newPos = ccpAdd(pos, ccp(0, ARROW_PARAM.cellSpeed * delta))
            cell:setScaleY(scaleY)
        end

        cell:setPosition(newPos)

        if (newPos.y - size.height - ARROW_PARAM.cellSpace > 0 and n == 1) then
            cell = ImageView:create()
            cell:loadTexture(arrowPlist.arrowBody, UI_TEX_TYPE_PLIST)
            cell:setAnchorPoint(ARROW_PARAM.cellAP)
            cell:setPosition(ccpAdd(pos, ccp(0, - size.height - ARROW_PARAM.cellSpace)))
            body:addChild(cell)
            table.insert(cells, 1, cell)
        elseif (n <= 1) then
            break
        else
            n = n - 1
            cell = cells[n]
        end
    end

    -- 调整cell大小
    for i, cell in ipairs(cells) do
        repeat
            local pos = ccp(cell:getPosition())
            local scaleY = cell:getScaleY()

            -- 已经到顶上去了
            if (pos.y >= bSize.height) then
                local height = pos.y - bSize.height
                pos = ccp(pos.x, bSize.height)
                if (height > size.height * scaleY) then
                    scaleY = 0
                    cell:setVisible(false)
                else
                    scaleY = (size.height * scaleY - height) / size.height * scaleY
                end
                cell:setScaleY(scaleY)
                cell:setOpacity(255 * scaleY)
                cell:setPosition(pos)

                break
            end

            -- 底下
            if (pos.y < size.height) then
                if (pos.y < 0) then
                    scaleY = 0
                else
                    scaleY = pos.y / size.height
                end
                cell:setScaleY(scaleY)
                cell:setOpacity(255 * scaleY)
            else
                cell:setScaleY(1)
                cell:setOpacity(255)
            end
        until true
    end

    -- 删除多余的cell
    for i, cell in ipairs(cells) do
        if (not cell:isVisible()) then
            local num = #cells
            for j = i, num, 1 do
                cells[j]:removeFromParentAndCleanup(true)
                cells[j] = nil
            end

            break
        end
    end

end


--[[
    下中锚点版
--]]
-- function Arrow:updateArrowBodies(delta)
--     local body = self.arrowBody
--     local cells = self.arrowCells
--     local num = #cells
--     local bSize = body:getSize()
--     if (bSize.height <= ARROW_PARAM.cellSH) then
--         if (num > 0) then
--             self.arrowCells = {}
--             body:removeAllChildrenWithCleanup(true)
--         end

--         return false
--     end

--     local arrowPlist = IMAGES.foreground.arrow
--     CCSpriteFrameCache:sharedSpriteFrameCache():addSpriteFramesWithFile(arrowPlist.plist)
--     local cells = self.arrowCells

--     -- 看看是否一个都没有
--     if (num == 0) then
--         local cell = ImageView:create()
--         cell:loadTexture(arrowPlist.arrowBody, UI_TEX_TYPE_PLIST)
--         -- cell:setAnchorPoint(ARROW_PARAM.cellAP)
--         cell:setAnchorPoint(ccp(0.5, 0))
--         cell:setPosition(ccp(bSize.width / 2, 0))
--         cell:setScaleY(0)
--         body:addChild(cell)
--         table.insert(cells, 1, cell)
--         num = #cells
--     end

--     local cell = cells[num]
--     local size = cell:getSize()
--     local n = num

--     -- 调位置
--     while (true) do
--         local pos = ccp(cell:getPosition())
--         local scaleY = cell:getScaleY()
--         local newPos = ccpAdd(pos, ccp(0, ARROW_PARAM.cellSpeed * delta))
--         if (pos.y == 0 and newPos.y * scaleY < bSize.height and scaleY < 1) then
--             scaleY = (size.height * scaleY + newPos.y) / size.height
--             cell:setScaleY(scaleY)
--             newPos = pos
--         elseif (pos.y < 0) then
--             scaleY = (size.height * scaleY + pos.y) / size.height
--             cell:setScaleY(scaleY)
--             newPos = ccpAdd(pos, ccp(0, - pos.y))
--         end

--         cell:setPosition(newPos)

--         if (newPos.y - ARROW_PARAM.cellSpace > 0 and n == 1) then
--             cell = ImageView:create()
--             cell:loadTexture(arrowPlist.arrowBody, UI_TEX_TYPE_PLIST)
--             -- cell:setAnchorPoint(ARROW_PARAM.cellAP)
--             cell:setAnchorPoint(ccp(0.5, 0))
--             cell:setScaleY(1)
--             cell:setPosition(ccpAdd(pos, ccp(0, - size.height - ARROW_PARAM.cellSpace)))
--             body:addChild(cell)
--             table.insert(cells, 1, cell)
--         elseif (n <= 1) then
--             break
--         else
--             n = n - 1
--             cell = cells[n]
--         end
--     end

--     -- 调整cell大小
--     for i, cell in ipairs(cells) do
--         repeat
--             local pos = ccp(cell:getPosition())
--             local scaleY = cell:getScaleY()

--             -- 超出
--             if (pos.y > bSize.height) then
--                 cell:setVisible(false)

--                 break
--             end

--             -- 到顶端
--             if (pos.y + size.height * scaleY > bSize.height) then
--                 local height = bSize.height - pos.y
--                 scaleY = height / size.height
--                 cell:setScaleY(scaleY)
--                 cell:setOpacity(255 * scaleY)

--                 break
--             end

--             -- 底下
--             if (pos.y == 0) then
--                 scaleY = cell:getScaleY()
--                 cell:setOpacity(255 * scaleY)

--                 break
--             end

--             -- 中间
--             scaleY = math.min(1, (bSize.height - pos.y) / size.height)
--             cell:setScaleY(scaleY)
--             cell:setOpacity(255 * scaleY)

--             break
--         until true
--     end

--     -- 删除多余的cell
--     for i, cell in ipairs(cells) do
--         if (not cell:isVisible()) then
--             local num = #cells
--             for j = i, num, 1 do
--                 cells[j]:removeFromParentAndCleanup(true)
--                 cells[j] = nil
--             end

--             break
--         end
--     end

-- end