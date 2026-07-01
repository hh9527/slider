#!/usr/bin/env python3
# /// script
# dependencies = [
#   "httpx>=0.28.0",
#   "rich>=13.0.0",
# ]
# ///
from __future__ import annotations

import argparse
import asyncio
import base64
from dataclasses import dataclass
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any

import httpx
from rich.console import Console
from rich.live import Live
from rich.text import Text


DEFAULT_OPENAI_BASE_URL = "https://api.openai.com/v1"
DEFAULT_TIMEOUT_SECONDS = 300.0
DEFAULT_CONCURRENCY = 2
DEFAULT_DEBOUNCE_SECONDS = 0.6


class AigcError(RuntimeError):
    pass


@dataclass
class WatchStatus:
    all: int = 0
    to_sync: int = 0
    to_update: int = 0
    reqs: int = 0
    ok: bool = True
    at: str = "-"


class Reporter:
    def __init__(self, *, live: bool = False) -> None:
        self.console = Console()
        self.status = WatchStatus()
        self.live_enabled = live and self.console.is_terminal
        self._live: Live | None = None

    def __enter__(self) -> Reporter:
        if self.live_enabled:
            self._live = Live(
                self.render_status(),
                console=self.console,
                refresh_per_second=8,
                transient=False,
            )
            self._live.__enter__()
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> None:
        if self._live:
            self._live.__exit__(exc_type, exc, tb)

    def event(self, message: str) -> None:
        if self._live:
            self._live.console.print(message)
            self._live.update(self.render_status())
        else:
            self.console.print(message)

    def update_status(self, **kwargs: Any) -> None:
        for key, value in kwargs.items():
            setattr(self.status, key, value)
        if self._live:
            self._live.update(self.render_status())

    def render_status(self) -> Text:
        state = "OK" if self.status.ok else "ERROR"
        state_style = "green" if self.status.ok else "red"
        return Text.assemble(
            ("[", "dim"),
            (f"all: {self.status.all}", "cyan"),
            (f", to-sync: {self.status.to_sync}", "yellow"),
            (f", to-update: {self.status.to_update}", "magenta"),
            (f", reqs: {self.status.reqs}", "blue"),
            ("] ", "dim"),
            (state, state_style),
            (f" at {self.status.at}", "dim"),
        )


def timestamp() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def repo_root_for(path: Path) -> Path:
    cur = path.resolve().parent
    for candidate in (cur, *cur.parents):
        if (candidate / ".git").exists() or (candidate / "typlibs" / "slider").exists():
            return candidate
    return Path.cwd().resolve()


def rel_path(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def typ_path_hash(typ_path: Path, root: Path) -> str:
    return hashlib.sha256(rel_path(typ_path, root).encode("utf-8")).hexdigest()[:16]


def find_typst_command() -> list[str]:
    if shutil.which("typst"):
        return ["typst"]
    if shutil.which("mise"):
        return ["mise", "x", "--", "typst"]
    raise AigcError("typst not found. Install typst or make it available through mise.")


def query_aigc_metadata(typ_path: Path, root: Path) -> list[dict[str, Any]]:
    input_path = rel_path(typ_path, root)
    cmd = [
        *find_typst_command(),
        "query",
        input_path,
        "metadata",
        "--root",
        str(root),
        "--input",
        "aigc-mode=query",
        "--format",
        "json",
    ]
    proc = subprocess.run(
        cmd,
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise AigcError(proc.stderr.strip() or "typst query failed")

    try:
        raw = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise AigcError(f"typst query returned invalid JSON: {exc}") from exc

    items: list[dict[str, Any]] = []
    for item in raw:
        value = item.get("value")
        if isinstance(value, dict) and value.get("kind") == "aigc":
            items.append(value)
    return items


def require_str(item: dict[str, Any], key: str) -> str:
    value = item.get(key)
    if not isinstance(value, str) or value == "":
        raise AigcError(f"aigc metadata field `{key}` must be a non-empty string")
    return value


def optional_str(item: dict[str, Any], key: str) -> str | None:
    value = item.get(key)
    if value is None:
        return None
    if not isinstance(value, str) or value == "":
        raise AigcError(f"aigc metadata field `{key}` must be a non-empty string when set")
    return value


def validate_item(item: dict[str, Any]) -> None:
    for key in (
        "vendor",
        "format",
        "content-size",
        "source-digest",
        "path",
        "model",
        "quality",
        "prompt",
    ):
        require_str(item, key)
    path = require_str(item, "path")
    if Path(path).is_absolute() or ".." in Path(path).parts:
        raise AigcError(f"aigc metadata path must be a safe relative path: {path}")
    optional_str(item, "chroma-key")
    optional_str(item, "chroma-key-prompt")


def cache_path_for(item: dict[str, Any], typ_hash: str, root: Path) -> Path:
    digest = require_str(item, "source-digest")
    fmt = require_str(item, "format").lstrip(".")
    if "/" in digest or "\\" in digest or digest in {"", ".", ".."}:
        raise AigcError(f"invalid source-digest: {digest}")
    return root / "target" / "cache" / "aigc" / typ_hash / f"{digest}.{fmt}"


def asset_path_for(item: dict[str, Any], typ_path: Path) -> Path:
    return typ_path.resolve().parent / require_str(item, "path")


def same_bytes(a: Path, b: Path) -> bool:
    if not a.exists() or not b.exists():
        return False
    if a.stat().st_size != b.stat().st_size:
        return False
    return hashlib.sha256(a.read_bytes()).digest() == hashlib.sha256(b.read_bytes()).digest()


def link_or_copy(src: Path, dest: Path) -> str:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(f".{dest.name}.tmp")
    try:
        tmp.unlink()
    except FileNotFoundError:
        pass

    method = "hardlink"
    try:
        os.link(src, tmp)
    except OSError:
        method = "copy"
        shutil.copy2(src, tmp)
    tmp.replace(dest)
    return method


def openai_url() -> str:
    base_url = os.environ.get("OPENAI_BASE_URL", DEFAULT_OPENAI_BASE_URL).rstrip("/")
    return f"{base_url}/images/generations"


async def remove_chroma_key(src: Path, out: Path, key_color: str) -> None:
    magick = shutil.which("magick")
    if not magick:
        raise AigcError("ImageMagick `magick` is required for chroma-key background removal")

    tmp = out.with_name(f".{out.name}.tmp")
    try:
        tmp.unlink()
    except FileNotFoundError:
        pass

    proc = await asyncio.create_subprocess_exec(
        magick,
        str(src),
        "-alpha",
        "set",
        "-fuzz",
        "8%",
        "-transparent",
        key_color,
        "-define",
        "png:color-type=6",
        str(tmp),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        if stdout:
            print(stdout.decode("utf-8", errors="replace"), end="")
        if stderr:
            print(stderr.decode("utf-8", errors="replace"), end="", file=sys.stderr)
        raise AigcError("ImageMagick chroma-key removal failed")
    tmp.replace(out)


async def generate_openai(item: dict[str, Any], out: Path, reporter: Reporter | None = None) -> None:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise AigcError("OPENAI_API_KEY is not set")

    prompt = require_str(item, "prompt")
    chroma_key = optional_str(item, "chroma-key")
    chroma_key_prompt = optional_str(item, "chroma-key-prompt")
    if chroma_key_prompt:
        prompt = f"{chroma_key_prompt}\n\n{prompt}"
    payload = {
        "model": require_str(item, "model"),
        "prompt": prompt,
        "size": require_str(item, "content-size"),
        "quality": require_str(item, "quality"),
        "n": 1,
    }

    timeout = httpx.Timeout(DEFAULT_TIMEOUT_SECONDS)
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.post(
            openai_url(),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        if resp.status_code >= 400:
            raise AigcError(f"OpenAI image request failed: {resp.status_code} {resp.text}")
        data = resp.json()

    try:
        encoded = data["data"][0]["b64_json"]
    except (KeyError, IndexError, TypeError) as exc:
        raise AigcError("OpenAI image response did not contain data[0].b64_json") from exc

    out.parent.mkdir(parents=True, exist_ok=True)
    if chroma_key:
        raw = out.with_name(f".{out.stem}.chroma-source{out.suffix}")
        raw.write_bytes(base64.b64decode(encoded))
        if reporter:
            reporter.event(f"post-processing asset {require_str(item, 'path')} ...")
        await remove_chroma_key(raw, out, chroma_key)
        raw.unlink(missing_ok=True)
    else:
        tmp = out.with_name(f".{out.name}.tmp")
        tmp.write_bytes(base64.b64decode(encoded))
        tmp.replace(out)


async def generate_item(item: dict[str, Any], cache_path: Path, reporter: Reporter | None = None) -> bool:
    vendor = require_str(item, "vendor")
    if cache_path.exists():
        return False
    if vendor == "openai":
        if reporter:
            reporter.event(f"requesting asset {require_str(item, 'path')} ...")
            reporter.update_status(reqs=reporter.status.reqs + 1)
        try:
            await generate_openai(item, cache_path, reporter=reporter)
        finally:
            if reporter:
                reporter.update_status(reqs=reporter.status.reqs - 1)
        if reporter:
            reporter.update_status(to_update=reporter.status.to_update - 1)
        return True
    raise AigcError(f"unsupported AIGC vendor: {vendor}")


async def update_assets(args: argparse.Namespace, reporter: Reporter | None = None) -> int:
    reporter = reporter or Reporter()
    typ_path = Path(args.typ_file)
    if not typ_path.exists():
        raise AigcError(f"Typst file not found: {typ_path}")

    root = Path(args.root).resolve() if args.root else repo_root_for(typ_path)
    typ_hash = typ_path_hash(typ_path, root)
    items = query_aigc_metadata(typ_path, root)
    if not items:
        reporter.update_status(all=0, to_sync=0, to_update=0, reqs=0)
        reporter.event("No AIGC assets found.")
        return 0

    sem = asyncio.Semaphore(args.concurrency)
    generated = 0
    synced = 0
    skipped = 0
    planned: list[tuple[dict[str, Any], Path, Path, bool, bool]] = []
    for item in items:
        validate_item(item)
        cache_path = cache_path_for(item, typ_hash, root)
        asset_path = asset_path_for(item, typ_path)
        needs_update = not cache_path.exists()
        needs_sync = needs_update or not same_bytes(cache_path, asset_path)
        planned.append((item, cache_path, asset_path, needs_update, needs_sync))

    reporter.update_status(
        all=len(items),
        to_update=sum(1 for _, _, _, needs_update, _ in planned if needs_update),
        to_sync=sum(1 for _, _, _, _, needs_sync in planned if needs_sync),
    )

    async def process(plan: tuple[dict[str, Any], Path, Path, bool, bool]) -> tuple[bool, bool, str]:
        item, cache_path, asset_path, _, _ = plan
        async with sem:
            did_generate = await generate_item(item, cache_path, reporter=reporter)
        did_sync = False
        if not same_bytes(cache_path, asset_path):
            method = link_or_copy(cache_path, asset_path)
            did_sync = True
            reporter.update_status(to_sync=reporter.status.to_sync - 1)
            return did_generate, did_sync, f"{asset_path} <- {cache_path} ({method})"
        return did_generate, did_sync, f"{asset_path} is up to date"

    results = await asyncio.gather(*(process(plan) for plan in planned), return_exceptions=True)
    failed = False
    for result in results:
        if isinstance(result, Exception):
            failed = True
            reporter.update_status(ok=False)
            reporter.event(f"asset failed: {result}")
            continue
        did_generate, did_sync, message = result
        generated += int(did_generate)
        synced += int(did_sync)
        skipped += int(not did_generate and not did_sync)
        reporter.event(message)

    reporter.event(
        f"AIGC assets: {len(items)} found, {generated} generated, {synced} synced, {skipped} unchanged."
    )
    return 1 if failed else 0


async def compile_typst(args: argparse.Namespace, root: Path, reporter: Reporter | None = None) -> int:
    reporter = reporter or Reporter()
    typ_path = Path(args.typ_file)
    input_path = rel_path(typ_path, root)
    reporter.event("rendering ...")
    cmd = [
        *find_typst_command(),
        "compile",
        input_path,
        str(Path(args.output)),
        "--root",
        str(root),
    ]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        cwd=root,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if stdout:
        reporter.event(stdout.decode("utf-8", errors="replace").rstrip())
    if stderr:
        stderr_text = stderr.decode("utf-8", errors="replace").rstrip()
        if proc.returncode == 0:
            reporter.event(stderr_text)
        else:
            reporter.event(f"rendered failed: {stderr_text}")
    return proc.returncode


async def watch(args: argparse.Namespace) -> int:
    typ_path = Path(args.typ_file)
    if not typ_path.exists():
        raise AigcError(f"Typst file not found: {typ_path}")

    root = Path(args.root).resolve() if args.root else repo_root_for(typ_path)
    input_path = rel_path(typ_path, root)
    watch_out = os.devnull
    cmd = [
        *find_typst_command(),
        "watch",
        "--root",
        str(root),
        "--input",
        "aigc-mode=query",
        "--format",
        "pdf",
        input_path,
        watch_out,
    ]

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        cwd=root,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.PIPE,
    )
    assert proc.stderr is not None

    reporter = Reporter(live=True)
    try:
        with reporter:
            reporter.event("Starting typst watch trigger.")
            while True:
                raw_line = await proc.stderr.readline()
                if not raw_line:
                    return await proc.wait()
                line = raw_line.decode("utf-8", errors="replace").rstrip()
                if "compiled successfully" in line:
                    at = timestamp()
                    reporter.update_status(ok=True, at=at)
                    reporter.event(f"source changed detected at {at}, scanning ...")
                    await asyncio.sleep(args.debounce)
                    code = await update_assets(args, reporter=reporter)
                    if code != 0:
                        reporter.update_status(ok=False)
                        reporter.event(f"update-assets failed with exit code {code}")
                        continue
                    code = await compile_typst(args, root, reporter=reporter)
                    if code != 0:
                        reporter.update_status(ok=False)
                    else:
                        reporter.update_status(ok=True)
                        reporter.event(f"rendered {args.output}")
    finally:
        if proc.returncode is None:
            proc.terminate()
            try:
                await asyncio.wait_for(proc.wait(), timeout=3)
            except asyncio.TimeoutError:
                proc.kill()
                await proc.wait()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="aigc")
    sub = parser.add_subparsers(dest="command", required=True)

    update = sub.add_parser("update-assets", help="Generate missing AIGC assets for a Typst file.")
    update.add_argument("typ_file")
    update.add_argument("--root", help="Repository root. Defaults to the nearest .git or typlibs/slider parent.")
    update.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY)

    watch_cmd = sub.add_parser("watch", help="Watch Typst inputs, update AIGC assets, and compile output.")
    watch_cmd.add_argument("typ_file")
    watch_cmd.add_argument("output")
    watch_cmd.add_argument("--root", help="Repository root. Defaults to the nearest .git or typlibs/slider parent.")
    watch_cmd.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY)
    watch_cmd.add_argument("--debounce", type=float, default=DEFAULT_DEBOUNCE_SECONDS)
    return parser


async def main_async(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "update-assets":
        return await update_assets(args)
    if args.command == "watch":
        return await watch(args)
    raise AigcError(f"unknown command: {args.command}")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
    try:
        return asyncio.run(main_async(sys.argv[1:]))
    except AigcError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
