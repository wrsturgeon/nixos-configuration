"""Build a GT America width-specific variable-font instance while preserving public axis labels."""

from fontTools.ttLib import TTFont
import subprocess
import sys

source_path = sys.argv[1]
output_path = sys.argv[2]
width_label = sys.argv[3]
target_default = float(width_label)
family = f"GT America {width_label}"
ps_family = "GTAmerica" + width_label.replace(".", "")
replacements = {
    "GT America Trial VF": family,
    "GTAmericaTrialVF": ps_family,
}
values = {
    1: family,
    2: "Regular",
    3: f"generated;{ps_family}",
    4: family,
    6: ps_family,
    16: family,
    17: "Regular",
    25: ps_family,
}


def clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def fmt_axis_value(value):
    value = float(value)
    return str(int(value)) if value.is_integer() else str(value)


def get_axis(font, tag):
    for axis in font["fvar"].axes:
        if axis.axisTag == tag:
            return axis
    raise ValueError(f"font has no {tag!r} axis")


def apply_axis_boost(font, tag, boost):
    axis_bounds = {}
    for axis in font["fvar"].axes:
        if axis.axisTag != tag:
            continue

        axis.minValue -= boost
        axis.defaultValue -= boost
        axis.maxValue -= boost
        axis_bounds[tag] = (axis.minValue, axis.maxValue, axis.defaultValue)
        break

    if tag not in axis_bounds:
        raise ValueError(f"font has no {tag!r} axis")

    for instance in font["fvar"].instances:
        if tag in instance.coordinates:
            minimum, maximum, _default = axis_bounds[tag]
            instance.coordinates[tag] = clamp(float(instance.coordinates[tag]), minimum, maximum)

    return axis_bounds


def clamp_stat_axis_values(font, axis_bounds):
    if not axis_bounds or "STAT" not in font:
        return

    stat = font["STAT"].table
    design_axes = getattr(getattr(stat, "DesignAxisRecord", None), "Axis", None)
    axis_values = getattr(getattr(stat, "AxisValueArray", None), "AxisValue", None)
    if not design_axes or not axis_values:
        return

    axis_tags = {index: axis.AxisTag for index, axis in enumerate(design_axes)}

    def adjust(axis_index, value):
        tag = axis_tags.get(axis_index)
        if tag not in axis_bounds:
            return value
        minimum, maximum, _default = axis_bounds[tag]
        return clamp(float(value), minimum, maximum)

    for axis_value in axis_values:
        fmt = axis_value.Format
        if fmt in (1, 3):
            axis_value.Value = adjust(axis_value.AxisIndex, axis_value.Value)
            if fmt == 3:
                axis_value.LinkedValue = adjust(axis_value.AxisIndex, axis_value.LinkedValue)
        elif fmt == 2:
            axis_value.NominalValue = adjust(axis_value.AxisIndex, axis_value.NominalValue)
            axis_value.RangeMinValue = adjust(axis_value.AxisIndex, axis_value.RangeMinValue)
            axis_value.RangeMaxValue = adjust(axis_value.AxisIndex, axis_value.RangeMaxValue)
        elif fmt == 4:
            for record in axis_value.AxisValueRecord:
                record.Value = adjust(record.AxisIndex, record.Value)


source_font = TTFont(source_path)
wdth = get_axis(source_font, "wdth")
if target_default < wdth.minValue or target_default > wdth.maxValue:
    raise ValueError(
        f"wdth default source {fmt_axis_value(target_default)} "
        f"is outside {fmt_axis_value(wdth.minValue)}:{fmt_axis_value(wdth.maxValue)}"
    )
wdth_arg = (
    f"wdth={fmt_axis_value(wdth.minValue)}:"
    f"{fmt_axis_value(target_default)}:"
    f"{fmt_axis_value(wdth.maxValue)}"
)
wdth_boost = target_default - float(wdth.defaultValue)
source_font.close()

subprocess.run(
    ["fonttools", "varLib.instancer", source_path, wdth_arg, "--output", output_path],
    check=True,
)

font = TTFont(output_path)
boosted_bounds = apply_axis_boost(font, "wdth", wdth_boost)
clamp_stat_axis_values(font, boosted_bounds)
for record in font["name"].names:
    value = values.get(record.nameID)
    if value is None:
        value = record.toUnicode()
        for old, new in replacements.items():
            value = value.replace(old, new)
    record.string = value.encode(record.getEncoding(), errors="replace")
font.save(output_path)
