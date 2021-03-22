--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 28/7/2020
-- Time: 上午9:08
-- To change this template use File | Settings | File Templates.
--
local require = require
local ngx = ngx
local core = require('gateway.core')
local balancer = require("gateway.models.balancer")
local app = require("gateway.models.app")
local router = require("gateway.models.router")
local plugin = require("gateway.models.plugin")


local _M = {}



---- 初始化
function _M.http_init()
    require("resty.core") -- 开启resty.core
end

--- work 级别的初始化
function _M.http_init_worker()
    core.config.local_conf(true) --- load cofig.yaml
    app.init_http_worker()
    balancer.init_http_worker()
    plugin.init_http_worker() --- 在router 之前
end

---------------------------/ 根路径 配置开始-------------------
--- rewriter 阶段
function _M.http_rewrite_phase()
end

--- access阶段,注意下面代码调用顺序不能改变
function _M.http_access_phase()
    --[[local args = core.util.get_args()
    if args then
        core.log.info("args => " , core.json.encode_json(args))
    end]]
    local ngx_ctx = ngx.ctx
    local gateway_ctx = ngx_ctx.gateway_ctx

    if not gateway_ctx then
        gateway_ctx = core.tablepool.fetch("gateway_ctx", 0, 5) --- table pool， 可以重复利用，所有request 共享
        ngx_ctx.gateway_ctx = gateway_ctx
    end


    plugin.run_global("rewrite",gateway_ctx)
    plugin.run_global("access",gateway_ctx)
    router.match(gateway_ctx)  --- 匹配路由

    local plugins = plugin.filter(gateway_ctx) ---过滤匹配router 的所有过滤器
    plugin.run("rewrite",plugins,gateway_ctx)
    plugin.run("access",plugins,gateway_ctx)
end

----balancer 阶段
function _M.http_balancer_phase()
    --- 如果设置自己的balancer  ，就执行自己的balancer 插件
    local gateway_ctx = ngx.ctx.gateway_ctx

    if gateway_ctx and not gateway_ctx.balancer then
        plugin.run("balancer", nil, gateway_ctx)
        if gateway_ctx.balancer then
            return
        end
    end

    --- 否则执行 默认的 balancer.

    balancer.run(gateway_ctx)
end


---header_filter 阶段
function _M.http_header_filter_phase()
    plugin.run_global("header_filter")
    plugin.run("header_filter")
end

---body_filter 阶段
function _M.http_body_filter_phase()
    plugin.run_global("body_filter")
    plugin.run("body_filter")
end

--- log 阶段
function _M.http_log_phase()
    plugin.run_global("log")
    plugin.run("log")

    --- 释放资源
    local ngx_ctx = ngx.ctx
    local gateway_ctx = ngx_ctx.gateway_ctx
    if gateway_ctx then
        if gateway_ctx.matched_plugins then
            core.tablepool.release("plugins", gateway_ctx.matched_plugins)
        end
        core.tablepool.release("gateway_ctx", gateway_ctx)
    end
end


---- /gateway/plgins 匹配开始
function _M.plugin_match_router()
    plugin.match()
end
function _M.plugin_rewrite_phase()
    plugin.rewrite()
end
function _M.plugin_header_filter_phase()
    plugin.header_filter()
end

return _M
