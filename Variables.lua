-- local functions
local GetSpellInfo = GetSpellInfo;
local string_format = string.format;

-- local variables
local _;

-- global Gnosis event tables
Gnosis.tCastbarEvents = {
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_INTERRUPTIBLE",
	"UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_FAILED_QUIET",
	"UNIT_SPELLCAST_SUCCEEDED",
};

Gnosis.tMiscEvents = {
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"UNIT_SPELLCAST_SENT",
	"PLAYER_ENTERING_WORLD",
	"PLAYER_FOCUS_CHANGED",
	"PLAYER_TARGET_CHANGED",
	"DISPLAY_SIZE_CHANGED",
	"PLAYER_TALENT_UPDATE",
};

Gnosis.tMirrorEvents = {
	"MIRROR_TIMER_START",
	"MIRROR_TIMER_STOP",
	"PLAYER_UNGHOST",
	"PLAYER_ALIVE",
};

Gnosis.tBlizzCastbar = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_INTERRUPTIBLE",
	"UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	"PLAYER_ENTERING_WORLD",
};

Gnosis.tBlizzMirrorUiParent = {
	"MIRROR_TIMER_START",
};

Gnosis.tBlizzMirror123 = {
	"MIRROR_TIMER_STOP",
	"MIRROR_TIMER_PAUSE",
	"PLAYER_ENTERING_WORLD",
};

Gnosis.tSwingEvents = {
	"PLAYER_ENTER_COMBAT",
	"PLAYER_LEAVE_COMBAT",
	"START_AUTOREPEAT_SPELL",
	"STOP_AUTOREPEAT_SPELL"
};

-- mirror bar icons for breath, fatigue and feign death
Gnosis.tMirrorIcons = {
	["BREATH"] = "Interface\\Icons\\Spell_Shadow_DemonBreath",
	["EXHAUSTION"] = "Interface\\Icons\\Ability_Suffocate",
	["FEIGNDEATH"] = "Interface\\Icons\\Ability_Rogue_FeignDeath",
};

Gnosis.tRuneName = {
	[1] = _G["COMBAT_TEXT_RUNE_BLOOD"],
	[2] = _G["COMBAT_TEXT_RUNE_UNHOLY"],
	[3] = _G["COMBAT_TEXT_RUNE_FROST"],
	[4] = _G["COMBAT_TEXT_RUNE_DEATH"],
};

Gnosis.tRuneTexture = {
	[1] = "Interface\\PlayerFrame\\Deathknight-Energize-Blood",
	[2] = "Interface\\PlayerFrame\\Deathknight-Energize-Unholy",
	[3] = "Interface\\PlayerFrame\\Deathknight-Energize-Frost",
	[4] = "Interface\\PlayerFrame\\Deathknight-Energize-White",
};

-- spell school colors
Gnosis.colSchools = {
	physical	= "1, 1, 1, 1",
	holy		= "1, 1, 0.627, 1",
	fire		= "1, 0.5, 0.5, 1",
	nature		= "0.5, 1, 0.5, 1",
	frost		= "0.5, 0.5, 1, 1",
	shadow		= "0.628, 0, 0.628, 1",
	arcane		= "1, 0.725, 1, 1",
	frostfire	= "0.824, 0.314, 0.471, 1",
};

-- class colors (http://www.wowwiki.com/Class_colors)
Gnosis.colClasses = {
	DEATHKNIGHT	= "0.77, 0.12, 0.23, 1.00",
	DRUID		= "1.00, 0.49, 0.04, 1.00",
	HUNTER		= "0.67, 0.83, 0.45, 1.00",
	MAGE		= "0.41, 0.80, 0.94, 1.00",
	MONK		= "0.33, 0.54, 0.52, 1.00",
	PALADIN		= "0.96, 0.55, 0.73, 1.00",
	PRIEST		= "1.00, 1.00, 1.00, 1.00",
	ROGUE		= "1.00, 0.96, 0.41, 1.00",
	SHAMAN		= "0.00, 0.44, 0.87, 1.00",
	WARLOCK		= "0.58, 0.51, 0.79, 1.00",
	WARRIOR		= "0.78, 0.61, 0.43, 1.00",
};

Gnosis.tPremadeNfs = {
	[1] = "namecol<1,0,0>txm< (>misctxm<)>col<pre>txts< (>tscurtxts</>tstottxts<)>",
	[2] = "namecol<1,0,0>txeff< (>effecttxeff<)>col<pre>",
	[3] = "col<1,1,0>whocol<pre>: name",
};

Gnosis.tPremadeTfs = {
	[1] = "col<1,0,0>p<2s>col<pre> r<1m> / t<2m>",
	[2] = "col<1,0,0>p<2s>col<pre> r<1> / t<2>",
	[3] = "r<2m> / t<3m>",
};

Gnosis.tSoundChannels = {
	[1] = "Master",
	[2] = "SFX",
	[3] = "Ambience",
	[4] = "Music",
};

function Gnosis:StartupVariables()
	local fCurTime = GetTime() * 1000;

	self.ver = 4.65;
	self.optver = 4.62;
	self.build = "r184";
	self.addonname = "Gnosis";
	local strVer = string_format("v%.2f", self.ver);
	if(self.build == strVer) then
		self.title = string_format("%s %s", self.addonname, strVer);
	else
		self.title = string_format("%s %s (%s)", self.addonname, strVer, self.build);
	end

	-- initial latency
	self.lag = select(4, GetNetStats());
	self.lastTimerScan = fCurTime;

	-- tables
	self.castbars = {};		-- castbars
	self.activebars = {};	-- currently active bars (performance reasons)
	self.fadeoutbars = {};	-- bars to fade out
	self.unusedcastbars = {};	-- table to store deleted castbar frames
	self.cb_fl = {};		-- castbar fast lookup
	self.ti_fl = {};		-- timer fast lookup
	self.ti_icd = {};		-- inner cooldown scan table
	self.ti_icd_active = {};-- active inner cooldowns
	self.scan = {};			-- units to scan
	self.counters = {};		-- counters
	self.timer_cds = {};	-- track player cds
	
	-- play intervals (audio)
	self.played = {
		s = {},
		m = {},
		f = {},
	};
	
	-- (LibSharedMedia)
	self.bartexnames = {};
	self.bartextures = {};
	self.fonts = {};
	self.fontnames = {};
	self.music = {};
	self.musicnames = {};

	-- events registered to blizzard castbar
	self.blizzcastbar = {};
	self.petcastbar = {};

	-- events registered to blizzard mirror castbar
	self.blizzmirroruiparent = {};
	self.blizzmirror1 = {};
	self.blizzmirror2 = {};
	self.blizzmirror3 = {};

	-- clip test
	self.curchannel = nil;	-- currently channeling spell
	self.nextchannel = nil;	--

	-- default variables
	self.tDefaults = {
		bAddonEn = true,
		bHideBlizz = false,
		bHideMirror = false,
		bHidePetVeh = false,
		bHideAddonMsgs = false,
		bResizeOptions = true,
		-- option settings
		bAutoCreateOptions = false,

		-- castbar configs
		cbconf = {},
		nameNewBar = "",

		-- channeled spells
		channeledspells = {},

		-- combat text/clip
		ct = {
			bsound = true,
			bmusic = false,
			bfile = false,
			sound = "MONEYFRAMEOPEN",
			music = nil,
			file = nil,
			channel = 1,
		},

		configs = {
			name = "",
			bsavecastbars = true,
			bsavespell = true,
			bsavedefaultopt = true,
			bsavectct = true,
		},

		-- clip test
		wfcl = 1000,	-- wait for combat log data (in ms), combat log timing tends to be bitchy (well, at least on Frostwolf)
		ctt = 300,		-- clip test time (in ms)

		-- timer scan
		iTimerScanEvery = 150,	-- scan for spell/item cooldowns and auras every 150ms (default)
	};

	-- set default combat text addon, if multiple addons found than MSBT > Parrot > SCT
	self.tDefaults.ct.addon = (MikSBT and "MSBT" or (Parrot and "Parrot" or (SCT and "SCT" or "Blizz")));

	-- swing timer
	self.iSwing = 0;				-- 1 == melee (onehand), 2 == range
	self.bSwingBar = false;	-- combat log event unfiltered registered
	self.iExtraSwings = 0;
	self.bNextSwingNotExtra = false;
	_, self.class = UnitClass("player");
	self.bIsDruid = self.class == "DRUID";

	self.curincombattype = 3;		-- set as out of combat

	self.tCastbarDefaults = {
		-- castbar options v
		cboptver = self.optver,

		-- default unit
		unit = "player",
		bartype = "cb",

		-- bar geometry
		width = 250,
		height = 20,
		border = 2.0,
		bordericon = 2.0,
		scale = 1.0,
		scaleicon = 1.0,
		alpha = 1.0,
		fadeout = 0.4;
		latbarsize = 0.15;
		latbarfixed = 0.03;

		-- coordinates
		coord = {
			castname = { x = 9, y = 0 },
			casttime = { x = -9, y = 0 },
			casticon = { x = -3, y = 0 },
			latency = { x = -1, y = 1 },
			shadow = { x = 3, y = -3 },
		},

		-- alignments
		alignment = "NAMETIME",	-- new alignment options for name and time (v1.30)
		alignname = "LEFT",		--
		aligntime = "RIGHT", 	--
		alignlat = "ADAPT",		--

		-- spark modifiers
		fSparkHeightMulti = 1.2,
		fSparkWidthMulti = 0.8,

		-- default bar colors
		colBar = { 0.15, 0.35, 0.35, 0.70 },
		colBarNI = { 0.15, 0.35, 0.35, 0.70 },
		colBarBg = { 0.15, 0.42, 0.42, 0.65 },
		colLagBar  = { 0.90, 0.85, 0.70, 0.65 },
		colBorder = { 0.00, 0.00, 0.00, 0.85 },
		colBorderNI = { 1.00, 0.80, 0.00, 0.85 },
		colText = { 1.00, 1.00, 1.00, 1.00 },
		colTextTime = { 1.00, 1.00, 1.00, 1.00 },
		colTextLag = { 1.00, 0.00, 0.00, 1.00 },
		colInterrupted = { 1.00, 0.80, 0.00, 0.70 },
		colFailed = { 0.70, 0.30, 0.20, 0.75 },
		colSpark = { 1.00, 1.00, 1.00, 1.00 },
		colSuccess = { 0.15, 0.25, 0.10, 0.70 },
		colShadow = { 0.00, 0.00, 0.00, 0.70 },

		-- default statusbar texture
		bartexture = "Gnosis_Plain",
		bordertexture = nil,

		-- bar settings
		anchor = nil,
		bEn = true,				-- enabled
		spectab =				-- active for all possible talent specializations
			{ [1] = true, [2] = true, [3] = true, [4] = true },
		bShowWNC = false,		-- show when not casting
		bShowLat = true,		-- show latency box
		bShowCBS = true,		-- show castbar spark
		bShowTicks = true,		-- show channeled ticks
		bExtChannels = true,	-- extend channeled spells
		bUnlocked = true,		-- unlocked when first created
		bFillup = false,		-- fill bar up at end of cast
		bShowShield = false,	-- do not show shielded icon for non-intteruptible casts
		iconside = "LEFT",		-- where to draw icon
		fontoutline = "OUTLINE",-- font outline
		font = "Accidental Presidency",		-- "Accidental Presidency", v4.00
		fontsize = 0,			-- automatic
		fontsize_timer = 0,		-- automatic
		fontsize_lat = 0,		-- automatic

		relationsel = 1,		-- show casts of friendly and/or enemy units
		incombatsel = 1,		-- show castbar in and out of combat (1==always)
		ingroupsel = 1,			-- show castbar while solo, in party or raid (1==always)
		instancetype = 1,		-- show castbar while inside or outside of instance (1==always)
		bnwtypesel = 1,			-- neither black-/whitelist
		bnwlist = {},			-- empty list to begin with
		bnwlistnew = "",		-- new entry box
		bResizeLongName = false,-- automatic resize of long spell names
		strata = "MEDIUM",		-- medium frame strata
		strNameFormat = Gnosis.tPremadeNfs[1],	-- default nfs
		strTimeFormat = Gnosis.tPremadeTfs[1],	-- default tfs
		bShowPlayerLatency = true,	-- do not show text latency information
		bShowAsMinutes = true,	-- show timer in minutes if longer than 60s
		bMergeTrade = true,		-- merge tradeskill information
		bIconUnlocked = false,	-- option to unlock icon (v1.31)
		strGap = 15,			-- minimum distance between name and time text

		rotateicon = 0,			-- rotate icon (degrees)
		orient = 1,				-- castbar orientation (horizontal, vertical)
		bInvDir = false,		-- invert bar direction
		bColSuc = false,		-- change castbar color when cast finished successfully
		bEnShadowOffset = false,-- enable changing of text shadow offset
		bEnShadowCol = true,	-- change text shadow color

		-- anchoring
		anchortype = 1,			-- no anchor
		anchorframe = "",		-- Anchor frame name
		anchorfrom = 5,			-- Gnosis bar anchor point
		anchorto = 5,			-- Anchor frame anchor point
		anchor_x = 0,			-- Offset x
		anchor_y = 0,			-- Offset y

		-- rotate text
		rotatectext = 0,		--
		rotatertext = 0,		--
		rotatelattext = 0,		--
	};
	
	self.tIconLikeOverrides = {
		-- bar geometry
		width = 40,
		height = 40,
		border = 0,
		
		coord = {
			castname = { x = 0, y = 0 },
			casttime = { x = 3, y = 0 },
			casticon = { x = 42, y = 0 },
			latency = { x = -1, y = 1 },
			shadow = { x = 3, y = -3 },
		},
		
		-- alignments
		alignment = "FREE",	-- new alignment options for name and time (v1.30)
		alignname = "CENTER",		--
		aligntime = "CENTER", 	--
		
		-- default bar colors
		colBar = { 0.15, 0.35, 0.35, 0.0 },
		colBarNI = { 0.15, 0.35, 0.35, 0.0 },
		colBarBg = { 0.15, 0.42, 0.42, 0.0 },
		colLagBar  = { 0.90, 0.85, 0.70, 0.0 },
		colBorder = { 0.00, 0.00, 0.00, 0.85 },
		colBorderNI = { 1.00, 0.80, 0.00, 0.0 },
		colText = { 1.00, 1.00, 1.00, 1.00 },
		colTextTime = { 1.00, 1.00, 1.00, 1.00 },
		colTextLag = { 1.00, 0.00, 0.00, 1.00 },
		colInterrupted = { 1.00, 0.80, 0.00, 0 },
		colFailed = { 0.70, 0.30, 0.20, 0 },
		colSpark = { 1.00, 1.00, 1.00, 0 },
		colSuccess = { 0.15, 0.25, 0.10, 0 },
		colShadow = { 0.00, 0.00, 0.00, 0.70 },

		-- bar settings
		bShowLat = false,		-- show latency box
		bShowCBS = false,		-- show castbar spark
		bShowTicks = false,		-- show channeled ticks
		strNameFormat = "",		-- default nfs
		strTimeFormat = "r<0m>",-- default tfs
		bShowPlayerLatency = false,	-- do not show text latency information
		bMergeTrade = false,		-- merge tradeskill information
		bIconUnlocked = true,	-- option to unlock icon (v1.31)
	};

	self.strAutoShot, _, self.iconAutoShot = GetSpellInfo(75);
	self.strAutoAttack, _, self.iconAutoAttack = GetSpellInfo(6603);
	self.strShootWand, _, self.iconShootWand = GetSpellInfo(5019);

	self.toyIcon = "Interface\\Icons\\Inv_Misc_Toy_07";

	if (not GnosisConfigs) then
		GnosisConfigs = {};
	end
end

-- sound files
Gnosis.BlizzSounds = {
	["PVPENTERQUEUE"] = "PVPENTERQUEUE",
	["PVPTHROUGHQUEUE"] = "PVPTHROUGHQUEUE",
	["GAMEABILITYBUTTONMOUSEDOWN"] = "GAMEABILITYBUTTONMOUSEDOWN",
	["GAMESPELLBUTTONMOUSEDOWN"] = "GAMESPELLBUTTONMOUSEDOWN",
	["GAMETARGETFRIENDLYUNIT"] = "GAMETARGETFRIENDLYUNIT",
	["GAMETARGETHOSTILEUNIT"] = "GAMETARGETHOSTILEUNIT",
	["GAMETARGETNEUTRALUNIT"] = "GAMETARGETNEUTRALUNIT",
	["ACTIONBARBUTTONDOWN"] = "ACTIONBARBUTTONDOWN",
	["MINIMAPZOOMOUT"] = "MINIMAPZOOMOUT",
	["MINIMAPZOOMIN"] = "MINIMAPZOOMIN",
	["MINIMAPOPEN"] = "MINIMAPOPEN",
	["BAGMENUBUTTONPRESS"] = "BAGMENUBUTTONPRESS",
	["ITEMWEAPONSOUND"] = "ITEMWEAPONSOUND",
	["ITEMARMORSOUND"] = "ITEMARMORSOUND",
	["ITEMGENERICSOUND"] = "ITEMGENERICSOUND",
	["LEVELUPSOUND"] = "LEVELUPSOUND",
	["GLUECREATECHARACTERBUTTON"] = "GLUECREATECHARACTERBUTTON",
	["GLUEENTERWORLDBUTTON"] = "GLUEENTERWORLDBUTTON",
	["SPELLBOOKOPEN"] = "SPELLBOOKOPEN",
	["SPELLBOOKCLOSE"] = "SPELLBOOKCLOSE",
	["SPELLBOOKCHANGEPAGE"] = "SPELLBOOKCHANGEPAGE",
	["PAPERDOLLOPEN"] = "PAPERDOLLOPEN",
	["PAPERDOLLCLOSE"] = "PAPERDOLLCLOSE",
	["QUESTADDED"] = "QUESTADDED",
	["QUESTCOMPLETED"] = "QUESTCOMPLETED",
	["QUESTLOGOPEN"] = "QUESTLOGOPEN",
	["QUESTLOGCLOSE"] = "QUESTLOGCLOSE",
	["SHEATHINGSHIELDSHEATHE"] = "SHEATHINGSHIELDSHEATHE",
	["SHEATHINGWOODWEAPONSHEATHE"] = "SHEATHINGWOODWEAPONSHEATHE",
	["SHEATHINGMETALWEAPONSHEATHE"] = "SHEATHINGMETALWEAPONSHEATHE",
	["SHEATHINGWOODWEAPONUNSHEATHE"] = "SHEATHINGWOODWEAPONUNSHEATHE",
	["SHEATHINGMETALWEAPONUNSHEATHE"] = "SHEATHINGMETALWEAPONUNSHEATHE",
	["SHEATHINGSHIELDUNSHEATHE"] = "SHEATHINGSHIELDUNSHEATHE",
	["GAMEERRORUNABLETOEQUIP"] = "GAMEERRORUNABLETOEQUIP",
	["ITEMGENERICSOUND"] = "ITEMGENERICSOUND",
	["GAMEERRORINVALIDTARGET"] = "GAMEERRORINVALIDTARGET",
	["LEVELUP"] = "LEVELUP",
	["GAMEERROROUTOFRANGE"] = "GAMEERROROUTOFRANGE",
	["QUESTADDED"] = "QUESTADDED",
	["MONEYFRAMEOPEN"] = "MONEYFRAMEOPEN",
	["MONEYFRAMECLOSE"] = "MONEYFRAMECLOSE",
	["LOOTWINDOWOPEN"] = "LOOTWINDOWOPEN",
	["LOOTWINDOWCLOSE"] = "LOOTWINDOWCLOSE",
	["LOOTWINDOWCOINSOUND"] = "LOOTWINDOWCOINSOUND",
	["GAMEHIGHLIGHTHOSTILEUNIT"] = "GAMEHIGHLIGHTHOSTILEUNIT",
	["GAMEHIGHLIGHTNEUTRALUNIT"] = "GAMEHIGHLIGHTNEUTRALUNIT",
	["GAMEHIGHLIGHTFRIENDLYUNIT"] = "GAMEHIGHLIGHTFRIENDLYUNIT",
	["INTERFACESOUND_LOSTTARGETUNIT"] = "INTERFACESOUND_LOSTTARGETUNIT",
	["INTERFACESOUND_CURSORGRABOBJECT"] = "INTERFACESOUND_CURSORGRABOBJECT",
	["INTERFACESOUND_CURSORDROPOBJECT"] = "INTERFACESOUND_CURSORDROPOBJECT",
	["GAMESCREENMEDIUMBUTTONMOUSEDOWN"] = "GAMESCREENMEDIUMBUTTONMOUSEDOWN",
	["GAMEABILITYACTIVATE"] = "GAMEABILITYACTIVATE",
	["GAMESPELLACTIVATE"] = "GAMESPELLACTIVATE",
	["gsTitleEnterWorld"] = "gsTitleEnterWorld",
	["gsTitleOptions"] = "gsTitleOptions",
	["gsTitleQuit"] = "gsTitleQuit",
	["gsTitleCredits"] = "gsTitleCredits",
	["gsTitleIntroMovie"] = "gsTitleIntroMovie",
	["gsTitleOptionScreenResolution"] = "gsTitleOptionScreenResolution",
	["gsTitleOption16bit"] = "gsTitleOption16bit",
	["gsTitleOption32bit"] = "gsTitleOption32bit",
	["gsTitleOptionOpenGL"] = "gsTitleOptionOpenGL",
	["gsTitleOptionDirect3D"] = "gsTitleOptionDirect3D",
	["gsTitleOptionFullScreenMode"] = "gsTitleOptionFullScreenMode",
	["gsTitleOptionOK"] = "gsTitleOptionOK",
	["gsTitleOptionExit"] = "gsTitleOptionExit",
	["gsLogin"] = "gsLogin",
	["gsLoginNewAccount"] = "gsLoginNewAccount",
	["gsLoginChangeRealm"] = "gsLoginChangeRealm",
	["gsLoginExit"] = "gsLoginExit",
	["gsLoginChangeRealmOK"] = "gsLoginChangeRealmOK",
	["gsLoginChangeRealmSelect"] = "gsLoginChangeRealmSelect",
	["gsLoginChangeRealmCancel"] = "gsLoginChangeRealmCancel",
	["gsCharacterSelection"] = "gsCharacterSelection",
	["gsCharacterSelectionEnterWorld"] = "gsCharacterSelectionEnterWorld",
	["gsCharacterSelectionDelCharacter"] = "gsCharacterSelectionDelCharacter",
	["gsCharacterSelectionAcctOptions"] = "gsCharacterSelectionAcctOptions",
	["gsCharacterSelectionExit"] = "gsCharacterSelectionExit",
	["gsCharacterSelectionCreateNew"] = "gsCharacterSelectionCreateNew",
	["gsCharacterCreationClass"] = "gsCharacterCreationClass",
	["gsCharacterCreationRace"] = "gsCharacterCreationRace",
	["gsCharacterCreationGender"] = "gsCharacterCreationGender",
	["gsCharacterCreationLook"] = "gsCharacterCreationLook",
	["gsCharacterCreationCreateChar"] = "gsCharacterCreationCreateChar",
	["gsCharacterCreationCancel"] = "gsCharacterCreationCancel",
	["UChatScrollButton"] = "UChatScrollButton",
	["Deathbind Sound"] = "Deathbind Sound",
	["LOOTWINDOWOPENEMPTY"] = "LOOTWINDOWOPENEMPTY",
	["TaxiNodeDiscovered"] = "TaxiNodeDiscovered",
	["UnwrapGift"] = "UnwrapGift",
	["TellMessage"] = "TellMessage",
	["WriteQuest"] = "WriteQuest",
	["MapPing"] = "MapPing",
	["igBonusBarOpen"] = "igBonusBarOpen",
	["FriendJoinGame"] = "FriendJoinGame",
	["Fishing Reel in"] = "Fishing Reel in",
	["HumanExploration"] = "HumanExploration",
	["OrcExploration"] = "OrcExploration",
	["UndeadExploration"] = "UndeadExploration",
	["TaurenExploration"] = "TaurenExploration",
	["TrollExploration"] = "TrollExploration",
	["NightElfExploration"] = "NightElfExploration",
	["GnomeExploration"] = "GnomeExploration",
	["DwarfExploration"] = "DwarfExploration",
	["igPVPUpdate"] = "igPVPUpdate",
	["ReadyCheck"] = "ReadyCheck",
	["RaidWarning"] = "RaidWarning",
	["AuctionWindowOpen"] = "AuctionWindowOpen",
	["AuctionWindowClose"] = "AuctionWindowClose"
};
