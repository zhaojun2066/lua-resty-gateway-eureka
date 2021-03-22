--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 4/3/2021
-- Time: 下午7:30
-- To change this template use File | Settings | File Templates.
-- 注册路由，读取配置文件，配置文件的优先级 要高于注册中心规则默认的路由规则
-- app 转换为 默认路由 和 upstream

---
local require = require
local ngx = ngx
local pairs = pairs
local radix = require("resty.radixtree")
local core = require('gateway.core')
local app = require('gateway.models.app')
local get_method = ngx.req.get_method

local cache_version



local radixtree_routers

local router_array


local function matched_handler(gateway_ctx,server)
    gateway_ctx.matched_router = server
end

local function creat_radixtree_router()
    local server_list = app.get_server_list()
    if not server_list then
        return
    end

    if not router_array then
        router_array = core.table.new(500,0)
    else
        core.table.clear(router_array)
    end

    for _,server in ipairs(server_list) do
        core.log.error('servername=>',server.name,',paht=>',core.json.encode_json(server.paths) )
        core.table.insert(router_array,{
            paths = server.paths,
            handler = function (gateway_ctx)
                matched_handler(gateway_ctx,server)
            end
        })
    end

    radixtree_routers = radix.new(router_array)
end

local function match(gateway_ctx)
    local current_server_version = app.get_server_version()
    if not cache_version or cache_version ~= current_server_version then
        creat_radixtree_router()
        cache_version = current_server_version
    end

    local  match_opts = core.table.new(4,0)
    local method = get_method()
    match_opts.method = method
    match_opts.host = ngx.var.host
    match_opts.remote_addr = core.util.get_ip()
    match_opts.vars = ngx.var
    local uri = ngx.var.uri

    local ok = radixtree_routers:dispatch(uri, match_opts,gateway_ctx)
    if not ok then
        core.util.cors()
        core.log.error("未匹配到任何路由，the uri => " , uri,", method=> " , method)
        return core.response.exit(404,{
            msg="未匹配到任何路由，the uri => " .. uri .. ", method=> " .. method
        })
    end

    return true
end

local _M = {}
_M.match = match
return _M

