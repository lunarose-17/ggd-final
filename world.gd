extends Node2D


@onready var grid: TileMapLayer = $TileMapLayer

@onready var rng:RandomNumberGenerator = RandomNumberGenerator.new()

const gridSize:Vector2i = Vector2i(32, 32)

const oceanTile:Vector2i = Vector2i(0, 1)
const floorTile:Vector2i = Vector2i(0, 0)

const targetLand:float = 0.5
const minIslandRadius:float = 4.5
const maxIslandRadius:float = 9.0
const edgeMargin:int = 0
# Negative so islands can overlap a bit
const islandGap:float = -3.0
const placeAttempts:int = 200

const centreLandChance:float = 0.95
const islandPlateau:float = 0.7
const backgroundLandChance:float = 0.08

const smoothPasses:int = 5
const minRegionSize:int = 8

var land:Array = []
# x, y is the centre and z is the radius
var islands:Array[Vector3] = []


func _ready() -> void:
	rng.seed = hash("wassup")
	self.generate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		rng.randomize()
		self.generate()


func generate() -> void:
	self.placeIslands()
	self.firstGen()
	for i:int in range(smoothPasses):
		self.smooth()
	self.removeSmallRegions(true)
	self.removeSmallRegions(false)
	self.paint()


func placeIslands() -> void:
	islands = []

	for attempt:int in range(placeAttempts):
		var radius:float = rng.randf_range(minIslandRadius, maxIslandRadius)
		var x:float = rng.randf_range(edgeMargin, gridSize.x - 1 - edgeMargin)
		var y:float = rng.randf_range(edgeMargin, gridSize.y - 1 - edgeMargin)

		if self.fitsIsland(Vector2(x, y), radius):
			islands.append(Vector3(x, y, radius))

			if self.islandCoverage() >= targetLand:
				break


## Rough guess of how much of the map will end up as land
func islandCoverage() -> float:
	var covered:int = 0
	for x:int in range(gridSize.x):
		for y:int in range(gridSize.y):
			if self.landChanceAt(Vector2i(x, y)) >= 0.5:
				covered += 1

	return float(covered) / (gridSize.x * gridSize.y)


func fitsIsland(centre:Vector2, radius:float) -> bool:
	for island:Vector3 in islands:
		var dist:float = centre.distance_to(Vector2(island.x, island.y))
		if dist < radius + island.z + islandGap:
			return false

	return true


## Chance of a tile starting as land, higher the closer it is to an island centre
func landChanceAt(pos:Vector2i) -> float:
	var best:float = 0.0

	for island:Vector3 in islands:
		var dist:float = Vector2(pos).distance_to(Vector2(island.x, island.y))
		var plateauEnd:float = island.z * islandPlateau
		var closeness:float = 1.0
		if dist > plateauEnd:
			closeness = 1.0 - (dist - plateauEnd) / (island.z - plateauEnd)
		if closeness < 0.0:
			closeness = 0.0

		if closeness > best:
			best = closeness

	return maxf(best * centreLandChance, backgroundLandChance)


func firstGen() -> void:
	land = []
	for x:int in range(gridSize.x):
		var column:Array = []
		for y:int in range(gridSize.y):
			column.append(rng.randf() < self.landChanceAt(Vector2i(x, y)))
		land.append(column)


func smooth(includeDiagonals:bool = true) -> void:
	# Check neighbors on a copy so tiles we already changed don't mess up the count
	var old:Array = land.duplicate(true)

	for x:int in range(gridSize.x):
		for y:int in range(gridSize.y):
			var neighbors:int = self.countNeighbors(old, Vector2i(x, y), includeDiagonals)
			var half:int = 4 if includeDiagonals else 2

			if neighbors > half:
				land[x][y] = true
			elif neighbors < half:
				land[x][y] = false


func countNeighbors(from:Array, tilePos:Vector2i, includeDiagonals:bool) -> int:
	var count:int = 0

	for x:int in range(-1, 2):
		for y:int in range(-1, 2):

			if (x == 0 and y == 0):
				continue

			if (not includeDiagonals and x != 0 and y != 0):
				continue

			var pos:Vector2i = tilePos + Vector2i(x, y)

			# Tiles outside the grid count as whatever this tile is
			if not self.inBounds(pos):
				if from[tilePos.x][tilePos.y]:
					count += 1
				continue

			if from[pos.x][pos.y]:
				count += 1

	return count


func removeSmallRegions(isLand:bool) -> void:
	var visited:Dictionary = {}

	for x:int in range(gridSize.x):
		for y:int in range(gridSize.y):
			var start:Vector2i = Vector2i(x, y)
			if visited.has(start) or land[x][y] != isLand:
				continue

			var region:Array[Vector2i] = self.floodFill(start, isLand, visited)
			if region.size() < minRegionSize:
				for tile:Vector2i in region:
					land[tile.x][tile.y] = not isLand


func floodFill(start:Vector2i, isLand:bool, visited:Dictionary) -> Array[Vector2i]:
	var region:Array[Vector2i] = []
	var toCheck:Array[Vector2i] = [start]
	visited[start] = true

	while toCheck.size() > 0:
		var tile:Vector2i = toCheck.pop_back()
		region.append(tile)

		for dir:Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next:Vector2i = tile + dir
			if self.inBounds(next) and not visited.has(next) and land[next.x][next.y] == isLand:
				visited[next] = true
				toCheck.append(next)

	return region


func inBounds(pos:Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < gridSize.x and pos.y < gridSize.y


func paint() -> void:
	for x:int in range(gridSize.x):
		for y:int in range(gridSize.y):
			grid.set_cell(Vector2i(x, y), 0, floorTile if land[x][y] else oceanTile)
