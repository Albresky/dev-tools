### **目标**

修改一个已经推送到 GitHub 的 Fork 仓库中的部分 commit 作者信息 (从 `wrong_user_name` 改为 `Albresky`)，并要求修改过程 “无痕”，即：

1. 保留所有 commit 原始的提交日期和时间戳。
2. 最终的提交历史要干净，并且与上游原始仓库 (`NVIDIA/cutlass`) 正确对齐。

---

### **第一阶段：修改 Commit 作者信息**

这是最核心的修改步骤，我们通过重写 Git 历史来完成。

- **使用的工具**：`git filter-repo`，这是官方推荐的、用于修改历史的现代化安全工具。

- **执行的步骤**：
  1. `git clone --mirror <仓库地址>`：克隆一个裸仓库 (bare repository)，这是执行历史重写操作的标准环境。
  2. `git filter-repo --mailmap <(echo '新作者 <新邮箱> 旧作者 <旧邮箱>')>`：通过邮件映射表，精准地将所有 `wrong_user_name` 的 commit 作者和提交者都更改为 `Albresky`。这个命令会创建一批具有新作者信息和新哈希值的 commit，但会保留原始的提交内容和时间戳。
  3. `git push --force --mirror origin`：将本地重写后的完美历史强制推送到自己的 GitHub Fork 仓库。

- **遇到的问题**：推送后，GitHub 显示我们的 Fork 仓库与上游仓库 “相差上千个提交” (`ahead` 和 `behind` 数量巨大)，因为重写后的历史与上游的原始历史失去了共同的基点。

---

### **第二阶段：将修改后的历史与上游仓库对齐**

为了解决历史分叉的问题，我们需要将我们修改过的 commit，重新 “嫁接” 到最新的上游仓库历史之上。

#### **失败方案：`reset` + `cherry-pick` ❌**

这个方案思路清晰，但有一个致命缺陷。

- **执行的步骤**：
  1. 克隆一个正常的仓库副本。
  2. 添加上游仓库 `git remote add upstream ...` 并 `git fetch upstream`。
  3. `git reset --hard upstream/main`：将本地 `main` 分支重置到和上游完全一致。
  4. `git cherry-pick <commit-hash>`：逐一将我们自己的 commit “摘取” 过来。

- **为什么失败了**：
  - **时间戳错误**：`cherry-pick` 会保留原始的**作者日期 (Author Date)**，但会将**提交者日期 (Committer Date)**                                                 更新为执行命令的当前时间。这导致 GitHub 上的时间戳全部变成了 “几分钟前”。
  - **提交者错误** \*\*：Committer\*\* 会变成当前执行命令的用户。因为您当时是在 `root` 用户下操作，所以所有 commit 都显示为 `Albresky authored and root committed`。
  - **结论**：这个方案无法满足 “无痕修改” 的要求。

#### **成功方案：`rebase` 配合参数 ✅**

这是实现 “无痕” 嫁接的终极方案，它解决了 `cherry-pick` 的所有缺点。

- **执行的步骤**：
  1. **修正身份**：在新克隆的仓库中，首先用 `git config user.name "Albresky"` 和 `git config user.email "..."` 来确保后续操作的提交者身份正确。
  2. **定位起点**：用 `git reset --hard origin/main` 将本地分支与我们**已经修改好作者信息**的远程分支对齐。
  3. **执行 Rebase**：运行核心命令 `git rebase --committer-date-is-author-date upstream/main`。
     - `rebase` 命令的作用就是将当前分支 (`main`) 的 commits 整体嫁接到 `upstream/main` 之上。
     - `--committer-date-is-author-date` 这个关键参数，让 `rebase` 在创建新 commit 时，**强制让提交者日期 (Committer Date) 与原始的作者日期 (Author Date) 保持一致**。
  4. **解决冲突**：(如果需要) 在 rebase 过程中手动解决代码冲突。
  5. **最终推送**：`git push --force origin main`，将这个时间戳和作者身份都完美无瑕的新历史推送到 GitHub。

### 同步远程修改完毕的 git 信息到本地 repo

**强制同步（原地更新）**

如果不想删除旧目录（比如里面有一些不想移动的未跟踪文件），可以在旧目录内部执行强制同步。

> 此操作会丢弃本地旧目录里 main 分支上所有未推送的提交，并清除所有未保存的工作区修改。

```bash
# 1. 进入旧的 cutlass 仓库目录
cd /path/to/original/repo

# 2. 确认当前在 main 分支
git checkout main

# 3. 从远程仓库 origin 下载最新的数据和历史记录
git fetch origin

# 4. 将本地的 main 分支强制重置，使其与远程的 origin/main 完全一致
# --hard 参数会丢弃所有本地修改和提交
git reset --hard origin/main

# 5. (可选) 如果想清理掉本地新增的、未被Git跟踪的文件和目录，使其和克隆下来的状态完全一样，可以执行以下命令
# -f 表示强制, -d 表示包含目录
git clean -fd
```

---

### **总结：关键命令与概念**

| 目的            | 推荐命令                                                    | 核心作用                                   |
| :------------ | :------------------------------------------------------ | :------------------------------------- |
| **重写作者**      | `git filter-repo --mailmap`                             | 安全、高效地批量修改历史 commit 的作者 / 邮箱。          |
| **修正身份**      | `git config user.name/email`                            | 定义当前操作的提交者身份，避免出现 `root` 等非预期用户。       |
| **对齐历史 (无痕)** | `git rebase --committer-date-is-author-date <new-base>` | 将一系列 commit 嫁接到新的基点上，同时**完美保留原始的时间戳**。 |
| **强制推送**      | `git push --force`                                      | 在重写历史后，用本地的新历史覆盖远程仓库的旧历史。              |
