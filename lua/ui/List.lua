--[[
    自定义网格滚动视图
    继承自ClippingArea，其实只是用了裁剪功能而已
    注意使用大小间距等最好相等

    注意，为了便于理解，锚点会因为方向而改变
    横向的锚点在左下角，maskContent位置为负值，cell位置为正值
    纵向的锚点在左上角，maskContent位置为正值，cell位置为负值
    定位和添加物体需要参考cell的位置

    改动比较大，所以不继承GridView
    仿照CCTableView的写法，需要继承来使用
--]]


require "Extension/class"
require "Extension/debug"
require "Extension/register"


--[[滚动方向
    因为需要继承，所以不可以使用local
--]]
DIRECTION =
{
    horizontal = 1,
    vertical = 2,
}


SLIDE =
{
    refresh = 1 / 30,
    --距离差转移动距离倍数（一般距离差为10到200，还要考虑到乘以dt）
    moveScale = 30,
    --加速度（0为速度不变，这里采用的是倍速，就是减少原来的速度多少）
    acceleration = 0.06,
    --滑动加速结束时间
    endTime = 1.3,
}


--[[
    成员变量
--]]
List =
{
    --遮罩层
    maskLayer = nil,
    --遮罩内容，使用CCNode来存放
    maskContent = nil,
    --遮罩内容的大小
    contentSize = nil,
    --滑动方向
    direction = nil,
    --定位的位置，还有一个回弹百分比
    locateRect = {x = nil, y = nil, width = nil, height = nil, ratio = nil,},
    --判断是否需要定位
    boolLocate = nil,
    --设定弹跳范围
    bounce = {width = nil, height = nil,},

    --刷新位置
    refreshPosition = {x = nil, y = nil,};
    --更新位置句柄
    refreshHandle = nil,
    --加速移动句柄
    accelerateHandle = nil,
    --移动速度
    speed = {x = nil, y = nil,},
    --统计时间
    time = nil;

    --cell的开始id和结束id（暂时限定startId <= endId，也就是至少1个数）
    --可以根据需求改，不过改动必须小心，以免造成错误
    startId = nil,
    endId = nil,
    --cell之间的距离差
    distance = {width = nil, height = nil,},
    --保存cells的信息
    --cells的boundingbox，使用table来存储
    --这些都是相对位置，所以是不会改变的，要算位置的时候需要加上位置
    --并不是真正的boundingBox，而是位置和大小，因为真正的boundingBox起始点都是左下角
    cells = {x = nil, y = nil, width = nil, height = nil, isLoaded = nil},
    --cell的数量
    amountOfCells = nil,

    --记录上次位移
    lastPosition = {x = nil, y = nil,},
    --记录是否移动过
    isDraged = nil,

    --记录是否已经是在触摸状态
    isTouched = nil,
}


--[[
    继承ClippingArea
    必须重写addCell，cellSize
--]]
List = class("List", register(ClippingArea, ClippingArea.create));


--创建List实例    
function List:create()
    local instance = self:new();

    if(instance and instance:init()) then
        return instance;
    else
        error("创建List实例失败!");

        instance = nil;

        return nil;
    end
end


--[[
    初始化
--]]
function List:init()
    self:setMaskLayer();
    self:setMaskContent();
    --默认不使用回弹效果
    self:setBounce(0, 0);
    --默认不使用定位
    self:setLocateEnabled(false);
    --默认使用横向滚动
    self:setDirection(DIRECTION.horizontal)
    --默认cell之间的距离差为(0, 0)
    self:setDistance(0, 0);
    --默认cell数量为0
    self:setAmountOfCells(0);
    --默认可视范围为(0, 0)
    self:setViewSize(0, 0);

    return true;
end


--[[
    删除对象，主要用于移除更新函数
    如果使用了create的话，必须也要注册该函数
--]]
function List:delete()
    if (self.refreshHandle) then
        CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.refreshHandle);
    end

    if (self.accelerateHandle) then
        CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.accelerateHandle);
    end
end


--[[
    判断鼠标点击的cell，如果没有点击到cell的话，返回0
--]]
function List:idOfCellTouched(x, y)
    --获取maskContent的位置
    local pos = ccp(self.maskContent:getPosition());
    
    --遍历一遍存在的cell，看点击是否成功
    for i = self.startId, self.endId, 1 do
        --转换CCRect为看到的cell的CCRect
        local box = self.cells[i];
        --小心陷阱，引用类型不能直接修改
        local realBox = nil;

        if self.direction == DIRECTION.horizontal then
            realBox = CCRectMake(box.x + pos.x, 
                                    box.y + pos.y,
                                    box.width, box.height);
        --转为boundingBox
        elseif self.direction == DIRECTION.vertical then
            realBox = CCRectMake(box.x + pos.x, 
                                        box.y + pos.y - box.height,
                                        box.width, box.height);
        end

        --碰撞检测，如果检测为真，则返回该cell的id
        if realBox:containsPoint(ccp(x, y)) then
            return i;
        end
    end

    --没有点击到cell，返回0
    return 0;
end


--[[
    鼠标在cell上点下鼠标的回调函数
--]]
function List:cellTouchedDown(id)
    log("cell：%d处点下鼠标！", id);
end


--[[
    鼠标在cell上松开鼠标的回调函数
--]]
function List:cellTouchedUp(id)
    log("cell：%d处松开鼠标！", id);
end


--[[
    鼠标在cell上点击
--]]
function List:cellClicked(id)
    log("cell：%d处点击鼠标！", id);
end


--[[
    更新位置信息
--]]
function List:refresh(dt)
    self.refreshPosition = {x = self.lastPosition.x,
                            y = self.lastPosition.y,};
end


--[[
    onTouchBegan回调函数
--]]
function List:onTouchBegan(x, y)
    --仅当坐标在触摸范围内才拦截
    if (not self.maskLayer:boundingBox():containsPoint(ccp(x, y))) then
        return false;
    end

    --判断是否已经在触摸状态，如果在的话，return false，不让其多触摸
    if (self.isTouched) then
        return false
    else
        self.isTouched = true
    end

    --获取点击cell
    local id = self:idOfCellTouched(x, y);
    if (id == 0) then
        log("没有点击到cell！");
    else
        self:cellTouchedDown(id);
    end

    --记录位置提供给touchMoved使用
    self.lastPosition = {x = x, y = y,};

    --记录位置提供给touchEnded使用
    self.refreshPosition = {x = x, y = y,};
    self.refreshHandle = 
        CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(register(self, self.refresh), SLIDE.refresh, false);

    --当还在移动的时候，停止加速移动
    if (self.accelerateHandle) then
        CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.accelerateHandle);
        self.accelerateHandle = nil;
    end

    --初始化移动状态
    self.isDraged = false;

    --拦截
    return true;
end


--[[
    根据需求设置cell的可见性，因为某些cell可能加载了但是不需要可见
    做法是遍历已经加载的cells
--]]
function List:setCellsVisible(newPos)
    --获取masklayer的boundingbox
    local box = self.maskLayer:boundingBox();

    --存放cell
    local cell = nil;

    --从startId开始遍历
    local startId = self.startId;
    local endId = self.endId;

    --横向判断
    if self.direction == DIRECTION.horizontal then
        --startId因为预加载处理需要判断，如果不需要显示，设为false，并且id后移
        --否则id不变
        if self.cells[startId].x +
            self.cells[startId].width + newPos.x <= 0 then
            cell = self.maskContent:getChildByTag(startId);
            cell:setVisible(false);
            startId = startId + 1;
        end

        --endId因为预加载处理需要判断，如果不需要显示，设为false，并且记录的id-1
        --否则记录的id不变
        if self.cells[endId].x + newPos.x >= box.size.width then
            cell = self.maskContent:getChildByTag(endId);
            cell:setVisible(false);
            endId = endId - 1;
        end
    end
    --竖向判断
    if self.direction == DIRECTION.vertical then
        --startId因为预加载处理需要判断，如果不需要显示，设为false，并且id后移
        --否则id不变
        if self.cells[startId].y -
            self.cells[startId].height + newPos.y >= 0 then
            cell = self.maskContent:getChildByTag(startId);
            cell:setVisible(false);
            startId = startId + 1;
        end

        --endId因为预加载处理需要判断，如果不需要显示，设为false，并且记录的id-1
        --否则记录的id不变        
        if self.cells[endId].y + newPos.y <= - box.size.height then
            cell = self.maskContent:getChildByTag(endId);
            cell:setVisible(false);
            endId = endId - 1;
        end
    end

    --开始遍历，打开显示
    for id = startId, endId, 1 do
        local cell = self.maskContent:getChildByTag(id);
        cell:setVisible(true);
    end
end


--[[
    判断是否需要增删cell，并且做相应操作
--]]
function List:changeList(newPos)
    --记录boudingbox
    local layerBox = self.maskLayer:boundingBox();

    --横向判断
    if self.direction == DIRECTION.horizontal then
        --左边删除（也就是第二个的右边超出显示范围左边，然后删除第一个）
        while self.cells[self.startId + 1].x + 
                self.cells[self.startId + 1].width + newPos.x <= 0 do
            self:removeCellTopLeft();

            --如果startId大于endId，则应该让其相等
            if (self.startId > self.endId) then
                self.endId = self.startId;
            end
        end
        --左边添加（也就是第一个的右边在显示范围左边内，需要增加一个）
        while self.startId > 1 and
                self.cells[self.startId].x + 
                self.cells[self.startId].width + newPos.x > 0 do
            self:addCellTopLeft();
        end
        --右边删除（也就是倒数第二个的左边在显示范围右边外，然后删除最后一个）
        while self.cells[self.endId - 1].x + newPos.x >=
                layerBox.size.width do
            self:removeCellBottomRight();

            --如果endId小于startId，则应该让其相等
            if (self.endId < self.startId) then
                self.startId = self.endId;
            end
        end
        --右边添加（也就是最后一个的左边在显示范围右边内，需要增加一个）
        while self.endId < self.amountOfCells and
            self.cells[self.endId].x + newPos.x <
                layerBox.size.width do
            self:addCellBottomRight();
        end
    --竖向判断
    elseif self.direction == DIRECTION.vertical then
        --上边删除（也就是第二个的下边超出显示范围上边，然后删除第一个）
        while self.cells[self.startId + 1].y -
                self.cells[self.startId +1].height + newPos.y >= 0 do
            self:removeCellTopLeft();

            --如果startId大于endId，则应该让其相等
            if (self.startId > self.endId) then
                self.endId = self.startId;
            end
        end
        --上边添加（也就是第一个的下边在显示范围上边内，需要增加一个）
        while self.startId > 1 and
            self.cells[self.startId].y - 
            self.cells[self.startId].height + newPos.y < 0 do
            self:addCellTopLeft();
        end
        --下边删除（也就是倒数第二个的上边超出显示范围下边，然后删除最后一个）
        while self.cells[self.endId - 1].y + newPos.y <=
                - layerBox.size.height do
            self:removeCellBottomRight();

            --如果endId小于startId，则应该让其相等
            if (self.endId < self.startId) then
                self.startId = self.endId;
            end
        end
        --下边添加（也就是倒数第一个的上边在显示范围下边内，需要增加一个）
        while self.endId < self.amountOfCells and
                self.cells[self.endId].y + newPos.y >
                - layerBox.size.height do
            self:addCellBottomRight();
        end
    end

    --加载cells
    self:loadCells();
    --打开关闭显示
    self:setCellsVisible(newPos);
end


--[[
    设置maskContent的位置
    虽然可以直接设，但是每次移动都应该changList，所以这里封装一下
    如果没有给出位置的话，代表位置不变，仅仅是为了刷新显示
    注意，这里没有检查位置有没有问题的
--]]
function List:setMaskContentPos(pos)
    --如果pos为nil的话，则不改变位置
    pos = pos or ccp(self.maskContent:getPosition());

    --先进行裁剪加载，再移动
    self:changeList(pos);
    self.maskContent:setPosition(pos);
end


--限制移动
function List:limitMove(newPos)
    --记录boudingbox
    local layerBox = self.maskLayer:boundingBox();
    local contentPos = ccp(self.maskContent:getPosition());
    local contentBox = CCRectMake(contentPos.x, contentPos.y, 
                                    self.contentSize.width, self.contentSize.height);

    --如果大小不符合，则不可以移动
    if (self.direction == DIRECTION.horizontal) then
        if (contentBox.size.width <= layerBox.size.width) then
            return newPos;
        end
    elseif (self.direction == DIRECTION.vertical) then
        if (contentBox.size.height <= layerBox.size.height) then
            return newPos;
        end
    end
    
    --判断是否允许移动
    --有定位框的，不允许超过定位框确定的定位比率
    if self.boolLocate then
        --横向判断
        if self.direction == DIRECTION.horizontal then
            --遮罩内容与定位框左边比较
            if newPos.x > self.locateRect.x + self.locateRect.width * self.locateRect.ratio then
                --遮罩内容左边定于于定位框
                newPos = ccp(self.locateRect.x + self.locateRect.width * self.locateRect.ratio, 0);
            --遮罩内容与定位框右边比较
            elseif newPos.x + contentBox.size.width < self.locateRect.x + self.locateRect.width * (1 - self.locateRect.ratio) then
                --遮罩内容右边定于于定位框
                newPos = ccp(- contentBox.size.width + self.locateRect.x + self.locateRect.width * (1 - self.locateRect.ratio), 0);
            end
        --竖向判断
        elseif self.direction == DIRECTION.vertical then
            --遮罩内容与定位框上边比较
            if newPos.y < - self.locateRect.y - self.locateRect.height * self.locateRect.ratio then
                --遮罩内容上边定于于定位框
                newPos = ccp(0, - self.locateRect.y - self.locateRect.height * self.locateRect.ratio);
            --遮罩内容与定位框下边比较
            elseif newPos.y - contentBox.size.height > - self.locateRect.y - self.locateRect.height * (1 - self.locateRect.ratio) then
                --遮罩内容下边定于于定位框
                newPos = ccp(0, contentBox.size.height - self.locateRect.y - self.locateRect.height * (1 - self.locateRect.ratio));
            end
        end
--[[
    没有定位框的，不允许超过预定设好的固定值

    这里有一个问题，就是在拖动的时候，因为右边界的值是动态变的
    所以，会很容易移动的时候就撞到右边的值，而造成限定了滑动的最大值

    修改办法1：值设大一点，但是也会产生相应问题，换汤不换药
    修改办法2：一开始就设定了maskContent的值为最大值，就没有这个问题了
                但是会造成不能动态改变的问题
--]]
    else
        --横向判断
        if self.direction == DIRECTION.horizontal then
            --遮罩内容与反弹范围左边比较
            if newPos.x > self.bounce.width then
                --定位于反弹左边
                newPos = ccp(self.bounce.width, 0);
            --遮罩内容与反弹范围右边比较
            elseif newPos.x + contentBox.size.width < layerBox.size.width - self.bounce.width then
                --定位于反弹右边
                newPos = ccp(- contentBox.size.width + layerBox.size.width - self.bounce.width, 0);
            end
        --竖向判断
        elseif self.direction == DIRECTION.vertical then
            --遮罩内容与反弹范围上边比较
            if newPos.y < - self.bounce.height then
                --定位于反弹上边
                newPos = ccp(0, - self.bounce.height);
            --遮罩内容与反弹范围下边比较
            elseif newPos.y - contentBox.size.height > - layerBox.size.height + self.bounce.height then
                --定位于反弹下边
                newPos = ccp(0, contentBox.size.height - layerBox.size.height + self.bounce.height);
            end
        end
    end

    --返回新位置
    return newPos;
end


--[[
    移动位置
--]]
function List:move(x, y)
    --如果可视范围大于滑动列表，也是不可滑动
    if (self.direction == DIRECTION.horizontal) then
        if (self.contentSize.width <= self.maskLayer:boundingBox().size.width and
            self.endId >= self.amountOfCells) then
            return;
        end
    elseif (self.direction == DIRECTION.vertical and
            self.endId >= self.amountOfCells) then
        if (self.contentSize.height <= self.maskLayer:boundingBox().size.height) then
            return;
        end
    end

    --获取遮罩内容位置，getPostion返回的是x，y两个值
    local pos = ccp(self.maskContent:getPosition());
    --存放移动值
    local movePos = {x = nil, y = nil,};

    --根据滑动方向滑动
    if self.direction == DIRECTION.horizontal then
        movePos = {x = x - self.lastPosition.x, y = 0,};
    elseif self.direction == DIRECTION.vertical then
        movePos = {x = 0, y = y - self.lastPosition.y,};
    end

    --记录位置供下次使用
    self.lastPosition = {x = x, y = y,};

    --算好新的位置
    local newPos = ccpAdd(pos, ccp(movePos.x, movePos.y));

    --传入新位置，判断是否允许
    newPos = self:limitMove(newPos);

    --如果位置没有发生变化，直接跳出就好了啦
    --有可能一直拉，但是到了边缘不能移动
    if pos.x == newPos.x and pos.y == newPos.y then
        return
    end

    --真正的移动
    self:setMaskContentPos(newPos);
end


--touchMoved回调函数
function List:onTouchMoved(x, y)
    --移动过，改变状态
    self.isDraged = true;

    return self:move(x, y);
end


--[[
    返回位置对应的cell+distacne的CCRect
--]
function List:locatePosition(pos)
    local locatePos = ccp(self.locateRect.x, self.locateRect.y);

    for i = self.startId, self.endId, 1 do
        local rect = nil;
        local box = self.cells[i];

        --根据方向转换对应的CCRect
        if (self.direction == DIRECTION.horizontal) then
            rect = CCRectMake(pos.x + box.x, pos.y + box.y,
                                box.width + self.distance.width, box.height);
        elseif (self.direction == DIRECTION.vertical) then
            rect = CCRectMake(pos.x + box.x, pos.y + box.y - (box.height + self.distance.height),
                                box.width, box.height + self.distance.height);
        end

        if (rect:containsPoint(locatePos)) then
            local newPos = nil;

            if (self.direction == DIRECTION.horizontal) then
                newPos = ccpAdd(pos, ccp(-pos.x - box.x + locatePos.x, 0));
            elseif (self.direction == DIRECTION.vertical) then
                newPos = ccpAdd(pos, ccp(0, locatePos.y - (pos.x + box.x)));
            end

            return newPos;
        end
    end

    --没找到说明出错了
    CCMessageBox("posToRect出错！", "函数出错：");
    return nil;
end
--]]


--[[
    该算法将cell后面的间隔也算为cell的一部分，就是说算一半的时候是cell+间隔的一半
    注意，传入的定位值是不需要算上间隔的，因为是在这里转换的
--]]
function List:moveToLocate()
    --获取遮罩内容位置，getPostion返回的是x，y两个值
    local pos = ccp(self.maskContent:getPosition());
    local newPos = nil;

    --根据滑动方向来确定定位
    if self.direction == DIRECTION.horizontal then
        --算出位置的距离差，求余数得到现在占取的部分
        local x =(self.locateRect.x - pos.x) % (self.locateRect.width + self.distance.width);

        --判断需要的是哪个值，在于判断有没有占了一半以上的位置
        --当占取的部分大于一半的时候，应该往左移，否则向右
        if x > (self.locateRect.width + self.distance.width) / 2 then
            x = - (self.locateRect.width + self.distance.width - x);
        end

        newPos = ccpAdd(pos, ccp(x, 0));
    --X轴和Y轴的算法是一样的
    elseif self.direction == DIRECTION.vertical then
        --算出位置的距离差，求余数得到现在占取的部分
        local y =(pos.y - self.locateRect.y) % (self.locateRect.height + self.distance.height);

        --判断需要的是哪个值，在于判断有没有占了一半以上的位置
        --当占取的部分大于一半的时候，应该往上移，否则向下
        if y > (self.locateRect.height + self.distance.height) / 2 then
            y = - (self.locateRect.height + self.distance.height - y);
        end

        --注意这里取反了，所以上面就不用改了
        newPos = ccpAdd(pos, ccp(0, - y));
    end

    --移动
    self:setMaskContentPos(newPos);   
end


--[[
    bounce效果
--]]
function List:moveBounce()
    --记录boudingbox
    local layerBox = self.maskLayer:boundingBox();
    local contentPos = ccp(self.maskContent:getPosition());
    local contentBox = CCRectMake(contentPos.x, contentPos.y, 
                                    self.contentSize.width, self.contentSize.height);

    --如果大小不符合，则不可以移动
    if (self.direction == DIRECTION.horizontal) then
        if (contentBox.size.width <= layerBox.size.width) then
            return false;
        end
    elseif (self.direction == DIRECTION.vertical) then
        if (contentBox.size.height <= layerBox.size.height) then
            return false;
        end
    end

    --超过位置则回归，需要判断是哪部分超出了
    local newPos = nil;
    --横向判断
    if self.direction == DIRECTION.horizontal then
        if contentBox.origin.x > 0 then
            newPos = ccp(0, 0);
        elseif contentBox.origin.x + contentBox.size.width < layerBox.size.width then
            newPos = ccp(- contentBox.size.width + layerBox.size.width, 0);
        end
    --竖向判断
    elseif self.direction == DIRECTION.vertical then
        if contentBox.origin.y < 0 then
            newPos = ccp(0, 0);
        elseif contentBox.origin.y - contentBox.size.height > - layerBox.size.height then
            newPos = ccp(0, contentBox.size.height - layerBox.size.height);
        end
    end

    --如果没有位置变化，则直接跳出
    if newPos == nil then
        return
    end

    --移动
    self:setMaskContentPos(newPos);
end


--[[
    加速移动
--]]
function List:accelerateMove(dt)
    --记录时间
    self.time = self.time + dt;

    --计算移动距离
    local movePos = {x = nil, y = nil,};

    --根据滑动方向滑动
    if self.direction == DIRECTION.horizontal then
        movePos = {x = self.speed.x * dt, y = 0};
    elseif self.direction == DIRECTION.vertical then
        movePos = {x = 0, y = self.speed.y * dt};
    end

    --减少速度
    self.speed = {x = self.speed.x * (1 - SLIDE.acceleration),
                    y = self.speed.y * (1 - SLIDE.acceleration)};

    --获取原来位置
    local pos = ccp(self.maskContent:getPosition());

    --计算新位置
    local newPos = ccpAdd(pos, ccp(movePos.x, movePos.y));

    --判断新位置是否可以移动
    newPos = self:limitMove(newPos);

    --当不可移动，或者时间超过后，结束加速滑动
    if newPos.x == pos.x and newPos.y == pos.y or
        self.time > SLIDE.endTime then
        --判断是使用定位还是回弹结束位移
        if self.boolLocate then
            self:moveToLocate();
        else
            self:moveBounce();
        end

        --取消加速移动
        CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.accelerateHandle);
        self.accelerateHandle = nil;
    else
        --移位
        self:setMaskContentPos(newPos);
    end
end


--[[
    加速移动的计算
--]]
function List:accelerateCount()
    --计算加速总位移
    local removeing = {x = self.lastPosition.x - self.refreshPosition.x,
                        y = self.lastPosition.y - self.refreshPosition.y};

    self.speed = {x = removeing.x * SLIDE.moveScale, 
                    y = removeing.y * SLIDE.moveScale};

    self.time = 0;

    --开始加速移动
    self.accelerateHandle =
        CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(register(self, self.accelerateMove), 0, false)
end


--[[
    touchEnded回调函数
--]]
function List:onTouchEnded(x, y)
    --停止刷新位置
    CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.refreshHandle);

    --获取鼠标点击处的id
    local id = self:idOfCellTouched(x, y);

    --仅当坐标在触摸范围内才调用鼠标松开函数
    if self.maskLayer:boundingBox():containsPoint(ccp(x, y)) then
        if id == 0 then
            log("没有点击到cell！");
        else
            self:cellTouchedUp(id);
        end
    end

    --判断有没有移动过鼠标
    --没有就执行click
    if not self.isDraged then
        if id ~= 0 then
            self:cellClicked(id);
        end
    end

    --初始化点击状态为false
    self.isTouched = false;
    
    --开始加速移动
    return self:accelerateCount();
end


--[[
    onTouch回调函数
--]]
function List:onTouch(event, x, y)
    --先将坐标转换为以遮罩层物体的坐标，也就是self
    local pos = self:convertToNodeSpace(ccp(x, y));
    --使用转换好的坐标
    x, y = pos.x, pos.y;

    if (event == "began") then
        return self:onTouchBegan(x, y);
    elseif (event == "moved") then
        return self:onTouchMoved(x, y);
    elseif (event == "ended" or event == "cancelled") then
        return self:onTouchEnded(x, y);
    end
end


--[[
    将绑定触摸事件单独抽出来，方便重写
--]]
function List:registerTouchHandler()
    --暂定，可以重写
    self.maskLayer:registerScriptTouchHandler(register(self, self.onTouch),
                                                
                                                false, 0, true);

    return true;
end


--[[
    设置遮罩层
--]]
function List:setMaskLayer()
    --默认是不使用大小
    self.maskLayer = CCLayer:create();
    --开启锚点在左下角（其实不一定，只需要统一即可）
    --其实默认就是没开启锚点，不过默认锚点为(0.5, 0.5)
    self.maskLayer:ignoreAnchorPointForPosition(false);
    self.maskLayer:setAnchorPoint(ccp(0, 0));

    --绑定onTouch回调
    self:registerTouchHandler();
    self.maskLayer:setTouchEnabled(true);

    self:setStencil(self.maskLayer);

    return true;
end


--[[
    添加cell，返回需要添加的cell，传入的是cell的id（需要重写）
--]]
function List:addCell(id)
    local cell = CCNode:create();
    return cell;
end


--[[
    返回cell的大小，有了这个便可以直接写死maskContent的大小
    但是暂时不使用这种算法，因为灵活性很差
    返回的是宽度和高度（需要重写）
    此接口是为了提供给对滑动列表进行大范围移动而开设的（暂时没提供该功能）
--]]
function List:cellSize(id)
    return 0, 0;
end


--移除cell，传入的是cell的id
function List:removeCell(id)
    --需要先判断是否加载
    if (self.cells[id].isLoaded) then
        --根据id移除cell
        self.maskContent:removeChildByTag(id, true);
        self.cells[id].isLoaded = false;
    end
end


--[[
    更新maskContent的大小
--]]
function List:updateMaskContent()
    --横向判断，高为0
    if self.direction == DIRECTION.horizontal then
        self.contentSize = CCSizeMake(self.cells[self.endId].x + 
                                        self.cells[self.endId].width, 0);
    --竖向判断，宽为0
    elseif self.direction == DIRECTION.vertical then
        self.contentSize = CCSizeMake(0,- self.cells[self.endId].y + 
                                        self.cells[self.endId].height);
    end
end


--[[
    删除cell，并且更新位置
    cell的数量会在这里减少
--]]
function List:removeCellWithIndex(idx)
    --取数不能为1以下或者比现有cell的数量还大
    if (idx < 1 or idx > self.amountOfCells) then
        error("删除cell的可取数字有错！");

        return nil;
    else
        self.amountOfCells = self.amountOfCells - 1;
    end

    --根据删除位置做相应的处理
    if (idx > self.endId) then
        --这种情况最简单，完全没有影响
    else
        if (idx >= self.startId) then
            --这种需要删除显示的cell
            self:removeCell(idx);
        elseif (idx >= 1) then
            --startId应该减1
            self.startId = self.startId - 1;

            --这种因为不在视野里，但是又影响了位置，所以应该手动更改位置
            local pos = ccp(self.maskContent:getPosition());
            local newPos = nil;

            --根据方向设置新位置
            if (self.direction == DIRECTION.horizontal) then
                newPos = ccpAdd(pos, ccp(self.cells[idx].width + self.distance.width, 0));
            elseif (self.direction == DIRECTION.vertical) then
                newPos = ccpAdd(pos, ccp(0, self.cells[idx].height + self.distance.height));
            end

            self:setMaskContentPos(newPos);
        end

        self.endId = self.endId - 1;

        --将cell往前移
        for id = idx, self.endId, 1 do
            local cell = self.maskContent:getChildByTag(id + 1);
            --因为可能cell并不在显示里面，所以可能得到的cell为空
            if (cell) then
                cell:setTag(id);
                self.cells[id].isLoaded = self.cells[id + 1].isLoaded;
            end
        end
        --最后的那个cell的加载设为false
        if (self.endId < self.amountOfCells) then
            self.cells[self.endId + 1].isLoaded = false;
        end

        --更新CellsBouningBox
        self:updateCellsBouningBox(idx);
    end
end


--[[
    插入一个新的cell，并且更新这个cell后面cell的位置
    不用自己再次设定cell的数量，这里会增加
    这里仅仅给出idx，cell还是在addCell()中获取
--]]
function List:insertCellWithIndex(idx)
    --取数不能为1以下或者比现有cell的数量+1还大
    if (idx < 1 or idx > self.amountOfCells + 1) then
        error("添加cell的可取数字有错！");

        return;
    else
        self.amountOfCells = self.amountOfCells + 1;
    end

    --如果一开始数量为0的话，就直接添加就好了
    if (self.amountOfCells == 1) then
        self.startId = 1;

        --这时候就可以直接使用addCellBottomRight来处理就好
        self:addCellBottomRight();

        return;
    end

    --计算cells新的信息
    local size = CCSizeMake(self:cellSize(idx));
    self.cells[idx].width = size.width;
    self.cells[idx].height = size.height;

    if (idx >= self.startId) then
        --也没有什么特别
    elseif (idx > 0) then
        --startId应该加1
        self.startId = self.startId + 1;

        --这种因为不在视野里，但是又影响了位置，所以应该手动更改位置
        local pos = ccp(self.maskContent:getPosition());
        local newPos = nil;

        --根据方向设置新位置
        if (self.direction == DIRECTION.horizontal) then
            newPos = ccpAdd(pos, ccp(- self.cells[idx].width - self.distance.width, 0));
        elseif (self.direction == DIRECTION.vertical) then
            newPos = ccpAdd(pos, ccp(0, - self.cells[idx].height - self.distance.height));
        end

        self:setMaskContentPos(newPos);
    end

    self.endId = self.endId + 1;
    --原来可能为空
    self.cells[self.endId] = self.cells[self.endId] or {};

    --遍历idx所在位置之后（包括idx）的cell，让其tag往后移
    for id = self.endId, idx + 1, -1 do
        local cell = self.maskContent:getChildByTag(id - 1);
        --因为可能cell并不在显示里面，所以可能得到的cell为空
        if (cell) then
            cell:setTag(id);
            self.cells[id].isLoaded = self.cells[id - 1].isLoaded;
        end
    end

    --将加载标识为false
    self.cells[idx].isLoaded =false;

    --更新CellsBouningBox，前面已经对idx的位置更新了
    self:updateCellsBouningBox(idx + 1);
end


--[[
    根据idx，更新idx（包括该idx）后面的cell的大小位置直到endId
    不更新内容
--]]
function List:updateCellsBouningBox(idx)
    --遍历从idx开始到endId，只需要变化位置
    for id = idx, self.endId, 1 do
        local cell = self.maskContent:getChildByTag(id);
        --仅在cell不为空的情况下才设置
        if (cell) then
            --设置cell的位置
            local box = self.cells[id - 1];
            local size = CCSizeMake(self:cellSize(id));

            --根据方向设置位置
            local newPos = nil;
            --横向判断
            if self.direction == DIRECTION.horizontal then
                --第一个的左边不需要添加距离差
                if id == 1 then
                    newPos = ccp(0, 0);
                else
                    newPos = ccp(box.x + box.width + self.distance.width, 0);
                end
            --竖向判断
            elseif self.direction == DIRECTION.vertical then
                --第一个的下边不需要添加距离差
                if id == 1 then
                    newPos = ccp(0, 0);
                else
                    newPos = ccp(0, box.y - box.height - self.distance.height);
                end
            end

            cell:setPosition(newPos);

            --保存cell的信息
            self.cells[id] = {x = newPos.x, y = newPos.y, width = size.width, height = size.height,
                                isLoaded = self.cells[id].isLoaded};
        end
    end

    --更新列表
    self:updateMaskContent();
    self:setMaskContentPos();
end


--[[
    加载cells
--]]
function List:loadCells()
    --遍历来加载
    for i = self.startId, self.endId, 1 do
        --判断是否已经加载，已经加载的就不需要加载了
        if (not self.cells[i].isLoaded) then
            local cell = self:addCell(i);
            --加载完，则改为已经加载了该cell
            self.cells[i].isLoaded = true;
            cell:setPosition(ccp(self.cells[i].x, self.cells[i].y));
            cell:setTag(i);

            if (self.direction == DIRECTION.horizontal) then
                cell:setAnchorPoint(ccp(0, 0));
            elseif (self.direction == DIRECTION.vertical) then
                cell:setAnchorPoint(ccp(0, 1));
            end

            self.maskContent:addChild(cell);
        end 
    end
end


--[[
    重新加载，相当于刷新
--]]
function List:reload()
    --删除加载的
    for i = self.startId, self.endId, 1 do
        self:removeCell(i);
    end

    --重新加载
    self:setMaskContentPos();
end


--[[
    在上边或者左边删除cell
--]]
function List:removeCellTopLeft()
    --不符合删除条件，跳出
    if self.startId >= self.endId then
        return
    end

    self:removeCell(self.startId);
    self.startId = self.startId + 1;
end


--[[
    在上边或者左边添加cell
--]]
function List:addCellTopLeft()
    --不符合添加条件，跳出
    if self.startId <= 1 then
        return;
    end

    self.startId = self.startId - 1;

    --计算cell的位置
    local box = self.cells[self.startId + 1];
    local size = CCSizeMake(self:cellSize(self.startId));
    --根据方向设置位置
    local pos = nil;
    --横向判断
    if self.direction == DIRECTION.horizontal then
        pos = ccp(box.x - size.width - self.distance.width, 0);
    --竖向判断
    elseif self.direction == DIRECTION.vertical then
        pos = ccp(0, box.y + size.height + self.distance.height);
    end

    --保存cell的信息
    self.cells[self.startId] = {x = pos.x, y = pos.y, width = size.width, height = size.height};
end


--[[
    在下边或者右边添加cell
--]]
function List:removeCellBottomRight()
    --不符合删除条件，跳出
    if self.endId <= self.startId then
        return
    end

    self:removeCell(self.endId);
    self.endId = self.endId - 1;

    --这个位置将会影响maskContent的大小，所以需要update
    self:updateMaskContent();
end


--[[
    在下边或者右边添加cell
--]]
function List:addCellBottomRight()
    --不符合添加条件，跳出
    if self.endId >= self.amountOfCells then
        return;
    end

    self.endId = self.endId + 1;

    --计算cell的位置
    local box = self.cells[self.endId - 1];
    local size = CCSizeMake(self:cellSize(self.endId));
    --根据方向设置位置
    local pos = nil;

    --横向判断
    if self.direction == DIRECTION.horizontal then
        --第一个的左边不需要添加距离差
        if self.endId == 1 then
            pos = ccp(0, 0);
        else
            pos = ccp(box.x + box.width + self.distance.width, 0);
        end
    --竖向判断
    elseif self.direction == DIRECTION.vertical then
        --第一个的下边不需要添加距离差
        if self.endId == 1 then
            pos = ccp(0, 0);
        else
            pos = ccp(0, box.y - box.height - self.distance.height);
        end
    end

     --保存cell的boundingbox
    self.cells[self.endId] = {x = pos.x, y = pos.y, width = size.width, height = size.height};

    --更新maskContent大小
    self:updateMaskContent();
end


--[[
    初始化一开始需要显示的cells
--]]
function List:initMaskContent()
    --初始化endId为0，然后往后添加
    self.endId = 0;
    --要先创建一个表，否则无法使用
    self.cells = {};
    --初始化0这个位置，因为需要使用到
    self.cells[0] = {x = 0, y = 0, width = 0, height = 0};
    --初始化amountOfCells + 1 这个位置，也是要用到的，提防出错
    --取无限大
    self.cells[self.amountOfCells + 1] = {x = 9999, y = -9999, width = 9999, height = 9999};
    --初始化contentSize大小为(0, 0)
    self.contentSize = CCSizeMake(0, 0);

    --开始往后添加cells
    --因为初始位置为(0, 0)，所以忽略位置
    --预加载多一个，所以就算endId是建好的也可以拿来判断
    while self.endId < self.amountOfCells and
        self.cells[self.endId].x < self.maskLayer:boundingBox().size.width and
        self.cells[self.endId].y > - self.maskLayer:boundingBox().size.height
            do
        self:addCellBottomRight();
    end

    --判断列表是否为空，空的话startId应该为0
    if self.endId ~= 0 then
        self.startId = 1;
    else
        self.startId = 0;
    end

    --更新列表
    self:setMaskContentPos();
end


--[[
    进入的时候初始化被遮罩层
    不能在新建的时候就初始化，必须在进入场景的时候，否则因为某些参数未设置而报错
--]]
function List:onNodeEvent(event)
    if event == "enter" then
        return self:initMaskContent();
    elseif event == "cleanup" then
        return self:delete();
    end

    return false;
end


--[[
    设置被遮罩层
--]]
function List:setMaskContent()
    self.maskContent = CCNode:create();
    self:addChild(self.maskContent);
    --绑定初始化回调函数，在进入的时候初始化
    self.maskContent:registerScriptHandler(register(self, self.onNodeEvent));
end


--[[
    设置bounce大小
--]]
function List:setBounce(width, height)
    self.bounce ={width = width, height = height};
end


--[[
    设置遮罩层大小
--]]
function List:setViewSize(width, height)
    self:setClippingSize(CCSizeMake(width, height));
end


--[[
    设置方向
    横向锚点在左下角
    纵向锚点在左上角
--]]
function List:setDirection(direction)
    if (direction == DIRECTION.horizontal) then
        self.direction = DIRECTION.horizontal;
        self.maskLayer:setAnchorPoint(ccp(0, 0));
    elseif (direction == DIRECTION.vertical) then
        self.direction = DIRECTION.vertical;
        self.maskLayer:setAnchorPoint(ccp(0, 1));
    end

    return true;
end


--[[
    设置定位框大小
    因为大小是相对大小，如果只是对父物体进行缩放的话，对子物体的相对大小没有影响
    所以传入的值应该是相对大小的值，而不是缩放后的值
--]]
function List:setLocateRect(x, y, width, height, ratio)
    --local scale = self:getScale();
    self.locateRect = {x = x, y = y, width = width, height = height, ratio = ratio};

    --设置的同时开启定位开关
    self.boolLocate = true;
end


--[[
    设置定位开关状态
--]]
function List:setLocateEnabled(enabled)
    if (type(enabled) ~= "boolean") then
        error("参数错误！");

        return false;
    end

    self.boolLocate = enabled;
end


--[[
    设置cell之间的距离差
--]]
function List:setDistance(width, height)
    self.distance = {width = width, height = height,};
end


--[[
    设置cell的数量
--]]
function List:setAmountOfCells(num)
    self.amountOfCells = num;
end