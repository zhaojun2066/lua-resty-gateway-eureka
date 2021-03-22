--
-- Created by IntelliJ IDEA.
-- User: zhaojun
-- Date: 12/8/2020
-- Time: 下午11:00
-- To change this template use File | Settings | File Templates.
--


local ngx = ngx
local now = ngx.now
local update_time = ngx.update_time


local _M = {}

function _M.now()
    update_time()
    return now()
end


return _M

