extends Node2D

# Grid variables
@export var visible_width: int
@export var visible_height: int
@export var x_start: int
@export var y_start: int
@export var offset: int

@export var level_width: int
@export var level_height: int

@export var character_spawn_column: int
@export var character_spawn_row: int
var character_vertical_travel: int = 0
var character_current_depth: int #tracks the row in the array character is
@export var depth_visibility: int #tracks rows player can see

@export var destroy_timer: Timer
@export var collapse_timer: Timer
@export var refill_timer: Timer

@export var treasure_texture: Texture2D

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

# The current pieces in the game window scene
var all_pieces: Array = [];

# Touch variables
var first_touch: Vector2 = Vector2(0, 0);
var final_touch: Vector2 = Vector2(0, 0);
var controlling: bool = false;

@onready var win_screen: Control = %WinScreen

func _ready() -> void:
	all_pieces = make_2d_array(level_width, level_height);
	spawn_pieces()
	depth_visibility = 0

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	touch_input();

func make_2d_array(columns: int, rows: int) -> Array: #makes an empty array to hold the pieces
	var array: Array = []
	for i in columns:
		array.append([])
		for j in rows:
			array[i].append(null);
	return array

func spawn_pieces() -> void:
	for i: int in level_width:
		for j: int in level_height:
			var random_scene: PackedScene = possible_pieces.pick_random();
			var temporary_instance: Node2D = random_scene.instantiate()
			var loops: int = 0
			
			while match_at(i, j, temporary_instance.color) and loops < 100:
				temporary_instance.free()
				random_scene = possible_pieces.pick_random()
				temporary_instance = random_scene.instantiate()
				loops += 1
				
			temporary_instance.position = grid_to_pixel(i, j)
			
			apply_treasure_chance(temporary_instance, 0.25)
				
			add_child(temporary_instance)
			all_pieces[i][j] = temporary_instance
	
	if is_in_visible_grid(character_spawn_column, character_spawn_row) and all_pieces[character_spawn_column][character_spawn_row] != null:
		all_pieces[character_spawn_column][character_spawn_row].queue_free()
		var character = character_piece.instantiate()
		character.position = grid_to_pixel(character_spawn_column, character_spawn_row)
		character_current_depth = character_spawn_row
		add_child(character)
		all_pieces[character_spawn_column][character_spawn_row] = character

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
	return Vector2(
		x_start + (offset * column),
		y_start + (offset * (row)))

func pixel_to_grid(pixel_x: float, pixel_y: float) -> Vector2i:
	return Vector2i(
		round((pixel_x - x_start) / offset),
		round((pixel_y - y_start) / offset))

func get_piece_grid_position(piece: Node2D) -> Vector2i:
	for i: int in level_width:
		for j: int in level_height:
			if all_pieces[i][j] == piece:
				return Vector2i(i, j)
	return Vector2i(-1, -1)

func get_character_grid() -> Vector2i:
	for i: int in level_width:
		for j: int in level_height:
			var piece = all_pieces[i][j]
			
			if piece != null:
				if piece.color == "character":
					return Vector2i(i, j)
	
	return Vector2i(-1, -1)

func is_in_visible_grid(column: int, row: int) -> bool:
	if not is_in_level_grid(column, row):
		return false
	return column >= 0 and column < visible_width and row >= 0 + character_vertical_travel and row < visible_height + character_vertical_travel

func is_in_level_grid(column: int, row: int) -> bool:
	if column < 0 or column >= all_pieces.size():
		return false
	if row < 0 or row >= all_pieces[column].size():
		return false
	return true

func touch_input() -> void:
	if win_screen.visible:
		return
	
	if Input.is_action_just_pressed("ui_touch"):
		first_touch = get_global_mouse_position()
		var touch_grid_position: Vector2i = pixel_to_grid(first_touch.x, first_touch.y)
		print("---")
		print("touch grid ", touch_grid_position)
		print("character current depth ", character_current_depth)
		controlling = is_in_visible_grid(touch_grid_position.x, touch_grid_position.y);

	if Input.is_action_just_released("ui_touch") and controlling:
		final_touch = get_global_mouse_position()
		var release_grid_position: Vector2i = pixel_to_grid(final_touch.x, final_touch.y);

		if is_in_visible_grid(release_grid_position.x, release_grid_position.y):
			touch_difference(pixel_to_grid(first_touch.x, first_touch.y), release_grid_position)
		controlling = false

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

func swap_pieces(column: int, row: int, direction: Vector2i) -> void:
	var target_column: int = column + direction.x
	var target_row: int = row + direction.y
	print(target_column, " ", target_row)
	
	if not is_in_visible_grid(target_column, target_row):
		return
	
	var controlled_piece = all_pieces[column][row]
	var other_piece = all_pieces[target_column][target_row]
	
	if controlled_piece == null or other_piece == null: # stops the attempted move of null all_pieces[i][j]
		return
	
	all_pieces[column][row] = other_piece
	all_pieces[target_column][target_row] = controlled_piece
	
	var is_character_moving: bool = (controlled_piece.color == "character" or other_piece.color == "character")
	if controlled_piece.color == "character":
		character_current_depth += direction.y
		character_vertical_travel += direction.y
	elif other_piece.color == "character":
		character_current_depth += -direction.y
		character_vertical_travel += -direction.y
	print("direction ", direction.y)
	print("character current depth ", character_current_depth)
	print("character vertical travel ", character_vertical_travel)
	
	if is_character_moving and direction.y != 0:
		
		y_start -= direction.y * offset
		
		for i in level_width:
			for j in level_height:
				var piece = all_pieces[i][j]
				if piece != null:
					var target_position: Vector2 = grid_to_pixel(i, j)
					piece.move(target_position)
	
	else:
		controlled_piece.move(grid_to_pixel(target_column, target_row)) #move() is in piece.gd on peice.tcsn
		other_piece.move(grid_to_pixel(column, row)) #move() is in piece.gd on piece.tcsn
	
	find_matches()
	check_win()

func find_matches() -> void:
	var character_grid = get_character_grid()
	if character_grid == null:
		return
	
	var directions: Array = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var pieces_to_destroy: Array = []
	
	for direction in directions:
		var ni = character_grid.x + direction.x
		var nj = character_grid.y + direction.y
		
		if is_in_visible_grid(ni, nj) and all_pieces[ni][nj]:
			var matched_pieces = get_matched_pieces(ni, nj)
			for piece in matched_pieces:
				if piece not in pieces_to_destroy:
					pieces_to_destroy.append(piece)
	
	if pieces_to_destroy.size() > 0:
		for piece in pieces_to_destroy:
			var doomed_piece = all_pieces[piece.x][piece.y]
			if doomed_piece:
				doomed_piece.dim()
				doomed_piece.queue_free()
				all_pieces[piece.x][piece.y] = null
				
		if get_parent().has_node("collapse_timer"):
			get_parent().get_node("collapse_timer").start()

func get_matched_pieces(i: int, j: int) -> Array:
	var matching_color = all_pieces[i][j].color
	if matching_color == "character":
		return []
	
	var grids_to_return: Array = []
	
	for adjacents in range(-2, 1):
		if is_in_visible_grid(i + adjacents, j ) and is_in_visible_grid(i + adjacents +2, j):
			var piece1 = all_pieces[i + adjacents][j]
			var piece2 = all_pieces[i + adjacents + 1][j]
			var piece3 = all_pieces[i + adjacents + 2][j]
			if piece1 and piece2 and piece3:
				if piece1.color == matching_color and piece2.color == matching_color and piece3.color == matching_color:
					grids_to_return.append(Vector2i(i + adjacents, j))
					grids_to_return.append(Vector2i(i + adjacents + 1, j))
					grids_to_return.append(Vector2i(i + adjacents + 2, j))
	
	for adjacents in range(-2, 1):
		if is_in_visible_grid(i, j + adjacents) and is_in_visible_grid(i, j + adjacents + 2):
			var piece1 = all_pieces[i][j + adjacents]
			var piece2 = all_pieces[i][j + adjacents + 1]
			var piece3 = all_pieces[i][j + adjacents + 2]
			if piece1 and piece2 and piece3:
				if piece1.color == matching_color and piece2.color == matching_color and piece3.color == matching_color:
					grids_to_return.append(Vector2i(i, j + adjacents))
					grids_to_return.append(Vector2i(i, j + adjacents + 1))
					grids_to_return.append(Vector2i(i, j + adjacents + 2))
	
	return grids_to_return

func collapse_and_refill_columns() -> void:
	var moving_pieces: Array = []
	var character_fell: bool = false
	var character_drop_amount: int = 0
	
	for i: int in level_width:
		var empty_spots: int = 0
		
		for j: int in range(level_height - 1, -1, -1):
			if all_pieces[i][j] == null:
				empty_spots += 1
			elif empty_spots > 0:
				var piece: Node2D = all_pieces[i][j]
				var nj: int = j + empty_spots
				
				all_pieces[i][nj] = piece
				all_pieces[i][j] = null
				
				if piece.color == "character":
					character_fell = true
					character_drop_amount = empty_spots
					character_current_depth += empty_spots
					character_vertical_travel += empty_spots
					print("Character fell ", empty_spots, " rows during collapse. New depth is ", character_current_depth)
				
				moving_pieces.append(piece)
				
		for k: int in range(empty_spots):
			var nj: int = k
			
			var random_scene: PackedScene = possible_pieces.pick_random()
			var new_piece: Node2D = random_scene.instantiate()
			
			apply_treasure_chance(new_piece, 0.25)
			add_child(new_piece)
			all_pieces[i][nj] = new_piece
			
			moving_pieces.append(new_piece)
	
	if character_fell:
		y_start -= character_drop_amount * offset
		
		for i: int in level_width:
			for j: int in level_height:
				var piece: Node2D = all_pieces[i][j]
				if is_instance_valid(piece):
					piece.move(grid_to_pixel(i, j))
	else:
		for piece: Node2D in moving_pieces:
			var grid_position: Vector2i = get_piece_grid_position(piece)
			if grid_position != Vector2i(-1, -1):
				piece.move(grid_to_pixel(grid_position.x, grid_position.y))
	
	if moving_pieces.size() > 0:
		await get_tree().create_timer(0.35).timeout
		find_matches()
	
	check_win()

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

func check_win() -> void:
	var character_grid = get_character_grid()
	if character_grid == null:
		return
	
	var bottom_row_index = all_pieces[character_grid.x].size() - 1
	
	if character_grid.y == bottom_row_index:
		trigger_victory()

func trigger_victory() -> void:
	print("Player wins")
	win_screen.visible = true
	
#func _on_destroy_timer_timeout() -> void:
#	destroy_matched();

func _on_collapse_timer_timeout() -> void:
	# collapse_columns()
	collapse_and_refill_columns()

func _on_refill_timer_timeout() -> void:
	# refill_columns()
	collapse_and_refill_columns()

func _on_button_pressed() -> void:
	print("reset button was clicked")
	get_tree().reload_current_scene()
