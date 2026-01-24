## HexPathfinding - 六边形寻路和视野算法
##
## 提供:
## - A* 寻路
## - BFS 可达性分析
## - 视野 (FOV) 计算
## - 简单射线可见性
##
## 所有方法使用回调函数来判断格子是否可通行/阻挡视线
## 参考: https://www.redblobgames.com/grids/hexagons/
class_name HexPathfinding
extends RefCounted


# ========== A* 寻路 ==========

## A* 寻路结果
class PathResult:
	var path: Array[Vector2i] = []  ## 路径 (包含起点和终点)
	var cost: float = 0.0           ## 总代价
	var found: bool = false         ## 是否找到路径
	
	func _init(p_path: Array[Vector2i] = [], p_cost: float = 0.0, p_found: bool = false) -> void:
		path = p_path
		cost = p_cost
		found = p_found


## A* 寻路 (Axial 坐标)
##
## @param start: 起点
## @param goal: 终点
## @param is_passable: 判断格子是否可通行的回调 func(coord: Vector2i) -> bool
## @param cost_func: 移动代价回调 func(from: Vector2i, to: Vector2i) -> float (可选，默认为1)
## @param max_cost: 最大搜索代价 (可选，防止无限搜索)
## @return: PathResult
static func astar(
	start: Vector2i,
	goal: Vector2i,
	is_passable: Callable,
	cost_func: Callable = Callable(),
	max_cost: float = INF
) -> PathResult:
	# 优先队列: [priority, coord]
	var frontier: Array = []
	_heap_push(frontier, [0.0, start])
	
	var came_from: Dictionary = { start: null }
	var cost_so_far: Dictionary = { start: 0.0 }
	
	while not frontier.is_empty():
		var current: Vector2i = _heap_pop(frontier)[1]
		
		if current == goal:
			# 重建路径
			var result_path := _reconstruct_path(came_from, start, goal)
			return PathResult.new(result_path, cost_so_far[goal], true)
		
		for neighbor in HexMath.axial_neighbors(current):
			if not is_passable.call(neighbor):
				continue
			
			var move_cost := 1.0
			if cost_func.is_valid():
				move_cost = cost_func.call(current, neighbor)
			
			var new_cost: float = cost_so_far[current] + move_cost
			
			if new_cost > max_cost:
				continue
			
			if neighbor not in cost_so_far or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				var priority := new_cost + _heuristic(goal, neighbor)
				_heap_push(frontier, [priority, neighbor])
				came_from[neighbor] = current
	
	# 未找到路径
	return PathResult.new([], 0.0, false)


## 启发式函数 (六边形距离)
static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(HexMath.axial_distance(a, b))


## 重建路径
static func _reconstruct_path(
	came_from: Dictionary,
	start: Vector2i,
	goal: Vector2i
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := goal
	
	while current != start:
		path.append(current)
		current = came_from[current]
	
	path.append(start)
	path.reverse()
	return path


# ========== 简单堆实现 ==========

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	_heap_sift_up(heap, heap.size() - 1)


static func _heap_pop(heap: Array) -> Array:
	var result: Array = heap[0]
	var last: Variant = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		_heap_sift_down(heap, 0)
	return result


static func _heap_sift_up(heap: Array, idx: int) -> void:
	while idx > 0:
		var parent: int = (idx - 1) / 2
		if heap[idx][0] < heap[parent][0]:
			var tmp: Array = heap[idx]
			heap[idx] = heap[parent]
			heap[parent] = tmp
			idx = parent
		else:
			break


static func _heap_sift_down(heap: Array, idx: int) -> void:
	var arr_size: int = heap.size()
	while true:
		var smallest: int = idx
		var left: int = 2 * idx + 1
		var right: int = 2 * idx + 2
		
		if left < arr_size and heap[left][0] < heap[smallest][0]:
			smallest = left
		if right < arr_size and heap[right][0] < heap[smallest][0]:
			smallest = right
		
		if smallest != idx:
			var tmp: Array = heap[idx]
			heap[idx] = heap[smallest]
			heap[smallest] = tmp
			idx = smallest
		else:
			break


# ========== BFS 可达性 ==========

## BFS 可达性分析
##
## @param start: 起点
## @param max_movement: 最大移动距离
## @param is_passable: 判断格子是否可通行的回调
## @return: 所有可达格子的集合
static func reachable(
	start: Vector2i,
	max_movement: int,
	is_passable: Callable
) -> Array[Vector2i]:
	var visited: Dictionary = { start: true }
	var fringes: Array[Array] = [[start]]
	
	for k in range(1, max_movement + 1):
		fringes.append([])
		for hex in fringes[k - 1]:
			for neighbor in HexMath.axial_neighbors(hex):
				if neighbor not in visited and is_passable.call(neighbor):
					visited[neighbor] = true
					fringes[k].append(neighbor)
	
	var result: Array[Vector2i] = []
	for coord in visited.keys():
		result.append(coord)
	return result


## BFS 可达性分析 (带代价)
##
## @param start: 起点
## @param max_cost: 最大移动代价
## @param is_passable: 判断格子是否可通行的回调
## @param cost_func: 移动代价回调
## @return: Dictionary { coord: cost }
static func reachable_with_cost(
	start: Vector2i,
	max_cost: float,
	is_passable: Callable,
	cost_func: Callable = Callable()
) -> Dictionary:
	var visited: Dictionary = { start: 0.0 }
	var frontier: Array[Vector2i] = [start]
	
	while not frontier.is_empty():
		var current := frontier.pop_front()
		var current_cost: float = visited[current]
		
		for neighbor in HexMath.axial_neighbors(current):
			if not is_passable.call(neighbor):
				continue
			
			var move_cost := 1.0
			if cost_func.is_valid():
				move_cost = cost_func.call(current, neighbor)
			
			var new_cost := current_cost + move_cost
			
			if new_cost > max_cost:
				continue
			
			if neighbor not in visited or new_cost < visited[neighbor]:
				visited[neighbor] = new_cost
				frontier.append(neighbor)
	
	return visited


# ========== 视野 (FOV) ==========

## 简单射线可见性检测
##
## @param origin: 观察点
## @param target: 目标点
## @param blocks_vision: 判断格子是否阻挡视线的回调
## @return: 目标是否可见
static func is_visible(
	origin: Vector2i,
	target: Vector2i,
	blocks_vision: Callable
) -> bool:
	var line := HexMath.axial_line(origin, target)
	
	# 检查中间的格子 (排除起点和终点)
	for i in range(1, line.size() - 1):
		if blocks_vision.call(line[i]):
			return false
	
	return true


## 计算视野范围内所有可见格子
##
## @param origin: 观察点
## @param vision_range: 视野范围
## @param blocks_vision: 判断格子是否阻挡视线的回调
## @return: 所有可见格子
static func field_of_view(
	origin: Vector2i,
	vision_range: int,
	blocks_vision: Callable
) -> Array[Vector2i]:
	var visible: Array[Vector2i] = [origin]
	
	for hex in HexMath.axial_range(origin, vision_range):
		if hex == origin:
			continue
		if is_visible(origin, hex, blocks_vision):
			visible.append(hex)
	
	return visible


## 计算视野范围内所有可见格子 (优化版，使用环形扫描)
##
## 从内向外扫描，如果一个格子不可见，则不再检查它后面的格子
static func field_of_view_optimized(
	origin: Vector2i,
	vision_range: int,
	blocks_vision: Callable
) -> Array[Vector2i]:
	var visible: Dictionary = { origin: true }
	var blocked: Dictionary = {}
	
	# 按环从内向外扫描
	for radius in range(1, vision_range + 1):
		for hex in HexMath.axial_ring(origin, radius):
			# 检查是否被之前的格子阻挡
			var is_blocked := false
			var line := HexMath.axial_line(origin, hex)
			
			for i in range(1, line.size() - 1):
				if line[i] in blocked:
					is_blocked = true
					break
			
			if not is_blocked:
				visible[hex] = true
				if blocks_vision.call(hex):
					blocked[hex] = true
	
	var result: Array[Vector2i] = []
	for coord in visible.keys():
		result.append(coord)
	return result


# ========== 射线投射 ==========

## 射线投射，返回第一个阻挡的格子
##
## @param origin: 起点
## @param direction: 方向 (0-5)
## @param max_distance: 最大距离
## @param blocks_ray: 判断格子是否阻挡射线的回调
## @return: 第一个阻挡的格子，如果没有则返回 null
static func raycast(
	origin: Vector2i,
	direction: int,
	max_distance: int,
	blocks_ray: Callable
) -> Variant:
	var current := origin
	
	for i in range(max_distance):
		current = HexMath.axial_neighbor(current, direction)
		if blocks_ray.call(current):
			return current
	
	return null


## 射线投射到目标，返回路径上第一个阻挡的格子
static func raycast_to(
	origin: Vector2i,
	target: Vector2i,
	blocks_ray: Callable
) -> Variant:
	var line := HexMath.axial_line(origin, target)
	
	for i in range(1, line.size()):
		if blocks_ray.call(line[i]):
			return line[i]
	
	return null


# ========== 洪水填充 ==========

## 洪水填充，找到所有连通的格子
##
## @param start: 起点
## @param is_same_region: 判断格子是否属于同一区域的回调
## @param max_size: 最大区域大小 (防止无限扩展)
## @return: 所有连通的格子
static func flood_fill(
	start: Vector2i,
	is_same_region: Callable,
	max_size: int = 10000
) -> Array[Vector2i]:
	if not is_same_region.call(start):
		return []
	
	var visited: Dictionary = { start: true }
	var frontier: Array[Vector2i] = [start]
	var result: Array[Vector2i] = [start]
	
	while not frontier.is_empty() and result.size() < max_size:
		var current := frontier.pop_front()
		
		for neighbor in HexMath.axial_neighbors(current):
			if neighbor not in visited and is_same_region.call(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)
				result.append(neighbor)
	
	return result
