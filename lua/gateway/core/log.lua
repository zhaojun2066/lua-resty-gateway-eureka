--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 23/12/2019
-- Time: 上午11:25
-- To change this template use File | Settings | File Templates.
--

local ngx = ngx
local ngx_log  = ngx.log
local ngx_DEBUG= ngx.DEBUG
local DEBUG    = ngx.config.debug
local require  = require
local setmetatable  = setmetatable


local _M = {version = 0.3}


local log_levels = {
    stderr = ngx.STDERR,
    emerg  = ngx.EMERG,
    alert  = ngx.ALERT,
    crit   = ngx.CRIT,
    error  = ngx.ERR,
    warn   = ngx.WARN,
    notice = ngx.NOTICE,
    info   = ngx.INFO
}


do
    local cur_level

    function _M.debug(...)
        if not cur_level then
            cur_level = ngx.config.subsystem == "http" and
                    require "ngx.errlog" .get_sys_filter_level()
        end

        if not DEBUG and cur_level and ngx_DEBUG > cur_level then
            return
        end

        return ngx_log(ngx_DEBUG, ...)
    end

end -- do


setmetatable(_M, {__index = function(self, cmd)
    local cur_level = ngx.config.subsystem == "http" and
            require "ngx.errlog" .get_sys_filter_level()
    local log_level = log_levels[cmd]

    local method
    if cur_level and log_levels[cmd] > cur_level then
        method = function() end
    else
        method = function(...)
            return ngx_log(log_level, ...)
        end
    end

    -- cache the lazily generated method in our
    -- module table
    _M[cmd] = method
    return method
end})


return _M
