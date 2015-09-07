pyromancer_fireball = class({})

function pyromancer_fireball:GetAreaRadius()
    return self:GetSpecialValueFor("area_radius") * 1
end

function pyromancer_fireball:OnSpellStart()
    local height = 70
    local caster = self:GetCaster()
    local data = self:GetSpecials()
    local startPos = caster:GetAbsOrigin() + Vector(0,0,height)
    local maxDistance = data.speed*data.duration
    local forward = (self:GetCursorPosition() - self:GetAbsOrigin()):Normalized()
    forward.z = 0
    local velocity = forward * data.speed
    local endPos = GetGroundPosition(startPos + velocity*data.duration, caster) + Vector(0,0,height)
    --velocity.z = (endPos.z - startPos.z) / data.speed
    --print(startPos, endPos, velocity)
    --util.printTable(data)
    
    function Explode(p)
        local pfx = ParticleManager:CreateParticle("particles/heroes/pyromancer/fireball_explosion.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:SetParticleControl(pfx, 1, p.vel)
        ParticleManager:SetParticleControl(pfx, 3, p.pos)
        ParticleManager:SetParticleControl(pfx, 4, Vector(1,1,1))
        --DebugDrawCircle(p.pos, Vector(200,0,0), 1, self:GetAreaRadius(), false, 2)
        local ents = FindUnitsInRadius(caster:GetTeam(), p.pos, nil, self:GetAreaRadius(), self:GetAbilityTargetTeam(), self:GetAbilityTargetType(), self:GetAbilityTargetFlags(), FIND_ANY_ORDER, false)
        for _, unit in ipairs(ents) do
            ApplyWoeDamage({
                Victim = unit,
                Attacker = caster,
                Ability = self,
                MagicalDamage = self:GetAbilityDamage()
            })
        end
        GridNav:DestroyTreesAroundPoint(p.pos, self:GetAreaRadius(), false)
    end
    
    Projectiles:CreateProjectile({
        Ability             = self,
        EffectName			= "particles/heroes/pyromancer/fireball.vpcf",
        Source				= caster,
        fGroundOffset       = height,
        bGroundLock         = true,
        vSpawnOrigin		= startPos,
        fDistance			= maxDistance,
        fStartRadius		= data.projectile_radius,
        fEndRadius			= data.projectile_radius,
        fExpireTime			= GameRules:GetGameTime() + data.duration,
        vVelocity			= velocity,
        GroundBehavior      = PROJECTILES_NOTHING,
        WallBehavior        = PROJECTILES_NOTHING,
        TreeBehavior        = PROJECTILES_NOTHING,
        UnitBehavior        = PROJECTILES_DESTROY,
        WallBehavior        = PROJECTILES_NOTHING,
        --fChangeDelay        = 0.1,
        bCutTrees           = true,
        bZCheck             = false,
        --draw                = true,
        bProvidesVision     = true,
        iVisionRadius       = data.vision_radius,
        OnFinish = function(p)
            --Explode(p)
        end,
        OnUnitHit   = function(p, unit)
            Explode(p)
        end,
    })
end

