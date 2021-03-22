--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 12/8/2020
-- Time: 下午9:18
-- To change this template use File | Settings | File Templates.
--

local require = require
local ngx = ngx
local rapidjson = require('rapidjson')
local encode_json = rapidjson.encode
local ngx_resp = require "ngx.resp"
local ngx_print = ngx.print
local ngx_exit = ngx.exit

local _M = {}


function _M.add_header(key,value)
    if ngx.headers_sent then
       return
    end
    ngx_resp.add_header(key,value)
end

function _M.exit(code,table_body)
    ngx_resp.add_header("Content-Type","application/json;charset=utf-8")

    if code then
        ngx.status = code
    end

    if table_body then
        ngx_print(encode_json(table_body))
    end

    if code then
        return ngx_exit(code)
    end
end


function _M.exit_txt(code,str)
    if code then
        ngx.status = code
    end

    if str then
        ngx_print(str)
    end

    if code then
        return ngx_exit(code)
    end
end


function _M.exit_msg(code,msg)
    ngx_resp.add_header("Content-Type","application/json;charset=utf-8")

    if code then
        ngx.status = code
    end

    if msg then
        ngx_print(encode_json({
            msg = msg
        }))
    end

    if code then
        return ngx_exit(code)
    end
end


return _M