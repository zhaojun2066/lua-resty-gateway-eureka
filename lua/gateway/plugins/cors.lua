--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 17/9/2020
-- Time: 下午2:16
-- To change this template use File | Settings | File Templates.
-- 跨域

local ngx = ngx
local require = require
local core    = require("gateway.core")
local get_headers = ngx.req.get_headers

local schema = {
    type = "object",
    properties = {
        allow_origins = {
            description =
            "you can use '*' to allow all origins when no credentials," ..
                    "'**' to allow forcefully(it will bring some security risks, be carefully)," ..
                    "multiple origin use ',' to split. default: *.",
            type = "string",
            default = "*"
        },
        allow_methods = {
            description =
            "you can use '*' to allow all methods when no credentials and '**'," ..
                    "'**' to allow forcefully(it will bring some security risks, be carefully)," ..
                    "multiple method use ',' to split. default: *.",
            type = "string",
            default = "*"
        },
        allow_headers = {
            description =
            "you can use '*' to allow all header when no credentials," ..
                    "'**' to allow forcefully(it will bring some security risks, be carefully)," ..
                    "multiple header use ',' to split. default: *.",
            type = "string",
            default = "*"
        },
        expose_headers = {
            description =
            "you can use '*' to expose all header when no credentials," ..
                    "multiple header use ',' to split. default: *.",
            type = "string",
            default = "*"
        },
        max_age = {
            description =
            "maximum number of seconds the results can be cached." ..
                    "-1 mean no cached,the max value is depend on browser," ..
                    "more detail plz check MDN. default: 5.",
            type = "integer",
            default = 5
        },
        allow_credential = {
            description =
            "allow client append crendential. according to CORS specification," ..
                    "if you set this option to 'true', you can not use '*' for other options.",
            type = "boolean",
            default = false
        }
    }
}

local plugin_name = "cors"

local _M = {
    version = 0.1,
    priority = 4100,
    type = "cors",
    name = plugin_name,
}



---- options 直接返回200
function _M.rewrite(conf, gateway_ctx)
    if ngx.var.request_method == "OPTIONS" then
        core.response.exit(200)
    end
end

--- 设置响应头
function _M.header_filter(conf,gateway_ctx)
    core.util.cors()
end


return _M