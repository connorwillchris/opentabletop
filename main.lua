--[[
    OPENTABLETOP

    LICENSE HERE
]]

GAME = {};


--[[
-- MAIN FILE HERE

function lovr.draw(pass)
    pass:cube(0, 1.7, -1, 0.5, lovr.headset.getTime(), 0, 1, 0, "line");
end
]]

--[[ SPACE STRETCH CODE
local motion = {
  pose = lovr.math.newMat4(0,0,0, 1,1,1, 0, 0,1,0),
  left_anchor_vr = lovr.math.newVec3(),
  right_anchor_vr = lovr.math.newVec3(),
}

local palette = {0x0d2b45, 0x203c56, 0x544e68, 0x8d697a, 0xd08159, 0xffaa5e, 0xffd4a3, 0xffecd6}
lovr.graphics.setBackgroundColor(palette[1])

function lovr.update(dt)
    local left_vr  = vec3(motion.pose:mul(lovr.headset.getPosition('hand/left')))
    local right_vr = vec3(motion.pose:mul(lovr.headset.getPosition('hand/right')))
    
    if lovr.headset.wasPressed('hand/left', 'grip') then
        motion.left_anchor_vr:set(left_vr)
    end

    if lovr.headset.wasPressed('hand/right', 'grip') then
        motion.right_anchor_vr:set(right_vr)
    end

    if lovr.headset.isDown('hand/left',  'grip') and
        lovr.headset.isDown('hand/right', 'grip') then
        local x, y, z, scale, _, _, angle, ax, ay, az = motion.pose:unpack()
        -- Scale: get the ratio of distances between anchors over current controllers distance
        local offset_scale = motion.left_anchor_vr:distance(motion.right_anchor_vr) / left_vr:distance(right_vr)
        offset_scale = 1 + (offset_scale - 1)
        scale = scale * offset_scale
        -- the change of scale must also affect the viewpoint location
        x, y, z = x * offset_scale, y * offset_scale, z * offset_scale
        -- Position: the mid-point of anchors is compared to midpoint of current controllers position
        local midpoint_anchor     = vec3(motion.left_anchor_vr):lerp(motion.right_anchor_vr, 0.5)
        local midpoint_controller = vec3(left_vr):lerp(right_vr, 0.5)
        local offset_position = vec3(midpoint_anchor):sub(midpoint_controller)
        x, y, z = x + offset_position.x, y + offset_position.y, z + offset_position.z
        motion.pose:set(x, y, z, scale, scale, scale, angle, ax, ay, az)  -- apply transition and scaling
        -- Rotation: get angle between current controllers and anchors in XZ
        local l_to_r_anchor = vec3(motion.right_anchor_vr):sub(motion.left_anchor_vr)
        local l_to_r_controller = vec3(right_vr):sub(left_vr)
        local sign = 1
        if vec3(l_to_r_controller):cross(vec3(l_to_r_anchor)):dot(vec3(0, 1, 0)) < 0 then
        sign = -1
        end
        l_to_r_anchor = l_to_r_anchor.xz:normalize()
        l_to_r_controller = l_to_r_controller.xz:normalize()
        local cos_angle = l_to_r_controller:dot(l_to_r_anchor)
        cos_angle = math.max(-1, math.min(1, cos_angle))
        local offset_rotation = math.acos(cos_angle) * sign
        motion.pose:rotate(offset_rotation, 0,1,0) -- apply rotation
        -- pose & anchor reset
        if lovr.headset.isDown('hand/right', 'trigger') then
        motion.pose:set()
        motion.left_anchor_vr:set(left_vr)
        motion.right_anchor_vr:set(right_vr)
        end
    end
end


function lovr.draw(pass)
    pass:transform(mat4(motion.pose):invert())
    -- Render hands
    for _, hand in ipairs(lovr.headset.getHands()) do
        -- Whenever pose of hand or head is used, need to account for VR movement
        local poseRW = mat4(lovr.headset.getPose(hand))
        local poseVR = mat4(motion.pose):mul(poseRW)
        if lovr.headset.isDown(hand, 'grip') then
        pass:setColor(palette[6])
        else
        pass:setColor(palette[8])
        end
        poseVR:scale(0.02)
        pass:sphere(poseVR)
    end
    -- An example scene
    local t = lovr.timer.getTime()
    pass:setCullMode('back')
    local step = 0.5
    for x = -5, 5, step do
        for z = -5, 5, step do
        local y = 0.5 * math.sin(t * 0.2 + (x * 0.5)^2 + (z * 0.5)^2)
        pass:setColor(palette[2 + math.floor(y * 10) % (#palette - 1)])
        pass:sphere(x, y, z, step / 2)
        end
    end
end]]

--[[ CUSTOM HAND RIG CODE ]]
hands = {}

local function animateHand(device, skeleton, model, map)
    model:resetNodeTransforms()

    if not skeleton then return end

    -- Get offset of wrist node in the model
    local modelFromWrist = mat4(model:getNodeTransform(map[2]))
    local wristFromModel = mat4(modelFromWrist):invert()

    -- Get offset of wrist joint in the world
    local x, y, z, _, angle, ax, ay, az = unpack(skeleton[2])
    local worldFromWrist = mat4(x, y, z, angle, ax, ay, az)
    local wristFromWorld = mat4(worldFromWrist):invert()

    -- Combine the two into a matrix that will transform the
    -- world-space hand joints into local node poses for the model
    local modelFromWorld = modelFromWrist * wristFromWorld

    -- Transform the nodes
    for index, node in pairs(map) do
        local x, y, z, _, angle, ax, ay, az = unpack(skeleton[index])

        local jointWorld = mat4(x, y, z, angle, ax, ay, az)
        local jointModel = modelFromWorld * jointWorld

        model:setNodeTransform(node, jointModel)
    end

    -- This offsets the root node so the wrist poses line up when the
    -- model is drawn at the hand pose.  Instead of doing this, you
    -- could just draw the model at worldFromWrist * wristFromModel
    local worldFromGrip = mat4(lovr.headset.getPose(device))
    local gripFromWorld = mat4(worldFromGrip):invert()
    model:setNodeTransform(model:getRootNode(), gripFromWorld * worldFromWrist * wristFromModel)
end

function lovr.load()
    for i, hand in ipairs({ 'left', 'right' }) do
        hands[hand] = {
            model = lovr.graphics.newModel("assets/meshes/" .. hand .. '.glb'),
            skeleton = nil
        }
    end

    -- Maps skeleton joint index to node names in the model
    map = {
        [2] = 'wrist',
        [3] = 'thumb-metacarpal',
        [4] = 'thumb-phalanx-proximal',
        [5] = 'thumb-phalanx-distal',

        [7] = 'index-finger-metacarpal',
        [8] = 'index-finger-phalanx-proximal',
        [9] = 'index-finger-phalanx-intermediate',
        [10] = 'index-finger-phalanx-distal',

        [12] = 'middle-finger-metacarpal',
        [13] = 'middle-finger-phalanx-proximal',
        [14] = 'middle-finger-phalanx-intermediate',
        [15] = 'middle-finger-phalanx-distal',

        [17] = 'ring-finger-metacarpal',
        [18] = 'ring-finger-phalanx-proximal',
        [19] = 'ring-finger-phalanx-intermediate',
        [20] = 'ring-finger-phalanx-distal',

        [22] = 'pinky-finger-metacarpal',
        [23] = 'pinky-finger-phalanx-proximal',
        [24] = 'pinky-finger-phalanx-intermediate',
        [25] = 'pinky-finger-phalanx-distal'
    }
end

function lovr.update(dt)
  for device, hand in pairs(hands) do
    hand.skeleton = lovr.headset.getSkeleton(device)
    animateHand(device, hand.skeleton, hand.model, map)
  end
end

function lovr.draw(pass)
    lovr.graphics.setBackgroundColor(0x202224)

    if not hands.left.skeleton and not hands.right.skeleton then
        pass:text('No skelly :(', 0, 1, -1, .1)
        return
    end

    for device, hand in pairs(hands) do
        if hand.skeleton then
            -- Debug dots for joints
            pass:setColor(0x8000ff)
            pass:setDepthWrite(false)
            for i = 1, #hand.skeleton do
                local x, y, z, _, angle, ax, ay, az = unpack(hand.skeleton[i])
                pass:sphere(mat4(x, y, z, angle, ax, ay, az):scale(.003))
            end
            pass:setDepthWrite(true)

            -- Draw the (procedurally animated) wireframe hand model
            local worldFromGrip = mat4(lovr.headset.getPose(device))
            pass:setColor(0xffffff)
            pass:setWireframe(true)
            pass:draw(hand.model, worldFromGrip)
            pass:setWireframe(false)
        end
    end
end
