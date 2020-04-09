--
--------------------------------------------------------------------------------
--         File: beamer-spans.lua
--
--        Usage: pandoc --lua-filter=beamer-spans.lua
--
--  Description: map spans in Pandoc markdown to beamer LaTeX commands
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2019-07-20
-- Last Changed: 2020-03-15, 13:44:58 (+01:00)
--------------------------------------------------------------------------------
--

-- local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
utils = require 'pandoc.utils'
-- io.stderr:write(FORMAT .. "\n")

loc_utils = require(debug.getinfo(1, "S").source:sub(2):match(
"(.*[\\/])") .. "utils")

-- box types
local boxes = {
  "block",
  "goodbox", "badbox", "acceptbox",
  "claimbox",
  "yellowbox", "bluebox",
  "exbox", "exxbox"
}

local name_caps

return {
  {
    Meta = function(meta)
      name_caps = meta["name-small-caps"]
    end
  },
  {
    Header = function(span)
      if FORMAT == "beamer" then
        if span.classes:includes("nofooter") then
          span.content:extend({
            pandoc.RawInline(FORMAT, "\\nofooter")
          })
          return span
        end
      end
    end,
    Div = function(div)
      if FORMAT == "beamer" then
        local start = nil
        local finish = nil
        -- wrap div in box containers
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
          local ret = List:new({pandoc.RawBlock(FORMAT, start)})
          ret:extend(div.content)
          ret:extend({pandoc.RawBlock(FORMAT, finish)})
          div.content = ret
          return div
        end
      elseif FORMAT == "latex" then
      local start = nil
      local finish = nil
      -- wrap div in box containers
      for i, b in pairs(boxes) do
        if div.classes:includes(b) then
          local title=div.attributes["title"]
          -- io.stderr:write(title.."\n")
          start = "\\begin{description}" ..
          "\\item[".. title .. "] ~"
          if div.attributes["rechts"] then
            start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
          end

          finish = "\\end{description}"
        end
        end
        -- io.stderr:write(table.concat(div.classes, ";;"), "\n")
        if start == nil and div.classes:includes("Frage") or div.classes:includes("Frage/Bewertung") or div.classes:includes("Bewertung/Frage") or div.classes:includes("Bewertung") then
          start = "\\begin{addmargin}[1cm]{1cm}\\vskip1ex\\begingroup\\sffamily\\textbf{" .. table.concat(div.classes, ";;") .. "}"
          finish = "\\endgroup\\vskip1ex\\end{addmargin}"
        end

        if start ~= nil then
          local ret = List:new({pandoc.RawBlock(FORMAT, start)})
          ret:extend(div.content)
          ret:extend({pandoc.RawBlock(FORMAT, finish)})
          div.content = ret
          return div
        end
      end
    end,
    Span = function(span)
      if FORMAT == "beamer" or FORMAT == "latex" then
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
        elseif span.classes:includes("underline")
        or span.classes:includes("ul") then
          start = "\\underline{"
          finish = "}"
        elseif span.classes:includes("unemph") then
          start = "\\unemph{"
          finish = "}"
        elseif span.classes:includes("name") then
          start = "\\texsc{"
          finish = "}"
        elseif span.classes:includes("transl") then
          start = "\\transl{"
          finish = "}"
        end
        if start then
          local ret = List:new({pandoc.RawInline(FORMAT, start)})
          ret:extend(span.content)
          ret:extend({pandoc.RawInline(FORMAT, finish)})
          return {
            pandoc.Span(ret, span.attr)
          }
        end
      end
    end
  }
}
