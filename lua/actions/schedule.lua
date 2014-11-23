--[[
    使用action来代替schedule
--]]


--[[
    获取延迟时间来优化
--]]
function intervalDelay()
    local exTime = CCDirector:sharedDirector():getAnimationInterval();

    return exTime * 2;
end


--[[
    每隔一段时间便执行
--]]
function schedule(node, callback, delay)
    local delay = CCDelayTime:create(delay)
    local callfunc = CCCallFuncN:create(callback)
    local sequence = CCSequence:createWithTwoActions(delay, callfunc)
    local action = CCRepeatForever:create(sequence)
    node:runAction(action)
    return action
end


--[[
    延迟执行
--]]
function performWithDelay(node, callback, delay)
    local delay = CCDelayTime:create(delay)
    local callfunc = CCCallFuncN:create(callback)
    local sequence = CCSequence:createWithTwoActions(delay, callfunc)
    node:runAction(sequence)
    return sequence
end