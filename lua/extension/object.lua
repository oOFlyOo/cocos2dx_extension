--[[
    对继承CCObject的物体进行功能上的辅助或者扩展
--]]


require "LuaScript/commons/debug"


--[[
    设置物体透明度
    非递归
--]]
function setOpacity(node, opacity)
    if (not node or not opacity) then
        error("参数错误！");
        
        return false;
    end

    -- 投机取巧
    local nodeWidget = tolua.cast(node, "Widget");
    if (nodeWidget.setOpacity) then
        -- 超出范围不要
        if (opacity > 255) then
            opacity = 255;
        elseif (opacity < 0) then
            opacity = 0;
        end
        nodeWidget:setOpacity(opacity);

        return true;
    end

    return false;
end


--[[
    递归设置物体透明度
--]]
function setOpacityRecursive(node, opacity)
    if (not node or not opacity) then
        error("参数错误！");

        return false;
    end

    setOpacity(node, opacity)

    local children = node:getChildren();
    if (not children) then
        return false;
    end

    local len = children:count();
    for i = 0, len - 1, 1 do
        nodeChild = tolua.cast(children:objectAtIndex(i), "CCNode");

        -- setOpacity(nodeChild, opacity);

        --递归遍历下去
        setOpacityRecursive(nodeChild, opacity);
    end
end


--[[
    获取物体世界坐标
--]]
function getWorldPosition(node)
    if (not node) then
        error("参数错误！");

        return false;
    end

    local fNode = node:getParent();
    local pos = ccp(node:getPosition());

    -- 如果没有父节点，那么它便是世界坐标
    if (not fNode) then
        return pos;
    else
        -- 不适用父节点锚点相关
        return fNode:convertToWorldSpace(pos);
    end
end