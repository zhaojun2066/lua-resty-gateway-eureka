--
-- Created by IntelliJ IDEA.
-- User: 86186
-- Date: 12/8/2020
-- Time: 下午10:09
-- To change this template use File | Settings | File Templates.
--


local setmetatable = setmetatable
local error = error
local pcall = pcall
local type = type
local string = string
local ngx = ngx
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every
local sleep = ngx.sleep
local resty_lock = require("resty.lock")
local log = require("gateway.core.log")
local time = require("gateway.core.time")


local _M = {}

local mt = {__index = _M}

local function new_lock()
    local lock, err = resty_lock:new("timer_lock")
    if not lock then
        error("failed to create lock: " .. err)
    end
    return lock
end

function _M.new(name, callback, opts)
    if not name then
        error("missing argument: name")
    end
    if not callback or type(callback) ~= "function" then
        error("missing argument: callback or callback is not a function")
    end

    local lock
    if opts.use_lock then
        lock = new_lock()
    end

    local self = {
        name = name,
        callback = callback,
        delay = opts.delay or 0.5,
        lock = lock,
        fail_sleep_time = opts.fail_sleep_time or 0,
        ctx = opts.ctx or {}
    }
    return setmetatable(self, mt)
end


local function callback_fun(self)
    local name = self.name
    local callback = self.callback
    local lock = self.lock
    return function(premature)
        if premature then
            log.error("timer[", name, "] is premature")
            return
        end

        if lock then
            local elapsed, err = lock:lock(name)
            if not elapsed then
                log.info("timer[", name, "] failed to acquire the lock: ", err)
                if self.fail_sleep_time > 0 then
                    sleep(self.fail_sleep_time)
                end
                return
            end
        end

       -- log.info("timer[", name, "] start")
        local start_time = time.now()
        local ok, err = pcall(callback, self.ctx)
        if not ok then
            log.error("failed to run the timer: ", name, " err: ", err)
            if self.fail_sleep_time > 0 then
                sleep(self.fail_sleep_time)
            end
        end

        if lock then
            lock:unlock()
        end

       local ms = time.now() - start_time
       --log.info("timer[", name, "] run finish, take ", string.format("%.2f", ms), "s")
    end
end

local function recursion_fun(self)
    return function()
        callback_fun(self)()
        timer_at(self.delay, recursion_fun(self))
    end
end

-- 执行一次
function _M.once(self)
    return timer_at(self.delay, callback_fun(self))
end

-- 递归循环执行
function _M.recursion(self)
    return timer_at(self.delay, recursion_fun(self))
end

-- 定时间隔执行
function _M.every(self)
    return timer_every(self.delay, callback_fun(self))
end

return _M

