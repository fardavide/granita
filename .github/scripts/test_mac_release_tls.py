"""Download release artifacts securely without configured system CA roots."""

import io
import json
import ssl
from pathlib import Path
from urllib.request import BaseHandler, HTTPSHandler, Request

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
import pytest

import mac_release


class FakeNetwork:
    def __init__(self: "FakeNetwork") -> None:
        self.requests: list[tuple[str, str | None]] = []
        self.responses: dict[str, bytes] = {}

    def build_opener(
        self: "FakeNetwork",
        *handlers: BaseHandler,
    ) -> "FakeOpener":
        context: ssl.SSLContext | None = None
        for handler in handlers:
            if isinstance(handler, HTTPSHandler):
                candidate: object = getattr(handler, "_context", None)
                if isinstance(candidate, ssl.SSLContext):
                    context = candidate
        return FakeOpener(context=context, network=self)

    def urlopen(
        self: "FakeNetwork",
        url: str | Request,
        data: bytes | None = None,
        timeout: float = 60,
        *,
        context: ssl.SSLContext | None = None,
    ) -> io.BytesIO:
        tls = context if context is not None else ssl.create_default_context()
        assert tls.verify_mode == ssl.CERT_REQUIRED, "HTTPS must require a verified certificate"
        assert tls.check_hostname, "HTTPS must verify the server hostname"
        assert tls.get_ca_certs(), "HTTPS must have trusted CA roots when the system store is empty"
        request = url if isinstance(url, Request) else Request(url)
        self.requests.append((request.full_url, request.get_header("Authorization")))
        return io.BytesIO(self.responses[request.full_url])


class FakeOpener:
    def __init__(
        self: "FakeOpener",
        context: ssl.SSLContext | None,
        network: FakeNetwork,
    ) -> None:
        self.context = context
        self.network = network

    def open(
        self: "FakeOpener",
        fullurl: str | Request,
        data: bytes | None = None,
        timeout: float = 60,
    ) -> io.BytesIO:
        return self.network.urlopen(fullurl, data, timeout, context=self.context)


class FakeSystemTrust:
    @staticmethod
    def load_default_certs(
        context: ssl.SSLContext,
        purpose: ssl.Purpose = ssl.Purpose.SERVER_AUTH,
    ) -> None:
        pass

    @staticmethod
    def set_default_verify_paths(context: ssl.SSLContext) -> None:
        pass


class TestAppleClient:
    def test_given_empty_system_ca_store_when_downloading_then_verifies_both_hosts_and_keeps_the_token_on_the_api(
        self: "TestAppleClient",
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(directory=tmp_path, monkeypatch=monkeypatch)
        destination = tmp_path / "download" / "Granita-notarized.zip"

        # when
        scenario.sut.download("notarized-archive", destination)

        # then
        assert destination.read_bytes() == b"notarized archive bytes"
        assert len(scenario.network.requests) == 2
        metadata_url, authorization = scenario.network.requests[0]
        assert metadata_url == "https://api.appstoreconnect.apple.com/v1/ciArtifacts/notarized-archive"
        assert authorization is not None and authorization.startswith("Bearer ")
        assert scenario.network.requests[1] == ("https://artifacts.example.invalid/Granita.zip", None)

    class Scenario:
        def __init__(
            self: "TestAppleClient.Scenario",
            directory: Path,
            monkeypatch: pytest.MonkeyPatch,
        ) -> None:
            monkeypatch.setattr(ssl.SSLContext, "load_default_certs", FakeSystemTrust.load_default_certs)
            monkeypatch.setattr(ssl.SSLContext, "set_default_verify_paths", FakeSystemTrust.set_default_verify_paths)
            self.network = FakeNetwork()
            self.network.responses = {
                "https://api.appstoreconnect.apple.com/v1/ciArtifacts/notarized-archive": json.dumps({
                    "data": {"attributes": {"downloadUrl": "https://artifacts.example.invalid/Granita.zip"}},
                }).encode(),
                "https://artifacts.example.invalid/Granita.zip": b"notarized archive bytes",
            }
            monkeypatch.setattr(mac_release, "build_opener", self.network.build_opener)
            monkeypatch.setattr(mac_release, "urlopen", self.network.urlopen)
            key_file = directory / "AuthKey_RELEASE.p8"
            key_file.write_bytes(ec.generate_private_key(ec.SECP256R1()).private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.PKCS8,
                serialization.NoEncryption(),
            ))
            self.sut = mac_release.AppleClient(
                issuer_id="00000000-0000-0000-0000-000000000001",
                key_file=key_file,
                key_id="RELEASE",
            )
