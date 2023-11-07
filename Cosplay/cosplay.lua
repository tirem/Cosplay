-- Copyright (c) 2023 Tirem
-- Some code used from sexchange addon and is copyrighted to atom0s and ashitav4

addon.name      = 'Cosplay';
addon.author    = 'Tirem';
addon.version   = '1.0';
addon.desc      = 'Copies the look at the targets gear and applies it to your self';
addon.link      = 'https://github.com/tirem/Cosplay';

require('common');
local chat = require('chat');
local ffi = require('ffi');

-- saved outfit this session
local Cosplay = T{
};

-- Cached version of what we are supposed to look like
local OriginalLook = T{
};

-- Cache player look now if we have one
local player = GetPlayerEntity();
if (player ~= nil) then
    OriginalLook.Head = player.Look.Head;
    OriginalLook.Body = player.Look.Body;
    OriginalLook.Hands = player.Look.Hands;
    OriginalLook.Legs = player.Look.Legs;
    OriginalLook.Feet = player.Look.Feet;
end

local function ResetLook()
    local player = GetPlayerEntity();
    if (player ~= nil) then
        player.Look.Head = OriginalLook.Head;
        player.Look.Body = OriginalLook.Body;
        player.Look.Hands = OriginalLook.Hands;
        player.Look.Legs = OriginalLook.Legs;
        player.Look.Feet = OriginalLook.Feet;
        player.ModelUpdateFlags = 0x10;
    end
end

local function UpdateLook()
    local player = GetPlayerEntity();
    if (player ~= nil) then
        if (Cosplay.Head ~= nil) then
            player.Look.Head = Cosplay.Head;
        end
        if (Cosplay.Body ~= nil) then
            player.Look.Body = Cosplay.Body;
        end
        if (Cosplay.Hands ~= nil) then
            player.Look.Hands = Cosplay.Hands;
        end
        if (Cosplay.Legs ~= nil) then
            player.Look.Legs = Cosplay.Legs;
        end
        if (Cosplay.Feet ~= nil) then
            player.Look.Feet = Cosplay.Feet;
        end
        player.ModelUpdateFlags = 0x10;
    end
end

local function GetStPartyIndex()
    local ptr = AshitaCore:GetPointerManager():Get('party');
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    local isActive = (ashita.memory.read_uint32(ptr + 0x54) ~= 0);
    if isActive then
        return ashita.memory.read_uint8(ptr + 0x50);
    else
        return nil;
    end
end

local function GetTargets()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    local party = AshitaCore:GetMemoryManager():GetParty();

    if (playerTarget == nil or party == nil) then
        return nil, nil;
    end

    local mainTarget = playerTarget:GetTargetIndex(0);
    local secondaryTarget = playerTarget:GetTargetIndex(1);
    local partyTarget = GetStPartyIndex();

    if (partyTarget ~= nil) then
        secondaryTarget = mainTarget;
        mainTarget = party:GetMemberTargetIndex(partyTarget);
    end

    return mainTarget, secondaryTarget;
end

function IsPlayer(targetEntity)
    -- Obtain the entity spawn flags..

    local flag = targetEntity.SpawnFlags;

    -- Determine the entity type and apply the proper color
    if (bit.band(flag, 0x0001) == 0x0001) then --players
		return true;
    else
        return false;
    end
end

local function CopyTargetsLook()
    -- Obtain the player target entity (account for subtarget)
	local targetIndex, _ = GetTargets();
	local player = GetEntity(targetIndex);
    if (player ~= nil and IsPlayer(player)) then
        Cosplay.Head = player.Look.Head;
        Cosplay.Body = player.Look.Body;
        Cosplay.Hands = player.Look.Hands;
        Cosplay.Legs = player.Look.Legs;
        Cosplay.Feet = player.Look.Feet;
        return true;
    end
    return false;
end

ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/cosplay' and args[1] ~= '/cos')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /Cosplay - Copies the targets current look
    if (#args == 1) then
        if (CopyTargetsLook() == true) then
            UpdateLook();
            print(chat.header(addon.name):append(chat.message('Cosplaying Target!')));
        end
        return;
    end

    -- Handle: /Cosplay (clear | off) - Turns off Cosplay.
    if (#args == 2 and args[2]:any('clear', 'off')) then
        Cosplay.Head = nil;
        Cosplay.Body = nil;
        Cosplay.Hands = nil;
        Cosplay.Legs = nil;
        Cosplay.Feet = nil;
        ResetLook();
        print(chat.header(addon.name):append(chat.message('Cleared Cosplay!')));
        return;
    end

    -- Handle: /Cosplay (help) - Turns off Cosplay.
    if (#args == 2 and args[2]:any('help')) then
        print(chat.header(addon.name):append(chat.message('"/cosplay" to copy your targets look (Players only)')));
        print(chat.header(addon.name):append(chat.message('"/cosplay clear" OR "/cosplay off" to clear your cosplay')));
        print(chat.header(addon.name):append(chat.message('"/cos" works too :)"')));
        return;
    end
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.blocked) then
        return;
    end

    -- Packet: Zone Enter
    if (e.id == 0x000A) then
        local p = ffi.cast('uint16_t*', e.data_modified_raw);

        -- Save incoming look for clearing
        OriginalLook.Head = p[0x46];
        OriginalLook.Body = p[0x48];
        OriginalLook.Hands = p[0x4A];
        OriginalLook.Legs = p[0x4C];
        OriginalLook.Feet = p[0x4E];
        
        if (Cosplay.Head ~= nil) then
            p[0x46] = Cosplay.Head;
        end
        if (Cosplay.Body ~= nil) then
            p[0x48] = Cosplay.Body;
        end
        if (Cosplay.Hands ~= nil) then
            p[0x4A] = Cosplay.Hands;
        end
        if (Cosplay.Legs ~= nil) then
            p[0x4C] = Cosplay.Legs;
        end
        if (Cosplay.Feet ~= nil) then
            p[0x4E] = Cosplay.Feet;
        end
    end

    -- Packet: Character Update
    if (e.id == 0x000D) then
        local p = ffi.cast('uint16_t*', e.data_modified_raw);
        local i = struct.unpack('L', e.data_modified, 0x04 + 0x1);
        if (i == AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0) and p[0x0A] == 0x1F) then

            -- Save incoming look for clearing
            OriginalLook.Head = p[0x4A];
            OriginalLook.Body = p[0x4C];
            OriginalLook.Hands = p[0x4E];
            OriginalLook.Legs = p[0x50];
            OriginalLook.Feet = p[0x52];

            if (Cosplay.Head ~= nil) then
                p[0x4A] = Cosplay.Head;
            end
            if (Cosplay.Body ~= nil) then
                p[0x4C] = Cosplay.Body;
            end
            if (Cosplay.Hands ~= nil) then
                p[0x4E] = Cosplay.Hands;
            end
            if (Cosplay.Legs ~= nil) then
                p[0x50] = Cosplay.Legs;
            end
            if (Cosplay.Feet ~= nil) then
                p[0x52] = Cosplay.Feet;
            end
        end
    end

    -- Packet: Character Appearance
    if (e.id == 0x0051) then
        local p = ffi.cast('uint16_t*', e.data_modified_raw);

        -- Save incoming look for clearing
        OriginalLook.Head = p[0x06];
        OriginalLook.Body = p[0x08];
        OriginalLook.Hands = p[0x0A];
        OriginalLook.Legs = p[0x0C];
        OriginalLook.Feet = p[0x0E];

        if (Cosplay.Head ~= nil) then
            p[0x06] = Cosplay.Head;
        end
        if (Cosplay.Body ~= nil) then
            p[0x08] = Cosplay.Body;
        end
        if (Cosplay.Hands ~= nil) then
            p[0x0A] = Cosplay.Hands;
        end
        if (Cosplay.Legs ~= nil) then
            p[0x0C] = Cosplay.Legs;
        end
        if (Cosplay.Feet ~= nil) then
            p[0x0E] = Cosplay.Feet;
        end
    end
end);