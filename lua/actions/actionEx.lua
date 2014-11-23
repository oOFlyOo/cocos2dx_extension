--[[
    专门用于存放动画
    这里的动画都可以直接通过runAction使用
--]]


require "luaScript/common/debug"
require "luaScript/common/object"
require "luaScript/common/schedule"


--[[
    翻转动画的参数
--]]
FLIP_SEQUENCE =
{
    start = 1,
    over = 2,
}


--[[
    改变透明度动画
    bug1:这个action是不能暂停的
--]]
function fadeFromToAction(duration, fromOpacity, toOpacity, isRecursive)
    if (not duration or not fromOpacity or not toOpacity) then
        error("参数错误！");

        return false;
    end

    local fadeOutEnd = nil;
    local sequence = nil;
    local handler = nil;
    local function fadeOutStart(sender)
        local opacity = fromOpacity;
        local changeOpacity = toOpacity - fromOpacity;
        local time = 0;

        local delay = duration - intervalDelay();
        -- 减过之后可能小于0
        -- 这时候直接变
        if (delay < intervalDelay()) then
            if (isRecursive and sender) then
                setOpacityRecursive(sender, toOpacity);
            elseif (sender) then
                setOpacity(sender, toOpacity);
            end
        else
            local function fadeOut(delta)
                -- 通过检测动作是否存在，检测是否还在播放
                -- 若不检测，这个动画被停止了，或者物体被移除了，将会产生bug
                if (tolua.isnull(sequence)) then
                    return fadeOutEnd();
                end

                if (time < delay) then
                    time = time + delta;
                    opacity = fromOpacity + changeOpacity * (time / delay);

                    if (isRecursive and sender) then
                        setOpacityRecursive(sender, opacity);
                    elseif (sender) then
                        setOpacity(sender, opacity);
                    end
                end
            end

            handler = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(fadeOut, 0, false);
            fadeOut(CCDirector:sharedDirector():getAnimationInterval())
        end

        return true;
    end
    local callBack1 = CCCallFuncN:create(fadeOutStart);
    local delay = CCDelayTime:create(duration);

    function fadeOutEnd(sender)
        if (handler) then
            CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(handler);
        end

        -- 这里再给它设一下值
        -- 考虑到可能已经被释放掉了
        if (isRecursive and sender) then
            setOpacityRecursive(sender, toOpacity);
        elseif (sender) then
            setOpacity(sender, toOpacity);
        end

        return true;
    end
    local callBack2 = CCCallFuncN:create(fadeOutEnd);

    local array = CCArray:create();
    array:addObject(callBack1);
    array:addObject(delay);
    array:addObject(callBack2);
    sequence = CCSequence:create(array);

    return sequence;
end


--[[
    延迟移除
--]]
function delayRemoveAction(delay)
    local function remove(sender)
        sender:removeFromParentAndCleanup(true);

        return true;
    end

    local callFuncN = CCCallFuncN:create(remove);

    local action = nil;
    --如果需要延迟才添加延迟函数
    if (delay and delay > 0) then
        local delay = CCDelayTime:create(delay);
        local array = CCArray:create();
        array:addObject(delay);
        array:addObject(callFuncN);
        action = CCSequence:create(array);
    else
        action = callFuncN;
    end

    return action;
end


--[[
    改变投影回调
--]]
function changeProjectionAction(projection)
    if (not projection) then
        error("参数错误！");

        return false;
    end

    function changeProjection(sender)
        CCDirector:sharedDirector():setProjection(projection);

        return true;
    end

    local callBack = CCCallFuncN:create(changeProjection);

    return callBack;
end


--[[
    翻转动画，从有到消失
--]]
function flipAction(delay, sequence)
    if (not delay or not sequence) then
        error("参数错误！");

        return false;
    end

    local array = CCArray:create();
    if (sequence == FLIP_SEQUENCE.start) then
        local projection = changeProjectionAction(kCCDirectorProjection2D);
        local orbitCamera = CCOrbitCamera:create(delay, 1, 0, 0, 90, 0, 0);

        array:addObject(projection);
        array:addObject(orbitCamera);
    elseif (sequence == FLIP_SEQUENCE.over) then
        local orbitCamera = CCOrbitCamera:create(delay, 1, 0, - 90, 90, 0, 0);
        local projection = changeProjectionAction(kCCDirectorProjectionDefault);

        array:addObject(orbitCamera);
        array:addObject(projection)
    end

    local sequence = CCSequence:create(array);

    return sequence;
end