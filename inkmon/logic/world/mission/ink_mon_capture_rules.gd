class_name InkMonCaptureRules
## 捕捉概率/掷点规则 (M2.3, Q2.1 气绝制): 纯 static 函数, 无状态。
##
## 概率 v1 极简 = 基础率 × 物种稀有度 (拍板公式); 稀有度当前无 lab 数据 → 占位全 1.0,
## 数据落 lab canon 后本处换读数, 公式形状不变。
## 掷点确定性: 每只气绝个体恰好一次投掷 → 结果按 (mission_seed, node_id, slot) hash 预定
## 与现场 randf 对玩家不可分辨 (单次尝试无重掷), 换来复跑/测试可断言。


const BASE_CAPTURE_RATE := 0.5


## 物种稀有度乘数 (v1 占位: lab 侧 rarity 数据未定, 全物种 1.0)。
static func rarity_multiplier(_species_id: String) -> float:
	return 1.0


## 捕捉成功率 = 基础率 × 稀有度, clamp [0,1]。
static func capture_chance(species_id: String) -> float:
	return clampf(BASE_CAPTURE_RATE * rarity_multiplier(species_id), 0.0, 1.0)


## 该个体的确定性掷点 [0,1): roll < capture_chance(species) ⇒ 捕获成功。
static func capture_roll(mission_seed: int, node_id: int, slot_index: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([mission_seed, node_id, slot_index])
	return rng.randf()
