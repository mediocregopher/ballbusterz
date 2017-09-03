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
            newDude(1, {
                pos = {x = w/2 - w/4, y = h/2},
                color = {250, 60, 60},
                keys = {"w", "s", "a", "d"},
            }),
            newDude(2, {
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

function newDude(i, opts)
    return {
        i = i,
        pos = opts.pos or {x = w/2, y = h/2},
        radius = opts.radius or 50,

        accel = 90,
        max_speed = 750,
        curr_speed = 0,

        attack_timer = 0,
        attack_duration = 0.1,
        attack_cooldown_timer = 0,
        attack_cooldown_duration = 0.25,
        attack_hitstun_timer = 0,
        attack_knockback_scalar = 1350,
        attack_hitstun_scalar = 0.5, -- multiplied by the intersection amount

        defend_timer = 0,
        defend_duration = 0.5,
        defend_cooldown_timer = 0,
        defend_cooldown_duration = 0.25,

        color = opts.color or {0, 200, 0},
        keys = opts.keys or {"w", "s", "a", "d"},

        shine_sound = opts.shine_sound or love.audio.newSource("assets/shine.wav", "static"),

        state = "neutral", -- "attacking", "defending", "cooldown", "hitstun", "dead"
        --force_cooldown = false,
        --cooldown = 0,
        --action_timer = 0,
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
    return ((xsqr + ysqr) - rsqr) / rsqr
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
                local dude1 = game.dudes[i]
                local dude2 = game.dudes[j]

                -- if neither dude is attacking intersection doesn't matter
                if dude1.state == "attacking" or dude2.state == "attacking" then
                    local int = intersect(dude1, dude2)
                    if int < 0 then
                        int = math.abs(int)
                        -- now int is a value [0,1], with 1 being total overlap
                        if dude1.state == "attacking" and dude2.state == "attacking" then
                            -- negated
                        elseif dude1.state == "defending" then
                            hit(int, dude1, dude2)
                        elseif dude2.state == "defending" then
                            hit(int, dude2, dude1)
                        elseif dude1.state == "attacking" then
                            hit(int, dude1, dude2)
                        elseif dude2.state == "attacking" then
                            hit(int, dude2, dude1)
                        end
                    end
                end
            end
        end

        local inbounds = {}
        for i = 1,#game.dudes do
            local dude = game.dudes[i]
            if dude.pos.x > -1 * dude.radius and dude.pos.x < w + dude.radius then
                table.insert(inbounds, dude)
            end
        end
        if #inbounds == 1 then
            won(inbounds[1])
        end
    end
end

function won(dude)
    game.state = "ending"
    game.winner = dude.i
    game.winner_delay_cur = game.winner_delay
end

function hit(int, dude1, dude2)
    love.audio.play(dude1.shine_sound)
    if dude1.pos.x > dude2.pos.x then
        dude2.curr_speed = -1 * int * dude1.attack_knockback_scalar
    elseif dude1.pos.x < dude2.pos.x then
        dude2.curr_speed = int * dude1.attack_knockback_scalar
    end
    dude2.state = "attack_hitstun"
    dude2.attack_hitstun_timer = dude1.attack_hitstun_scalar * int
    dude1.state = "start_attack_cooldown"
end

function updateDude(dt, dude)
    local w, h = love.graphics.getDimensions()

    local left_key = isDown({dude.keys[KEY_LEFT]})
    local right_key = isDown({dude.keys[KEY_RIGHT]})
    local up_key = isDown({dude.keys[KEY_UP]})
    local down_key = isDown({dude.keys[KEY_DOWN]})

    local movement_delta = 0

    if dude.state == "start_attacking" then
        dude.state = "attacking"
        dude.attack_timer = dude.attack_duration

    elseif dude.state == "start_attack_cooldown" then
        dude.state = "attack_cooldown"
        dude.attack_cooldown_timer = dude.attack_cooldown_duration

    elseif dude.state == "start_defending" then
        dude.state = "defending"
        dude.defend_timer = dude.defend_duration

    elseif dude.state == "start_defend_cooldown" then
        dude.state = "defend_cooldown"
        dude.defend_cooldown_timer = dude.defend_cooldown_duration
    end

    if dude.state == "neutral" then
        if up_key then
            dude.attacked = true
            dude.state = "start_attacking"
        elseif down_key then
            dude.defended = true
            dude.state = "start_defending"
        elseif left_key and not right_key then
            dude.moved = true
            movement_delta = -1 * dude.accel
        elseif right_key and not left_key then
            dude.moved = true
            movement_delta = dude.accel
        end

    elseif dude.state == "attacking" then
        dude.attack_timer = dude.attack_timer - dt
        if not up_key or dude.attack_timer <= 0 then
            dude.state = "start_attack_cooldown"
        end

    elseif dude.state == "attack_cooldown" then
        dude.attack_cooldown_timer = dude.attack_cooldown_timer - dt
        if dude.attack_cooldown_timer <= 0 then
            dude.state = "neutral"
        end

    elseif dude.state == "attack_hitstun" then
        dude.attack_hitstun_timer = dude.attack_hitstun_timer - dt
        if dude.attack_hitstun_timer <= 0 then
            dude.state = "neutral"
        end

    elseif dude.state == "defending" then
        dude.defend_timer = dude.defend_timer - dt
        if not down_key or dude.defend_timer <= 0 then
            dude.state = "start_defend_cooldown"
        end

    elseif dude.state == "defend_cooldown" then
        dude.defend_cooldown_timer = dude.defend_cooldown_timer - dt
        if dude.defend_cooldown_timer <= 0 then
            dude.state = "neutral"
        end

    else
        print("unknown state: "..dude.state)

    end

    -- if there was no player initiated movement slow down automatically
    if movement_delta == 0 and dude.curr_speed ~= 0 then
        local sign = dude.curr_speed / math.abs(dude.curr_speed)
        movement_delta = -1 * sign * dude.accel
    end

    dude.curr_speed = dude.curr_speed + movement_delta

    -- There's no speed limit when in hitstun
    if dude.state ~= "attack_hitstun" then
        dude.curr_speed = math.clamp(-1 * dude.max_speed, dude.curr_speed, dude.max_speed)
    end

    if math.abs(dude.curr_speed) < (dude.accel / 2) then
        dude.curr_speed = 0
    end

    dude.pos.x = dude.pos.x + (dude.curr_speed * dt)
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
    if dude.state == "neutral" then
        -- we good
    elseif dude.state == "attacking" then
        action = "fill"
    elseif dude.state == "defending" then
        alpha = 75
        action = "fill"
    elseif dude.state == "attack_cooldown" or
        dude.state == "attack_hitstun" or
        dude.state == "defend_cooldown" then
        alpha = 60
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
