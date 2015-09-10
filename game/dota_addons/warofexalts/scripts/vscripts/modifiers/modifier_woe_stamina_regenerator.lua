modifier_woe_stamina_regenerator = class({})

function modifier_woe_stamina_regenerator:IsHidden()
    return true
end

function modifier_woe_stamina_regenerator:IsPurgable()
    return false
end

function modifier_woe_stamina_regenerator:GetAttributes()
    return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_woe_stamina_regenerator:OnCreated(keys)
    if IsServer() then
        self.refreshInterval = keys.refreshInterval or 0.01
        self:StartIntervalThink(self.refreshInterval)
    end
end

function modifier_woe_stamina_regenerator:OnIntervalThink()
    if IsServer() then
        local unit = self:GetParent()
        local stamPerSec = unit:GetStaminaRegen()
        if unit:IsStaminaRecharging() then
            stamPerSec = stamPerSec + unit:GetMaxStamina() * unit:GetStaminaRechargeRate()
        end
        unit:SetStamina(unit:GetStamina() + self.refreshInterval * stamPerSec)
    end
end
