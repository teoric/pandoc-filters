#!/usr/bin/env python
from pandocfilters import walk, toJSONFilter, RawInline, Str
import regex  # allow unicode character properties

"""prepare smallcaps for macro that needs upper case letters."""


def upstr(key, value, fmt, _meta):
    """replace lower-case letters by macro-wrapped upper-case letters"""
    if fmt == "ms":
        if key == 'Str':
            words = regex.finditer(r'(?P<U>\p{Lu}*)(?P<L>\P{Lu}*)', value)
            if words:
                ret = []
                for w in words:
                    if w["U"]:
                        ret.append(RawInline("ms", w["U"]))
                    if w["L"]:
                        ret.extend([
                            RawInline("ms", '\\c\n.smallcaps\n'),
                            Str(w["L"].upper()),
                            RawInline("ms", '\\c\n./smallcaps\n'),
                        ])
                return ret

    return None  # else change nothing


def scaps(key, val, fmt, meta):
    if fmt == "ms":
        if key == 'SmallCaps':
            return walk(val, upstr, fmt, meta)


if __name__ == "__main__":
    toJSONFilter(scaps)
