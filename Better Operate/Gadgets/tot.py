#!/usr/bin/env python3
"""编辑文本，将 LaTeX 数学分隔符替换为 Markdown 分隔符后保存。"""

import argparse
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="输出文件；无后缀时补 .md，相对路径基于当前目录")
    parser.add_argument(
        "--editor",
        default=os.environ.get("EDITOR", "vim"),
        help="编辑器命令，可含参数；默认使用 EDITOR，未设置时使用 vim",
    )
    args = parser.parse_args()
    editor = shlex.split(args.editor)
    if not editor:
        parser.error("编辑器命令不能为空")

    output = args.output.expanduser()
    if not output.suffix:
        output = output.with_suffix(".md")
    if not output.parent.is_dir():
        parser.error(f"输出目录不存在：{output.parent}")

    work_dir = Path.home() / ".pi" / "work"
    work_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tot-", dir=work_dir) as temporary:
        draft = Path(temporary) / "input.md"
        subprocess.run([*editor, str(draft)], check=True)
        if not draft.is_file():
            print("tot: 未保存文本，未写入目标文件", file=sys.stderr)
            return 1
        text = draft.read_text(encoding="utf-8")
        for source, replacement in ((r"\[", "$$"), (r"\]", "$$"), (r"\(", "$"), (r"\)", "$")):
            text = text.replace(source, replacement)
        output.write_text(text, encoding="utf-8")

    print(output.absolute())
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(f"tot: 编辑器退出码 {error.returncode}，未写入目标文件", file=sys.stderr)
        sys.exit(1)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"tot: {error}", file=sys.stderr)
        sys.exit(1)
