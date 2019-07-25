--
--------------------------------------------------------------------------------
--         File: image-ms.lua
--
--        Usage: pandoc --lua-filter=image-ms.lua
--
--  Description: - make graphic a float in Pandoc -ms export
--                 - make float if {float=true} or {float=1} in
--                   parameters
--               - correct unlinkable labels in BibTeX ("/" -> "+")
--               - options to render small caps
--               - handle font within font
--               - wrap BlockQuote in .STARTQUOTE/.ENDQUOTE
--               - make links breakable
--               - scale references section down
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2018-03-30
-- Last Changed: 2019-07-25, 10:38:27 (CEST)
--------------------------------------------------------------------------------
--

local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'

-- pattern for keep macro:
local keep_pattern = ".ANYPIC"

-- characters to protect from Pandoc smartness
local protected = {"’", "…"} -- not used currently

-- references section title
local refsec = {
  References = true,
  Quellen = true,
  Literatur = true,
  Bibliographie = true,
  Bibliography = true,
  Bibliografia = true,
  ["Bibliografía"] = true,
}

local zero_space = "​"

-- http://lua-users.org/wiki/StringRecipes

--[[ -- as yet unused
function string.startswith(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end
--]]
function string.endswith(String, End)
  return End=='' or string.sub(String, - string.len(End)) == End
end

-- end

-- https://stackoverflow.com/questions/4990990/lua-check-if-a-file-exists
function file_exists(name)
  -- file exists if it is readable
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end
--

function convert_measurements(size)
  -- convert and guess HTML/LaTeX units to [gt]roff units
  if size ~= nil then
    size = string.gsub(size, "[;:,]$", "")
    size = string.gsub(size, "pt$", "p") -- pt called p
    size = string.gsub(size, "px$", "p") -- assuming 72 dpi, 1px is 1p
    size = string.gsub(size, "em$", "m") -- em called m
    size = string.gsub(size, "ex$", "n") -- ex called n
    if (string.match(size, "^[0-9.]+cm") or
      string.match(size, "^[0-9.]+p") or
      string.match(size, "^[0-9.]+P") or
      string.match(size, "^[0-9.]+in")) then
      return size
    end
  end
  return nil
end

-- http://lua-users.org/wiki/CopyTable
function table.clone(org)
  return {table.unpack(org)}
end

--[[
  function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
          copy[deepcopy(orig_key)] = deepcopy(orig_value)
      end
      setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
  end
--]]
-- end

local use_small_caps = false

local walker = {
  Strong=pandoc.walk_inline,
  Emph=pandoc.walk_inline,
  Header=pandoc.walk_block,
}

function embolden_emph(elem)
  if FORMAT == "ms" then
    return walker[elem.t](
      elem,
      {
        Emph = function (el)
          local ret = List:new({
              pandoc.RawInline("ms", "\\f[BI]"),
          })
          ret:extend(el.c)
          ret:extend({
              pandoc.RawInline("ms", "\\f[R]\\f[B]"),
          })
          return pandoc.Span(ret)
        end
    })
  end
end

function emphasize_bold(elem)
  if FORMAT == "ms" then
    return walker[elem.t](
      elem,
      {
        Strong = function (el)
          local ret = List:new({
              pandoc.RawInline("ms", "\\f[BI]")
          })
          ret:extend(el.c)
          ret:extend({
              pandoc.RawInline("ms", "\\f[R]\\f[I]"),
          })
          return pandoc.Span(ret)
        end
    })
  end
end

return {
  {
    Meta = function(meta)
      if meta["use-small-caps"] == true then
        use_small_caps = "small-caps"
      elseif meta["use-small-caps"] == false then
        use_small_caps = "none"
      else
        use_small_caps = (meta["use-small-caps"] ~= nil) and text.lower(meta["use-small-caps"][1].c)
      end
    end,
    Link = function (cit)
      -- hangs if in last filter
      function space(el)
        -- allow line breaking of links
        if el.t == "Str" then
          el.c = string.gsub(el.c, "/", "/" .. zero_space)
          el.c = string.gsub(el.c, "%.", "." .. zero_space)
          el.c = string.gsub(el.c, "_", "_" .. zero_space)
        end
      end
      cit.c[2]:map(space)
      return cit
    end,
  },
  {
    Table = function (tab)
      -- wrap tables in macros and a caption macro
      -- RESULT:
      -- .TABLESTART
      -- .\" (table)
      -- .TABLELABLE \" if caption
      -- .\" caption if given
      -- .TABLEEND
      if FORMAT == "ms" then
        cap = pandoc.Plain(table.clone(tab.caption))
        -- cap = pandoc.utils.stringify(tab.caption) or ""
        tab.caption = {} -- delete old caption
        local ret = List:new{
          pandoc.RawBlock("ms", ".TABLESTART\n"),
          tab,
        }
        if cap ~= nil then
          ret:extend({pandoc.RawBlock("ms", string.format('.TABLELABLE')),
                      cap})
        end
        ret:extend({pandoc.RawBlock("ms", string.format('.TABLEEND'))})
        return ret
      end
    end,

    Cite = function (cit)
      -- sanitize cite id
      -- this is not used, anyway!?
      if FORMAT == "ms" then
        for k, v in pairs(cit.citations) do
          v.id = string.gsub(v.id, '/', "+")
        end
        return cit
      end
    end,

    Div = function(div)
      -- sanitize div id
      -- this is not used, anyway!?
      if FORMAT == "ms" then
        if string.find(div.c[1][1], "^ref-.*/") then
          div.c[1][1] = string.gsub(div.c[1][1], '/', '+')
        end
      end
    end,

    DefinitionList = function(div)
      -- make definitions Bold
      if FORMAT == "ms" then
        for i = 1, #(div.c) do
          local ret = pandoc.List:new{}
          for j = 1, #(div.c[i][1]) do
            ret:extend({pandoc.Strong(div.c[i][1][j])})
          end
          div.c[i][1] = ret
        end
        return div
      end
    end,

    Link = function (cit)
      -- sanitize Link ID
      -- protect against https://github.com/jgm/pandoc/issues/4515
      if FORMAT == "ms" then
        if string.sub(cit.c[3][1], 1, 1) == "#" then
          cit.c[3][1] = string.gsub(cit.c[3][1], '/', "+")
        end
        return cit
      end
    end,

    Image = function (im)
      -- cf. https://github.com/jgm/pandoc/issues/4475
      -- Image inclusion is by default disabled for ms in pandoc
      -- this uses the private macro .ANYPIC to include PDF graphics
      --
      -- uses image property `float`; if set, uses ANYPIC F
      --
      -- If there is no graphics file that can be included (PDF),
      -- it is generated by ImageMagicks convert – this may not be the
      -- optimal way to deal with this.
      --
      -- Determines size using pdfinfo not strictly necessary, but a
      -- starting point for changing size in ms.
      --
      if FORMAT == "ms" then
        pat = keep_pattern
        if text.lower(im.attributes.float) == "true" or im.attributes.float == "1" then
          pat = pat .. " F"
        else
          pat = pat .. " S"
        end
        pat = pat .. string.format(' "%s"', pandoc.utils.stringify(im.caption))
        local im_src_old = im.src
        if not string.endswith(text.lower(im.src), ".pdf") then
          im.src = string.gsub(im.src, "%.[^.]+$", ".pdf")
        end
        if not file_exists(im.src) and file_exists(im_src_old) then
          pandoc.pipe("convert", {im_src_old, im.src}, "")
        end
        pat = pat .. string.format(' "%s"', im.src)
        if im.attributes ~= nil then
          if im.attributes.width ~= nil then
            im.attributes.width = convert_measurements(im.attributes.width)
          end
          if im.attributes.height ~= nil then
            im.attributes.height = convert_measurements(im.attributes.height)
          end
          if im.attributes.width ~= nil then
            pat = pat .. string.format(' "%s"', im.attributes.width)
            -- height only matters if width was given
            if im.attributes.height ~= nil then
              pat = pat .. string.format(' "%s"', im.attributes.height)
            end
          else
            size = pandoc.pipe('pdfinfo', {im.src}, "")
            _, _, w, h = string.find(size, "Page size:%s+([%d.]+)%s+x%s+([%d.]+)")
            pat = pat .. string.format(" %sp %sp", w, h)
          end
        end
        return pandoc.RawInline("ms", pat)
      end
    end,
    BlockQuote = function(el)
      return {
        pandoc.RawBlock("ms", ".STARTQUOTE"),
        el,
        pandoc.RawBlock("ms", ".ENDQUOTE"),
      }
    end,
    Header = embolden_emph,
    Strong = embolden_emph,
    Emph = emphasize_bold,
    SmallCaps = function (elem)
      -- use different macros for small caps – potentially better than size escapes
      if FORMAT == "ms" then
        if use_small_caps == "underline" then
          return List:new{
            pandoc.RawInline("ms",
                             string.format('\\c\n.UL "%s"\\c\n', pandoc.utils.stringify(elem.c)))
          }
        elseif use_small_caps == "space-out" then
          return List:new{
            pandoc.RawInline("ms",
                             string.format('\\c\n.SPERR "%s"\n', pandoc.utils.stringify(elem.c)))
          }
        elseif use_small_caps == "small-caps" then
          local ret = List:new{
            pandoc.RawInline("ms", '\n.smallcaps\n')
          }
          for i, el in pairs(elem.c) do
            ret:extend({el})
          end
          ret:extend({pandoc.RawInline("ms", '\\c\n./smallcaps\n')})
          return ret
        elseif use_small_caps == "all-caps" then
          return pandoc.walk_inline(
            pandoc.Span(elem.c), {
              Str = function(el)
                return pandoc.Str(text.upper(el.text))
              end
          })
        elseif use_small_caps == "strong" then
          return pandoc.Strong(elem.c)
        elseif use_small_caps == "emph" then
          return pandoc.Emph(elem.c)
        elseif use_small_caps == "none" then
          return pandoc.Span(elem.c)
        elseif use_small_caps == "pandoc-default" then
        end
      end
    end,

    Str = function(str)
        -- Protect letters in `protected` against smartness
        -- Protect U+2019 against https://github.com/jgm/pandoc/issues/4550
      if FORMAT == "ms" then
        local s = str.c
        local substrings = List:new()
        local i = 1
        while i <= text.len(s) do
          local il
          for j, p in ipairs(protected) do
            il = text.len(p)
            skip = 1
            if text.sub(s, i, i + il - 1) == p then
              substrings:extend({{i, il}})
              skip = il
              break
            end
          end
          i = i + skip
        end
        local old_start = 1
        local ret = List:new()
        substrings:map(function (p)
            local start = p[1]
            local il = p[2]
            if start > old_start then
              ret:extend({pandoc.Str(text.sub(s, old_start, start - 1))})
            end
            ret:extend({pandoc.RawInline("ms", text.sub(s, start, start + il - 1))})
            old_start = start + il
        end)
        if old_start <= text.len(s) then
          ret:extend({pandoc.Str(text.sub(s, old_start, text.len(s)))})
        end
        return ret
      end
    end,
  },
  {
    Header = function (h)
      if FORMAT == "ms" then
        if refsec[pandoc.utils.stringify(h)] then
          return {pandoc.RawBlock("ms", ".REF_SIZE"), h}
        else
          return {pandoc.RawBlock("ms", ".RESTORE_SIZE"), h}
        end
      end
    end,
  }
}
