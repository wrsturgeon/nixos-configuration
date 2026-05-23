"""Build renamed variable-font variants from a generated variant-config.json file."""

from fontTools.ttLib import TTFont
import json
import os
import shutil
import subprocess
import tempfile


def clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def fmt_axis_value(value):
    value = float(value)
    return str(int(value)) if value.is_integer() else str(value)


def get_axis(font, tag):
    if "fvar" not in font:
        raise ValueError(f"font has no fvar table; cannot set {tag!r} default source")

    for axis in font["fvar"].axes:
        if axis.axisTag == tag:
            return axis

    raise ValueError(f"font has no {tag!r} axis")


def build_axis_args(font, axis_default_sources, axis_ranges):
    overlap = set(axis_default_sources) & set(axis_ranges)
    if overlap:
        axes = ", ".join(sorted(overlap))
        raise ValueError(f"axis listed in both axisDefaultSources and axisRanges: {axes}")

    axis_args = []
    axis_default_boosts = {}
    for tag, value in axis_default_sources.items():
        axis = get_axis(font, tag)
        value = float(value)
        minimum = float(axis.minValue)
        default = float(axis.defaultValue)
        maximum = float(axis.maxValue)
        if value < minimum or value > maximum:
            raise ValueError(
                f"{tag!r} default source {fmt_axis_value(value)} "
                f"is outside {fmt_axis_value(minimum)}:{fmt_axis_value(maximum)}"
            )

        axis_args.append(
            f"{tag}={fmt_axis_value(minimum)}:{fmt_axis_value(value)}:{fmt_axis_value(maximum)}"
        )
        if value != default:
            axis_default_boosts[tag] = value - default

    axis_args += [
        f"{tag}={fmt_axis_value(values['min'])}:{fmt_axis_value(values['default'])}:{fmt_axis_value(values['max'])}"
        for tag, values in axis_ranges.items()
    ]

    return axis_args, axis_default_boosts


# Re-label axes whose source default moved (e.g. wdth 90 should
# still be requested by apps as normal width 100).
def apply_axis_relabels(font, axis_relabels):
    if not axis_relabels or "fvar" not in font:
        return {}

    relabeled_bounds = {}
    for axis in font["fvar"].axes:
        shift = axis_relabels.get(axis.axisTag)
        if shift is None:
            continue

        shift = float(shift)
        axis.minValue -= shift
        axis.defaultValue -= shift
        axis.maxValue -= shift
        relabeled_bounds[axis.axisTag] = (axis.minValue, axis.maxValue, axis.defaultValue)

    for instance in font["fvar"].instances:
        for tag, (minimum, maximum, _default) in relabeled_bounds.items():
            if tag in instance.coordinates:
                instance.coordinates[tag] = clamp(float(instance.coordinates[tag]), minimum, maximum)

    if "wght" in relabeled_bounds and "OS/2" in font:
        font["OS/2"].usWeightClass = round(relabeled_bounds["wght"][2])

    return relabeled_bounds


# Boost the default source design while preserving public axis
# values/named instances (especially CSS weights like 400/700).
def apply_axis_default_boosts(font, axis_boosts):
    if not axis_boosts or "fvar" not in font:
        return {}

    boosted_defaults = {}
    for axis in font["fvar"].axes:
        boost = axis_boosts.get(axis.axisTag)
        if boost is None:
            continue

        boost = float(boost)
        default = axis.defaultValue - boost
        if default < axis.minValue or default > axis.maxValue:
            raise ValueError(
                f"{axis.axisTag!r} boosted default {fmt_axis_value(default)} "
                f"is outside {fmt_axis_value(axis.minValue)}:{fmt_axis_value(axis.maxValue)}"
            )

        axis.defaultValue = default
        boosted_defaults[axis.axisTag] = default

    if "wght" in boosted_defaults and "OS/2" in font:
        font["OS/2"].usWeightClass = round(boosted_defaults["wght"])

    return boosted_defaults


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


def rename_font(font, family, ps_family, style, ps_suffix):
    ps_suffix = ps_suffix if ps_suffix is not None else "".join(style.split())
    full_name = family if style == "Regular" else f"{family} {style}"
    postscript_name = ps_family if style == "Regular" else f"{ps_family}-{ps_suffix}"
    values = {
        1: family,
        2: style,
        3: f"generated;{postscript_name}",
        4: full_name,
        6: postscript_name,
        16: family,
        17: style,
        25: ps_family,
    }

    for record in font["name"].names:
        value = values.get(record.nameID)
        if value is None:
            continue
        record.string = value.encode(record.getEncoding(), errors="replace")


def main():
    with open("variant-config.json") as f:
        config = json.load(f)

    source_root = os.environ["src"]
    output_root = os.path.join(os.environ["out"], "share/fonts/truetype")
    family = config["family"]
    ps_family = config["psFamily"]
    axis_default_sources = config.get("axisDefaultSources", {})
    axis_ranges = config.get("axisRanges", {})
    axis_boosts = config.get("axisBoosts", {})

    boost_overlap = set(axis_default_sources) & set(axis_boosts)
    if boost_overlap:
        axes = ", ".join(sorted(boost_overlap))
        raise ValueError(f"axis listed in both axisDefaultSources and axisBoosts: {axes}")

    for face in config["faces"]:
        input_path = os.path.join(source_root, face["input"])
        output_path = os.path.join(output_root, face["output"])

        with tempfile.TemporaryDirectory() as temp_dir:
            prepared_input = os.path.join(temp_dir, os.path.basename(face["input"]))
            shutil.copyfile(input_path, prepared_input)
            source_font = TTFont(prepared_input)
            face_axis_args, axis_default_boosts = build_axis_args(
                source_font,
                axis_default_sources,
                axis_ranges,
            )
            source_font.close()

            subprocess.run(
                [
                    "fonttools",
                    "varLib.instancer",
                    prepared_input,
                    *face_axis_args,
                    "--output",
                    output_path,
                ],
                check=True,
            )

        font = TTFont(output_path)
        relabeled_bounds = apply_axis_relabels(font, axis_default_boosts)
        clamp_stat_axis_values(font, relabeled_bounds)
        apply_axis_default_boosts(font, axis_boosts)
        rename_font(
            font,
            family,
            ps_family,
            face.get("style", "Regular"),
            face.get("psSuffix"),
        )
        font.save(output_path)


if __name__ == "__main__":
    main()
