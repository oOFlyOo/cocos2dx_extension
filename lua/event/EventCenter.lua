--[[
    观察者模式，用于绑定信息，并且发送信息
    使用单例模式
    
    msg和target决定了唯一的func和pri
    必须注意以上的要求，否则会出错
--]]
require "LuaScript/commons/math"
--[[
    属性
--]]
EventCenter =
{
    --自身对象
    instance = nil,
    --注册的函数及对象的存储
    scriptObserver =
    {
        --msg存着一个priority的优先级数组
        --而priority又是一个存着包含多个{observer, script}的数组
        msg = {},
    },

    --相对于scirptObserver[msg][priority]的暂存值
    tempArray = {},
    --已经读取到的位置
    tempKey = nil,
}


--[[
    EventCenter类
--]]
EventCenter = class("EventCenter");


--[[
    如果没有新建对象，则新建
    最终返回对象
--]]
function EventCenter:getInstance()
    if (not self.instance) then
        local instance = self:new();
        if (instance and instance:init()) then
            self.instance = instance;
        else
            error("获取EventCenter失败！");

            instance = nil;
        end
    end

    return self.instance;
end


--[[
    初始化
--]]
function EventCenter:init()
    self.instance = nil;
    self.scriptObserver = {};
    self.tempArray = {};
    self.tempKey = nil;

    return true;
end


--[[
    删除单例
--]]
function EventCenter:destroyInstance()
    self.instance = nil;

    return true;
end


--[[
    注册观察者
    可以不给出pri，不给出的情况下默认为0
    pri越小，优先级越大
--]]
function EventCenter:registerScriptObserver(msg, target, func, pri)
    --检测参数是否为空，空的情况下直接退出
    if (not msg or not target or type(func) ~= "function") then
        if (msg) then
            error(string.format("消息%s：其它参数错误！", msg));
        else
            error(string.format("消息：%s 为空！", msg));
        end

        return false;
    end

    --没给出优先级的情况下，设为0
    if (not pri) then
        pri = 0;
    end

    --需要判断该msg的表是否已经创建了
    if (not self.scriptObserver[msg]) then
        self.scriptObserver[msg] = {};
    end

    --需要判断该msg下的pri表是否已经创建了
    if (not self.scriptObserver[msg][pri]) then
        self.scriptObserver[msg][pri] = {};
    end

    --判断该注册的函数是否已经注册
    local isExist = self:isExist(msg, target);

    --如果已经存在，则跳出，不会再存
    if (isExist) then
        log("消息：%s 已存在，请不要重复注册！", msg);

        return false;
    end

    table.insert(self.scriptObserver[msg][pri], {observer = target, script = func});
end


--[[
    判断对应的msg下是否有对应的target
--]]
function EventCenter:isExist(msg, target)
    for pri, scriobss in pairs(self.scriptObserver[msg]) do
        key = self:isExistWithPriority(msg, target, pri);

        if (key) then
            return true;
        end
    end

    return false;
end


--[[
    遍历表，看对应的msg，pri下是否有对应的target
    有的话返回key, target和func
    没有的话返回nil，即可以根据key的值来判断是否存在

    因为取消函数的时候不会给出优先级，所以注意不要给出不同优先级的同一注册函数
    否则这里返回的信息会错乱
--]]
function EventCenter:isExistWithPriority(msg, target, pri)
    for k, scriobs in ipairs(self.scriptObserver[msg][pri]) do
        --有对应的对象返回存在的值
        if (scriobs.observer == target) then
            return k, scriobs.observer, scriobs.script;
        end
    end

    --来到这说明不存在
    return nil;
end


--[[
    返回优先级的排序
    因为在Lua里面pairs的遍历是根据hash值得，而不是根据数字的大小
--]]
function EventCenter:sort(msg)
    return sortWithKey(self.scriptObserver[msg]);
end


--[[
    发送消息
--]]
function EventCenter:postNotification(msg, ...)
    --检查参数
    if (not msg) then
        error("发送消息的参数为空，错误！");

        return false;
    end

    --如果此消息不存在，则直接退出
    if (not self.scriptObserver[msg]) then
        log("消息：%s 不存在，发送失败！", msg);

        return false;
    end

    --获取优先级的排序
    local sortPri = self:sort(msg);

    --根据优先级，遍历执行函数
    for k, pri in ipairs(sortPri) do
        --存储值，以免在post里面移除了自身，则数组会乱序产生bug
        local temp = {};
        for k, v in pairs(self.scriptObserver[msg][pri]) do
            temp[k] = v;
        end
        self.tempArray = temp;

        for k, scriobs in ipairs(self.tempArray) do
            --保存遍历到的位置，存储起来
            self.tempKey = k;

            local obj = scriobs.observer;
            local func = scriobs.script;
            func(obj, ...); 
        end

        self.tempArray = {};
        self.tempKey = nil;
    end

    return true;
end


--[[
    取消注册
--]]
function EventCenter:unRegisterScriptObserver(msg, target)
    --判断参数是否为空
    if (not msg or not target) then
        if (msg) then
            error(string.format("消息%s：其它参数错误！", msg));
        else
            error("消息msg为空！");
        end

        return false;
    end

    --如果此消息不存在，则直接退出
    if (not self.scriptObserver[msg]) then
        log("消息：%s 不存在，取消注册失败！", msg);

        return false;
    end

    --用来保存pri
    local key = nil;

    --遍历消息表，获取pri和对应的observer表
    for pri, scriobs in pairs(self.scriptObserver[msg]) do
        key = self:isExistWithPriority(msg, target, pri);

        --如果key为非nil的话，则删掉表，并且退出函数
        if (key) then
            table.remove(scriobs, key);

            --如果正在遍历，那么也应该移除暂存表
            if (self.tempKey) then
                if (self.tempArray == scriobs and self.tempKey < key) then
                    talbe.remove(self.tempArray, key);
                end
            end

            --如果优先级表空了，则变回nil
            if (not next(self.scriptObserver[msg][pri])) then
                self.scriptObserver[msg][pri] = nil;
            end

            --如果信息表空了，则变回nil
            if (not next(self.scriptObserver[msg])) then
                self.scriptObserver[msg] = nil;
            end

            return true;
        end
    end

    --如果没有获取到key值，说明该函数不存在，跳出函数
    if (not key) then
        log("消息：%s 存在！，但是注册对象不存在", msg);

        return false;
    end
end