extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 300.0
@export var grid_size: float = 32.0
@export var distraction_rate: float = 0.05
@export var rock_density: float = 0.15
@export var current_seed: int = 12345
@export var run_test: bool = false

var astar := AStarGrid2D.new()
var path: PackedVector2Array = []
var path_index: int = 0
enum state {IDLE, FOLLOWING, DISTRACTED}
var current_state: state = state.IDLE
var state_timer: float = 0.0
var saved_path: PackedVector2Array = []
var saved_path_index: int = 0
var wander_target: Vector2 = Vector2.ZERO
var rng = RandomNumberGenerator.new()
var rock_count: int = 0

func _ready() -> void:
	rock_count = 600 * rock_density
	
	if run_test:
		run_evaluation()
	
	# create a grid of 100 x 100 squares
	astar.region = Rect2i(0, 0, 100, 100)
	astar.cell_size = Vector2(grid_size, grid_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	
	rng.seed = current_seed
	
	# initially set the state to idle
	current_state = state.IDLE
	spawn_obstacles()

	# find any obstacles placed in the game
	for node in get_tree().get_nodes_in_group("obstacles"):
		var cell := Vector2i((node.global_position / grid_size).floor())
		if astar.is_in_boundsv(cell):
			astar.set_point_solid(cell, true)

func _unhandled_input(event: InputEvent) -> void:
	# debugging for the distracted state
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		transition_to(state.DISTRACTED)
		return
	
	# calculate path when clicking a valid position
	if event.is_action_pressed("click"):
		var start := Vector2i((global_position / grid_size).floor())
		var end := Vector2i((get_global_mouse_position() / grid_size).floor())
		
		# if point is invalid then dont go
		if not astar.is_in_boundsv(end) or astar.is_point_solid(end):
			return
	
		var id_path := astar.get_id_path(start, end)
		if id_path.is_empty():
			return
		
		# clear previous path if any
		path.clear()
		
		# create the path
		for id in id_path:
			path.append(Vector2(id) * grid_size + Vector2(grid_size, grid_size) / 2.0)
		path_index = 1 if path.size() > 1 else 0  # skip the cell we're already in
		
		# switch to following after path is made
		transition_to(state.FOLLOWING)	


func _physics_process(delta: float) -> void:
	# flip animation sprite direction
	if velocity.x < -5.0:
		sprite.flip_h = true
	elif velocity.x > 5.0:
		sprite.flip_h = false
	
	# check the current state
	match current_state:
		# if idle, do nothing
		state.IDLE:
			velocity = Vector2.ZERO
		
		# follow the path to the end
		state.FOLLOWING:
			# if at the end of path switch back to idle
			if path_index >= path.size():
				velocity = Vector2.ZERO
				transition_to(state.IDLE)
				return
			
			# move along the path
			var next_point := path[path_index]
			if global_position.distance_to(next_point) <= max(3.0, speed * delta):
				path_index += 1
				# random chance to get distracted while following the path
				if rng.randf_range(0.0, 1.0) < distraction_rate:
					transition_to(state.DISTRACTED)
				return
	
			velocity = global_position.direction_to(next_point) * speed
			move_and_slide()
	
		# do random movements that dont go to point
		# mimic a baby getting distracted
		state.DISTRACTED:
			state_timer -= delta
			# move in a random direction
			if global_position.distance_to(wander_target) > 4.0:
				velocity = global_position.direction_to(wander_target) * (speed * 0.4)
				move_and_slide()
			else:
				# if reach the end of random direction have chance to move again in new direction
				if rng.randf_range(0.0, 1.0) < 0.01:
					calculate_distraction_offset()
				else:
					velocity = Vector2.ZERO
				
			# if the distraction timer runs out, start following original path again
			if state_timer <= 0.0:
				path = saved_path
				path_index = saved_path_index
				transition_to(state.FOLLOWING)
	
# helper function to swtch between states
func transition_to(new_state: state) -> void:
	current_state = new_state
	
	# do actions after switching states
	match current_state:
		state.IDLE:
			print("Idling")
			sprite.play("idle")
		state.FOLLOWING:
			print("following")
			sprite.play("walk")
		state.DISTRACTED:
			print("distracted")
			state_timer = 2.0
			
			saved_path = path
			saved_path_index = path_index
			calculate_distraction_offset()

# calculate the position that the player goes to while distracted
func calculate_distraction_offset() -> void:
	var random_offset = Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
	wander_target = global_position + random_offset

	
# function for placing rocks. used for testing pathfinding
func spawn_obstacles() -> void:
	# var spawned = 0
	# var attempts = 0
	var duck_cell := Vector2i((global_position / grid_size).floor())
	var rock_scene = preload("res://Rock.tscn")
	var screen_cells := Vector2i(get_viewport_rect().size / grid_size)
	var bounds := Rect2i(1, 1, screen_cells.x - 2, screen_cells.y - 2)

	for cell in generate_rock_cells(rng, rock_count, bounds, [duck_cell]):
		var rock := rock_scene.instantiate()
		rock.position = Vector2(cell) * grid_size + Vector2(grid_size, grid_size) / 2.0
		rock.add_to_group("obstacles")
		get_tree().current_scene.add_child.call_deferred(rock)
		astar.set_point_solid(cell, true)
	
	# while spawned < rock_count and attempts < 500:
	# 	attempts += 1
	# 	var random_cell := Vector2i(rng.randi_range(1, screen_cells.x - 2), rng.randi_range(1, screen_cells.y - 2))
	# 	# var world_pos = Vector2(random_cell) * grid_size + Vector2(grid_size, grid_size) / 2.0
	# 
	# 	if random_cell == duck_cell or astar.is_point_solid(random_cell):
	# 		continue
	# 	
	# 	var rock = rock_scene.instantiate()
	# 	rock.global_position = Vector2(random_cell) * grid_size + Vector2(grid_size, grid_size) / 2.0
	# 	rock.add_to_group("obstacles")
	# 	get_tree().current_scene.add_child.call_deferred(rock)
	# 	astar.set_point_solid(random_cell, true)
	# 	spawned += 1

func generate_rock_cells(r: RandomNumberGenerator, count: int, bounds: Rect2i, exclude: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var taken := {}
	for c in exclude:
		taken[c] = true
	var attempts := 0
	while cells.size() < count and attempts < count * 20:
		attempts += 1
		var cell := Vector2i(
				r.randi_range(bounds.position.x, bounds.end.x - 1),
				r.randi_range(bounds.position.y, bounds.end.y - 1))
		if taken.has(cell):
			continue
		taken[cell] = true
		cells.append(cell)
	return cells
		
# test function for printing data
func run_evaluation() -> void:
	var bounds := Rect2i(5, 5, 90, 90)
	var densities := [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00]
	var total_seeds := 200
	var start := Vector2i(10, 10)
	var end := Vector2i(90, 90)
	var straight := Vector2(start).distance_to(Vector2(end))

	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 100, 100)
	grid.cell_size = Vector2(grid_size, grid_size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES

	print("Density | Rocks | Success | Avg Len Ratio | Avg Time OK (us) | Avg Time Fail (us)")
	for density in densities:
		var count := int(bounds.get_area() * density)
		var ok := 0
		var ratio_sum := 0.0
		var t_ok := 0
		var t_fail := 0

		for s in total_seeds:
			var r := RandomNumberGenerator.new()
			r.seed = 1000 + s
			grid.update()  # clears all solid cells
			# grid.fill_solid_region(grid.region, false)
			var rock_cells := generate_rock_cells(r, count, bounds, [start, end])
			for c in rock_cells:
				grid.set_point_solid(c, true)

			var t0 := Time.get_ticks_usec()
			var id_path := grid.get_id_path(start, end)
			var dt := Time.get_ticks_usec() - t0

			for c in rock_cells:
				grid.set_point_solid(c, false)
			
			if id_path.is_empty():
				t_fail += dt
				continue
			ok += 1
			t_ok += dt
			var length := 0.0
			for i in range(1, id_path.size()):
				length += Vector2(id_path[i]).distance_to(Vector2(id_path[i - 1]))
			ratio_sum += length / straight

		var fails := total_seeds - ok
		print("%6.0f%% | %5d | %6.1f%% | %13.3f | %16.1f | %18.1f" % [
			density * 100.0, count, 100.0 * ok / total_seeds,
			ratio_sum / maxi(ok, 1), float(t_ok) / maxi(ok, 1), float(t_fail) / maxi(fails, 1)])