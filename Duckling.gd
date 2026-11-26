extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 250.0
@export var follow_distance: float = 40.0
@export var slot_offset: Vector2 = Vector2.ZERO
@export var distraction_rate: float = 0.01
@export var current_seed: int = 12345

var mother: CharacterBody2D = null
enum state {IDLE, FOLLOWING, DISTRACTED}
var current_state: state = state.IDLE
var state_timer: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var behind_distance: float = 40.0
var side_distance: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	# adding variation for each duckling
	rng.seed = current_seed + get_instance_id()
	
	# find the current mother in the scene
	var mothers = get_tree().get_nodes_in_group("player")
	if not mothers.is_empty():
		mother = mothers[0]
		
	# give each duckling a slight randomized offset	
	behind_distance = rng.randf_range(30.0, 50.0)
	side_distance = rng.randf_range(-30.0, 30.0)
	speed += rng.randf_range(-20.0, 20.0)
	
	transition_to(state.IDLE)
		
		
func _physics_process(delta: float) -> void:
	# flip animation sprite direction
	if velocity.x < -5.0:
		sprite.flip_h = true
	elif velocity.x > 5.0:
		sprite.flip_h = false
	
	if not mother:
		return
	
	# target position always relative to mother
	update_slot_offset(delta)
	var target_position = mother.global_position + slot_offset
	
	match current_state:
		state.IDLE:
			velocity = Vector2.ZERO
			
			# move if mother moves far enough away
			if global_position.distance_to(target_position) > 25.0:
				transition_to(state.FOLLOWING)
		
		state.FOLLOWING:
			# stop moving toward mother if we are close enough
			if global_position.distance_to(target_position) <= 15.0 and mother.velocity == Vector2.ZERO:
				velocity = Vector2.ZERO
				transition_to(state.IDLE)
				return
			
			if global_position.distance_to(target_position) > 10.0:
				var direction = global_position.direction_to(target_position)
				velocity = direction * speed
				move_and_slide()

				if rng.randf_range(0.0, 1.0) < distraction_rate:
					transition_to(state.DISTRACTED)
			else:
				velocity = Vector2.ZERO
				
		state.DISTRACTED:
			state_timer -= delta
			
			if global_position.distance_to(wander_target) > 4.0:
				velocity = global_position.direction_to(wander_target) * (speed * 0.3)
				move_and_slide()
			else:
				velocity = Vector2.ZERO
			
			if state_timer <= 0.0:
				transition_to(state.FOLLOWING)
			

# helper function to swtch between states
func transition_to(new_state: state) -> void:
	current_state = new_state

	# do actions after switching states
	match current_state:
		state.IDLE:
			print("Child Idling")
			sprite.play("idle")
		state.FOLLOWING:
			print("Child following")
			sprite.play("walk")
		state.DISTRACTED:
			print("Child distracted")
			state_timer = rng.randf_range(1.5, 3.0)

			calculate_distraction_offset()

# calculate the position that the player goes to while distracted
func calculate_distraction_offset() -> void:
	var random_offset = Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
	wander_target = global_position + random_offset
	
func update_slot_offset(delta: float) -> void:
	if mother.velocity.length() > 10.0:
		var move_dir := mother.velocity.normalized()
		facing = facing.slerp(move_dir, 1.0 - exp(-8.0 * delta))
		
	slot_offset = -facing * behind_distance + facing.orthogonal() * side_distance