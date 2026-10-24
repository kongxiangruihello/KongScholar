# KongScholar 2.2

新增同行意见收件簿、稿次及证据定位、项目修订清单、可选择内部材料的修订稿交付包。自动备份支持15/30/60/120分钟及30/60/120份保留数量，首次保存及关闭或退出前检查，跳过相同内容。

GitHub仅同步APP源码和版本说明，研究资料只在本机备份。发布者通过已授权连接提交源码白名单，保留.gitignore资料排除规则。APP不持有GitHub凭证，不因研究资料变化自动上传。详见Documentation/release-2.2.md。

本版通过23项原生测试、14组JavaScript测试及Mac隔离验收。APP退出后不运行后台备份服务。

## 历史版本

# KongScholar 2.1

离线 Mac 私人学术工作台。此次新增项目目录层级与顺序、按项目保存的写作状态、章节论点证据矩阵、共享史料的项目使用说明，以及包含有序Word正文和七份Markdown清单的ZIP阶段成果包。正文和既有脚注快照保留；完整备份新增目录与使用说明。目录顺序同时用于项目章节列表、写作提纲和当前项目全部章节导出。

KongFolio 当前目标仍是文稿目录中的0.22系列，精确联动使用0.22.1补丁。以下1.x说明为版本历史，不应用其中旧0.4/0.5构建替换当前KongFolio。

20项Swift测试、13组JavaScript测试通过；阶段成果包Word样稿已渲染并检查全部页面。新增界面已用隔离合成资料完成Mac验收。具体操作见Documentation/使用说明.html。

## 历史版本

# KongScholar 1.4.1

修正 KongFolio 目标：默认绑定文稿目录的 App，明确显示路径与版本，拒绝旧 0.4/0.5 构建。支持 0.22 的 Markdown 摘录与格式 4 项目，并配合基于 0.22 的 0.22.1 联动补丁。

# KongScholar 1.4

新增自包含 Word 页下注导出、三类可编辑引注模板、定稿检查定位、章节版本比较与恢复、人物与文本回应证据表。无需安装 Python 或 Word 即可导出；KongFolio 0.5 继续兼容。

# KongScholar 1.3

章节写作台、引文脚注草稿、批次导入历史与字段级撤销。配合 KongFolio 0.5 按勾选、页码与标签发送摘录。兼容既有研究数据；正文及导入历史纳入完整备份。

# KongScholar 1.2

新增文献档案、双页码、人工引文核对与章节清单导出。原文、文献、定位变化自动提示复核；个人解释不影响核对状态。中性灰界面随系统切换深浅色。兼容 1.1 数据及 KongFolio 0.4。

# KongScholar 1.1 for Mac

围绕“何以为士：林乐知与晚清士大夫的重塑”的离线私人学术工作台。

## KongFolio 联动

搭配 KongFolio 0.4：发送摘录包、预览新增/更新/冲突、保留个人解释与研究关联、按稳定批注编号返回原文。兼容旧版 Markdown 摘要；支持项目重新关联。见 Documentation/folio-protocol.md 与 validation-1.1.md。

## 运行

macOS 13+，Apple 芯片 / Intel 通用程序。安装包位于 ../outputs/KongScholar/。将 APP 拖入应用程序后打开。无需 Node、Python、网络、账户登录或本地服务器。界面使用系统 WebKit，窗口、菜单、文件选择、导出及数据存储由 AppKit 提供。

桌面版将数据原子写入 ~/Library/Application Support/KongScholar/scholar-data.json。上一份文件保存在 recovery/previous-data.json；锁文件防止多进程同时写入。应用更新或移动 APP 不会更改此数据位置。

通过“文件 → 导入 JSON 备份…”迁入网页版 / 旧版史序数据；导入前预览，并先保存当前快照，取消快照会中止恢复。网页版与桌面版不会自动同步。

使用说明见 Documentation/使用说明.html。未设置单独的应用密码，也未接入 AI、在线文献服务或 KongReview 个人数据库。

## 构建与验证

需要 Xcode / Apple 命令行工具。无第三方依赖。

```sh
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift test --scratch-path .build --disable-sandbox
node Tests/JavaScript/desktop-bridge.cjs
./Tools/build-mac.sh
```

Tools/sync-web.py 从同项目 sites/shixu/dist 生成 Web/ 内的桌面界面；归档包含已生成的 Web/，独立源码构建时可保留这些资源（无网页版源码时跳过生成）。本机签名，没有开发者证书或 Apple 公证。
