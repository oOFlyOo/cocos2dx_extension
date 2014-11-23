--[[
	该函数用于注册函数的时候使用
    针对那些有self的函数来使用
--]]


--[[
    封装注册函数，改掉必须自己写函数来调用自身函数，从而不用显示写明self的麻烦

    使用示例：
    registerScript(
                    function (...)
                        return self:doSomething(..)
                    end);
    改为：
    registerScript(register(self, self.doSomething));

    仅使用C++的注册函数或者没有给出对象的Lua注册函数需要使用
    对于给出对象的Lua注册函数，会在内部封装
--]]
function register(obj, func)
    if (not obj or type(func) ~= "function") then
        error("参数错误！");

        return false;
    end

    return
            function (...)
                return func(obj, ...);
            end;
end