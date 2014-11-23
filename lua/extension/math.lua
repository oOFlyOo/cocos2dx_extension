--[[
	此文件用于一些数学运算
--]]


--[[
    对传进来的表根据key进行排序
    返回一个新的表，该表的key是从1开始的数组
    value则是原来的key
--]]
function sortWithKey(sortT)
    --检测传进来的表是否为空
    if (not sortT) then
        log("排序参数为空！");

        return nil;
    end

    --新的表
    local valueT = {};
    --将新数值插进表中
    for k, v in pairs(sortT) do
        table.insert(valueT, k);
    end
    --排序
    table.sort(valueT);

    return valueT;
end


--[[
    对传进来的表根据value进行排序
    返回一个新的表，该表的key是从1开始的数组
    value则是原来的key
--]]
function sortWithValue(sortT)
    --检测传进来的表是否为空
    if (not sortT) then
        log("排序参数为空！");

        return nil;
    end

    --用于中转的table
    local changeT = {};
    --将新数值插进表中
    for k, v in pairs(sortT) do
        table.insert(changeT, {pri = k, value = v});
    end
    --排序，根据“value”字段值来排序
    table.sort(changeT, function (a, b) return a.value < b.value; end);

    --改结构，让其value值为原来的key
    local valueT = {};
    for k, v in ipairs(changeT) do
        valueT[k] = v.pri;
    end

    return valueT;
end


--[[
    复制函数，对传进来的talbe进行复制，并且返回新的table
    进行简单的深复制
    复杂的深复制就没办法了(例如复杂的嵌套，或者userdata，function之类的)
--]]
function copy(data)
    if (type(data) == "table") then
        --原来的数据是一个table，进行深复制
        local newData = {};
        for k, v in pairs (data) do
            newData[k] = copy(v);
        end

        return newData;
    else
        --非表，直接返回
        return data;
    end
end


--[[
    从后面查找子字符串匹配
    查找位置可以限定在start到last之间（包括），这是可选位置
--]]
function findLastOf(strA, strB, start, last)
    if (type(strA) ~= "string" or type(strB) ~= "string") then
        log("参数错误！");

        return false;
    end

    --看看是否有值
    start = start or 1;
    last = last or #strA;

    if (last < start) then
        log("参数错误！");

        return false;
    end

    subStr = string.sub(strA, start, last);
    reverseStr = string.reverse(subStr);
    reverseStrB = string.reverse(strB);

    local startB, lastB = string.find(reverseStr, reverseStrB);

    if (startB) then
        return #subStr - lastB + start, last - startB + 1;
    else
        return false;
    end
end