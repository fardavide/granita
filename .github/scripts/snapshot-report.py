#!/usr/bin/env python3
"""Turn snapshot mismatches into one browsable HTML page.

A red snapshot job is only useful if you can see what moved. Uploading the `.xcresult` gives
hundreds of opaque files and needs Xcode to open; this pairs each freshly-rendered image with the
baseline it failed against and inlines both, so the artifact is a single self-contained page that
opens in any browser — including on a phone, which is where these get looked at.

    snapshot-report.py <failures-dir> <baselines-dir> <output-dir>

Exits 0 even with nothing to report. The step that runs it is guarded by `if: failure()`, and that
failure is often a build error or a crash rather than a mismatch — exiting non-zero there would turn
one failure into two and bury the real one.
"""

from __future__ import annotations

import base64
import html
import pathlib
import sys


def data_uri(path: pathlib.Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2

    failures, baselines, output = (pathlib.Path(p) for p in argv)
    output.mkdir(parents=True, exist_ok=True)

    rendered = sorted(failures.rglob("*.png")) if failures.is_dir() else []
    if not rendered:
        (output / "index.html").write_text(
            "<!doctype html><meta charset=utf-8><title>Snapshot report</title>"
            "<p>No snapshot mismatches were captured. The job failed for another reason — "
            "check the build and test logs.</p>"
        )
        print("No mismatches captured; wrote a placeholder report.")
        return 0

    sections = []
    for actual in rendered:
        relative = actual.relative_to(failures)
        expected = baselines / relative
        # The blend is what makes a subtle move visible: difference mode goes black where the two
        # agree, so anything non-black is exactly what changed.
        expected_cell = (
            f'<img src="{data_uri(expected)}" alt="baseline">' if expected.is_file()
            else "<p><em>No baseline on disk — this is a newly recorded snapshot.</em></p>"
        )
        difference = (
            f'<div class="diff"><img src="{data_uri(expected)}" alt="baseline">'
            f'<img class="over" src="{data_uri(actual)}" alt="rendered"></div>'
            if expected.is_file() else ""
        )
        sections.append(f"""
  <section>
    <h2>{html.escape(str(relative))}</h2>
    <div class="row">
      <figure><figcaption>Baseline (committed)</figcaption>{expected_cell}</figure>
      <figure><figcaption>Rendered (this run)</figcaption><img src="{data_uri(actual)}" alt="rendered"></figure>
      <figure><figcaption>Difference</figcaption>{difference}</figure>
    </div>
  </section>""")

    (output / "index.html").write_text(f"""<!doctype html>
<meta charset=utf-8>
<title>Snapshot report — {len(rendered)} mismatch(es)</title>
<style>
  body {{ font: 15px -apple-system, system-ui, sans-serif; margin: 2rem; background: #f6f6f8; color: #111; }}
  section {{ background: #fff; border-radius: 12px; padding: 1rem 1.25rem; margin-bottom: 1.5rem; }}
  h2 {{ font-size: 0.9rem; font-family: ui-monospace, monospace; font-weight: 600; word-break: break-all; }}
  .row {{ display: flex; gap: 1rem; flex-wrap: wrap; }}
  figure {{ margin: 0; flex: 1 1 260px; }}
  figcaption {{ font-size: 0.8rem; color: #666; margin-bottom: 0.4rem; }}
  img {{ width: 100%; border: 1px solid #ddd; border-radius: 6px; background: #fff; }}
  .diff {{ position: relative; }}
  .diff .over {{ position: absolute; inset: 0; mix-blend-mode: difference; }}
</style>
<h1>{len(rendered)} snapshot mismatch(es)</h1>
<p>Anything not black in the difference column is what changed. If the change is intended,
re-record the baselines <strong>locally</strong> and commit them — never on CI, which would turn the
test into a recorder of whatever the code currently does.</p>
{"".join(sections)}
""")
    print(f"Wrote a report for {len(rendered)} mismatch(es) to {output}/index.html")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
