extends Node

var socket := PacketPeerUDP.new()
var server_port := 6000

var camera: Camera3D
var move_speed := 35.0
var mouse_sensitivity := 0.01
var rotation_x := 0.0
var rotation_y := 0.0

var flow_planes := {
	"2": null,
	"4": null,
	"10": null,
	"35": null,
	"50": null
}

var level_data := {
	"2": {"wind_vector": Vector3(1, 0, 0), "temperature": 15.0, "pressure": 100.0},
	"4": {"wind_vector": Vector3(0, 1, 0), "temperature": 18.0, "pressure": 150.0},
	"10": {"wind_vector": Vector3(1, 1, 0), "temperature": 20.0, "pressure": 200.0},
	"35": {"wind_vector": Vector3(0, -1, 0), "temperature": 12.0, "pressure": 250.0},
	"50": {"wind_vector": Vector3(0, 1, 1), "temperature": 22.0, "pressure": 300.0}
}

func _ready():
	camera = find_child("Camera3D", true, false)
	for level in flow_planes.keys():
		flow_planes[level] = find_child("FlowPlane_%s" % level, true, false)

	var err = socket.bind(server_port)
	if err != OK:
		push_error("Ошибка привязки сокета к порту " + str(server_port))
	else:
		print("Сокет слушает порт:", server_port)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	handle_socket_data()
	if camera:
		handle_camera_movement(delta)

func handle_socket_data():
	while socket.get_available_packet_count() > 0:
		var raw = socket.get_packet()
		var json_string = raw.get_string_from_utf8()
		var json = JSON.new()

		if json.parse(json_string) == OK:
			var result = json.get_data()
			if result.has("towers"):
				for tower_id in result["towers"].keys():
					var levels = result["towers"][tower_id]
					for level in levels.keys():
						var level_key = str(level)
						if not level_data.has(level_key):
							continue
						var weather_data = levels[level]
						level_data[level_key] = {
							"wind_vector": Vector3(weather_data["wind_vector"]["x"], weather_data["wind_vector"]["y"], weather_data["wind_vector"]["z"]),
							"temperature": weather_data.get("temperature", 0.0),
							"pressure": weather_data.get("pressure", 0.0)
						}
						update_flow_plane(level_key)
						update_sphere_color(tower_id, level_key)
						update_pressure_arrow(tower_id, level_key)

func get_arrow_rotation(level_key: String, pressure: float) -> float:
	var min_pressure = 100.0
	var max_pressure = 500.0
	var norm = clamp((pressure - min_pressure) / (max_pressure - min_pressure), 0.0, 1.0)

	if arrow_rotations.has(level_key):
		var min_rot = arrow_rotations[level_key]["min"]
		var max_rot = arrow_rotations[level_key]["max"]
		var rotation = lerp(min_rot, max_rot, norm)
		return rotation
	return 0.0

var arrow_rotations = {
	"2": {"min": -30, "max": -75},
	"4": {"min": -25, "max": -70},
	"10": {"min": 0, "max": -65},
	"35": {"min": 60, "max": 45},
	"50": {"min": 70, "max": 0}
}

func update_pressure_arrow(tower_id: String, level_key: String):
	var arrow_name = "PressureArrow_%s_%s" % [tower_id, level_key]
	var arrow = find_child(arrow_name, true, false)
	if arrow == null:
		return

	var pressure = level_data[level_key]["pressure"]
	var column_name = "PressureColumn_%s" % tower_id
	var column = find_child(column_name, true, false)
	if column == null:
		return

	var min_pressure = 100.0
	var max_pressure = 500.0
	var min_height = 10.0
	var max_height = 50.0
	var pressure_norm = clamp((pressure - min_pressure) / (max_pressure - min_pressure), 0.0, 1.0)
	var target_y = min_height + pressure_norm * (max_height - min_height)

	if not arrow_rotations.has(level_key):
		return
	var min_rot = deg_to_rad(arrow_rotations[level_key]["min"])
	var max_rot = deg_to_rad(arrow_rotations[level_key]["max"])
	var angle_x = lerp(min_rot, max_rot, pressure_norm)

	var rotation = arrow.rotation
	rotation.x = angle_x
	arrow.rotation = rotation

	var mat = get_mesh_instance(arrow).material_override
	if mat == null:
		mat = StandardMaterial3D.new()
		arrow.material_override = mat

	var color : Color
	if pressure < 100.0:
		color = Color(0.0, 0.0, 1.0)
	elif pressure <= 300.0:
		color = Color(0.0, 1.0, 0.0)
	else:
		color = Color(1.0, 0.0, 0.0)

	mat.albedo_color = color

	# Вывод трансформации стрелки на мачте 4, уровне 50
	if tower_id == "4" and level_key == "50":
		print("=== Arrow Transform for tower 4, level 50 ===")
		print("Global Position: ", arrow.global_transform.origin)
		print("Rotation (radians): ", arrow.rotation)
		print("Rotation (degrees): ", Vector3(
			rad_to_deg(arrow.rotation.x),
			rad_to_deg(arrow.rotation.y),
			rad_to_deg(arrow.rotation.z)
		))
		print("===========================================")

func update_sphere_color(tower_id: String, level_key: String):
	var sphere_name = "Sphere_%s_%s" % [tower_id, level_key]
	var sphere = find_child(sphere_name, true, false)
	if sphere:
		var mesh_instance = get_mesh_instance(sphere)
		if mesh_instance:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = temperature_to_color(level_data[level_key]["temperature"])
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh_instance.material_override = mat

func get_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh = get_mesh_instance(child)
		if mesh:
			return mesh
	return null

func temperature_to_color(temp_celsius: float) -> Color:
	if temp_celsius < -100:
		return Color(0.1, 0.1, 0.5)
	elif temp_celsius < -50:
		return Color(0.2, 0.2, 0.8)
	elif temp_celsius < 0:
		return Color(0.4, 0.6, 1.0)
	elif temp_celsius < 15:
		return Color(0.9, 0.9, 1.0)
	elif temp_celsius < 30:
		return Color(1.0, 0.95, 0.9)
	elif temp_celsius < 50:
		return Color(1.0, 0.8, 0.6)
	elif temp_celsius < 100:
		return Color(1.0, 0.6, 0.3)
	else:
		return Color(1.0, 0.3, 0.1)

func calculate_average_wind_speed():
	var total_speed = 0.0
	var count = 0
	for level in level_data.keys():
		var wind_vec = level_data[level]["wind_vector"]
		total_speed += wind_vec.length()
		count += 1
	return total_speed / count if count > 0 else 0.0

func update_flow_plane(level_key):
	if not flow_planes.has(level_key) or not flow_planes[level_key]:
		return

	var plane = flow_planes[level_key]
	var wind_vec = level_data[level_key]["wind_vector"]
	var wind_angle = atan2(wind_vec.z, wind_vec.x)

	var avg_wind_speed = calculate_average_wind_speed()
	plane.rotation = Vector3(0, wind_angle, 0)

	var mat = plane.get_active_material(0)
	if mat:
		mat.set("shader_parameter/speed", avg_wind_speed * 0.4)
		mat.set("shader_parameter/flow_strength", 0.5)
		mat.set("shader_parameter/temperature", level_data[level_key]["temperature"])

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))
		if camera:
			camera.rotation = Vector3(rotation_x, rotation_y, 0)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func handle_camera_movement(delta):
	var direction = Vector3.ZERO
	var camera_basis = camera.transform.basis
	if Input.is_action_pressed("move_forward"):
		direction -= camera_basis.z
	if Input.is_action_pressed("move_back"):
		direction += camera_basis.z
	if Input.is_action_pressed("move_left"):
		direction -= camera_basis.x
	if Input.is_action_pressed("move_right"):
		direction += camera_basis.x
	camera.position += direction.normalized() * move_speed * delta
