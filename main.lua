--[[
    OPENTABLETOP

    LICENSE HERE
]]

GAME = {};

function lovr.draw(pass)
    pass:cube(0, 1.7, -1, 0.5, lovr.headset.getTime(), 0, 1, 0, "line");
end
