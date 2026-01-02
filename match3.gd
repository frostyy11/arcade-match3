# Save this as: CandyCrush.gd
# Then create a new 2D Scene, rename the Node2D to "CandyCrush"
# Click on the CandyCrush node, in Inspector panel click the script icon (📄) next to "Script"
# Click "Load" and select this CandyCrush.gd file

extends Node2D

# Grid settings
const GRID_WIDTH = 8
const GRID_HEIGHT = 8
const CELL_SIZE = 64
const SWAP_SPEED = 0.2
const FALL_SPEED = 0.3

# Candy types (colors)
const CANDY_COLORS = [
	Color(1, 0, 0),      # Red
	Color(0, 1, 0),      # Green
	Color(0, 0, 1),      # Blue
	Color(1, 1, 0),      # Yellow
	Color(1, 0, 1),      # Magenta
	Color(0, 1, 1)       # Cyan
]

# Game state
var grid = []
var selected_candy = null
var is_swapping = false
var is_processing = false
var score = 0
var move_count = 0
var combo_multiplier = 1

# UI references
var score_label
var moves_label
var combo_label

func _ready():
	randomize()
	setup_ui()
	initialize_grid()
	
	# Ensure no matches at start
	while find_all_matches().size() > 0:
		initialize_grid()

func setup_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.2)
	bg.size = Vector2(GRID_WIDTH * CELL_SIZE + 200, GRID_HEIGHT * CELL_SIZE + 100)
	bg.position = Vector2(-50, -50)
	add_child(bg)
	
	# Score label
	score_label = Label.new()
	score_label.position = Vector2(GRID_WIDTH * CELL_SIZE + 20, 20)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.text = "Score: 0"
	add_child(score_label)
	
	# Moves label
	moves_label = Label.new()
	moves_label.position = Vector2(GRID_WIDTH * CELL_SIZE + 20, 60)
	moves_label.add_theme_font_size_override("font_size", 20)
	moves_label.text = "Moves: 0"
	add_child(moves_label)
	
	# Combo label
	combo_label = Label.new()
	combo_label.position = Vector2(GRID_WIDTH * CELL_SIZE + 20, 100)
	combo_label.add_theme_font_size_override("font_size", 20)
	combo_label.text = "Combo: x1"
	add_child(combo_label)
	
	# Instructions
	var instructions = Label.new()
	instructions.position = Vector2(10, GRID_HEIGHT * CELL_SIZE + 20)
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.text = "Click candies to swap and match 3 or more!"
	add_child(instructions)

func initialize_grid():
	# Clear existing grid
	for row in grid:
		for candy in row:
			if candy:
				candy.queue_free()
	grid.clear()
	
	# Create new grid
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			var candy = create_candy(x, y)
			row.append(candy)
		grid.append(row)

func create_candy(x, y, color_index = -1):
	var candy = ColorRect.new()
	candy.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	candy.position = Vector2(x * CELL_SIZE + 2, y * CELL_SIZE + 2)
	
	if color_index == -1:
		color_index = randi() % CANDY_COLORS.size()
	
	candy.color = CANDY_COLORS[color_index]
	candy.set_meta("grid_x", x)
	candy.set_meta("grid_y", y)
	candy.set_meta("color_index", color_index)
	
	add_child(candy)
	return candy

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_swapping or is_processing:
			return
			
		var pos = event.position
		var grid_x = int(pos.x / CELL_SIZE)
		var grid_y = int(pos.y / CELL_SIZE)
		
		if grid_x >= 0 and grid_x < GRID_WIDTH and grid_y >= 0 and grid_y < GRID_HEIGHT:
			handle_candy_click(grid_x, grid_y)

func handle_candy_click(x, y):
	if selected_candy == null:
		selected_candy = Vector2(x, y)
		highlight_candy(x, y, true)
	else:
		var dx = abs(selected_candy.x - x)
		var dy = abs(selected_candy.y - y)
		
		# Check if adjacent
		if (dx == 1 and dy == 0) or (dx == 0 and dy == 1):
			highlight_candy(selected_candy.x, selected_candy.y, false)
			await swap_candies(selected_candy.x, selected_candy.y, x, y)
			selected_candy = null
		else:
			highlight_candy(selected_candy.x, selected_candy.y, false)
			selected_candy = Vector2(x, y)
			highlight_candy(x, y, true)

func highlight_candy(x, y, highlight):
	var candy = grid[y][x]
	if candy:
		if highlight:
			candy.modulate = Color(1.5, 1.5, 1.5)
		else:
			candy.modulate = Color(1, 1, 1)

func swap_candies(x1, y1, x2, y2):
	is_swapping = true
	move_count += 1
	update_ui()
	
	var candy1 = grid[y1][x1]
	var candy2 = grid[y2][x2]
	
	# Swap in grid
	grid[y1][x1] = candy2
	grid[y2][x2] = candy1
	
	# Update metadata
	candy1.set_meta("grid_x", x2)
	candy1.set_meta("grid_y", y2)
	candy2.set_meta("grid_x", x1)
	candy2.set_meta("grid_y", y1)
	
	# Animate swap
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(candy1, "position", Vector2(x2 * CELL_SIZE + 2, y2 * CELL_SIZE + 2), SWAP_SPEED)
	tween.tween_property(candy2, "position", Vector2(x1 * CELL_SIZE + 2, y1 * CELL_SIZE + 2), SWAP_SPEED)
	await tween.finished
	
	# Check for matches
	var matches = find_all_matches()
	
	if matches.size() == 0:
		# Swap back if no match
		grid[y1][x1] = candy1
		grid[y2][x2] = candy2
		candy1.set_meta("grid_x", x1)
		candy1.set_meta("grid_y", y1)
		candy2.set_meta("grid_x", x2)
		candy2.set_meta("grid_y", y2)
		
		var tween2 = create_tween()
		tween2.set_parallel(true)
		tween2.tween_property(candy1, "position", Vector2(x1 * CELL_SIZE + 2, y1 * CELL_SIZE + 2), SWAP_SPEED)
		tween2.tween_property(candy2, "position", Vector2(x2 * CELL_SIZE + 2, y2 * CELL_SIZE + 2), SWAP_SPEED)
		await tween2.finished
	else:
		combo_multiplier = 1
		await process_matches()
	
	is_swapping = false

func find_all_matches():
	var matches = []
	
	# Check horizontal matches
	for y in range(GRID_HEIGHT):
		var i = 0
		while i < GRID_WIDTH:
			var color = grid[y][i].get_meta("color_index")
			var match_length = 1
			
			while i + match_length < GRID_WIDTH and grid[y][i + match_length].get_meta("color_index") == color:
				match_length += 1
			
			if match_length >= 3:
				for j in range(match_length):
					var pos = Vector2(i + j, y)
					if not matches.has(pos):
						matches.append(pos)
			
			i += match_length if match_length >= 3 else 1
	
	# Check vertical matches
	for x in range(GRID_WIDTH):
		var i = 0
		while i < GRID_HEIGHT:
			var color = grid[i][x].get_meta("color_index")
			var match_length = 1
			
			while i + match_length < GRID_HEIGHT and grid[i + match_length][x].get_meta("color_index") == color:
				match_length += 1
			
			if match_length >= 3:
				for j in range(match_length):
					var pos = Vector2(x, i + j)
					if not matches.has(pos):
						matches.append(pos)
			
			i += match_length if match_length >= 3 else 1
	
	return matches

func process_matches():
	is_processing = true
	
	while true:
		var matches = find_all_matches()
		if matches.size() == 0:
			break
		
		# Add score
		score += matches.size() * 10 * combo_multiplier
		combo_multiplier += 1
		update_ui()
		
		# Remove matched candies
		for match in matches:
			var candy = grid[match.y][match.x]
			if candy:
				var tween = create_tween()
				tween.tween_property(candy, "scale", Vector2.ZERO, 0.2)
				await tween.finished
				candy.queue_free()
				grid[match.y][match.x] = null
		
		# Drop candies
		await drop_candies()
		
		# Fill empty spaces
		fill_empty_spaces()
		
		await get_tree().create_timer(0.3).timeout
	
	combo_multiplier = 1
	update_ui()
	is_processing = false

func drop_candies():
	var has_dropped = false
	
	for x in range(GRID_WIDTH):
		var empty_spaces = 0
		for y in range(GRID_HEIGHT - 1, -1, -1):
			if grid[y][x] == null:
				empty_spaces += 1
			elif empty_spaces > 0:
				has_dropped = true
				var candy = grid[y][x]
				var new_y = y + empty_spaces
				
				grid[new_y][x] = candy
				grid[y][x] = null
				
				candy.set_meta("grid_y", new_y)
				
				var tween = create_tween()
				tween.tween_property(candy, "position", Vector2(x * CELL_SIZE + 2, new_y * CELL_SIZE + 2), FALL_SPEED)
	
	if has_dropped:
		await get_tree().create_timer(FALL_SPEED).timeout

func fill_empty_spaces():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] == null:
				var candy = create_candy(x, y)
				candy.position.y = -CELL_SIZE
				grid[y][x] = candy
				
				var tween = create_tween()
				tween.tween_property(candy, "position", Vector2(x * CELL_SIZE + 2, y * CELL_SIZE + 2), FALL_SPEED)

func update_ui():
	score_label.text = "Score: " + str(score)
	moves_label.text = "Moves: " + str(move_count)
	combo_label.text = "Combo: x" + str(combo_multiplier)