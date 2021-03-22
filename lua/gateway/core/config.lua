--
-- Created by IntelliJ IDEA.
-- User: jufeng
-- Date: 20/12/2019
-- Time: 上午10:04
-- 读yaml 配置文件 util
--
local require = require
local ngx = ngx
local yaml  = require("tinyyaml")
local log  = require("gateway.core.log")
local io_open = io.open
local type = type
local gateway_env = os.getenv("gateway_env")   ---根据环境读取各个环境的配置信息
local local_conf_path = ngx.config.prefix() .. "conf/config-"..gateway_env..".yaml"
local config_data

local _M = {}
local function read_file(path)
    local file, err = io_open(path, "rb")   -- read as binary mode
    if not file then
        log.error("faild to read config file:" .. path, ", error info:", err)
        return nil, err
    end

    local content = file:read("*a") -- `*a` reads the whole file
    file:close()
    return content
end

function _M.clear_cache()
    config_data = nil
end

--- force  是否强制刷新
function _M.local_conf(force)
    if not force and config_data then
        return config_data
    end

    local yaml_config, err = read_file(local_conf_path)
    if type(yaml_config) ~= "string" then
        return nil, "failed to read config file:" .. err
    end

    config_data = yaml.parse(yaml_config)
    return config_data
end


return _M

