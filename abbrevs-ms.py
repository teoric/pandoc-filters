#!/usr/bin/env python

"""
Pandoc filter to recognise some abbreviations and prevent sentence
spacing in ``ms``."""

from pandocfilters import toJSONFilter, Str, RawInline
import regex  # allow unicode character properties

abbrevs = {
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

pattern = regex.compile(
    r'^[\p{Pi}\p{Ps}]?(?:' +
    r'|'.join(a for l in abbrevs for a in abbrevs[l]) +
    r')\.$'
)


def abbrevs(key, value, format, meta):
    """French-space guessed abbreviations."""
    if format == "ms":
        if key == 'Str':
            m = pattern.match(value)
            if m:
                return RawInline("ms", value + r'\&')


if __name__ == "__main__":
    toJSONFilter(abbrevs)
