if WarOfExalts == nil then
	--print ( '[WAROFEXALTS] creating warofexalts game mode' )
	WarOfExalts = class({})
end

--Put links to Lua modifiers here
function WarOfExalts:LinkModifiers()

    --Core game modifiers
    LinkLuaModifier("modifier_client_side_init", "modifiers/modifier_client_side_init", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_woe_base", "modifiers/modifier_woe_base", LUA_MODIFIER_MOTION_NONE) -- Note: this needs to be linked before most other modifiers
    LinkLuaModifier("modifier_woe_stamina_regenerator", "modifiers/modifier_woe_stamina_regenerator", LUA_MODIFIER_MOTION_NONE)
    --LinkLuaModifier("modifier_woe_attributes", "modifiers/modifier_woe_attributes", LUA_MODIFIER_MOTION_NONE)
    
end