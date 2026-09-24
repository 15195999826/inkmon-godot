# LGF 表演管线上提——偏离记录

> 配套 [`lgf-presentation-lift-plan.md`](lgf-presentation-lift-plan.md) §2 第 2 关。每阶段执行方在此追加；格式 `- PL<n>-<序号> / 做了什么 / 为什么`，每条 ≤ 200 字；「影响」只在会改变后续阶段时写；锚点写符号不写 `file:line`。范围外发现不写这里，记计划 §6「后续观察」。

## PL0 钉子先行

- PL0-1 / golden 用 3 个 seed（651143 + 900127 + 900191）而非只取 `hex/random-frontend` 那一个 / 651143 一局只出 10 种卡片，缺 `bump` 与 `cone_debug_overlay`——恰是 PL1 要改坐标口径的两张。在 `hex/random-golden` 的 10 个覆盖率 seed 上探针：900191 出 bump、900127 出 cone（另有 5 张投射物），三个合起来 12 种全覆盖，一次 4 s。
- PL0-2 / dump 里的生成 id 按 seed 内首现序规范化成「前缀#序号」（`Character#1` / `ability#3`） / 多 seed 同进程连跑时 IdGenerator 计数随顺序漂，指纹须与 RUNS 增删顺序无关。录像 sha（`record_sha256`）不规范化，只用于归因。
- PL0-3 / golden 接 Director 走三处私有字段：`_registry` 换成记录包装（翻译结果原样透传）、`_world.as_context()` 读取整位置、`_scheduler.get_action_count()` 只用于报错 / 「不改 frontend 源码」前提下拿翻译结果只能包注册表。影响：PL2 / PL3 搬家改名时这三处钩子随之改指向，不止「换用映射表」。
- PL0-4 / 主仓 §6 状态行的主仓 SHA 用单独一个 docs 提交回填（沿用 core 计划 P1 / P2 的做法） / 提交无法自引用自己的 SHA；阶段本身仍是两仓各一个提交。
- PL0-5 / leak 基线目录加 `README.md` / 直方图是零泄漏的空文件，没有说明看不出是「零」还是「没烤」；照 core 基线目录惯例，只记场景、命令与「仍为空即合格」的判据。

## PL1 坐标对齐

（未开始）

## PL2 搬家 + 改名 + 扩展缝

（未开始）

## PL3 Director 骨架 + live 入口

（未开始）

## PL4 文档与规则之家

（未开始）

## PL5 整体审与收口

（未开始）
