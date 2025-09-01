--[[
    DEFAUT COPY-PASTE FOR THE OPENTABLETOP GAME
]]
local M = {};

M.GameObject = {
    x = 0,
    y = 0,
    z = 0,

    new = function(self, x, y, z)
        local obj = {};
        setmetatable(obj, self);
        self.__index = self;
        obj.x = x;
        obj.y = y;
        obj.z = z;
        return obj;
    end,

    --[[print = function(self)
        print("GameObject at (" .. self.x .. ", " .. self.y .. ", " .. self.z .. ")");
    end]]
};

--[[
local a = GAME.GameObject.new(0, 1, 2);
]]
return M;
