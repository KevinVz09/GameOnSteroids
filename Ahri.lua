local UtilsManager = {}
local ImmobileBuffs  = {}
local WaypointManager = {}
local AllyTeam = GetTeam(myHero)
local aa_wind, aa_anim, move_next = 0, 0, 0
local focus_target = nil

menu = MenuConfig("GSO", "GamSterOn Ahri")
menu:KeyBinding("combo", "Combo", 32)
menu:Menu("f", "Focus List")
menu:ColorPick("c", "Color", {255,255,0,0})

OnIssueOrder(function(order)
        if order.flag == 3 then
                local t = GetTickCount()
                local s = GetAttackSpeed(myHero) * GetBaseAttackSpeed(myHero)
                aa_wind = t+( 200 / s )
                aa_anim = t+( 1000 / s )
        end
        if order.flag == 2 then
                move_next = GetTickCount() + 175
        end
end)

OnLoad(function()
        for i, enemy in ipairs(GetEnemyHeroes()) do
                local name = GetObjectName(enemy)
                menu.f:Boolean(name, name, true)
                WaypointManager[GetNetworkID(enemy)] = { dir = {}, time = 0, from = {}, to = {}, dist = 0 }
                UtilsManager[GetNetworkID(enemy)] = { CanMove = true, IsMoving = false, LastStopMoveTime = 0, IsAttacking = false, AALast = 0, AACastDelay = 0, IsImmobile = false, Immobile = {} }
        end
        ImmobileBuffs = { [GetBuffTypeList().Stun] = true, [GetBuffTypeList().Taunt] = true, [GetBuffTypeList().Snare] = true, [GetBuffTypeList().Fear] = true, [GetBuffTypeList().Charm] = true, [GetBuffTypeList().Suppression] = true, [GetBuffTypeList().Flee] = true, [GetBuffTypeList().Knockup] = true, [GetBuffTypeList().Knockback] = true }
end)

OnProcessWaypoint(function(unit,waypoint)
        local id = GetNetworkID(unit)
        if WaypointManager[id] then
                if waypoint.index == 2 then
                        WaypointManager[id].from = waypoint.position
                        WaypointManager[id].time = GetTickCount()
                end
                if waypoint.index == 1 then
                        if GetTickCount() < WaypointManager[id].time + 25 then
                                UtilsManager[id].CanMove = true
                                local t = waypoint.position
                                WaypointManager[id].to = t
                                local f = WaypointManager[id].from
                                local a = t.x - f.x
                                local b = t.z - f.z
                                local c = math.sqrt(a*a+b*b)
                                WaypointManager[id].dist = c
                                WaypointManager[id].dir = { x = a/c, z = b/c }
                                UtilsManager[id].IsMoving = true
                        else
                                UtilsManager[id].CanMove = false
                                UtilsManager[id].LastStopMoveTime = GetTickCount()
                                UtilsManager[id].IsMoving = false
                        end
                end
        end
end)

OnProcessSpellAttack(function(unit, aa)
        local id = GetNetworkID(unit)
        if UtilsManager[id] then
                UtilsManager[id].AACastDelay = aa.windUpTime*1000
                UtilsManager[id].AALast = GetTickCount()
                UtilsManager[id].IsAttacking = true
        end
end)

OnUpdateBuff(function(unit, buff)
        local id = GetNetworkID(unit)
        if WaypointManager[id] then
                local type = buff.Type
                if ImmobileBuffs[type] then
                        table.insert(UtilsManager[id].Immobile, { StartTime = GetTickCount(), EndTime = buff.ExpireTime } )
                        UtilsManager[id].IsImmobile = true
                end
        end
end)

OnDraw(function(myHero)
        local t = GetTarget(1200)
        if t ~= nil then
                DrawCircle(t.pos, 125, 1, 1, menu.c:Value())
        end
end)

OnRemoveBuff(function(unit, buff)
        local id = GetNetworkID(unit)
        local et = buff.ExpireTime
        if UtilsManager[id] then
                for i, b in ipairs(UtilsManager[id].Immobile) do
                        if b.EndTime == et then
                                table.remove(UtilsManager[id].Immobile, i)
                                break
                        end
                end
        end
end)

function Orb()
        if GetTickCount() > aa_wind + GetLatency() then
                MoveToXYZ(GetMousePos())
        end
        local aat = GetTarget(GetRange(myHero) + GetHitBox(myHero), true)
        if aat ~= nil then
                if GetTickCount() > aa_anim + GetLatency() then
                        AttackUnit(aat)
                end
        end
end

function QLOGIC()
        if Ready(_Q) then
                local qt = GetTarget(975, false)
                if qt ~= nil then
                        local i = InterceptionPoint(qt,1500,0,0.25,880)
                        if i ~= nil and math.sqrt((i.x-qt.pos.x)*(i.x-qt.pos.x)+(i.z-qt.pos.z)* (i.z-qt.pos.z)) < 200  then
                                CastSkillShot(_Q, i)
                        else
                                MoveToXYZ(GetMousePos())
                        end
                else
                        Orb()
                end
        else
                Orb()
        end
end

function WLOGIC()
        if Ready(_W) then
                local wt = GetTarget(550, false)
                if wt ~= nil then
                        CastSpell(_W)
                end
        end
end

function ELOGIC()
        if Ready(_E) then
                local et = GetTarget(975, false)
                if et ~= nil then
                        local i = InterceptionPoint(et,1500,60,0.25,975)
                        if i ~= nil and NoCollision(et, myHero.pos, et.pos, 100, 975) and math.sqrt((i.x-et.pos.x)*(i.x-et.pos.x)+(i.z-et.pos.z)* (i.z-et.pos.z)) < 200 then
                                CastSkillShot(_E, i)
                        end
                end
        end
end

OnTick(function()
        if menu.combo:Value() then
                WLOGIC()
                ELOGIC()
                QLOGIC()
        end
end)

function GetTarget(r, aa)
        local t = nil
        num = 10000
        for i, enemy in pairs(GetEnemyHeroes()) do
                local name = GetObjectName(enemy)
                if ValidTarget(enemy, r) and menu.f[name]:Value() then
                        if GetCurrentHP(enemy) < num then
                                num = GetCurrentHP(enemy)
                                t = enemy
                        end
                end
        end
        if focus_target ~= nil and ValidTarget(focus_target, r) then
                t = focus_target
        end
        if aa then
                if  t ~= nil then
                        r = r + GetHitBox(t)
                end
        end
        return t
end

function NoCollision(x, a, b, h, r)
        no_col = true
        for i, minion in pairs(minionManager.objects) do
                if ValidTarget(minion, r+150) and Collision(a, b, minion, h) then
                        no_col = false
                end
        end
        for i, enemy in pairs(GetEnemyHeroes()) do
                if  GetNetworkID(enemy) ~= GetNetworkID(x) and ValidTarget(minion, r+150) and Collision(a, b, enemy, h) then
                        no_col = false
                end
        end
        return no_col
end
		
function Collision(a, b, c, h)
        local n1 = (a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)
        local n2 = (a.x - c.x) * (a.x - c.x) + (a.z - c.z) * (a.z - c.z)
        local ac = math.sqrt(n2)
        local n3 = (c.x - b.x) * (c.x - b.x) + (c.z - b.z) * (c.z - b.z)
        local a1 = math.acos((n1 + n2 - n3) / math.sqrt(4 * n1 * n2))
        local a2 = math.acos((n1 + n3 - n2) / math.sqrt(4 * n1 * n3))
        if a1 < math.pi / 2 and a2 < 1.75 then
                local x = math.sin(a1) * math.sqrt(n2)
                if x < h then
                        return true
                else
                        return false
                end
        else
                return false
        end
end

OnWndMsg(function(msg, key)
        if key == 1 then
                local obj = nil
                for i, enemy in ipairs(GetEnemyHeroes()) do
                        if ValidTarget(enemy, 2500) then
                                local dist = math.sqrt((enemy.pos.x - GetMousePos().x)*(enemy.pos.x - GetMousePos().x)+(enemy.pos.z- GetMousePos().z)*(enemy.pos.z - GetMousePos().z))
                                if dist < 150 then
                                        obj = enemy
                                        break
                                end
                        end
                end
                focus_target = obj
        end
end)

function InterceptionPoint(t,s,w,d,r)
        local id = GetNetworkID(t)
        if UtilsManager[id].IsImmobile then
                local max = 0
                local tick = 0
                for i, buff in ipairs(UtilsManager[id].Immobile) do
                        if buff.EndTime > max then
                                max = buff.EndTime
                                tick = buff.StartTime
                        end
                end
                if GetTickCount() < tick + max - max/7 then
                        local dist = math.sqrt((myHero.pos.x - t.pos.x)*(myHero.pos.x - t.pos.x)+(myHero.pos.z - t.pos.z)*(myHero.pos.z - t.pos.z))
                        if dist < r then
                                return t.pos
                        end
                else
                        UtilsManager[id].IsImmobile = false
                end
        end
        if UtilsManager[id].IsAttacking then
                local lastaa = UtilsManager[id].AALast
                local windup = UtilsManager[id].AACastDelay
                local dist = math.sqrt((myHero.pos.x - t.pos.x)*(myHero.pos.x - t.pos.x)+(myHero.pos.z - t.pos.z)*(myHero.pos.z - t.pos.z))
                if GetTickCount() < lastaa + windup - windup/7 then
                        if dist < r then
                                return t.pos
                        end
                else
                        UtilsManager[id].IsAttacking = false
                end
        end
        if UtilsManager[id].IsMoving and UtilsManager[id].CanMove then
                local dirx = WaypointManager[id].dir.x
                local dirz = WaypointManager[id].dir.z
                local A = myHero.pos
                local B = t.pos
                for i = 1, 3 do
                        local AB = math.sqrt((A.x - B.x)*(A.x - B.x)+(A.z - B.z)*(A.z - B.z))
                        local tAB = AB / s
                        A = B
                        B.x = B.x + (dirx * GetMoveSpeed(t) * tAB)
                        B.z = B.z + (dirz * GetMoveSpeed(t) * tAB)
                end
                local dist = math.sqrt((myHero.pos.x - B.x)*(myHero.pos.x - B.x)+(myHero.pos.z - B.z)*(myHero.pos.z - B.z))
                if GetTickCount() < WaypointManager[id].time + 100 or GetTickCount() > WaypointManager[id].time + 1000 then
                        if dist < r then
                                return { x = B.x + (dirx * ( ( GetMoveSpeed(t) * d ) - ( w / 2) ) ), z = B.z + (dirz * ( ( GetMoveSpeed(t) * d ) - ( w / 2) ) ) }
                        end
                end
        else
                local dist = math.sqrt((myHero.pos.x - t.pos.x)*(myHero.pos.x - t.pos.x)+(myHero.pos.z - t.pos.z)*(myHero.pos.z - t.pos.z))
                if dist < r then
                        if GetTickCount() < UtilsManager[id].LastStopMoveTime + 100 or dist < 300 then
                                return t.pos
                        end
                end
        end
end
