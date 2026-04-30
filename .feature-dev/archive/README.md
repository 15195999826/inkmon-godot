# archive/

已完成 feature 的历史快照。每个完成的 feature 在此创建一个子目录：

```
archive/
└── <YYYY-MM-DD-feature-slug>/
    ├── Summary.md         feature 名称 / acceptance 结论 / 命令 / 真实运行证据 / 关键路径 / 残余风险
    ├── Current-State.md   完成时的 baseline 快照（拷贝自根目录同名文件）
    ├── Next-Steps.md      完成时的状态（已置为"等待用户确认下一个 feature"）
    ├── Progress.md        最终 evidence + 全部 checkbox 勾选
    └── task-plan/         拷贝自根目录 task-plan/
```

## Summary.md 必备字段

```markdown
# <feature 名称> — Summary (<YYYY-MM-DD>)

## Acceptance 结论
- [x] AC1 — ...（命令 + evidence 路径）
- [x] ACn — ...

## 关键 artifact 路径
- 入口场景：...
- Smoke 入口：...
- 配置文件：...

## 真实运行证据
- 命令 1：... → 结果
- 命令 N：... → 结果

## 残余风险 / 已知 follow-up
- ...

## Commits
- 主仓：<hash> <subject>
- submodule（如有）：<hash> <subject>
```

## 归档时机

`/autonomous-feature-runner` 判定 acceptance 5/5 通过 → 创建本目录子文件夹并填入快照 → 把根目录 `Next-Steps.md` 切到等待状态。

不要在 acceptance 没全过时归档。
