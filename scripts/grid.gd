extends Node2D

# Grid variables
@export var width: int
@export var height: int
@export var x_start: int
@export var y_start: int
@export var offset: int

@export var destroy_timer: Timer
@export var collapse_timer: Timer
@export var refill_timer: Timer

@export var treasure_texture: Texture2D

# The piece array wherein pieces are pulled to randomly generate grid
var possible_pieces: Array[PackedScene] = [
# preload("res://scenes/tile_red.tscn"),
# preload("res://scenes/tile_orange.tscn"),
# preload("res://scenes/tile_yellow.tscn"),
# preload("res://scenes/tile_green.tscn"),
preload("res://scenes/tile_ground_biege.tscn"),
preload("res://scenes/tile_ground_green.tscn"),
preload("res://scenes/tile_ground_orange.tscn"),
preload("res://scenes/tile_ground_purple.tscn")
# preload("res://scenes/tile_blue.tscn"),
# preload("res://scenes/tile_grey.tscn")
];

var character_piece: PackedScene = preload("res://scenes/tile_character.tscn");

# The current pieces in the scene
var all_pieces: Array = [];

# Touch variables
var first_touch: Vector2 = Vector2(0, 0);
var final_touch: Vector2 = Vector2(0, 0);
var controlling: bool = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	all_pieces = make_2d_array();
	spawn_pieces();

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	touch_input();

func make_2d_array() -> Array: #makes an empty array to hold the pieces
	var array: Array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null);
	return array

func spawn_pieces() -> void:
	for i: int in width:
		for j: int in height:
			var random_scene: PackedScene = possible_pieces.pick_random();
			var temporary_instance: Node2D = random_scene.instantiate()
			var loops: int = 0
			
			while match_at(i, j, temporary_instance.color) and loops < 100:
				temporary_instance.queue_free()
				random_scene = possible_pieces.pick_random()
				temporary_instance = random_scene.instantiate()
				loops += 1
				
			temporary_instance.position = grid_to_pixel(i, j)
			
			apply_treasure_chance(temporary_instance, 0.25)
				
			add_child(temporary_instance)
			all_pieces[i][j] = temporary_instance
	
	var character_spawn_i: int = 3
	var character_spawn_j: int = 4
	
	if is_in_grid(character_spawn_i,  character_spawn_j) and all_pieces[character_spawn_i][character_spawn_j] != null:
		all_pieces[character_spawn_i][character_spawn_j].queue_free()
		var character = character_piece.instantiate()
		character.position = grid_to_pixel(character_spawn_i, character_spawn_j)
		add_child(character)
		all_pieces[character_spawn_i][character_spawn_j] = character

func match_at(i:int, j:int, color_to_check: String) -> bool: #ensures no matches when pieces spawned on _ready
	if i > 1:
		if  all_pieces[i - 1][j] != null and all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].color == color_to_check and all_pieces[i - 2][j].color == color_to_check:
				return true;
	if j > 1:
		if  all_pieces[i][j - 1] != null and all_pieces[i][j - 2] != null:
			if all_pieces[i][j - 1].color == color_to_check and all_pieces[i][j - 2].color == color_to_check:
				return true;
	return false; #false is good meaning no matches in all_pieces

func grid_to_pixel(column: int, row: int) -> Vector2:
	return Vector2(x_start + offset * column, y_start + -offset * row)

func pixel_to_grid(pixel_x: float, pixel_y: float) -> Vector2i:
	return Vector2i(
		round((pixel_x - x_start) / offset),
		round((pixel_y - y_start) / -offset))

func is_in_grid(column: int, row: int) -> bool:
	return column >= 0 and column < width and row >= 0 and row < height

func touch_input() -> void:
	if Input.is_action_just_pressed("ui_touch"):
		first_touch = get_global_mouse_position()
		var touch_grid_position = pixel_to_grid(first_touch.x, first_touch.y)
		controlling = is_in_grid(touch_grid_position.x, touch_grid_position.y);

	if Input.is_action_just_released("ui_touch") and controlling:
		final_touch = get_global_mouse_position()
		var release_grid_position = pixel_to_grid(final_touch.x, final_touch.y);

		if is_in_grid(release_grid_position.x, release_grid_position.y):
			touch_difference(pixel_to_grid(first_touch.x, first_touch.y), release_grid_position)
		controlling = false

func swap_pieces(column: int, row: int, direction: Vector2i) -> void:
	var target_column: int = column + direction.x
	var target_row: int = row + direction.y
	print(target_column, target_row)
	if not is_in_grid(target_column, target_row):
		return
		
	var controlled_piece = all_pieces[column][row]
	var other_piece = all_pieces[target_column][target_row]
	if controlled_piece != null and other_piece != null: # stops the attempted move of null all_pieces[i][j]
		all_pieces[column][row] = other_piece
		all_pieces[target_column][target_row] = controlled_piece
		controlled_piece.move(grid_to_pixel(target_column, target_row)) #move() is in piece.gd on peice.tcsn
		other_piece.move(grid_to_pixel(column, row)) #move() is in piece.gd on piece.tcsn
		find_matches()

func touch_difference(touch_grid: Vector2i, release_grid: Vector2i):
	var difference: Vector2i = release_grid - touch_grid;
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(touch_grid.x, touch_grid.y, Vector2i (1, 0));
		elif difference.x < 0:
			swap_pieces(touch_grid.x, touch_grid.y, Vector2i (-1, 0));
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(touch_grid.x, touch_grid.y, Vector2i (0, 1));
		elif difference.y < 0:
			swap_pieces(touch_grid.x, touch_grid.y, Vector2i (0,-1));

func character_adjacent(i: int, j: int) -> bool:
	var directions: Array = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)];
	for each in directions:
		var ni = i + each.x;
		var nj = j + each.y;
		if ni >= 0 and ni < all_pieces.size() and nj >= 0 and nj < all_pieces[ni].size():
			var piece = all_pieces[ni][nj];
			if piece != null and piece.color == "character":
				return true
	return false

func find_matches() -> void:
	var match_grid: Array = []
	for i in width:
		match_grid.append([])
		for j in height:
			match_grid[i].append(false)
	
	for j in height:
		for i in range(width - 2):
			if all_pieces[i][j] and all_pieces[i + 1][j] and all_pieces[i + 2][j]:
				var color_match = all_pieces[i][j].color
				if all_pieces[i + 1][j].color == color_match and all_pieces[i + 2][j].color == color_match and color_match != "character":
					match_grid[i][j] = true
					match_grid[i + 1][j] = true
					match_grid[i + 2][j] = true
	
	for i in width:
		for j in range(height - 2):
			if all_pieces[i][j] and all_pieces[i][j + 1] and all_pieces[i][j + 2]:
				var color_match = all_pieces[i][j].color
				if all_pieces[i][j + 1].color == color_match and all_pieces[i][j + 2].color == color_match and color_match != "character":
					match_grid[i][j] = true
					match_grid[i][j + 1] = true
					match_grid[i][j + 2] = true
	
	var visited_piece: Array = []
	for i in width:
		visited_piece.append([])
		for j in height:
			visited_piece[i].append(false)
	
	var pieces_to_destroy: Array = []
	
	for i in width:
		for j in height:
			if match_grid[i][j] and not visited_piece[i][j]:
				var cluster = get_cluster_nodes(i, j, match_grid, visited_piece)
				
				var cluster_character_adjacent: bool = false
				for coord in cluster:
					if character_adjacent(coord.x, coord.y):
						cluster_character_adjacent = true
						break
				
				if cluster_character_adjacent:
					pieces_to_destroy.append_array(cluster)
	
	if pieces_to_destroy.size() > 0:
		for coord in pieces_to_destroy:
			var doomed_piece = all_pieces[coord.x][coord.y]
			if doomed_piece:
				doomed_piece.dim()
				doomed_piece.queue_free()
				all_pieces[coord.x][coord.y] = null
				
		if get_parent().has_node("collapse_timer"):
			get_parent().get_node("collapse_timer").start()

func apply_treasure_chance(piece: Node2D, chance: float) -> void:
	var random_rotation_multiplier: int = randi() % 4
	piece.rotation_degrees = random_rotation_multiplier * 90
	
	if randf() < chance:
		piece.treasured = true
		
		var treasure_sprite: Sprite2D = Sprite2D.new()
		treasure_sprite.texture = treasure_texture
		treasure_sprite.scale = Vector2(0.5, 0.5)
		
		treasure_sprite.rotation_degrees = -piece.rotation_degrees
		
		piece.add_child(treasure_sprite)

func get_cluster_nodes(i: int, j: int, match_grid: Array, visited_piece: Array) -> Array:
	var cluster: Array = []
	var queue: Array = [Vector2i(i, j)]
	visited_piece[i][j] = true
	
	var directions = [Vector2i(-1, 0),  Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	
	while queue.size() > 0:
		var current_piece = queue.pop_front()
		cluster.append(current_piece)
		
		for direction in directions:
			var ni = current_piece.x + direction.x
			var nj = current_piece.y + direction.y
			
			if is_in_grid(ni, nj):
				if match_grid[ni][nj] and not visited_piece[ni][nj]:
					visited_piece[ni][nj] = true
					queue.append(Vector2i(ni, nj))
					
	return cluster

#func collapse_columns() -> void:
	#for i in width:
		#var empty_slot: int = 0
		#for j in height:
			#if all_pieces[i][j] != null:
				#if j != empty_slot:
					#all_pieces[i][j].move(grid_to_pixel(i, empty_slot))
					#all_pieces[i][empty_slot] = all_pieces[i][j]
					#all_pieces[i][j] = null
				#empty_slot += 1
	#get_parent().get_node("refill_timer").start();
#
#func refill_columns() -> void:
	#for i: int in width:
		#for j: int in height:
			#if all_pieces[i][j] == null:
				#var random_scene: PackedScene = possible_pieces.pick_random()
				#var temporary_instance: Node2D = random_scene.instantiate()
				#var loops: int = 0
				#while match_at(i, j, temporary_instance.color) and loops < 100:
					#temporary_instance.queue_free()
					#random_scene = possible_pieces.pick_random()
					#temporary_instance = random_scene.instantiate()
					#loops += 1
				#temporary_instance.position = grid_to_pixel(i, j)
				#
				#apply_treasure_chance(temporary_instance, 0.25)
				#
				#add_child(temporary_instance)
				#all_pieces[i][j] = temporary_instance
	#find_matches();

func collapse_and_refill_columns() -> void:
	var moving_pieces: Array = []
	
	for i: int in width:
		var empty_spots: int = 0
		
		for j: int in range(0, height):
			if all_pieces[i][j] == null:
				empty_spots += 1
			elif empty_spots > 0:
				var piece: Node2D = all_pieces[i][j]
				var nj: int = j - empty_spots
				
				all_pieces[i][nj] = piece
				all_pieces[i][j] = null
				
				var target_position: Vector2 = grid_to_pixel(i, nj)
				piece.move(target_position)
				moving_pieces.append(piece)
				
		for k: int in range(empty_spots):
			var nj: int = (height - empty_spots) + k
			
			var random_scene: PackedScene = possible_pieces.pick_random()
			var new_piece: Node2D = random_scene.instantiate()
			
			var target_position: Vector2 = grid_to_pixel(i, nj)
			var start_y_offset: float = (empty_spots - k) * offset
			new_piece.position = Vector2(target_position.x, target_position.y - start_y_offset)
			
			apply_treasure_chance(new_piece, 0.25)
			add_child(new_piece)
			all_pieces[i][nj] = new_piece
			
			new_piece.move(target_position)
			moving_pieces.append(new_piece)
	
	if moving_pieces.size() > 0:
		await get_tree().create_timer(0.35).timeout
		find_matches()

#func _on_destroy_timer_timeout() -> void:
#	destroy_matched();

func _on_collapse_timer_timeout() -> void:
	# collapse_columns()
	collapse_and_refill_columns()

func _on_refill_timer_timeout() -> void:
	# refill_columns()
	collapse_and_refill_columns()
