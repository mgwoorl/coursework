extends Node

var socket := PacketPeerUDP.new()
var server_port := 6000
var sphere_mesh: MeshInstance3D

func _ready():
	# 1. Получаем MeshInstance3D внутри Sphere
	sphere_mesh = $Sphere.get_node("MeshInstance3D")

	if not sphere_mesh:
		push_error("MeshInstance3D не найден! Проверьте структуру:")
		print("Дочерние элементы Sphere:", get_children_names($Sphere))
		return
	
	# 2. Настройка сокета
	var err = socket.bind(server_port)
	if err != OK:
		push_error("❌ Ошибка привязки сокета к порту " + str(server_port))
	else:
		print("🟢 Сокет слушает порт:", server_port)
	
	# 3. Тестовый вызов (можно удалить после проверки)
	call_deferred("test_color_change")

func test_color_change():
	# Проверка работы материалов
	update_sphere_color(0.0)   # Синий
	await get_tree().create_timer(1.0).timeout
	update_sphere_color(20.0)  # Фиолетовый
	await get_tree().create_timer(1.0).timeout
	update_sphere_color(40.0)  # Красный

func get_children_names(node: Node) -> Array:
	return Array(node.get_children().map(func(child): return child.name))

func _process(_delta):
	# Обработка входящих данных
	while socket.get_available_packet_count() > 0:
		var data = socket.get_packet()
		var json_string = data.get_string_from_utf8()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var temp = json.get_data().get("temperature", 0.0)
			update_sphere_color(temp)
		else:
			push_error("Ошибка JSON: " + json.get_error_message())

func update_sphere_color(temp: float):
	if not is_instance_valid(sphere_mesh):
		push_error("❌ MeshInstance3D уничтожен!")
		return
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = temperature_to_color(temp)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	
	sphere_mesh.material_override = mat
	print("Обновлён цвет на температуре:", temp)

func temperature_to_color(temp: float) -> Color:
	var t = clamp(temp / 40.0, 0.0, 1.0)  # 0°C-40°C → 0.0-1.0
	return Color(t, 0.0, 1.0 - t)  # R↑, G=0, B↓
