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
-- Last Changed: 2023-10-26 13:46:19 (+02:00)
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

local boxes_optional = {
  "definition", "theorem", "claim", "remark"
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
    Header = function(el)
      if FORMAT:match 'latex' then
        if utils.stringify(el) == "Anlagen" then
          local ret = pandoc.RawBlock(FORMAT, "\\Anlagen{}")
          return ret
        elseif utils.stringify(el) == "Unterschriften" then
          local ret = pandoc.RawBlock(FORMAT, "\\bigskip\\unterschrift{Torsten Zesch}{r}{Annemarie Friedrich}{}")
          return ret
        else
          -- local typ = el.attributes["type"]

          if loc_utils.startswith(el.identifier, "anlage:") then
            local scale = (el.attributes["scale"] ~= nil) and ("[".. el.attributes["scale"] .. "]") or ""
            local file = el.attributes["file"]
            if file == nil then
              if el.level == 2 then
              local ret = List:new({pandoc.RawInline(FORMAT, "\\secanlage{" .. utils.stringify(el.content) .. "}{"
              .. el.identifier .. "}")})
              return ret
              else error(string.format("No file for %s [#%s]", utils.stringify(el), el.identifier))
              end
            else
              local subtype = (el.level > 2) and "sub" or ""
              local ret = List:new({pandoc.RawInline(FORMAT, "\\".. subtype .. "anlage" .. scale .. "{".. utils.stringify(el.content) .. "}{"
              .. el.identifier .. "}{" .. file .. "}"
              )})
              return ret
            end
          end
        end
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
      if FORMAT:match 'latex' then
        if el.attributes["type"] == "anlage" then
          local ret = pandoc.RawInline(FORMAT, "\\emnameref{anlage:".. utils.stringify(el) .. "}")
          return ret
        end
      end
    end
  },
  {
    Span = function(el)
      local color = el.attributes['color']
      -- if no color attribute, return unchanged -- redundant!
      if color ~= nil then
        -- transform to <span style="color: red;"></span>
        if FORMAT:match 'html' or FORMAT:match 'html5' then
          -- remove color attributes
          el.attributes['color'] = nil
          -- use style attribute instead
          el.attributes['style'] = 'color: ' .. color .. ';'
          -- return full span element
          -- return el
        elseif FORMAT:match 'latex' or FORMAT:match 'beamer' then
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
          -- return el.content
        else
          -- for other format return unchanged
          -- return el
        end
      end
      if el.classes:includes("menu") then
        if FORMAT:match 'latex' or FORMAT:match 'beamer' then
          table.insert(
            el.content, 1,
            pandoc.RawInline('latex', '\\textsf{\\bfseries{}')
          )
          table.insert(
            el.content,
            pandoc.RawInline('latex', '}')
          )
          -- returns only span content
          -- return el.content
        else
          -- for other format return unchanged
          -- return el
        end
      end
      if el.classes:includes("serif") then
        if FORMAT:match 'latex' or FORMAT:match 'beamer' then
          table.insert(
            el.content, 1,
            pandoc.RawInline('latex', '\\textrm{')
          )
          table.insert(
            el.content,
            pandoc.RawInline('latex', '}')
          )
          -- returns only span content
          -- return el.content
        else
          -- for other format return unchanged
          -- return el
        end
      end
      return el
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
          local scope = div.attributes["scope"] or "+-"
          start = start .. "\\only<" ..
            scope ..
            ">{"
          finish =  "}" .. finish
        end
        if div.classes:includes("uncover") then
          local scope = div.attributes["scope"] or "+-"
          start = start .. "\\uncover<" ..
            scope ..
            ">{"
          finish =  "}" .. finish
        end
        if div.classes:includes("on_next") then
          local scope = div.attributes["scope"] or "+"
          start = start .. "\\only<" .. scope .. ">{"
          finish = "}" .. finish
        end
        for i, b in pairs(boxes) do
          if div.classes:includes(b) then
            local title = div.attributes["title"]
            local scope = div.attributes["scope"]
            if scope ~= nil and not(div.classes:includes("uncover")) and not(div.classes:includes("only")) and not(div.classes:includes("on_next")) then
              scope = "<" .. scope .. ">"
            else
              scope = ""
            end
            -- io.stderr:write(title .. "\n")
            start = start .. "\\begin{" .. b .. "}" .. scope ..
            "{" .. title
            if div.attributes["rechts"] then
              start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
            end
            start = start .. "}"
            finish = "\\end{" .. b .. "}" .. finish
            -- break -- allow only first box!
          end
        end
        for i, b in pairs(boxes_optional) do
          if div.classes:includes(b) then
            local title = div.attributes["title"]
            -- io.stderr:write(title .. "\n")
            start = start .. "\\begin{" .. b .. "}" ..
            "[" .. title
            if div.attributes["rechts"] then
              start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
            end
            start = start .. "]"
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
        local start = ""
        local finish = ""
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
        if div.classes:includes("xml") then
          start = "\\paragraph{XML}\\begingroup\\sffamily{}".. start
          finish = finish .. "\\endgroup{}"
        end
        if div.classes:includes("xml_details") then
          start = "\\begin{addmargin}{1em}\\sffamily{}\\relsize{-1}\\color{darkgray}".. start
          finish = finish .. "\\end{addmargin}"
        end

        if start ~= nil and start ~= "" then
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
        if span.classes:includes("key") then
          start = "\\fbox{\\small{}"
          finish = "}"
        elseif span.classes:includes("rechts") then
          start = "\\rechts{"
          finish = "}"
        elseif span.classes:includes("rkomment") then
          start = "\\rechts{\\emph{"
          finish = "}}"
        elseif span.classes:includes("emph") then
          -- start = "\\oldemph{"
          start = "\\emph{"
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
        elseif span.classes:includes("emoji") then
          start = "\\emojiText{"
          finish = "}"
        elseif span.classes:includes("underline")
        or span.classes:includes("ul") then
          start = "\\underline{"
          finish = "}"
        elseif span.classes:includes("unemph") then
          start = "\\unemph{"
          finish = "}"
        elseif span.classes:includes("fnhd_text") then
          start = "{\\normalfont\\unifont{}"
          finish = "}"
        elseif span.classes:includes("name") then
          start = "\\textsc{"
          finish = "}"
        elseif span.classes:includes("transl") then
          start = "\\transl{"
          finish = "}"
        elseif span.classes:includes("kbd") then
          start = "\\fbox{\\small{}\\bfseries{}"
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
