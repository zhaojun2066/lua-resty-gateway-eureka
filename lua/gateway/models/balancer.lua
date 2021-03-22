--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 8/3/2021
-- Time: 下午3:07
-- To change this template use File | Settings | File Templates.
--

local require = require
local ngx = ngx
local pairs = pairs
local string_char = string.char
local string_gsub = string.gsub
local roundrobin  = require("resty.roundrobin")
local resty_chash = require("resty.chash")
local ngx_balancer = require("ngx.balancer")
local lrucache = require ("resty.lrucache")
local core = require('gateway.core')
local app = require('gateway.models.app')


local load_balance_argo_cache  --- upstream 负载算法


--- 实例化 upstream_argo_cache
local function init_upstream_argo_cache()
    local c, err = lrucache.new(15000)  -- allow up to 15000 items in the cache
    if not c then
        core.log.error("failed to create the cache: " , (err or "unknown"))
        return
    end
    load_balance_argo_cache = c
end

--- 删除对应负载的算法cache
local function delete_load_balance_argo_cache(upstream_id)
    load_balance_argo_cache:delete("rr_"..upstream_id)
    load_balance_argo_cache:delete("ch_"..upstream_id)
end


--- 根据设置负载算法选择对应的server
local function choose_server(upstream,nodes)
    local upstream_id = upstream.id
    --core.log.info("upstream=> " , core.json.encode_json(upstream))
   -- core.log.info("all_nodes=> " , core.json.encode_json(nodes))
    local type = upstream.type -- "chash", "roundrobin"
    local server
    core.log.info("upstream.type=> " .. upstream.type)
    if type == "roundrobin" then
        local cache_key ="rr_" .. upstream_id
        local picker = load_balance_argo_cache:get(cache_key)
        if not picker then --- 失效的情况下 ，重新生成picker
            --core.log.info("roundrobin:new")
            local handler = roundrobin:new(nodes)
            picker = {
                handler = handler
            }
            load_balance_argo_cache:set(cache_key,picker,300) ---ttl is second
        end
        local handler = picker.handler
        server = handler:find()
    else
        local str_null = string_char(0)
        local servers, hash_nodes = {}, {}
        for serv, weight in pairs(nodes) do
            local id = string_gsub(serv, ":", str_null)
            servers[id] = serv
            hash_nodes[id] = weight
        end
        local cache_key ="ch_" .. upstream_id
        local hash_key = upstream.key
        if not hash_key then
            core.log.error("hash_key is not config ")
            return core.response.exit_msg(502,"hash 负载均衡 的 hash_key 没有配置 ,upstream : ", upstream.name)
        end

        local picker = load_balance_argo_cache:get(cache_key)
        if not picker then
            picker = {
                handler = resty_chash:new(hash_nodes)
            }
            load_balance_argo_cache:set(cache_key,picker,300) ---ttl is second
        end
        local handler = picker.handler
        local hash_key_value = ngx.var[hash_key]
       -- core.log.error("choose hash_key is => " , hash_key)
       -- core.log.error("choose hash_key_value is => " , hash_key_value)
        local id = handler:find(hash_key_value)
       -- core.log.error("choose id is => " , id)
        server = servers[id]
    end

    return server
end

local function set_balancer_param(upstream,gateway_ctx)

    local timeout = upstream.timeout
    if timeout then
        --- timeout.connect => proxy_connect_timeout
        ----send_timeout and read_timeout are controlled by the same config proxy_timeout
        local ok, err = ngx_balancer.set_timeouts( timeout.connect, timeout.send,
            timeout.read)
        if not ok then
            core.log.error("could not set upstream timeouts: ", err)
        end
    end

    local retries = upstream.retries
    if retries and retries > 0 then
        ngx.ctx.balancer_try_count = (ngx.ctx.balancer_try_count or 0) + 1
        if ngx.ctx.balancer_try_count > 1 then
            local state, code = ngx_balancer.get_last_failure()
            core.log.error("ngx_balancer.get_last_failure() status , code: ", state," , ", code,
                ",ip:port=> ", ngx.ctx.balancer_ip,":",ngx.ctx.balancer_port)
        end


        if ngx.ctx.balancer_try_count ==1 then
            local ok, err = ngx_balancer.set_more_tries(retries)
            if not ok then
                core.log.error("could not set upstream retries: ", err)
            end
        end
    end

    core.log.error("ngx.ctx.balancer_try_count: ", ngx.ctx.balancer_try_count)

end



--- 进行lb
local function run(gateway_ctx)

    local matched_router = gateway_ctx.matched_router
    local matched_upstream = app.get_upstream(matched_router.name)
    local matched_nodes = matched_upstream.upstream_nodes

    local server = choose_server(matched_upstream,matched_nodes)
    core.log.error("choose_server: ", server)

    local ip, port ,err= core.util.parse_addr(server)
    if err then
        core.log.error("failed to set server peer: ", err)
        return core.response.exit_code(502)
    end

    set_balancer_param(matched_upstream,gateway_ctx)

    local ok, err = ngx_balancer.set_current_peer( ip, port )
    if not ok then
        core.log.error("failed to set server peer: ", err)
        return core.response.exit_msg(502,"设置proxy host and port 错误 : ", err)
    end

    core.log.info("set_current_peer: ", ip,":",port)

    --- 写入入当前ip ，下次如果重试，就知道上次失败的ip和端口了
    ngx.ctx.balancer_ip = ip
    ngx.ctx.balancer_port = port
end




local _M = {}

_M.run = run
_M.delete_load_balance_argo_cache = delete_load_balance_argo_cache
_M.init_http_worker = function()
    init_upstream_argo_cache()
end

return _M