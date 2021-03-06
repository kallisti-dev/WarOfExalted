require("modifiers/modifier_base")
modifier_pyra_pyromania = class({}, nil, modifier_base)

modifier_pyra_pyromania:Init({
    IsPurgable = false,
    DestroyOnExpire = false,
    DeclareFunctions = { MODIFIER_EVENT_ON_ABILITY_EXECUTED },
    
    IsHidden = function(self)
        return self:GetStackCount() == 0
    end,
    
    Properties = {
        SpellSpeedBonus = function(self)
            return self:GetStackCount() * self:GetAbility():GetSpecialValueFor("spell_speed")
        end
    },
    
    OnCreated = function(self, params)
        if IsServer() then
            self.pfx = ParticleManager:CreateParticle( "particles/units/heroes/hero_lina/lina_fiery_soul.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
            ParticleManager:SetParticleControl( self.pfx, 1, Vector( self:GetStackCount(), 0, 0 ) )
            self:AddParticle( self.pfx, false, false, -1, false, false )
        end
    end,
    
    OnRefresh = function(self, params)
        if IsServer() then
            ParticleManager:SetParticleControl( self.pfx, 1, Vector( self:GetStackCount(), 0, 0 ) )
        end
    end,
    
    OnIntervalThink = function(self)
        if IsServer() then
            self:SetStackCount(0)
            self:StartIntervalThink(-1)
            ParticleManager:SetParticleControl( self.pfx, 1, Vector( self:GetStackCount(), 0, 0 ) )
            self:GetParent():GetSpellSpeed() -- force UI update
        end
    end,
    
    OnAbilityExecuted = function(self, params)
        if IsServer() then
            if params.unit == self:GetParent() then
                if self:GetParent():PassivesDisabled() then
                    return 0
                end
                local ability = params.ability
                local data = self:GetAbility():GetSpecials() 
                if ability ~= nil and ( ability.isWoeAbility and ability:GetKeywords():Has("spell") ) and ( not ability:IsItem() ) and ( not ability:IsToggle() ) then
                    if self:GetStackCount() < data.max_stacks and self:GetParent():SpendStamina(data.stamina_cost) then
                        self:IncrementStackCount()
                    else
                        self:SetStackCount( self:GetStackCount() )
                        self:ForceRefresh()
                    end
                    self:SetDuration(data.duration, true)
                    self:StartIntervalThink(data.duration)
                    self:GetParent():GetSpellSpeed() -- force UI update
                end
            end
        end
        return 0 
    end,
})