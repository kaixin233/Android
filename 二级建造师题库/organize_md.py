# -*- coding: utf-8 -*-
"""
对 convert_html_to_md.py 生成的 Markdown 大纲考点做进一步整理：
1. 按「第N章」数字升序重排章节（目录与正文一致，1 -> 最后章，不颠倒）
2. 丢弃源文件中错位的「第X篇」h1 篇标题（保持扁平、按章排序）
3. 重建有序目录（## 目录 + 列表）
4. 下载所有远程图片到本地 images/ 目录，并把 Markdown 中的图片引用改写为本地相对路径

用法：在 二级建造师题库/ 目录下运行：
    python organize_md.py
"""
import os
import re
import ssl
import sys
import urllib.request
import urllib.parse

BASE = os.path.dirname(os.path.abspath(__file__))
IMAGES_DIR = os.path.join(BASE, "images")
CHAPTER_RE = re.compile(r"^##\s+第(\d+)章")
H1_RE = re.compile(r"^#\s+")
PIAN_RE = re.compile(r"^#\s+第.+篇")
IMG_RE = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def is_remote(url):
    return url.startswith("http://") or url.startswith("https://")


def local_name(url):
    path = urllib.parse.urlparse(url).path
    base = os.path.basename(path)
    if not base:
        base = re.sub(r"\W+", "_", url) + ".jpg"
    return base


def download(url):
    """下载 url 到 IMAGES_DIR/local_name，返回本地相对路径 'images/xxx'。失败返回原 url。"""
    name = local_name(url)
    dest = os.path.join(IMAGES_DIR, name)
    rel = "images/" + name
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return rel
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Referer": "http://farfoot.com/",
        },
    )
    try:
        data = urllib.request.urlopen(req, timeout=30, context=ctx).read()
        if not data:
            return url
        with open(dest, "wb") as f:
            f.write(data)
        return rel
    except Exception as e:
        print(f"  [WARN] 下载失败，保留远程链接: {url} -> {e}")
        return url


def parse(md_path):
    with open(md_path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    title = None
    chapters = []  # (num, [lines])
    cur = None
    for line in lines:
        m = CHAPTER_RE.match(line)
        if m:
            num = int(m.group(1))
            if cur is not None:
                chapters.append(cur)
            cur = (num, [line])
            continue
        if H1_RE.match(line):
            # h1：第一个作为标题；其余（第X篇）丢弃
            if title is None and not PIAN_RE.match(line):
                title = line
            continue
        if cur is not None:
            cur[1].append(line)
        # 首个章节之前的行（旧目录等）忽略
    if cur is not None:
        chapters.append(cur)
    return title, chapters


def rebuild(title, chapters):
    chapters_sorted = sorted(chapters, key=lambda x: x[0])
    out = []
    if title:
        out.append(title)
        out.append("")
    out.append("## 目录")
    out.append("")
    for num, blk in chapters_sorted:
        heading_text = blk[0].replace("##", "", 1).strip()
        out.append(f"- {heading_text}")
    out.append("")
    for num, blk in chapters_sorted:
        out.extend(blk)
        out.append("")
    return "\n".join(out).strip() + "\n"


def localize_images(text):
    urls = sorted(
        set(m.group(2).strip() for m in IMG_RE.finditer(text) if is_remote(m.group(2).strip()))
    )
    mapping = {}
    for url in urls:
        mapping[url] = download(url)
    def repl(m):
        alt, url = m.group(1), m.group(2).strip()
        if url in mapping:
            new = mapping[url]
            if is_remote(new):
                return m.group(0)  # 下载失败，保留原样
            return f"![{alt}]({new})"
        return m.group(0)
    return IMG_RE.sub(repl, text)


def main():
    os.makedirs(IMAGES_DIR, exist_ok=True)
    md_files = [f for f in os.listdir(BASE) if f.endswith("_大纲考点.md")]
    for mf in md_files:
        path = os.path.join(BASE, mf)
        print(f"[处理] {mf}")
        title, chapters = parse(path)
        nums = [c[0] for c in chapters]
        print(f"  章节数={len(chapters)} 章节号={nums}")
        if nums != sorted(nums):
            print(f"  -> 顺序已重排: {sorted(nums)}")
        else:
            print(f"  -> 顺序已为 1..N，无需重排")
        text = rebuild(title, chapters)
        text = localize_images(text)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        # 统计图片
        n_local = text.count("images/")
        n_remote = len(re.findall(r"!\[\]?\(https?://", text))
        print(f"  本地图片引用={n_local} 剩余远程引用={n_remote}")


if __name__ == "__main__":
    main()
