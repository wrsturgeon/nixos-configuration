"""Bake Spline Sans' ss02 glyph substitutions into a renamed variable font."""

from fontTools.ttLib import TTFont
import sys


FAMILY = "Spline Sans SS02"
PS_FAMILY = "SplineSansSS02"
FEATURE = "ss02"
STYLE = "Regular"
PATH = sys.argv[1]


def get_single_substitutions(font, feature_tag):
    if "GSUB" not in font:
        raise ValueError("font has no GSUB table")

    gsub = font["GSUB"].table
    lookups = gsub.LookupList.Lookup
    substitutions = {}
    for record in gsub.FeatureList.FeatureRecord:
        if record.FeatureTag != feature_tag:
            continue

        for lookup_index in record.Feature.LookupListIndex:
            lookup = lookups[lookup_index]
            if lookup.LookupType != 1:
                raise ValueError(
                    f"{feature_tag!r} uses unsupported lookup type {lookup.LookupType}"
                )

            for subtable in lookup.SubTable:
                substitutions.update(getattr(subtable, "mapping", {}))

    if not substitutions:
        raise ValueError(f"feature {feature_tag!r} was not found")

    return substitutions


def apply_substitutions_to_cmap(font, substitutions):
    if "cmap" not in font:
        raise ValueError("font has no cmap table")

    changed = False
    for table in font["cmap"].tables:
        if not table.isUnicode():
            continue

        cmap = dict(table.cmap)
        for codepoint, glyph_name in table.cmap.items():
            replacement = substitutions.get(glyph_name)
            if replacement is not None:
                cmap[codepoint] = replacement
                changed = True

        table.cmap = cmap

    if not changed:
        raise ValueError("no Unicode cmap entries matched the substitutions")


def set_name(font, name_id, value):
    for platform_id, encoding_id, language_id in (
        (3, 1, 0x409),
        (1, 0, 0),
    ):
        font["name"].setName(
            value,
            name_id,
            platform_id,
            encoding_id,
            language_id,
        )


def get_name(font, name_id):
    for platform_id, encoding_id, language_id in (
        (3, 1, 0x409),
        (1, 0, 0),
    ):
        name = font["name"].getName(
            name_id,
            platform_id,
            encoding_id,
            language_id,
        )
        if name is not None:
            return name.toUnicode()

    return None


def rename_font(font):
    postscript_name = f"{PS_FAMILY}-{STYLE}"
    set_name(font, 1, FAMILY)
    set_name(font, 2, STYLE)
    set_name(font, 3, f"generated;{postscript_name}")
    set_name(font, 4, f"{FAMILY} {STYLE}")
    set_name(font, 6, postscript_name)
    set_name(font, 16, FAMILY)
    set_name(font, 17, STYLE)
    set_name(font, 25, PS_FAMILY)

    if "fvar" not in font:
        return

    for instance in font["fvar"].instances:
        if instance.postscriptNameID == 0xFFFF:
            continue

        style = get_name(font, instance.subfamilyNameID)
        if style is None:
            continue

        ps_suffix = "".join(style.split())
        set_name(font, instance.postscriptNameID, f"{PS_FAMILY}-{ps_suffix}")


font = TTFont(PATH, recalcTimestamp=False)
substitutions = get_single_substitutions(font, FEATURE)
if substitutions.get("g") != "g.ss02":
    raise ValueError("Spline Sans ss02 no longer maps g to g.ss02")

apply_substitutions_to_cmap(font, substitutions)
rename_font(font)
font.save(PATH)
