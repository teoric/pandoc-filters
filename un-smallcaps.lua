--
--------------------------------------------------------------------------------
--         File: un-smallcaps.lua
--
--        Usage: pandoc --lua-filter=un-smallcaps.lua
--
--  Description: - make small caps all capitals – graceless degradation
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2018-04-21
-- Last Changed: 2018-04-21, 18:57:04 CEST
--------------------------------------------------------------------------------
--

local text = require("text")

return {
  {
    SmallCaps = function(elem)
      return pandoc.walk_inline(pandoc.Span(elem.c), {
        Str = function(el)
          return pandoc.Str(text.upper(el.text))
        end,
      })
    end,
  },
}
