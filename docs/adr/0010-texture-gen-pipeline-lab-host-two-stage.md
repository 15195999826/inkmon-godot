# 生图资产管线架构：lab 宿主 + MCP 调用面 + 车间/入库两段制

tile 美术管线进入"AI 生图贴图"阶段（gpt-image-2 唯一生图模型），需要决定生图能力宿主、AI 调用面、
资产真相归属。领域语言与生产流细节见根目录 `CONTEXT.md`；相机角度冻结前提见 adr/0009。

**决定四条：**

1. **宿主 = inkmon-lab，调用面 = MCP 操作活的 lab app**（要求生图工作时 lab 常驻打开，与
   Blender MCP 同模式）。拒绝另起脚本仓 / 纯 CLI / 裸 HTTP：lab 已付清生图基建成本
   （imageProvider 文生图+图生图+参考图槽位、Seed SDK 网关 key 隔离、图库持久化、Electron UI），
   MCP 走活 app 让用户在 UI 里全程可见、可插手 AI 的生成过程，双方共享同一份状态。

2. **lab 不长 tile 领域知识**。lab 只新增"通用生图工作类型"，两层结构：session（配方）=
   用户调参沉淀的提示词骨架+参考图组合，lab 持有本体按 id 引用；tile 几何逻辑（线稿模板生成、
   网格画布拼装、warp、mask 裁切、数据级 QC）全部住 godot 仓工具脚本。地形 → 现役 session id
   的映射归 git 管（`blender/textures/gen_config.json`）。

3. **车间/入库两段制**。lab = 车间：全部生成历史含裸模式（自动 scratch session，无例外）；
   AI 永不直接收图字节，拿文件唯一通道是 export。godot 仓 = 入库真相：批准品进
   `blender/designs|textures/`（含 provenance JSON：prompt/方案/参考图/lab session id）并
   git 提交，烘焙只读仓库路径——任意 commit 可重烘当时画面，多机拉仓即全量，lab 数据丢失
   只丢历史溯源不伤游戏构建。候选评估走 gitignored `_candidates/` 缓冲（后置闸门要求批准前
   烘焙试评），永不 commit，不构成第三真相。

4. **MCP 契约最小集**：`generate`（session 模式主用 / 裸模式兜底，同步阻塞，底图与参考图传
   本地路径，返回 lab image id + 只读预览路径）、`export`（id + 绝对路径写文件）、`history`、
   `tag`（可选）。审批模式 = 后置闸门：AI 车间内全自主（生成→QC→烘焙→Godot 实拍自评→shortlist），
   用户审 Godot 实景，点头即触发 export 入库。

## Considered Options

- 调用面：CLI（零常驻但每次冷启动、双真相风险）/ HTTP sidecar（要保证常驻、无 UI 联动收益）/
  **MCP 操作活 lab（采纳）**。
- 真相归属："lab 即真相、烘焙时从 lab 拉"——省仓库体积，但多机与 git 回滚两条变脆，拒绝。
