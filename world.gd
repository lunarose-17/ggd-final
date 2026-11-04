extends Node2D


@onready var grid: TileMapLayer = $TileMapLayer

@onready var rng:RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = hash("wassup") * hash("wassup") * 50
	
	self.firstGen()
	self.clearOutliers()
	self.clearOutliers(false)

	
func firstGen() -> void:
	for x:int in range(0, 32):
		for y:int in range(0, 32):
			grid.set_cell(Vector2i(x, y), 0, Vector2i(0, 0 if (rng.randi() % 2 == 0) else 1))


func clearOutliers(includeDiagnols:bool = true) -> void:
	for x:int in range(0, 32):
		for y:int in range(0, 32):
			var curTile:Vector2i = grid.get_cell_atlas_coords(Vector2i(x, y))
			
			if (self.countNeighbors(Vector2i(x, y), includeDiagnols) < 1):
				grid.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

			
## Counts how many tiles surrounding the given tile coord
func countNeighbors(tilePos:Vector2i, includeDiagnols:bool) -> int:
	var count:int = 0
	
	for x:int in range(-1, 1):
		for y:int in range(-1, 1):
			if (x == 0 and y == 0):
				continue;
			
			if (not includeDiagnols):
				if (x == y): continue
			
			var curTile:Vector2i = grid.get_cell_atlas_coords(tilePos + Vector2i(x, y))
			
			if (curTile == Vector2i(-1, -1)):
				count += 1
				
			if (curTile == Vector2i(0, 0)):
				count += 1
				
	return count
	

func _process(delta: float) -> void:
	pass
