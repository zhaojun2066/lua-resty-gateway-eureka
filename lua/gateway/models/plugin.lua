--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 28/7/2020
-- Time: 下午5:43
-- 初始化、添加更新删除插件，热加载实现
--

local require = require
local ngx = ngx
local core = require('gateway.core')
local get_method = ngx.req.get_method
local pkg_loaded    = package.loaded
local table_clear = core.table.clear
local table_insert = core.table.insert
local table_sort =  core.table.sort
local table_new = core.table.new
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local pkg_name_prefix = "gateway.plugins."
local radix = require("resty.radixtree")

local local_plugins = table_new(20,0) --- router plugin  router级别的plugin
local local_plugin_hash = table_new(0,20) --- router plugin  router级别的plugin
local local_global_plugins = table_new(10,0)--- global plugin  全局plugin
local plugin_routers = table_new(10,0) --- plugin 所需要的router ，是网关自身的


local function sort_plugin(l, r)
    return l.priority > r.priority
end

local plugin_rdx_routers
--- 加载和插件相关的路由，如获取token等
local function load_plugins_routers()
    local router_array = core.table.new(10,0)
    --core.log.info("plugin_routers size=> ", #plugin_routers)
    for _,router_data  in ipairs(plugin_routers)  do
        core.table.insert(router_array,{
            paths = router_data.uris or router_data.uri,
            methods = router_data.methods,
            handler = function (...)
                local code ,body = router_data.handler(...)
                if code or body then
                    core.response.exit(code, body)
                end
            end
        })
    end
    --core.log.info("router_array size=> ", #router_array)
    plugin_rdx_routers = radix.new(router_array)
end

--- 加载所有的plugin
local function load_plugins()
    table_clear(local_global_plugins)
    table_clear(local_plugins)
    table_clear(plugin_routers)
    local local_config = core.config.local_conf()
    local plugin_config_array = local_config.plugins
    if not plugin_config_array then
        core.log.error(" faild to load plugins" )
        return
    end
    for _,plugin_cofing in ipairs(plugin_config_array) do

        local enable = plugin_cofing.enable or false
        if enable then
            local name = plugin_cofing.name
            core.log.info("init plugin name=> ",name)
            local pkg_name = pkg_name_prefix .. name
            --- 装载之前先卸载
            pkg_loaded[pkg_name] = nil
            local ok, plugin = pcall(require, pkg_name)
            if not ok then
                core.log.error("failed to load plugin [", name, "] err: ", plugin)
                return
            end
            if not plugin.priority then
                core.log.error("invalid plugin [", name, "], missing field: priority")
                return
            end
            plugin.name = name
            local api =  plugin.api --- plugin 需要的api path ，也是需要注册到routers里
            if api then
                local api_routes = api()
                for _, route in ipairs(api_routes) do
                    core.table.insert(plugin_routers, {
                        methods = route.methods,
                        uri = route.uri,
                        handler = function (...)
                            local code, body = route.handler(...)
                            if code or body then
                                core.response.exit(code, body)
                            end
                        end
                    })
                end
            end

            local scope = plugin_cofing.scope
            if scope and scope == "global" then
                table_insert(local_global_plugins,plugin)
            else
                local_plugin_hash[name] = plugin
                table_insert(local_plugins,plugin)
            end
            --- 执行plugin 的初始化操作
            if plugin.init then
                plugin.init()
            end
        end
    end

    if #local_plugins > 0 then
        table_sort(local_plugins, sort_plugin)
    end
    if #local_global_plugins > 0 then
        table_sort(local_global_plugins, sort_plugin)
    end
    if #plugin_routers > 0 then
        table_sort(local_global_plugins, sort_plugin)
    end
    load_plugins_routers()
end

local function get_plugin(name)
    return local_plugin_hash[name]
end

---- router的plugin在 ngx.ctx中，执行某个阶段的plugins 所对应的方法
local function run_plugins(phase,plugins,gateway_ctx)
    gateway_ctx = gateway_ctx or ngx.ctx.gateway_ctx
    if not gateway_ctx then
        return
    end

    plugins = plugins or gateway_ctx.matched_plugins
    if not plugins then
        return
    end

    for _,plugin_obj in ipairs(plugins) do
        local plugin = plugin_obj["plugin"]
        if plugin[phase] then
            core.log.info("run filter plugin => " , plugin.name)
            plugin[phase](plugin_obj["conf"],gateway_ctx)
        end
    end
end


--- 执行全局的plugin ，这些plugin 和router无关
local function run_global_plugins(phase,gateway_ctx)
    gateway_ctx = gateway_ctx or ngx.ctx.gateway_ctx
    if not gateway_ctx then
        return
    end
    for _,plugin in ipairs(local_global_plugins) do
        if plugin[phase] then
            plugin[phase]({},gateway_ctx)
        end
    end
end


--- 过滤当前匹配router 要执行的plugin ，最后存储在ngx.ctx 中
local function filter(gateway_ctx)
    ----合并plugin
    --- 拿到匹配的router，过滤出该router 需要执行 plugin
    local matched_router = gateway_ctx.matched_router

    local filter_plugins_hash = table_new(0,32)

    local router_plugins = matched_router.plugins
    if router_plugins then
        for name,param_obj in pairs(router_plugins) do
            filter_plugins_hash[name] = param_obj
        end
    end

    ---  相当于按照之前的排序
   --- local filter_plugins = table_new(32,0)
    local filter_plugins = core.tablepool.fetch("plugins", 32, 0)
    for _,plugin in ipairs(local_plugins) do
        local plugin_name = plugin.name
        local conf = filter_plugins_hash[plugin_name]
        if conf then
            local filter_plugin = {}
            filter_plugin["conf"] = conf
            filter_plugin["plugin"] = plugin
            core.log.info("filter plugin => " , plugin.name)
            table_insert(filter_plugins,filter_plugin)
        end
    end
    if #filter_plugins>0 then
        gateway_ctx.matched_plugins = filter_plugins
    end

    return filter_plugins
end




local function match()
    local  match_opts = core.table.new(4,0)
    match_opts.method = get_method()
    match_opts.host = ngx.var.host
    match_opts.remote_addr = core.util.get_ip()
    match_opts.vars = ngx.var
    local uri = ngx.var.uri

    local ok = plugin_rdx_routers:dispatch(uri, match_opts)
    if not ok then
        core.log.error("未匹配到任何插件路由，the uri => " , uri)
        return core.response.exit(404,{
            msg="未匹配到任何插件路由，the uri => " .. uri
        })
    end

    return true
end

local _M = {}

---- 下面是对外透露的方法

_M.init_http_worker = function()
    local load =  core.timer.new("load_plugins_timer",load_plugins,{delay = 0})
    load:once()
end
--- 获得plugin 对应的router 或者叫接口

--- 执行全局插件
_M.run_global = run_global_plugins
--- 执行router 级别的插件
_M.run = run_plugins
--- 过滤匹配router所需要的插件
_M.filter = filter
_M.match = match
_M.get_plugin = get_plugin


---- options 直接返回200
function _M.rewrite()
    if ngx.var.request_method == "OPTIONS" then
        core.response.exit(200)
    end
end

--- 设置响应头
function _M.header_filter()
    core.response.add_header("Access-Control-Allow-Methods", "*")
    core.response.add_header("Access-Control-Allow-Origin", "*")
    core.response.add_header("Access-Control-Max-Age", 5)
    core.response.add_header("Access-Control-Expose-Headers", "*")
    core.response.add_header("Access-Control-Allow-Headers", "*")
    core.response.add_header("Access-Control-Allow-Credentials", false)
end
return _M