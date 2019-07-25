--
--------------------------------------------------------------------------------
--         File: image-ms.lua
--
--        Usage: pandoc --lua-filter=beamer-spans.lua
--
--  Description: map spans in Pandoc markdown to beamer LaTeX commands
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2018-03-30
-- Last Changed: 2019-07-25, 10:58:44 (CEST)
--------------------------------------------------------------------------------
--

local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
-- io.stderr:write(FORMAT .. "\n")
return {{
  Header = function(span)
    if FORMAT == "beamer" then
      if span.classes:includes("nofooter") then
        span.content:extend({
            pandoc.RawInline("beamer", "\\nofooter")
        })
        return span
      end
    end
  end,

  Span = function(span)
    if FORMAT == "beamer" then
      local start = nil
      local finish = nil
      if span.classes:includes("rechts") then
        start = "\\rechts{"
        finish = "}"
      elseif span.classes:includes("rkomment") then
        start = "\\rechts{\\emph{"
        finish = "}}"
      elseif span.classes:includes("emph") then
        start = "\\oldemph{"
        finish = "}"
      elseif span.classes:includes("transl") then
        start = "\\transl{"
        finish = "}"
      end
      if start then
        local ret = List:new({pandoc.RawInline("beamer", start)})
        ret:extend(span.content)
        ret:extend({pandoc.RawInline("beamer", finish)})
        return {
          pandoc.Span(ret, span.attr)
        }
      end
    end
  end
}}
