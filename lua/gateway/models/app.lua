--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 3/3/2021
-- Time: 下午5:20
-- To change this template use File | Settings | File Templates.
-- 查询 eureka


local core = require("gateway.core")
local http_new = core.http.new
local ipairs = ipairs
local pairs = pairs
local string_lower = string.lower
local md5 = ngx.md5
local gsub = ngx.re.gsub
local config_local = core.config.local_conf

local pkg_loaded    = package.loaded




local function get_ce_balancer()
    return pkg_loaded["gateway.models.balancer"];
end

local server_version
---- server 信息
local server_list = {}

---- upstream  key-> server_name, value-> node_list
local upstream_hash



local function response_content(res,http_client)
    local content = {}
    if res.status == 200 then
        local reader = res.body_reader
        repeat
            local chunk, err = reader(65536)
            if err then
                ngx.log(ngx.ERR, err)
                break
            end
            if chunk then
                core.table.insert(content,chunk)
            end
        until not chunk
    end
    http_client:set_keepalive()
    return core.table.concat(content)
end

local function http_request(http_client,host,port,uri)
    return http_client:request(
        host,
        port ,
        uri
        ,{
        method="GET",
        headers = {
            ["Accept"] = 'application/json'
        },
    })
end

local function get_app()
    local http_client = http_new()
    local eureka = config_local().eureka
   --[[ local res ,err = http_client:request_uri(
        eureka.address .. ':' ..eureka.port .. eureka.apps_uri
        ,{
        method="GET",
        headers = {
            ["Accept"] = 'application/json'
        },
    })]]
    local hosts = eureka.address
    local res ,err = http_request(http_client,hosts[1],eureka.port,eureka.apps_uri)
    if err then
        core.log.error('get_app err=> ' , err)
        if #hosts > 1 then
            res ,err = http_request(http_client,hosts[2],eureka.port,eureka.apps_uri)
            if err then
                core.log.error('get_app err=> ' , err)
                if #hosts==3 then
                    res ,err = http_request(http_client,hosts[3],eureka.port,eureka.apps_uri)
                    if err then
                        core.log.error('get_app err=> ' , err)
                        return
                    end
                end
            end
        end
    end

    if res  then
        --core.log.error('get_app res.status=> ' ,res.status)
        local body = response_content(res,http_client)
        if not body then
            return
        end
        body = gsub(body,"\\$","value","jo")
        body = gsub(body,"\\@enabled","enabled","jo")
        body = gsub(body,"\\@class","class","jo")
        --core.log.error('get_app body=> ' ,type(body))
        --core.log.error('get_app body=> ' , body)
        local body_json = core.json.decode_json(body)
        local local_server_list = {}
        local local_upstream_hash = {}
        if body_json.applications.application then
            --core.log.error('get_app => ')
            for _, app_info  in ipairs(body_json.applications.application) do
                local upstream = {}
                local server = {}
                local name = string_lower(app_info.name)
                server.name = name
                core.table.insert(local_server_list,server)
                upstream.id = name
                if app_info.instance then
                    local node_list = core.table.new(#app_info.instance,0)
                    local upstream_nodes = core.table.new(0,#app_info.instance)
                    for _, ins in ipairs(app_info.instance) do
                        if ins.status == 'UP' then
                            local node = {}

                            node.ip = ins.ipAddr
                            node.port = ins.port.value
                            node.status_page_url = ins.statusPageUrl
                            node.health_check_url = healthCheckUrl
                            core.table.insert(node_list,node)
                            upstream_nodes[node.ip.. ":" .. node.port] = 1
                            if not ins.metadata.routerpaths then
                                --core.log.error('servername=>',name,' routerpath is null')
                                if not  server.paths then
                                    server.paths = {'/' .. name .. '/*'}
                                end
                            end
                            if ins.metadata.routerpaths and  not  server.paths then
                               -- core.log.error('servername=>',name,' routerpath is ' , ins.metadata.routerpaths)
                               server.paths = core.json.decode_json(ins.metadata.routerpaths)
                            end
                            upstream.upstream_nodes = upstream_nodes


                            --core.log.error('servername=>',name,' => ' , node.ip , ":" .. node.port)
                        end
                    end
                    upstream.type = 'roundrobin' --- 写死轮询
                    upstream.timeout = {
                        connect = 5000,
                        read = 5000,
                        send = 5000
                    }
                    upstream.node_list = node_list
                end
                local str_node_list_value = core.json.encode_json(upstream.node_list)
                upstream.md5 = md5(str_node_list_value)
                local_upstream_hash[name] = upstream
                if upstream_hash and  upstream_hash[name] then
                    if upstream_hash[name].md5 ~= upstream.md5 then
                        upstream_hash[name] = upstream  --- 立即更新老的
                        get_ce_balancer().delete_load_balance_argo_cache(name)
                        core.log.error('servername=>',name,'  - node list is changed...')
                    end
                end
            end
        end

        if not upstream_hash then
            upstream_hash = local_upstream_hash
        else
            --- 循环 local_upstream_hash, 也可以不删除，lru 会把不常用的算法删除
            for server_name, _ in pairs(upstream_hash) do
                --- 如果有下线的服务，直接删除对应的算法cache ，防止无效cache
                if not local_upstream_hash[server_name] then
                    get_ce_balancer().delete_load_balance_argo_cache(server_name)
                    core.log.error('servername=>',server_name,'  node list is all dwon...')
                end
            end

            upstream_hash = local_upstream_hash
        end


        if #local_server_list>0 then
            local local_server_version =  md5(core.json.encode_json(local_server_list))
            if not server_version then -- 可能是第一次初始化
                server_version = local_server_version
                server_list = local_server_list
                return
            end
            if local_server_version ~= server_version then
                server_list = local_server_list
                server_version = local_server_version
                core.log.error('router is changed...')
            end
        end

    end

end

local function get_upstream(server_name)
    return upstream_hash[server_name];
end

local function get_server_version()
    return server_version;
end


local function get_server_list()
    return server_list;
end


local function update_apps()
    local timer = core.timer.new('update_apps',get_app,{
        fail_sleep_time = 3
    })
    timer:recursion()  -- 循环调用 用于看是否增减或者减少服务节点了
end

local _M = {}
_M.init_http_worker = update_apps
_M.get_upstream = get_upstream
_M.get_server_version = get_server_version
_M.get_server_list = get_server_list
return _M


