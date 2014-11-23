--[[
    用于实现富文本
    暂时只提供限制宽度
--]]


--[[
    属性
--]]
RichWidget =
{
    rootWidget = nil,
    width = nil,
    height = nil,

    -- 行距
    verticalSpace = nil,
    -- 当前行的高度
    rowHeight = nil,
    -- 当前行的剩余宽度
    remainWidth = nil,

    -- 用于计算用的label
    tempLabel = nil,
}


--[[
    类
--]]
RichWidget = class("RichWidget", register(Widget, Widget.create))


--[[
    创建
--]]
function RichWidget:create()
    local instance = self:new()
    if (instance and instance:init()) then
        return instance
    else
        error("创建RichWidget失败！")

        return nil
    end
end


--[[
    初始化
--]]
function RichWidget:init()
    self:registerScriptHandler(register(self, self.onNodeEvent))

    self.width = 0
    self.height = 0
    self.rootWidget = Widget:create()
    self:addChild(self.rootWidget)
    self:setRootHeight(self.height)

    self.verticalSpace = 0
    self.rowHeight = 0
    self.remainWidth = 0

    self.tempLabel = Label:create()
    -- 锚点统一在左上
    self.tempLabel:setAnchorPoint(ccp(0, 1))
    self.tempLabel:retain()

    return true
end


--[[
    场景进入时调用函数
--]]
function RichWidget:onEnter()

    return true;
end


--[[
    场景释放时调用函数
--]]
function RichWidget:onCleanup()
    self.tempLabel:release()

    return true;
end


--[[
    场景进入退出函数
--]]
function RichWidget:onNodeEvent(event)
    if (event == "enter") then
        return self:onEnter();
    elseif (event == "cleanup") then
        return self:onCleanup();
    end

    return false;
end


--[[
    获取大小
--]]
function RichWidget:getSize()
    return CCSizeMake(self.width, self.height)
end


--[[
    设置行距
    也是得一开始便设置好的玩意
--]]
function RichWidget:setVerticalSpace(space)
    self.verticalSpace = space
end


--[[
    设置宽度
    暂时不考虑动态调整，所以必须在插入前设置好宽度
--]]
function RichWidget:setWidth(width)
    -- 由于必须在初始化的时候设置，所以可以一并设置剩余宽度
    if (self.width == 0 and self.height == 0 and self.remainWidth == 0) then
        self.remainWidth = width
    end

    self.width = width

    return true
end


--[[
    设置根节点的高度
--]]
function RichWidget:setRootHeight(height)
    self.rootWidget:setPositionY(height)
    self.height = height

    return true
end


--[[
    放进text
    需要空白行的时候请使用 "\n \n"
--]]
function RichWidget:pushBackText(text, color, opacity, fSize)
    text = tostring(text)

    local tLabel = self.tempLabel
    tLabel:setColor(color)
    tLabel:setOpacity(opacity)
    tLabel:setFontSize(fSize)

    -- 用于存返回的label
    local labels = {}
    while(#text > 0) do
        local tText = nil
        local size = nil
        -- 一直计算到最大宽度为止
        local len = self:getStringNum(text)
        local tLen = 0
        repeat
            tLen = tLen + 1
            tText = self:subStringWithNum(text, 1, tLen)
            tLabel:setText(tText)

            -- 遇到换行符了
            if (string.sub(tText, #tText) == "\n") then
                -- 这是第一个字符
                if (tLen == 1) then
                    -- 手动将字符串往后取
                    text = string.sub(text, 2)

                end

                break
            end

            size = tLabel:getSize()
        until (size.width > self.remainWidth or tLen > len)

        tText = self:subStringWithNum(tText, 1, tLen - 1)
        -- 一个都放不下, 也就是换行
        if (#tText == 0) then
            self:newline()
            -- 刷上行距
            self:setRootHeight(self.height + self.verticalSpace)
        -- 能放多少个就多少个罗
        else
            tLabel:setText(tText)
            local label = tLabel:clone()
            self:pushBack(label)
            table.insert(labels, label)

            text = self:subStringWithNum(text, tLen, len)
        end
    end

    return labels
end


--[[
    插入一个widget
--]]
function RichWidget:pushBackWidget(widget)
    -- 强制锚点左上
    widget:setAnchorPoint(ccp(0, 1))
    widget:ignoreAnchorPointForPosition(false)

    -- 看看需不需要换一行
    local size = widget:getSize()
    if (self.remainWidth < self.width and size.width > self.remainWidth) then
        self:newline()
        -- 刷上行距
        self:setRootHeight(self.height + self.verticalSpace)
    end

    return self:pushBack(widget)
end


--[[
    排版插入
--]]
function RichWidget:pushBack(widget)
    local size = widget:getSize()
    if (self.rowHeight < size.height) then
        self:setRootHeight(self.height + size.height - self.rowHeight)
        self.rowHeight = size.height
    end

    widget:setPosition(ccp(self.width - self.remainWidth, - self.height + size.height))
    self.remainWidth = self.remainWidth - size.width
    self.rootWidget:addChild(widget)

    return true
end


--[[
    换行
--]]
function RichWidget:newline()
    self.rowHeight = 0
    self.remainWidth = self.width

    return true
end


--[[
    根据个数截取字符串
--]]
function RichWidget:subStringWithNum(str, start, over)
    local j = start
    if (j ~= 1) then
        local s = self:subStringWithNum(str, 1, j - 1)
        j = #s + 1
    end

    local tStr = ""
    for i = start, over, 1 do
        -- 超出长度，可以跳出了，返回最大长度
        if (j > #str) then
            break
        end

        if (string.byte(str, j) < 128) then
            tStr = tStr .. string.sub(str, j, j)
            j = j + 1
        else
            tStr = tStr .. string.sub(str, j, j + 2)
            j = j + 3
        end
    end

    return tStr
end


--[[
    计算字符个数
--]]
function RichWidget:getStringNum(str)
    local num = 0
    local i = 1
    while (i <= #str) do
        if (string.byte(str, i) < 128) then
            i = i + 1
        else
            i = i + 3
        end

        num = num + 1
    end

    return num
end