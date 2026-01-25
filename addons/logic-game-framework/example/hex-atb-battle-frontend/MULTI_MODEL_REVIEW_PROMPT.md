# 🤖 多模型代码审核协调指南

## 📋 审核请求模板（复制即用）

### 【通用版本】适用于所有模型

```
你是代码审核专家。请对以下 Godot GDScript 项目进行全面的代码审核。

【项目信息】
- 项目名称: Hex ATB Battle Frontend (表演层)
- 项目路径: addons/logic-game-framework/example/hex-atb-battle-frontend/
- 项目类型: Godot 4.x GDScript 项目
- 核心设计: 逻辑表演分离 + 声明式动画系统

【审核范围】
请审核以下核心文件：
1. core/battle_director.gd - 主控制器
2. core/action_scheduler.gd - 动作调度器
3. core/render_world.gd - 渲染状态管理
4. core/visualizer_registry.gd - 事件翻译器注册表
5. scene/battle_replay_scene.gd - 3D 场景管理
6. actions/visual_action.gd - 视觉动作基类
7. visualizers/base_visualizer.gd - Visualizer 基类

【🔥 优先级 1】项目规范检查
根据项目 AGENTS.md 的编码规范，重点检查：

1. ✅ 变量名遮蔽问题
   - 是否有变量名遮蔽基类方法（如 `var set := ...`）
   - 是否有变量名遮蔽全局类

2. ✅ 全局类使用规范
   - 是否使用 preload 加载全局类（应直接使用 class_name）
   - 示例：`const TestFramework = preload(...)` ❌ vs 直接使用 ✅

3. ✅ 变量名混淆
   - 同一函数不同分支是否使用相同变量名
   - 示例：if 分支和 else 分支都有 `var base_value`

4. ✅ Lambda 捕获变量
   - Lambda 是否正确处理外部变量修改
   - 简单类型应使用字典包装

5. ✅ 类型推断
   - 类型不明确时是否使用 `as` 转换
   - 避免类型推断失败导致的隐式转换

6. ✅ 继承要求
   - Autoload 是否继承 Node（不是 RefCounted）
   - 测试脚本是否继承 SceneTree 或 MainLoop

【通用审核维度】

【2】代码逻辑正确性
- 数据流是否符合设计：GameEvent → VisualAction → ActiveAction → RenderState
- 信号连接是否正确且无泄漏
- 状态管理是否一致（无竞态条件）
- 回放流程是否完整（load → play → pause → reset）

【3】边界条件和错误处理
- 空值检查（null 检查）
- 数组越界保护
- 字典键存在性检查（使用 .get() 而非直接访问）
- 异常情况处理（无效事件、缺失 actor 等）

【4】代码风格和可读性
- 命名规范：snake_case 变量，PascalCase 类名
- 注释完整度（特别是复杂逻辑和公共 API）
- 代码组织：函数长度、职责单一性
- 常量定义是否清晰

【5】架构设计和可维护性
- 模块间耦合度（是否过度耦合）
- 接口设计是否清晰（公共方法签名）
- 扩展性：添加新 Visualizer 是否容易
- 与 Web 端架构的一致性

【6】性能优化机会
- 不必要的信号触发（如 actor_state_changed 每帧触发）
- 内存泄漏风险（RefCounted 对象的生命周期）
- 重复计算或查询（如重复查找 actor）
- 集合操作效率（Dictionary vs Array）

【7】安全性问题
- 类型安全（避免 `as any` 式的强制转换）
- 资源释放（_notification(NOTIFICATION_PREDELETE)）
- 信号连接泄漏（是否正确断开连接）

【8】测试覆盖建议
- 单元测试：各 Visualizer 的翻译逻辑
- 集成测试：完整回放流程
- 边界测试：空回放、单位死亡、移动等
- 性能测试：大量单位的回放

【输出要求】

请按以下格式返回审核结果：

返回 Markdown 格式, 写入项目根目录下的review目录下， 注意文件保存名字不要重复：
# 代码审核报告 - Hex ATB Battle Frontend

## 📊 审核概览
[表格：问题统计]

## 🔴 严重问题 (Critical)
[按文件组织]

## 🟠 主要问题 (Major)
[按文件组织]

## 🟡 次要问题 (Minor)
[按文件组织]

## 💡 建议项 (Suggestion)
[按类别组织]

## ✨ 亮点
[项目的优点]

## 📋 总体评价
[100字以内]

【已知问题参考】
项目 README 中列出的已知问题（可作为参考）：
1. 内存泄漏：退出时有 ObjectDB instances leaked 警告
2. 资源未释放：退出时有 resources still in use 错误
3. 单位名称：UnitView 显示为 @Node3D@2 而非实际名称
4. actor_state_changed 频繁触发：每帧都在触发
5. HP 信息缺失：actor_state_changed 信号中没有 HP 数据
6. 移动动画：actor_1 的移动事件没有正确更新位置状态

【审核重点】
- 这些已知问题的根本原因是什么？
- 代码中是否有其他隐藏的类似问题？
- 如何从架构层面解决这些问题？
```

---

## 🎯 按模型定制的审核请求

### 模型 1: GLM-4.7 (智谱清言) - 代码规范专家

```
你是 Godot GDScript 代码规范专家。请对 Hex ATB Battle Frontend 项目进行规范性审核。

【重点关注】
1. GDScript 编码规范遵循情况（参考 AGENTS.md）
2. 变量命名规范（snake_case vs PascalCase）
3. 类型系统使用（类型推断、as 转换）
4. 代码组织和结构（模块划分、职责单一性）
5. 注释和文档完整度

【输出格式】
JSON + Markdown（见通用版本）

【特别关注】
- 是否有违反 AGENTS.md 规范的代码
- 命名是否一致（全项目范围）
- 注释是否清晰完整
```

### 模型 2: Claude 3.5 Sonnet - 架构设计专家

```
你是软件架构设计专家。请对 Hex ATB Battle Frontend 的架构进行深度审核。

【重点关注】
1. 架构设计的合理性
   - 逻辑表演分离是否彻底
   - 各模块职责是否清晰
   - 模块间耦合度是否合理

2. 扩展性和可维护性
   - 添加新 Visualizer 是否容易
   - 添加新 Action 类型是否容易
   - 与 Web 端架构的一致性

3. 设计模式应用
   - Registry 模式是否正确使用
   - Observer 模式（信号）是否合理
   - 是否有更好的设计方案

4. 与逻辑层的接口设计
   - GameEvent 格式是否清晰
   - 数据流是否高效

【输出格式】
JSON + Markdown（见通用版本）

【特别关注】
- 架构是否能支持未来的扩展
- 是否有设计缺陷或反模式
- 与 Web 端的架构对齐情况
```

### 模型 3: GPT-4 Turbo - 性能和安全专家

```
你是游戏引擎性能和安全专家。请对 Hex ATB Battle Frontend 进行性能和安全审核。

【重点关注】
1. 性能问题
   - 内存泄漏风险（RefCounted 生命周期）
   - 不必要的信号触发（每帧 actor_state_changed）
   - 重复计算或查询
   - 集合操作效率

2. 安全性问题
   - 类型安全（避免强制转换）
   - 资源释放（_notification 处理）
   - 信号连接泄漏
   - 空指针异常风险

3. 已知问题的根本原因
   - 内存泄漏的具体原因
   - 资源未释放的原因
   - actor_state_changed 频繁触发的原因

4. 优化建议
   - 如何减少信号触发
   - 如何改进内存管理
   - 如何提高回放性能

【输出格式】
JSON + Markdown（见通用版本）

【特别关注】
- 已知问题的根本原因分析
- 性能瓶颈识别
- 内存泄漏的具体位置
```

### 模型 4: Gemini 2.0 Flash - 测试和可靠性专家

```
你是游戏开发测试和可靠性专家。请对 Hex ATB Battle Frontend 进行测试覆盖和可靠性审核。

【重点关注】
1. 测试覆盖建议
   - 单元测试：各 Visualizer 的翻译逻辑
   - 集成测试：完整回放流程
   - 边界测试：空回放、单位死亡、移动等
   - 性能测试：大量单位的回放

2. 边界条件处理
   - 空值检查（null 检查）
   - 数组越界保护
   - 字典键存在性检查
   - 异常情况处理

3. 可靠性问题
   - 竞态条件风险
   - 状态不一致风险
   - 信号连接泄漏风险

4. 错误处理
   - 是否有足够的错误处理
   - 错误消息是否清晰
   - 是否有恢复机制

【输出格式】
JSON + Markdown（见通用版本）

【特别关注】
- 缺失的测试用例
- 边界条件处理不足的地方
- 可靠性风险
```

---

## 📊 审核结果汇总脚本

### 步骤 1: 收集所有审核结果

```bash
# 创建结果目录
mkdir -p addons/logic-game-framework/example/hex-atb-battle-frontend/review_results

# 保存各模型的 JSON 结果
# review_results/glm-4.7.json
# review_results/claude-3.5.json
# review_results/gpt-4-turbo.json
# review_results/gemini-2.0.json
```

### 步骤 2: 汇总脚本（Python）

```python
import json
from collections import defaultdict

def merge_reviews(json_files):
    """合并多个审核结果"""
    all_issues = []
    all_positive = []
    all_recommendations = []
    
    for file in json_files:
        with open(file) as f:
            data = json.load(f)
            all_issues.extend(data['issues'])
            all_positive.extend(data['positive_points'])
            all_recommendations.extend(data['recommendations'])
    
    # 按 severity 分类
    by_severity = defaultdict(list)
    for issue in all_issues:
        by_severity[issue['severity']].append(issue)
    
    # 去重
    unique_issues = []
    seen = set()
    for issue in all_issues:
        key = (issue['file'], issue['line'], issue['description'][:50])
        if key not in seen:
            seen.add(key)
            unique_issues.append(issue)
    
    return {
        'total_issues': len(unique_issues),
        'by_severity': {k: len(v) for k, v in by_severity.items()},
        'issues': unique_issues,
        'positive_points': list(set(all_positive)),
        'recommendations': list(set(all_recommendations))
    }

# 使用
results = merge_reviews([
    'review_results/glm-4.7.json',
    'review_results/claude-3.5.json',
    'review_results/gpt-4-turbo.json',
    'review_results/gemini-2.0.json'
])

with open('review_results/MERGED_RESULT.json', 'w') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
```

---

## 🔄 审核流程

```
1. 准备阶段
   ├─ 复制通用版本审核请求
   ├─ 根据模型特点定制请求
   └─ 准备好项目代码和规范文档

2. 执行阶段
   ├─ 发送给 GLM-4.7（规范专家）
   ├─ 发送给 Claude 3.5（架构专家）
   ├─ 发送给 GPT-4 Turbo（性能专家）
   └─ 发送给 Gemini 2.0（测试专家）

3. 收集阶段
   ├─ 收集所有 JSON 结果
   ├─ 收集所有 Markdown 报告
   └─ 保存到 review_results/ 目录

4. 汇总阶段
   ├─ 运行汇总脚本
   ├─ 去重相同问题
   ├─ 按 severity 排序
   └─ 生成最终报告

5. 分析阶段
   ├─ 分析问题根本原因
   ├─ 优先级排序
   ├─ 制定修复计划
   └─ 分配修复任务
```

---

## 📌 检查清单

- [ ] 已准备好项目代码
- [ ] 已准备好 AGENTS.md 规范文档
- [ ] 已准备好 README.md 项目文档
- [ ] 已准备好各模型的定制审核请求
- [ ] 已创建 review_results/ 目录
- [ ] 已准备好汇总脚本
- [ ] 已确认各模型的访问权限
- [ ] 已设置好结果保存位置

---

## 💾 输出位置

```
addons/logic-game-framework/example/hex-atb-battle-frontend/
├── CODE_REVIEW_TEMPLATE.md          # 审核模板（本文件）
├── MULTI_MODEL_REVIEW_PROMPT.md     # 多模型审核指南（本文件）
├── review_results/
│   ├── glm-4.7.json                 # GLM-4.7 审核结果
│   ├── glm-4.7.md
│   ├── claude-3.5.json              # Claude 3.5 审核结果
│   ├── claude-3.5.md
│   ├── gpt-4-turbo.json             # GPT-4 Turbo 审核结果
│   ├── gpt-4-turbo.md
│   ├── gemini-2.0.json              # Gemini 2.0 审核结果
│   ├── gemini-2.0.md
│   ├── MERGED_RESULT.json           # 汇总结果
│   └── FINAL_REPORT.md              # 最终报告
```
