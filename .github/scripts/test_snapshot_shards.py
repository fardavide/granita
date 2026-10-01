import pytest

import snapshot_shards


class TestSnapshotShards:
    def test_given_missing_partition_method_when_verified_then_partition_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        identifiers = [
            "Bundle/SuiteA/testA()",
            "Bundle/SuiteA/testB()",
            "Bundle/SuiteB/testC()",
        ]
        plan = {
            "errors": [],
            "values": [{
                "disabledTests": [],
                "enabledTests": [{"identifier": identifier} for identifier in identifiers],
                "testPlan": "GranitaMobile",
            }],
        }
        shards = [[identifiers[0]], [identifiers[2]]]

        # when
        with pytest.raises(ValueError, match="partition") as error:
            snapshot_shards.verify_partition(plan, shards)

        # then
        assert identifiers[1] in str(error.value)

    def test_given_more_shards_than_suites_when_plan_created_then_count_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        plan = {
            "errors": [],
            "values": [{
                "disabledTests": [],
                "enabledTests": [{"identifier": "Bundle/SuiteA/testA()"}],
                "testPlan": "GranitaMobile",
            }],
        }
        durations = {"SuiteA": 10.0}

        # when
        # then
        with pytest.raises(ValueError, match="shard count"):
            snapshot_shards.create_plan(plan, durations, 2)

    def test_given_failed_argument_when_verified_then_inventory_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        expected_tests = ["Bundle/Suite/testA()"]
        inventory = {
            "testNodes": [{
                "children": [{"nodeType": "Arguments", "result": "Failed"}],
                "nodeIdentifier": "Suite/testA()",
                "nodeType": "Test Case",
                "result": "Passed",
            }],
        }

        # when
        # then
        with pytest.raises(ValueError, match="failed"):
            snapshot_shards.verify_completed_tests(expected_tests, inventory)

    def test_given_suite_methods_when_plan_created_then_suites_stay_together(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        identifiers = [
            "Bundle/SuiteA/testA()",
            "Bundle/SuiteA/testB()",
            "Bundle/SuiteB/testC()",
        ]
        plan = {
            "errors": [],
            "values": [{
                "disabledTests": [],
                "enabledTests": [{"identifier": identifier} for identifier in identifiers],
                "testPlan": "GranitaMobile",
            }],
        }
        durations = {"SuiteA": 10.0, "SuiteB": 1.0}

        # when
        shards = snapshot_shards.create_plan(plan, durations, 2)

        # then
        assert sorted(identifier for shard in shards for identifier in shard) == sorted(identifiers)
        assert any(identifiers[0] in shard and identifiers[1] in shard for shard in shards)

    def test_given_missing_completed_test_when_verified_then_inventory_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        expected_tests = ["Bundle/Suite/testA()", "Bundle/Suite/testB()"]
        inventory = {
            "testNodes": [{
                "nodeIdentifier": "Suite/testA()",
                "nodeType": "Test Case",
                "result": "Passed",
            }],
        }

        # when
        # then
        with pytest.raises(ValueError, match="inventory"):
            snapshot_shards.verify_completed_tests(expected_tests, inventory)

    def test_given_empty_enabled_tests_when_read_then_plan_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        plan = {
            "errors": [],
            "values": [{
                "disabledTests": [],
                "enabledTests": [],
                "testPlan": "GranitaMobile",
            }],
        }

        # when
        # then
        with pytest.raises(ValueError, match="empty"):
            snapshot_shards.planned_tests(plan)

    def test_given_disabled_tests_when_read_then_plan_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        plan = {
            "errors": [],
            "values": [{
                "disabledTests": [{"identifier": "Bundle/Suite/testDisabled()"}],
                "enabledTests": [{"identifier": "Bundle/Suite/testA()"}],
                "testPlan": "GranitaMobile",
            }],
        }

        # when
        # then
        with pytest.raises(ValueError, match="disabled"):
            snapshot_shards.planned_tests(plan)

    def test_given_enumeration_errors_when_read_then_plan_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        plan = {
            "errors": ["enumeration failed"],
            "values": [{
                "disabledTests": [],
                "enabledTests": [{"identifier": "Bundle/Suite/testA()"}],
                "testPlan": "GranitaMobile",
            }],
        }

        # when
        # then
        with pytest.raises(ValueError, match="enumeration"):
            snapshot_shards.planned_tests(plan)

    def test_given_enumerated_plan_when_read_then_all_enabled_identifiers_are_preserved(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        plan = {
            "errors": [],
            "values": [{
                "disabledTests": [],
                "enabledTests": [
                    {"identifier": "Bundle/Suite/testA()"},
                    {"identifier": "Bundle/Other/testB()"},
                ],
                "testPlan": "GranitaMobile",
            }],
        }

        # when
        identifiers = snapshot_shards.planned_tests(plan)

        # then
        assert identifiers == ["Bundle/Suite/testA()", "Bundle/Other/testB()"]

    def test_given_zero_shard_count_when_sharded_then_count_is_rejected(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        suite_durations = {"SuiteA": 100.0}

        # when
        # then
        with pytest.raises(ValueError, match="shard count"):
            snapshot_shards.balanced_shards(suite_durations, 0)

    def test_given_unequal_suite_durations_when_sharded_then_loads_are_balanced(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        suite_durations = {
            "SuiteA": 100.0,
            "SuiteB": 90.0,
            "SuiteC": 10.0,
            "SuiteD": 1.0,
        }

        # when
        shards = snapshot_shards.balanced_shards(suite_durations, 2)

        # then
        loads = [sum(suite_durations[suite] for suite in shard) for shard in shards]
        assert max(loads) - min(loads) <= 1.0

    def test_given_suite_durations_when_sharded_then_every_suite_appears_once(
        self: "TestSnapshotShards",
    ) -> None:
        # given
        suite_durations = {
            "SuiteA": 100.0,
            "SuiteB": 90.0,
            "SuiteC": 10.0,
            "SuiteD": 1.0,
        }

        # when
        shards = snapshot_shards.balanced_shards(suite_durations, 2)

        # then
        assert len(shards) == 2
        assert sorted(suite for shard in shards for suite in shard) == sorted(suite_durations)
