## KaykitPreview .tscn 生成器 (新版: GridMapRenderer3D MultiMesh 渲染)
##
## 输出场景: 1 个 GridMapRenderer3D 节点 + 6 个 KayKit 角色 PackedScene。
## 117 个 hex tile + 装饰 + 建筑全走 MultiMesh, scene tree 节点骤减。
import math


SCENE_PATH = "D:/GodotProjects/inkmon/inkmon-godot/scenes/KaykitPreview.tscn"

ART_HEX = "res://art/kaykit/hexagon/addons/kaykit_medieval_hexagon_pack/Assets/gltf"
ART_ADV = "res://art/kaykit/adventurers/addons/kaykit_character_pack_adventures/Characters/gltf"
ART_SKL = "res://art/kaykit/skeletons/addons/kaykit_character_pack_skeletons/Characters/gltf"
ART_LOMO = "res://addons/lomolib/camera/lomo_camera_rig.tscn"

# (env_id, gltf_path) — 静态 mesh, 通过 GridMapRenderer3D.register_env 注入
ENV_MESHES = [
    ("grass",          f"{ART_HEX}/tiles/base/hex_grass.gltf"),
    ("road",           f"{ART_HEX}/tiles/roads/hex_road_A.gltf"),
    ("river",          f"{ART_HEX}/tiles/rivers/hex_river_A.gltf"),
    ("river_cross",    f"{ART_HEX}/tiles/rivers/hex_river_crossing_A.gltf"),
    ("hill_A",         f"{ART_HEX}/decoration/nature/hill_single_A.gltf"),
    ("hill_B",         f"{ART_HEX}/decoration/nature/hill_single_B.gltf"),
    ("hill_C",         f"{ART_HEX}/decoration/nature/hill_single_C.gltf"),
    ("trees_A",        f"{ART_HEX}/decoration/nature/hills_A_trees.gltf"),
    ("trees_B",        f"{ART_HEX}/decoration/nature/hills_B_trees.gltf"),
    ("trees_C",        f"{ART_HEX}/decoration/nature/hills_C_trees.gltf"),
    ("mountain_A",     f"{ART_HEX}/decoration/nature/mountain_A.gltf"),
    ("mountain_B",     f"{ART_HEX}/decoration/nature/mountain_B.gltf"),
    ("mountain_grass", f"{ART_HEX}/decoration/nature/mountain_A_grass.gltf"),
    ("castle_blue",    f"{ART_HEX}/buildings/blue/building_castle_blue.gltf"),
    ("barracks_blue",  f"{ART_HEX}/buildings/blue/building_barracks_blue.gltf"),
    ("archery_blue",   f"{ART_HEX}/buildings/blue/building_archeryrange_blue.gltf"),
    ("tower_blue",     f"{ART_HEX}/buildings/blue/building_tower_A_blue.gltf"),
    ("smith_blue",     f"{ART_HEX}/buildings/blue/building_blacksmith_blue.gltf"),
    ("castle_red",     f"{ART_HEX}/buildings/red/building_castle_red.gltf"),
    ("barracks_red",   f"{ART_HEX}/buildings/red/building_barracks_red.gltf"),
    ("archery_red",    f"{ART_HEX}/buildings/red/building_archeryrange_red.gltf"),
    ("tower_red",      f"{ART_HEX}/buildings/red/building_tower_A_red.gltf"),
    ("smith_red",      f"{ART_HEX}/buildings/red/building_blacksmith_red.gltf"),
]

UNITS = [
    ("Knight",           "blue", f"{ART_ADV}/Knight.glb",         (-3, -1)),
    ("Mage",             "blue", f"{ART_ADV}/Mage.glb",           (-3,  0)),
    ("Barbarian",        "blue", f"{ART_ADV}/Barbarian.glb",      (-3,  1)),
    ("Skeleton_Warrior", "red",  f"{ART_SKL}/Skeleton_Warrior.glb", (3, -1)),
    ("Skeleton_Mage",    "red",  f"{ART_SKL}/Skeleton_Mage.glb",    (3,  0)),
    ("Skeleton_Rogue",   "red",  f"{ART_SKL}/Skeleton_Rogue.glb",   (3,  1)),
]

# 战场 tile 配置 (q, r) -> env_id, facing(deg)
QR = [(q, r) for q in range(-6, 7) for r in range(-4, 5)]

BUILDINGS = {
    (-6,  0): ("castle_blue",   90),
    ( 6,  0): ("castle_red",   -90),
    (-5, -2): ("barracks_blue", 90),
    (-5,  2): ("archery_blue",  90),
    (-5,  0): ("smith_blue",    90),
    (-4, -3): ("tower_blue",     0),
    (-4,  3): ("tower_blue",     0),
    ( 5, -2): ("barracks_red", -90),
    ( 5,  2): ("archery_red",  -90),
    ( 5,  0): ("smith_red",    -90),
    ( 4, -3): ("tower_red",      0),
    ( 4,  3): ("tower_red",      0),
}

DECOR = {
    (-6, -4): "mountain_A", (-6,  4): "mountain_B",
    ( 6, -4): "mountain_B", ( 6,  4): "mountain_A",
    (-5, -4): "mountain_grass", ( 5, -4): "mountain_grass",
    (-5,  4): "trees_A", ( 5,  4): "trees_B",
    (-4, -4): "trees_B", (-4,  4): "trees_C",
    ( 4, -4): "trees_C", ( 4,  4): "trees_A",
    (-3, -4): "hill_A",  (-3,  4): "hill_B",
    ( 3, -4): "hill_C",  ( 3,  4): "hill_A",
    (-2, -4): "trees_A", (-2,  4): "hill_B",
    ( 2, -4): "hill_C",  ( 2,  4): "trees_C",
    (-1, -4): "hill_A",  (-1,  4): "hill_C",
    ( 1, -4): "hill_B",  ( 1,  4): "hill_A",
    (-6, -3): "trees_A", (-6,  3): "trees_B",
    ( 6, -3): "trees_B", ( 6,  3): "trees_A",
    (-3, -3): "hill_C",  ( 3,  3): "hill_C",
    (-2, -3): "hill_A",  ( 2,  3): "hill_B",
}

RIVER = {(0, r) for r in range(-4, 5)}
RIVER_CROSS = {(0, 0)}
ROADS = {(q, 0) for q in range(-5, 6) if q not in (-6, 0, 6)}


def axial_to_world_pointy(q, r, size):
    x = size * math.sqrt(3.0) * (q + r / 2.0)
    z = size * 1.5 * r
    return x, z


def yaw_basis(yaw_deg):
    yaw = math.radians(yaw_deg)
    cs = math.cos(yaw); sn = math.sin(yaw)
    return f"Transform3D({cs:.4f}, 0.0, {-sn:.4f}, 0.0, 1.0, 0.0, {sn:.4f}, 0.0, {cs:.4f}, "


def transform3d(yaw_deg, x, y, z):
    return yaw_basis(yaw_deg) + f"{x:.4f}, {y:.4f}, {z:.4f})"


def env_for_tile(q, r):
    if (q, r) in BUILDINGS:        # 建筑层独立处理(在 GridMapModel tile 之上)
        return None
    if (q, r) in DECOR:
        return None
    if (q, r) in RIVER_CROSS:
        return "river_cross"
    if (q, r) in RIVER:
        return "river"
    if (q, r) in ROADS:
        return "road"
    return "grass"


def main():
    # KayKit hex_grass mesh 内置朝向 = pointy-top, outer_radius = 2/sqrt(3)
    HEX_SIZE = 2.0 / math.sqrt(3.0)

    # ext_resources
    res = [
        ("Script", "res://scenes/KaykitPreview.gd", "script_main"),
        ("PackedScene", ART_LOMO, "cam_rig"),
    ]
    for env_id, path in ENV_MESHES:
        res.append(("PackedScene", path, f"env_{env_id}"))
    for unit_name, _team, path, _coord in UNITS:
        res.append(("PackedScene", path, f"unit_{unit_name}"))

    out = []
    out.append(f'[gd_scene load_steps={len(res) + 5} format=3 uid="uid://b0g1y7r13we1q"]')
    out.append("")
    for kind, path, rid in res:
        out.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
    out.append("")

    # Environment
    out += [
        '[sub_resource type="Environment" id="env_main"]',
        "background_mode = 1",
        "background_color = Color(0.55, 0.7, 0.9, 1)",
        "ambient_light_source = 1",
        "ambient_light_color = Color(0.65, 0.7, 0.78, 1)",
        "ambient_light_energy = 0.7",
        "fog_enabled = true",
        "fog_density = 0.005",
        "fog_light_color = Color(0.7, 0.78, 0.85, 1)",
        "",
    ]

    # Root
    out += [
        '[node name="KaykitPreview" type="Node"]',
        'script = ExtResource("script_main")',
        f'tile_size = {HEX_SIZE}',
        "",
        '[node name="CameraRig" parent="." instance=ExtResource("cam_rig")]',
        "default_arm_length = 28.0",
        "min_zoom = 8.0",
        "max_zoom = 60.0",
        "default_pitch = -50.0",
        "move_speed = 14.0",
        "",
        '[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]',
        "transform = Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 5, 12, 5)",
        "light_energy = 1.2",
        "shadow_enabled = true",
        "",
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]',
        'environment = SubResource("env_main")',
        "",
        '[node name="GridRenderer" type="Node3D" parent="."]',
        # GridMapRenderer3D 由 script _ready 创建并填充, 不在 .tscn 静态实例化(class_name 单 .gd 文件无法 type=)
        "",
        '[node name="Units" type="Node3D" parent="."]',
        "",
    ]

    # Units 直接 PackedScene instance
    for unit_name, team, _path, (q, r) in UNITS:
        x, z = axial_to_world_pointy(q, r, HEX_SIZE)
        yaw = 90.0 if team == "blue" else -90.0
        out.append(f'[node name="{unit_name}" parent="Units" instance=ExtResource("unit_{unit_name}")]')
        out.append(f"transform = {transform3d(yaw, x, 0.0, z)}")
        out.append("")

    # Tile 配置数据 — 由 script 读取后 set_tile_env 灌进 GridRenderer
    # 静态保留 layout 数据放在 .gd 里(避免 .tscn 复杂化), 这里只生成 res file 引用清单
    text = "\n".join(out) + "\n"
    with open(SCENE_PATH, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"written: {SCENE_PATH} ({len(out)} lines, {len(res)} ext_resources)")


main()
