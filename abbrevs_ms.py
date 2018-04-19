#!/usr/bin/env python

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
        r'Nr',
        r'[Zz]\.Zt',
        r'[Gg]gf\.',
        r'[UuOo]\.[AaäÄ]',
        r'[Uu]\.?s\.?w',
        r'[Ss]',
        r'[Vv]gl',
    ],
    "en": [
        r'[Pp]p?',
        r'[Nn]o',
        r'[Vv]ol',
        r'[Ee]\.g'
        r'[Ii]\.e'
        r'[Vv]iz'
    ]
}

PATTERN = regex.compile(
    r'^[\p{Pi}\p{Ps}]?(?:' +
    r'|'.join(a for l in ABBREVS for a in ABBREVS[l]) +
    r')\.$'
)


def abbrevs(key, value, fmt, _meta):
    """French-space guessed abbreviations."""
    if fmt == "ms":
        if key == 'Str':
            m = PATTERN.match(value)
            if m:
                return RawInline("ms", value + r'\&')
    return None  # change nothing


if __name__ == "__main__":
    toJSONFilter(abbrevs)