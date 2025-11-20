extends Node3D

@onready var cube_mesh: Mesh = preload("res://cube_mesh.tres") # A plain cube mesh, not a scene
var rng = RandomNumberGenerator.new()

@onready var sizeX = int($Control/SpinBoxX.value)
@onready var sizeY = int($Control/SpinBoxY.value)
@onready var sizeZ = int($Control/SpinBoxZ.value)
@onready var spawn_chance = float($Control/SpinBoxChance.value)

@onready var born_with_min = int($Control/born_with_min.value)
@onready var born_with_max = int($Control/born_with_max.value)

@onready var survive_with_min = int($Control/survive_with_min.value)
@onready var survive_with_max = int($Control/survive_with_max.value)

@onready var grid = []

# Create a MultiMeshInstance3D
@onready var mmi = MultiMeshInstance3D.new()

#stuff for multithreading, or 1 more thread in this case ^^ 
#UPDATE: browser supports no multithreading with godot... :C 
var worker_thread: Thread
var is_processing := false

func _ready() -> void:
	$Camera3D.target = Vector3(sizeX/2, sizeY/2, sizeZ/2)
	$Camera3D._update_camera_position()
	rng.randomize()
	grid = PackedInt32Array()
	

func _on_start_pressed() -> void:
	rng.randomize()
	
	sizeX = int($Control/SpinBoxX.value)
	sizeY = int($Control/SpinBoxY.value)
	sizeZ = int($Control/SpinBoxZ.value)
	
	#update cam
	$Camera3D.target = Vector3(sizeX/2, sizeY/2, sizeZ/2)
	$Camera3D._update_camera_position()
	
	spawn_chance = float($Control/SpinBoxChance.value)
	
	
	born_with_min = int($Control/born_with_min.value)
	born_with_max = int($Control/born_with_max.value)

	survive_with_min = int($Control/survive_with_min.value)
	survive_with_max = int($Control/survive_with_max.value)
	
	#if !(mmi.multimesh and mmi.multimesh.instance_count > 0):
	mmi.multimesh = MultiMesh.new()
	var total = sizeX * sizeY * sizeZ
	mmi.multimesh.mesh = cube_mesh
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.multimesh.instance_count = total

	add_child(mmi)
	
	grid.resize(sizeX * sizeY * sizeZ)
	for x in range(sizeX):
		for y in range(sizeY):
			for z in range(sizeZ):
				var index = x * sizeY * sizeZ + y * sizeZ + z
				grid[index] = int(rng.randi_range(0, 99) <= spawn_chance - 1)
	
	updateField()
	
	


func updateField():
	var index = 0
	for x in sizeX:
		for y in sizeY:
			for z in sizeZ:
				var gridindex = x * sizeY * sizeZ + y * sizeZ + z
				if grid[gridindex] == 1:
					var t = Transform3D()
					t.origin = Vector3(x, y, z)
					mmi.multimesh.set_instance_transform(index, t)
				else:
					# moving cube far away to not render it ^^
					mmi.multimesh.set_instance_transform(index, Transform3D(Basis(), Vector3(0, -9999, 0)))
				index += 1




func next_generation():
	var new_grid := PackedInt32Array()
	new_grid.resize(sizeX * sizeY * sizeZ)

	for x in range(sizeX):
		for y in range(sizeY):
			for z in range(sizeZ):
				var index = x * sizeY * sizeZ + y * sizeZ + z
				var neighbors = 0

				# Count neighbors in 3D (26 possible), wrapping around edges
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						for dz in range(-1, 2):
							if dx == 0 and dy == 0 and dz == 0:
								continue
							
							# wrap-around stuff
							var nx = (x + dx + sizeX) % sizeX
							var ny = (y + dy + sizeY) % sizeY
							var nz = (z + dz + sizeZ) % sizeZ

							var n_index = nx * sizeY * sizeZ + ny * sizeZ + nz
							if grid[n_index] == 1:
								neighbors += 1

				var current = grid[index]
				var new_value = 0

				#survive with 5–8 neighbors, born with exactly 6
				if current == 1 and neighbors in range( int($Control/survive_with_min.value), int($Control/survive_with_max.value)):
					new_value = 1
				elif current == 0 and neighbors in range( int($Control/born_with_min.value), int($Control/born_with_max.value)):
					new_value = 1

				new_grid[index] = new_value

	grid = new_grid

#liks its a single additional thread, tried multithreading but too much right now
#ignore what i wrote here, not using multithreaded bcs browser :c 
func _compute_next_generation_threaded(old_grid: PackedInt32Array):
	var new_grid := PackedInt32Array()
	new_grid.resize(sizeX * sizeY * sizeZ)
	
	for x in range(sizeX):
		for y in range(sizeY):
			for z in range(sizeZ):
				var index = x * sizeY * sizeZ + y * sizeZ + z
				var neighbors = 0
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						for dz in range(-1, 2):
							if dx == 0 and dy == 0 and dz == 0:
								continue
							var nx = (x + dx + sizeX) % sizeX
							var ny = (y + dy + sizeY) % sizeY
							var nz = (z + dz + sizeZ) % sizeZ
							var n_index = nx * sizeY * sizeZ + ny * sizeZ + nz
							if old_grid[n_index] == 1:
								neighbors += 1
				var current = old_grid[index]
				var new_value = 0
				# 5,6 then survive, born if 6, my defaults values 
				if current == 1 and neighbors in range( int($Control/survive_with_min.value), int($Control/survive_with_max.value)):
					new_value = 1
				elif current == 0 and neighbors in range( int($Control/born_with_min.value), int($Control/born_with_max.value)):
					new_value = 1
				new_grid[index] = new_value

	# Return result to main thread
	call_deferred("_on_generation_done", new_grid)

func _on_generation_done(new_grid: PackedInt32Array):
	grid = new_grid
	updateField()  #"draw" new field
	is_processing = false
	if worker_thread:
		worker_thread.wait_to_finish()



func _on_next_pressed() -> void:
	if is_processing:
		return
	is_processing = true
	#worker_thread = Thread.new()
	# i hate my live why did i use gd script and godot its soooooo slow 
	#worker_thread.start(Callable(self, "_compute_next_generation_threaded").bind(grid.duplicate()))
	
	#ok i just firgured out godot does not support multithreading in browser right now.. ufff omfg 
	
	_compute_next_generation_threaded(grid)
	

	pass # Replace with function body.
