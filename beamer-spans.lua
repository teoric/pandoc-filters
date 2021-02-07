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
-- Last Changed: 2021-01-27, 12:09:43 (CET)
--------------------------------------------------------------------------------
--

local inspect = require('inspect')
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

local comments = {
  "Bemerkung",
  "Bewertung",
  "Kommentar",
  "Erläuterung",
  "Beispiel"
}

local remarks = {
  "Anmerkung",
  "Frage",
  "Antwort",
  "Frage/Bewertung",
  "Frage/Anregung",
  "Bewertung/Frage"
}

local name_caps

local sec_start = nil
local sec_finish = nil
local slide_level = 3

local remark_color = "\\color{blue}\\sffamily"

function check_comment(div)
  return check_classes(div, comments)
end

function check_remark(div)
  return check_classes(div, remarks)
end

function check_classes(div, classes)
  local ret = false
  for i, typ in pairs(classes) do
    if div.classes:includes(typ) then
      ret = true
      break
    end
  end
  return ret
end

return {
  {
    Meta = function(meta)
      name_caps = meta["name-small-caps"]
      color_comments = meta["color-remarks"]
      if (meta["slide-level"]) then
        local meta_level = meta["slide-level"]
        slide_level = tonumber(utils.stringify(meta_level)) + 1
      end
    end
  },
  {
    Div = function(div)
      if FORMAT == "beamer" then
        local start = nil
        local finish = nil
        -- wrap div in box containers
        for i, b in pairs(boxes) do
          if div.classes:includes(b) then
            local title = div.attributes["title"]
            -- io.stderr:write(title .. "\n")
            start = "\\begin{" .. b .. "}" ..
            "{" .. title
            if div.attributes["rechts"] then
              start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
            end
            start = start .. "}"
            finish = "\\end{" .. b .. "}"
          end
        end
        if div.classes:includes("only") then
          local scope = div.attributes["scope"]
          start = "\\only<" ..
            scope ..
            ">{"
          finish = "}"
        end
        if div.classes:includes("on_next") then
          local scope = div.attributes["scope"]
          start = "\\only<+>{"
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
          -- io.stderr:write(title .. "\n")
          start = "\\begin{description}" ..
          "\\item[".. title .. "] ~"
          if div.attributes["rechts"] then
            start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
          end
          finish = "\\end{description}"
        end
        end
        local is_remark = check_remark(div)
        local is_comment = check_comment(div)
        -- io.stderr:write(table.concat(div.classes, ";;"), "\n")
        if div.attributes["resolved"] then
          return List:new()
        elseif start == nil and (is_remark or is_comment) then
          local color = ""
          if is_comment and color_comments then
            color = remark_color
          elseif is_remark then
            color = remark_color
          end
          start = "\\medskip\\begin{addmargin}[1cm]{1cm}" .. color .."\\vskip1ex\\begingroup\\textbf{" .. table.concat(div.classes, ";;") .. "}"
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
