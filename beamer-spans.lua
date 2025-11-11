
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
-- Last Changed: 2025-11-11 09:36:31 (+01:00)
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

local pdfcomment_author = nil

local doc_language = "en"
local bank_language = "en"

-- box types
local boxes = {
  "block",
  "goodbox", "badbox", "acceptbox",
  "claimbox",
  "yellowbox", "bluebox",
  "exbox", "exxbox"
}
local fontsizes = {
  "tiny",
  "scriptsize",
  "footnotesize",
  "small",
  "normalsize",
  "large",
  "Large",
  "LARGE",
  "huge",
  "Huge"
}

local markup_types = pandoc.List:new({
  "Highlight",
  "Underline",
  "Squiggly",
  "StrikeOut"
})

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

local qr_fields = {
  "bic",
  "name",
  "iban",
  "amount",
  "reason",
  "ref",
  "text",
  "information"
}

local qr_labels = {
  ["de"] = {
    ["bic"] = "BIC",
    ["name"] = "Name",
    ["iban"] = "IBAN",
    ["amount"] = "Betrag",
    ["reason"] = "Verwendungszweck",
    ["ref"] = "Referenz",
    ["text"] = "Text",
    ["information"] = "Zusatzinformation"
  }, 
  ["en"] = {
    ["bic"] = "BIC",
    ["name"] = "Name",
    ["iban"] = "IBAN",
    ["amount"] = "Amount",
    ["reason"] = "Reason",
    ["ref"] = "Reference",
    ["text"] = "Text",
    ["information"] = "Information"
  }
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
  if code:match("^%s*$") then
    return pandoc.Span("")
  end
  local md_text = pandoc.read(code, "markdown")
  return pandoc.Span(md_text.blocks[1].c)
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
        doc_language = meta.lang
        bank_language = "de"
      end
      if meta["pdfcomment-author"] ~= nil then
        pdfcomment_author = utils.stringify(meta["pdfcomment-author"])
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
          local start = List:new()
          local finish = List:new()
          if color ~= nil then
            -- remove color attributes
            el.attributes['color'] = nil
            table.insert(el.content, 1, pandoc.RawInline(FORMAT, '\\textcolor{'..color..'}{'))
            table.insert(el.content, pandoc.RawInline(FORMAT, "}"))
          end
          if bgcolor ~= nil then
            -- remove color attributes
            el.attributes['bgcolor'] = nil
            table.insert(el.content, 1, pandoc.RawInline(FORMAT, '\\colorbox{'..bgcolor..'}{'))
            table.insert(el.content, pandoc.RawInline(FORMAT, "}"))
          end
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
      for i, b in pairs(fontsizes) do
        if el.classes:includes(b) then
          if FORMAT:match 'latex' or FORMAT:match 'beamer' then
            table.insert(
              el.content, 1,
              pandoc.RawInline('latex', '\\begingroup\\' .. b .. '{}')
            )
            table.insert(
              el.content,
              pandoc.RawInline('latex', '\\endgroup')
            )
            -- returns only span content
            -- return el.content
          else
            -- for other format return unchanged
            -- return el
          end
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
        -- local start = List:new({
        -- local finish = List:new({})
        local start = List:new()
        local finish = List:new()
        -- wrap div in box containers
        if div.classes:includes("only") then
          local scope = div.attributes["scope"] or "+-"
          table.insert(start, 1, pandoc.RawInline(FORMAT, "\\only<" .. scope ..
          ">{"))
          table.insert(finish, pandoc.RawInline(FORMAT, "}"))
        end
        if div.classes:includes("uncover") then
          local scope = div.attributes["scope"] or "+-"
          table.insert(start, 1, pandoc.RawInline(FORMAT, "\\uncover<" .. scope ..
          ">{"))
          table.insert(finish, pandoc.RawInline(FORMAT, "}"))
        end
        if div.classes:includes("on_next") then
          local scope = div.attributes["scope"] or "+"
          table.insert(start, 1, pandoc.RawInline(FORMAT, "\\only<" .. scope .. ">{"))
          table.insert(finish, pandoc.RawInline(FORMAT, "}"))
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
            table.insert(start, pandoc.RawInline(FORMAT, "\\begin{" .. b .. "}" .. scope ..  "{"))
            local title_span = pandoc.Span(eval_md(title))
            table.insert(start,  title_span)
            if div.attributes["rechts"] then
              table.insert(title_span.c, pandoc.Span(
                {pandoc.RawInline(FORMAT, "\\rechtsanm{"),
                eval_md(div.attributes["rechts"]),
                pandoc.RawInline(FORMAT, "}")}))
            end
            table.insert(start, pandoc.RawInline(FORMAT, "}"))
            table.insert(finish, 1, pandoc.RawInline(FORMAT, "\\end{" .. b .. "}"))
            -- break -- allow only first box!
          end
        end
        for i, b in pairs(boxes_optional) do
          if div.classes:includes(b) then
            local title = div.attributes["title"] or ""
            -- io.stderr:write(title .. "\n")
            table.insert(start, pandoc.RawInline(FORMAT, start .. "\\begin{" .. b .. "}" ..  "["))
            local title_span = pandoc.Span(eval_md(title))
            table.insert(start,  title_span)
            if div.attributes["rechts"] then
              table.extend(title_span.c,
                {pandoc.RawInline(FORMAT, "\\rechtsanm{"),
                eval_md(div.attributes["rechts"]),
                pandoc.RawInline(FORMAT, "}")})
            end
            table.insert(start, pandoc.RawInline(FORMAT, "}"))
            table.insert(finish, 1, pandoc.RawInline(FORMAT, "\\end{" .. b .. "}"))
            -- break -- allow only first box!
          end
        end
        if div.classes:includes("lineno") then
          -- io.stderr:write(title .. "\n")
          local start_no = div.attributes["start"] or "1"
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{linenumbers}[" .. start_no .. "]"))
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
          table.insert(start, pandoc.RawInline(FORMAT, '\\' .. skip .. "skip{}"))
        end
        if start ~= "" then
          local ret = start
          ret:extend(div.content)
          ret:extend(finish)
          div.content = ret
        end
        return div
      elseif FORMAT == "latex" then
        local start = List:new()
        local finish = List:new()
        if div.classes:includes("sideways") then
          -- io.stderr:write(title .. "\n")
          table.insert(start, pandoc.RawInline(FORMAT,  "\\begin{sideways}"))
          table.insert(finish, 1, pandoc.RawInline(FORMAT,"\\end{sideways}"))
          -- break -- allow only first box!
        end
        if div.classes:includes("multicols") then
          local number = div.attributes["columns"] or "2"
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{multicols}{" .. number .. "}"))
          table.insert(finish, 1, pandoc.RawInline(FORMAT, "\\end{multicols}"))
        end
        -- wrap div in box containers
        for i, b in pairs(boxes) do
          if div.classes:includes(b) then
            local title=div.attributes["title"] or ""
            -- io.stderr:write(title .. "\n")
            table.insert(start, pandoc.RawInline(FORMAT, "\\begin{tcolorbox}["))
            if div.classes:includes("breakable") then
              table.insert(start, pandoc.RawInline(FORMAT, "breakable"))
            end
            if title ~= nil and title ~= "" then
              if start:match("[^%]]$") then
                table.insert(start, pandoc.RawInline(FORMAT, ","))
              end
              table.extend(start, {pandoc.RawInline(FORMAT, "title={"), eval_md(title), pandoc.RawInline(FORMAT, "}")})
            end
            table.insert(start, pandoc.RawInline(FORMAT, "]"))
            if div.attributes["rechts"] then
              table.extend(start,
                {pandoc.RawInline(FORMAT, "\\rechtsanm{"),
                eval_md(div.attributes["rechts"]),
                pandoc.RawInline(FORMAT, "}")})
            end
            table.insert(finish, 1, pandoc.RawInline(FORMAT, "\\end{tcolorbox}"))
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
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{tcolorbox}[title=" .. table.concat(div.classes, ";;") .. "]"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\end{tcolorbox}")
          -- table.insert(start, pandoc.RawInline(FORMAT, "\\begin{addmargin}[1cm]{1cm}" .. color .."\\vskip1ex\\begingroup\\textbf{" .. table.concat(div.classes, ";;") .. "}"))
          -- table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\endgroup\\vskip1ex\\end{addmargin}")
        elseif (color ~= nil) then
          table.insert(start, pandoc.RawInline(FORMAT, '{' .. color))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, '}')
        end
        if div.attributes["linestretch"] then
          table.insert(start, pandoc.RawInline(FORMAT, '\\bgroup\\setstretch{' .. div.attributes["linestretch"] ..'}'))
          finish = '\\egroup{}' .. finish
        end
        if div.attributes["bgcolor"] then
          table.insert(start, pandoc.RawInline(FORMAT, '\\begin{tcolorbox}[colback='.. div.attributes["bgcolor"] ..'!20, colframe=' .. div.attributes["bgcolor"] .. '!80!black]'))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, '\\end{tcolorbox}')
        end
        if div.classes:includes("xml") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\paragraph{XML}\\begingroup\\sffamily{}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\endgroup{}")
        end
        if div.classes:includes("xml_details") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{addmargin}{1em}\\sffamily{}\\relsize{-1}\\color{darkgray}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\end{addmargin}")
        end
        if div.classes:includes("transcription") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{aeettranscription}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\end{aeettranscription}")
        end
        if div.classes:includes("references") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{aeetreferences}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\end{aeetreferences}")
        end
        if div.classes:includes("figure_text") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{figureText}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\end{figureText}")
        end
        if div.classes:includes("lineno") then
          -- io.stderr:write(title .. "\n")
          local start_no = div.attributes["start"] or "1"
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{linenumbers}[" .. start_no .. "]"))
          finish = "\\end{linenumbers}" .. finish
          -- break -- allow only first box!
        end
        if div.classes:includes("verse") then
          -- io.stderr:write(title .. "\n")
          table.insert(start, pandoc.RawInline(FORMAT, "\\begin{poem}"))
          local title = div.attributes["title"]
          local author = div.attributes["author"]
          local prefix = div.attributes["prefix"] or ""
          if title ~= nil then
            if author ~= nil then
              table.insert(start, pandoc.RawInline(FORMAT, "\\titleauthorpoem[" .. prefix .."]{" .. title .. "}{" .. author .."}"))
            else
              table.insert(start, pandoc.RawInline(FORMAT, "\\titlepoem{" .. title .. "}"))
            end
          elseif author ~= nil then
            table.insert(start, pandoc.RawInline(FORMAT, "\\titleauthorpoem[" .. prefix .."]{\\poemblanktitle}{" .. author .."}"))
          end
          table.insert(finish, 1 , pandoc.RawInline(FORMAT, "\\\\-\\end{poem}"))
          -- break -- allow only first box!
        end
        local skip = div.attributes["skip"]
        if skip ~= nil and skips:includes(skip) then
          table.insert(start, pandoc.RawInline(FORMAT, '\\' .. skip .. "skip{}"))
        end
        local break_after = div.attributes["break-after"] or div.classes:includes("break_after")
        if break_after ~= nil and break_after ~= false and break_after ~= "" then
          print(break_after)
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\newpage")
        end
        if start ~= nil then
          local ret = List:new(start)
          ret:extend(div.content)
          ret:extend(finish)
          div.content = ret
          return div
        end
      end
    end,
    Span = function(span)
      if FORMAT:match 'html' or FORMAT:match 'html5' then
        if span.classes:includes("comment") then
          local typ = span.attributes["type"] or "Highlight"
          local color = "Yellow"
          local text = ""
          local author = ""
          if not markup_types:includes(typ) then
            io.stderr:write(string.format("Unknown markup type %s in comment span, replacing by 'Highlight'\n", typ))
            typ = "Highlight"
          elseif typ == "StrikeOut" then
            color = "Red"
          elseif typ == "Squiggly" then
            color = "Red"
          elseif typ == "Underline" then
            color = "Red"
          end
          if span.attributes["author"] ~= nil then
            author = span.attributes["author"]
          elseif pdfcomment_author ~= nil then
            author = pdfcomment_author
          else
            author = utils.stringify(author)
          end
          if span.attributes["text"] ~= nil then
            text = span.attributes["text"]
          end
          if span.attributes["hl-color"] ~= nil then
            color = span.attributes["hl-color"]
            span.attributes["style"] = "background-color: " .. color .. ";"
          end
          span.classes:insert("mark")
          if text ~= "" then
            span.attributes["title"] = text
          end
          if author ~= "" then
            if span.attributes["title"] ~= nil then
              span.attributes["title"] = "(" .. author .. ") " .. span.attributes["title"]
            else
              span.attributes["title"] = "(" .. author .. ")"
            end
          end
          return span
        end
      elseif FORMAT == "beamer" or FORMAT == "latex" then
        local start = List:new()
        local finish = List:new()
        if span.classes:includes("key") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\fbox{\\small{}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        elseif span.classes:includes("rechts") then
          -- if FORMAT == "beamer" then
            table.insert(start, pandoc.RawInline(FORMAT, "\\rechts{"))
            table.insert(finish, 1, pandoc.RawInline(FORMAT, "}"))
          -- nonsense: only for paragraphs!
          -- else
          --   table.insert(start, pandoc.RawInline(FORMAT, "\\begin{flushright}"))
          --   table.insert(pandoc.RawInline(FORMAT, finish), 1, "\\end{flushright}")
          -- end
        end
        if span.classes:includes("rkomment") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\rechts{\\emph{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}}")
        end
        if span.classes:includes("sans") or span.classes:includes("sf") then
          -- start = "\\oldemph{"
          table.insert(start, pandoc.RawInline(FORMAT, "\\textsf{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("emph") then
          -- start = "\\oldemph{"
          table.insert(start, pandoc.RawInline(FORMAT, "\\emph{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("bank_transfer") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\epcqr{"))
          table.insert(finish, pandoc.LineBreak())
          local field_list = List:new()
          local qr_first = true
          for i, qr_name in pairs(qr_fields) do
            if span.attributes[qr_name] ~= nil then
              table.insert(start, pandoc.RawInline(FORMAT, qr_name .. "=".. span.attributes[qr_name] .. ",\n"))
              table.insert(finish,
                pandoc.Span({(qr_first and "" or ",\n"), pandoc.LineBreak(), pandoc.Strong(qr_labels[bank_language][qr_name]), ": "}))
              if qr_name == "amount" and not string.match(bank_language, "^[eE][nN]")then
                span.attributes[qr_name] = string.gsub(span.attributes[qr_name], "%.", ",")
              end
              table.insert(finish,
                pandoc.Span(span.attributes[qr_name]))
              if qr_name == "amount" then
                table.insert(finish,
                  pandoc.Span(" €"))
              end
              qr_first = false
            end
          end
          table.insert(start, pandoc.RawInline(FORMAT, "}"))
        end
        if span.classes:includes("icon") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\icontext{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("lig") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\ligtext{\\unemph{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}}")
        end
        if span.classes:includes("uni") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\unitext{\\unemph{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}}")
        end
        if span.classes:includes("emoji") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\emojiText{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("underline")
        or span.classes:includes("ul") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\underline{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("unemph") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\unemph{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("fnhd_text") then
          table.insert(start, pandoc.RawInline(FORMAT, "{\\normalfont\\unifont{}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("so") or span.classes:includes("ls") or span.classes:includes("gesperrt") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\textso{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("name") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\textsc{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("sl") or span.classes:includes("slanted") or span.classes:includes("schraeg") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\textsl{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("transl") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\transl{"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("kbd") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\fbox{\\small{}\\bfseries{}"))
          table.insert(pandoc.RawInline(FORMAT, finish), 1, "}")
        end
        if span.classes:includes("number") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\mbox{\\small{}\\bfseries{}"))
          table.insert(finish, 1, pandoc.RawInline(FORMAT, ".}"))
        end
        if span.classes:includes("comment") then
          local typ = span.attributes["type"] or "Highlight"
          local color = "Yellow"
          local author=""
          local text = ""
          if not markup_types:includes(typ) then
            io.stderr:write(string.format("Unknown markup type %s in comment span, replacing by 'Highlight'\n", typ))
            typ = "Highlight"
          elseif typ == "StrikeOut" then
            color = "Red"
          elseif typ == "Squiggly" then
            color = "Red"
          elseif typ == "Underline" then
            color = "Red"
          end
          if span.attributes["text"] ~= nil then
            text = span.attributes["text"]
          end
          if span.attributes["author"] ~= nil then
            author = span.attributes["author"]
          elseif pdfcomment_author ~= nil then
            author = pdfcomment_author
          end
          if span.attributes["type"] ~= nil then
            typ = span.attributes["type"]
          end
          if span.attributes["hl-color"] ~= nil then
            color = span.attributes["hl-color"]
          end
          -- table.insert(start, pandoc.RawInline(FORMAT, "\\pdftooltip[markup=".. typ .. ",color=Yellow]{" .. "\\pdfmarkupcomment[markup=".. typ .. ",color=Yellow]{"))
          -- table.insert(pandoc.RawInline(FORMAT, finish), 1, "}{".. span.attributes["text"] .."}" .. "}{".. span.attributes["text"] .."}")
          local prefix = "\\pdfmarkupcomment[markup=".. typ .. ",color=" .. color
          if author ~= "" then
            prefix = prefix .. ",author={" .. author .. "}"
          end
          prefix = prefix .. "]{"
          table.insert(start, pandoc.RawInline(FORMAT, prefix))
          table.insert(finish, 1, pandoc.RawInline(FORMAT, "}{".. text .."}"))
        end
        if span.classes:includes("margincomment") then
          table.insert(start, pandoc.RawInline(FORMAT, "\\pdfmargincomment[color=Yellow]{" .. text .. "}"))
          print("START: ".. start)
        end
        -- weird hack

        if span.classes:includes("endstanza") then
          table.insert(finish, 1, pandoc.RawInline(FORMAT, "\\\\!\\advance\\poemlineno by1"))
        end
        if start or finish then
          local ret = List:new(start)
          ret:extend(span.content)
          ret:extend(finish)
          return {
            pandoc.Span(ret, span.attr)
          }
        end
      end
    end
  }
}
