---
name: game-architecture-patterns
description: 涉及游戏架构设计、系统边界划分、大型类重构、性能瓶颈优化、数据驱动设计、状态/行为建模时调用。务必在用户描述"这个类越来越大/想拆"、"性能掉帧/卡顿"、"新功能写在哪/接哪条线"、"想让策划配数据"、"撤销/重放/事件/调度"、"行为/状态有 N 种怎么表达"等架构相关场景下触发本 skill,即使用户没点名"设计模式"也要主动调用,按 19 章经典游戏模式简述给出候选并对照项目已有机制,不要凭训练语料里的模式名记忆即兴推荐。
---

# Game Architecture Patterns

游戏架构设计参考库,收录《Game Programming Patterns》(Bob Nystrom) 19 章经典模式简述。原文外链 gpp.tkchu.me,本文件自包含简述索引和推荐协议。

## 症状到候选模式速查

skill 已被加载意味着已经决定要用了,下表只负责把用户的具体症状路由到几个候选简述,不要把"19 章简述"里全部 19 条都扫一遍。

| 用户症状 | 候选模式(下面"19 章模式简述"里查这几条) |
|---|---|
| Actor/Entity 类越来越大 / 改一个字段牵连一堆地方 | component, observer, event-queue, service-locator |
| 几百个单位掉帧 / 每帧大量空间查询 / O(n²) 碰撞 | spatial-partition, data-locality, object-pool, dirty-flag |
| 新机制写在哪 / 接哪条线 / 要不要新起 System | component, event-queue, service-locator, type-object |
| 想让策划/JSON 配数据 / 不想每变体写代码 | type-object, bytecode, prototype |
| 敌人/AI 有 N 种状态或行为 | state, type-object, subclass-sandbox, bytecode |
| N 帧后触发 / 撤销/重放 / 延迟执行 | command, event-queue, update-method, game-loop |
| 频繁 new/free 卡 / 粒子/投射物太多 | object-pool, flyweight |
| 想优化 cache 命中 / SoA 布局 | data-locality, component |
| 渲染中间状态闪烁 / 物理交互顺序错乱 | double-buffer, dirty-flag |
| 跨系统反应耦合 / 直接 call 太多 | observer, event-queue, service-locator |
| 继承层次出现致命菱形 / 想自由组合能力 | component, type-object, prototype |
| 全局访问点滥用 / 单例污染 | singleton, service-locator |

## 推荐协议(关键,不要跳)

凡是要给架构建议,按这套流程走:

### Step 1 — 用症状匹配候选模式

扫下面 19 条简述。不要凭模式名第一印象,看清楚每条的"症状"栏 —— 用户问题用的是症状语言,不是模式名。挑 2-4 个候选,不要一次推 6+。

### Step 2 — 检查项目是否已有现成机制 ⚠️

**这是本 skill 最大价值,千万别跳。**

在推荐前,先 grep 项目主要 addon/lib 目录,确认现有架构是否已经实现了你想推荐的模式。常见落地形态:
- BuffSystem / StatusSystem → 通常已实现 Observer + Type Object 混合
- EventProcessor / EventBus / pre-post handler → Event Queue + Observer
- AttributeSet / StatSystem → Type Object
- Timeline / Action / Ability → Command + Type Object
- 自研 Grid / NavMesh / SpatialHash → Spatial Partition
- ObjectPool / ProjectilePool → Object Pool
- Resolver / Factory → Service Locator / Prototype

如果项目已有同职责系统,**优先建议复用,不要让用户造新的**。这是 LLM 默认不会做、但项目里最常踩的坑(凭训练语料推 "Component Pattern" 让用户重构 actor,实际项目已有 BuffSystem 能直接挂)。

找不到现成机制 → 在输出里显式说"项目未发现 X 系统,建议从下列模式新建"。

### Step 3 — 输出 chosen / rejected 对比

不要只给单一答案。最少包含:
- **chosen**: 选哪个 + 接现有系统的具体路径(文件/类/接入点)
- **rejected**: 哪些候选不选 + 一句话理由(避免用户后续追问"那 X 模式不行吗")
- **边界**: 哪些场景这个推荐会失效

### Step 4 — 必要时查阅原文

**默认不查原文**,简述够用。仅在下列情况点开简述末尾的外链 `https://gpp.tkchu.me/<name>.html`(可用 WebFetch 抓取):
- 需要 Bob Nystrom 书中的具体代码示例
- 讨论实现边界(多线程 / 内存 / 性能临界点)
- 用户追问书中具体段落
- 简述里 4 栏不足以下判断

原文 ~16-44KB/章,多章累加会爆 context,这步是按需,不是默认。

---

## 19 章模式简述

### 设计模式重访(Design Patterns Revisited)

#### Command 命令模式
- 意图: 把方法调用具现化为对象,让"执行什么"可被存储/传递/排队/撤销/重放/序列化
- 症状: 想让按键/操作可自由 rebind 不要 hardcode 函数调用; 想撤销/重放/序列化/网络同步玩家操作; AI 和玩家共享同一套行为接口; 想录制一段操作流以后回放
- 不用: 一次性方法调用无需具现化; 闭包/函数指针的语言里命令对象不优雅(直接传函数); **项目已有 Action / Ability / SkillExecution / Timeline keyframe 系统时优先复用,不要为每个新操作再造 Command 类**
- 组合: 配 Queue / Event Queue 做命令流(网络多人 / replay); 撤销重做时配 Memento 或持久数据结构存上一状态; 共享无状态命令时配 Flyweight(JumpCommand 不必每按一次实例化一份)
- 原文: https://gpp.tkchu.me/command.html

#### Flyweight 享元模式
- 意图: 把"上下文无关的"重复数据(网格/纹理/类型属性)抽到一个共享对象,实例只存"上下文相关的"少量字段
- 症状: 几千个对象大部分字段重复(树/瓦片/粒子/单位类型); 内存装不下/GPU 传输爆量; 列举枚举又想配数据想换 Class; 一类对象天然分"千个实例共享的属性"和"每实例独占的少量属性"
- 不用: 共享对象会被修改(享元几乎必须不可变); 对象本就少 / 字段本就轻; **项目已有 AttributeSet config / SkillResource / TextureAtlas / MeshInstance / TileSet 等共享资源机制时直接复用,不要为同一目的再造一层**
- 组合: 跟 Type Object 高度相似,Type Object 偏类型建模,Flyweight 偏内存节约; 配 Data Locality 让共享对象指针指向紧凑数组; 配 Object Pool 管享元生命周期
- 原文: https://gpp.tkchu.me/flyweight.html

#### Observer 观察者模式
- 意图: 让 subject 不知道谁在听的前提下广播事件,任意模块可注册成观察者收消息
- 症状: 物理/战斗代码里偷偷塞了成就/音效/UI/统计调用,改一处牵连一堆; 跨领域模块要解耦但又要互通(物理事件触发音效/UI 更新血条/成就解锁); 担心删除观察者忘了取消注册导致 listener 失效
- 不用: 同一关注点内部两块紧耦合代码间直接调用更清晰,别为了"解耦"硬上 Observer; 信息流难追踪会拖慢调试; **项目已有 Godot Signal / EventProcessor pre/post handler / EventBus 时直接用 emit/handler,不要再写一套 Subject/Observer 类**
- 组合: 异步化用 Event Queue 替代同步 notify(避免观察者阻塞 subject); 多观察者优先级链路时退化为 Chain of Responsibility; 现代写法用闭包/函数引用代替 Observer 接口类
- 原文: https://gpp.tkchu.me/observer.html

#### Prototype 原型模式
- 意图: 让对象能克隆自身产出同类同状态的新对象,从而不必为每种类型写工厂/子类
- 症状: 平行类层次(每个 Monster 子类都要配一个 MonsterSpawner 子类); 想由数据复制出"基本怪/精英怪/Boss 变体",只在少数字段上有区别; 同种实体的微调要避免重新写一份 JSON / class
- 不用: 类型本身就少,直接 new 就好; 深 vs 浅克隆边界容易踩坑; **项目已有 Resource.duplicate() / PackedScene.instantiate() / ScriptableObject 复制 / 数据驱动 prototype-field(基础哥布林 + 派生哥布林) 时优先复用,不要在代码层造 clone() 接口**
- 组合: 把"clone"思想搬到数据层 = 数据 prototype 委托(用 JSON 字段 `"prototype": "goblin grunt"`); 与 Type Object 思想接近,Prototype 强调克隆个体,Type Object 强调引用类型
- 原文: https://gpp.tkchu.me/prototype.html

#### Singleton 单例模式
- 意图: 保证一个类只有一个实例 + 全局可访问;这个模式本章重点其实是教你**怎么避免它**
- 症状: 想要文件系统/日志/音频引擎全局可拿,又懒得把它传到处都是; 担心多人意外创建多个实例打架; 旧代码到处 `XxxManager::instance()` 调链漫天飞
- 不用: 全局变量的所有问题它一个不少(理解难/促进耦合/对并行不友好/惰性初始化失控); 后期想拆多实例(多 Log 文件/多 World)时调用点全要改; **项目已有 Godot Autoload(Log/GameWorld/IdGenerator/...) 时直接用 autoload 全局名,不要在游戏代码里再写一层 `XxxSystem.instance()` 包装**
- 组合: 退化为静态类 / 普通类 + 传参; 大部分场景用 Service Locator 替代更灵活; 派生类用 Subclass Sandbox 基类提供静态/共享访问
- 原文: https://gpp.tkchu.me/singleton.html
> 备注: 与 Service Locator 重合度高,Service Locator 是更现代 / 更灵活的替代;真要全局访问优先考虑 Service Locator 或现成 autoload

#### State 状态模式
- 意图: 一个实体在内部状态变化时改变行为,把每个状态封装成对象/枚举/FSM 节点,状态转移显式化
- 症状: 一堆 isJumping/isDucking/isAttacking bool 字段互相打架出现非法组合; handleInput/update 里嵌套 if 检查多个 flag,加新动作就改一堆; 输入响应/动画/AI 行为随"角色现在在做什么"差异巨大; 想给状态加 entry/exit 行为(切贴图/重置计时器)
- 不用: 状态只有 2-3 个 bool 就够,别上 State 类; 状态机不够表达复杂 AI 时上 Behavior Tree / GOAP; **项目已有 AnimationStateMachine / FSM / BehaviorTree / Activity 系统时优先复用,不要自己滚一套 State 类层次**
- 组合: 多个独立维度的状态用并发状态机(动作 × 装备 = n+m 而不是 n×m); 状态共享父行为用层次状态机(子状态不处理 fallback 给父); 需要历史/返回上一态用下推自动机栈; 静态无字段状态用 Flyweight 单例共享
- 原文: https://gpp.tkchu.me/state.html

---

### 序列模式(Sequencing Patterns)

#### Double Buffer 双缓冲
- 意图: 用一对缓冲区让"被增量修改中的状态"对外永远看起来是原子完成的瞬时切换
- 症状: 渲染时屏幕出现撕裂/半绘制画面; 同一帧内多个对象互改状态导致"先更新者影响后更新者"(扇巴掌循环顺序敏感); 玩家应该觉得"所有单位同时移动",实际却受 update 顺序污染; 读到一半的状态被另一线程读走
- 不用: 内存严格受限装不下两份状态; swap 本身比修改还慢就得不偿失; 对象很少互相影响时 update 顺序无关紧要; **项目已有 GPU 渲染管线 swap chain / Godot 渲染服务器 / 物理 double-buffered transform 时不要为视觉再造一层**
- 组合: 配 Update Method 让对象逐帧更新但读写双缓冲解决顺序敏感问题; swap 用指针交换最快(代价:外部不能存永久指针 + 数据延迟一帧); 粒度可细到每对象 bool 字段也可粗到整张帧缓冲
- 原文: https://gpp.tkchu.me/double-buffer.html

#### Game Loop 游戏循环
- 意图: 把"游戏推进"与"玩家输入/硬件速度"解耦,无阻塞处理输入 + 固定速度推进世界 + 自适应帧率
- 症状: 游戏在快机上飞慢机上爬; 每帧抖动不一致导致物理飞天遁地; 游戏需要在等待输入时仍然让动画/音乐继续; 浏览器/移动设备耗电过快需要限帧
- 不用: 几乎没有"不用"的情况——所有游戏都需要; 但如果在引擎/浏览器/事件循环上,**项目已经在 Godot _process / _physics_process 上时直接用,不要在 GDScript 里再 while true 跑自己的 loop,会和引擎主循环冲突**
- 组合: 配 Update Method 让每个实体在 tick 内更新; 配 Double Buffer 让 update 与 render 解耦; 典型模式 = 固定 update timestep + 动态 render + lag 累积追赶(避免变化时间步带来的非确定性)
- 原文: https://gpp.tkchu.me/game-loop.html

#### Update Method 更新方法
- 意图: 每个对象暴露 update(dt) 由游戏循环每帧调用,把"对象自己每帧干什么"封装进对象本身
- 症状: 游戏循环里堆满了 if 是骷髅就这样 if 是雕像就那样的特化分支; 想加新实体类型要改 game loop; 每个实体的"巡逻方向/充能计时/AI 状态"散落在 loop 外的全局变量里
- 不用: 棋类等回合制非实时游戏不需要每帧 tick; 对象数量极大且行为高度同构时考虑 ECS/Data Locality 替代逐对象虚调用; **项目已有 Godot Node._process / Actor.tick / System.update 时直接用,不要再造一套 IUpdatable 接口轮询**
- 组合: 配 Game Loop 是天作之合(loop 调用 update); 多状态实体把 update 委托给当前 State 对象(状态模式); 组件系统里 update 应放在 Component 而不是 Entity 上; 遍历时增删对象要小心(缓存 count / 标记 dead 后清理)
- 原文: https://gpp.tkchu.me/update-method.html

---

### 行为模式(Behavioral Patterns)

#### Bytecode 字节码
- 意图: 自定义一套小指令集 + 栈式 VM,把行为存成数据让设计师/玩家在游戏外编写,运行时由 VM 解释执行
- 症状: 技能/法术/AI 规则改一行就要重编译整个游戏; 想让设计师/模组作者写行为又不能让他们碰引擎源码; 高层脚本(Lua)太重又怕 sandbox 失效; 有上百种法术规则差异巨大不可能硬编码
- 不用: 这是本书最重的模式不要轻易上; 少量配置直接走数据驱动 + Type Object 就够; **项目已有 GDScript / Lua / Resource 配置 / TimelineKeyframe 数据驱动系统时直接用现成脚本/数据,不要自己造 VM**; 字节码本身 debug 困难需要配套工具链
- 组合: 通常配 Type Object 让数据定义类型属性,配字节码定义类型行为; 前端工具(图形 UI / DSL 编译器)是配套必需品; 与 Interpreter 模式同源(VM 是 AST 的紧凑/线性化版本)
- 原文: https://gpp.tkchu.me/bytecode.html

#### Subclass Sandbox 子类沙箱
- 意图: 基类提供一组 protected 工具方法 + 一个抽象沙箱方法,子类只在沙箱方法里组合工具实现具体行为
- 症状: 大量子类(几十上百种 Skill / Power / Ability)都需要 playSound / spawnParticles / move 等通用操作; 子类各自直接 include 一堆引擎子系统造成耦合蛛网; 改音频/渲染接口要扫所有子类
- 不用: 子类只有几个不必上基类工具方法; 基类容易膨胀成上帝类需要警惕; **项目已有 Action / Condition / Cost / Ability 的 LGF 共享无状态对象时已是这模式的实例,直接复用基类提供的 helper 不要在子类里直接调底层引擎**
- 组合: Update Method 的 update() 本身常是沙箱方法; 基类需要的依赖通过构造参/两阶 init/static/Service Locator 注入; 若基类爆炸把工具拆到辅助类(SoundPlayer)走 Component 拆分; 反向是 Template Method(基类有主干子类填具体步骤)
- 原文: https://gpp.tkchu.me/subclass-sandbox.html

#### Type Object 类型对象
- 意图: 不让每种"类型"都对应一个 class,而是定义 Type 类把类型变成可在运行时配置的数据,实例持有 Type 引用
- 症状: 设计师每加一种怪/技能/装备就要程序员写新 class + 重编译; 大量子类只差几个数据字段(血量/攻击文本); 想从 JSON / Resource 读类型配置而不是 hardcode; 想让"类型"也支持继承(troll archer 继承 troll)
- 不用: 类型差异主要在**行为/算法**(不只是数据)时 Type Object 表达力不足,需要配字节码或函数指针; 类型本就只有 2-3 种; **项目已有 AttributeSet config / SkillResource / UnitData Resource / Godot Resource 数据驱动系统时直接用 .tres / JSON 加载,不要在代码里再写一层 BreedClass**
- 组合: 跟 Flyweight 重合(共享数据)但意图不同(Type Object 是建模 / Flyweight 是省内存); 跟 State 都委托但 Type Object 委托"是什么"State 委托"现在在做什么"; 加行为差异时配 Bytecode/Interpreter
- 原文: https://gpp.tkchu.me/type-object.html

---

### 解耦模式(Decoupling Patterns)

#### Component 组件模式
- 意图: 把跨多个领域(输入/物理/渲染/AI/音效)的巨型实体类按领域切独立组件,实体退化为组件容器
- 症状: Actor/Entity 类同时处理输入物理渲染 AI 音效改字段牵连一堆; 继承层次出现致命菱形; 想自由组合能力继承表达不出来
- 不用: 简单游戏 / 类只单一领域; **项目已有 BuffSystem/AttributeSet/AbilitySet 横切机制时新功能优先挂这些,不要造新 Component System**
- 组合: 配 Observer/Event Queue 解耦组件通信(避免组件直接持有彼此引用); 配 Data Locality 同类组件存连续内存(ECS 形态)
- 原文: https://gpp.tkchu.me/component.html

#### Event Queue 事件队列
- 意图: 把事件/消息按 FIFO 入队,解耦发出时刻和处理时刻,允许批合并/异步/跨线程消费
- 症状: playSound 同步阻塞调用者卡几帧; 同一帧多次相同请求需要合并(同声音叠加爆音/同伤害合并); 请求来自任意线程需要在单一目标线程消费; 想让事件迟点处理但 Observer 是同步的; 反馈环路: 处理事件时又发出事件
- 不用: 只想解耦发送者/接收者不需要时延用 Observer / Command 更轻; 需要同步回值的请求不适合队列; 中心 event bus 本质是全局变量,小范围内的领域队列就够; **项目已有 EventProcessor / Signal 系统 / Godot call_deferred 时优先复用,不要造新 event bus**
- 组合: 事件存"已发生" vs 消息存"想要发生"语义不同; 广播 vs 单播 vs 工作队列三种消费模式选一; 环形缓冲实现既快又对 cache 友好; 配 Object Pool 管理消息对象生命周期
- 原文: https://gpp.tkchu.me/event-queue.html

#### Service Locator 服务定位器
- 意图: 提供一个全局查询点,调用方按抽象接口拿到具体 service 实现,不耦合到 service 是怎么构造/在哪里的
- 症状: 音频/日志/输入这类全局服务又不想做成传统 Singleton; 想在测试时替换成 mock / null 实现; 想在运行时切换具体实现(在线 vs 离线 controller); 想给 service 加装饰器(LoggedAudio 包真 Audio)
- 不用: 仍然是全局变量的所有毛病(时序耦合/隐式依赖/可测性差); 能传参就别 locate; **项目已有 Godot Autoload(Log/GameWorld/IdGenerator)时它就是 Service Locator 的实现,直接用 autoload 名访问,不要在 GDScript 里再写一层 Locator 类**
- 组合: 配 Null Object 解决 service 未注册时返回 null 崩游戏(默认 null service 让调用方无需检查); 配 Decorator 包装日志/性能监控; 比 Singleton 更现代——基本等价但允许换实现
- 原文: https://gpp.tkchu.me/service-locator.html
> 备注: 与 Singleton 重合度高,Service Locator 是更现代的替代(允许换实现/null 兜底/装饰器); Godot Autoload 兼任两者的角色

---

### 优化模式(Optimization Patterns)

#### Data Locality 数据局部性
- 意图: 按 CPU 缓存友好方式组织数据(连续数组/SoA),让"处理顺序"和"内存顺序"一致以避免 cache miss
- 症状: 每帧遍历几千上万个对象但性能很差 profiler 显示 cache miss 高; OOP 设计里每个 Entity 持有 Component 指针,update 时到处追指针; 数据本身没变快但访问模式变烂; 粒子/单位/Tile 大量同类对象需要批量更新
- 不用: 对象数 < 几百性能不是瓶颈别上; 为优化牺牲抽象/继承/多态前先 profile 确认 cache miss 真的是问题; **项目已有 PackedArray / typed Array / ECS 框架 / UGridMap flat storage / Godot ServerAPI 时优先复用,不要为局部热点单独造 SoA**
- 组合: 与 Component 模式联用做 ECS(每种 Component 一条连续数组); 配 Object Pool 让同类对象在内存里挨着; 冷热分割(热字段 inline,冷字段指针外移); 粒子/敌人按 active 状态排序避免分支预测失败
- 原文: https://gpp.tkchu.me/data-locality.html

#### Dirty Flag 脏标识
- 意图: 用一位 bool 标记"派生数据是否过期",把昂贵的重算延迟到真正需要结果时再做,合并多次原始变更
- 症状: 场景图世界变换/物理 transform/UI 布局每帧重算但大多对象没动; 同一帧内父对象多次改 transform 子对象被多次冗余重算; 文档/状态需要同步到磁盘/服务器但每次改都写代价太大; 层级数据有缓存但缓存一致性难维护
- 不用: 增量更新更便宜时直接增量(战利品总重量直接加减比 dirty + 全部累加快); 延迟太久导致请求结果时一次性卡顿(自动保存掉电丢数据); 忘记在某条修改路径设置 dirty 会产生极难调试的 bug; **项目已有 Godot Node.queue_redraw / Transform notification / RenderingServer 缓存系统时直接用,不要在 GDScript 里再写一层 dirty 字段**
- 组合: 配缓存策略(LRU/timer/事件触发清 dirty); 粒度选择(每节点 dirty vs 每层 dirty)影响节约 vs 元数据开销; 原始数据修改最好走 setter API 内部自动 mark dirty 避免遗漏
- 原文: https://gpp.tkchu.me/dirty-flag.html

#### Object Pool 对象池
- 意图: 预分配一批同类对象循环复用,避免运行时频繁 new/delete 造成内存碎片或 GC 压力
- 症状: 每秒生成销毁成百上千粒子/子弹/特效造成 GC 卡顿或堆碎片化; 主机/移动设备内存紧张又要稳定运行不能 OOM; 创建对象本身代价大(DB/网络连接/复杂初始化); 浸泡测试跑几天就崩溃
- 不用: 创建很少 / 对象大小变化大造成槽位浪费; 有 GC 的现代语言里碎片化不严重时增加复杂度不值; **项目已有 ProjectilePool / ParticlePool / Godot 内建 MultiMesh / GPUParticles / Tween 等批处理机制时直接用,不要为每种短生命周期对象都造池**
- 组合: 池满时三种策略(扩容/拒绝/挤掉旧的最不重要); 空闲列表(free list)用对象自身未用字段当链表节点零额外内存; 配 Data Locality 同类对象天然连续; 复用对象时必须重置状态防止上次残留 bug
- 原文: https://gpp.tkchu.me/object-pool.html

#### Spatial Partition 空间分区
- 意图: 按位置组织对象进数据结构,把"找附近对象"从 O(n²) 降到 O(n log n) 或 O(n)
- 症状: 几百个单位每帧两两距离检测卡顿; 碰撞检测随单位数量平方增长; AOE/视野/声源范围/鼠标拾取/视锥剔除空间查询慢
- 不用: 对象数 n 不大(< 几十)裸循环够; 对象很少移动维护代价 > 查询收益; 内存比 CPU 紧张; **项目已有 UGridMap/NavMesh/SpatialHash 时直接复用不要再起一套**
- 组合: 网格分区天然配 Data Locality(同格内存挨着); 大世界 + 不均匀分布用层次分区(四叉树/八叉树/BSP/k-d); 静态地形 vs 动态单位常用不同分区
- 原文: https://gpp.tkchu.me/spatial-partition.html

---

## 简述模板(给未来扩展用)

每条简述固定 5 行,目的是让 LLM 能用症状语言快速匹配候选,而不是按模式名记忆推荐:

```markdown
#### <英文名> <中文名>
- 意图: 一句话核心目的,不要复述原文动机
- 症状: 3-5 条用户视角的问题描述(大白话/口语化,不是术语),分号分隔
- 不用: 反向边界 + **项目已有 X 系统时优先复用 X** 这条要明写并加粗
- 组合: 跟哪些模式天然搭配 / 哪些有重叠,分号分隔
- 原文: https://gpp.tkchu.me/<name>.html
```

---

## 注意事项

- 这个 skill 不替你看代码 —— Step 2 grep 项目机制必须真的去 grep,不要凭印象说"项目应该有 X"
- 推荐时坦诚 trade-off —— 经典模式很多是 1980-2000 年代游戏环境下的最优,放在现代 Godot/Unity/Unreal 引擎里有时引擎本身已经替你做了一半(比如 Godot 的 Node/Signal 已经是 Component + Observer 的具体实现),不要让用户去手搓引擎已经提供的东西
- 19 章模式不是金科玉律 —— 用户可能有更现代的方案(ECS、reactive 编程、actor model)。简述匹配不到时显式说"经典 19 章不太贴这个问题,建议换 X 角度",不要硬塞
