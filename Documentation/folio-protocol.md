# KongFolio ↔ KongScholar exchange protocol, v1

本机文件交换，不携带 PDF。发送需要显式用户操作；接收仅建立待确认预览，不自动改库。

## JSON 摘录包

- `format`: `KongFolioScholar`；`version`: 1。
- `document`: `id` 为保存进 .kongfolio 的 UUID；`title`；`filePath` 为本机项目路径；可选 `bookmarkData` 为 Foundation 最小文件书签的 base64；`fingerprint` 为项目内 PDF 二进制的 SHA-256；`pageCount`。
- `annotations`: `id` 为写入 PDFAnnotation 的 `KongFolioScholarAnnotationID` UUID；`pageIndex` 从 0 起；`physicalPage` 必须等于 pageIndex+1；`printedPage` 人工核对，默认空；`kind`；`quote`；`note`。
- 25 MB 文件上限，10000 条记录上限；单条原文或笔记不超过 200 万字符。无文字的纯图形标注不交换。

去重依据 document.id + annotation.id。快照对比包括来源文字、笔记与位置。来源变化先预览；本地改写过来源字段时标为冲突。个人解释、研究问题、研究卡片 ID 与论证关联不由来源覆盖。人工改名、引文与印刷页码保留。删除来源批注不会自动删除研究卡片。

## 本机入口

- KongScholar: `kongscholar://import?file=<本机 JSON 路径>`，只读摘录包并预览。
- KongFolio: `kongfolio://open?file=<项目路径>&document=<UUID>&annotation=<UUID>&page=<1起页码>&fingerprint=<SHA256>&quoteHash=<SHA256>`。

使用 URLComponents 编解码，拒绝重复参数与无效编号。KongFolio 验证目标项目的文档 UUID，优先查批注编号。页序或内容变化时提示核对；批注缺失只在确认后退回旧物理页码。项目路径统一解析符号链接，以免同一项目被当成另一文件重新载入。

重新关联结构化来源必须匹配文档 UUID。旧 Markdown 无稳定身份，按标题、页码、类型和完整文字去重；变化会新增，返回原文需人工关联及页码确认。同名文档、编辑后的任意 Markdown 不保证可自动解析。

## 兼容

ProjectArchive 新增可选 scholarDocumentID，保持 version=3；可读 v2/v3。旧版 KongFolio 另存可能丢弃此可选字段。KongScholar 保留旧数据键及文件位置；完整 JSON 备份包含 folio 来源信息，但 PDF 和 .kongfolio 项目须另行迁移。
