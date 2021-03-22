--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 24/12/2019
-- Time: 下午2:52
-- To change this template use File | Settings | File Templates.
--

local require = require
local rapidjson = require('rapidjson')
local decode_json = rapidjson.decode
local encode_json = rapidjson.encode


local  _M = {}

function _M.decode_json(str_data)
   return decode_json(str_data)
end

function _M.encode_json(table_obj)
    return encode_json(table_obj)
end

function _M.to_json_empty_array()
    return encode_json(rapidjson.array())
end
function _M.to_json_empty_object()
    return encode_json(rapidjson.object())
end
return _M

