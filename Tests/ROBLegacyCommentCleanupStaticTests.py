#!/usr/bin/env python3
"""Static regression against disabled executable code in active legacy controllers."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATHS = (
    ROOT / "Consciousness" / "ConsciousViewController.mm",
    ROOT / "Consciousness" / "AppDelegate.m",
)

# Match source-shaped declarations/statements only. Ordinary lifecycle, safety,
# and protocol explanations are intentionally outside this test's scope.
EXECUTABLE_COMMENT_PATTERNS = (
    (
        "Objective-C declaration",
        re.compile(
            r"^(?:[-+]\s*\([^)]*\)\s*[A-Za-z_]|"
            r"@(?:property|interface|implementation|synthesize|dynamic)\b)"
        ),
    ),
    (
        "disabled compiler directive",
        re.compile(r"^#\s*(?:if|ifdef|ifndef|else|elif|endif|define|import|include|pragma)\b"),
    ),
    (
        "control-flow statement",
        re.compile(
            r"^(?:if\s*\(|else(?:\s+if\s*\(|\s*\{)|for\s*\(|while\s*\(|"
            r"switch\s*\(|return(?:\s|;|$)|do\s*\{)"
        ),
    ),
    (
        "C/Objective-C declaration",
        re.compile(
            r"^(?:(?:const|static|unsigned|signed)\s+)*"
            r"(?:BOOL|bool|char|short|int|long|float|double|NSInteger|NSUInteger|"
            r"CGFloat|NSTimeInterval|[A-Z][A-Za-z0-9_]*(?:\s*<[^>]+>)?)"
            r"(?:\s+\*?\s*|\s*\*\s*)[A-Za-z_]\w*\s*(?:=|;)"
        ),
    ),
    ("Objective-C message statement", re.compile(r"^\[[^\n]+\]\s*;")),
    (
        "property assignment",
        re.compile(
            r"^(?:self|[A-Za-z_]\w*)(?:\.|->)[A-Za-z_]\w*\s*"
            r"(?:=|\+=|-=|\*=|/=)"
        ),
    ),
    (
        "function call",
        re.compile(
            r"^(?:(?:[A-Za-z_]\w*\.)+[A-Za-z_]\w*[!?]?|"
            r"dispatch_(?:async|after|once)|NSLog|printf|assert)\s*\("
        ),
    ),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def leading_comment_payloads(source: str):
    in_block_comment = False
    for line_number, line in enumerate(source.splitlines(), start=1):
        remaining = line.lstrip()
        while True:
            if in_block_comment:
                end = remaining.find("*/")
                if end < 0:
                    yield line_number, remaining.lstrip("* ")
                    break
                yield line_number, remaining[:end].lstrip("* ")
                remaining = remaining[end + 2 :].lstrip()
                in_block_comment = False
                if not remaining:
                    break
                continue
            if remaining.startswith("//"):
                yield line_number, remaining[2:].lstrip()
                break
            if remaining.startswith("/*"):
                in_block_comment = True
                remaining = remaining[2:]
                continue
            break


def require_focused_matchers() -> None:
    explanatory_comments = (
        "Physical-action requests require an explicit opt-in after every launch.",
        "A second tap retries the same immutable stop command.",
        "The controller reports its status after pairing succeeds.",
    )
    executable_examples = (
        "[self startCapture];",
        "self.isSpeaking = YES;",
        "NSTimeInterval elapsed = CACurrentMediaTime();",
        "if (self.audioEngine.isRunning) {",
    )
    for comment in explanatory_comments:
        require(
            not any(pattern.search(comment) for _, pattern in EXECUTABLE_COMMENT_PATTERNS),
            f"Comment matcher became too broad for explanatory prose: {comment}",
        )
    for comment in executable_examples:
        require(
            any(pattern.search(comment) for _, pattern in EXECUTABLE_COMMENT_PATTERNS),
            f"Comment matcher stopped recognizing disabled code: {comment}",
        )


def main() -> None:
    require_focused_matchers()
    findings: list[str] = []
    for path in SOURCE_PATHS:
        require(path.is_file(), f"Missing active controller: {path.relative_to(ROOT)}")
        source = path.read_text(encoding="utf-8")
        require(
            re.search(r"^\s*#\s*if\s+(?:0|false)\b", source, re.MULTILINE) is None,
            f"{path.relative_to(ROOT)} still contains a disabled preprocessor block",
        )
        for line_number, payload in leading_comment_payloads(source):
            for description, pattern in EXECUTABLE_COMMENT_PATTERNS:
                if pattern.search(payload):
                    findings.append(
                        f"{path.relative_to(ROOT)}:{line_number}: "
                        f"{description}: {payload.strip()}"
                    )
                    break

    require(
        not findings,
        "Active ROBController files still contain commented-out executable code:\n"
        + "\n".join(findings),
    )
    print("ROBController active legacy files contain no commented-out executable code")


if __name__ == "__main__":
    main()
