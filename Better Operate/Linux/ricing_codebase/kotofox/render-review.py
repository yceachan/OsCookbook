#!/usr/bin/python3
"""Render the review artifact from the single evidence.json source."""
from pathlib import Path
from html import escape
import json

root = Path(__file__).resolve().parent
data = json.loads((root / "evidence.json").read_text())
e = escape
checks = "".join(
    f'<article class="check"><span class="tick">{"✓" if item["passed"] else "!"}</span><div><h3>{e(item["name"])}</h3><p>{e(item["detail"])}</p></div></article>'
    for item in data["checks"]
)
fixes = "".join(
    f'<article class="fix"><h3>{e(item["name"])}</h3><p class="before">{e(item["before"])}</p><p>{e(item["after"])}</p></article>'
    for item in data["fixes"]
)
commands = "".join(
    f'<div class="command"><span>{e(label)}</span><code>{e(command)}</code></div>'
    for label, command in data["commands"].items()
)
menu = "".join(f'<div class="menu-item">{e(label)}</div>' for label in data["menu_labels"])
terminal = e(data["terminal_validation"]["terminal"].upper())
size = data["package"]["bytes"] / 1024 / 1024
html = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kotofox · 本机原型审阅</title>
<style>
*{{box-sizing:border-box}} :root{{--ink:#252d3c;--muted:#697080;--paper:#f7f6f1;--line:#dedfd7;--mint:#6fdbc5;--orange:#ffad70}}
body{{margin:0;background:var(--paper);color:var(--ink);font:16px/1.65 system-ui,-apple-system,"Noto Sans CJK SC",sans-serif}}
main{{max-width:1080px;margin:0 auto;padding:36px 32px 64px}}a{{color:inherit;text-decoration-thickness:1px;text-underline-offset:4px}}
.mast{{display:flex;justify-content:space-between;align-items:center;font-size:12px;letter-spacing:.08em;color:var(--muted);margin-bottom:24px}}
.hero{{background:#181d2c;color:#f7f6f1;border-radius:28px;padding:48px;position:relative;overflow:hidden}}
.hero:after{{content:"♪";position:absolute;right:50px;top:30px;font:200px/1 Georgia,serif;color:#303b43;transform:rotate(-15deg)}}
.hero-content{{position:relative;z-index:1}}.eyebrow{{color:var(--mint);font-size:12px;letter-spacing:.1em}}h1{{font-size:72px;line-height:1.05;letter-spacing:-.06em;margin:18px 0 16px}}
.tagline{{font-size:24px;margin:0 0 28px;font-weight:400}}.hero p.meta{{font-size:13px;color:#a7b0c3;margin:0}}.badge{{display:inline-flex;align-items:center;gap:8px;background:#253e3b;color:#b6f5e6;border:1px solid #38544f;border-radius:24px;padding:6px 14px;margin-bottom:18px;font-size:12px}}
.dot{{height:6px;width:6px;border-radius:50%;background:var(--mint)}}.facts{{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:20px}}
.fact{{border:1px solid var(--line);border-radius:16px;padding:20px 22px;background:#fffef9}}.fact small{{font-size:11px;color:var(--muted);letter-spacing:.08em}}.fact strong{{display:block;font-size:22px;margin:4px 0;font-weight:550}}.fact p{{font-size:13px;color:var(--muted);margin:0}}
.section{{margin-top:44px}}.section-head{{display:flex;align-items:baseline;gap:14px;border-bottom:1px solid var(--line);padding-bottom:13px;margin-bottom:20px}}
.number{{font:12px ui-monospace,monospace;color:#90988d}}h2{{font-size:20px;font-weight:550;letter-spacing:-.02em;margin:0}}h3{{font-size:15px;font-weight:600;margin:0 0 4px}}p{{margin:0}}.note{{color:var(--muted);font-size:13px;margin:12px 0 20px}}
.lifecycle{{display:grid;grid-template-columns:1fr 1.3fr 1fr;gap:16px;align-items:stretch}}
.node{{padding:22px;border-radius:18px;background:#eceee7;border:1px solid #dfe3d9}}.node.central{{background:#dcebe6;border-color:#c5ddd4}}.node .label{{color:#597b6b;font:11px ui-monospace,monospace;letter-spacing:.08em}}
.node h3{{font-size:19px;margin:12px 0 7px}}.node p{{font-size:13px;color:#566170}}.node .state{{display:block;margin-top:20px;padding-top:12px;border-top:1px solid #c9d4c8;font-size:12px;color:#376858}}
.checks{{display:grid;grid-template-columns:1fr 1fr;gap:12px}}.check{{display:flex;gap:15px;align-items:flex-start;padding:20px;background:#fffef9;border:1px solid var(--line);border-radius:16px}}
.tick{{color:#438674;border:1px solid #d0e3d8;background:#edf5ef;min-width:24px;height:24px;display:flex;justify-content:center;align-items:center;border-radius:50%;font-size:12px;margin-top:2px}}.check p{{font-size:13px;color:var(--muted)}}
.columns{{display:grid;grid-template-columns:1.05fr .95fr;gap:24px}}.command{{padding:13px 0;border-bottom:1px solid var(--line)}}.command span{{display:block;font-size:12px;color:var(--muted);margin-bottom:3px}}
code{{font:13px/1.6 ui-monospace,"Cascadia Code",monospace;word-break:break-all}}.menu{{background:#181d2c;color:#e2e7ef;border-radius:18px;padding:12px 0}}.menu-item{{padding:8px 23px;font-size:13px}}.menu-item:nth-child(3),.menu-item:nth-child(8),.menu-item:nth-child(12){{border-top:1px solid #343b4a;margin-top:7px;padding-top:15px}}
.fixes{{display:grid;grid-template-columns:1fr 1fr;gap:16px}}.fix{{background:#edece4;border-radius:16px;padding:24px}}.fix p{{font-size:13px;color:#566170;margin-top:10px}}.fix p.before{{color:#9b7762}}
.download{{display:flex;justify-content:space-between;gap:24px;align-items:center;background:#e9ede4;border-radius:18px;padding:24px}}.download a{{background:#263e38;color:#e7f5ed;border-radius:24px;padding:9px 20px;font-size:13px;text-decoration:none;white-space:nowrap}}
details{{margin-top:15px;border:1px solid var(--line);border-radius:12px;padding:12px 16px;font-size:12px}}summary{{cursor:pointer;color:var(--muted)}}details code{{display:block;margin-top:10px;font-size:11px}}
footer{{margin-top:30px;border-top:1px solid var(--line);padding-top:18px;color:var(--muted);font-size:12px}}.scope{{font-size:14px;color:#566170;margin-top:22px;max-width:780px}}.links{{margin-top:12px;display:flex;gap:18px;flex-wrap:wrap}}
@media(max-width:700px){{main{{padding:20px 16px 40px}}.hero{{padding:30px 25px}}h1{{font-size:56px}}.tagline{{font-size:20px}}.hero:after{{right:0;font-size:170px}}.facts,.lifecycle,.checks,.columns,.fixes{{grid-template-columns:1fr}}.facts{{gap:8px}}.fact{{padding:16px 20px}}.download{{align-items:flex-start;flex-direction:column}}.mast{{font-size:10px;gap:15px}}}}
@media print{{body{{background:white}}main{{max-width:none;padding:0}}.hero{{padding:28px}}.section{{break-inside:avoid;margin-top:24px}}h1{{font-size:48px}}}}
</style></head><body><main>
<div class="mast"><span>RICING CODEBASE / KDE</span><span>实机记录 · {e(data['date'])}</span></div>
<section class="hero"><div class="hero-content"><div class="eyebrow">MUSICFOX × KOTONOHA × UNIDESKTOP</div><h1>Kotofox</h1><p class="tagline">关掉窗口，音乐继续。</p><span class="badge"><span class="dot"></span>本机原型已运行</span><p class="meta">{e(data['target'])} · v{e(data['version'])}</p></div></section>
<div class="facts"><div class="fact"><small>统一入口</small><strong>一个 Kotofox</strong><p>主任务栏启动项 + 系统托盘</p></div><div class="fact"><small>播放器生命周期</small><strong>沿用 musicfox 会话</strong><p>读取现有 tmux 配置与快捷键</p></div><div class="fact"><small>桌面歌词</small><strong>自动置顶</strong><p>只跟随 Musicfox，随时显示或隐藏</p></div></div>
<section class="section"><div class="section-head"><span class="number">01</span><h2>窗口与播放分别运行</h2></div>
<div class="lifecycle"><article class="node"><span class="label">KDE / {terminal}</span><h3>播放器窗口</h3><p>连接已有 tmux 会话。重复打开会恢复同一个窗口。</p><span class="state">关闭窗口 → 客户端退出</span></article><article class="node central"><span class="label">TMUX / MUSICFOX</span><h3>持续运行的播放器</h3><p>播放器由 tmux 会话持有。终端窗口只负责查看和输入。</p><span class="state">窗口关闭后 → 会话继续运行</span></article><article class="node"><span class="label">KOTOFOX / KOTONOHA</span><h3>托盘与歌词</h3><p>托盘控制两个应用。歌词通过桌面的媒体接口读取播放进度。</p><span class="state">隐藏歌词 → 播放不受影响</span></article></div>
<p class="note">退出 Kotofox 时可以保留播放。选择“退出并停止播放器”时，才关闭 musicfox 会话。</p></section>
<section class="section"><div class="section-head"><span class="number">02</span><h2>本次验证</h2></div><div class="checks">{checks}</div></section>
<section class="section"><div class="section-head"><span class="number">03</span><h2>直接试用</h2></div><div class="columns"><div>{commands}<p class="note">也可以点击主任务栏中的 Kotofox。右键系统托盘可以控制歌词和播放器。歌词设置独立保存在 ~/.config/kotofox/lyrics.json。</p></div><div class="menu">{menu}</div></div></section>
<section class="section"><div class="section-head"><span class="number">04</span><h2>试用时修复的问题</h2></div><div class="fixes">{fixes}</div></section>
<section class="section"><div class="section-head"><span class="number">05</span><h2>试用包与源码</h2></div><div class="download"><div><h3>kotofox-0.1.0-fedora44-x86_64.tar.gz</h3><p class="note" style="margin:5px 0 0">{size:.1f} MiB · 包含两个应用、歌词原生库和托盘库</p></div><a href=".packages/kotofox-0.1.0-fedora44-x86_64.tar.gz">查看试用包</a></div>
<details><summary>包的 SHA-256 与上游版本</summary><code>{e(data['package']['sha256'])}</code><code>UniDesktop: {e(data['provenance']['uda_commit'])}</code><code>Kotonoha: {e(data['provenance']['kotonoha_commit'])} / 0.2.3<br>Musicfox: 5.1.0</code></details>
<p class="scope">{e(data['scope'])}</p><div class="links"><a href="README.md">操作说明</a><a href="https://github.com/yceachan/SDK/commit/{e(data['provenance']['uda_commit'])}">SDK 修复提交</a><a href="evidence.json">验证记录</a></div></section>
<footer>本页由 evidence.json 生成，展示本次实机结果。页面不需要外部字体、图片或脚本。</footer>
</main></body></html>'''
(root / "review.html").write_text(html)
print(root / "review.html")
