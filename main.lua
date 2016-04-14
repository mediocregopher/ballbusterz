pp = require 'inspect'

-- The font to use
fontPath = 'assets/Roboto-Thin.ttf'
titleFont = love.graphics.newFont(fontPath, 128)
instrFont = love.graphics.newFont(fontPath, 48)

KEY_UP = 1
KEY_DOWN = 2
KEY_LEFT = 3
KEY_RIGHT = 4


function newGame()
    game = {
        state = "inplay", -- "ending"
        dudes = {
            newDude({
                pos = {x = w/2 - w/4, y = h/2},
                color = {250, 60, 60},
                keys = {"w", "s", "a", "d"},
            }),
            newDude({
                pos = {x = w/2 + w/4, y = h/2},
                color = {60, 60, 250},
                keys = {"up", "down", "left", "right"},
            }),
        },

        winner = nil,
        winner_delay_cur = 0,
        winner_delay = 2,
    }
    return game
end

function newDude(opts)
    return {
        pos = opts.pos or {x = w/2, y = h/2},
        radius = opts.radius or 50,
        speed = opts.speed or 500,
        slow_speed_mult = opts.slow_speed_mult or 0.2,
        defend_cooldown = opts.defend_cooldown or 0.15,
        defend_max = opts.defend_max or 1,
        attack_min_cooldown = opts.attack_min_cooldown or 0.25,
        attack_max = opts.attack_max or 0.75,
        color = opts.color or {0, 200, 0},
        keys = opts.keys or {"w", "s", "a", "d"},

        state = "moving", -- "attacking", "defending", "cooldown", "dead"
        force_cooldown = false,
        cooldown = 0,
        action_timer = 0,
        moved = false,
        attacked = false,
        defended = false,
    }
end

function love.load()
    love.math.setRandomSeed(love.timer.getTime())
    love.window.setMode(1024, 1024, {
        --fullscreen = true,
        vsync = true,
    })
    love.mouse.setVisible(false)
    love.graphics.setBackgroundColor(248, 252, 255)
    w, h = love.graphics.getDimensions()

    game = newGame()
end

function isDown(keys)
    for _, k in pairs(keys) do
        if love.keyboard.isDown(k) then
            return true
        end
    end
end

function math.clamp(low, n, high) return math.min(math.max(n, low), high) end

function intersect(dude1, dude2)
    local xsqr = dude2.pos.x - dude1.pos.x
    xsqr = xsqr * xsqr
    local ysqr = dude2.pos.y - dude1.pos.y
    ysqr = ysqr * ysqr

    -- We buffer a bit so that the intersection isn't super slight
    local rsqr = dude2.radius + dude1.radius - 3
    rsqr = rsqr * rsqr
    return (xsqr + ysqr) <= rsqr
end

function love.update(dt)
    -- Always want to be able to quit
    if isDown({"escape"}) then
        love.event.quit()
    end

    if game.state == "ending" then
        game.winner_delay_cur = game.winner_delay_cur - dt
        if game.winner_delay_cur <= 0 then
            -- at this point, press up key to continue
            for _, dude in pairs(game.dudes) do
                if isDown({dude.keys[KEY_UP]}) then
                    game = newGame()
                    return
                end
            end
        end

    elseif game.state == "inplay" then
        for _, dude in pairs(game.dudes) do
            updateDude(dt, dude)
        end

        for i = 1,#game.dudes do
            for j = i+1,#game.dudes do
                dude1 = game.dudes[i]
                dude2 = game.dudes[2]
                if intersect(dude1, dude2) then
                    if dude1.state == "attacking" and dude2.state == "attacking" then
                        dude1.force_cooldown = true
                        dude2.force_cooldown = true
                    elseif dude1.state == "defending" or dude2.state == "defending" then
                        -- do nothing
                    elseif dude1.state == "attacking" then
                        game.state = "ending"
                        game.winner = i
                        game.winner_delay_cur = game.winner_delay
                    elseif dude2.state == "attacking" then
                        game.state = "ending"
                        game.winner = j
                        game.winner_delay_cur = game.winner_delay
                    end
                end
            end
        end
    end
end

function updateDude(dt, dude)
    local w, h = love.graphics.getDimensions()
    local minx = dude.radius
    local miny = dude.radius
    local maxx = w - dude.radius
    local maxy = h - dude.radius

    if dude.state == "attacking" then
        dude.action_timer = dude.action_timer + dt
        if not isDown({dude.keys[KEY_UP]}) or dude.action_timer > dude.attack_max or dude.force_cooldown then
            dude.cooldown = math.clamp(dude.attack_min_cooldown, dude.action_timer, 2)
            dude.action_timer = 0
            dude.state = "cooldown"
        end

    elseif dude.state == "defending" then
        dude.action_timer = dude.action_timer + dt
        if not isDown({dude.keys[KEY_DOWN]}) or dude.action_timer > dude.defend_max or dude.force_cooldown then
            dude.cooldown = dude.defend_cooldown
            dude.action_timer = 0
            dude.state = "cooldown"
        end

    elseif dude.state == "cooldown" then
        dude.force_cooldown = false
        dude.cooldown = dude.cooldown - dt
        if dude.cooldown < 0 then
            dude.state = "moving"
        end
    end

    -- If we made this part of the if-else chain above then it wouldn't be
    -- possible to go immediately from cooldown back to attacking/defending
    -- without a frame of moving in between, which creates some weird movement
    if dude.state == "moving" then
        if isDown({dude.keys[KEY_UP]}) then
            dude.attacked = true
            dude.state = "attacking"
        elseif isDown({dude.keys[KEY_DOWN]}) then
            dude.defended = true
            dude.state = "defending"
        end
    end

    local speed = dude.speed
    if dude.state ~= "moving" then
        speed = speed * dude.slow_speed_mult
    end

    if isDown({dude.keys[KEY_LEFT]}) then
        dude.moved = true
        dude.pos.x = math.clamp(minx, dude.pos.x - (dt * speed), maxx)
    elseif isDown({dude.keys[KEY_RIGHT]}) then
        dude.moved = true
        dude.pos.x = math.clamp(minx, dude.pos.x + (dt * speed), maxy)
    end
end

function love.draw()
    love.graphics.setFont(titleFont)
    love.graphics.setColor({100, 100, 100})
    love.graphics.printf("BALL BUSTERZ", 0, h/2 - 300, w, "center")

    if game.state == "ending" then
        local winnerDude = game.dudes[game.winner]
        love.graphics.setColor(winnerDude.color)
        love.graphics.printf("Player " .. tostring(game.winner) .. " wins!", 0, h/2+100, w, "center")
        drawDude(winnerDude)

    elseif game.state == "inplay" then
        for _, dude in pairs(game.dudes) do
            drawDude(dude)
            drawDudeUI(dude)
        end
    end
end

function drawDude(dude)
    local action = "line"
    local width = 5
    local alpha = 255
    if dude.state == "moving" then
        -- we good
    elseif dude.state == "attacking" then
        action = "fill"
    elseif dude.state == "defending" then
        alpha = 75
        action = "fill"
    elseif dude.state == "cooldown" then
        alpha = 60
        --width = 1
    end
    love.graphics.setColor(dude.color[1], dude.color[2], dude.color[3], alpha)
    love.graphics.setLineWidth(width)
    love.graphics.circle(action, dude.pos.x, dude.pos.y, dude.radius, 50)
end

function drawDudeUI(dude)
    love.graphics.setFont(instrFont)
    love.graphics.setColor(dude.color)
    local boxW = 400
    local s = ""
    if not dude.moved then
        s = s .. "Move: " .. dude.keys[KEY_LEFT] .. "/" .. dude.keys[KEY_RIGHT]
    end
    s = s .. "\n"
    if not dude.attacked then
        s = s .. "Attack: " .. dude.keys[KEY_UP]
    end
    s = s .. "\n"
    if not dude.defended then
        s = s .. "Defend: " .. dude.keys[KEY_DOWN]
    end
    love.graphics.printf(s, dude.pos.x-(boxW/2), h/2 + dude.radius + 30, boxW, "center")
end
