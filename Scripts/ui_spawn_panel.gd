extends CanvasLayer

@export_category("Unit Roster Data")
@export var rifleman_data: UnitData
@export var tank_data: UnitData
@export var biplane_data: UnitData

# UI State Containers (routed through the Control parent node)
@onready var state_a_recruitment = $Control/StateARecruitment
@onready var state_b_garrison = $Control/StateBGarrison

# State A Nodes (Recruitment)
@onready var label_war_bonds = $Control/StateARecruitment/WarBondsLabel
@onready var btn_lane_selector = $Control/StateARecruitment/LaneSelectorButton
@onready var btn_rifleman = $Control/StateARecruitment/UnitQueue/RiflemanButton
@onready var btn_tank = $Control/StateARecruitment/UnitQueue/TankButton
@onready var btn_plane = $Control/StateARecruitment/UnitQueue/PlaneButton

# State B Nodes (Garrison Management)
@onready var label_trench_info = $Control/StateBGarrison/TrenchInfoLabel
@onready var label_garrison_desc = $Control/StateBGarrison/GarrisonDescLabel
@onready var btn_advance = $Control/StateBGarrison/AdvanceButton
@onready var btn_fall_back = $Control/StateBGarrison/FallBackButton
@onready var btn_close_garrison = $Control/StateBGarrison/CloseButton

# State Tracking
enum HUDState { RECRUITMENT, GARRISON }
var current_state: HUDState = HUDState.RECRUITMENT
var current_lane: String = "MID"
var active_selected_trench: Node2D = null

# Cooldown dictionary
var cooldowns: Dictionary = {} 

func _ready() -> void:
	# 1. Bind GameManager for War Bonds updates
	if Engine.is_editor_hint():
		return
	if GameManager:
		GameManager.war_bonds_changed.connect(_on_war_bonds_changed)
		_on_war_bonds_changed(GameManager.war_bonds)
	
	# 2. Bind State A Recruitment Buttons
	if btn_rifleman and rifleman_data:
		btn_rifleman.pressed.connect(_on_spawn_button_pressed.bind(rifleman_data, btn_rifleman))
	if btn_tank and tank_data:
		btn_tank.pressed.connect(_on_spawn_button_pressed.bind(tank_data, btn_tank))
	if btn_plane and biplane_data:
		btn_plane.pressed.connect(_on_spawn_button_pressed.bind(biplane_data, btn_plane))

	# 3. Bind Lane Selector
	if btn_lane_selector:
		btn_lane_selector.pressed.connect(_on_lane_selector_pressed)
		btn_lane_selector.text = "[LANE: " + current_lane + "]"

	# 4. Bind State B Garrison Macro Commands
	if btn_advance:
		btn_advance.pressed.connect(_on_advance_pressed)
	if btn_fall_back:
		btn_fall_back.pressed.connect(_on_fallback_pressed)
	if btn_close_garrison:
		btn_close_garrison.pressed.connect(_switch_to_recruitment_state)

	# 5. Connect World SignalBus Listeners
	if SignalBus:
		if SignalBus.has_signal("trench_selected"):
			SignalBus.trench_selected.connect(_on_trench_selected)
		if SignalBus.has_signal("ground_clicked"):
			SignalBus.ground_clicked.connect(_switch_to_recruitment_state)

	# Initialize default view
	_switch_to_recruitment_state()

func _process(delta: float) -> void:
	# Manage button cooldown timers per frame
	for btn in cooldowns.keys():
		if cooldowns[btn] > 0.0:
			cooldowns[btn] -= delta
			if cooldowns[btn] <= 0.0:
				btn.disabled = false
				cooldowns.erase(btn)

func _on_war_bonds_changed(new_count: int) -> void:
	if label_war_bonds:
		label_war_bonds.text = "War Bonds: " + str(new_count)

func _on_spawn_button_pressed(data: UnitData, button: Button) -> void:
	if GameManager and GameManager.spend_war_bonds(data.cost):
		# Pass unit data, is_enemy (false), and the selected HUD lane
		SignalBus.spawn_unit_requested.emit(data, false, current_lane)
		
		# Apply a 5-second recruitment cooldown on that button
		cooldowns[button] = 5.0
		button.disabled = true
	else:
		print("Not enough War Bonds! Need: ", data.cost)

func _on_lane_selector_pressed() -> void:
	# Cycle through lanes: TOP -> MID -> BOT -> TOP
	if current_lane == "TOP":
		current_lane = "MID"
	elif current_lane == "MID":
		current_lane = "BOT"
	else:
		current_lane = "TOP"
	
	if btn_lane_selector:
		btn_lane_selector.text = "[LANE: " + current_lane + "]"
	
	# Changing lanes overrides and returns you to recruitment mode
	_switch_to_recruitment_state()

func _on_trench_selected(trench_node: Node2D) -> void:
	active_selected_trench = trench_node
	current_state = HUDState.GARRISON
	
	# Swap visible HUD panels
	if state_a_recruitment: state_a_recruitment.visible = false
	if state_b_garrison: state_b_garrison.visible = true
	
	if label_trench_info:
		label_trench_info.text = "[" + current_lane + ": FRONTLINE]"
	if label_garrison_desc:
		label_garrison_desc.text = "Garrison: 2x Rifle, 1x Mortar"

func _switch_to_recruitment_state() -> void:
	current_state = HUDState.RECRUITMENT
	active_selected_trench = null
	
	# Swap visible HUD panels back
	if state_a_recruitment: state_a_recruitment.visible = true
	if state_b_garrison: state_b_garrison.visible = false

func _on_advance_pressed() -> void:
	if active_selected_trench and active_selected_trench.has_method("order_advance"):
		active_selected_trench.order_advance()
	print("Whistle blown: ORDER ADVANCE")

func _on_fallback_pressed() -> void:
	if active_selected_trench and active_selected_trench.has_method("order_fallback"):
		active_selected_trench.order_fallback()
	print("Order issued: FALL BACK")
