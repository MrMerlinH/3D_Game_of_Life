extends Node3D

@onready var cube_mesh: Mesh = preload("res://cube_mesh.tres")
var rng = RandomNumberGenerator.new()

@onready var sizeX = int($Control/SpinBoxX.value)
@onready var sizeY = int($Control/SpinBoxY.value)
@onready var sizeZ = int($Control/SpinBoxZ.value)
@onready var spawn_chance = float($Control/SpinBoxChance.value)

@onready var grid: PackedInt32Array = PackedInt32Array()
@onready var mmi = MultiMeshInstance3D.new()

# Threading control

var thread_count := 4
var worker_threads: Array = []
var threads_done := 0
var thread_mutex := Mutex.new()
var neighbor_offsets: Array = []
var is_processing := false

func _ready() -> void:
# Camera setup
	$Camera3D.target = Vector3(sizeX/2, sizeY/2, sizeZ/2)
	$Camera3D._update_camera_position()
	rng.randomize()

# Precompute neighbor offsets (26 positions)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				neighbor_offsets.append(Vector3i(dx, dy, dz))

func _on_start_pressed() -> void:
	rng.randomize()

	sizeX = int($Control/SpinBoxX.value)
	sizeY = int($Control/SpinBoxY.value)
	sizeZ = int($Control/SpinBoxZ.value)
	spawn_chance = float($Control/SpinBoxChance.value)

#tried to just spawn single meshes for everything but that was also really slow
#multimesh performance is ok, i just teleport blocks that are not visible far away
	if !(mmi.multimesh and mmi.multimesh.instance_count > 0):
		mmi.multimesh = MultiMesh.new()
		var total = sizeX * sizeY * sizeZ
		mmi.multimesh.mesh = cube_mesh
		mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mmi.multimesh.instance_count = total
		add_child(mmi)

#using 1d array becasue godot is slow with 3d array, like really slow
	grid.resize(sizeX * sizeY * sizeZ)
	for x in range(sizeX):
		for y in range(sizeY):
			for z in range(sizeZ):
				var index = x * sizeY * sizeZ + y * sizeZ + z
				grid[index] = int(rng.randi_range(0, 100) <= spawn_chance)

	updateField()

#updates the multimesh to, draws block in correcnt possition grid[gridindex] == 1 or out of sight
func updateField():
	var index = 0
	for x in range(sizeX):
		for y in range(sizeY):
			for z in range(sizeZ):
				var gridindex = x * sizeY * sizeZ + y * sizeZ + z
				if grid[gridindex] == 1:
					var t = Transform3D()
					t.origin = Vector3(x, y, z)
					mmi.multimesh.set_instance_transform(index, t)
				else:
					mmi.multimesh.set_instance_transform(index, Transform3D(Basis(), Vector3(0, -9999, 0)))
				index += 1

# ============ MULTI-THREAD NEXT GENERATION ============

func _compute_grid_slice(old_grid: PackedInt32Array, new_grid: PackedInt32Array, x_start: int, x_end: int) -> void:
	for x in range(x_start, x_end):
		for y in range(sizeY):
			for z in range(sizeZ):
				var index = x * sizeY * sizeZ + y * sizeZ + z
				var neighbors = 0
				for offset in neighbor_offsets:
					var nx = (x + offset.x + sizeX) % sizeX
					var ny = (y + offset.y + sizeY) % sizeY
					var nz = (z + offset.z + sizeZ) % sizeZ
					var n_index = nx * sizeY * sizeZ + ny * sizeZ + nz
					if old_grid[n_index] == 1:
						neighbors += 1
					var current = old_grid[index]
					var new_value = 0
					if current == 1 and neighbors in range(5, 8):
						new_value = 1
					elif current == 0 and neighbors == 6:
						new_value = 1
					new_grid[index] = new_value

# Thread finished one slice
	thread_mutex.lock()
	threads_done += 1
	thread_mutex.unlock()

func _compute_next_generation_threaded(old_grid: PackedInt32Array):
	var new_grid := PackedInt32Array()
	new_grid.resize(sizeX * sizeY * sizeZ)
	threads_done = 0
	worker_threads.clear()
	
	var slice_size = int(ceil(float(sizeX) / thread_count))

	for t in range(thread_count):
		var x_start = t * slice_size
		var x_end = min((t + 1) * slice_size, sizeX)
		if x_start >= x_end:
			continue
		var thread = Thread.new()
		worker_threads.append(thread)
		thread.start(Callable(self, "_compute_grid_slice").bind(old_grid.duplicate(), new_grid, x_start, x_end))
	
	# Start polling for completion
	call_deferred("_poll_threads", new_grid)


func _poll_threads(new_grid: PackedInt32Array):
	if threads_done >= worker_threads.size():
		for t in worker_threads:
			t.wait_to_finish()
		call_deferred("_on_generation_done", new_grid)
	else:
		call_deferred("_poll_threads", new_grid)

func _on_generation_done(new_grid: PackedInt32Array):
	grid = new_grid
	updateField()
	is_processing = false

# Button handler

func _on_next_pressed() -> void:
	if is_processing:
		return
	is_processing = true
	_compute_next_generation_threaded(grid.duplicate())
