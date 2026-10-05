"""Read every page of App Store Connect release resources."""

from pathlib import Path
from email.message import Message
from urllib.request import Request

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

import mac_release
import jwt
import pytest


class FakeAppleRequest:
    def __init__(self: "FakeAppleRequest") -> None:
        self.calls: list[tuple[str, str]] = []
        self.responses: dict[str, object] = {
            "https://api.appstoreconnect.apple.com/v1/ciWorkflows/workflow/buildRuns?limit=200": {
                "data": [{"attributes": {}, "id": "one"}],
                "links": {
                    "next": "https://api.appstoreconnect.apple.com/v1/page2",
                },
            },
            "https://api.appstoreconnect.apple.com/v1/page2": {
                "data": [{"attributes": {}, "id": "two"}],
                "links": {"next": None},
            },
        }

    def __call__(
        self: "FakeAppleRequest",
        url: str,
        bearer_token: str,
    ) -> object:
        self.calls.append((url, bearer_token))
        return self.responses[url]


class TestAppleClient:
    def test_given_authenticated_api_request_when_redirected_then_does_not_follow_redirect(self: "TestAppleClient") -> None:
        # given
        handler = mac_release.NoApiRedirects()
        request = Request("https://api.appstoreconnect.apple.com/v1/ciProducts", headers={"Authorization": "Bearer test"})
        # when
        with pytest.raises(ValueError, match="redirect"):
            handler.redirect_request(request, None, 302, "Found", Message(), "https://example.invalid")
        # then

    def test_given_cross_origin_next_page_when_read_then_rejects_before_sending_credentials(
        self: "TestAppleClient",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        first_page = "https://api.appstoreconnect.apple.com/v1/ciWorkflows/workflow/buildRuns?limit=200"
        scenario.request.responses[first_page] = {
            "data": [{"attributes": {}, "id": "one"}],
            "links": {"next": "https://example.invalid/stolen"},
        }

        # when
        with pytest.raises(ValueError, match="(?i)origin|host|apple"):
            scenario.sut.resources("ciWorkflows/workflow/buildRuns?limit=200")

        # then
        assert [url for url, _ in scenario.request.calls] == [first_page]

    def test_given_paginated_resources_when_read_then_returns_resources_from_every_page(
        self: "TestAppleClient",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)

        # when
        resources = scenario.sut.resources(
            "ciWorkflows/workflow/buildRuns?limit=200",
        )

        # then
        assert [resource["id"] for resource in resources] == ["one", "two"]
        assert len(scenario.request.calls) == 2

    def test_given_signing_key_when_resources_requested_then_token_has_verified_release_claims(
        self: "TestAppleClient",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)

        # when
        scenario.sut.resources("ciWorkflows/workflow/buildRuns?limit=200")

        # then
        token = scenario.request.calls[0][1]
        claims = jwt.decode(
            token,
            scenario.public_key,
            algorithms=["ES256"],
            audience="appstoreconnect-v1",
        )
        assert claims["iss"] == "00000000-0000-0000-0000-000000000001"
        assert jwt.get_unverified_header(token)["kid"] == "KEY123"
        assert isinstance(claims["iat"], int)
        assert isinstance(claims["exp"], int)
        assert 0 < claims["exp"] - claims["iat"] <= 1200

    class Scenario:
        def __init__(
            self: "TestAppleClient.Scenario",
            directory: Path,
        ) -> None:
            key = ec.generate_private_key(ec.SECP256R1())
            self.public_key = key.public_key()
            key_file = directory / "AuthKey_KEY123.p8"
            key_file.write_bytes(
                key.private_bytes(
                    serialization.Encoding.PEM,
                    serialization.PrivateFormat.PKCS8,
                    serialization.NoEncryption(),
                ),
            )
            self.request = FakeAppleRequest()
            self.sut = mac_release.AppleClient(
                issuer_id="00000000-0000-0000-0000-000000000001",
                key_file=key_file,
                key_id="KEY123",
                request=self.request,
            )
