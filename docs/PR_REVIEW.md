# PR 审核与合并标准

适用于 `dev_env` 的所有改动。目标是让每个 PR 都能复现、验证、回滚和审计，
而不是只看“代码能不能跑”。

## 1. 通过标准

一个 PR 可以合并，必须同时满足：

1. 没有未解决的 P0/P1 问题；P2 已修复或有明确的后续 issue/记录。
2. PR 描述是最新的，包含目标、非目标、影响平台、验证命令和结果、风险与回滚。
3. 所有要求的自动/手动检查通过；外部网络导致的失败有可复现证据，且能证明
   不是本次改动引入。
4. 至少完成一次作者自审，以及一次不依赖作者结论的 fresh-context review。
5. 改动范围与 PR 标题一致；没有顺手混入无关重构、格式化或生成物。
6. 不包含密钥、令牌、个人隐私、真实 HOME 路径或机器专属配置。
7. 文档与实际行为一致；新增/修改的行为有对应测试或明确的手动验收步骤。

## 2. 问题分级

| 级别 | 定义 | 处理 |
|---|---|---|
| P0 | 密钥泄露、数据丢失、破坏用户配置、不可恢复的安装错误 | 阻止合并，必须修复 |
| P1 | 功能错误、平台回归、离线安装失效、错误的备份/覆盖行为 | 阻止合并，必须修复 |
| P2 | 可维护性、测试缺口、文档不一致、非主路径的可移植性问题 | 修复，或记录为后续任务 |
| P3 | 命名、措辞、纯风格建议 | 可选 |

评审意见要写清楚“触发条件 → 实际结果 → 期望结果”，不要只写“这里不太好”。

## 3. PR 范围与提交

- 一个 PR 只解决一个主题；标题使用 Conventional Commits 风格，例如
  `feat(tmux): ...`、`fix(install): ...`、`docs: ...`。
- 手工改动超过约 800 行时，PR 描述必须解释为什么不能拆分；vendored 上游代码
  不计入手工行数。
- vendored 代码单独提交，保留 LICENSE、版本文件和上游目录结构；升级时记录
  上游 tag/commit。
- 不提交离线包、构建产物、`dist/`、临时文件、编辑器缓存。
- 默认保留有意义的分步提交；只有用户明确要求时才 squash。

## 4. 代码与脚本检查

### 4.1 通用

- 不在脚本里硬编码真实用户名、HOME、代理或令牌；使用 `$HOME`、环境变量。
- 写入用户配置前必须备份；重复执行必须幂等。
- 测试和安装脚本不得修改真实 `~/.config/nvim`、`~/.config/tmux`、`~/.zshrc`；
  使用临时 HOME/XDG 目录或容器。
- 不执行 `tmux kill-*` / `tmux kill-server`；测试使用独立 socket，并用
  `exit`/`C-c` 结束测试 session。
- 下载的二进制/压缩包必须固定版本并校验 SHA256；离线安装过程不得访问网络。

### 4.2 Shell

```sh
find platforms nvim/scripts tests -name '*.sh' -print0 | xargs -0 -n1 /bin/bash -n
zsh -n shell/zshrc shell/*.zsh
shellcheck -x -S warning \
  platforms/lib/common.sh \
  platforms/macos/install.sh platforms/macos/offline/*.sh \
  platforms/macos/scripts/build-tmux.sh \
  platforms/linux/ubuntu/24.04/install.sh \
  platforms/linux/ubuntu/24.04/offline/*.sh \
  tests/*.sh nvim/scripts/*.sh
```

- macOS 目标脚本必须在系统 `/bin/bash` 3.2 下通过语法检查；不要使用 `mapfile`、
  关联数组等 bash 4+ 特性。
- `rm -rf` 的路径变量必须是非空、可验证的目录；必要时使用 `${var:?}`。
- 所有临时目录使用 `mktemp`，并用 `trap ... EXIT` 清理。

### 4.3 跨平台

- 同时检查 macOS 与 Ubuntu 的路径、命令名、包名、架构和默认 shell 差异。
- macOS 不假设 `readlink -f`、GNU `stat`、`sha256sum` 存在。
- Ubuntu 不假设 Homebrew、`shasum` 或系统 neovim 版本。
- 自定义 `XDG_CONFIG_HOME`/`XDG_DATA_HOME` 必须能工作；不能只测试默认 `~/.config`。

## 5. 测试证据

PR 描述中粘贴实际命令和结果，不要只写“已测试”。至少包含：

```sh
git status --short
git diff --check main...HEAD -- . ':(exclude)shell/vendor'
bash tests/tmux-config-smoke.sh
bash tests/shell-config-smoke.sh
bash tests/theme-assets-smoke.sh
```

按改动范围追加：

```sh
# macOS 构建
DEV_ENV_RUN_SLOW_TESTS=1 bash tests/macos-tmux-build-smoke.sh

# Ubuntu 联网
DOCKER_PROXY=http://host.docker.internal:7897 bash tests/ubuntu-24.04-online.sh

# Ubuntu 离线（--network none）
DOCKER_PROXY=http://host.docker.internal:7897 bash tests/ubuntu-24.04-offline.sh

# 临时 HOME 安装，不碰真实配置
TMP_HOME="$(mktemp -d)"; TMP_CONFIG="$(mktemp -d)"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_CONFIG" bash platforms/macos/install.sh
```

外部网络失败时，必须同时给出：

- 失败命令、错误摘要、发生阶段；
- 证明失败位于外部依赖（apt/GitHub/Docker 网络）而不是本次 diff；
- 同一改动在网络恢复后重跑成功的记录，或明确标注“待重跑”的阻塞项。

## 6. 安全与隐私

- 扫描 diff：私钥头、`sk-...`、非注释的 `API_KEY=`/`TOKEN=`/`SECRET=`/`PASSWORD=`。
- 不打印或提交 `~/.claude/settings.json`、备份文件、真实 `.zshrc.local`。
- 新增下载源必须使用 HTTPS、固定版本、校验 SHA256；不使用 `curl | sh`。
- 安装器默认拒绝 root；容器/CI 才允许 `--allow-root`。
- 不自动修改终端偏好、登录 shell 或系统级配置；只复制资源并打印说明。

## 7. 文档

- 行为变化同时更新 `README.md`、`docs/USAGE.md`、`docs/TESTING.md` 或对应模块
  README。
- 写清楚限制、未实现内容和回滚步骤；不要把“后续处理”写成“已完成”。
- 键位、路径、版本号必须和代码一致；示例命令要能直接复制执行。

## 8. 自审流程

1. 作者先完整读一遍 `git diff main...HEAD`，按上面的检查表逐项核对。
2. 运行静态检查和与改动相关的测试。
3. 做一次 fresh-context review（例如 `/code-review` 或独立 subagent），不要把自己
   的结论喂给它。
4. 对每条意见标记 P0/P1/P2/P3，修复后重跑受影响测试。
5. 在 PR 中记录评审结论、修复提交和最终验证结果。

## 9. 合并与清理

默认使用 merge commit，保留分支上的分步提交：

```sh
gh pr merge <number> --merge --delete-branch
git switch main
git pull --ff-only
```

只有在用户明确说“squash”时才使用 `--squash`。合并后确认：

- 远程目标分支包含 PR 的 merge commit；
- 远程开发分支已删除；
- 本地开发分支已删除；
- 本地目标分支与远程同步且工作区干净。

## 10. Definition of Done

- [ ] 范围单一，PR 描述完整且最新
- [ ] 无 P0/P1；P2 已修复或记录
- [ ] 静态检查、相关 smoke/平台/离线测试通过
- [ ] 文档与行为一致
- [ ] 无密钥、生成物、真实 HOME 写入
- [ ] 作者自审 + fresh-context review 完成
- [ ] 合并方式符合约定，分支已清理，目标分支已同步
