"""Release publication stops when Apple rejects the installer."""

from pathlib import Path
import os
import plistlib
import shlex
import subprocess
import sys
import hashlib
import json


class TestMacRelease:
    def test_given_accepted_notarization_and_absent_version_tag_when_publishing_then_publishes_release_with_both_assets(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.environment["MAC_RELEASE_NOTARY_STATUS"] = "Accepted"
        scenario.environment["MAC_RELEASE_TAG_LOOKUP_ERROR"] = (
            "gh: No commit found for SHA: v0.22.0 (HTTP 422)"
        )

        # when
        result = subprocess.run(
            scenario.command,
            capture_output=True,
            check=False,
            env=scenario.environment,
            text=True,
        )

        # then
        assert result.returncode == 0, result.stderr
        calls = [shlex.split(line) for line in scenario.calls_file.read_text().splitlines()]
        create = next(index for index, call in enumerate(calls) if call[:3] == ["gh", "release", "create"])
        upload = next(index for index, call in enumerate(calls) if call[:3] == ["gh", "release", "upload"])
        publish = next(index for index, call in enumerate(calls) if call[:3] == ["gh", "release", "edit"])
        assert create < upload < publish
        assert "--draft" in calls[create]
        assert str(tmp_path / "dist/Granita-0.22.0.dmg") in calls[upload]
        assert str(tmp_path / "dist/SHA256SUMS") in calls[upload]
        assert "--draft=false" in calls[publish]

    def test_given_other_signing_team_when_publishing_then_rejects_before_packaging(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.environment["MAC_RELEASE_SIGNING_TEAM"] = "A7Q83J6LR4OTHER"
        scenario.environment["MAC_RELEASE_NOTARY_STATUS"] = "Accepted"
        # when
        result = subprocess.run(scenario.command, capture_output=True, check=False, env=scenario.environment, text=True)
        # then
        assert result.returncode != 0
        assert "certificate" in result.stderr
        calls = [shlex.split(line) for line in scenario.calls_file.read_text().splitlines()]
        assert not any(call[0] == "hdiutil" for call in calls)

    def test_given_rejected_notarization_when_release_fails_then_keeps_apple_diagnostics(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        # when
        result = subprocess.run(scenario.command, capture_output=True, check=False, env=scenario.environment, text=True)
        # then
        assert result.returncode != 0
        assert json.loads((tmp_path / "dist/notarization.json").read_text())["status"] == "Invalid"

    def test_given_existing_draft_when_retrying_then_completes_draft_without_creating_another_release(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.environment["MAC_RELEASE_NOTARY_STATUS"] = "Accepted"
        scenario.environment["MAC_RELEASE_DRAFT"] = "true"
        # when
        result = subprocess.run(scenario.command, capture_output=True, check=False, env=scenario.environment, text=True)
        # then
        assert result.returncode == 0, result.stderr
        calls = [shlex.split(line) for line in scenario.calls_file.read_text().splitlines()]
        assert not any(call[:3] == ["gh", "release", "create"] for call in calls)
        assert any(call[:3] == ["gh", "release", "upload"] and "--clobber" in call for call in calls)
        assert any(call[:3] == ["gh", "release", "edit"] and "--draft=false" in call for call in calls)

    def test_given_existing_tag_for_another_commit_when_publishing_then_refuses_before_packaging(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.environment["MAC_RELEASE_NOTARY_STATUS"] = "Accepted"
        scenario.environment["MAC_RELEASE_TAG_REVISION"] = "b" * 40
        # when
        result = subprocess.run(scenario.command, capture_output=True, check=False, env=scenario.environment, text=True)
        # then
        assert result.returncode != 0
        assert "commit" in result.stderr.lower()
        calls = [shlex.split(line) for line in scenario.calls_file.read_text().splitlines()]
        assert not any(call[0] == "hdiutil" or call[:2] == ["gh", "release"] for call in calls)

    def test_given_accepted_dmg_when_publishing_then_uploads_assets_before_publication(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.environment["MAC_RELEASE_NOTARY_STATUS"] = "Accepted"

        # when
        result = subprocess.run(scenario.command, capture_output=True, check=False, env=scenario.environment, text=True)

        # then
        assert result.returncode == 0, result.stderr
        calls = [shlex.split(line) for line in scenario.calls_file.read_text().splitlines()]
        create = next(index for index, call in enumerate(calls) if call[:3] == ["gh", "release", "create"])
        upload = next(index for index, call in enumerate(calls) if call[:3] == ["gh", "release", "upload"])
        publish = next(index for index, call in enumerate(calls) if call[:3] == ["gh", "release", "edit"])
        assert create < upload < publish
        tag = next(index for index, call in enumerate(calls) if call[:2] == ["gh", "api"] and "POST" in call and call[2].endswith("/git/refs"))
        assert tag < create
        assert "sha=" + "a" * 40 in calls[tag]
        assert "--draft" in calls[create]
        assert "--verify-tag" in calls[create]
        assert "--draft=false" in calls[publish]
        assert calls[create][calls[create].index("--target") + 1] == "a" * 40
        dmg = tmp_path / "dist/Granita-0.22.0.dmg"
        checksum = hashlib.sha256(dmg.read_bytes()).hexdigest()
        assert (tmp_path / "dist/SHA256SUMS").read_text() == f"{checksum}  {dmg.name}\n"
        assert any(call[:3] == ["xcrun", "stapler", "validate"] and call[-1] == str(dmg) for call in calls)

    def test_given_signed_app_when_dmg_notarization_is_rejected_then_release_is_unpublished(
        self: "TestMacRelease",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)

        # when
        result = subprocess.run(
            scenario.command,
            capture_output=True,
            check=False,
            env=scenario.environment,
            text=True,
        )

        # then
        calls = [
            shlex.split(line)
            for line in scenario.calls_file.read_text().splitlines()
        ]
        assert any(
            call[:3] == ["xcrun", "notarytool", "submit"]
            and any(argument.endswith(".dmg") for argument in call[3:])
            for call in calls
        ), result.stderr
        assert result.returncode != 0, result.stdout
        assert not any(
            call[:2] == ["gh", "release"]
            and len(call) > 2
            and call[2] in {"create", "edit", "upload"}
            for call in calls
        ), calls

    class Scenario:
        def __init__(
            self: "TestMacRelease.Scenario",
            directory: Path,
        ) -> None:
            root = Path(__file__).resolve().parents[2]
            app = directory / "Granita.app"
            contents = app / "Contents"
            contents.mkdir(parents=True)
            with (contents / "Info.plist").open("wb") as plist_file:
                plistlib.dump(
                    {
                        "CFBundleIdentifier": "dev.fardavide.granita.mac",
                        "CFBundleShortVersionString": "0.22.0",
                        "CFBundleVersion": "42",
                    },
                    plist_file,
                )
            self.calls_file = directory / "calls.txt"
            self.calls_file.touch()
            executables = directory / "bin"
            executables.mkdir()
            fake_command = f"#!{sys.executable}\n" + '''\
from pathlib import Path
import json
import os
import shlex
import shutil
import sys

command = Path(sys.argv[0]).name
arguments = sys.argv[1:]
with Path(os.environ["MAC_RELEASE_CALLS_FILE"]).open("a") as calls_file:
    calls_file.write(shlex.join([command, *arguments]) + "\\n")

if command == "codesign":
    if any(argument.startswith("-d") for argument in arguments):
        print("Authority=Developer ID Application: Davide Fardella (A7Q83J6LR4)", file=sys.stderr)
        print("TeamIdentifier=" + os.environ.get("MAC_RELEASE_SIGNING_TEAM", "A7Q83J6LR4"), file=sys.stderr)
elif command == "ditto":
    shutil.copytree(arguments[-2], arguments[-1], dirs_exist_ok=True)
elif command == "hdiutil":
    destination = next(Path(argument) for argument in arguments if argument.endswith(".dmg"))
    destination.parent.mkdir(parents=True, exist_ok=True)
    if arguments[0] == "create":
        source = Path(arguments[arguments.index("-srcfolder") + 1])
        assert (source / "Granita.app/Contents/Info.plist").is_file()
        assert (source / "Applications").readlink() == Path("/Applications")
        destination.write_bytes(b"fake disk image")
elif command == "xcrun":
    if arguments[:2] == ["notarytool", "submit"]:
        print(json.dumps({"id": "00000000-0000-0000-0000-000000000042", "status": os.environ.get("MAC_RELEASE_NOTARY_STATUS", "Invalid")}))
    elif arguments[:2] not in (["stapler", "validate"], ["stapler", "staple"]):
        sys.exit("Unexpected xcrun invocation: " + shlex.join(arguments))
elif command == "gh":
    if arguments[0] == "api" and arguments[1].endswith("/releases?per_page=100"):
        if os.environ.get("MAC_RELEASE_DRAFT"):
            print(json.dumps({"draft": True, "target_commitish": "a" * 40, "assets": []}))
        sys.exit(0)
    if arguments[0] == "api" and "/commits/v" in arguments[1]:
        revision = os.environ.get("MAC_RELEASE_TAG_REVISION")
        if revision:
            print(revision)
            sys.exit(0)
        print(os.environ.get("MAC_RELEASE_TAG_LOOKUP_ERROR", "gh: Not Found (HTTP 404)"), file=sys.stderr)
        sys.exit(1)
    if arguments[0] == "api" and "/releases/tags/" in arguments[1]:
        print("gh: Not Found (HTTP 404)", file=sys.stderr)
        sys.exit(1)
    print("https://github.com/fardavide/granita/releases/tag/v0.22.0")
else:
    sys.exit("Unexpected executable: " + command)
'''
            for name in ("codesign", "ditto", "gh", "hdiutil", "xcrun"):
                executable = executables / name
                executable.write_text(fake_command)
                executable.chmod(0o755)
            key_file = directory / "AuthKey_KEY123.p8"
            key_file.write_text("fake notarization key")
            notes_file = directory / "notes.md"
            notes_file.write_text("Mac installer release acceptance fixture.\n")
            self.environment = {
                **os.environ,
                "MAC_RELEASE_CALLS_FILE": str(self.calls_file),
                "PATH": str(executables) + os.pathsep + os.environ["PATH"],
            }
            self.command = [
                sys.executable,
                str(root / ".github/scripts/mac_release.py"),
                "publish",
                "--app", str(app),
                "--version", "0.22.0",
                "--build-number", "42",
                "--revision", "a" * 40,
                "--repository", "fardavide/granita",
                "--key-file", str(key_file),
                "--key-id", "KEY123",
                "--issuer-id", "00000000-0000-0000-0000-000000000001",
                "--output", str(directory / "dist"),
                "--notes-file", str(notes_file),
            ]
