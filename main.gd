extends Node2D

onready var player = $guy
onready var tile_map = $TileMap

func _physics_process(delta):
	tile_map.get_material().set_shader_param("player_position", player.position)
