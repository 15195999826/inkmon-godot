# Into the Breach — Raw Mechanics Data

> 数据源：Fandom Wiki（intothebreach.fandom.com，通过 WebSearch 抽取）、gamepressure.com、Steam Community Guides、dualshockers、celjaded.com
> 抓取日期：2026-04-18
> 说明：Fandom 的 WebFetch 被站点侧 403 拦截，主要字段通过搜索 snippet + gamepressure / Steam guide 的 WebFetch 间接抽取。数值以官方 wiki 为准，拿不到完整数值的条目明确标 `(wiki 未提供)`。
> 覆盖范围：基础版 + Advanced Edition (AE) 全部内容。

---

## 0. 核心系统速览

### 回合流程（Players → Vek）
- 每关地图为 8x8 hex-like 方格，实际是正交方格（非 hex）。
- 每回合玩家先动：3 机甲各可移动 + 使用武器/能力。
- Vek 先"宣告"下回合攻击（attack markers 显示在地图），玩家可通过推、拉、冻结、击杀、改变方向等方式"破局"。
- 目标：保护 power grid（建筑物血条），grid 归零 = 时间线失败，撤回 1 名 pilot 进入下一时间线。

### 战斗核心资源
- **Reactor Core**：全局升级货币，用于武器加点和机甲 HP/Move 升级。
- **Power Grid**：全局 HP（跨 missions 共用），建筑物受伤扣 grid。
- **Rep (Reputation)**：岛 2 后的通关货币，买武器 / core / pilots。
- **Corporation Funds**：通关 mission 内 objective 给的金币 + reputation。

### 伤害 / 推 / 其他修饰符（来源 Fandom "Abilities and status effects"、Steam 环境指南）
- **Push (击退)**：把目标推 1 格；若被推目标后面有单位，双方各受 1 点碰撞伤害。
- **Pull (拉)**：相反方向。
- **Damage**：直接扣血，建筑物 / Vek / Mech 通用。
- **Bump Damage (碰撞伤害)**：push/pull 进入堵塞时 1 点。

### 状态 / Trait

| 名称 | 规则 |
|---|---|
| Shield | 吸收一次非致死伤害，并在持续时挡住 status effect（fire/acid/web/smoke 不生效） |
| Armored | 所有受到的武器伤害 -1（最低 0） |
| Flying | 可站在任意非山脉/非单位格；冰冻会取消 flying |
| Massive | 可走水，但站水里不能射击 |
| Stable | 不受任何推/拉/传送/击飞等位移效果影响 |
| Boost (Boosted) | 下一次攻击 +1 伤害（对所有目标包括自伤生效）；施放任何技能（含无伤动作、repair）后移除；Boosted 状态 repair 时 +2 HP |
| Frozen (冰冻) | 本回合不能行动 / 不能攻击；再次冻结前被打断过，之后仍然是冻结；飞行单位冻结后变地面；被冻结单位的攻击被中断（即使同回合解冻也不恢复） |
| Webbed | 下回合无法移动，仍可攻击 |
| Fire (着火) | 每回合开始时受 1 伤；flying 在火格回合结束时也会被点燃；建筑不吃火伤 |
| A.C.I.D. | 受到的武器伤害翻倍（与 shield 互斥，acid 会剥掉 shield / Psion armor buff）；踩水会把水变 A.C.I.D. 池 |
| Smoke | 该格单位**不能攻击也不能 repair**；Rusting Hulks "Storm Generator" 下每回合还 1 伤 |

### 地形 (来源 gamepressure "Combat Mechanics"、Steam "Environmental Interactions")

| 地形 | 效果 |
|---|---|
| Forest (森林) | 被攻击 / 着火源接触 → 变火格 |
| Sand (沙) | 被攻击 → 变 Smoke（沙漠岛特有） |
| Ice (冰) | 可站立；被攻击 1 次 → 变水；再被攻击 → 变 cracked chasm；对水施冷冻 → 变 ice |
| Water (水) | 推 non-massive/non-flying 单位入水 = 即死；Mech 推入水只是失能（后续 repair 恢复）但武器会失效 |
| Chasm (深渊) | 推 non-flying 入深渊 = 即死 |
| A.C.I.D. Pool (酸池) | 踩入 → 获得 A.C.I.D. 状态 |
| Lava (熔岩) | 同水的即死效果，并且给活下来的单位（flying）上火 |
| Mountain (山脉) | 阻挡移动和攻击，2 次攻击 → Damaged Mountain → 1 次 → 空地 |
| Cracked tile (裂缝地) | Cataclysm 队的 Drill Mech 制造；再受任何伤害 → 坍塌成 chasm |
| Conveyor (传送带) | 每回合回合末把格内单位推 1 格沿传送带方向 |
| Tentacles (触手格) | 回合结束时，触手格子里的单位即死（Volcanic Hive 二阶段） |

### Map Events (环境事件，随机 mission 修饰符)

- **Air Strike**：指定几格，下回合开始时摧毁这些格子的单位（即死）。
- **High Tide (Tidal Wave)**：下回合整列变水。
- **Ice Storm**：下回合一个 3x3 区域全部冻结。
- **Lightning Storm**：每回合随机几格闪电，打到 → 即死。
- **Seismic Activity**：标记格下回合变 chasm。
- **Falling Rocks**：标记格下回合砸落 1 点伤害。
- **Volcanic Projectiles**：火山岛环境事件，落点即死 + 火。
- **Old Earth Mines (古地球雷)**：踩上 → 即死；地图固有。
- **Cave-Ins / Tentacles** (Volcanic Hive)：与 Falling Rocks 类似，固定机制。

---

## 1. Squads / Mechs

> 每个 squad 有 3 台 mech，每台有 1 把起手武器。武器可 reactor core 升级；升级数值若 wiki 原页面未给可能留白。
> 所有基础数据源：gamepressure "Units" 页 + Steam "Know your Breach" squad 总结 + Fandom 单页 snippet。

### 1.1 Rift Walkers（基础/教学队）
**Squad Passive**：无（纯基础阵容，强在多面击退）
- **Combat Mech**（Prime, HP 3, Move 3）— **Titan Fist**：近战 1 格，2 伤害，击退 1 格。
  - Upgrade 1：Dash Punch（2 core）— 可冲刺任意距离再打击
  - Upgrade 2：+2 Damage（3 core）— 总计 4 伤害
- **Cannon Mech**（Brute, HP 3, Move 3）— **Taurus Cannon**：直线无限距离，命中第一格 1 伤害 + 击退 1 格。
  - Upgrade：+2 Damage / +1 Building friendly（wiki 未提供精确 core 成本）
- **Artillery Mech**（Ranged, HP 2, Move 3）— **Artemis Artillery**：抛物线，选定格 1 伤害并推向四邻格。
  - Upgrade 1：Building Safety（1 core）— 不伤友方建筑
  - Upgrade 2：+1 Damage（wiki 未提供精确 core）

### 1.2 Rusting Hulks（烟雾伤害队）
**Squad Passive / Passive Item**：**Storm Generator** — 所有 smoke 格子每回合对内部单位造成 1 伤害（不伤 mech）。
- **Jet Mech**（Brute, HP 2, Move 4, Flying）— **Aerial Bombs**：跳过目标格，沿途每格放 smoke，起跳/落点相邻格造 1 伤害。
- **Rocket Mech**（Ranged, HP 3, Move 3）— **Rocket Artillery**：抛射火箭 2 伤害，击退 1 格，并在火箭尾部后方 1 格产生 smoke。
- **Pulse Mech**（Science, HP 3, Move 4）— **Repulse**：推开所有四邻单位 1 格（无伤害）。

### 1.3 Zenith Guard（高伤单点队）
**Squad Passive**：无特殊（强在纯伤害）
- **Laser Mech**（Prime, HP 3, Move 3）— **Burst Beam**：直线激光穿透，第 1 格 3 伤害，第 2 格 2，第 3 格 1（穿透递减，点空白也能穿墙）。
- **Charge Mech**（Brute, HP 3, Move 3）— **Ramming Engines**：冲刺任意距离撞击，对目标 2 伤害，击退 1 格；撞到墙/山/water 会自伤 1。
- **Defense Mech**（Science, HP 2, Move 4）— **Shield Projector**：远程给任意单位（含友方/建筑/敌方）上 shield；起手 2 uses per battle。

### 1.4 Blitzkrieg（闪电连锁队）
**Squad Passive**：闪电/链式武器相关（具体装备加成 wiki 未明示）
- **Lightning Mech**（Prime, HP 3, Move 3）— **Electric Whip**：近战 2 伤害；**连锁到相邻所有占格单位（含友军）**；电流走导电体（building 也会"跳"穿）。
- **Hook Mech**（Brute, HP 3, Move 3, Armored）— **Grappling Hook**：直线抛出 grapple，拉目标/自身（撞墙就拉自己去），不伤害。
- **Boulder Mech**（Ranged, HP 2, Move 4）— **Rock Accelerator**：直线抛石头，命中第一格 2 伤害 + 把目标沿直线再推 1 格（推走而非砸回）。

### 1.5 Steel Judoka（位移友伤队）
**Squad Passive**：相关于 Vek 互相伤害放大（Vek Hormones，见 Gravity Mech）
- **Judo Mech**（Prime, HP 3, Move 4, Armored）— **Vice Fist**：抓住相邻目标，甩到自己身后，1 伤害。
- **Siege Mech**（Ranged, HP 2, Move 3）— **Cluster Artillery**：抛物线射到目标格，对四邻 1 伤害 + 击退（中心格不伤）。
- **Gravity Mech**（Science, HP 3, Move 4）— **Gravity Well**：选定任意格，把格内单位向 Gravity Mech 方向拉 1 格（无伤害）。Mech 身上带 **Vek Hormones** passive item：Vek 互相攻击时 +1 伤害。

### 1.6 Flame Behemoths（火焰队）
**Squad Passive**：**Flame Shielding** — 全队免疫 fire status。
- **Flame Mech**（Prime, HP 3, Move 3）— **Flame Thrower**：直线 2 格火焰，推 1 格 + 2 伤害 + 目标格变 fire tile。
- **Meteor Mech**（Ranged, HP 3, Move 3）— **Vulcan Artillery**：抛射火焰弹到目标格，目标 0 伤害但点火（fire tile），并击退四邻。（注：原描述"1 伤害 + 推"——wiki snippet 有冲突，保守以 gamepressure 1 伤害为准）
- **Swap Mech**（Science, HP 2, Move 4）— **Teleporter**：远程把 Swap Mech 和目标格内单位交换位置（含敌方/友方/建筑）。

### 1.7 Frozen Titans（冰冻队）
**Squad Passive**：无特殊 passive（强在冰冻各种东西）
- **Aegis Mech**（Prime, HP 3, Move 4）— **Spartan Shield**：近战 2 伤害 + 把目标的下回合攻击方向**反转 180°**。
- **Mirror Mech**（Brute, HP 3, Move 3）— **Janus Cannon**：前后两方向同时射出，各 1 伤害（强制双向）。
- **Ice Mech**（Ranged, HP 2, Move 3）— **Cryo-Launcher**：抛物线冷冻弹，目标格被冻结；**自己也被冻结**。

### 1.8 Hazardous Mechs（自伤/高产队）
**Squad Passive**：**Viscera Nanobots** — 机甲对敌造成最后一击时自身回 1 HP。
- **Leap Mech**（Prime, HP 5, Move 4）— **Hydraulic Legs**：跳到 4 格内任意空格，对四邻 1 伤害 + 对自己 1 伤害。
- **Unstable Mech**（Brute, HP 3, Move 3）— **Unstable Cannon**：远程 2 伤害，击退 1 格；发射后自己被反推 1 格 + 1 自伤。
- **Nano Mech**（Science, HP 2, Move 4）— **A.C.I.D. Projector**：远程投掷 A.C.I.D.，击退 + 给目标 A.C.I.D. 状态（下次受伤 x2）。

### 1.9 Secret Squad（赛博格 Cyborg 三虫机甲）
**Squad Passive**：三机甲均为 Cyborg 类；所有非 Cyborg 武器需要额外 1 reactor core 才能装。解锁需 25 金币（8 squads 全通后）。
- **Techno-Hornet**（Cyborg, 飞行）— **Needle Shot**：直线射出针，命中第一格 1 伤害，推 1 格。
- **Techno-Scarab**（Cyborg）— **Explosive Goo**：抛物线，目标格 1 伤害，目标周边也被 splash，产生击退。
- **Techno-Beetle**（Cyborg）— 起手武器为类似 beetle charge（冲撞），具体名 wiki 未明示（Beetle Charge 同族名），推目标 + 1 伤害。

### 1.10 Arachnophiles (AE 新)
**Squad Passive**：Arachnoid Injector 的 KO 效果会在击杀格生成 1 只 Arachnoid（友军小单位，下回合可牺牲冲撞）。
- **Bulk Mech**（Brute, HP 3）— **Ricochet Rocket**：直线射导弹，撞到目标后 L 型折射命中第二目标，推动。
- **Arachnoid Mech**（Ranged）— **Arachnoid Injector**：抛物线投射，造成伤害；**KO 效果：击杀时在格生成一只 Arachnoid**（spider bot 1 HP，近战 1 伤害）。
- **Slide Mech**（Science）— 具体武器名 wiki 未提供完整数据（snippet 只确认 Science class）。

### 1.11 Bombermechs (AE 新)
**Squad Passive**：无独立 passive，靠 walking bombs 合作。
- **Pierce Mech**（Ranged, HP 2-3）— **AP Cannon**：直线 2 伤害，**推第一目标** + **伤害第二目标**（穿透机制）。
- **Bombling Mech**（Ranged）— **Bombling Deployer**：远程投放"Bombling"（长脚小狗样小炸弹单位），Bombling 独立行动，被推/被撞 → 爆炸伤害周围。
- **Exchange Mech**（Science）— **Exchange Shot**：远程把任意两格的单位互相交换位置（含敌我）。

### 1.12 Cataclysm (AE 新)
**Squad Passive**：**Cracked tiles** 机制 — Drill Mech 击杀 Vek 时在该格产生"cracked tile"，任何后续伤害 → 地面坍塌成 chasm → 格内 non-flying 单位即死。
- **Pitcher Mech**（Prime）— **Hydraulic Lifter**：近战抓起目标向前抛出，落地时 1 伤害，无推；最适合扔到 cracked tile 上触发坍塌秒杀。
- **Triptych Mech**（Ranged）— **Tri-Rocket**：直线发射 3 枚导弹成一列，推目标；可以一次把最多两个 cracked tile 炸成 chasm。
- **Drill Mech**（Brute）— **Drill Smash**：近战攻击，击杀 Vek 时在该格产生 cracked tile。

### 1.13 Heat Sinkers (AE 新)
**Squad Passive**：**Heat Engines** — 机甲进入 fire tile 时**消耗该 fire 并获得 Boost 状态**（下一次攻击 +1 伤害）。
- **Dispersal Mech**（Brute）— **Thermal Discharger**：直线 2 格伤害 + 把第一格侧向两格推走（T 字型影响）。
- **Quick-Fire Mech**（Ranged）— **Quick-Fire Rockets**：强制双向 2 导弹，但**可自由选择第 2 发方向**（比 Mirror Mech 灵活）。
- **Napalm Mech**（Prime）— **Firestorm Generator**：产生 fire tile 设伏，自己/友军踩上后吃 Heat Engines boost。

### 1.14 Mist Eaters (AE 新)
**Squad Passive**：**Nanofilter Mending** — 机甲踩进 smoke 格 → 消耗该 smoke + 回 1 HP。
- **Thruster Mech**（Brute）— **Reverse Thrusters**：冲刺离开+留 smoke 在目标格；伤害随冲刺距离递增（最多 2）；自伤 1。起手 2 tile range。
- **Smog Mech**（Ranged）— **Smoldering Shells**：范围造 smoke + 伤害（具体 wiki snippet 只说混伤害+控场）。
- **Control Mech**（Science）— **Control Shot**：远程，强制目标 Vek 移动 1 格（可用来让 Vek 互相攻击或走到你想要的位置）。

---

## 2. Weapons（武器池）

> Fandom "Weapons" 页有 97 条武器条目（Talk:Weapons 明示），其中 base game 约 50+ 条，AE 新增 40。以下按 class 分类列出已从 wiki snippet / fetchable page 明确抽取到的条目，**不完整的地方标注 wiki 未提供**。
>
> 通用规则：每把武器 1~2 个 upgrade（reactor core 成本各 1~3），也有少数 single-use / limited-use（battle 级一次性）。

### 2.1 Prime Class（Prime-only）
基础武器只能装在 Prime 级机甲。

- **Titan Fist**（Combat Mech starter）— 近战 1 格 2 伤 + 推 1；Upgrade: Dash Punch (2c, 冲刺) / +2 Damage (3c)
- **Burst Beam**（Laser Mech starter）— 直线穿透激光，命中递减 3/2/1（wiki 标 "1-3 Damage"）；Upgrade: +1 Damage / +2 Damage
- **Vice Fist**（Judo Mech starter）— 抓取相邻 + 甩到身后 + 1 伤
- **Electric Whip**（Lightning Mech starter）— 近战 2 伤，连锁相邻所有单位（含友军），沿导电体跳跃
- **Flame Thrower**（Flame Mech starter）— 直线 2 格 fire tile + 2 伤 + 推
- **Spartan Shield**（Aegis Mech starter）— 近战 2 伤 + 翻转目标攻击方向
- **Hydraulic Legs**（Leap Mech starter）— 跳 4 格内空格，四邻 1 伤 + 自伤 1
- **Hydraulic Lifter**（Pitcher Mech, AE）— 近战抛投目标，落地 1 伤
- **Firestorm Generator**（Napalm Mech, AE）— 创建 fire tile 区域
- **Prime Spear** — 直线穿刺多格 2 伤 + 推最远格；起手 range 2 tile；Upgrade: A.C.I.D. Tip / +1 Range
- **Prime Punch** — 近战 3 伤 + 推 1；Upgrade 未明示
- **Titanite Blade** — 大剑 2 伤 + 推 3 格（wiki 标 "push 3 tiles"）；*single-use per battle*（+Conservative 升级后 +1 use）
- **Fissure Fist** — 高伤近战（AE），*single-use per battle*
- **Mercury Fist** — 砸地，4 伤 + 推所有相邻（wiki snippet）
- **Prime Axiom** / **Prime Slash** — 其余 Prime 类 wiki 未确认（搜索 snippet 显示未找到这些名字，**(wiki 未提供)** 或为非官方名）

### 2.2 Brute Class

- **Taurus Cannon**（Cannon Mech starter）— 直线 1 伤 + 推
- **Ramming Engines**（Charge Mech starter）— 冲刺撞击 2 伤 + 撞墙自伤
- **Aerial Bombs**（Jet Mech starter）— 飞越目标投 smoke + 1 伤沿途
- **Grappling Hook**（Hook Mech starter）— 拉单位到自己身边 / 拉自己去墙
- **Janus Cannon**（Mirror Mech starter）— 前后同时射 1 伤
- **Unstable Cannon**（Unstable Mech starter）— 远程 2 伤 + 推 + 自伤 1 + 反推自己
- **Thermal Discharger**（Dispersal Mech, AE）— T 字型伤害 + 推
- **Drill Smash**（Drill Mech, AE）— 近战攻击，击杀 Vek 产 cracked tile
- **Reverse Thrusters**（Thruster Mech, AE）— 冲刺 + smoke + 自伤 1
- **Rocket Fist** — 远程发射拳头 + 冲击；Upgrade: Launch (1c, 降成本) / +2 Damage (3c)
- **Explosive Vents** — 四邻 1 伤 + AE 后变成"造成伤害后跳 2 格"；
- **Dual Saws** (wiki 未提供具体效果)
- **Ramming Speed** / **Shrapnel Cannon** / **Heavy Artillery** 等名字在搜索返回但具体 snippet 不全，**(wiki 未提供完整数据)**

### 2.3 Ranged Class

- **Artemis Artillery**（Artillery Mech starter）— 抛物线 1 伤 + 四邻推；Upgrade: Building Safety (1c) / +1 Damage
- **Rocket Artillery**（Rocket Mech starter）— 2 伤 + 推 + 尾部 smoke
- **Cluster Artillery**（Siege Mech starter）— 抛射 → 四邻 1 伤 + 推（中心格安全）
- **Rock Accelerator**（Boulder Mech starter）— 直线石头 2 伤 + 推
- **Cryo-Launcher**（Ice Mech starter）— 抛射 → 目标冰冻 + 自身冰冻
- **Vulcan Artillery**（Meteor Mech starter）— 抛射 → 目标火 + 四邻推
- **Tri-Rocket**（Triptych Mech, AE）— 3 发平行导弹 + 推
- **Ricochet Rocket**（Bulk Mech, AE）— 导弹 L 型折射，命中两目标
- **AP Cannon**（Pierce Mech, AE）— 直线 2 伤：推第一 + 打第二
- **Arachnoid Injector**（Arachnoid Mech, AE）— 抛射伤害，KO 生成 Arachnoid
- **Quick-Fire Rockets**（Quick-Fire Mech, AE）— 强制双射，第 2 发方向自选
- **Bombling Deployer**（Bombling Mech, AE）— 远程部署 Bombling 小单位
- **Missile Barrage** — 单次使用，全图每个敌人都命中（*single-use per battle*）
- **Heavy Rocket** — 远程 3 伤 + 推（wiki 未提供完整 upgrade）
- **Shrapnel Cannon** — 直线霰弹
- **Rail Cannon** / **Rail Gun** — 高伤狙击（**(wiki 未提供具体数值)**）

### 2.4 Science Class

- **Shield Projector**（Defense Mech starter）— 远程给目标 shield，starts 2 uses per battle
- **Repulse**（Pulse Mech starter）— 四邻推 1，无伤
- **Gravity Well**（Gravity Mech starter）— 远程拉 1 格
- **Teleporter**（Swap Mech starter）— Mech 与目标格互换位置
- **A.C.I.D. Projector**（Nano Mech starter）— 远程 A.C.I.D. + 推
- **Exchange Shot**（Exchange Mech, AE）— 远程互换两格单位
- **Control Shot**（Control Mech, AE）— 远程强制 Vek 移动 1 格
- **Tele-Shot** / **Attraction Pulse** / **Wind Torrent** — 官方存在但 wiki 条目没全抓到：
  - **Attraction Pulse**：直线拉 1 格（Defense Mech 过去的变种，或 Vek Attractor 同族）
  - **Wind Torrent**：把一行/一列所有单位沿固定方向推
  - **Tele-Shot**：开一个远程传送门类
  - **(具体数值 wiki 未明确抓取)**
- **Frost Beam** — 直线冷冻一列单位（AE）
- **Refractor Laser** (AE) — 可折射的激光，周边附带伤害 + 穿透；rep reward / Time Pod 限定

### 2.5 Any Class（任何机甲均可装）

- **Vek Hormones**（Steel Judoka 初始 passive item）— Vek 对 Vek 攻击 +1 伤害
- **Storm Generator**（Rusting Hulks 初始 passive item）— Smoke 每回合对内部单位 1 伤
- **Viscera Nanobots**（Hazardous Mechs 初始 passive item）— 机甲最后一击回 1 HP
- **Flame Shielding**（Flame Behemoths 初始 passive item）— 全队免疫 fire
- **Heat Engines**（Heat Sinkers 初始 passive item, AE）— 机甲吃 fire → boost
- **Nanofilter Mending**（Mist Eaters 初始 passive item, AE）— 机甲吃 smoke → +1 HP

### 2.6 Cyborg Class（Secret Squad 专属）
非 Cyborg 武器装备需要 +1 reactor core。

- **Needle Shot**（Techno-Hornet starter）— 直线 1 伤 + 推最远格
- **Explosive Goo**（Techno-Scarab starter）— 抛射 1 伤 + 溅射 + 推
- Techno-Beetle starter weapon — wiki 未提供官方名（可能为 "Beetle Leap" / "Explosive Vents" 变种，**(wiki 未提供精确名)**）

### 2.7 Single-Use / Special
- **Missile Barrage** — 全图每敌人 1 伤害，battle 一次
- **Titanite Blade** — Prime 近战高伤，battle 一次
- **Fissure Fist** (AE) — Prime 高伤，battle 一次
- **Alpha Strike / Bomblet** 等 wiki 部分条目未能明确抓取

---

## 3. Vek / Enemies

> Vek 每种都有 3 个等级：**Base / Alpha / Leader**（leader 只在 boss mission 出现）。
> 每个 Tier (1 / 2 / 1-Advanced / 2-Advanced) 在不同岛屿池出现。

### 3.1 Tier 1（基础岛 Vek）

- **Firefly**（HP 3 / A:5 / L:6，Move 2 / 2 / 3，DMG 1 / 3 / 4）
  - 直线远程抛射，**命中路径上第一个物体**；Leader 同时向反方向射
- **Hornet**（HP 2 / 4 / 6，Move 5 / 5 / 3，DMG 1 / 2 / 2）
  - Flying；近战攻击；Alpha / Leader 射程更远（单次多格穿透）
  - 无视障碍 / 地形
- **Leaper**（HP 1 / 3 / —，Move 4 / 4 / —，DMG 3 / 5 / —）
  - 跳跃到目标 + 近战 + 给目标 **Webbed**
- **Scarab**（HP 2 / 4 / 6，Move 3 / 3 / 3，DMG 1 / 3 / 4）
  - 抛物线远程，**无视遮挡**；Leader 在 AE 中增加击退
- **Scorpion**（HP 3 / 5 / 7，Move 3 / 3 / 3，DMG 1 / 3 / 2）
  - 近战；攻击前给目标 Webbed；Leader 4 方向同时 + web + push

### 3.2 Tier 2（中后期 Vek）

- **Beetle**（HP 4 / 5 / 6，Move 2 / 2 / 3，DMG 1 / 3 / 3）
  - 直线冲撞 + 推；Leader 冲撞路径放火
- **Blobber**（HP 3 / 4 / 5，Move 2 / 2 / 2，DMG 1 / 3 / 1）
  - 放置 1 HP 炸弹，炸弹下回合炸四邻 1 伤；Leader 放 2 HP 炸弹（AE 限定）
- **Burrower**（HP 3 / 5 / —，Move 4 / 4 / —，DMG 1 / 2 / —）
  - 3 格直线同时攻击；**免疫 push**；受任何伤害取消攻击；可钻地瞬移
- **Centipede**（HP 3 / 5 / 7，Move 2 / 2 / 3，DMG 1 / 2 / 3）
  - 直线 3 格伤害 + 给目标 A.C.I.D.；Leader 对走过的每格 + 命中的格都加 A.C.I.D.
- **Crab**（HP 3 / 5 / 6，Move 3 / 3 / 3，DMG 1 / 3 / 2）
  - 远程；一次打两格直线；Leader 打从自己到目标的所有格（AE）
- **Digger**（HP 2 / 4 / —，Move 3 / 3 / —，DMG 1 / 2 / —）
  - 先在四邻空格制造 rock（阻挡 non-flying），然后攻击四邻
- **Spider**（HP 2 / 4 / 6，Move 2 / 2 / 2，DMG 1 / 1 / 1 per spiderling）
  - 抛出 Spiderling Egg：egg 给四邻 webbed，下回合孵化成 Spiderling；Spiderling 1 HP，近战攻击
  - Leader 跳跃 + 扔 2~3 egg，不带 web

### 3.3 Tier 1 Advanced (AE)

- **Bouncer**（HP 3 / 5 / 4，Move 5 / 3 / 3，DMG 1 / 3 / 2）
  - 近战；推目标 + 推自己后退；Leader 自带 armor + 打 3 个垂直方向
- **Gastropod**（HP 3 / 4 / 6，Move 2 / 3 / 3，DMG 1 / 3 / 3）
  - **无限距离拉钩**：拉目标或拉自己（若目标 stable）；Leader 同时在四邻放火
- **Mosquito**（HP 2 / 4 / 5，Move 4 / 4 / 4，DMG 1 / 3 / 9999）
  - Flying；近战；落点格产生 **Smoke**
  - **Leader 9999 伤害（即死）** + smoke + web
- **Moth**（HP 3 / 5 / —，Move 3 / 3 / —，DMG 1 / 3 / —）
  - Flying；类似 Scarab 远程抛射，但**攻击推自身 + 推目标**

### 3.4 Tier 2 Advanced (AE)

- **Plasmodia**（HP 3 / 5 / 5，Move 2 / 2 / 2，DMG 1 / 3 / 2）
  - 放 1 HP 孢子单次射击，有击退；Leader 放 2 HP 孢子
- **Starfish**（HP 2 / 4 / 6，Move 3 / 3 / 3，DMG 1 / 2 / 3）
  - 4 斜向攻击（diagonal，X 型）；Leader 四邻还 push
- **Tumblebug**（HP 3 / 5 / 6，Move 3 / 3 / 3，DMG 1 / 3 / 3）
  - 攻击同时在随机四邻格子生成 explosive rock（爆炸伤害 1 四邻）；Leader 造 2 块

### 3.5 Psions（每关至多 1 只，死一次就清场）

**通用**：Psion 本体不攻击，但给**所有其他 Vek**持续 buff（不 buff 自己）。
Normal: HP 2, Move 2, Flying；Abomination (Leader): HP 5, Move 3, Flying。

- **Blast Psion** — Vek 攻击后四邻额外爆炸 1 伤
- **Blood Psion** — Vek 每回合回 1 HP
- **Shell Psion** — 所有 Vek 获得 armor（-1 伤害）
- **Soldier Psion** — 所有 Vek +1 攻击伤害
- **Psion Tyrant** (Volcanic Hive 终局) — 综合加成（具体 wiki 未全抓到）
- **Arachnid Psion** (AE) — 所有 Vek 攻击附 web
- **Raging Psion** (AE) — 所有 Vek 开场 boosted
- **Smoldering Psion** (AE) — 所有 Vek 死亡时留 fire tile

### 3.6 Boss / Unique

- **Large Goo**（HP 3, Move 3, DMG 4）— 死后分裂成 2 Medium Goo
- **Medium Goo**（HP 2, Move 3, DMG 4）— 死后分裂成 2 Small Goo
- **Small Goo**（HP 1, Move 3, DMG 4）
- **Volcanic Hive Cave-in / Tentacles**：触手格回合末即死（环境级 boss 机制）
- **Renfield Bomb**（Volcanic Hive 第二阶段队友）：HP 4，不爆炸；持续 5 回合完成 mission；被毁不立即失败但惩罚 +2 回合，重补一个

### 3.7 Pinnacle Robots（机械岛 mission 特殊敌人，可被 Vek 控制）

- **Basic Bots**：HP 1, Move 3；装备 Cannon / Artillery / Laser
- **Mech variants**：HP 同上，伤害大幅提升（wiki 未给精确数字）
- **Bot Leader**：HP 5-6, Move 3，带**每回合再生的 shield**，抛物线 artillery 攻击

---

## 4. Environment Hazards / Map Events

（第 0 节已给地形基本规则；此处合并 **event 级** 的地图修饰符 + 补充）

### 固定地形效果表
| Tile / Status | 触发 | 效果 |
|---|---|---|
| Fire | 被火系武器/熔岩/forest 着火 | 每回合开始时内部单位 1 伤；飞行单位回合末在火格也点燃；建筑免疫 |
| Smoke | Mist / Rocket / Jet Mech 等武器 | 格内单位不能攻击也不能 repair；Storm Generator 下 +1 伤/回合 |
| A.C.I.D. | Centipede 攻击 / A.C.I.D. 池 | 下次受伤 x2；剥 shield / psion armor；踩水变 acid 池 |
| Webbed | Leaper / Scorpion / Spider 攻击 | 下回合无法移动 |
| Frozen (status) | Cryo-Launcher / Ice Storm | 本回合不行动不攻击，再次被打断后仍冻；冰冻飞行 → 变地面 |
| Ice tile | 水被冻结 / 冬季岛 | 攻击 → 水；再攻击 → chasm |
| Water | 本就是水 / Tidal Wave | non-massive non-flying 推入即死 |
| Chasm | Seismic / 冰裂 / Cataclysm cracked 再伤 | non-flying 掉入即死 |
| Lava | 火山岛 | 同水即死；幸存 flying 点燃 |
| Mountain | 本就是山 | 阻挡；2 次攻击毁掉 → Damaged Mountain → 空地 |
| Forest | 温带/冻土岛 | 被火/爆炸 → 变 fire tile |
| Sand | 沙漠岛 | 被攻击 → smoke |
| Cracked tile | Cataclysm Drill | 再吃任何伤害 → chasm + 格内 non-flying 即死 |
| Conveyor | 工业岛 | 回合末沿方向推 1 格 |
| Tentacles (cave) | 火山 hive | 回合末格内单位即死 |
| Old Earth Mine | 某些地图固定 | 踩入/被推入 → 即死 |

### Random Map Events（mission 修饰符）
| 事件 | 规则 |
|---|---|
| Air Strike | 下回合几格被摧毁（即死） |
| Lightning Storm | 每回合随机几格标闪电 → 下回合 hit → 即死 |
| Ice Storm | 下回合 3x3 区域全体冻结 |
| Tidal Wave / High Tide | 下回合整列变水 |
| Seismic Activity | 下回合标记格变 chasm |
| Falling Rock | 下回合砸 1 伤害 |
| Volcanic Projectiles | 火山岛特有 → 即死 + 火 |
| Cave-in | Volcanic Hive 二阶段交替触手 |

---

## 5. Pilots

> 每个 pilot 有独立 **inherent skill**（自带被动），人类 / AI / Cyborg pilot 还能在 25 XP 和 +50 XP 各学 1 个随机 **learnable skill**，共 2 个。
> 基础版 + AE 列表。

### 5.1 Inherent（自带）Skills

| Pilot | 内部 ID | 自带技能 |
|---|---|---|
| Ralph Karlsson | Pilot_Original | 每击杀 +2 bonus XP；游戏开局默认 pilot |
| Harold Schmidt | Pilot_Repairman | Repair 时推所有四邻 1 格 |
| Abe Isamu | Pilot_Assassin | 机甲获得 Armored（-1 受伤） |
| Bethany Jones | Pilot_Genius | 每场 mission 开始自带 Shield |
| Henry Kwan | Pilot_Hotshot | 机甲可穿过敌方单位 |
| Gana | Pilot_Warrior | 可从地图任意格降落，落点四邻受 1 伤 |
| Prospero | Pilot_Recycler | 机甲获得 Flying（消耗 1 reactor core） |
| Lily Reed | Pilot_Youth | 每场 mission 第一回合 +3 Move |
| Chen Rong | Pilot_Leader | 攻击后 +1 免费移动格 |
| Camila Vera | Pilot_Soldier | 机甲免疫 Webbing 和 Smoke |
| Isaac Jones | Pilot_Medic | 每场 battle 多 1 次 Reset Turn |
| Silica | Pilot_Miner | 若机甲回合内不移动，可执行 2 次动作（attack twice） |
| Archimedes | Pilot_Aquatic | 开火后**可再移动一次** |
| Kazaaakpleth | Pilot_Mantis | 2 伤近战攻击**替代 Repair** 行动 |
| Mafan | Pilot_Zoltan | +1 Reactor Core；机甲 HP 固定为 1；每回合自动上 Shield |
| Ariadne | Pilot_Rock | +3 HP；免疫 Fire |
| Kai Miller (AE) | Pilot_Arrogant | 满血时机甲 Boosted；不满血 -1 Move |
| Rosie Rivets (AE) | Pilot_Caretaker | 每次 Move 后对相邻机甲 Repair |
| Morgan Lejeune (AE) | Pilot_Chemical | 每次击杀后机甲获得 Boosted |
| Adam (AE) | Pilot_Delusional | 使用 Reset Turn 后获得 Shield + 2 Move |

### 5.2 Learnable Skills（随 XP 增长随机习得）

| Skill | 效果 |
|---|---|
| Opener | 第一回合 Boost + 2 Move |
| Finisher | 最后回合 Boost + 2 Move |
| Popular Hero | 卖出获得 4 reputation |
| Thick Skin | 免疫 A.C.I.D. 和 Fire |
| Skilled | +1 Move, +2 Mech HP |
| Invulnerable | 机甲被击破后自身不死 |
| Adrenaline | 每杀 1 Vek 当场 +1 Move |
| Masochist | 不满血时 +2 Move |
| Technician | 每个 enemy turn 开始时 Repair 1 HP |
| Conservative | Limited-use 武器 +1 使用次数 |
| 其他 | Reliable 等搜索未确认为官方 skill，(wiki 未明确提供完整列表) |

### 5.3 Time Travelers（剧情/已不可用的特殊 Pilot）
游戏世界观上 Ralph 为"Time Traveler"可被带去下一时间线，其他 pilot 只能在当前时间线存在；具体叙事分类 wiki 未全部抓到 **(wiki 未完整提供)**。

---

## 6. Squad Passive / Team Items 总览

把第 1 节分散的 passive 汇总：

| Squad | Passive / 初始装备 |
|---|---|
| Rift Walkers | 无特殊（教学) |
| Rusting Hulks | Storm Generator：所有 smoke 每回合 1 伤 |
| Zenith Guard | 无独立 passive |
| Blitzkrieg | 无独立 passive（闪电链式为 Lightning Mech 武器属性） |
| Steel Judoka | Vek Hormones：Vek 对 Vek 攻击 +1 伤害 |
| Flame Behemoths | Flame Shielding：全队免疫 fire |
| Frozen Titans | 无独立 passive（冰冻由 Cryo-Launcher 等提供） |
| Hazardous Mechs | Viscera Nanobots：击杀回 1 HP |
| Secret Squad | Cyborg class：非 Cyborg 武器 +1 reactor core |
| Arachnophiles (AE) | Arachnoid Injector 的 KO 效果（生成 Arachnoid 小单位） |
| Bombermechs (AE) | 无独立 item，Bombling + Pierce + Exchange 协作 |
| Cataclysm (AE) | Cracked Tile 系统（Drill 击杀产 cracked，再伤触发坍塌） |
| Heat Sinkers (AE) | Heat Engines：机甲吃 fire → 消耗 fire + Boost |
| Mist Eaters (AE) | Nanofilter Mending：机甲吃 smoke → 消耗 smoke + 1 HP |

---

## 7. 缺失 / 疑问列表

以下在 Fandom 无法直接 fetch + snippet 不足的地方明确记录：

1. **Prime / Brute / Ranged / Science 的完整武器池**（Fandom 说 97 条目）：只抽到 ~50 条名字 + 起手武器效果，升级成本/数值**约一半未明确**。
2. **Vek "Leader 技能详细效果"**：基础 HP/DMG/Move 抓到，**特殊词条**（如 Leader Centipede 的 "every traveled tile"）部分模糊。
3. **Psion Tyrant 具体效果**：只知道综合 buff；精确组合 **(wiki 未提供)**。
4. **Techno-Beetle 起手武器名称**：**(wiki 未明确)**（Secret Squad 三个中只有 Techno-Hornet / Techno-Scarab 的武器名 snippet 清晰）。
5. **Pilot learnable skill 完整列表**：只抓到 10 条核心；AE 可能新增的 skill **(wiki 未完整提供)**。
6. **AE 40 新武器**：只识别了约 15 条具体条目，其余通过类别描述补全。
7. **Map Events 精细触发（哪些岛出哪些）**：未全部 cross-reference。

以上条目标注 `(wiki 未提供)` 或 `(具体数值 wiki 未明确)`。后续若要完整表格，建议直接拉 Fandom 的 Weapons 页 HTML（换 User-Agent 绕 403）或用 namu.wiki 韩文镜像交叉验证。
