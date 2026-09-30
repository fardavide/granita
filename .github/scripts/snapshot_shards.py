"""Assign whole serialized suites to isolated snapshot processes."""

import json
import sys
from pathlib import Path


def balanced_shards(
    suite_durations: dict[str, float],
    count: int,
) -> list[list[str]]:
    if count < 1:
        raise ValueError("The shard count must be positive")
    shards: list[list[str]] = [[] for _ in range(count)]
    loads = [0.0] * count
    for suite in sorted(suite_durations, key=lambda name: (-suite_durations[name], name)):
        index = min(range(count), key=lambda shard: (loads[shard], shard))
        shards[index].append(suite)
        loads[index] += suite_durations[suite]
    return shards


def planned_tests(plan: object) -> list[str]:
    if not isinstance(plan, dict) or not isinstance(plan.get("values"), list):
        raise ValueError("Invalid snapshot test plan")
    if plan.get("errors") != []:
        raise ValueError("Snapshot test enumeration failed")
    identifiers: list[str] = []
    for configuration in plan["values"]:
        if not isinstance(configuration, dict) or not isinstance(configuration.get("enabledTests"), list):
            raise ValueError("Invalid snapshot test configuration")
        if configuration.get("disabledTests") != []:
            raise ValueError("Snapshot test plan contains disabled tests")
        for test in configuration["enabledTests"]:
            if not isinstance(test, dict) or not isinstance(test.get("identifier"), str):
                raise ValueError("Invalid snapshot test identifier")
            identifiers.append(test["identifier"])
    if not identifiers:
        raise ValueError("Snapshot test plan is empty")
    return identifiers


def create_plan(
    plan: object,
    durations: dict[str, float],
    count: int,
) -> list[list[str]]:
    tests = planned_tests(plan)
    suites = {identifier.split("/")[1] for identifier in tests}
    if count > len(suites):
        raise ValueError("The shard count exceeds the number of suites")
    assignments = balanced_shards({suite: durations.get(suite, 1.0) for suite in suites}, count)
    return [
        sorted(identifier for identifier in tests if identifier.split("/")[1] in assignment)
        for assignment in assignments
    ]


def verify_partition(plan: object, shards: list[list[str]]) -> None:
    expected = planned_tests(plan)
    actual = [identifier for shard in shards for identifier in shard]
    if not all(shards) or sorted(actual) != sorted(expected):
        raise ValueError(f"Snapshot partition inventory differs: {sorted(set(expected) ^ set(actual))}")


def verify_completed_tests(
    expected_tests: list[str],
    inventory: object,
) -> None:
    completed: list[str] = []
    remaining: list[object] = [inventory]
    while remaining:
        node = remaining.pop()
        if isinstance(node, dict):
            if node.get("nodeType") in ("Test Case", "Arguments") and node.get("result") != "Passed":
                raise ValueError(f"Snapshot test failed or did not execute: {node.get('name', node.get('nodeIdentifier'))}")
            if node.get("nodeType") == "Test Case":
                identifier = node.get("nodeIdentifier")
                if not isinstance(identifier, str):
                    raise ValueError("Invalid snapshot test inventory identifier")
                completed.append(identifier)
            remaining.extend(node.values())
        elif isinstance(node, list):
            remaining.extend(node)
    expected = [identifier.split("/", 1)[1] for identifier in expected_tests]
    if sorted(completed) != sorted(expected):
        raise ValueError(f"Snapshot test inventory differs: {sorted(set(expected) ^ set(completed))}")


if __name__ == "__main__":
    match sys.argv[1]:
        case "plan":
            enumeration: object = json.loads(Path(sys.argv[2]).read_text())
            weights: object = json.loads(Path(sys.argv[3]).read_text())
            if not isinstance(weights, dict) or not isinstance(weights.get("durations"), dict):
                raise ValueError("Invalid snapshot durations")
            durations: dict[str, float] = {}
            for suite, duration in weights["durations"].items():
                if not isinstance(suite, str) or not isinstance(duration, (int, float)):
                    raise ValueError("Invalid snapshot duration")
                durations[suite] = float(duration)
            destination = Path(sys.argv[4])
            destination.mkdir(parents=True, exist_ok=True)
            for index, tests in enumerate(create_plan(enumeration, durations, int(sys.argv[5]))):
                (destination / f"shard-{index}.txt").write_text("\n".join(tests) + "\n")
                (destination / f"shard-{index}.json").write_text(json.dumps(tests))
        case "verify":
            expected: object = json.loads(Path(sys.argv[2]).read_text())
            if not isinstance(expected, list) or not all(isinstance(item, str) for item in expected):
                raise ValueError("Invalid expected snapshot tests")
            verify_completed_tests(expected, json.loads(Path(sys.argv[3]).read_text()))
        case "partition":
            plan: object = json.loads(Path(sys.argv[2]).read_text())
            shards: list[list[str]] = []
            for path in sys.argv[3:]:
                shard: object = json.loads(Path(path).read_text())
                if not isinstance(shard, list) or not all(isinstance(item, str) for item in shard):
                    raise ValueError("Invalid snapshot partition")
                shards.append(shard)
            verify_partition(plan, shards)
        case _:
            raise ValueError("Expected plan or verify")
