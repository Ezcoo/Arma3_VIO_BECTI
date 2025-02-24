CTI_UI_Respawn_GetAvailableLocations = {
	private ["_fobs", "_hq", "_ignore_mobile_crew", "_list", "_mobile", "_structures"];
	
	_list = [];
	
	_hq = (CTI_P_SideJoined) call CTI_CO_FNC_GetSideHQ;
	_deployed = (CTI_P_SideJoined) call CTI_CO_FNC_GetSideHQDeployStatus;
	_structures = (CTI_P_SideJoined) call CTI_CO_FNC_GetSideStructures;
	if (alive _hq && !_deployed) then {_list pushBack _hq}; //--- Don't add HQ if deployed as it already counts as a structure
	_list = _list + _structures;
	if (count _list < 1) then {_list = [_hq]};
	
	//--- Add FOBs if available.
	if (CTI_BASE_FOB_MAX > 0) then {
		_fobs = CTI_P_SideLogic getVariable ["cti_fobs", []];
		{if (alive _x && _x distance CTI_DeathPosition <= CTI_RESPAWN_FOB_RANGE) then {_list pushBack _x}} forEach _fobs;
	};
	
	//--- Add mobile respawns if available (Also we retrieve the crew which may belong to the player to prevent "in-AI-respawn" over those)
	_ignore_mobile_crew = [];
	if ((missionNamespace getVariable "CTI_RESPAWN_MOBILE") > 0) then {
		_mobile = (CTI_DeathPosition) call CTI_UI_Respawn_GetMobileRespawn;
		_list = _list + _mobile;
		{{if (group _x == group player) then {_ignore_mobile_crew pushBack _x}} forEach crew _x} forEach _mobile;
	};
	
	//--- Add the nearest player's AI (impersonation) minus the mobile's crew
	if ((missionNamespace getVariable "CTI_RESPAWN_AI") > 0) then {
		{
			if (_x distance CTI_DeathPosition <= CTI_RESPAWN_AI_RANGE && !(_x in _ignore_mobile_crew) && !isPlayer _x) then {_list pushBack _x};
		} forEach ((units player - [player]) call CTI_CO_FNC_GetLiveUnits);
	};
	
	//--- Add camps if available
	if ((missionNamespace getVariable "CTI_RESPAWN_CAMPS_MODE") > 0) then {
		_side = CTI_P_SideJoined;
		_list = _list + (_side Call CTI_UI_Respawn_GetCamps);
	};

	_list;
};

CTI_UI_Respawn_GetMobileRespawn = {
	private ["_available", "_center"];
	_center = _this;
	
	_available = [];
	
	{
		if ((_x getVariable ["cti_spec", -1]) == CTI_SPECIAL_MEDICALVEHICLE && (_x getVariable ["cti_net", -1]) == CTI_P_SideID) then {_available pushBack _x};
	} forEach ((_center nearEntities [["Car","Air","Tank","Ship"], CTI_RESPAWN_MOBILE_RANGE]) + (nearestObjects [_center, ["StaticWeapon", "Thing"], CTI_RESPAWN_MOBILE_RANGE])); //--- Huron/Taru pods arent returned with near entities?
	
	_available
};

CTI_UI_Respawn_GetListLabels = {
	private ["_emplacements", "_hq", "_list"];
	
	_emplacements = _this;
	
	_list = [];
	_hq = (CTI_P_SideJoined) call CTI_CO_FNC_GetSideHQ;
	
	{
		_list = _list + [format["%1 - %2", _x call CTI_UI_Respawn_GetRespawnLabel, _x call CTI_UI_Respawn_GetLocationInformation]];
	} forEach _emplacements;
	
	_list
};

CTI_UI_Respawn_GetRespawnLabel = {
	private ["_location", "_value"];
	_location = _this;

	_value = "Structure";
	switch (true) do {
		case (_location == (CTI_P_SideJoined call CTI_CO_FNC_GetSideHQ)): { _value = "Headquarters"	};
		case (!isNil {_location getVariable "cti_structure_type"}): { 
			_var = missionNamespace getVariable format ["CTI_%1_%2", CTI_P_SideJoined, _location getVariable "cti_structure_type"];
			_value = (_var select 0) select 1;
		};
		case (_location isKindOf "AllVehicles" || _location isKindOf "SlingLoad_Base_F"): { _value = getText(configFile >> "CfgVehicles" >> typeOf _location >> "displayName") };
		case (!isNil {_location getVariable "CTI_CO_CAMP_BUNKER"}): { _value = "Camp" };
	};
	
	_value
};

CTI_UI_Respawn_GetLocationInformation = {
	private ["_closest", "_direction", "_direction_eff", "_distance", "_distance_near", "_format", "_location"];
	
	_location = _this;
	_format = "";
	
	_closest = (_location) call CTI_CO_FNC_GetClosestTown;
	_direction = [_closest, _location] call CTI_CO_FNC_GetDirTo;
	if (_direction < 0) then { _direction = _direction + 360};
	
	_direction_eff = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"];
	_direction_eff = _direction_eff select round((_direction + 22.5)/45);
	
	_distance = _closest distance _location;
	_distance_near = _distance - (_distance % 100);
	
	format ["%1 %2 %3",_closest getVariable "cti_town_name", _direction_eff, _distance_near]
};

CTI_UI_Respawn_AppendTracker = {
	private ["_location", "_marker", "_tracker"];
	
	_location = _this;
	
	_marker = createMarkerLocal [Format ["cti_respawn_marker %1", CTI_P_MarkerIterator], getPos _location];
	CTI_P_MarkerIterator = CTI_P_MarkerIterator + 1;
	_marker setMarkerTypeLocal "Select";
	_marker setMarkerColorLocal "ColorYellow";
	_marker setMarkerSizeLocal [1,1];
	
	_tracker = uiNamespace getVariable "cti_dialog_ui_respawnmenu_locations_tracker";
	_tracker pushBack [_location, _marker];
	
	if (_location isKindOf "AllVehicles") then {
		[_location, _marker] spawn {
			_location = _this select 0;
			_marker = _this select 1;
			
			while {!isNil {uiNamespace getVariable "cti_dialog_ui_respawnmenu"} && alive _location} do {
				_locations_tracker = uiNamespace getVariable "cti_dialog_ui_respawnmenu_locations_tracker";
				
				_marker setMarkerPosLocal (getPos _location);
				
				_abort = true;
				{ if ((_x select 0) == _location) exitWith {_abort = false} } forEach _locations_tracker;
				sleep .25;
			};
		};
	};
};

CTI_UI_Respawn_LoadLocations = {
	private ["_old_locations", "_respawn_locations", "_respawn_locations_formated", "_set", "_spawn"];
	_respawn_locations = call CTI_UI_Respawn_GetAvailableLocations;
	_respawn_locations = [CTI_DeathPosition, _respawn_locations] call CTI_CO_FNC_SortByDistance;
	_respawn_locations_formated = (_respawn_locations) call CTI_UI_Respawn_GetListLabels;
	
	_old_locations = uiNamespace getVariable "cti_dialog_ui_respawnmenu_locations";
	if (isNil '_old_locations') then { _old_locations = [] };
	uiNamespace setVariable ["cti_dialog_ui_respawnmenu_locations", _respawn_locations];
	
	{if !(_x in _old_locations) then {(_x) call CTI_UI_Respawn_AppendTracker}} forEach _respawn_locations;
	
	lbClear ((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120002);
	
	{
		((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120002) lbAdd _x;
		// ((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120002) lbSetValue [_forEachIndex, _forEachIndex];
	} forEach _respawn_locations_formated;
	
	//--- Is a spawn currently selected?
	_spawn = uiNamespace getVariable "cti_dialog_ui_respawnmenu_respawnat";
	
	_set = false;
	{
		if (_x == _spawn) exitWith { _set = true; uiNamespace setVariable ["cti_dialog_ui_respawnmenu_respawn_update", false]; ((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120002) lbSetCurSel _forEachIndex; };
	} forEach _respawn_locations;
	
	if !(_set) then {
		((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120002) lbSetCurSel 0;
	};
};

CTI_UI_Respawn_CenterMap = {
	private ["_position"];
	_position = _this;
	
	ctrlMapAnimClear ((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120001);
	((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120001) ctrlMapAnimAdd [.65, .35, _position];
	ctrlMapAnimCommit ((uiNamespace getVariable "cti_dialog_ui_respawnmenu") displayCtrl 120001);
};

CTI_UI_Respawn_UseSelector = {
	private ["_marker","_marker_difference","_marker_expand","_marker_dir","_marker_min_size","_marker_max_size","_marker_size","_target"];
	
	_target = _this;
	_marker_size = 1.4;
	_marker_min_size = 1.4;
	_marker_max_size = 1.8;
	_marker_dir = 0;
	_marker_difference = (_marker_max_size - _marker_min_size)/10;
	_marker_expand = true;

	_marker = createMarkerLocal [format["cti_respawn_selector_%1", CTI_P_MarkerIterator], [0,0,0]];
	CTI_P_MarkerIterator = CTI_P_MarkerIterator + 1;
	_marker setMarkerTypeLocal "Select";
	_marker setMarkerColorLocal CTI_P_SideColor;
	_marker setMarkerSizeLocal [_marker_size, _marker_size];

	while {_target == (uiNamespace getVariable "cti_dialog_ui_respawnmenu_respawnat") && !isNil {uiNamespace getVariable "cti_dialog_ui_respawnmenu"}} do {
		_marker_dir = (_marker_dir + 1) % 360;
		_marker setMarkerDirLocal _marker_dir;
		_marker setMarkerSizeLocal [_marker_size, _marker_size];
		
		if (_marker_size > _marker_max_size) then {_marker_expand = false};
		if (_marker_size < _marker_min_size) then {_marker_expand = true};
		if (_marker_expand) then {_marker_size = _marker_size + _marker_difference} else {_marker_size = _marker_size - _marker_difference};
		
		if (getMarkerPos _marker distance _target > 0.5) then {_marker setMarkerPosLocal getPos _target};
		
		sleep .03;
	};

	deleteMarkerLocal _marker;
};

CTI_UI_Respawn_OnRespawnReady = {
	_where = uiNamespace getVariable "cti_dialog_ui_respawnmenu_respawnat";
	
	_respawn_ai = false;
	_respawn_ai_gear = [];
	if (_where isKindOf "Man") then { //--- The location is an AI?
		if (_where in units player) then { //--- The AI is in the player group?
			_pos = getPos _where; //--- Get the AI position (todo: copy the stance)
			_respawn_ai_gear = (_where) call CTI_UI_Gear_GetUnitEquipment; //--- Get the AI current equipment using the Gear UI function
			deleteVehicle _where; //--- Remove the AI
			player setPos _pos; //--- Place the player where the AI was
			_respawn_ai = true;
		};
	};
	
	if !(_respawn_ai) then { //--- Stock respawn
		_spawn_at = [_where, 8, 30] call CTI_CO_FNC_GetRandomPosition;
		player setPos _spawn_at;
	};
	
	titleCut["","BLACK IN",1];
	
	closeDialog 0;
	
	if !(isNil "CTI_DeathCamera") then {
		CTI_DeathCamera cameraEffect ["TERMINATE", "BACK"];
		camDestroy CTI_DeathCamera;
	};
	
	if !(_respawn_ai) then { //--- Stock respawn
		_gear = missionNamespace getVariable "cti_gear_lastpurchased";
		_cost = 0;

		
		_funds = call CTI_CL_FNC_GetPlayerFunds;
		if (!isnil '_gear' && CTI_RESPAWN_PENALTY in [0,2,3,4]) then {
			{
				_var = missionNamespace getVariable _x;	
				if !(isNil '_var') then {
					_cost = _cost + ((_var select 0) select 1);
				};
			} forEach (_gear call CTI_CO_FNC_ConvertGearToFlat);
		
			switch (CTI_RESPAWN_PENALTY) do {
				case 0: {_cost = 0}; //--- Free gear cost
				case 2: {_cost = _cost}; //--- Full gear cost
				case 3: {_cost = round (_cost/2)}; //--- 1/2 gear cost
				case 4: {_cost = round (_cost/4)}; //--- 1/4 gear cost
			};
			
			if (_funds >= _cost) then {
				[player, missionNamespace getVariable "cti_gear_lastpurchased"] call CTI_CO_FNC_EquipUnit; //--- Equip the last purchased equipment
				if (_cost > 0) then {
					-(_cost) call CTI_CL_FNC_ChangePlayerFunds;
				};
			} else {
				[player, missionNamespace getVariable format ["CTI_AI_%1_DEFAULT_GEAR", CTI_P_SideJoined]] call CTI_CO_FNC_EquipUnit; //--- Insufficient funds - Equip the default equipment
			};
		} else {
			[player, missionNamespace getVariable format ["CTI_AI_%1_DEFAULT_GEAR", CTI_P_SideJoined]] call CTI_CO_FNC_EquipUnit; //--- No previous purchase found or parameter set to default gear - Equip the default equipment
		};
	} else { //--- Respawn in own AI
		[player, _respawn_ai_gear] call CTI_CO_FNC_EquipUnit; //--- Equip the equipment of the AI on the player
	};
	
	if ((missionNamespace getVariable "CTI_UNITS_FATIGUE") >= 1) then {			
		player enableFatigue false;													//--- Disable the unit's fatigue
		if ((missionNamespace getVariable "CTI_UNITS_FATIGUE") >= 2) then {		
			player enableStamina false;												//--- Disable the unit's stamina system and weapons sway
		};
		if ((missionNamespace getVariable "CTI_UNITS_FATIGUE") >= 3) then {		
			player enableAimPrecision false;										//--- Disable the animation's aim precision affects weapon sway 
		};
	}; 
	CTI_P_Respawning = false;
};

CTI_UI_Respawn_GetCamps = {
	Private ['_camps','_closestCamp','_enemySide','_get','_hostiles','_list','_nearestCamps','_respawnCampsRuleMode','_respawnMinRange','_side','_town','_townSID'];

	_side = _this;

	_respawnCampsRuleMode = missionNamespace getVariable "CTI_RESPAWN_CAMPS_RULE_MODE";
	_respawnMinRange = missionNamespace getVariable "CTI_RESPAWN_CAMPS_SAFE_RADIUS";
	_list = [];
	_enemySide = sideEnemy;

	switch (missionNamespace getVariable "CTI_RESPAWN_CAMPS_MODE") do {
		case 1: {
			//--- Classic Respawn
			_town = (CTI_DeathPosition) Call CTI_CO_FNC_GetClosestTown;
			if !(isNull _town) then {
				if (_town distance CTI_DeathPosition < (missionNamespace getVariable "CTI_RESPAWN_CAMPS_RANGE")) then {
					_camps = [_town,_side] Call CTI_CO_FNC_GetFriendlyCamps; //,true  //camp rep stuff
					if (count _camps > 0) then {
						if (_respawnCampsRuleMode > 0) then {
							_closestCamp = [CTI_DeathPosition,_camps] Call CTI_CO_FNC_GetClosestEntity;
							_enemySide = if (_side == west) then {[east]} else {[west]};
							if (_respawnCampsRuleMode == 2) then {_enemySide = _enemySide + [resistance]};
							_hostiles = [_closestCamp,_enemySide,_respawnMinRange] Call CTI_CO_FNC_GetHostilesInArea;
							if (CTI_DeathPosition distance _closestCamp < _respawnMinRange && _hostiles > 0) then {_camps = _camps - [_closestCamp]};
						};
						_list = _list + _camps;
					};
				};
			};
		};
		case 2: {
		//--- Enhanced Respawn - Get the camps around the unit
			_nearestCamps = CTI_DeathPosition nearEntities [CTI_Logic_Camp, (missionNamespace getVariable "CTI_RESPAWN_CAMPS_RANGE")];
			{
				if !(isNil {_x getVariable 'cti_camp_sideID'}) then {
					if ((_side Call CTI_CO_FNC_GetSideID) == (_x getVariable 'cti_camp_sideID') ) then { //&& alive(_x getVariable "CTI_CO_CAMP") // will reactivate when camps can be destroyed
						if (_respawnCampsRuleMode > 0) then {
							if (CTI_DeathPosition distance _x < _respawnMinRange) then {
								_enemySide = if (_side == west) then {[east]} else {[west]};
								if (_respawnCampsRuleMode == 2) then {_enemySide = _enemySide + [resistance]};
								_hostiles = [_x,_enemySide,_respawnMinRange] Call CTI_CO_FNC_GetHostilesInArea;
								if (_hostiles == 0) then {_list = _list + [_x]};
							} else {
								_list = _list + [_x];					
							};
						};
					};	
				};
			} forEach _nearestCamps;		
		};
		case 3: {
			//--- Defender Only Respawn - Get the camps around the unit only if the town is friendly to the unit.
			_nearestCamps = CTI_DeathPosition nearEntities [CTI_Logic_Camp, (missionNamespace getVariable "CTI_RESPAWN_CAMPS_RANGE")];
			{
				if !(isNil {_x getVariable 'cti_camp_sideID'}) then {
					_town = _x getVariable 'town';
					_townSID = _town getVariable 'cti_town_sideID';
					if ((_side Call CTI_CO_FNC_GetSideID) == _townSID && (_x getVariable 'cti_camp_sideID') == _townSID) then { //&& alive(_x getVariable "CTI_CO_CTI_CO_CAMP") // see above.
						if (_respawnCampsRuleMode > 0) then {
							if (CTI_DeathPosition distance _x < _respawnMinRange) then {
								_enemySide = if (_side == west) then {[east]} else {[west]};
								if (_respawnCampsRuleMode == 2) then {_enemySide = _enemySide + [resistance]};
								_hostiles = [_x,_enemySide,_respawnMinRange] Call CTI_CO_FNC_GetHostilesInArea;
								if (_hostiles == 0) then {_list = _list + [_x]};
							} else {
								_list = _list + [_x];
							};
						} else {
							_list = _list + [_x];
						};
					};
				};
			} forEach _nearestCamps;
		};
	};

	//--- Return the available camps
	_list;
};
