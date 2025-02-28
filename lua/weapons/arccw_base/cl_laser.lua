local mth        = math
local m_log10    = mth.log10
local m_rand     = mth.Rand
local rnd        = render
local SetMat     = rnd.SetMaterial
local DrawBeam   = rnd.DrawBeam
local DrawSprite = rnd.DrawSprite
local cam        = cam

local lasermat = Material("arccw/laser")
local flaremat = Material("effects/whiteflare")
local delta    = 1

function SWEP:DoLaser(world, nocontext)
    world = world or false

    if !nocontext then
        if world then
            cam.Start3D()
        else
            cam.Start3D(EyePos(), EyeAngles(), self:QuickFOVix(self.CurrentViewModelFOV))
        end
    end

    for slot, k in pairs(self.Attachments) do
        if !k.Installed then continue end

        local attach = ArcCW.AttachmentTable[k.Installed]

        if self:GetBuff_Stat("Laser", slot) then
            local color = self:GetBuff_Stat("LaserColor", slot) or attach.ColorOptionsTable[k.ColorOptionIndex or 1]

            if world then
                if !k.WElement then continue end
                self:DrawLaser(attach, k.WElement.Model, color, true)
            else
                if !k.VElement then continue end
                self:DrawLaser(attach, k.VElement.Model, color)
            end
        end
    end

    if self.Lasers then
        if world then
            for _, k in pairs(self.Lasers) do
                self:DrawLaser(k, self.WMModel or self, k.LaserColor, true)
            end
        else
            -- cam.Start3D(nil, nil, self.ViewmodelFOV)
            for _, k in pairs(self.Lasers) do
                self:DrawLaser(k, self:GetOwner():GetViewModel(), k.LaserColor)
            end
            -- cam.End3D()
        end
    end

    if !nocontext then
        cam.End3D()
    end
end

function SWEP:DrawLaser(laser, model, color, world)
    local owner = self:GetOwner()
    local behav = ArcCW.LaserBehavior

    if !owner then return end

    if !IsValid(owner) then return end

    if !model then return end

    if !IsValid(model) then return end

    local att = model:LookupAttachment(laser.LaserBone or "laser")

    att = att == 0 and model:LookupAttachment("muzzle") or att

    local pos, ang, dir

    if att == 0 then
        pos = model:GetPos()
        ang = owner:EyeAngles() + self:GetFreeAimOffset()
        dir = ang:Forward()
    else
        local attdata  = model:GetAttachment(att)
        pos, ang = attdata.Pos, attdata.Ang
        dir      = -ang:Right()
    end

    if world then
        dir = owner:IsNPC() and (-ang:Right()) or dir
    else
        ang:RotateAroundAxis(ang:Up(), 90)

        if self.LaserOffsetAngle then
            ang:RotateAroundAxis(ang:Right(), self.LaserOffsetAngle[1])
            ang:RotateAroundAxis(ang:Up(), self.LaserOffsetAngle[2])
            ang:RotateAroundAxis(ang:Forward(), self.LaserOffsetAngle[3])
        end
        if self.LaserIronsAngle and self:GetActiveSights().IronSight then
            local d = 1 - self:GetSightDelta()
            ang:RotateAroundAxis(ang:Right(), d * self.LaserIronsAngle[1])
            ang:RotateAroundAxis(ang:Up(), d * self.LaserIronsAngle[2])
            ang:RotateAroundAxis(ang:Forward(), d * self.LaserIronsAngle[3])
        end

        dir = ang:Forward()

        local eyeang   = EyeAngles() - self:GetOurViewPunchAngles() + self:GetFreeAimOffset()
        local canlaser = self:GetCurrentFiremode().Mode != 0 and !self:GetReloading() and self:BarrelHitWall() <= 0

        delta = Lerp(0, delta, canlaser and self:GetSightDelta() or 1)

        if self.GuaranteeLaser then
            delta = 1
        else
            delta = self:GetSightDelta()
        end

        dir = Lerp(delta, eyeang:Forward(), dir)
    end

    local beamdir, tracepos = dir, pos

    beamdir = world and (-ang:Right()) or beamdir

    if behav and !world then
        -- local cheap = GetConVar("arccw_cheapscopes"):GetBool()
        local punch = self:GetOurViewPunchAngles()

        ang = EyeAngles() - punch + self:GetFreeAimOffset()

        tracepos = EyePos() - Vector(0, 0, 1)
        pos, dir = tracepos, ang:Forward()
        beamdir  = dir
    end

    local dist = 128

    local tl = {}
    tl.start  = tracepos
    tl.endpos = tracepos + (dir * 33000)
    tl.filter = owner

    local tr = util.TraceLine(tl)

    tl.endpos = tracepos + (beamdir * dist)

    local btr = util.TraceLine(tl)

    local hit    = tr.Hit
    local hitpos = tr.HitPos
    local solid  = tr.StartSolid

    local strength = laser.LaserStrength or 1
    local laserpos = solid and tr.StartPos or hitpos

    laserpos = laserpos - ((EyeAngles() + self:GetFreeAimOffset()):Forward())

    if solid then return end

    local width = m_rand(0.05, 0.1) * strength * 1

    if (!behav or world) and hit then
        SetMat(lasermat)
        local a = 200
        DrawBeam(pos, btr.HitPos, width * 0.3, 1, 0, Color(a, a, a, a))
        DrawBeam(pos, btr.HitPos, width, 1, 0, color)
    end

    if hit and !tr.HitSky then
        local mul = 1 * strength
        mul = m_log10((hitpos - EyePos()):Length()) * strength
        local rad = m_rand(4, 6) * mul
        local glr = rad * m_rand(0.2, 0.3)

        SetMat(flaremat)

        -- if !world then
        --     cam.IgnoreZ(true)
        -- end
        DrawSprite(laserpos, rad, rad, color)
        DrawSprite(laserpos, glr, glr, color_white)

        -- if !world then
        --     cam.IgnoreZ(false)
        -- end
    end
end
