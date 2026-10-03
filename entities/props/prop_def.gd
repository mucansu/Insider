class_name PropDef
extends Resource
## Interactive object definition (US-005; S10): `data/props/<id>.tres`, id = file name. The prop scene binds its definition and in `_ready`
## passes the values to the Interactable component (S7); these files are the single source of numbers, script defaults are neutral.
## Only state goes over the network, never the definition.

## i18n key of the interaction action (HUD prompt "[E] <action>", S9).
@export var action_key: String = ""
## Action key of the second state (e.g. "close" while a door is open); action_key if empty.
@export var alt_action_key: String = ""
## Hold time (s); 0 = instant.
@export_range(0.0, 60.0, 0.05, "suffix:s") var hold_time: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var interact_range: float = 0.0
## Amount added to team cash on completion (register).
@export_range(0, 1000000) var cash_value: int = 0
@export var requirement: InteractionRequirement


## id = file name (S10); empty on an unsaved definition.
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())
