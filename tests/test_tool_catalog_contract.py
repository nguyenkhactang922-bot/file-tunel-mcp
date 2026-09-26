#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "contracts" / "tool_catalog.v1.json"
EXPECTED_CATALOG_VERSION = "1.2.0"
EXPECTED_INSTRUCTION_VERSION = "1.0.0"
EXPECTED_MODERN = "2026-07-28"
EXPECTED_LEGACY = ["2025-11-25", "2025-06-18", "2025-03-26"]
EXPECTED_HANDLERS = {"local_tools", "skills", "server"}
VALID_RISK = {"low", "medium", "high"}
VALID_EFFECT = {"read", "write", "delete", "execute", "external", "metadata"}


def fail(message: str) -> None:
    raise ValueError(message)


def need_dict(value, path: str):
    if not isinstance(value, dict):
        fail(f"{path} must be object")
    return value


def need_list(value, path: str):
    if not isinstance(value, list):
        fail(f"{path} must be array")
    return value


def need_string(value, path: str):
    if not isinstance(value, str) or not value.strip():
        fail(f"{path} must be non-empty string")
    return value


def validate_catalog(catalog: dict) -> None:
    need_dict(catalog, "root")
    if catalog.get("schemaVersion") != 1:
        fail("unsupported schemaVersion")
    catalog_version = need_string(catalog.get("catalogVersion"), "catalogVersion")
    if catalog_version != EXPECTED_CATALOG_VERSION:
        fail("unsupported catalogVersion")
    instruction_version = need_string(catalog.get("instructionVersion"), "instructionVersion")
    if instruction_version != EXPECTED_INSTRUCTION_VERSION:
        fail("unsupported instructionVersion")

    protocols = need_dict(catalog.get("protocolVersions"), "protocolVersions")
    if protocols.get("modern") != EXPECTED_MODERN:
        fail("modern protocol mismatch")
    legacy = need_list(protocols.get("legacy"), "protocolVersions.legacy")
    if legacy != EXPECTED_LEGACY:
        fail("legacy protocol order/set mismatch")

    instructions = need_dict(catalog.get("instructions"), "instructions")
    need_string(instructions.get("base"), "instructions.base")
    suffix = instructions.get("observabilitySuffix")
    if not isinstance(suffix, str) or not suffix:
        fail("instructions.observabilitySuffix must be string")

    facades = need_dict(catalog.get("facades"), "facades")
    correlation = need_dict(facades.get("correlationArgument"), "facades.correlationArgument")
    if correlation.get("name") != "_filemcp_chat":
        fail("correlation facade name mismatch")
    need_dict(correlation.get("definition"), "facades.correlationArgument.definition")

    tools = need_list(catalog.get("tools"), "tools")
    names: set[str] = set()
    for index, item in enumerate(tools):
        item = need_dict(item, f"tools[{index}]")
        name = need_string(item.get("name"), f"tools[{index}].name")
        if name in names:
            fail(f"duplicate tool {name}")
        names.add(name)
        handler = need_string(item.get("handler"), f"tools[{index}].handler")
        if handler not in EXPECTED_HANDLERS:
            fail(f"unknown handler {handler}")
        risk = need_string(item.get("risk"), f"tools[{index}].risk")
        if risk not in VALID_RISK:
            fail(f"invalid risk {risk}")
        effect = need_string(item.get("effect"), f"tools[{index}].effect")
        if effect not in VALID_EFFECT:
            fail(f"invalid effect {effect}")
        capabilities = need_list(item.get("capabilities"), f"tools[{index}].capabilities")
        if not capabilities or any(not isinstance(v, str) or not v for v in capabilities):
            fail(f"invalid capabilities for {name}")
        availability = need_dict(item.get("availability"), f"tools[{index}].availability")
        for key, value in availability.items():
            if key not in {"requiresCommands", "requiresObservability"} or not isinstance(value, bool):
                fail(f"invalid availability metadata for {name}")
        definition = need_dict(item.get("definition"), f"tools[{index}].definition")
        if definition.get("name") != name:
            fail(f"definition name mismatch for {name}")
        input_schema = need_dict(definition.get("inputSchema"), f"{name}.inputSchema")
        output_schema = need_dict(definition.get("outputSchema"), f"{name}.outputSchema")
        annotations = need_dict(definition.get("annotations"), f"{name}.annotations")
        if input_schema.get("type") != "object" or input_schema.get("additionalProperties") is not False:
            fail(f"invalid input schema envelope for {name}")
        need_dict(input_schema.get("properties"), f"{name}.inputSchema.properties")
        need_list(input_schema.get("required"), f"{name}.inputSchema.required")
        if output_schema.get("type") != "object":
            fail(f"invalid output schema envelope for {name}")
        for key in ("readOnlyHint", "destructiveHint", "openWorldHint"):
            if not isinstance(annotations.get(key), bool):
                fail(f"annotation {key} missing/invalid for {name}")

    if len(tools) != 20:
        fail(f"expected 20 tools, got {len(tools)}")

    by_name = {item["name"]: item for item in tools}
    exec_process = by_name["exec_process"]
    if exec_process["risk"] != "high" or exec_process["effect"] != "execute":
        fail("exec_process risk/effect mismatch")
    if exec_process["capabilities"] != ["process.exec", "network.open_world"]:
        fail("exec_process capabilities mismatch")
    if exec_process["availability"] != {}:
        fail("exec_process must be governed by policy rather than legacy requiresCommands")
    if by_name["run_command"]["availability"] != {"requiresCommands": True}:
        fail("run_command availability mismatch")
    if by_name["filemcp_observability_connect"]["availability"] != {"requiresObservability": True}:
        fail("observability availability mismatch")
    if by_name["git_push"]["risk"] != "high" or by_name["git_push"]["effect"] != "external":
        fail("git_push risk/effect mismatch")


def expect_invalid(base: dict, mutate, contains: str) -> None:
    case = copy.deepcopy(base)
    mutate(case)
    try:
        validate_catalog(case)
    except ValueError as exc:
        if contains.lower() not in str(exc).lower():
            raise AssertionError(f"negative case expected {contains!r}, got {exc!r}") from exc
        return
    raise AssertionError(f"negative case unexpectedly accepted: {contains}")


def normalized_catalog_bytes(raw: bytes) -> bytes:
    text = raw.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    return text.encode("utf-8")


def main() -> None:
    raw = CATALOG_PATH.read_bytes()
    catalog = json.loads(raw.decode("utf-8"))
    validate_catalog(catalog)

    expect_invalid(catalog, lambda c: c.__setitem__("schemaVersion", 2), "schemaVersion")
    expect_invalid(catalog, lambda c: c.__setitem__("catalogVersion", "0.9.0"), "catalogVersion")
    expect_invalid(catalog, lambda c: c.__setitem__("instructionVersion", "0.9.0"), "instructionVersion")
    expect_invalid(catalog, lambda c: c["tools"].append(copy.deepcopy(c["tools"][0])), "duplicate")
    expect_invalid(catalog, lambda c: c["tools"][0].pop("risk"), "risk")
    expect_invalid(catalog, lambda c: c["tools"][0].__setitem__("risk", "unknown"), "risk")
    expect_invalid(catalog, lambda c: c["tools"][0]["definition"].__setitem__("name", "wrong"), "definition name mismatch")
    expect_invalid(catalog, lambda c: c["tools"][0]["definition"]["inputSchema"].__setitem__("additionalProperties", True), "input schema")
    expect_invalid(catalog, lambda c: c["tools"][0].__setitem__("availability", {"unexpected": True}), "availability")
    expect_invalid(catalog, lambda c: c["protocolVersions"].__setitem__("modern", "stale-version"), "modern protocol")

    windows_tools = (ROOT / "windows/src/FileMCP.Core/LocalTools.cs").read_text(encoding="utf-8")
    mac_tools = (ROOT / "macos/LocalMCPServer.swift").read_text(encoding="utf-8")
    if "private static JsonObject Tool(" in windows_tools or "private func tool(" in mac_tools:
        raise AssertionError("runtime still contains an alternate hard-coded tool schema builder")
    if "CanonicalToolCatalog.ToolDefinitions" not in windows_tools:
        raise AssertionError("Windows LocalTools is not catalog-backed")
    if "CanonicalToolCatalog.shared.toolDefinitions" not in mac_tools:
        raise AssertionError("macOS LocalTools is not catalog-backed")

    digest = hashlib.sha256(normalized_catalog_bytes(raw)).hexdigest()
    print(f"tool-catalog-contract: ok (tools={len(catalog['tools'])}, sha256={digest})")


if __name__ == "__main__":
    main()