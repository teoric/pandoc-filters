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
-- Last Changed: 2023-02-18, 17:26:20 (CET)
--------------------------------------------------------------------------------
--

-- local inspect = require('inspect')
local text = require 'text'
local List = require 'pandoc.List'
local utils = require 'pandoc.utils'

local utilPath = string.match(PANDOC_SCRIPT_FILE, '.*[/\\]')
if PANDOC_VERSION >= {2,12} then
  local path = require 'pandoc.path'
  utilPath = path.directory(PANDOC_SCRIPT_FILE) .. path.separator
end
local loc_utils = dofile ((utilPath or '') .. 'utils.lua')

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

local color_comments
local to_omit
local to_highlight

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
      local omitted = meta["omit"]
      local highlighted = meta["highlight"]
      to_omit = loc_utils.listify(omitted):map(function(o)
        return utils.stringify(o)
      end)
      to_highlight = loc_utils.listify(highlighted):map(function(o)
        return utils.stringify(o)
      end)
      if (meta["slide-level"]) then
        local meta_level = meta["slide-level"]
        slide_level = tonumber(utils.stringify(meta_level)) + 1
      end
    end
  },
  {
    Link = function(el)
      local typ = el.attributes["type"]
      if typ ~= nil then
      local typ = text.lower(typ)
      end
      -- print (utils.stringify(el.content))
      -- print(typ)
      if el.attributes["type"] == "doi" then
        local base = "http://doi.org/"
        local hdl = loc_utils.trim(utils.stringify(el))
        el.target = base .. hdl
        return el
      elseif el.attributes["type"] == "hdl" then
        local base = "http://hdl.handle.net/"
        local hdl = loc_utils.trim(utils.stringify(el))
        el.target = base .. hdl
        return el
      elseif el.attributes["type"] == "konde" then
        local base = "https://gams.uni-graz.at/"
        local hdl = loc_utils.trim(utils.stringify(el))
        el.target = base .. hdl
        return el
      elseif string.find(utils.stringify(el.content), "doi.org") then
        local target = el.target:gsub("^http[^:]*://[^/]+/", "")
        -- print(target)
        el.content = target
        local ret = List:new({pandoc.RawInline(FORMAT, "DOI: "), pandoc.Link(target, "https://doi.org/" .. target)})
        return ret
      end
    end
  },
  {
    Span = function(el)
      color = el.attributes['color']
      -- if no color attribute, return unchanged -- redundant!
      if color == nil then return el end
      -- transform to <span style="color: red;"></span>
      if FORMAT:match 'html' or FORMAT:match 'html5' then
        -- remove color attributes
        el.attributes['color'] = nil
        -- use style attribute instead
        el.attributes['style'] = 'color: ' .. color .. ';'
        -- return full span element
        return el
      elseif FORMAT:match 'latex' then
        -- remove color attributes
        el.attributes['color'] = nil
        -- encapsulate in latex code
        table.insert(
          el.content, 1,
          pandoc.RawInline('latex', '\\textcolor{'..color..'}{')
        )
        table.insert(
          el.content,
          pandoc.RawInline('latex', '}')
        )
        -- returns only span content
        return el.content
      else
        -- for other format return unchanged
        return el
      end
    end
  },
  {
    Div = function(div)
      for i, class in ipairs(div.classes) do
        if to_omit:includes(class) then
          return pandoc.List:new()
        end
        if to_highlight:includes(class) then
          table.insert(
            div.content, 1,
            pandoc.Para(pandoc.Strong("⇓ " .. text.upper(class) .. " ⇓"))
          )
          table.insert(
            div.content,
            pandoc.Para(pandoc.Strong("⇑ " .. text.upper(class) .. " ⇑"))
          )
        end
        -- return div
      end
      if FORMAT == "beamer" then
        local start = ""
        local finish = ""
        -- wrap div in box containers
        if div.classes:includes("only") then
          local scope = div.attributes["scope"]
          start = start .. "\\only<" ..
            scope ..
            ">{"
          finish =  "}" .. finish
        end
        if div.classes:includes("on_next") then
          local scope = div.attributes["scope"]
          start = start .. "\\only<+>{"
          finish = "}" .. finish
        end
        for i, b in pairs(boxes) do
          if div.classes:includes(b) then
            local title = div.attributes["title"]
            -- io.stderr:write(title .. "\n")
            start = start .. "\\begin{" .. b .. "}" ..
            "{" .. title
            if div.attributes["rechts"] then
              start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
            end
            start = start .. "}"
            finish = "\\end{" .. b .. "}" .. finish
            -- break -- allow only first box!
          end
        end
        if start ~= "" then
          local ret = List:new({pandoc.RawBlock(FORMAT, start)})
          ret:extend(div.content)
          ret:extend({pandoc.RawBlock(FORMAT, finish)})
          div.content = ret
        end
        return div
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
          start = "\\begin{addmargin}[1cm]{1cm}" .. color .."\\vskip1ex\\begingroup\\textbf{" .. table.concat(div.classes, ";;") .. "}"
          -- start = "\\medskip\\begin{addmargin}[1cm]{1cm}" .. color .."\\vskip1ex\\begingroup\\textbf{" .. table.concat(div.classes, ";;") .. "}"
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
        elseif span.classes:includes("lig") then
          start = "\\ligtext{\\unemph{"
          finish = "}}"
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
