--[[
    自定义缩放
    继承自ClippingArea，其实只是用了裁剪功能而已
    仿照CCScrollView和CCClippingNode的写法，需要继承来使用（简单的功能的话倒是可以不用）
    最多支持双触点
    单触点下，是移动状态
    双触点下，是缩放状态

    这里限定了遮罩内容的锚点必须为中心
    缩放如果超过了做小大小，将定位于中间
--]]


require "Extension/class"
require "Extension/debug"
require "Extension/register"


--成员变量
ZoomView =
{
    --遮罩层
    maskLayer = nil,
    --遮罩内容，使用CCNode来存放
    maskContent = nil,

    --记录上次位移
    --采用这种方式是为了在缩放状态转为移动状态的时候，不会丢失信息
    --[0]才是真正用于记录上次移动信息的
    lastPosition = {
                        [0] = nil,
                        [1] = nil,
                        [2] = nil,
                    },
    --记录上次距离差
    lastDistance = nil,
    --记录缩放中点与缩放物体的锚点之间的距离
    lastDelta = nil,

    --记录当前触摸手指数
    touchNum = nil,
    --缩放状态下记录的传递触摸信息的次数
    touchMsgNum = nil,

    --设置是否开启缩放，默认开启
    boolZoom = nil,
    --缩放上限和下限，默认是10倍和0.1倍
    zoomMax = nil,
    zoomMin = nil,
}


--继承ClippingArea
ZoomView = class("ZoomView", register(ClippingArea, ClippingArea.create));


--创建ZoomView实例    
function ZoomView:create()
    local instance = self:new();

    if(instance and instance:init()) then
        return instance;
    else
        error("ZoomView实例创建失败!");

        instance = nil;

        return nil;
    end
end


--[[
    初始化
--]]
function ZoomView:init()
    self:setMaskLayer();
    self:setZoomEnabled(true);
    self:setZoomMax(10);
    self:setZoomMin(0.1);

    self.maskContent = nil;
    self.lastPosition = {};
    self.lastPosition[0] = nil;
    self.lastPosition[1] = nil;
    self.lastPosition[2] = nil;
    self.lastDistance = nil;
    self.lastDelta = nil;
    self.touchNum = 0;
    self.touchMsgNum = 0;

    return true;
end


--[[
    onTouchBegan回调函数
--]]
function ZoomView:onTouchBegan(x, y)
    --仅当坐标在触摸范围内才拦截
    if (not self.maskLayer:boundingBox():containsPoint(ccp(x, y))) then
        return false;
    end

    --判断是否已经超过了触摸上限，因为只提供了缩放功能，所以为2
    if (self.touchNum == 2) then
        return false
    elseif (self.touchNum == 1 and not self.boolZoom) then
        --已经有一个触摸点，但是不可以缩放，所以返回false
        return false;
    else
        --这时候要不就是还没有触摸点，要不就是开启缩放
        self.touchNum = self.touchNum + 1;
    end

    --根据标示做相应操作
    if (self.touchNum == 1) then
        --说明现在是移动状态

        self.lastPosition[0] = ccp(x, y);
        self.lastPosition[1] = ccp(x, y);
    elseif (self.touchNum == 2) then
        --说明现在是缩放状态

        --计算触摸点距离以后使用
        self.lastPosition[0] = ccp(x, y);
        self.lastPosition[2] = ccp(x, y);
        self.lastDistance = ccpDistance(self.lastPosition[1], self.lastPosition[2]);

        --计算触摸中心与锚点距离以后使用
        local midPoint = ccpMidpoint(self.lastPosition[1], self.lastPosition[2]);
        self.lastDelta = ccpSub(midPoint, ccp(self.maskContent:getPosition()));

        --顺便初始化缩放标识
        self.touchMsgNum = 0;
    end

    return true;
end


--[[
    限制移动函数，这里不实现移动
    最终定位于左下角
--]]
function ZoomView:limitMove()
    --获取位置
    local pos = ccp(self.maskContent:getPosition());
    --获取节点的boudingbox进行计算
    local contentBox = self.maskContent:boundingBox();
    local layerBox = self.maskLayer:boundingBox();

    --计算上下左右的移动次数，如果移动了两次，说明高或者宽已经小于最小大小了
    local limitX, limitY = 0, 0;

    --右边计算
    if (contentBox:getMaxX() < layerBox:getMaxX()) then
        pos = ccp(layerBox:getMaxX() - contentBox.size.width / 2, pos.y);
        self.maskContent:setPosition(pos);
        contentBox = self.maskContent:boundingBox();

        limitX = limitX + 1;
    end

    --上边计算
    if (contentBox:getMaxY() < layerBox:getMaxY()) then
        pos = ccp(pos.x, layerBox:getMaxY() - contentBox.size.height / 2);
        self.maskContent:setPosition(pos);
        contentBox = self.maskContent:boundingBox();

        limitY = limitY + 1;
    end

    --左边计算
    if (contentBox:getMinX() > layerBox:getMinX()) then
        pos = ccp(layerBox:getMinX() + contentBox.size.width / 2, pos.y);
        self.maskContent:setPosition(pos);
        contentBox = self.maskContent:boundingBox();

        limitX = limitX + 1;
    end

    --下边计算
    if (contentBox:getMinY() > layerBox:getMinY()) then
        pos = ccp(pos.x, layerBox:getMinY() + contentBox.size.height / 2);
        self.maskContent:setPosition(pos);

        limitY = limitY + 1;
    end

    if (limitX == 2) then
        self.maskContent:setPositionX(0);
    end

    if (limitY == 2) then
        self.maskContent:setPositionY(0);
    end

    return true;
end


--提供给onTouchMoved的位移函数
function ZoomView:move(x, y)
    --根据非空的触摸点记录移动距离
    local move = ccpSub(ccp(x, y), self.lastPosition[0]);

    --计算新位置
    local pos = ccp(self.maskContent:getPosition());
    local newPos = ccpAdd(pos, move);
    self.maskContent:setPosition(newPos)
    self:limitMove();

    --保存新触点位置
    self.lastPosition[0] = ccp(x, y);
    self.lastPosition[1] = ccp(x, y);

    return true;
end


--提供给onTouchMoved的缩放函数
function ZoomView:zoom(x, y)
    --触发信息记录自增
    self.touchMsgNum = self.touchMsgNum + 1;

    --根据当前触发信息记录来判断操作
    if (self.touchMsgNum == 1) then
        --循环信息的第一条，只需记录

        self.lastPosition[0] = ccp(x, y);
        self.lastPosition[1] = ccp(x, y);
    elseif (self.touchMsgNum == 2) then
        --循环信息的第二条，开始缩放

        self.lastPosition[0] = ccp(x, y);
        self.lastPosition[2] = ccp(x, y);

        --计算新的距离
        local distance = ccpDistance(self.lastPosition[1], self.lastPosition[2]);

        --计算新的缩放
        local scale = self.maskContent:getScale();
        local newScale = distance / self.lastDistance * scale;

        --需要匹配缩放极限
        if (newScale < self.zoomMin) then
            newScale = self.zoomMin;
        elseif (newScale > self.zoomMax) then
            newScale = self.zoomMax;
        end

        --缩放
        self.maskContent:setScale(newScale);

        --计算新的中线点距离
        local delta = ccpMult(self.lastDelta, newScale / scale);
        --算出变化的距离差
        local changeMove = ccpSub(self.lastDelta, delta);
        --保存新距离
        self.lastDelta = delta;

        --计算出新位置
        local newPos = ccpAdd(ccp(self.maskContent:getPosition()), changeMove);
        self.maskContent:setPosition(newPos);
        --保持位置
        self:limitMove();

        --保存新距离
        self.lastDistance = distance;
        
        --初始化触摸信息
        self.touchMsgNum = 0;
    end

    return true;
end


--touchMoved回调函数
function ZoomView:onTouchMoved(x, y)
    --根据状态来进行操作
    if (self.touchNum == 1) then
        --单触点，移动状态
        --移动
        self:move(x, y);
    elseif (self.touchNum == 2) then
        --多触点，缩放状态
        --缩放
        self:zoom(x, y);
    end

    return true;
end


--[[
    onTouchEnded回调函数
--]]
function ZoomView:onTouchEnded(x, y)
    --触摸点数减一
    self.touchNum = self.touchNum - 1;

    --如果touchNum变成0的话，说明已经结束操作
    --如果从2变成1的话，说明从缩放变回移动操作
    if (self.touchNum == 1) then
        --判断应该将哪个点标识为位移点
        if (self.lastPosition[1] and 
            self.lastPosition[1].x == x and self.lastPosition[1].y == y) then
            --2变成了1
            self.lastPosition[1] = self.lastPosition[2];
            self.lastPosition[0] = self.lastPosition[2];
        elseif (self.lastPosition[2] and 
                self.lastPosition[2].x == x and self.lastPosition[2].y == y) then
            self.lastPosition[0] = self.lastPosition[1];
        end
        --匹配不上就不管了，一般都可以匹配上的
    end

    return true;
end


--[[
    onTouch回调函数
--]]
function ZoomView:onTouch(event, x, y)
    --先将坐标转换为以遮罩层物体的坐标，也就是self
    local pos = self:convertToNodeSpace(ccp(x, y));
    --使用转换好的坐标
    x, y = pos.x, pos.y;

    --如果maskContent为空的话直接跳出
    if (not self.maskContent) then
        return false;
    end

    if (event == "began") then
        return self:onTouchBegan(x, y);
    elseif (event == "moved") then
        return self:onTouchMoved(x, y);
    elseif (event == "ended") then
        return self:onTouchEnded(x, y);
    elseif (event == "cancelled") then
        return self:onTouchEnded(x, y);
    end
end


--[[
    将绑定触摸事件单独抽出来，方便重写
--]]
function ZoomView:registerTouchHandler()
    --暂定，可以重写
    self.maskLayer:registerScriptTouchHandler(register(self, self.onTouch),
                                                
                                                false, 0, true);

    return true;
end


--[[
    设置遮罩层
--]]
function ZoomView:setMaskLayer()
    --默认大小是屏幕大小
    self.maskLayer = CCLayer:create();
    --开启锚点在中间（其实不一定，只需要统一即可）
    --其实默认就是没开启锚点，不过默认锚点为(0.5, 0.5)
    self.maskLayer:ignoreAnchorPointForPosition(false);

    --绑定onTouch回调
    self:registerTouchHandler();
    self.maskLayer:setTouchEnabled(true);

    self:setStencil(self.maskLayer);

    return true;
end


--[[
    设置是否允许缩放
--]]
function ZoomView:setZoomEnabled(enabled)
    if (type(enabled) ~= "boolean") then
        error("参数错误！");

        return false;
    end

    self.boolZoom = enabled;

    return true;
end


--[[
    设置缩放上限
--]]
function ZoomView:setZoomMax(max)
    --检查参数
    if (not max or max < 1) then
        error("参数错误！");

        return false;
    end

    self.zoomMax = max;

    return true;
end


--[[
    设置缩放下限
--]]
function ZoomView:setZoomMin(min)
    --检查参数
    if (not min or min > 1) then
        error("参数错误！");

        return false;
    end

    self.zoomMin = min;

    return true;
end


--[[
    设置遮罩内容
    只能有一个遮罩内容存在，如果需要其它，则设为子节点
--]]
function ZoomView:setMaskContent(content)
    --检查参数
    if (not content) then
        error("参数错误！");

        return false;
    end

    --如果原来已经有遮罩内容了，则先删除
    if (self.maskContent) then
        self.maskContent:removeFromParentAndCleanup(true);
        self.maskContent = nil;
    end

    --保险起见的设置
    content:ignoreAnchorPointForPosition(false);
    content:setAnchorPoint(ccp(0.5, 0.5));

    self:addChild(content);
    self.maskContent = content;

    return true;
end