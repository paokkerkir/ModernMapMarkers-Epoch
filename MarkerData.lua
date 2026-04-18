-- ModernMapMarkers - MarkerData.lua
-- ============================================================
-- Entry format
-- ============================================================
--
--   { zoneID, x, y, name, type, info, atlasID [, slot8] }
--
--   zoneID   : numeric zone ID within the continent
--   x, y     : map coordinates
--   name     : marker name shown on hover and in the Find Marker panel
--              may contain an embedded comment after \n
--              example: "Gnomeregan\n|cFF808080(Workshop Entrance)|r"
--              the comment is shown as a second line in the Find Marker panel
--   type     : "dungeon", "raid", "worldboss", "boat", "zepp", "tram" & "portal"
--   info     : level range, examples: "52-60" or "80"
--              faction string: "Alliance", "Horde" & "Neutral"
--              nil for non-combat world bosses handled separately
--   atlasID  : AtlasLoot zone index (number), or nil if not applicable
--   slot8    : optional, one of:
--
--              - Transport destination(s) — boat / zepp / tram / portal only:
--                  single - {continent, zone}
--                  dual   - {{continent, zone}, {continent, zone}}
--                           left-click navigates to dest[1]
--                           right-click navigates to dest[2]
--                  multi  - {{continent, zone, "Label"}, ...}  (3 or more)
--                           opens a popup menu listing all destinations
--                           the third element is the label shown in the menu
--                           and in the transport hint line
--
--              - "nopulse"  — used inside a dest table as the third element:
--                             {continent, zone, "nopulse"}
--                             navigates normally but suppresses the return
--                             highlight pulse on the destination marker
--                             (used for portals that loop back to the same map)
--
--              - "nolist"   — excludes the entry from the Find Marker panel
--                             while still showing it on the world map
--                             (use for duplicate/secondary entrance markers)
--
--              - "dropdown" — the marker comment is shown only in the
--                             Find Marker panel, not on the world map hover
--                             tooltip (use when the comment is context for
--                             navigation but not needed on the map pin)
--
-- ============================================================
-- Continent IDs
-- ============================================================
--
--   [1] Kalimdor        [2] Eastern Kingdoms
--   [3] Outland         [4] Northrend
--
-- ============================================================
-- Datasets
-- ============================================================
--
--   MMM_DefaultPoints  used when WDM is not loaded
--   MMM_WdmPoints      used when WDM is detected; contains remapped zone IDs
--                      for Kalimdor and Eastern Kingdoms only.
--                      Outland and Northrend dungeon/raid/worldboss entries
--                      are shared from MMM_DefaultPoints automatically —
--                      do NOT duplicate them in MMM_WdmPoints.
MMM_DefaultPoints = {
    -- -------------------------------------------------------------------------
    [1] = { -- Kalimdor
        -- Dungeons
        {1, 0.123, 0.128, "Blackfathom Deeps", "dungeon", "24-32", 3},
        {11, 0.648, 0.303, "Dire Maul - East", "dungeon", "55-58", 10},
        {11, 0.771, 0.369, "Dire Maul - East\n|cFF808080(The Hidden Reach)|r", "dungeon", "55-58", 10},
        {11, 0.671, 0.34, "Dire Maul - East\n|cFF808080(Side Entrance)|r", "dungeon", "55-58", 10},
        {11, 0.624, 0.249, "Dire Maul - North", "dungeon", "57-60", 12},
        {11, 0.604, 0.311, "Dire Maul - West", "dungeon", "57-60", 13},
        {7, 0.29, 0.629, "Maraudon", "dungeon", "46-55", 14},
        {14, 0.53, 0.486, "Ragefire Chasm", "dungeon", "13-18", 17},
        {19, 0.508, 0.94, "Razorfen Downs", "dungeon", "37-46", 18},
        {19, 0.423, 0.9, "Razorfen Kraul", "dungeon", "29-38", 19},
        {19, 0.462, 0.357, "Wailing Caverns", "dungeon", "17-24", 20},
        {17, 0.389, 0.184, "Zul'Farrak", "dungeon", "44-54", 22},
        {17, 0.650, 0.458, "Old Hillsbrad Foothills", "dungeon", "66-70", 7},
        {17, 0.685, 0.48, "The Black Morass", "dungeon", "68-70", 8},
        {17, 0.678, 0.512, "The Culling of Stratholme", "dungeon", "75-80", 9},
        -- Raids
        {9, 0.529, 0.777, "Onyxia's Lair", "raid", "60", 16},
        {15, 0.305, 0.987, "Ruins of Ahn'Qiraj", "raid", "60", 1},
        {15, 0.269, 0.987, "Temple of Ahn'Qiraj", "raid", "60", 2},
        {17, 0.67, 0.45, "Hyjal Summit", "raid", "70", 6},
        -- World Bosses
        {2, 0.535, 0.816, "Azuregos", "worldboss", "60", nil},
        {1, 0.937, 0.355, "Emerald Dragon\n|cFF808080(Bough Shadow)|r", "worldboss", "60", nil},
        {11, 0.512, 0.108, "Emerald Dragon\n|cFF808080(Dream Bough)|r", "worldboss", "60", nil},
        -- Transport
        {8, 0.512, 0.135, "Zeppelins to Tirisfal Glades & Grom'Gol", "zepp", "Horde", nil, {{2, 25, "Tirisfal Glades"}, {2, 22, "Grom'Gol"}}},
        {8, 0.415, 0.183, "Zeppelins to Thunder Bluff & Warsong Hold", "zepp", "Horde", nil, {{1, 22, "Thunder Bluff"}, {4, 1, "Warsong Hold"}}},
        {22, 0.137, 0.257, "Zeppelin to Durotar", "zepp", "Horde", nil, {1, 8}},
        {19, 0.636, 0.389, "Boat to Booty Bay", "boat", "Neutral", nil, {2, 22}},
        {5, 0.333, 0.399, "Boat to Rut'Theran Village", "boat", "Alliance", nil, {1, 18}},
        {5, 0.308, 0.410, "Boat to Azuremyst Isle", "boat", "Alliance", nil, {1, 3}},
        {5, 0.325, 0.436, "Boat to Stormwind Harbor", "boat", "Alliance", nil, {2, 21}},
        {9, 0.718, 0.566, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 29}},
        {11, 0.311, 0.395, "Boat to Forgotten Coast", "boat", "Alliance", nil, {1, 11}},
        {11, 0.431, 0.428, "Boat to Sardor Isle", "boat", "Alliance", nil, {1, 11}},
        {18, 0.552, 0.949, "Boat to Auberdine", "boat", "Alliance", nil, {1, 5}},
        {3, 0.200, 0.542, "Boat to Auberdine", "boat", "Alliance", nil, {1, 5}},
        -- Portals
        {6, 0.405, 0.817, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 4}},
        {20, 0.463, 0.608, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 4}},
        {14, 0.381, 0.857, "Portal to Blasted Lands", "portal", "Horde", nil, {2, 4}},
        {22, 0.232, 0.135, "Portal to Blasted Lands\n|cFF808080(Inside The Pools of Vision)|r", "portal", "Horde", nil, {2, 4}},
    },
    -- -------------------------------------------------------------------------
    [2] = { -- Eastern Kingdoms
        -- Dungeons
        {18, 0.387, 0.833, "Blackrock Depths\n|cFF808080(Searing Gorge)|r", "dungeon", "52-60", 2, "dropdown"},
        {5, 0.328, 0.365, "Blackrock Depths\n|cFF808080(Burning Steppes)|r", "dungeon", "52-60", 2, "dropdown"},
        {28, 0.423, 0.726, "The Deadmines", "dungeon", "17-26", 7},
        {7, 0.178, 0.392, "Gnomeregan", "dungeon", "29-38", 9},
        {7, 0.216, 0.30, "Gnomeregan\n|cFF808080(Workshop Entrance)|r", "dungeon", "29-38", 9},
        {5, 0.32, 0.39, "Lower Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", 3, "dropdown"},
        {18, 0.379, 0.858, "Lower Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", 3, "dropdown"},
        {25, 0.87, 0.325, "Scarlet Monastery - Armory", "dungeon", "32-42", 16},
        {25, 0.862, 0.295, "Scarlet Monastery - Cathedral", "dungeon", "35-45", 17},
        {25, 0.839, 0.283, "Scarlet Monastery - Graveyard", "dungeon", "26-36", 18},
        {25, 0.85, 0.335, "Scarlet Monastery - Library", "dungeon", "29-39", 19},
        {27, 0.69, 0.729, "Scholomance", "dungeon", "58-60", 20},
        {20, 0.448, 0.678, "Shadowfang Keep", "dungeon", "22-30", 21},
        {21, 0.508, 0.67, "The Stockade", "dungeon", "24-32", 22},
        {9, 0.273, 0.122, "Stratholme", "dungeon", "58-60", 23},
        {9, 0.437, 0.175, "Stratholme\n|cFF808080(Back Gate)|r", "dungeon", "58-60", 23},
        {23, 0.703, 0.55, "The Temple of Atal'Hakkar", "dungeon", "50-60", 24},
        {3, 0.429, 0.13, "Uldaman", "dungeon", "41-51", 27},
        {3, 0.657, 0.438, "Uldaman\n|cFF808080(Back Entrance)|r", "dungeon", "41-51", 27},
        {5, 0.312, 0.365, "Upper Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", 4, "dropdown"},
        {18, 0.371, 0.833, "Upper Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", 4, "dropdown"},
        {15, 0.612, 0.309, "Magisters' Terrace", "dungeon", "70", 14},
        -- Raids
        {18, 0.332, 0.833, "Blackwing Lair\n|cFF808080(Searing Gorge)|r", "raid", "60", 5, "dropdown"},
        {5, 0.273, 0.363, "Blackwing Lair\n|cFF808080(Burning Steppes)|r", "raid", "60", 5, "dropdown"},
        {18, 0.332, 0.86, "Molten Core\n|cFF808080(Searing Gorge)|r", "raid", "60", 6, "dropdown"},
        {5, 0.273, 0.39, "Molten Core\n|cFF808080(Burning Steppes)|r", "raid", "60", 6, "dropdown"},
        {22, 0.53, 0.172, "Zul'Gurub", "raid", "60", 30},
        {12, 0.78, 0.64, "Zul'Aman", "raid", "70", 29},
        {15, 0.443, 0.456, "Sunwell Plateau", "raid", "70", 26},
        {6, 0.469, 0.747, "Karazhan", "raid", "70", 12},
        {6, 0.467, 0.708, "Karazhan\n|cFF808080(Side Entrance)|r", "raid", "70", 12},
        -- World Bosses
        {8, 0.465, 0.357, "Emerald Dragon\n|cFF808080(The Twilight Grove)|r", "worldboss", "60", nil},
        {24, 0.632, 0.217, "Emerald Dragon\n|cFF808080(Seradane)|r", "worldboss", "60", nil},
        -- Transport
        {21, 0.677, 0.325, "Tram to Ironforge", "tram", "Alliance", nil, {2, 14}},
        {14, 0.762, 0.511, "Tram to Stormwind", "tram", "Alliance", nil, {2, 21}},
        {29, 0.051, 0.634, "Boat to Theramore Isle", "boat", "Alliance", nil, {1, 9}},
        {29, 0.046, 0.572, "Boat to Valgarde", "boat", "Alliance", nil, {4, 6}},
        {22, 0.257, 0.73, "Boat to Ratchet", "boat", "Neutral", nil, {1, 19}},
        {25, 0.606, 0.583, "Zeppelins to Durotar, Grom'Gol & Vengeance Landing", "zepp", "Horde", nil, {{1, 8, "Durotar"}, {2, 22, "Grom'Gol"}, {4, 6, "Vengeance Landing"}}},
        {22, 0.312, 0.298, "Zeppelins to Tirisfal Glades & Durotar", "zepp", "Horde", nil, {{2, 25, "Tirisfal Glades"}, {1, 8, "Durotar"}}},
        {21, 0.216, 0.562, "Boat to Auberdine", "boat", "Alliance", nil, {1, 5}},
        {21, 0.172, 0.251, "Boat to Valiance Keep", "boat", "Alliance", nil, {4, 1}},
        -- Portals
        {19, 0.495, 0.148, "Silvermoon to Ruins of Lordaeron\n|cFF808080(Orb of Translocation)|r", "portal", "Horde", nil, {2, 26}},
        {19, 0.583, 0.21, "Portal to Blasted Lands", "portal", "Horde", nil, {2, 4}},
        {26, 0.595, 0.111, "Ruins of Lordaeron to Silvermoon\n|cFF808080(Orb of Translocation)|r", "portal", "Horde", nil, {2, 19}},
        {26, 0.852, 0.17, "Portal to Blasted Lands", "portal", "Horde", nil, {2, 4}},
        {21, 0.490, 0.873, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 4}},
        {14, 0.272, 0.07, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 4}},
    },
    -- -------------------------------------------------------------------------
    [3] = { -- Outland
        -- Dungeons
        {2, 0.48, 0.535, "Hellfire Ramparts", "dungeon", "60-62", 16},
        {2, 0.46, 0.51, "The Blood Furnace", "dungeon", "60-62", 18},
        {2, 0.48, 0.51, "Shattered Halls", "dungeon", "69-70", 19},
        {4, 0.745, 0.577, "The Arcatraz", "dungeon", "70", 20},
        {4, 0.717, 0.55, "The Botanica", "dungeon", "70", 21},
        {4, 0.706, 0.698, "The Mechanar", "dungeon", "70", 23},
        {7, 0.396, 0.602, "Mana-Tombs", "dungeon", "64-66", 3},
        {7, 0.361, 0.656, "Auchenai Crypts", "dungeon", "65-67", 2},
        {7, 0.432, 0.656, "Sethekk Halls", "dungeon", "67-69", 4},
        {7, 0.396, 0.71, "Shadow Labyrinth", "dungeon", "69-70", 5},
        {8, 0.523, 0.386, "The Underbog", "dungeon", "62-64", 13},
        {8, 0.475, 0.41, "The Slave Pens", "dungeon", "63-65", 11},
        {8, 0.483, 0.386, "The Steamvault", "dungeon", "64-66", 12},
        -- Raids
        {1, 0.693, 0.237, "Gruul's Lair", "raid", "70", 14},
        {2, 0.46, 0.535, "Magtheridon's Lair", "raid", "70", 17},
        {4, 0.737, 0.637, "The Eye", "raid", "70", 22},
        {5, 0.711, 0.464, "Black Temple", "raid", "70", 6},
        {8, 0.503, 0.386, "Serpentshrine Cavern", "raid", "70", 10},
        -- World Bosses
        {2, 0.633, 0.156, "Doom Lord Kazzak", "worldboss", "70", nil},
        {5, 0.729, 0.44, "Doomwalker", "worldboss", "70", nil},
        -- Portals
        {6, 0.597, 0.466, "Portal to Exodar", "portal", "Alliance", nil, {1, 20}},
        {6, 0.591, 0.483, "Portal to Silvermoon", "portal", "Horde", nil, {2, 19}},
        {6, 0.558, 0.367, "Portals to Darnassus, Stormwind & Ironforge", "portal", "Alliance", nil, {{1, 6, "Darnassus"}, {2, 21, "Stormwind"}, {2, 14, "Ironforge"}}},
        {6, 0.522, 0.529, "Portals to Thunder Bluff, Orgrimmar & Undercity", "portal", "Horde", nil, {{1, 22, "Thunder Bluff"}, {1, 14, "Orgrimmar"}, {2, 26, "Undercity"}}},
        {6, 0.486, 0.42, "Portal to Isle of Quel'Danas", "portal", "Neutral", nil, {2, 15}},
        {2, 0.886, 0.528, "Portal to Stormwind", "portal", "Alliance", nil, {2, 21}},
        {2, 0.886, 0.477, "Portal to Orgrimmar", "portal", "Horde", nil, {1, 14}},
    },
    -- -------------------------------------------------------------------------
    [4] = { -- Northrend
        -- Dungeons
        {6, 0.587, 0.502, "Utgarde Keep", "dungeon", "70-72", 26},
        {6, 0.573, 0.467, "Utgarde Pinnacle", "dungeon", "80", 27},
        {5, 0.177, 0.266, "Drak'Tharon Keep", "dungeon", "74-76", 7},
        {12, 0.270, 0.87, "Drak'Tharon Keep", "dungeon", "74-76", 7},
        {12, 0.761, 0.21, "Gundrak\n|cFF808080(Cave of Mam'toth)|r", "dungeon", "76-78", 11},
        {12, 0.813, 0.291, "Gundrak\n|cFF808080(Den of Sseratus)|r", "dungeon", "76-78", 11},
        {10, 0.395, 0.269, "Halls of Stone", "dungeon", "77-79", 25},
        {10, 0.454, 0.213, "Halls of Lightning", "dungeon", "80", 24},
        {4, 0.288, 0.531, "Ahn'Kahet: The Old Kingdom\n|cFF808080(Inside The Pit of Narjun)|r", "dungeon", "73-75", 1},
        {4, 0.252, 0.531, "Azjol-Nerub\n|cFF808080(Inside The Pit of Narjun)|r", "dungeon", "72-74", 2},
        {1, 0.296, 0.267, "The Oculus", "dungeon", "80", 18},
        {1, 0.254, 0.267, "The Nexus", "dungeon", "71-73", 17},
        {3, 0.7, 0.725, "The Violet Hold", "dungeon", "75-77", 29},
        {8, 0.742, 0.203, "Trial of the Champion", "dungeon", "75-80", 5},
        {8, 0.564, 0.873, "The Forge of Souls", "dungeon", "80", 10},
        {8, 0.559, 0.945, "Pit of Saron", "dungeon", "80", 9},
        {8, 0.586, 0.906, "Halls of Reflection", "dungeon", "80", 8},
        -- Raids
        {11, 0.5, 0.116, "Vault of Archavon", "raid", "80", 28},
        {4, 0.600, 0.57, "The Obsidian Sanctum", "raid", "80", 3},
        {1, 0.275, 0.267, "The Eye of Eternity", "raid", "80", 16},
        {4, 0.885, 0.447, "Naxxramas", "raid", "80", 15},
        {10, 0.416, 0.177, "Ulduar", "raid", "80", 19},
        {8, 0.752, 0.218, "Trial of the Crusader", "raid", "80", 6},
        {8, 0.538, 0.87, "Icecrown Citadel", "raid", "80", 12},
        {4, 0.622, 0.563, "The Ruby Sanctum", "raid", "80", 4},
        -- Transport
        {1, 0.605, 0.715, "Boat to Stormwind Harbor", "boat", "Alliance", nil, {2, 21}},
        {1, 0.417, 0.551, "Zeppelin to Durotar", "zepp", "Horde", nil, {1, 8}},
        {6, 0.616, 0.627, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 29}},
        {6, 0.781, 0.3, "Zeppelin to Tirisfal Glades", "zepp", "Horde", nil, {2, 25}},
        {6, 0.228, 0.583, "Boat to Moa'ki Harbor", "boat", "Neutral", nil, {4, 4}},
        {4, 0.501, 0.797, "Boat to Kamagua", "boat", "Neutral", nil, {4, 6}},
        {4, 0.476, 0.797, "Boat to Unu'pe", "boat", "Neutral", nil, {4, 1}},
        {1, 0.790, 0.541, "Boat to Moa'ki Harbor", "boat", "Neutral", nil, {4, 4}},
        -- Portals
        {11, 0.488, 0.154, "Portal to The Violet Citadel", "portal", "Neutral", nil, {4, 3, "nopulse"}},
        {3, 0.395, 0.64, "Portals to Stormwind, Ironforge,\nDarnassus, Exodar & Shattrath", "portal", "Alliance", nil, {{2, 21, "Stormwind"}, {2, 14, "Ironforge"}, {1, 6, "Darnassus"}, {1, 20, "Exodar"}, {3, 6, "Shattrath"}}},
        {3, 0.331, 0.695, "Portal Wintergrasp", "portal", "Alliance", nil, {4, 11, "nopulse"}},
        {3, 0.582, 0.226, "Portal Wintergrasp", "portal", "Horde", nil, {4, 11, "nopulse"}},
        {3, 0.585, 0.292, "Portals to Orgrimmar, Undercity,\nShattrath, Thunder Bluff & Silvermoon", "portal", "Horde", nil, {{1, 14, "Orgrimmar"}, {2, 26, "Undercity"}, {3, 6, "Shattrath"}, {1, 22, "Thunder Bluff"}, {2, 19, "Silvermoon"}}},
        {3, 0.262, 0.437, "Portal to The Purple Parlor", "portal", "Neutral", nil, {4, 3}},
        {3, 0.223, 0.397, "Portal to The Violet Citadel", "portal", "Neutral", nil, {4, 3}},
    },
}

-- WDM-specific points (used when WDM addon is detected)
MMM_WdmPoints = {
    -- -------------------------------------------------------------------------
    [1] = { -- Kalimdor
        -- Dungeons
        {2, 0.123, 0.128, "Blackfathom Deeps", "dungeon", "24-32", 3},
        {20, 0.648, 0.303, "Dire Maul - East", "dungeon", "55-58", 10},
        {20, 0.771, 0.369, "Dire Maul - East\n|cFF808080(The Hidden Reach)|r", "dungeon", "55-58", 10},
        {20, 0.671, 0.34, "Dire Maul - East\n|cFF808080(Side Entrance)|r", "dungeon", "55-58", 10},
        {20, 0.624, 0.249, "Dire Maul - North", "dungeon", "57-60", 12},
        {20, 0.604, 0.311, "Dire Maul - West", "dungeon", "57-60", 13},
        {14, 0.29, 0.629, "Maraudon", "dungeon", "46-55", 14},
        {23, 0.581, 0.324, "Maraudon\n|cFF808080(The Wicked Grotto)|r", "dungeon", "46-55", 14, "nolist"},
        {24, 0.788, 0.63, "Maraudon\n|cFF808080(Foulspore Cavern)|r", "dungeon", "46-55", 14, "nolist"},
        {28, 0.53, 0.486, "Ragefire Chasm", "dungeon", "13-18", 17},
        {27, 0.703, 0.492, "Ragefire Chasm", "dungeon", "13-18", 17, "nolist"},
        {38, 0.508, 0.94, "Razorfen Downs", "dungeon", "37-46", 18},
        {38, 0.423, 0.9, "Razorfen Kraul", "dungeon", "29-38", 19},
        {38, 0.462, 0.357, "Wailing Caverns", "dungeon", "17-24", 20},
        {52, 0.549, 0.669, "Wailing Caverns", "dungeon", "17-24", 20, "nolist"},
        {36, 0.387, 0.2, "Zul'Farrak", "dungeon", "44-54", 22},
        {36, 0.65, 0.458, "Old Hillsbrad Foothills", "dungeon", "66-70", 7},
        {36, 0.685, 0.48, "The Black Morass", "dungeon", "68-70", 8},
        {36, 0.678, 0.512, "The Culling of Stratholme", "dungeon", "75-80", 9},
        {11, 0.264, 0.328, "Old Hillsbrad Foothills", "dungeon", "66-70", 7, "nolist"},
        {11, 0.344, 0.85, "The Black Morass", "dungeon", "68-70", 8, "nolist"},
        {11, 0.604, 0.828, "The Culling of Stratholme", "dungeon", "75-80", 9, "nolist"},
        -- Raids
        {16, 0.529, 0.777, "Onyxia's Lair", "raid", "60", 16},
        {32, 0.305, 0.987, "Ruins of Ahn'Qiraj", "raid", "60", 1},
        {32, 0.269, 0.987, "Temple of Ahn'Qiraj", "raid", "60", 2},
        {36, 0.67, 0.45, "Hyjal Summit", "raid", "70", 6},
        {11, 0.396, 0.169, "Hyjal Summit", "raid", "70", 6, "nolist"},
        -- World Bosses
        {3, 0.535, 0.816, "Azuregos", "worldboss", "60", nil},
        {2, 0.937, 0.355, "Emerald Dragon\n|cFF808080(Bough Shadow)|r", "worldboss", "60", nil},
        {20, 0.512, 0.108, "Emerald Dragon\n|cFF808080(Dream Bough)|r", "worldboss", "60", nil},
        -- Transport
        {15, 0.512, 0.135, "Zeppelins to Tirisfal Glades & Grom'Gol", "zepp", "Horde", nil, {{2, 48, "Tirisfal Glades"}, {2, 42, "Grom'Gol"}}},
        {15, 0.415, 0.183, "Zeppelins to Thunder Bluff & Warsong Hold", "zepp", "Horde", nil, {{1, 45, "Thunder Bluff"}, {4, 1, "Warsong Hold"}}},
        {45, 0.137, 0.257, "Zeppelin to Durotar", "zepp", "Horde", nil, {1, 15}},
        {38, 0.636, 0.389, "Boat to Booty Bay", "boat", "Neutral", nil, {2, 42}},
        {12, 0.333, 0.399, "Boat to Rut'Theran Village", "boat", "Alliance", nil, {1, 37}},
        {12, 0.308, 0.41, "Boat to Azuremyst Isle", "boat", "Alliance", nil, {1, 4}},
        {12, 0.325, 0.436, "Boat to Stormwind Harbor", "boat", "Alliance", nil, {2, 41}},
        {16, 0.718, 0.566, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 53}},
        {20, 0.311, 0.395, "Boat to Forgotten Coast", "boat", "Alliance", nil, {1, 20}},
        {20, 0.431, 0.428, "Boat to Sardor Isle", "boat", "Alliance", nil, {1, 20}},
        {37, 0.552, 0.949, "Boat to Auberdine", "boat", "Alliance", nil, {1, 12}},
        {4, 0.2, 0.542, "Boat to Auberdine", "boat", "Alliance", nil, {1, 12}},
        -- Portals
        {13, 0.405, 0.817, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 8}},
        {39, 0.463, 0.608, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 8}},
        {28, 0.381, 0.857, "Portal to Blasted Lands", "portal", "Horde", nil, {2, 8}},
        {45, 0.232, 0.135, "Portal to Blasted Lands\n|cFF808080(Inside The Pools of Vision)|r", "portal", "Horde", nil, {2, 8}},
    },
    -- -------------------------------------------------------------------------
    [2] = { -- Eastern Kingdoms
        -- Dungeons
        {38, 0.387, 0.833, "Blackrock Depths\n|cFF808080(Searing Gorge)|r", "dungeon", "52-60", 2, "dropdown"},
        {9, 0.328, 0.365, "Blackrock Depths\n|cFF808080(Burning Steppes)|r", "dungeon", "52-60", 2, "dropdown"},
        {7, 0.393, 0.181, "Blackrock Depths", "dungeon", "52-60", 2, "nolist"},
        {52, 0.423, 0.726, "The Deadmines", "dungeon", "17-26", 7},
        {45, 0.251, 0.51, "The Deadmines", "dungeon", "17-26", 7, "nolist"},
        {14, 0.178, 0.392, "Gnomeregan", "dungeon", "29-38", 9},
        {14, 0.216, 0.3, "Gnomeregan\n|cFF808080(Workshop Entrance)|r", "dungeon", "29-38", 9},
        {25, 0.191, 0.856, "Gnomeregan", "dungeon", "29-38", 9, "nolist"},
        {25, 0.405, 0.207, "Gnomeregan\n|cFF808080(Workshop Entrance)|r", "dungeon", "29-38", 9, "nolist"},
        {9, 0.32, 0.39, "Lower Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", 3, "dropdown"},
        {38, 0.379, 0.858, "Lower Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", 3, "dropdown"},
        {6, 0.817, 0.436, "Lower Blackrock Spire", "dungeon", "55-60", 3, "nolist"},
        {48, 0.87, 0.325, "Scarlet Monastery - Armory", "dungeon", "32-42", 16},
        {48, 0.862, 0.295, "Scarlet Monastery - Cathedral", "dungeon", "35-45", 17},
        {48, 0.839, 0.283, "Scarlet Monastery - Graveyard", "dungeon", "26-36", 18},
        {48, 0.85, 0.335, "Scarlet Monastery - Library", "dungeon", "29-39", 19},
        {37, 0.848, 0.437, "Scarlet Monastery - Armory", "dungeon", "32-42", 16, "nolist"},
        {37, 0.803, 0.271, "Scarlet Monastery - Cathedral", "dungeon", "35-45", 17, "nolist"},
        {37, 0.683, 0.211, "Scarlet Monastery - Graveyard", "dungeon", "26-36", 18, "nolist"},
        {37, 0.793, 0.603, "Scarlet Monastery - Library", "dungeon", "29-39", 19, "nolist"},
        {51, 0.69, 0.729, "Scholomance", "dungeon", "58-60", 20},
        {40, 0.448, 0.678, "Shadowfang Keep", "dungeon", "22-30", 21},
        {41, 0.508, 0.67, "The Stockade", "dungeon", "24-32", 22},
        {16, 0.273, 0.122, "Stratholme", "dungeon", "58-60", 23},
        {16, 0.437, 0.175, "Stratholme\n|cFF808080(Back Gate)|r", "dungeon", "58-60", 23},
        {44, 0.703, 0.55, "The Temple of Atal'Hakkar", "dungeon", "50-60", 24},
        {4, 0.429, 0.13, "Uldaman", "dungeon", "41-51", 27},
        {4, 0.657, 0.438, "Uldaman\n|cFF808080(Back Entrance)|r", "dungeon", "41-51", 27},
        {49, 0.368, 0.283, "Uldaman", "dungeon", "41-51", 27, "nolist"},
        {9, 0.312, 0.365, "Upper Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", 4, "dropdown"},
        {38, 0.371, 0.833, "Upper Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", 4, "dropdown"},
        {6, 0.79, 0.334, "Upper Blackrock Spire", "dungeon", "55-60", 4, "nolist"},
        {30, 0.612, 0.309, "Magisters' Terrace", "dungeon", "70", 14},
        -- Raids
        {38, 0.332, 0.833, "Blackwing Lair\n|cFF808080(Burning Steppes)|r", "raid", "60", 5, "dropdown"},
        {9, 0.273, 0.363, "Blackwing Lair\n|cFF808080(Searing Gorge)|r", "raid", "60", 5, "dropdown"},
        {6, 0.64, 0.715, "Blackwing Lair", "raid", "60", 5, "nolist"},
        {38, 0.332, 0.86, "Molten Core\n|cFF808080(Searing Gorge)|r", "raid", "60", 6, "dropdown"},
        {9, 0.273, 0.39, "Molten Core\n|cFF808080(Burning Steppes)|r", "raid", "60", 6, "dropdown"},
        {7, 0.538, 0.814, "Molten Core", "raid", "60", 6, "nolist"},
        {42, 0.53, 0.172, "Zul'Gurub", "raid", "60", 30},
        {24, 0.78, 0.64, "Zul'Aman", "raid", "70", 29},
        {30, 0.443, 0.456, "Sunwell Plateau", "raid", "70", 26},
        {12, 0.469, 0.747, "Karazhan", "raid", "70", 12},
        {12, 0.467, 0.708, "Karazhan\n|cFF808080(Side Entrance)|r", "raid", "70", 12},
        -- World Bosses
        {15, 0.465, 0.357, "Emerald Dragon\n|cFF808080(The Twilight Grove)|r", "worldboss", "60", nil},
        {47, 0.632, 0.217, "Emerald Dragon\n|cFF808080(Seradane)|r", "worldboss", "60", nil},
        -- Transport
        {41, 0.677, 0.325, "Tram to Ironforge", "tram", "Alliance", nil, {2, 29}},
        {29, 0.762, 0.511, "Tram to Stormwind", "tram", "Alliance", nil, {2, 41}},
        {53, 0.051, 0.634, "Boat to Theramore Isle", "boat", "Alliance", nil, {1, 16}},
        {53, 0.046, 0.572, "Boat to Valgarde", "boat", "Alliance", nil, {4, 6}},
        {42, 0.257, 0.73, "Boat to Ratchet", "boat", "Neutral", nil, {1, 38}},
        {48, 0.606, 0.583, "Zeppelins to Durotar, Grom'Gol & Vengeance Landing", "zepp", "Horde", nil, {{1, 15, "Durotar"}, {2, 42, "Grom'Gol"}, {4, 6, "Vengeance Landing"}}},
        {42, 0.312, 0.298, "Zeppelins to Tirisfal Glades & Durotar", "zepp", "Horde", nil, {{2, 48, "Tirisfal Glades"}, {1, 15, "Durotar"}}},
        {41, 0.216, 0.562, "Boat to Auberdine", "boat", "Alliance", nil, {1, 12}},
        {41, 0.172, 0.251, "Boat to Valiance Keep", "boat", "Alliance", nil, {4, 1}},
        -- Portals
        {39, 0.495, 0.148, "Silvermoon to Ruins of Lordaeron\n|cFF808080(Orb of Translocation)|r", "portal", "Horde", nil, {2, 50}},
        {39, 0.583, 0.21, "Portal to Blasted Lands", "portal", "Horde", nil, {2, 8}},
        {50, 0.595, 0.111, "Ruins of Lordaeron to Silvermoon\n|cFF808080(Orb of Translocation)|r", "portal", "Horde", nil, {2, 39}},
        {50, 0.852, 0.17, "Portal to Blasted Lands", "portal", "Horde", nil, {2, 8}},
        {41, 0.49, 0.873, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 8}},
        {29, 0.272, 0.07, "Portal to Blasted Lands", "portal", "Alliance", nil, {2, 8}},
    },
    -- -------------------------------------------------------------------------
    [3] = { -- Outland
        -- Portals
        {6, 0.597, 0.466, "Portal to Exodar", "portal", "Alliance", nil, {1, 39}},
        {6, 0.591, 0.483, "Portal to Silvermoon", "portal", "Horde", nil, {2, 39}},
        {6, 0.558, 0.367, "Portals to Darnassus, Stormwind & Ironforge", "portal", "Alliance", nil, {{1, 13, "Darnassus"}, {2, 41, "Stormwind"}, {2, 29, "Ironforge"}}},
        {6, 0.522, 0.529, "Portals to Thunder Bluff, Orgrimmar & Undercity", "portal", "Horde", nil, {{1, 45, "Thunder Bluff"}, {1, 28, "Orgrimmar"}, {2, 50, "Undercity"}}},
        {6, 0.486, 0.42, "Portal to Isle of Quel'Danas", "portal", "Neutral", nil, {2, 30}},
        {2, 0.886, 0.528, "Portal to Stormwind", "portal", "Alliance", nil, {2, 41}},
        {2, 0.886, 0.477, "Portal to Orgrimmar", "portal", "Horde", nil, {1, 28}},
    },
    -- -------------------------------------------------------------------------
    [4] = { -- Northrend
        -- Transport
        {1, 0.605, 0.715, "Boat to Stormwind Harbor", "boat", "Alliance", nil, {2, 41}},
        {1, 0.417, 0.551, "Zeppelin to Durotar", "zepp", "Horde", nil, {1, 15}},
        {6, 0.616, 0.627, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 53}},
        {6, 0.781, 0.3, "Zeppelin to Tirisfal Glades", "zepp", "Horde", nil, {2, 48}},
        {6, 0.228, 0.583, "Boat to Moa'ki Harbor", "boat", "Neutral", nil, {4, 4}},
        {4, 0.501, 0.797, "Boat to Kamagua", "boat", "Neutral", nil, {4, 6}},
        {4, 0.476, 0.797, "Boat to Unu'pe", "boat", "Neutral", nil, {4, 1}},
        {1, 0.790, 0.541, "Boat to Moa'ki Harbor", "boat", "Neutral", nil, {4, 4}},
        -- Portals
        {11, 0.488, 0.154, "Portal to The Violet Citadel", "portal", "Neutral", nil, {4, 3, "nopulse"}},
        {3, 0.395, 0.64, "Portals to Stormwind, Ironforge,\nDarnassus, Exodar & Shattrath", "portal", "Alliance", nil, {{2, 41, "Stormwind"}, {2, 29, "Ironforge"}, {1, 13, "Darnassus"}, {1, 39, "Exodar"}, {3, 6, "Shattrath"}}},
        {3, 0.331, 0.695, "Portal Wintergrasp", "portal", "Alliance", nil, {4, 11, "nopulse"}},
        {3, 0.582, 0.226, "Portal Wintergrasp", "portal", "Horde", nil, {4, 11, "nopulse"}},
        {3, 0.585, 0.292, "Portals to Orgrimmar, Undercity,\nShattrath, Thunder Bluff & Silvermoon", "portal", "Horde", nil, {{1, 28, "Orgrimmar"}, {2, 50, "Undercity"}, {3, 6, "Shattrath"}, {1, 45, "Thunder Bluff"}, {2, 39, "Silvermoon"}}},
        {3, 0.262, 0.437, "Portal to The Purple Parlor", "portal", "Neutral", nil, {4, 3}},
        {3, 0.223, 0.397, "Portal to The Violet Citadel", "portal", "Neutral", nil, {4, 3}},
    },
}
