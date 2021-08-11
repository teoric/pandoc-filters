#!/usr/bin/env python
from pandocfilters import walk, toJSONFilter, RawInline, Str
import regex  # allow unicode character properties

"""prepare smallcaps for macro that needs upper case letters."""


def upstr(key, value, fmt, _meta):
    """replace lower-case letters by macro-wrapped upper-case letters"""
    if fmt == "ms":
        if key == 'Str':
            words = regex.finditer(
                r'(?P<U>\p{Lu}*)(?P<L>\p{Ll}*)(?P<R>[^\p{Ll}\p{Lu}]*)',
                value)
            if words:
                ret = [RawInline("ms", "\n")]
                for w in words:
                    if w[2]:  # not useful if nothing will be small-capped
                        cmd = f'.SCAP "{w[1]}" "{w[2].upper()}"'
                        if w[3]:
                            cmd += ' "{w[3]}"'
                        cmd += '\n'
                        ret.append(
                            RawInline(
                                "ms",
                                cmd))
                    else:
                        ret.append(Str(w[0]))
                return ret

    return None  # else change nothing


def scaps(key, val, fmt, meta):
    if fmt == "ms":
        if key == 'SmallCaps':
            return walk(val, upstr, fmt, meta)


if __name__ == "__main__":
    toJSONFilter(scaps)
