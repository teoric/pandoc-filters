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
-- Last Changed: 2019-07-25, 16:06:01 (CEST)
--------------------------------------------------------------------------------
--

local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
utils = require 'pandoc.utils'
-- io.stderr:write(FORMAT .. "\n")

require(debug.getinfo(1, "S").source:sub(2):match("(.*[\\/])") .. "utils")

local boxes = {
  "block",
  "goodbox", "badbox", "acceptbox",
  "claimbox",
  "yellowbox", "bluebox",
  "exbox", "exxbox"
}

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
  Div = function(div)
    if FORMAT == "beamer" then
      local start = nil
      local finish = nil
      for i, b in pairs(boxes) do
        if div.classes:includes(b) then
          local title=div.attributes["title"]
          -- io.stderr:write(title.."\n")
          start = "\\begin{"..b.."}"..
            "{"..
            title..
            "}"
          finish = "\\end{"..b.."}"
        end
      end
      if div.classes:includes("only") then
        local scope=div.attributes["scope"]
        start = "\\only<"..
          scope..
          ">{"
        finish = "}"
      end
      if start ~= nil then
        local ret = List:new({pandoc.RawBlock("beamer", start)})
        ret:extend(div.content)
        ret:extend({pandoc.RawBlock("beamer", finish)})
        div.content = ret
        return div
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
      elseif span.classes:includes("icon") then
        start = "\\icontext{"
        finish = "}"
      elseif span.classes:includes("uni") then
        start = "\\unitext{\\unemph{"
        finish = "}}"
      elseif span.classes:includes("unemph") then
        start = "\\unemph{"
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
