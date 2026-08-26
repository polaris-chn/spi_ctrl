# PDF 解析中间产物说明

本目录用于保存 GD25LF256F.pdf 的解析脚本与文本抽取结果，供后续设计/验证文档迭代复用。

## 文件

| 文件 | 说明 |
|---|---|
| `extract_pdf_pages.py` | 纯 Python PDF 解析脚本：读取 PDF 对象树，按 /Kids 真实页序，zlib 解压内容流，抽取 Tj/TJ 文本 |
| `GD25LF256F_extracted_by_page.txt` | 按真实页序（1~121）抽取的每页文本 |

## 复现

```bash
cd /home/lr/ctrl_if
python3 pdf_analysis/extract_pdf_pages.py
```

脚本默认把结果写到：
- `pdf_analysis/GD25LF256F_extracted_by_page.txt`
- `pdf_analysis/GD25LF256F_extracted_by_page.json`

## 已知局限

1. 已递归解析页面引用的 Form XObject 矢量波形（如 p73 77h 波形），比初版覆盖更全。
2. 纯位图/Image XObject 内容仍无法还原。
3. 表格文字可能出现行列交错、顺序错乱。
4. 嵌入字体/CID 字体与特殊字符可能无法正确还原。
5. 未决项 Q-02~Q-09 仍不能仅凭此文本关闭。

## PDF 版本与缓存一致性

- 当前解析对应的 PDF：`GD25LF256F.pdf`
- SHA256：见 `GD25LF256F.pdf.sha256`
- 使用规则：
  - 若 `sha256sum GD25LF256F.pdf` 与 `pdf_analysis/GD25LF256F.pdf.sha256` 一致：优先直接读 `GD25LF256F_extracted_by_page.txt`，不必重新解析；
  - 若哈希不一致（PDF 被替换/更新）：先运行 `python3 pdf_analysis/extract_pdf_pages.py` 重新生成缓存，再分析。
