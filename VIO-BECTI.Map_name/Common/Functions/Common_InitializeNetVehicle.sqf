/*
  # HEADER #
	Script: 		Common\Functions\Common_InitializeNetVehicle.sqf
	Alias:			CTI_CO_FNC_InitializeNetVehicle
	Description:	Perform a generic unit/vehicle initialization for everyone
	Author: 		Benny
	Creation Date:	18-09-2013
	Revision Date:	07-03-2015 (Sari)
	
  # PARAMETERS #
    0	[Object]: The unit/vehicle
    1	[Integer]: The Side ID of the unit/vehicle
	
  # RETURNED VALUE #
	None
	
  # SYNTAX #
	[ENTITY, SIDE ID] call CTI_CO_FNC_InitializeNetVehicle
	
  # DEPENDENCIES #
	Client Function: CTI_CL_FNC_GetAIDigit
	Common Function: CTI_CO_FNC_GetSideFromID
	Common Function: CTI_CO_FNC_MarkerUpdate
	Also Depends on the initialization of the units
	
  # EXAMPLE #
    [vehicle player, CTI_P_SideID] call CTI_CO_FNC_InitializeNetVehicle
	  -> This will initialize the vehicle of the player with his own Side ID
*/

private ["_marker_dead_color", "_marker_dead_size", "_marker_dead_type", "_marker_color", "_marker_label", "_marker_name", "_marker_size", "_marker_type", "_side", "_sideID", "_vehicle"];

_vehicle = _this select 0;
_sideID = _this select 1;

_side = _sideID call CTI_CO_FNC_GetSideFromID;
_classname = typeOf _vehicle;

_marker_type = "";
_marker_size = [1,1];
_marker_color = CTI_P_SideColor;

//--- Perform general operations
_special = _vehicle getVariable "cti_spec";
if (isNil '_special') then { _special = [] };
if (typeName _special != "ARRAY") then { _special = [_special] };

if (CTI_SPECIAL_REPAIRTRUCK in _special) then { //--- Repair truck.
	_marker_size = [0.75,0.75];
	_marker_type = CTI_P_MarkerPrefix+"maint"; //type is ok? b_support ?
	_name = "";
	if (_vehicle isKindof "car") then {_name = "Truck"} else {_name = "Pod"};
	_vehicle addAction [format ["<t color='#a5c4ff'>MENU: Construction (Repair %1)</t>", _name], "Client\Actions\Action_DefenseMenu.sqf", "", 93, false, true, "", "_this == player && !CTI_P_PreBuilding"];
	
	//--- HQ can be repaired if fubarized
	if ((missionNamespace getVariable "CTI_BASE_HQ_REPAIR") > 0) then {
		_vehicle addAction ["<t color='#efb377'>Repair HQ</t>","Client\Actions\Action_RepairHQ.sqf", [], 99, false, true, "", 'driver _target == _this && alive _target && !alive(CTI_P_SideJoined call CTI_CO_FNC_GetSideHQ) && time - CTI_P_LastRepairTime > 10'];
	};
};
if (CTI_SPECIAL_AMMOTRUCK in _special) then { //--- Ammo truck.
	_marker_size = [0.75,0.75];
	_marker_type = CTI_P_MarkerPrefix+"support";
};
if (CTI_SPECIAL_MEDICALVEHICLE in _special) then { //--- Medical vehicle.
	_marker_size = [0.75,0.75];
	_marker_type = CTI_P_MarkerPrefix+"med";
};

/*if (_classname in CTI_VEHICLES_HOOKERS) then { //--- Revamped A2  Airlift
	[_vehicle] ExecVM 'Client\Module\ZetaCargo\Zeta_AddAction.sqf';
};

if (_classname in (CTI_VEHICLES_HOOKERS_EX)) then {
	_vehicle addAction ["<t color='#86F078'>Hook (Main)</t>", "Client\Actions\Action_HookMenu.sqf", "", 99, false, true, "", "alive _target && local _target && _this == driver _target"]
};*/

//--- Bypass DLC restrictions
_ownsKarts = if (288520 in getDLCs 1) then {true} else {false};
_ownsHelis = if (304380 in getDLCs 1) then {true} else {false};

if (((gettext (configfile >> "CfgVehicles" >> _classname >> "DLC")) != "") && (((!_ownsKarts) && _vehicle isKindOf "Car") || ((!_ownsHelis) && _vehicle isKindOf "Air"))) then {
	_name = getText (configfile >> "CfgVehicles" >> _classname >> "displayName"); 
	_vehicle addAction [format ["<t color='#86F078'>Get in %1 (DLC Bypass)</t>", _name], "Client\Actions\Action_DLCBypass.sqf", "", 99, false, true, "", "alive _target && isNull driver _target && locked _target == 0"]  
};

if (_vehicle isKindOf "Ship") then {
	_vehicle addAction ["<t color='#86F078'>Push Forward</t>","Client\Actions\Action_Push.sqf", [], 99, false, true, "", 'driver _target == _this && alive _target && speed _target < 10'];
	_vehicle addAction ["<t color='#86F078'>Push Reverse</t>","Client\Actions\Action_Reverse.sqf", "REVERSE", 99, false, true, "", 'driver _target == _this && alive _target && speed _target < 10 && speed _target > -4'];
};
if (_vehicle isKindOf "Plane") then {_vehicle addAction ["<t color='#86F078'>Taxi Reverse</t>","Client\Actions\Action_Reverse.sqf", "REVERSE", 99, false, true, "", 'driver _target == _this && alive _target && speed _target < 4 && speed _target > -4 && getPos _target select 2 < 4']};

//--- Perform side-speficic operations
if (_sideID != CTI_P_SideID) exitWith {};

if (CTI_SPECIAL_REPAIRTRUCK in _special) then { //--- Repair truck.
	if (CTI_BASE_FOB_MAX > 0) then {
		_vehicle addAction ["<t color='#eac6ff'>ACTION: Request FOB Build Permission</t>", "Client\Actions\Action_RequestAction.sqf", [CTI_REQUEST_FOB, []], 92, false, true, "", "_this == player && time - CTI_P_TeamsRequests_Last > 30 && !(call CTI_CL_FNC_IsPlayerCommander) && CTI_P_TeamsRequests_FOB < 1"];
		_vehicle addAction ["<t color='#eac6ff'>ACTION: Request FOB Dismantle Permission</t>", "Client\Actions\Action_RequestAction.sqf", [CTI_REQUEST_FOB_DISMANTLE, []], 92, false, true, "", "_this == player && time - CTI_P_TeamsRequests_Last > 30 && !(call CTI_CL_FNC_IsPlayerCommander) && CTI_P_TeamsRequests_FOB_Dismantle < 1"];
		_vehicle addAction ["<t color='#eac6ff'>ACTION: Dismantle Nearest FOB</t>", "Client\Actions\Action_DismantleFOB.sqf", "", 92, false, true, "", "_this == player && (CTI_P_TeamsRequests_FOB_Dismantle > 0 || call CTI_CL_FNC_IsPlayerCommander)"];
	};
};

//--- Get a proper icon
if (_marker_type == "") then {
	_marker_size = [0.75,0.75];
	switch (true) do {
		case (_classname isKindOf "Man"): { _marker_type = CTI_P_MarkerPrefix+"inf"; _marker_size = [0.4, 0.4]; _marker_color = "ColorYellow"; };
		case ((_classname isKindOf "Car" || _classname isKindOf "Motorcycle") && !(_classname isKindOf "Wheeled_APC_F")): { _marker_type = CTI_P_MarkerPrefix+"motor_inf" };
		case (_classname isKindOf "Wheeled_APC_F"): { _marker_type = CTI_P_MarkerPrefix+"mech_inf" };
		case (_classname isKindOf "Ship"): { _marker_type = CTI_P_MarkerPrefix+"naval" };
		case (_classname isKindOf "Tank"): { _marker_type = CTI_P_MarkerPrefix+"armor" };
		case (_classname isKindOf "Helicopter"): { _marker_type = CTI_P_MarkerPrefix+"air" };
		case (_classname isKindOf "Plane"): { _marker_type = CTI_P_MarkerPrefix+"plane" };
		default { _marker_type = CTI_P_MarkerPrefix+"unknown" };
	};
};

//--- Marker initialization
_marker_label = "";
_marker_name = format["cti_vehicle_%1", CTI_P_MarkerIterator];
CTI_P_MarkerIterator = CTI_P_MarkerIterator + 1;
_marker_dead_type = _marker_type;
_marker_dead_color = "ColorBlack";
_marker_dead_size = _marker_size;

if (_classname isKindOf "Man") then {
	if (_vehicle in units player) then {
		_marker_color = "ColorOrange";
		_marker_label = (_vehicle) call CTI_CL_FNC_GetAIDigit;
		(_vehicle) execFSM "Client\FSM\update_client_ai.fsm";
	};
};

[_vehicle, _marker_type, _marker_color, _marker_size, _marker_label, _marker_name, 1, _marker_dead_type, _marker_dead_color, _marker_dead_size] spawn CTI_CO_FNC_MarkerUpdate;
