"""Publish Xcode Cloud's notarized Mac export as a GitHub release."""

import argparse
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from dataclasses import dataclass
from email.message import Message
from enum import Enum
from pathlib import Path
from typing import BinaryIO, Protocol
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen

import jwt


@dataclass(frozen=True)
class CloudBuild:
    completion_status: str | None
    execution_progress: str
    identifier: str
    number: int


class PublicationState(Enum):
    Draft = "draft"
    Missing = "missing"
    Published = "published"


@dataclass(frozen=True)
class PublishOptions:
    app: Path
    build_number: int
    issuer_id: str
    key_file: Path
    key_id: str
    notes_file: Path
    output: Path
    repository: str
    revision: str
    version: str


class CloudClient(Protocol):
    def download(
        self: "CloudClient",
        artifact_id: str,
        destination: Path,
    ) -> None: ...

    def resources(self: "CloudClient", path: str) -> list[dict[str, object]]: ...


class NoApiRedirects(HTTPRedirectHandler):
    def redirect_request(
        self: "NoApiRedirects",
        req: Request,
        fp: BinaryIO | None,
        code: int,
        msg: str,
        headers: Message,
        newurl: str,
    ) -> None:
        raise ValueError("Refusing an authenticated App Store Connect redirect")


def request_json(url: str, bearer_token: str) -> object:
    request = Request(url, headers={"Authorization": f"Bearer {bearer_token}"})
    try:
        with build_opener(NoApiRedirects()).open(request, timeout=60) as response:
            return json.load(response)
    except HTTPError as error:
        raise ValueError(f"App Store Connect returned HTTP {error.code}") from None
    except URLError:
        raise ValueError("Could not connect to App Store Connect") from None


class AppleClient:
    def __init__(
        self: "AppleClient",
        issuer_id: str,
        key_file: Path,
        key_id: str,
        request: Callable[[str, str], object] = request_json,
    ) -> None:
        self.issuer_id = issuer_id
        self.key = key_file.read_text()
        self.key_id = key_id
        self.request = request

    def download(
        self: "AppleClient",
        artifact_id: str,
        destination: Path,
    ) -> None:
        document = mapping(self._get(f"https://api.appstoreconnect.apple.com/v1/ciArtifacts/{artifact_id}"))
        attributes = mapping(mapping(document.get("data")).get("attributes"))
        url = attributes.get("downloadUrl")
        if not isinstance(url, str) or urlparse(url).scheme != "https":
            raise ValueError("Missing HTTPS download URL for the notarized archive")
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Apple returns a temporary CDN URL. Never send the API bearer token to it.
        try:
            with urlopen(url, timeout=120) as response, destination.open("wb") as output:
                shutil.copyfileobj(response, output)
        except (HTTPError, URLError):
            raise ValueError("Could not download the notarized Xcode Cloud archive") from None

    def resources(self: "AppleClient", path: str) -> list[dict[str, object]]:
        url: str | None = f"https://api.appstoreconnect.apple.com/v1/{path}"
        result: list[dict[str, object]] = []
        while url is not None:
            document = mapping(self._get(url))
            data = document.get("data")
            if not isinstance(data, list):
                raise ValueError("Invalid API resource list")
            result.extend(mapping(resource) for resource in data)
            next_url = mapping(document.get("links", {})).get("next")
            if next_url is not None and not isinstance(next_url, str):
                raise ValueError("Invalid API pagination link")
            url = next_url
        return result

    def _get(self: "AppleClient", url: str) -> object:
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com" or not parsed.path.startswith("/v1/"):
            raise ValueError("Refusing an API URL outside Apple's origin")
        issued = int(time.time())
        token = jwt.encode(
            {"aud": "appstoreconnect-v1", "exp": issued + 600, "iat": issued, "iss": self.issuer_id},
            self.key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )
        return self.request(url, token)


def mapping(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or any(not isinstance(key, str) for key in value):
        raise ValueError("Invalid API object")
    return {str(key): item for key, item in value.items()}


def release_notes(changelog: str, version: str) -> str:
    heading = re.search(rf"^### {re.escape(version)} — \d{{4}}-\d{{2}}-\d{{2}}\s*$", changelog, re.MULTILINE)
    if heading is None:
        raise ValueError(f"No changelog entry for {version}")
    remainder = changelog[heading.end():]
    next_heading = re.search(r"^### ", remainder, re.MULTILINE)
    notes = remainder[:next_heading.start()] if next_heading else remainder
    if not notes.strip():
        raise ValueError(f"Empty changelog entry for {version}")
    return notes.strip() + "\n"


def project_version(manifest: str) -> str:
    versions = re.findall(r"^    MARKETING_VERSION: ([0-9]+\.[0-9]+\.[0-9]+)\s*$", manifest, re.MULTILINE)
    if len(versions) != 1:
        raise ValueError("Expected one shared MARKETING_VERSION in project.yml")
    return versions[0]


def select_build(builds: list[dict[str, object]], revision: str) -> CloudBuild | None:
    matches: list[CloudBuild] = []
    for build in builds:
        attributes = mapping(build.get("attributes"))
        source = mapping(attributes.get("sourceCommit"))
        if source.get("commitSha") != revision or attributes.get("isPullRequestBuild") is not False:
            continue
        identifier = build.get("id")
        number = attributes.get("number")
        progress = attributes.get("executionProgress")
        status = attributes.get("completionStatus")
        if not isinstance(identifier, str) or not isinstance(number, int) or isinstance(number, bool):
            raise ValueError("Invalid Xcode Cloud build identity")
        if not isinstance(progress, str) or not (status is None or isinstance(status, str)):
            raise ValueError("Invalid Xcode Cloud build status")
        matches.append(CloudBuild(status, progress, identifier, number))
    return max(matches, key=lambda build: build.number, default=None)


def fetch_notarized_export(
    client: CloudClient,
    output: Path,
    revision: str,
    workflow_id: str,
    timeout_seconds: int = 3600,
    interval_seconds: int = 30,
    wait: Callable[[float], None] = time.sleep,
    clock: Callable[[], float] = time.monotonic,
) -> tuple[Path, int]:
    deadline = clock() + timeout_seconds
    while clock() < deadline:
        build = select_build(client.resources(f"ciWorkflows/{workflow_id}/buildRuns?sort=-number&limit=200"), revision)
        if build is not None and build.execution_progress == "COMPLETE":
            if build.completion_status != "SUCCEEDED":
                raise ValueError(f"Xcode Cloud build {build.number} has failed status {build.completion_status}")
            actions = client.resources(f"ciBuildRuns/{build.identifier}/actions?limit=200")
            artifacts: list[dict[str, object]] = []
            for action in actions:
                identifier = action.get("id")
                if not isinstance(identifier, str):
                    raise ValueError("Invalid Xcode Cloud action identity")
                artifacts.extend(client.resources(f"ciBuildActions/{identifier}/artifacts?limit=200"))
            notarized = [artifact for artifact in artifacts if mapping(artifact.get("attributes")).get("fileType") == "STAPLED_NOTARIZED_ARCHIVE"]
            if len(notarized) != 1:
                raise ValueError("Expected exactly one stapled notarized Mac archive")
            identifier = notarized[0].get("id")
            if not isinstance(identifier, str):
                raise ValueError("Invalid notarized artifact identity")
            archive = output / "Granita-notarized.zip"
            client.download(identifier, archive)
            return archive, build.number
        print(f"Waiting for Xcode Cloud's notarized Mac build of {revision}", flush=True)
        wait(interval_seconds)
    raise ValueError("Timed out waiting for the notarized Mac build; check Xcode Cloud")


def publication_state(
    repository: str,
    revision: str,
    version: str,
    skip_published: bool = False,
) -> PublicationState:
    tag = f"v{version}"
    existing = subprocess.run([
        "gh", "api", f"repos/{repository}/releases?per_page=100", "--paginate",
        "--jq", f'.[] | select(.tag_name == "{tag}")',
    ], capture_output=True, check=True, text=True).stdout.strip()
    release = mapping(json.loads(existing)) if existing else None
    if skip_published and release is not None and release.get("draft") is False:
        return PublicationState.Published
    existing_tag = subprocess.run([
        "gh", "api", f"repos/{repository}/commits/{tag}", "--jq", ".sha",
    ], capture_output=True, check=False, text=True)
    if existing_tag.returncode == 0:
        if existing_tag.stdout.strip() != revision:
            raise ValueError(f"Tag {tag} already belongs to a different commit")
    elif (
        "HTTP 404" not in existing_tag.stderr
        and existing_tag.stderr.strip() != f"gh: No commit found for SHA: {tag} (HTTP 422)"
    ):
        raise ValueError("Could not check the release tag on GitHub")
    if release is None:
        return PublicationState.Missing
    if release.get("target_commitish") != revision and existing_tag.returncode != 0:
        raise ValueError(f"Draft {tag} already belongs to a different commit")
    if release.get("draft") is True:
        return PublicationState.Draft
    if release.get("draft") is False:
        return PublicationState.Published
    raise ValueError("Invalid GitHub release state")


def ensure_tag(repository: str, revision: str, version: str) -> None:
    tag = f"v{version}"
    existing = subprocess.run([
        "gh", "api", f"repos/{repository}/commits/{tag}", "--jq", ".sha",
    ], capture_output=True, check=False, text=True)
    if existing.returncode == 0:
        if existing.stdout.strip() != revision:
            raise ValueError(f"Tag {tag} already belongs to a different commit")
        return
    if (
        "HTTP 404" not in existing.stderr
        and existing.stderr.strip() != f"gh: No commit found for SHA: {tag} (HTTP 422)"
    ):
        raise ValueError("Could not check the release tag on GitHub")
    # Fix the exact target before draft creation. The release token has both Contents and
    # Workflows write permission, which GitHub can require when tagging historical commits.
    subprocess.run([
        "gh", "api", f"repos/{repository}/git/refs", "--method", "POST",
        "-f", f"ref=refs/tags/{tag}", "-f", f"sha={revision}",
    ], check=True)


def verify_app(
    app: Path,
    build_number: int,
    version: str,
) -> None:
    with (app / "Contents/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    expected = {
        "CFBundleIdentifier": "dev.fardavide.granita.mac",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": str(build_number),
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f"App {key} does not match {value}")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    signature = subprocess.run(
        ["codesign", "-dv", "--verbose=4", str(app)],
        capture_output=True,
        check=True,
        text=True,
    ).stderr
    if (
        not any(line.startswith("Authority=Developer ID Application:") for line in signature.splitlines())
        or "TeamIdentifier=A7Q83J6LR4" not in signature.splitlines()
    ):
        raise ValueError("App must be signed with Granita's Developer ID Application certificate")
    subprocess.run(["xcrun", "stapler", "validate", str(app)], check=True)


def create_dmg(
    app: Path,
    output: Path,
    version: str,
) -> Path:
    output.mkdir(parents=True, exist_ok=True)
    dmg = output / f"Granita-{version}.dmg"
    if dmg.exists():
        raise ValueError(f"Output already exists: {dmg}")
    with tempfile.TemporaryDirectory(prefix="granita-dmg-") as temporary:
        stage = Path(temporary) / "contents"
        stage.mkdir()
        subprocess.run(["ditto", str(app), str(stage / "Granita.app")], check=True)
        (stage / "Applications").symlink_to("/Applications")
        subprocess.run([
            "hdiutil", "create", "-volname", "Granita", "-srcfolder", str(stage),
            "-format", "UDZO", str(dmg),
        ], check=True)
    return dmg


def notarize_dmg(
    dmg: Path,
    issuer_id: str,
    key_file: Path,
    key_id: str,
) -> None:
    notarization = subprocess.run([
        "xcrun", "notarytool", "submit", str(dmg),
        "--key", key_file, "--key-id", key_id,
        "--issuer", issuer_id, "--wait", "--timeout", "30m",
        "--output-format", "json",
    ], capture_output=True, check=False, text=True)
    (dmg.parent / "notarization.json").write_text(notarization.stdout)
    result: object = json.loads(notarization.stdout)
    if notarization.returncode != 0 or not isinstance(result, dict) or result.get("status") != "Accepted":
        raise ValueError("Apple rejected DMG notarization; no release was published")
    subprocess.run(["xcrun", "stapler", "staple", str(dmg)], check=True)
    subprocess.run(["xcrun", "stapler", "validate", str(dmg)], check=True)
    subprocess.run(["hdiutil", "verify", str(dmg)], check=True)


def publish(arguments: PublishOptions) -> None:
    state = publication_state(arguments.repository, arguments.revision, arguments.version)
    tag = f"v{arguments.version}"
    if state is PublicationState.Published:
        print(f"Release {tag} is already published; leaving its assets unchanged")
        return
    verify_app(arguments.app, arguments.build_number, arguments.version)
    dmg = create_dmg(arguments.app, arguments.output, arguments.version)
    notarize_dmg(dmg, arguments.issuer_id, arguments.key_file, arguments.key_id)
    checksum = arguments.output / "SHA256SUMS"
    with dmg.open("rb") as image:
        digest = hashlib.file_digest(image, "sha256").hexdigest()
    checksum.write_text(f"{digest}  {dmg.name}\n")
    if state is PublicationState.Missing:
        ensure_tag(arguments.repository, arguments.revision, arguments.version)
        subprocess.run([
            "gh", "release", "create", tag, "--repo", arguments.repository,
            "--draft", "--verify-tag", "--target", arguments.revision, "--title", f"Granita {arguments.version}",
            "--notes-file", arguments.notes_file,
        ], check=True)
    subprocess.run([
        "gh", "release", "upload", tag, str(dmg), str(checksum), "--repo", arguments.repository, "--clobber",
    ], check=True)
    subprocess.run([
        "gh", "release", "edit", tag, "--repo", arguments.repository, "--draft=false",
    ], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    plan = commands.add_parser("plan", help="Preview the current version and changelog notes")
    plan.add_argument("--output", default=Path("build/release-plan"), type=Path)
    release = commands.add_parser("release", help="Download the notarized Cloud export, package and publish")
    release.add_argument("--workflow-id", required=True)
    publish_command = commands.add_parser("publish", help="Package an already notarized app and publish")
    publish_command.add_argument("--app", required=True, type=Path)
    publish_command.add_argument("--build-number", required=True, type=int)
    publish_command.add_argument("--notes-file", required=True, type=Path)
    publish_command.add_argument("--version", required=True)
    for command in (release, publish_command):
        for name in ("issuer-id", "key-id", "repository", "revision"):
            command.add_argument(f"--{name}", required=True)
        for name in ("key-file", "output"):
            command.add_argument(f"--{name}", required=True, type=Path)
    arguments = parser.parse_args()
    if arguments.command != "plan" and not re.fullmatch(r"[a-f0-9]{40}", arguments.revision):
        raise ValueError("Release revision must be a full commit SHA")
    if arguments.command in ("plan", "release"):
        version = project_version(Path("project.yml").read_text())
        notes = release_notes(Path("CHANGELOG.md").read_text(), version)
        arguments.output.mkdir(parents=True, exist_ok=True)
        notes_file = arguments.output / "release-notes.md"
        notes_file.write_text(notes)
        if arguments.command == "plan":
            print(f"Granita {version}\n\n{notes}")
            return
        if publication_state(arguments.repository, arguments.revision, version, skip_published=True) is PublicationState.Published:
            print(f"Version {version} is already published; bump the version for another release")
            return
        client = AppleClient(arguments.issuer_id, arguments.key_file, arguments.key_id)
        archive, build_number = fetch_notarized_export(
            client=client,
            output=arguments.output,
            revision=arguments.revision,
            workflow_id=arguments.workflow_id,
        )
        with tempfile.TemporaryDirectory(prefix="granita-cloud-export-") as temporary:
            exported = Path(temporary)
            subprocess.run(["ditto", "-x", "-k", str(archive), str(exported)], check=True)
            apps = [app for app in exported.rglob("Granita.app") if app.is_dir()]
            if len(apps) != 1:
                raise ValueError("Expected exactly one Granita.app in the notarized Cloud archive")
            publish(PublishOptions(
                app=apps[0], build_number=build_number, issuer_id=arguments.issuer_id,
                key_file=arguments.key_file, key_id=arguments.key_id, notes_file=notes_file,
                output=arguments.output, repository=arguments.repository, revision=arguments.revision,
                version=version,
            ))
    elif arguments.command == "publish":
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", arguments.version):
            raise ValueError("Release version must be a numeric major.minor.patch")
        publish(PublishOptions(
            app=arguments.app, build_number=arguments.build_number, issuer_id=arguments.issuer_id,
            key_file=arguments.key_file, key_id=arguments.key_id, notes_file=arguments.notes_file,
            output=arguments.output, repository=arguments.repository, revision=arguments.revision,
            version=arguments.version,
        ))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, jwt.PyJWTError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
