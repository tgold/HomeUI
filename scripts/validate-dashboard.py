#!/usr/bin/env python3
"""Validate dashboard.json using the same rules as DashboardConfig.cpp."""

import json
import sys
from pathlib import Path

VALID_PANEL_TYPES = {
    "room", "energy", "camera", "mode", "controls", "mqtt",
    "sonos", "grafana", "irrigationFloorplan", "schematic",
}
VALID_CONTROL_KINDS = {
    "switch", "dimmer", "color", "shutter", "thermostat", "scene",
    "progress", "gauge", "selector", "dropdown", "value",
}
VALID_CAMERA_FORMATS = {"mjpeg", "snapshot", "placeholder"}
VALID_LAYOUTS = {"columns", "grid", "masonry"}


def has_object_list(obj: dict, key: str) -> bool:
    value = obj.get(key)
    if not isinstance(value, list) or not value:
        return False
    return all(isinstance(entry, dict) for entry in value)


def validate_panel(panel: dict, path: str, errors: list[str]) -> None:
    panel_type = panel.get("type", "")
    if panel_type not in VALID_PANEL_TYPES:
        errors.append(
            f"{path}.type must be one of: {', '.join(sorted(VALID_PANEL_TYPES))}"
        )
        return

    if panel_type == "controls":
        controls = panel.get("controls")
        if not isinstance(controls, list):
            errors.append(f"{path}.controls must be an array of control objects")
            return
        for index, control in enumerate(controls):
            control_path = f"{path}.controls[{index}]"
            if not isinstance(control, dict):
                errors.append(f"{control_path} must be an object")
                continue
            kind = (control.get("kind") or control.get("widget") or "").lower()
            if kind and kind not in VALID_CONTROL_KINDS:
                errors.append(
                    f"{control_path}.kind must be one of: "
                    f"{', '.join(sorted(VALID_CONTROL_KINDS))}"
                )
            if kind in ("selector", "dropdown"):
                options = control.get("options")
                if not isinstance(options, list) or not options:
                    errors.append(
                        f"{control_path}.options must be a non-empty array for {kind} controls"
                    )

    if panel_type == "sonos":
        if not isinstance(panel.get("items"), dict):
            errors.append(f"{path}.items must be an object of role->item mappings")
        favorites = panel.get("favorites")
        if favorites is not None and not isinstance(favorites, list):
            errors.append(f"{path}.favorites must be an array of {{label, command}} objects")

    if panel_type == "mqtt" and not has_object_list(panel, "items"):
        errors.append(f"{path}.items must be an array of mqtt entries")

    if panel_type == "camera":
        fmt = panel.get("format")
        if fmt and str(fmt).lower() not in VALID_CAMERA_FORMATS:
            errors.append(
                f"{path}.format must be one of: {', '.join(sorted(VALID_CAMERA_FORMATS))}"
            )

    if panel_type == "grafana":
        if not str(panel.get("baseUrl", "")).strip():
            errors.append(f"{path}.baseUrl must be a non-empty Grafana base URL")
        if not str(panel.get("dashboardUid", "")).strip():
            errors.append(f"{path}.dashboardUid must be a non-empty Grafana dashboard UID")
        panel_id = panel.get("panelId")
        try:
            panel_id_int = int(panel_id)
        except (TypeError, ValueError):
            panel_id_int = 0
        if panel_id_int <= 0:
            errors.append(f"{path}.panelId must be a positive integer Grafana panel id")
        extra = panel.get("extraParams")
        if extra is not None and not isinstance(extra, dict):
            errors.append(f"{path}.extraParams must be an object of key/value query parameters")

    if panel_type == "irrigationFloorplan":
        if not str(panel.get("imageSource", "")).strip():
            errors.append(f"{path}.imageSource must be a non-empty image path/url")
        zones = panel.get("zones")
        if not isinstance(zones, list) or not zones:
            errors.append(f"{path}.zones must contain at least one zone")
        else:
            for index, zone in enumerate(zones):
                zone_path = f"{path}.zones[{index}]"
                if not isinstance(zone, dict):
                    errors.append(f"{zone_path} must be an object")
                    continue
                if not str(zone.get("label", "")).strip():
                    errors.append(f"{zone_path}.label must be set")
                for coord in ("x", "y"):
                    if coord not in zone:
                        errors.append(f"{zone_path}.{coord} must be set")
                        continue
                    value = zone[coord]
                    if not isinstance(value, (int, float)) or value < 0 or value > 1:
                        errors.append(f"{zone_path}.x and {zone_path}.y must be numbers between 0 and 1")
                if not str(zone.get("activityItem", "")).strip():
                    errors.append(f"{zone_path}.activityItem must be set")

        sensors = panel.get("sensors")
        if sensors is not None:
            if not isinstance(sensors, list):
                errors.append(f"{path}.sensors must be an array of sensor objects")
            else:
                for index, sensor in enumerate(sensors):
                    sensor_path = f"{path}.sensors[{index}]"
                    if not isinstance(sensor, dict):
                        errors.append(f"{sensor_path} must be an object")
                        continue
                    if not str(sensor.get("label", "")).strip():
                        errors.append(f"{sensor_path}.label must be set")
                    if not str(sensor.get("item", "")).strip():
                        errors.append(f"{sensor_path}.item must be set")

    if panel_type == "schematic":
        labels = panel.get("labels")
        controls = panel.get("controls")
        has_labels = isinstance(labels, list) and len(labels) > 0
        has_controls = isinstance(controls, list) and len(controls) > 0
        if not has_labels and not has_controls:
            errors.append(f"{path} must define labels and/or controls arrays")
        if has_labels:
            for index, label in enumerate(labels):
                label_path = f"{path}.labels[{index}]"
                if not isinstance(label, dict):
                    errors.append(f"{label_path} must be an object")
                    continue
                if not str(label.get("label", "")).strip():
                    errors.append(f"{label_path}.label must be set")
                for coord in ("x", "y"):
                    value = label.get(coord)
                    if not isinstance(value, (int, float)) or value < 0 or value > 1:
                        errors.append(
                            f"{label_path}.x and {label_path}.y must be numbers between 0 and 1"
                        )
                if not str(label.get("item", "")).strip() and "value" not in label:
                    errors.append(f"{label_path}.item must be set unless value is provided")
        if has_controls:
            for index, control in enumerate(controls):
                control_path = f"{path}.controls[{index}]"
                if not isinstance(control, dict):
                    errors.append(f"{control_path} must be an object")
                    continue
                if not str(control.get("label", "")).strip():
                    errors.append(f"{control_path}.label must be set")
                gutter = str(control.get("gutter", "")).strip().lower()
                if gutter and gutter not in ("left", "right"):
                    errors.append(f"{control_path}.gutter must be 'left' or 'right' when set")
                if gutter not in ("left", "right"):
                    for coord in ("x", "y"):
                        value = control.get(coord)
                        if not isinstance(value, (int, float)) or value < 0 or value > 1:
                            errors.append(
                                f"{control_path}.x and {control_path}.y must be numbers between 0 and 1"
                            )
                kind = (control.get("kind") or control.get("widget") or "").lower()
                if kind in ("selector", "dropdown"):
                    options = control.get("options")
                    if not isinstance(options, list) or not options:
                        errors.append(
                            f"{control_path}.options must be a non-empty array for {kind} controls"
                        )


def validate_page(page: dict, page_path: str, errors: list[str]) -> None:
    if not str(page.get("title", "")).strip():
        errors.append(f"{page_path}.title must be set")
    layout = page.get("layout", "columns")
    if layout not in VALID_LAYOUTS:
        errors.append(f"{page_path}.layout must be 'columns', 'grid' or 'masonry'")
        return

    if layout == "columns":
        if not has_object_list(page, "columns"):
            errors.append(f"{page_path}.columns must contain at least one column")
            return
        for column_index, column in enumerate(page["columns"]):
            column_path = f"{page_path}.columns[{column_index}]"
            if not has_object_list(column, "panels"):
                errors.append(f"{column_path}.panels must contain at least one panel")
                continue
            for panel_index, panel in enumerate(column["panels"]):
                validate_panel(panel, f"{column_path}.panels[{panel_index}]", errors)
    else:
        if not has_object_list(page, "panels"):
            errors.append(f"{page_path}.panels must contain at least one panel")
            return
        for panel_index, panel in enumerate(page["panels"]):
            validate_panel(panel, f"{page_path}.panels[{panel_index}]", errors)


def validate_config(config: dict) -> list[str]:
    errors: list[str] = []
    pages = config.get("pages")
    if not isinstance(pages, list) or not pages:
        errors.append("'pages' must be a non-empty array of page objects")
        return errors
    for page_index, page in enumerate(pages):
        if not isinstance(page, dict):
            errors.append(f"pages[{page_index}] must be an object")
            continue
        validate_page(page, f"pages[{page_index}]", errors)
    return errors


def main() -> int:
    config_path = Path(sys.argv[1] if len(sys.argv) > 1 else "config/dashboard.json")
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"JSON syntax error: {exc}")
        return 1
    except OSError as exc:
        print(f"Unable to read {config_path}: {exc}")
        return 1

    print(f"JSON syntax: OK ({config_path})")
    errors = validate_config(config)
    if errors:
        print(f"HomeUI validation: FAILED ({len(errors)} error(s))")
        for error in errors:
            print(f"  - {error}")
        return 1

    pages = config["pages"]
    panel_types: dict[str, int] = {}

    def count_panels(panels: list) -> None:
        for panel in panels:
            panel_type = panel.get("type", "?")
            panel_types[panel_type] = panel_types.get(panel_type, 0) + 1

    for page in pages:
        layout = page.get("layout", "columns")
        if layout == "columns":
            for column in page.get("columns", []):
                count_panels(column.get("panels", []))
        else:
            count_panels(page.get("panels", []))

    print("HomeUI validation: OK")
    print(f"  Pages: {len(pages)}")
    print(f"  Panels: {sum(panel_types.values())} ({', '.join(f'{k}={v}' for k, v in sorted(panel_types.items()))})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
