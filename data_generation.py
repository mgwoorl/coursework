import math
import socket
import json
import random
import time

HOST = "127.0.0.1"
PORT = 6000
DELAY = 2  # в секундах

FIRST_THREE_TOWERS_LEVELS = [2, 4, 10, 35]
LAST_TWO_TOWERS_LEVELS = [2, 4, 10, 35, 50]
TOWER_IDS = range(5)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
print(f"[Python] Отправка данных на {HOST}:{PORT}...")

def generate_wind_vector():
    wind_angle = random.uniform(0, 360)
    wind_speed = random.uniform(0.0, 5.0)
    wind_x = wind_speed * math.cos(math.radians(wind_angle))
    wind_z = wind_speed * math.sin(math.radians(wind_angle))
    return {"x": wind_x, "y": 0, "z": wind_z}, wind_speed

def generate_pressure():
    return round(random.uniform(100, 500), 2)

while True:
    towers_data = {}

    for tower_id in TOWER_IDS:
        levels = FIRST_THREE_TOWERS_LEVELS if tower_id < 3 else LAST_TWO_TOWERS_LEVELS

        tower_levels = {}
        for level in levels:
            wind_vector, wind_speed = generate_wind_vector()
            weather = {
                "temperature": round(random.uniform(-50, 50), 2),
                "pressure": generate_pressure(),
                "wind_vector": wind_vector,
                "wind_speed": wind_speed
            }
            tower_levels[str(level)] = weather

        towers_data[str(tower_id)] = tower_levels

    full_data = {"towers": towers_data}
    json_data = json.dumps(full_data)
    sock.sendto(json_data.encode(), (HOST, PORT))
    print("[Python] Отправлено:\n", json.dumps(full_data, indent=2))
    time.sleep(DELAY)
