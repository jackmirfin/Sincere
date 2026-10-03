extends RefCounted
class_name SpiderSurfaceCrawler

const GRAVITY: float = 1250.0
const CARDINAL_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

var body: CharacterBody2D = null
var body_shape: CollisionShape2D = null
var surface_normal: Vector2 = Vector2.UP
var crawl_direction: float = 1.0
var attached: bool = false
var probe_distance: float = 28.0
var stuck_time: float = 0.0
var previous_position: Vector2 = Vector2.ZERO
var has_previous_position: bool = false

func configure(character: CharacterBody2D, shape: CollisionShape2D, default_direction: float) -> void:
	body = character
	body_shape = shape
	crawl_direction = -1.0 if default_direction < 0.0 else 1.0
	var rectangle: RectangleShape2D = shape.shape as RectangleShape2D
	if rectangle != null:
		var world_size: Vector2 = rectangle.size * shape.global_scale.abs()
		probe_distance = maxf(world_size.x, world_size.y) * 0.5 + 16.0
	var requested_normal: Variant = body.get_meta("crawl_surface_normal", Vector2.UP)
	if requested_normal is Vector2 and not Vector2(requested_normal).is_zero_approx():
		surface_normal = Vector2(requested_normal).normalized()
		attached = true
		_set_surface_normal(surface_normal)

func prepare_motion(delta: float, requested_x_speed: float, target_position: Vector2, jumping: bool = false) -> void:
	if body == null or body_shape == null:
		return
	if jumping:
		_detach()
		body.velocity.y += GRAVITY * delta
		return

	if attached and absf(requested_x_speed) > 20.0:
		if has_previous_position and body.global_position.distance_to(previous_position) < 1.0:
			stuck_time += delta
		else:
			stuck_time = 0.0
	else:
		stuck_time = 0.0
	previous_position = body.global_position
	has_previous_position = true

	if attached:
		var approach_tangent: Vector2 = surface_normal.rotated(PI * 0.5).normalized()
		var approach_target: float = (target_position - body.global_position).dot(approach_tangent)
		if absf(approach_target) > 4.0:
			crawl_direction = signf(approach_target)
		elif absf(requested_x_speed) > 0.1 and absf(surface_normal.y) > 0.7:
			crawl_direction = signf(requested_x_speed)
	var expected_travel: Vector2 = surface_normal.rotated(PI * 0.5).normalized() * crawl_direction
	var collision_normal: Vector2 = _read_surface_collision(expected_travel if attached else Vector2.ZERO)
	if collision_normal != Vector2.ZERO:
		var collision_surface: Dictionary = _ray_for_surface(-collision_normal, probe_distance)
		_attach(collision_normal, collision_surface)

	if attached:
		var held_surface: Dictionary = _ray_for_surface(-surface_normal, probe_distance)
		if held_surface.is_empty():
			attached = false
		else:
			_attach(held_surface["normal"] as Vector2, held_surface)

	if not attached:
		var nearby_surface: Dictionary = _nearest_surface(probe_distance)
		if nearby_surface.is_empty():
			body.up_direction = Vector2.UP
			body.rotation = 0.0
			body.velocity.y += GRAVITY * delta
			return
		_attach(nearby_surface["normal"] as Vector2, nearby_surface)

	var target_delta: Vector2 = target_position - body.global_position
	var tangent: Vector2 = surface_normal.rotated(PI * 0.5).normalized()
	var tangent_target: float = target_delta.dot(tangent)
	if absf(tangent_target) > 4.0:
		crawl_direction = signf(tangent_target)
	elif absf(requested_x_speed) > 0.1 and absf(surface_normal.y) > 0.7:
		crawl_direction = signf(requested_x_speed)

	var travel_direction: Vector2 = tangent * crawl_direction
	var corner_hit: Dictionary = _ray_for_surface(travel_direction, probe_distance)
	if not corner_hit.is_empty():
		var new_normal: Vector2 = corner_hit["normal"] as Vector2
		if new_normal.dot(surface_normal) < 0.7:
			_attach(new_normal, corner_hit)
			tangent = surface_normal.rotated(PI * 0.5).normalized()
			travel_direction = tangent * crawl_direction

	if stuck_time >= 0.18:
		var recovery_surface: Dictionary = _ray_for_surface(travel_direction, probe_distance * 2.0)
		if not recovery_surface.is_empty() and (recovery_surface["normal"] as Vector2).dot(surface_normal) < 0.7:
			_attach(recovery_surface["normal"] as Vector2, recovery_surface)
			tangent = surface_normal.rotated(PI * 0.5).normalized()
			travel_direction = tangent * crawl_direction
		else:
			_detach()
			body.velocity = travel_direction * absf(requested_x_speed)
			body.velocity.y += GRAVITY * delta
			stuck_time = 0.0
			return
		stuck_time = 0.0

	body.up_direction = surface_normal
	body.velocity = travel_direction * absf(requested_x_speed)

func attack_launch_velocity(target_position: Vector2, launch_speed: float, grounded_velocity: Vector2) -> Vector2:
	if surface_normal.dot(Vector2.UP) > 0.9:
		return grounded_velocity
	var target_direction: Vector2 = target_position - body.global_position
	if target_direction.is_zero_approx():
		target_direction = surface_normal
	else:
		target_direction = target_direction.normalized()
	var launch_direction: Vector2 = target_direction
	if target_direction.dot(surface_normal) < 0.25:
		var tangent: Vector2 = surface_normal.rotated(PI * 0.5).normalized()
		if (target_position - body.global_position).dot(tangent) < 0.0:
			tangent = -tangent
		launch_direction = surface_normal + tangent * 0.65
	else:
		launch_direction = target_direction + surface_normal * 0.25
	return launch_direction.normalized() * launch_speed

func _read_surface_collision(expected_travel: Vector2) -> Vector2:
	for collision_index: int in body.get_slide_collision_count():
		var collision: KinematicCollision2D = body.get_slide_collision(collision_index)
		var normal: Vector2 = collision.get_normal()
		if absf(normal.length_squared() - 1.0) >= 0.1:
			continue
		if attached and normal.dot(surface_normal) >= 0.7:
			continue
		if attached and not expected_travel.is_zero_approx() and normal.dot(expected_travel) > -0.5:
			continue
		return normal
	return Vector2.ZERO

func _nearest_surface(max_distance: float) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance: float = max_distance + 1.0
	var center: Vector2 = body_shape.global_position
	for direction: Vector2 in CARDINAL_DIRECTIONS:
		var hit: Dictionary = _ray_for_surface(direction, max_distance)
		if hit.is_empty():
			continue
		var hit_position: Vector2 = hit["position"] as Vector2
		var distance: float = center.distance_to(hit_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = hit
	return nearest

func _ray_for_surface(direction: Vector2, distance: float) -> Dictionary:
	var origin: Vector2 = body_shape.global_position
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, origin + direction.normalized() * distance)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.collide_with_areas = false
	return body.get_world_2d().direct_space_state.intersect_ray(query)

func _attach(normal: Vector2, surface_hit: Dictionary = {}) -> void:
	if body == null or normal.is_zero_approx():
		return
	var shape_center_before: Vector2 = body_shape.global_position
	var normalized_normal: Vector2 = normal.normalized()
	if not attached or surface_normal.dot(normalized_normal) < 0.7:
		stuck_time = 0.0
	attached = true
	surface_normal = normalized_normal
	_set_surface_normal(surface_normal)
	body.global_position += shape_center_before - body_shape.global_position
	if not surface_hit.is_empty():
		var rectangle: RectangleShape2D = body_shape.shape as RectangleShape2D
		if rectangle != null:
			var scaled_size: Vector2 = rectangle.size * body_shape.global_scale.abs()
			var axis_x: Vector2 = body_shape.global_transform.x.normalized()
			var axis_y: Vector2 = body_shape.global_transform.y.normalized()
			var support_radius: float = absf(surface_normal.dot(axis_x)) * scaled_size.x * 0.5 + absf(surface_normal.dot(axis_y)) * scaled_size.y * 0.5
			var contact: Vector2 = surface_hit["position"] as Vector2
			var target_center: Vector2 = contact + surface_normal * support_radius
			body.global_position += target_center - body_shape.global_position

func _set_surface_normal(normal: Vector2) -> void:
	body.up_direction = normal
	body.rotation = Vector2.UP.angle_to(normal)

func launch_impulse(initial_velocity: Vector2) -> void:
	_detach()
	if body != null:
		body.velocity = initial_velocity


func _detach() -> void:
	var shape_center_before: Vector2 = body_shape.global_position
	attached = false
	surface_normal = Vector2.UP
	body.up_direction = Vector2.UP
	body.rotation = 0.0
	body.global_position += shape_center_before - body_shape.global_position
