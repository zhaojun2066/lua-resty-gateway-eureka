--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 9/11/2020
-- Time: 下午5:14
-- To change this template use File | Settings | File Templates.
--

local log = require("gateway.core.log")
local http = require "resty.http"
local setmetatable = setmetatable
local _M={}

local mt = {
    __index = _M
}
function _M.new()
    local httpc = http:new()
    httpc:set_timeout(15000) -- time unit ms
    local self = {
        httpc = httpc
    }
    return  setmetatable(self,mt)
end



function _M:request_uri(uri,options)
    options.keepalive_timeout = 10000
    options.keepalive_pool = 10
    local res, err =  self.httpc:request_uri(uri,options)
    return res ,err

end


function _M:request(host,port,uri,options)
    local httpc = self.httpc
    httpc:set_timeouts(15000)
    local ok, err = httpc:connect(host, port)
    if not ok then
        log.error('http connect err=> ' ,err, ' fot host=> ', host, ' , port=> ' , port)
        return nil, err
    end
    options.path = uri
    local res, err =  httpc:request(
        options)

    return res , err
end

function _M:set_keepalive()
    local httpc = self.httpc
    if httpc then
        httpc:set_keepalive(10000,200)
    end
end

return _M

