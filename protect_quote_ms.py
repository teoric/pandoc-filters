#!/usr/bin/env python3

"""
Pandoc filter to protect U+2019 from smartness."""

from pandocfilters import toJSONFilter, Str, RawInline
import re


def protect_quote(key, value, fmt, _meta):
    """Protect U+2019 against https://github.com/jgm/pandoc/issues/4550"""
    if fmt == "ms":
        if key == 'Str':
            if re.search(r'[’]', value):
                strs = re.split(r'[’]', value)
                ret = [Str(strs[0])]
                for s in strs[1:]:
                    ret += [RawInline("ms", "’"), Str(s)]
                return ret
    return None  # change nothing


if __name__ == "__main__":
    toJSONFilter(protect_quote)
