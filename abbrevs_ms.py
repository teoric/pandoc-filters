#!/usr/bin/env python3

"""
Pandoc filter to recognise some abbreviations and prevent sentence
spacing in ``ms``."""

from pandocfilters import toJSONFilter, RawInline
import regex  # allow unicode character properties

ABBREVS = {
    "all": [
        r'\p{L}'
    ],
    "de": [
        r'[Ee]vtl',
        r'Nr',
        r'[Zz]\.Zt',
        r'[Gg]gf\.',
        # r'[UuOo]\.[AaäÄ]',
        # r'[Uu]\.?s\.?w',
        r'[Ss]',
        # r'[muMUsSiI]\.e'
        r'[Vv]gl',
        r'Kap',
        r'Fn',
        r'Anm',
        r'Hg',
        r'Hgg',
        r'Hrsg',
        r'Abb',
        r'\d+',
        r'[Ii]nsb',
    ],
    "en": [
        r'[Pp]p?',
        r'[Nn]o',
        r'[Vv]ol',
        # r'[Ee]\.g'
        # r'[Ii]\.e'
        r'[Vv]iz',
        r'fig',
    ]
}

PATTERN = regex.compile(
    r'^[\p{Pi}\p{Ps}]?(?:'
    + r'|'.join(a for l in ABBREVS for a in ABBREVS[l])
    + r')\.$'
)
MULTI_PATTERN = regex.compile(r'^(?:\p{L}+\.){2,}$')


def abbrevs(key, value, fmt, _meta):
    """French-space guessed abbreviations."""
    if fmt == "latex" or fmt == "beamer":
        if key == 'Str':
            n = MULTI_PATTERN.match(value)
            if n:
                value = regex.sub(r'\p{L}+\.(?!$)', r'\g<0>\kern 0.16667ex', value)
            m = PATTERN.match(value)
            if m or n:
                return RawInline(fmt, value + r'\ ')
    if fmt == "ms":
        if key == 'Str':
            n = MULTI_PATTERN.match(value)
            if n:
                value = regex.sub(r'\p{L}+\.(?!$)', r'\g<0>\|', value)
            m = PATTERN.match(value)
            if m or n:
                return RawInline("ms", value + r'\&')
    return None  # change nothing


if __name__ == "__main__":
    toJSONFilter(abbrevs)
