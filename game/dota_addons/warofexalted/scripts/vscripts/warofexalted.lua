--print ('[WAROFEXALTED] warofexalted.lua' )


require("settings") -- import settings parameters

Testing = true
OutOfWorldVector = Vector(11000, 11000, -200)

-- Fill this table up with the required XP per level if you want to change it
XP_PER_LEVEL_TABLE = {}
for i=1,MAX_LEVEL do
    XP_PER_LEVEL_TABLE[i] = i * 100
end

-- Generated from template
if WarOfExalted == nil then
    --print ( '[WAROFEXALTED] creating warofexalted game mode' )
    WarOfExalted = class({})
end

function WarOfExalted:PostLoadPrecache()
    --print("[WAROFEXALTED] Performing Post-Load precache")

    PrecacheUnitByNameAsync("npc_precache_everything", function(...) end)
end

--[[
  This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
  It can be used to initialize state that isn't initializeable in InitWarOfExalted() but needs to be done before everyone loads in.
]]
function WarOfExalted:OnFirstPlayerLoaded()
    --print("[WAROFEXALTED] First Player has loaded")
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function WarOfExalted:OnAllPlayersLoaded()
    --print("[WAROFEXALTED] All Players have loaded into the game")
    for steamID, player in pairs(self.vSteamIds) do
        local playerID = player:GetPlayerID()
        Storage:Get(steamID, function(config, success)
            if not success or config == nil then
                config = { }
            end
            if config.VectorTargetClickDrag == nil then
                config.VectorTargetClickDrag = false
            end
            CustomNetTables:SetTableValue("PlayerConfig", tostring(playerID), config)
        end)
    end
    self:InitClientSideLua()
end

--[[
  This function is called once and only once for every player when they spawn into the game for the first time.  It is also called
  if the player's hero is replaced with a new hero for any reason.  This function is useful for initializing heroes, such as adding
  levels, changing the starting gold, removing/adding abilities, adding physics, etc.

  The hero parameter is the hero entity that just spawned in.
]]
function WarOfExalted:OnHeroInGame(hero)
    --print("[WAROFEXALTED] Hero spawned in game for first time -- " .. hero:GetUnitName())

    if not self.greetPlayers then
        -- At this point a player now has a hero spawned in your map.
        local greetLines = {
            util.color("Welcome to ", "blue") .. util.color(self.addonInfo.addontitle, "red") .. " " .. util.color(self.addonInfo.addonversion, "white"),
            util.color("Lead Developer / Designer: ", "blue") .. util.color(self.addonInfo.addonauthor, "orange"),
            util.color("Artist: ", "blue") .. util.color("Venastoned (Tina Grillo)", "green"),
        }
        -- Send the first greeting in 4 secs.
        Timers:CreateTimer(4, function()
            for _,line in ipairs(greetLines) do
                GameRules:SendCustomMessage(line, 0, 0)
            end
        end)

        self.greetPlayers = true
    end

    -- Store a reference to the player handle inside this hero handle.
    hero.player = PlayerResource:GetPlayer(hero:GetPlayerID())
    -- Store the player's name inside this hero handle.
    hero.playerName = PlayerResource:GetPlayerName(hero:GetPlayerID())
    -- Store this hero handle in this table.
    table.insert(self.vPlayers, hero)

    if Testing then
        Say(nil, "Testing is on.", false)
    end

    --util.initAbilities(hero)

    -- Show a popup with game instructions.
    --ShowGenericPopupToPlayer(hero.player, "#warofexalted_instructions_title", "#warofexalted_instructions_body", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN )

    -- This line for example will set the starting gold of every hero to 500 unreliable gold
    hero:SetGold(STARTING_GOLD, false)

    -- These lines will create an item and add it to the player, effectively ensuring they start with the item
    --local item = CreateItem("item_example_item", hero, hero)
    --hero:AddItem(item)
end

--[[
    This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
    gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
    is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function WarOfExalted:OnGameInProgress()
    --print("[WAROFEXALTED] The game has officially begun")

    Timers:CreateTimer(30, function() -- Start this timer 30 game-time seconds later
        --print("This function is called 30 seconds after the game begins, and every 30 seconds thereafter")
        return 30.0 -- Rerun this timer every 30 game-time seconds
    end)
end

function WarOfExalted:PlayerSay( keys )
    local ply = keys.ply
    local hero = ply:GetAssignedHero()
    local txt = keys.text

    if keys.teamOnly then
        -- This text was team-only.
    end

    if txt == nil or txt == "" then
        return
    end

  -- At this point we have valid text from a player.
    --print("P" .. ply .. " wrote: " .. keys.text)
end

-- Cleanup a player when they leave
function WarOfExalted:OnDisconnect(keys)
    --print('[WAROFEXALTED] Player Disconnected ' .. tostring(keys.userid))
    --util.printTable(keys)

    local name = keys.name
    local networkid = keys.networkid
    local reason = keys.reason
    local userid = keys.userid
end

-- The overall game state has changed
function WarOfExalted:OnGameRulesStateChange(keys)
    --print("[WAROFEXALTED] GameRules State Changed")
    --util.printTable(keys)

    local newState = GameRules:State_Get()
    if newState == DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD then
        self.bSeenWaitForPlayers = true
    elseif newState == DOTA_GAMERULES_STATE_INIT then
        Timers:RemoveTimer("alljointimer")
    elseif newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
        local et = 6
        if self.bSeenWaitForPlayers then
            et = .01
        end
        Timers:CreateTimer("alljointimer", {
            useGameTime = true,
            endTime = et,
            callback = function()
                if PlayerResource:HaveAllPlayersJoined() then
                    WarOfExalted:PostLoadPrecache()
                    WarOfExalted:OnAllPlayersLoaded()
                    return
                end
                return 1
            end})
    elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        WarOfExalted:OnGameInProgress()
    end
end

-- An NPC has spawned somewhere in game.  This includes heroes
function WarOfExalted:OnNPCSpawned(keys)
    --print("[WAROFEXALTED] NPC Spawned")
    --util.printTable(keys)
    local npc = EntIndexToHScript(keys.entindex)
    self:WoeUnitWrapper(npc)
    npc:EachAbility(function(a) self:WoeAbilityWrapper(a) end)

    if npc:IsRealHero() and npc.bFirstSpawned == nil then
        npc.bFirstSpawned = true
        WarOfExalted:OnHeroInGame(npc)
    end
end

-- An entity somewhere has been hurt.  This event fires very often with many units so don't do too many expensive
-- operations here
function WarOfExalted:OnEntityHurt(keys)
    --print("[WAROFEXALTED] Entity Hurt")
    --util.printTable(keys)
    local attacker = EntIndexToHScript(keys.entindex_attacker)
    local victim = EntIndexToHScript(keys.entindex_killed)
end

-- An item was picked up off the ground
function WarOfExalted:OnItemPickedUp(keys)
    --print ( '[WAROFEXALTED] OnItemPickedUp' )
    --util.printTable(keys)

    local heroEntity = EntIndexToHScript(keys.HeroEntityIndex)
    local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
    local player = PlayerResource:GetPlayer(keys.PlayerID)
    local itemName = keys.itemname
    self:WoeAbilityWrapper(itemEntity)
end

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function WarOfExalted:OnPlayerReconnect(keys)
    --print ( '[WAROFEXALTED] OnPlayerReconnect' )
    --util.printTable(keys)
end

-- An item was purchased by a player
function WarOfExalted:OnItemPurchased( keys )
    --print ( '[WAROFEXALTED] OnItemPurchased' )
    --util.printTable(keys)

    -- The playerID of the hero who is buying something
    local pID = keys.PlayerID
    local itemCost = keys.itemcost
    local itemName = keys.itemname
    for _, item in ipairs(Entities:FindAllByName(itemName)) do
        self:WoeAbilityWrapper(item)
    end
end

-- An ability was used by a player
function WarOfExalted:OnAbilityUsed(keys)
    --print('[WAROFEXALTED] AbilityUsed')
    --util.printTable(keys)

    local player = EntIndexToHScript(keys.PlayerID)
    local abilityname = keys.abilityname
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function WarOfExalted:OnNonPlayerUsedAbility(keys)
    --print('[WAROFEXALTED] OnNonPlayerUsedAbility')
    --util.printTable(keys)

    local abilityname=  keys.abilityname
end

-- A player changed their name
function WarOfExalted:OnPlayerChangedName(keys)
    --print('[WAROFEXALTED] OnPlayerChangedName')
    --util.printTable(keys)

    local newName = keys.newname
    local oldName = keys.oldName
end

-- A player leveled up an ability
function WarOfExalted:OnPlayerLearnedAbility( keys)
    --print ('[WAROFEXALTED] OnPlayerLearnedAbility')
    --util.printTable(keys)

    local player = EntIndexToHScript(keys.player)
    local abilityname = keys.abilityname
end

-- A channelled ability finished by either completing or being interrupted
function WarOfExalted:OnAbilityChannelFinished(keys)
    --print ('[WAROFEXALTED] OnAbilityChannelFinished')
    --util.printTable(keys)

    local abilityname = keys.abilityname
    local interrupted = keys.interrupted == 1
end

-- A player leveled up
function WarOfExalted:OnPlayerLevelUp(keys)
    --print ('[WAROFEXALTED] OnPlayerLevelUp')
    --util.printTable(keys)

    local player = EntIndexToHScript(keys.player)
    local level = keys.level
end

-- A player last hit a creep, a tower, or a hero
function WarOfExalted:OnLastHit(keys)
    --print ('[WAROFEXALTED] OnLastHit')
    --util.printTable(keys)

    local isFirstBlood = keys.FirstBlood == 1
    local isHeroKill = keys.HeroKill == 1
    local isTowerKill = keys.TowerKill == 1
    local player = PlayerResource:GetPlayer(keys.PlayerID)
end

-- A tree was cut down by tango, quelling blade, etc
function WarOfExalted:OnTreeCut(keys)
    --print ('[WAROFEXALTED] OnTreeCut')
    --util.printTable(keys)

    local treeX = keys.tree_x
    local treeY = keys.tree_y
end

-- A rune was activated by a player
function WarOfExalted:OnRuneActivated (keys)
    --print ('[WAROFEXALTED] OnRuneActivated')
    --util.printTable(keys)

    local player = PlayerResource:GetPlayer(keys.PlayerID)
    local rune = keys.rune

    --[[ Rune Can be one of the following types
    DOTA_RUNE_DOUBLEDAMAGE
    DOTA_RUNE_HASTE
    DOTA_RUNE_HAUNTED
    DOTA_RUNE_ILLUSION
    DOTA_RUNE_INVISIBILITY
    DOTA_RUNE_MYSTERY
    DOTA_RUNE_RAPIER
    DOTA_RUNE_REGENERATION
    DOTA_RUNE_SPOOKY
    DOTA_RUNE_TURBO
    ]]
end

-- A player took damage from a tower
function WarOfExalted:OnPlayerTakeTowerDamage(keys)
    --print ('[WAROFEXALTED] OnPlayerTakeTowerDamage')
    --util.printTable(keys)

    local player = PlayerResource:GetPlayer(keys.PlayerID)
    local damage = keys.damage
end

-- A player picked a hero
function WarOfExalted:OnPlayerPickHero(keys)
    --print ('[WAROFEXALTED] OnPlayerPickHero')
    --util.printTable(keys)

    local heroClass = keys.hero
    local heroEntity = EntIndexToHScript(keys.heroindex)
    local player = EntIndexToHScript(keys.player)
end

-- A player killed another player in a multi-team context
function WarOfExalted:OnTeamKillCredit(keys)
    --print ('[WAROFEXALTED] OnTeamKillCredit')
    --util.printTable(keys)

    local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
    local victimPlayer = PlayerResource:GetPlayer(keys.victim_userid)
    local numKills = keys.herokills
    local killerTeamNumber = keys.teamnumber
end

-- An entity died
function WarOfExalted:OnEntityKilled( keys )
    --print( '[WAROFEXALTED] OnEntityKilled Called' )
    --util.printTable( keys )

    -- The Unit that was Killed
    local killedUnit = EntIndexToHScript( keys.entindex_killed )
    -- The Killing entity
    local killerEntity = nil

    if keys.entindex_attacker ~= nil then
        killerEntity = EntIndexToHScript( keys.entindex_attacker )
    end

    if killedUnit:IsRealHero() then
        --print ("KILLEDKILLER: " .. killedUnit:GetName() .. " -- " .. killerEntity:GetName())
        if killedUnit:GetTeam() == DOTA_TEAM_BADGUYS and killerEntity:GetTeam() == DOTA_TEAM_GOODGUYS then
            self.nRadiantKills = self.nRadiantKills + 1
            if END_GAME_ON_KILLS and self.nRadiantKills >= KILLS_TO_END_GAME_FOR_TEAM then
                GameRules:SetSafeToLeave( true )
                GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )
            end
        elseif killedUnit:GetTeam() == DOTA_TEAM_GOODGUYS and killerEntity:GetTeam() == DOTA_TEAM_BADGUYS then
            self.nDireKills = self.nDireKills + 1
            if END_GAME_ON_KILLS and self.nDireKills >= KILLS_TO_END_GAME_FOR_TEAM then
                GameRules:SetSafeToLeave( true )
                GameRules:SetGameWinner( DOTA_TEAM_BADGUYS )
            end
        end

        if SHOW_KILLS_ON_TOPBAR then
            GameRules:GetGameModeEntity():SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.nDireKills )
            GameRules:GetGameModeEntity():SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.nRadiantKills )
        end
    end

    -- Put code here to handle when an entity gets killed
end

function WarOfExalted:OnWoeUnitRequest( keys )
    --print("[WAROFEXALTED] OnWoeUnitRequest called")
    --util.printTable(keys)
    local unit = EntIndexToHScript(keys.id)
    if unit then
        keys.isWoeUnit = unit.isWoeUnit
        if unit.isWoeUnit then
            Property.BatchUpdateEvents(unit, function()
                keys.MoveSpeedBase = unit:GetBaseMoveSpeed()
                keys.MoveSpeed = unit:GetIdealSpeed()
                keys.MagicResist = unit:GetMagicResist()
                keys.ArmorBase = unit:GetPhysicalArmorBaseValue()
                keys.Armor = unit:GetPhysicalArmorValue()
                keys.SpellSpeed = unit:GetSpellSpeed()
                keys.MaxStamina = unit:GetMaxStamina()
                keys.CurrentStamina = unit:GetStamina()
                keys.StaminaRechargeDelay = unit:GetStaminaRechargeDelay()
                keys.ForceStaminaRecharge = unit:IsStaminaRechargeForced()
                keys.StaminaTimer = unit:GetStaminaTimer()
                keys.StaminaRegen = unit:GetStaminaRegen()
                --util.mergeTable(keys, unit._props)
            end)
        end
    end
    --util.printTable(keys)
    if keys.playerID then
        CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(keys.playerID), "woe_unit_response", keys)
    else
        CustomGameEventManager:Send_ServerToAllClients("woe_unit_response", keys)
    end
end

function WarOfExalted:OnWoeAbilityRequest(keys)
    local abi = EntIndexToHScript(keys.id)
    if abi then
        keys.isWoeAbility = abi.isWoeAbility
        if abi.isWoeAbility then
            util.mergeTable(keys, abi._woeKeys)
        end
    end
    if keys.playerID then
        CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(keys.playerID), "woe_ability_response", keys)
    else
        CustomGameEventManager:Send_ServerToAllClients("woe_ability_response", keys)
    end
end

function WarOfExalted:OnWoeSaveConfig(keys)
    local steamId = PlayerResource:GetSteamAccountID(keys.playerId)
    local config = CustomNetTables:SetTableValue("PlayerConfig", tostring(keys.playerId), keys.config)
    print("saving config for", keys.playerId)
    util.printTable(config)
    if config ~= nil then
        Storage:Put(steamId, keys.config, function(resultTable, success)
            print("success: ", success)
            util.printTable(resultTable)
        end)
    end
end

--[[
function WarOfExalted:AbilityTuningFilter( keys )
    print("[WAROFEXALTED] AbilityTuningFilter called")
    util.printTable(keys)
end
]]


-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function WarOfExalted:InitWarOfExalted()
    WarOfExalted = self
    local gameMode = GameRules:GetGameModeEntity()
    print('[WAROFEXALTED] Starting to load WarOfExalted gamemode...')
    
    
    CustomNetTables:SetTableValue("GameConfig", "Testing", {value = Testing})
    
    self:LinkModifiers() --Initialize custom Lua modifiers
    
    VectorTarget:Init() --Initialize vector targeting system
    
    --Property.SetDebug(true)
    
    --gameMode:SetAbilityTuningValueFilter(Dynamic_Wrap(WarOfExalted, "AbilityTuningFilter"), self)

    -- Setup rules
    GameRules:SetHeroRespawnEnabled( ENABLE_HERO_RESPAWN )
    GameRules:SetUseUniversalShopMode( UNIVERSAL_SHOP_MODE )
    GameRules:SetSameHeroSelectionEnabled( ALLOW_SAME_HERO_SELECTION )
    GameRules:SetHeroSelectionTime( HERO_SELECTION_TIME )
    GameRules:SetPreGameTime( PRE_GAME_TIME)
    GameRules:SetPostGameTime( POST_GAME_TIME )
    GameRules:SetTreeRegrowTime( TREE_REGROW_TIME )
    GameRules:SetUseCustomHeroXPValues ( USE_CUSTOM_XP_VALUES )
    GameRules:SetGoldPerTick(GOLD_PER_TICK)
    GameRules:SetGoldTickTime(GOLD_TICK_TIME)
    GameRules:SetRuneSpawnTime(RUNE_SPAWN_TIME)
    GameRules:SetUseBaseGoldBountyOnHeroes(USE_STANDARD_HERO_GOLD_BOUNTY)
    GameRules:SetHeroMinimapIconScale( MINIMAP_ICON_SIZE )
    GameRules:SetCreepMinimapIconScale( MINIMAP_CREEP_ICON_SIZE )
    GameRules:SetRuneMinimapIconScale( MINIMAP_RUNE_ICON_SIZE )
    --print('[WAROFEXALTED] GameRules set')

    InitLogFile( "log/warofexalted.txt","")

    -- Event Hooks
    -- All of these events can potentially be fired by the game, though only the uncommented ones have had
    -- Functions supplied for them.  If you are interested in the other events, you can uncomment the
    -- ListenToGameEvent line and add a function to handle the event
    ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(WarOfExalted, 'OnPlayerLevelUp'), self)
    ListenToGameEvent('dota_ability_channel_finished', Dynamic_Wrap(WarOfExalted, 'OnAbilityChannelFinished'), self)
    ListenToGameEvent('dota_player_learned_ability', Dynamic_Wrap(WarOfExalted, 'OnPlayerLearnedAbility'), self)
    ListenToGameEvent('entity_killed', Dynamic_Wrap(WarOfExalted, 'OnEntityKilled'), self)
    ListenToGameEvent('player_connect_full', Dynamic_Wrap(WarOfExalted, 'OnConnectFull'), self)
    ListenToGameEvent('player_disconnect', Dynamic_Wrap(WarOfExalted, 'OnDisconnect'), self)
    ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(WarOfExalted, 'OnItemPurchased'), self)
    ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(WarOfExalted, 'OnItemPickedUp'), self)
    ListenToGameEvent('last_hit', Dynamic_Wrap(WarOfExalted, 'OnLastHit'), self)
    ListenToGameEvent('dota_non_player_used_ability', Dynamic_Wrap(WarOfExalted, 'OnNonPlayerUsedAbility'), self)
    ListenToGameEvent('player_changename', Dynamic_Wrap(WarOfExalted, 'OnPlayerChangedName'), self)
    ListenToGameEvent('dota_rune_activated_server', Dynamic_Wrap(WarOfExalted, 'OnRuneActivated'), self)
    ListenToGameEvent('dota_player_take_tower_damage', Dynamic_Wrap(WarOfExalted, 'OnPlayerTakeTowerDamage'), self)
    ListenToGameEvent('tree_cut', Dynamic_Wrap(WarOfExalted, 'OnTreeCut'), self)
    ListenToGameEvent('entity_hurt', Dynamic_Wrap(WarOfExalted, 'OnEntityHurt'), self)
    ListenToGameEvent('player_connect', Dynamic_Wrap(WarOfExalted, 'PlayerConnect'), self)
    ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(WarOfExalted, 'OnAbilityUsed'), self)
    ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(WarOfExalted, 'OnGameRulesStateChange'), self)
    ListenToGameEvent('npc_spawned', Dynamic_Wrap(WarOfExalted, 'OnNPCSpawned'), self)
    ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(WarOfExalted, 'OnPlayerPickHero'), self)
    ListenToGameEvent('dota_team_kill_credit', Dynamic_Wrap(WarOfExalted, 'OnTeamKillCredit'), self)
    ListenToGameEvent("player_reconnected", Dynamic_Wrap(WarOfExalted, 'OnPlayerReconnect'), self)
    --ListenToGameEvent('player_spawn', Dynamic_Wrap(WarOfExalted, 'OnPlayerSpawn'), self)
    --ListenToGameEvent('dota_unit_event', Dynamic_Wrap(WarOfExalted, 'OnDotaUnitEvent'), self)
    --ListenToGameEvent('nommed_tree', Dynamic_Wrap(WarOfExalted, 'OnPlayerAteTree'), self)
    --ListenToGameEvent('player_completed_game', Dynamic_Wrap(WarOfExalted, 'OnPlayerCompletedGame'), self)
    --ListenToGameEvent('dota_match_done', Dynamic_Wrap(WarOfExalted, 'OnDotaMatchDone'), self)
    --ListenToGameEvent('dota_combatlog', Dynamic_Wrap(WarOfExalted, 'OnCombatLogEvent'), self)
    --ListenToGameEvent('dota_player_killed', Dynamic_Wrap(WarOfExalted, 'OnPlayerKilled'), self)
    --ListenToGameEvent('player_team', Dynamic_Wrap(WarOfExalted, 'OnPlayerTeam'), self)
    
    -- Custom Event Hooks
    CustomGameEventManager:RegisterListener("woe_unit_request", Dynamic_Wrap(WarOfExalted, "OnWoeUnitRequest"))
    CustomGameEventManager:RegisterListener("woe_ability_request", Dynamic_Wrap(WarOfExalted, "OnWoeAbilityRequest"))
    CustomGameEventManager:RegisterListener("woe_save_config", Dynamic_Wrap(WarOfExalted, "OnWoeSaveConfig"))
    
    gameMode:SetModifierGainedFilter(function(a, b)
        --[[print("modifierfilter")
        print("IsServer", IsServer())
        print(type(a), type(b))
        util.printTable(a)
        print("--------------")
        util.printTable(b)]]
        return true
    end, { })


    Convars:RegisterCommand('player_say', function(...)
        local arg = {...}
        table.remove(arg,1)
        local sayType = arg[1]
        table.remove(arg,1)

        local cmdPlayer = Convars:GetCommandClient()
        keys = {}
        keys.ply = cmdPlayer
        keys.teamOnly = false
        keys.text = table.concat(arg, " ")

        if (sayType == 4) then
            -- Student messages
        elseif (sayType == 3) then
            -- Coach messages
        elseif (sayType == 2) then
            -- Team only
            keys.teamOnly = true
            -- Call your player_say function here like
            self:PlayerSay(keys)
        else
            -- All chat
            -- Call your player_say function here like
            self:PlayerSay(keys)
        end
    end, 'player say', 0)
    
    -- Fill server with fake clients
    -- Fake clients don't use the default bot AI for buying items or moving down lanes and are sometimes necessary for debugging
    Convars:RegisterCommand('fake', function()
        -- Check if the server ran it
        if not Convars:GetCommandClient() then
            -- Create fake Players
            SendToServerConsole('dota_create_fake_clients')

            Timers:CreateTimer('assign_fakes', {
                useGameTime = false,
                endTime = Time(),
                callback = function(warofexalted, args)
                    local userID = 20
                    for i=0, 9 do
                        userID = userID + 1
                        -- Check if this player is a fake one
                        if PlayerResource:IsFakeClient(i) then
                            -- Grab player instance
                            local ply = PlayerResource:GetPlayer(i)
                            -- Make sure we actually found a player instance
                            if ply then
                                CreateHeroForPlayer(FAKE_CLIENT_HERO, ply)
                                self:OnConnectFull({
                                    userid = userID,
                                    index = ply:entindex()-1
                                })

                                ply:GetAssignedHero():SetControllableByPlayer(0, true)
                            end
                        end
                    end
                end})
        end
    end, 'Connects and assigns fake Players.', 0)
    
    Convars:RegisterCommand("run_lua", function(...)
        if not Convars:GetCommandClient() then
            ex = select(2, ...)
            loadstring(ex)()
        end
    end, "Execute lua", 0 )
    
    Convars:RegisterCommand("debug_properties", function(...)
        Property.SetDebug(not Property.DebugMode)
    end, "Enable/disable debugging of custom properties", 0)

    -- Change random seed
    local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
    math.randomseed(tonumber(timeTxt))
    
    -- Initialized tables for tracking state
    self.vUserIds = {}
    self.vSteamIds = {}
    self.vBots = {}
    self.vBroadcasters = {}

    self.vPlayers = {}
    self.vRadiant = {}
    self.vDire = {}

    self.nRadiantKills = 0
    self.nDireKills = 0

    self.bSeenWaitForPlayers = false
    
    self.addonInfo = LoadKeyValues("addoninfo.txt")
    self.config = LoadKeyValues("woeconfig.txt")
    self.datadriven = {}
    self:LoadAllDatadrivenFiles()
    
    Storage:SetApiKey(self.addonInfo.storage_api_key)

    if RECOMMENDED_BUILDS_DISABLED then
        gameMode:SetHUDVisible( DOTA_HUD_VISIBILITY_SHOP_SUGGESTEDITEMS, false )
    end

    --print('[WAROFEXALTED] Done loading WarOfExalted gamemode!\n\n')
end

function WarOfExalted:LoadAllDatadrivenFiles()
    self:LoadAbilityDatadrivenFiles()
    self:LoadItemDatadrivenFiles()
    self:LoadUnitDatadrivenFiles()
    self:LoadHeroDatadrivenFiles()
end

function WarOfExalted:LoadAbilityDatadrivenFiles()
    self:_LoadDatadrivenFilesHelper("abilities", self.config.AbilityFile)
end

function WarOfExalted:LoadItemDatadrivenFiles()
    self:_LoadDatadrivenFilesHelper("items", self.config.ItemFile)
end

function WarOfExalted:LoadUnitDatadrivenFiles()
    self:_LoadDatadrivenFilesHelper("units", self.config.UnitFile)

end

function WarOfExalted:LoadHeroDatadrivenFiles()
    self:_LoadDatadrivenFilesHelper("heroes", self.config.HeroFile)
end

function WarOfExalted:_LoadDatadrivenFilesHelper(keyName, fileName)
    print("[WAROFEXALTED] Loading WoE KV file:", fileName)
    local keys = LoadKeyValues(fileName)
    if keys then
        self.datadriven[keyName] = keys
    elseif not self.datadriven[keyName] then
        print("[WAROFEXALTED] " .. fileName .. " not found")
        self.datadriven[keyName] = {}
    end
end

mode = nil

-- This function is called as the first player loads and sets up the WarOfExalted parameters
function WarOfExalted:CaptureWarOfExalted()
    if mode == nil then
        -- Set WarOfExalted parameters
        mode = GameRules:GetGameModeEntity()
        mode:SetRecommendedItemsDisabled( RECOMMENDED_BUILDS_DISABLED )
        mode:SetCameraDistanceOverride( CAMERA_DISTANCE_OVERRIDE )
        mode:SetCustomBuybackCostEnabled( CUSTOM_BUYBACK_COST_ENABLED )
        mode:SetCustomBuybackCooldownEnabled( CUSTOM_BUYBACK_COOLDOWN_ENABLED )
        mode:SetBuybackEnabled( BUYBACK_ENABLED )
        mode:SetTopBarTeamValuesOverride ( USE_CUSTOM_TOP_BAR_VALUES )
        mode:SetTopBarTeamValuesVisible( TOP_BAR_VISIBLE )
        mode:SetUseCustomHeroLevels ( USE_CUSTOM_HERO_LEVELS )
        mode:SetCustomHeroMaxLevel ( MAX_LEVEL )
        mode:SetCustomXPRequiredToReachNextLevel( XP_PER_LEVEL_TABLE )

        --mode:SetBotThinkingEnabled( USE_STANDARD_DOTA_BOT_THINKING )
        mode:SetTowerBackdoorProtectionEnabled( ENABLE_TOWER_BACKDOOR_PROTECTION )

        mode:SetFogOfWarDisabled(DISABLE_FOG_OF_WAR_ENTIRELY)
        mode:SetGoldSoundDisabled( DISABLE_GOLD_SOUNDS )
        mode:SetRemoveIllusionsOnDeath( REMOVE_ILLUSIONS_ON_DEATH )

        self:OnFirstPlayerLoaded()
    end
end

-- This function is called 1 to 2 times as the player connects initially but before they
-- have completely connected
function WarOfExalted:PlayerConnect(keys)
    --print('[WAROFEXALTED] PlayerConnect')
    --util.printTable(keys)

    if keys.bot == 1 then
        -- This user is a Bot, so add it to the bots table
        self.vBots[keys.userid] = 1
    end
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function WarOfExalted:OnConnectFull(keys)
    --print ('[WAROFEXALTED] OnConnectFull')
    --util.printTable(keys)
    WarOfExalted:CaptureWarOfExalted()

    local entIndex = keys.index+1
    -- The Player entity of the joining user
    local ply = EntIndexToHScript(entIndex)

    -- The Player ID of the joining player
    local playerID = ply:GetPlayerID()

    local steamID = PlayerResource:GetSteamAccountID(playerID)
    
    -- Update the user ID table with this user
    self.vUserIds[keys.userid] = ply

    -- Update the Steam ID table
    self.vSteamIds[steamID] = ply

    -- If the player is a broadcaster flag it in the Broadcasters table
    if PlayerResource:IsBroadcaster(playerID) then
        self.vBroadcasters[keys.userid] = 1
        return
    end
end

function WarOfExalted:OnScriptReload()
    self:InitClientSideLua()
end

function WarOfExalted:InitClientSideLua()
    CreateModifierThinker(self.vPlayers[1], nil, "modifier_client_side_init", { duration = 0.2 }, Vector(0,0,0), DOTA_TEAM_NEUTRALS, false)
end

-- This is an example console command
function WarOfExalted:ExampleConsoleCommand()
    --print( '******* Example Console Command ***************' )
    local cmdPlayer = Convars:GetCommandClient()
    if cmdPlayer then
        local playerID = cmdPlayer:GetPlayerID()
        if playerID ~= nil and playerID ~= -1 then
            -- Do something here for the player who called this command
            PlayerResource:ReplaceHeroWith(playerID, "npc_dota_hero_viper", 1000, 1000)
        end
    end
    --print( '*********************************************' )
end

if reloaded then
    WarOfExalted:OnScriptReload()
end
