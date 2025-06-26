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
-- Last Changed: 2025-06-26 14:11:07 (+02:00)
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
  "definition", "theorem", "claim", "remark", "anm"
}

local comments = {
  "Comment",
  "comment",
  "Bemerkung",
  "Bewertung",
  "Kommentar",
  "Erläuterung",
  "Beispiel",
  "Lösung"
}

local remarks = {
  "Remark",
  "Anmerkung",
  "Frage",
  "Antwort",
  "Frage/Bewertung",
  "Frage/Anregung",
  "Bewertung/Frage"
}

local skips = pandoc.List({
  "big", "med", "small"
})

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

function add_style(el, style, value)
  if el.attributes['style'] == nil then
    el.attributes['style'] = ""
  end
  -- TODO: proof against missing semicolon?
  el.attributes['style'] = el.attributes['style'] .. style .. ': ' .. value .. ';'
end

function eval_md(code)
  local md_text = pandoc.read(code, "markdown")
  return md_text.blocks[1].c
end

local remove_break = {
  LineBreak = function()
    return pandoc.Space()
  end
}

local search_dirs = {
  PANDOC_STATE.user_data_dir .. "/templates",
  PANDOC_STATE.user_data_dir,
  -- maybe not the best location, but why not:
  PANDOC_STATE.user_data_dir .. "/filters"

}

function get_and_search(filename)
  -- check if file exists locally or in user data directory
  local path = nil
  -- local file first
  if loc_utils.file_exists(filename) then
    path = filename
  end
  if path == nil then
    local candidate_path = PANDOC_STATE.user_data_dir .. "/" .. filename
    for k, dir in ipairs(search_dirs) do
      candidate_path = dir .. "/" .. filename
      if loc_utils.file_exists(candidate_path) then
        path = candidate_path
        break
      end
    end
  end
  if path == nil then
    io.stderr:write("File " .. filename .. " does not exist.\n")
  end
  return path
end

return {
  {
    Meta = function(meta)
      -- apply pandoc-crossref localization
      if meta.lang ~= nil and string.match(utils.stringify(meta.lang), "^[Dd][eE]") then
        local crossref = "pandoc-crossref-de.yaml"
        local got_file = get_and_search(crossref)
        meta["crossrefYaml"] = got_file or crossref
      end
      if meta.supertitle ~= nil then
        meta["supertitle-lined"] = meta.supertitle:walk(remove_break)
      end
      if meta.title ~= nil then
        meta["title-lined"] = meta.title:walk(remove_break)
      end
      if meta.subtitle ~= nil then
        meta["subtitle-lined"] = meta.subtitle:walk(remove_break)
      end
      if meta.subsubtitle ~= nil then
        meta["subsubtitle-lined"] = meta.subsubtitle:walk(remove_break)
      end
      name_caps = meta["name-small-caps"]
      color_comments = meta["color-remarks"]
      local omitted = meta["omit"]
      if (meta["classoption"] ~= nil and meta["classoptions"] ~= nil) then
          meta["classoption"] = loc_utils.listify(meta["classoption"])
          meta["classoption"]:extend(loc_utils.listify(meta["classoptions"]))
      end
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
      -- force different default document class
      if FORMAT:match 'latex' and meta.documentclass ~= "article" then
        meta["documentclass"] = "scrartcl"
      end
      return meta
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
    Span = function(el)
      if FORMAT:match 'latex' or FORMAT:match 'beamer' then
        if el.classes:includes("voccom") then
          local ret = List:new()
          table.insert(ret, pandoc.RawInline(FORMAT, "\\voclemCom"))
          if el.attributes["remark"] ~= nil then
            -- optional remark
            table.insert(ret, pandoc.RawInline(FORMAT, "["))
            
            table.insert(ret, pandoc.Span(eval_md(el.attributes["remark"])))
            table.insert(ret, pandoc.RawInline(FORMAT, "]"))
          end
          table.insert(ret, pandoc.RawInline(FORMAT, "{"))
          table.insert(ret, pandoc.Span(el.c, el.attr))
          table.insert(ret, pandoc.RawInline(FORMAT, "}"))
          -- insert lemma
          if el.attributes["lemma"] ~= nil then
            table.insert(ret, eval_md(el.attributes["lemma"]))
          else
            table.insert(ret, pandoc.Span(el.c))
          end

          -- insert meaning
          if el.attributes["comment"] ~= nil then
            table.insert(ret, pandoc.Span(eval_md(el.attributes["comment"])))
          else
            table.insert(ret, pandoc.RawInline(FORMAT, "{}"))
          end
          return ret
        end
        if el.classes:includes("vocnote") then
          local ret = List:new()
          table.insert(ret, pandoc.RawInline(FORMAT, "\\voclemnote"))
          if el.attributes["remark"] ~= nil then
            -- optional remark
            table.insert(ret, pandoc.RawInline(FORMAT, "["))
            
            table.insert(ret, pandoc.Span(eval_md(el.attributes["remark"])))
            table.insert(ret, pandoc.RawInline(FORMAT, "]"))
          end
          table.insert(ret, pandoc.RawInline(FORMAT, "{"))
          table.insert(ret, pandoc.Span(el.c, el.attr))
          table.insert(ret, pandoc.RawInline(FORMAT, "}"))
          -- insert lemma
          if el.attributes["lemma"] ~= nil then
            table.insert(ret, eval_md(el.attributes["lemma"]))
          else
            table.insert(ret, pandoc.Span(el.c))
          end

          -- insert meaning
          if el.attributes["meaning"] ~= nil then
            table.insert(ret, pandoc.Span(eval_md(el.attributes["meaning"])))
          else
            table.insert(ret, pandoc.RawInline(FORMAT, "{}"))
          end
          return ret
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
      elseif el.attributes["type"] == "urn" then
        local base = "https://mdz-nbn-resolving.de/"
        local hdl = loc_utils.trim(utils.stringify(el))
        el.target = base .. hdl
        return el
      elseif string.find(utils.stringify(el.content), "mdz.nbn.resolving.de") then
        local target = el.target:gsub("^http[^:]*://[^/]+/", "")
        -- print(target)
        el.content = target
        local ret = List:new({pandoc.RawInline(FORMAT, "\\textsc{urn}: "), pandoc.Link(target, "https://mdz-nbn-resolving.de/" .. target)})
        return ret
      elseif string.find(utils.stringify(el.content), "doi.org") then
        local target = el.target:gsub("^http[^:]*://[^/]+/", "")
        -- print(target)
        el.content = target
        local ret = List:new({pandoc.RawInline(FORMAT, "\\textsc{doi}: "), pandoc.Link(target, "https://doi.org/" .. target)})
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
      local bgcolor = el.attributes['bgcolor']
      if color ~= nil or bgcolor ~= nil then
      -- if no color attribute, return unchanged -- redundant!
        -- transform to <span style="color: red;"></span>
        if FORMAT:match 'html' or FORMAT:match 'html5' then
          -- remove color attributes
          if color ~= nil then
            el.attributes['color'] = nil
            -- use style attribute instead
            add_style(el, "color", color)
          end
          if bgcolor ~= nil then
            el.attributes['bgcolor'] = nil
            -- use style attribute instead
            add_style(el, "background-color", bgcolor)
            add_style(el, "padding", ".5ex")
          end
          -- return full span element
          -- return el
        elseif FORMAT:match 'latex' or FORMAT:match 'beamer' then
          local start = ""
          local finish = ""
          if color ~= nil then
            -- remove color attributes
            el.attributes['color'] = nil
            start = start .. '\\textcolor{'..color..'}{'
            finish = "}" .. finish
          end
          if bgcolor ~= nil then
            -- remove color attributes
            el.attributes['bgcolor'] = nil
            start = start .. '\\colorbox{'..bgcolor..'}{'
            finish = "}" .. finish
          end
          -- encapsulate in latex code
          table.insert(
            el.content, 1,
            pandoc.RawInline('latex', start)
          )
          table.insert(
            el.content,
            pandoc.RawInline('latex', finish)
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
      local color = div.attributes['color']
      local bgcolor = div.attributes['bgcolor']
      if color ~= nil or bgcolor ~= nil then
      -- if no color attribute, return unchanged -- redundant!
        -- transform to <span style="color: red;"></span>
        if FORMAT:match 'html' or FORMAT:match 'html5' then
          -- remove color attributes
          if color ~= nil then
            div.attributes['color'] = nil
            -- use style attribute instead
            add_style(div, "color", color)
          end
          if bgcolor ~= nil then
            div.attributes['bgcolor'] = nil
            -- use style attribute instead
            add_style(div, "background-color", bgcolor)
          end
        end
      elseif FORMAT == "beamer" then
        -- TODO: make start and finish lists of RawBlock, pandoc.RawInline and others
        -- like vocnote above
        -- local start = List:new({})
        -- local finish = List:new({})
        local start = ""
        local finish = ""
        -- wrap div in box containers
        if div.classes:includes("only") then
          local scope = div.attributes["scope"] or "+-"
          start = "\\only<" .. scope ..
          ">{" .. start 
          finish =  "}" .. finish
        end
        if div.classes:includes("uncover") then
          local scope = div.attributes["scope"] or "+-"
          start = "\\uncover<" .. scope ..
            ">{" .. start
          finish =  "}" .. finish
        end
        if div.classes:includes("on_next") then
          local scope = div.attributes["scope"] or "+"
          start = "\\only<" .. scope .. ">{" .. start
          finish = finish .. "}"
        end
        if div.classes:includes("sideways") then
          -- io.stderr:write(title .. "\n")
          start = start .. "\\begin{sideways}"
          finish = "\\end{sideways}" .. finish
          -- break -- allow only first box!
        end
        for i, b in pairs(boxes) do
          if div.classes:includes(b) then
            local title = div.attributes["title"] or ""
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
            local title = div.attributes["title"] or ""
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
        if div.classes:includes("lineno") then
          -- io.stderr:write(title .. "\n")
          local start_no = div.attributes["start"] or "1"
          start = start .. "\\begin{linenumbers}[" .. start_no .. "]"
          finish = "\\end{linenumbers}" .. finish
          -- break -- allow only first box!
        end
        if div.classes:includes("verse") then
          -- io.stderr:write(title .. "\n")
          start = start .. "\\begin{verse}"
          finish = "\\end{verse}" .. finish
          -- break -- allow only first box!
        end
        -- same code below for LATEX
        local skip = div.attributes["skip"]
        if skip ~= nil and skips:includes(skip) then
          start = '\\' .. skip .. "skip{}" .. start
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
        if div.classes:includes("sideways") then
          -- io.stderr:write(title .. "\n")
          start = start .. "\\begin{sideways}"
          finish = "\\end{sideways}" .. finish
          -- break -- allow only first box!
        end
        if div.classes:includes("multicols") then
          local number = div.attributes["columns"] or "2"
          start = "\\begin{multicols}{" .. number .. "}" .. start 
          finish = finish .. "\\end{multicols}"
        end
        -- wrap div in box containers
        for i, b in pairs(boxes) do
          if div.classes:includes(b) then
            local title=div.attributes["title"] or ""
            -- io.stderr:write(title .. "\n")
            start = "\\begin{tcolorbox}["
            if div.classes:includes("breakable") then
              start = start .. "breakable"
            end
            if title ~= nil and title ~= "" then
              if start:match("[^%]]$") then
                start = start .. ","
              end
              start = start .. "title={" .. title .. "}"
            end
            start = start .. "]"
            if div.attributes["rechts"] then
              start = start .. "\\rechtsanm{" .. div.attributes["rechts"] .. "}"
            end
            finish = "\\end{tcolorbox}"
          end
        end
        local is_remark = check_remark(div)
        local is_comment = check_comment(div)
        -- io.stderr:write(table.concat(div.classes, ";;"), "\n")
        if div.attributes["color"] ~= nil then
          color = '\\color{'.. div.attributes["color"] ..'}'
        end
        if div.attributes["resolved"] then
          return List:new()
        elseif (is_remark or is_comment) then
          local color = ""
          if is_comment and color_comments then
            color = remark_color
          elseif is_remark then
            color = remark_color
          end
          start = "\\begin{tcolorbox}[title=" .. table.concat(div.classes, ";;") .. "]" .. start
          finish = finish .. "\\end{tcolorbox}"
          -- start = "\\begin{addmargin}[1cm]{1cm}" .. color .."\\vskip1ex\\begingroup\\textbf{" .. table.concat(div.classes, ";;") .. "}" .. start
          -- finish = finish .. "\\endgroup\\vskip1ex\\end{addmargin}"
        elseif (color ~= nil) then
          start = '{' .. color .. start
          finish = finish .. '}'
        end
        if div.attributes["linestretch"] then
          start = '\\bgroup\\setstretch{' .. div.attributes["linestretch"] ..'}' .. start
          finish = '\\egroup{}' .. finish
        end
        if div.attributes["bgcolor"] then
          start = '\\begin{tcolorbox}[colback='.. div.attributes["bgcolor"] ..'!20, colframe=' .. div.attributes["bgcolor"] .. '!80!black]' .. start
          finish = finish .. '\\end{tcolorbox}'
        end
        if div.classes:includes("xml") then
          start = "\\paragraph{XML}\\begingroup\\sffamily{}".. start
          finish = finish .. "\\endgroup{}"
        end
        if div.classes:includes("xml_details") then
          start = "\\begin{addmargin}{1em}\\sffamily{}\\relsize{-1}\\color{darkgray}".. start
          finish = finish .. "\\end{addmargin}"
        end
        if div.classes:includes("transcription") then
          start = "\\begin{aeettranscription}".. start
          finish = finish .. "\\end{aeettranscription}"
        end
        if div.classes:includes("references") then
          start = "\\begin{aeetreferences}".. start
          finish = finish .. "\\end{aeetreferences}"
        end
        if div.classes:includes("figure_text") then
          start = "\\begin{figureText}".. start
          finish = finish .. "\\end{figureText}"
        end
        if div.classes:includes("lineno") then
          -- io.stderr:write(title .. "\n")
          local start_no = div.attributes["start"] or "1"
          start = start .. "\\begin{linenumbers}[" .. start_no .. "]"
          finish = "\\end{linenumbers}" .. finish
          -- break -- allow only first box!
        end
        if div.classes:includes("verse") then
          -- io.stderr:write(title .. "\n")
          start = start .. "\\begin{poem}"
          local title = div.attributes["title"]
          local author = div.attributes["author"]
          local prefix = div.attributes["prefix"] or ""
          if title ~= nil then
            if author ~= nil then
              start = start .. "\\titleauthorpoem[" .. prefix .."]{" .. title .. "}{" .. author .."}"
            else
              start = start .. "\\titlepoem{" .. title .. "}"
            end
          elseif author ~= nil then
            start = start .. "\\titleauthorpoem[" .. prefix .."]{\\poemblanktitle}{" .. author .."}"
          end
          finish = "\\\\-\\end{poem}" .. finish
          -- break -- allow only first box!
        end
        local skip = div.attributes["skip"]
        if skip ~= nil and skips:includes(skip) then
          start = '\\' .. skip .. "skip{}" .. start
        end
        local break_after = div.attributes["break-after"]
        if break_after ~= nil and break_after ~= "" then
          finish = finish .. "\\newpage"
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
        local start = ""
        local finish = ""
        if span.classes:includes("key") then
          start = "\\fbox{\\small{}" .. start
          finish = finish .. "}"
        elseif span.classes:includes("rechts") then
          -- if FORMAT == "beamer" then
            start = "\\rechts{" .. start
            finish = "}"
          -- nonsense: only for paragraphs!
          -- else
          --   start = "\\begin{flushright}" .. start
          --   finish = finish .. "\\end{flushright}"
          -- end
        end
        if span.classes:includes("rkomment") then
          start = "\\rechts{\\emph{" .. start
          finish = finish .. "}}"
        end
        if span.classes:includes("emph") then
          -- start = "\\oldemph{"
          start = "\\emph{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("icon") then
          start = "\\icontext{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("lig") then
          start = "\\ligtext{\\unemph{" .. start
          finish = finish .. "}}"
        end
        if span.classes:includes("uni") then
          start = "\\unitext{\\unemph{" .. start
          finish = finish .. "}}"
        end
        if span.classes:includes("emoji") then
          start = "\\emojiText{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("underline")
        or span.classes:includes("ul") then
          start = "\\underline{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("unemph") then
          start = "\\unemph{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("fnhd_text") then
          start = "{\\normalfont\\unifont{}" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("so") or span.classes:includes("ls") or span.classes:includes("gesperrt") then
          start = "\\textso{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("name") then
          start = "\\textsc{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("sl") or span.classes:includes("slanted") or span.classes:includes("schraeg") then
          start = "\\textsl{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("transl") then
          start = "\\transl{" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("kbd") then
          start = "\\fbox{\\small{}\\bfseries{}" .. start
          finish = finish .. "}"
        end
        if span.classes:includes("comment") then
          local typ = "Highlight"
          if span.attributes["type"] ~= nil then
            typ = span.attributes["type"]
          end
          -- start = "\\pdftooltip[markup=".. typ .. ",color=Yellow]{" .. "\\pdfmarkupcomment[markup=".. typ .. ",color=Yellow]{" .. start
          -- finish = finish .. "}{".. span.attributes["text"] .."}" .. "}{".. span.attributes["text"] .."}"
          start = "\\pdfmarkupcomment[markup=".. typ .. ",color=Yellow]{" .. start
          finish = finish .. "}{".. span.attributes["text"] .."}"
        end
        if span.classes:includes("margincomment") then
          start = "\\pdfmargincomment[color=Yellow]{" .. span.attributes["text"] .. "}" .. start
          print("START: ".. start)
        end
        -- weird hack
        if span.classes:includes("endstanza") then
          finish = finish .. "\\\\!\\advance\\poemlineno by1"
        end
        if start or finish then
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
