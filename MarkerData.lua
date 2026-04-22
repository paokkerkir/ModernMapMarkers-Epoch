-- ModernMapMarkers - MarkerData.lua
-- ============================================================
-- Entry format (Project Epoch refactor)
-- ============================================================
--
--   { zoneName, x, y, name, type, info, atlasID [, slot8] }
--
--   zoneName : PE internal zone name string (from WorldMapArea.dbc).
--              Preserves PE's spelling, including typos:
--              "Aszhara", "Darnassis", "Ogrimmar", "Hilsbrad".
--   x, y     : map coordinates
--   name     : marker name shown on hover and in the Find Marker panel.
--              may contain an embedded comment after \n
--              example: "Gnomeregan\n|cFF808080(Workshop Entrance)|r"
--              the comment is shown as a second line in the Find Marker panel
--   type     : "dungeon", "raid", "worldboss", "boat", "zepp", "tram" & "portal"
--   info     : level range, examples: "52-60" or "80"
--              faction string: "Alliance", "Horde" & "Neutral"
--              nil for non-combat world bosses handled separately
--   atlasID  : Atlas map KEY (string), or nil if no Atlas page exists.
--              Examples: "BlackrockDepths", "TheDeadmines", "SMArmory".
--              Matches a key in AtlasMaps (from the Atlas addon). MMM
--              resolves this to AtlasOptions.AtlasType/AtlasZone at click
--              time by searching ATLAS_DROPDOWNS, so it survives any
--              re-sort, added maps (PE: BaradinHold, GlittermurkMines,
--              StonetalonCaverns), or plugin reorders. Numeric indices
--              are still accepted for legacy data but are fragile.
--   slot8    : optional, one of:
--
--              - Transport destination(s) — boat / zepp / tram / portal only:
--                  single - "ZoneName"
--                  dual   - {"ZoneName1", "ZoneName2"}
--                           left-click navigates to dest[1]
--                           right-click navigates to dest[2]
--                  multi  - {{"ZoneName", "Label"}, ...}  (2 or more)
--                           opens a popup menu listing all destinations
--                           the second element is the label shown in the menu
--                           and in the transport hint line
--
--              - "nopulse"  — used inside a single or dual dest sub-entry:
--                             {"ZoneName", "nopulse"}
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
-- Scope
-- ============================================================
--
--   Only Kalimdor and Eastern Kingdoms zones are included. PE serves
--   vanilla content, so Outland / Northrend / TBC-only zones (Azuremyst,
--   Eversong, Silvermoon, etc.) and WDM remappings were removed during
--   the 3.43-epoch refactor.
--   See docs/plans/2026-04-21-mmm-epoch-fix-design.md for details.
MMM_DefaultPoints = {
    -- -------------------------------------------------------------------------
    -- Kalimdor
    -- -------------------------------------------------------------------------
    -- Dungeons
    -- Dire Maul, Old Hillsbrad, The Black Morass, and The Culling of
    -- Stratholme are NOT in PE Atlas (no AtlasMaps entry) so atlasID=nil;
    -- they still show as pins but clicking them won't open Atlas.
    {"Ashenvale", 0.123, 0.128, "Blackfathom Deeps", "dungeon", "24-32", "BlackfathomDeeps"},
    {"Feralas", 0.648, 0.303, "Dire Maul - East", "dungeon", "55-58", nil},
    {"Feralas", 0.771, 0.369, "Dire Maul - East\n|cFF808080(The Hidden Reach)|r", "dungeon", "55-58", nil},
    {"Feralas", 0.671, 0.34, "Dire Maul - East\n|cFF808080(Side Entrance)|r", "dungeon", "55-58", nil},
    {"Feralas", 0.624, 0.249, "Dire Maul - North", "dungeon", "57-60", nil},
    {"Feralas", 0.604, 0.311, "Dire Maul - West", "dungeon", "57-60", nil},
    {"Desolace", 0.29, 0.629, "Maraudon", "dungeon", "46-55", "Maraudon"},
    {"Ogrimmar", 0.53, 0.486, "Ragefire Chasm", "dungeon", "13-18", "RagefireChasm"},
    {"Barrens", 0.508, 0.94, "Razorfen Downs", "dungeon", "37-46", "RazorfenDowns"},
    {"Barrens", 0.423, 0.9, "Razorfen Kraul", "dungeon", "29-38", "RazorfenKraul"},
    {"Barrens", 0.462, 0.357, "Wailing Caverns", "dungeon", "17-24", "WailingCaverns"},
    {"Tanaris", 0.389, 0.184, "Zul'Farrak", "dungeon", "44-54", "ZulFarrak"},
    {"Tanaris", 0.650, 0.458, "Old Hillsbrad Foothills", "dungeon", "66-70", nil},
    {"Tanaris", 0.685, 0.48, "The Black Morass", "dungeon", "68-70", nil},
    {"Tanaris", 0.678, 0.512, "The Culling of Stratholme", "dungeon", "75-80", nil},
    -- Raids
    -- Onyxia's Lair, AQ20/AQ40, and Hyjal Summit are not in PE Atlas.
    {"Dustwallow", 0.529, 0.777, "Onyxia's Lair", "raid", "60", nil},
    {"Silithus", 0.305, 0.987, "Ruins of Ahn'Qiraj", "raid", "60", nil},
    {"Silithus", 0.269, 0.987, "Temple of Ahn'Qiraj", "raid", "60", nil},
    {"Tanaris", 0.67, 0.45, "Hyjal Summit", "raid", "70", nil},
    -- World Bosses
    {"Aszhara", 0.535, 0.816, "Azuregos", "worldboss", "60", nil},
    {"Ashenvale", 0.937, 0.355, "Emerald Dragon\n|cFF808080(Bough Shadow)|r", "worldboss", "60", nil},
    {"Feralas", 0.512, 0.108, "Emerald Dragon\n|cFF808080(Dream Bough)|r", "worldboss", "60", nil},
    -- Transport
    -- PE places the Horde zeppelin towers inside Orgrimmar (Valley of
    -- Winds), not on the WotLK platform NW of the city in Durotar.
    {"Ogrimmar", 0.90, 0.52, "Zeppelins to Tirisfal Glades & Grom'Gol", "zepp", "Horde", nil, {"Tirisfal", "Stranglethorn"}},
    {"Ogrimmar", 0.83, 0.58, "Zeppelins to Thunder Bluff & Warsong Hold", "zepp", "Horde", nil, "ThunderBluff"},
    {"ThunderBluff", 0.137, 0.257, "Zeppelin to Durotar", "zepp", "Horde", nil, "Durotar"},
    {"Barrens", 0.636, 0.389, "Boat to Booty Bay", "boat", "Neutral", nil, "Stranglethorn"},
    {"Darkshore", 0.333, 0.399, "Boat to Rut'Theran Village", "boat", "Alliance", nil, "Teldrassil"},
    {"Darkshore", 0.325, 0.436, "Boat to Stormwind Harbor", "boat", "Alliance", nil, "Stormwind"},
    {"Dustwallow", 0.718, 0.566, "Boat to Menethil Harbor", "boat", "Alliance", nil, "Wetlands"},
    {"Feralas", 0.311, 0.395, "Boat to Forgotten Coast", "boat", "Alliance", nil, "Feralas"},
    {"Feralas", 0.431, 0.428, "Boat to Sardor Isle", "boat", "Alliance", nil, "Feralas"},
    {"Teldrassil", 0.552, 0.949, "Boat to Auberdine", "boat", "Alliance", nil, "Darkshore"},
    -- Portals
    {"Darnassis", 0.405, 0.817, "Portal to Blasted Lands", "portal", "Alliance", nil, "BlastedLands"},
    {"Ogrimmar", 0.381, 0.857, "Portal to Blasted Lands", "portal", "Horde", nil, "BlastedLands"},
    {"ThunderBluff", 0.232, 0.135, "Portal to Blasted Lands\n|cFF808080(Inside The Pools of Vision)|r", "portal", "Horde", nil, "BlastedLands"},
    -- -------------------------------------------------------------------------
    -- Eastern Kingdoms
    -- -------------------------------------------------------------------------
    -- Dungeons
    {"SearingGorge", 0.387, 0.833, "Blackrock Depths\n|cFF808080(Searing Gorge)|r", "dungeon", "52-60", "BlackrockDepths", "dropdown"},
    {"BurningSteppes", 0.328, 0.365, "Blackrock Depths\n|cFF808080(Burning Steppes)|r", "dungeon", "52-60", "BlackrockDepths", "dropdown"},
    {"Westfall", 0.423, 0.726, "The Deadmines", "dungeon", "17-24", "TheDeadmines"},
    {"DunMorogh", 0.178, 0.392, "Gnomeregan", "dungeon", "29-38", "Gnomeregan"},
    {"DunMorogh", 0.216, 0.30, "Gnomeregan\n|cFF808080(Workshop Entrance)|r", "dungeon", "29-38", "Gnomeregan"},
    {"BurningSteppes", 0.32, 0.39, "Lower Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", "BlackrockSpireLower", "dropdown"},
    {"SearingGorge", 0.379, 0.858, "Lower Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", "BlackrockSpireLower", "dropdown"},
    {"Tirisfal", 0.87, 0.325, "Scarlet Monastery - Armory", "dungeon", "32-42", "SMArmory"},
    {"Tirisfal", 0.862, 0.295, "Scarlet Monastery - Cathedral", "dungeon", "35-45", "SMCathedral"},
    {"Tirisfal", 0.839, 0.283, "Scarlet Monastery - Graveyard", "dungeon", "26-36", "SMGraveyard"},
    {"Tirisfal", 0.85, 0.335, "Scarlet Monastery - Library", "dungeon", "29-39", "SMLibrary"},
    {"WesternPlaguelands", 0.69, 0.729, "Scholomance", "dungeon", "58-60", "Scholomance"},
    {"Silverpine", 0.448, 0.678, "Shadowfang Keep", "dungeon", "22-30", "ShadowfangKeep"},
    {"Stormwind", 0.508, 0.67, "The Stockade", "dungeon", "24-31", "TheStockade"},
    {"EasternPlaguelands", 0.273, 0.122, "Stratholme", "dungeon", "58-60", "Stratholme"},
    {"EasternPlaguelands", 0.437, 0.175, "Stratholme\n|cFF808080(Back Gate)|r", "dungeon", "58-60", "Stratholme"},
    {"SwampOfSorrows", 0.703, 0.55, "The Sunken Temple", "dungeon", "50-60", "TheSunkenTemple"},
    {"Badlands", 0.429, 0.13, "Uldaman", "dungeon", "41-51", "Uldaman"},
    {"Badlands", 0.657, 0.438, "Uldaman\n|cFF808080(Back Entrance)|r", "dungeon", "41-51", "Uldaman"},
    {"BurningSteppes", 0.312, 0.365, "Upper Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", "BlackrockSpireUpper", "dropdown"},
    {"SearingGorge", 0.371, 0.833, "Upper Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", "BlackrockSpireUpper", "dropdown"},
    -- Raids
    -- Blackwing Lair, Zul'Gurub, and Karazhan are not in PE Atlas; they
    -- still pin on the map but do not open an Atlas page on click.
    {"SearingGorge", 0.332, 0.833, "Blackwing Lair\n|cFF808080(Searing Gorge)|r", "raid", "60", nil, "dropdown"},
    {"BurningSteppes", 0.273, 0.363, "Blackwing Lair\n|cFF808080(Burning Steppes)|r", "raid", "60", nil, "dropdown"},
    {"SearingGorge", 0.332, 0.86, "Molten Core\n|cFF808080(Searing Gorge)|r", "raid", "60", "MoltenCore", "dropdown"},
    {"BurningSteppes", 0.273, 0.39, "Molten Core\n|cFF808080(Burning Steppes)|r", "raid", "60", "MoltenCore", "dropdown"},
    {"Stranglethorn", 0.53, 0.172, "Zul'Gurub", "raid", "60", nil},
    {"DeadwindPass", 0.469, 0.747, "Karazhan", "raid", "70", nil},
    {"DeadwindPass", 0.467, 0.708, "Karazhan\n|cFF808080(Side Entrance)|r", "raid", "70", nil},
    -- World Bosses
    {"Duskwood", 0.465, 0.357, "Emerald Dragon\n|cFF808080(The Twilight Grove)|r", "worldboss", "60", nil},
    {"Hinterlands", 0.632, 0.217, "Emerald Dragon\n|cFF808080(Seradane)|r", "worldboss", "60", nil},
    -- Transport
    {"Stormwind", 0.677, 0.325, "Tram to Ironforge", "tram", "Alliance", nil, "Ironforge"},
    {"Ironforge", 0.762, 0.511, "Tram to Stormwind", "tram", "Alliance", nil, "Stormwind"},
    {"Wetlands", 0.051, 0.634, "Boat to Theramore Isle", "boat", "Alliance", nil, "Dustwallow"},
    {"Stranglethorn", 0.257, 0.73, "Boat to Ratchet", "boat", "Neutral", nil, "Barrens"},
    {"Tirisfal", 0.606, 0.583, "Zeppelins to Durotar, Grom'Gol & Vengeance Landing", "zepp", "Horde", nil, {{"Durotar", "Durotar"}, {"Stranglethorn", "Grom'Gol"}}},
    {"Stranglethorn", 0.312, 0.298, "Zeppelins to Tirisfal Glades & Durotar", "zepp", "Horde", nil, {"Tirisfal", "Durotar"}},
    {"Stormwind", 0.216, 0.562, "Boat to Auberdine", "boat", "Alliance", nil, "Darkshore"},
    -- Portals
    {"Undercity", 0.852, 0.17, "Portal to Blasted Lands", "portal", "Horde", nil, "BlastedLands"},
    {"Stormwind", 0.490, 0.873, "Portal to Blasted Lands", "portal", "Alliance", nil, "BlastedLands"},
    {"Ironforge", 0.272, 0.07, "Portal to Blasted Lands", "portal", "Alliance", nil, "BlastedLands"},
}

-- WDM points intentionally omitted in the PE refactor (see design doc).
MMM_WdmPoints = {}
