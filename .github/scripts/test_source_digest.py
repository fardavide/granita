import pytest

import source_digest


class TestSourceDigest:
    def test_given_changed_source_after_build_when_stamp_validated_then_products_are_rejected(
        self: "TestSourceDigest",
    ) -> None:
        # given
        stamp = {
            "revision": "current-revision",
            "root": "/workspace/Granita",
            "run": "36548067764:1",
            "source_digest": "previous-source-digest",
            "toolchain": "Xcode 26.3 Swift 6.3",
        }

        # when
        with pytest.raises(ValueError, match="source digest") as error:
            source_digest.validate_build_stamp(
                stamp=stamp,
                revision="current-revision",
                run="36548067764:1",
                toolchain="Xcode 26.3 Swift 6.3",
                root="/workspace/Granita",
                source_digest="current-source-digest",
            )

        # then
        assert "previous-source-digest" in str(error.value)

    def test_given_pruned_xcode_pin_when_measured_then_digest_matches_full_lock(
        self: "TestSourceDigest",
    ) -> None:
        # given
        files = {"Sources/Feature.swift": b"struct Feature {}"}
        production_pin = {
            "identity": "hummingbird",
            "kind": "remoteSourceControl",
            "location": "https://github.com/hummingbird-project/hummingbird.git",
            "state": {"revision": "production-revision", "version": "2.0.0"},
        }
        snapshot_pin = {
            "identity": "swift-snapshot-testing",
            "kind": "remoteSourceControl",
            "location": "https://github.com/pointfreeco/swift-snapshot-testing.git",
            "state": {"revision": "snapshot-revision", "version": "1.0.0"},
        }
        committed = {"pins": [production_pin, snapshot_pin], "version": 3}
        pruned = {"pins": [production_pin], "version": 3}

        # when
        full_digest = source_digest.measurement_digest(files, committed, committed)
        pruned_digest = source_digest.measurement_digest(files, pruned, committed)

        # then
        assert pruned_digest == full_digest

    def test_given_changed_snapshot_bytes_when_measured_then_digest_changes(
        self: "TestSourceDigest",
    ) -> None:
        # given
        files = {"Apps/Tests/__Snapshots__/baseline.png": b"original image"}
        changed_files = {"Apps/Tests/__Snapshots__/baseline.png": b"changed image"}
        resolved = {"pins": [], "version": 3}

        # when
        original_digest = source_digest.measurement_digest(files, resolved, resolved)
        repeated_digest = source_digest.measurement_digest(files, resolved, resolved)
        changed_digest = source_digest.measurement_digest(changed_files, resolved, resolved)

        # then
        assert original_digest == repeated_digest
        assert original_digest != changed_digest
