## 目标

<!-- 这个 PR 解决什么问题？ -->

## 非目标

<!-- 明确不在本 PR 范围内的事项。 -->

## 影响范围

- 平台：
- 模块：
- 用户可见变化：

## 验证

```sh
# 粘贴实际执行的命令和结果
```

- [ ] `git diff --check`（排除 vendored 代码）
- [ ] shell 静态检查 / `zsh -n`
- [ ] 相关 smoke test
- [ ] 平台或离线测试（如有改动）
- [ ] 未修改真实 HOME/配置

## 风险与回滚

<!-- 最坏情况是什么？如何恢复？ -->

## 自审

- [ ] 已完整阅读 diff
- [ ] 已完成 fresh-context review（`/code-review` 或独立 subagent）
- [ ] P0/P1 已修复；P2 已修复或记录
- [ ] 文档已同步

## 合并

- [ ] 默认 merge commit（只有明确要求时才 squash）
- [ ] 合并后删除本地和远程开发分支
- [ ] 本地目标分支已同步

审核标准见 [`docs/PR_REVIEW.md`](../docs/PR_REVIEW.md)。
