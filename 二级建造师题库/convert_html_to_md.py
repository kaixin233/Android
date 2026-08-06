# -*- coding: utf-8 -*-
"""
将二级建造师题库中的 HTML 大纲考点文件转换为 Markdown 文件。

转换规则：
- h1 -> #  (若是多个 h1，依次作为顶层标题)
- 目录 div.toc -> "## 目录" + 列表
- div.chapter-title -> ## 章节标题
- div.section-title -> ### 小节标题
- h2 -> 若与上一个 section-title 重复则跳过（源文件中 h2 是 section-title 的重复），否则 ###
- h4 -> #### 子标题
- p 内的 <strong> -> **加粗**（用于要点小标题）
- img -> ![alt](url)
- 无 class 的 div（图/表注） -> *斜体*
- &emsp; -> 2 个半角空格（保留缩进层级）
- <br/> -> 硬换行（行尾两空格 + 换行），保留原段落内的换行节奏
"""
import os
import sys
from bs4 import BeautifulSoup, NavigableString

EM = "\u2003"  # &emsp; 全角空格
NBSP = "\u00a0"


def _norm(text):
    """把全角空格/不间断空格规范化：每行行首的全角空格转为 2 个半角空格，其余转为普通空格。"""
    text = text.replace(NBSP, " ")
    text = text.replace(EM, "  ")
    return text


def _push_pending(state):
    s = state["pending"]
    if s.strip():
        state["segments"].append(s)
    state["pending"] = ""


def _segments_to_para(segments):
    segs = [_norm(s).rstrip() for s in segments if s.strip()]
    if not segs:
        return ""
    parts = [s + "  " for s in segs[:-1]] + [segs[-1]]
    return "\n".join(parts)


def _emit(state, lines):
    _push_pending(state)
    para = _segments_to_para(state["segments"])
    if para.strip():
        lines.append(para)
        lines.append("")
    state["segments"] = []


def process_node(node, lines, state, flush=True):
    for child in node.children:
        if isinstance(child, NavigableString):
            state["pending"] += str(child)
            continue
        tag = child.name
        if tag == "br":
            _push_pending(state)
        elif tag in ("strong", "b"):
            state["pending"] += "**" + child.get_text("", strip=False) + "**"
        elif tag in ("em", "i"):
            state["pending"] += "*" + child.get_text("", strip=False) + "*"
        elif tag == "img":
            _emit(state, lines)
            src = child.get("src", "")
            alt = child.get("alt", "") or ""
            lines.append(f"![{alt}]({src})")
            lines.append("")
        elif tag == "h1":
            _emit(state, lines)
            lines.append("# " + child.get_text(" ", strip=True))
            lines.append("")
        elif tag == "h2":
            _emit(state, lines)
            txt = child.get_text("", strip=True)
            if txt != state["last_header"]:
                lines.append("### " + txt)
                lines.append("")
            state["last_header"] = txt
        elif tag == "h4":
            _emit(state, lines)
            txt = child.get_text("", strip=True)
            lines.append("#### " + txt)
            lines.append("")
        elif tag == "p":
            _emit(state, lines)
            sub = {"segments": [], "pending": "", "last_header": None}
            process_node(child, [], sub, flush=False)
            _push_pending(sub)
            para = _segments_to_para(sub["segments"])
            if para.strip():
                lines.append(para)
                lines.append("")
        elif tag == "div":
            classes = child.get("class") or []
            if "toc" in classes:
                _emit(state, lines)
                lines.append("## 目录")
                lines.append("")
                for li in child.find_all("li"):
                    t = li.get_text(" ", strip=True).replace("  ", " ")
                    lines.append("- " + t)
                lines.append("")
            elif "chapter" in classes:
                _emit(state, lines)
                ct = child.find("div", class_="chapter-title")
                if ct:
                    txt = ct.get_text("", strip=True)
                    lines.append("## " + txt)
                    lines.append("")
                    state["last_header"] = txt
                process_node(child, lines, state)
            elif "chapter-title" in classes:
                pass  # 已由 chapter 处理
            elif "section" in classes:
                _emit(state, lines)
                st = child.find("div", class_="section-title")
                if st:
                    txt = st.get_text("", strip=True)
                    lines.append("### " + txt)
                    lines.append("")
                    state["last_header"] = txt
                process_node(child, lines, state)
            elif "section-title" in classes:
                pass  # 已由 section 处理
            elif "section-content" in classes:
                process_node(child, lines, state)
            else:
                # 无 class 的 div：图注 / 表注
                _emit(state, lines)
                txt = child.get_text("", strip=True)
                if txt:
                    lines.append("*" + _norm(txt) + "*")
                    lines.append("")
        else:
            process_node(child, lines, state)
    if flush:
        _emit(state, lines)


def convert(html_path, md_path):
    with open(html_path, encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "html.parser")
    body = soup.body
    if body is None:
        body = soup
    lines = []
    state = {"segments": [], "pending": "", "last_header": None}
    process_node(body, lines, state)
    # 清理多余空行（连续 3+ 空行 -> 2 空行）
    out = []
    blank = 0
    for ln in lines:
        if ln.strip() == "":
            blank += 1
            if blank <= 1:
                out.append(ln)
        else:
            blank = 0
            out.append(ln)
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(out).strip() + "\n")
    return len(out)


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    html_files = [f for f in os.listdir(base) if f.lower().endswith(".html")]
    for hf in html_files:
        html_path = os.path.join(base, hf)
        md_name = os.path.splitext(hf)[0] + ".md"
        md_path = os.path.join(base, md_name)
        n = convert(html_path, md_path)
        size = os.path.getsize(md_path)
        print(f"[OK] {hf} -> {md_name}  ({n} 行, {size/1024:.1f} KB)")


if __name__ == "__main__":
    main()
