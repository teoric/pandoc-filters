--
--------------------------------------------------------------------------------
--         File:  image-ms.lua
--
--        Usage:  ./image-ms.lua
--
--  Description:  make graphic a float in Pandoc -ms export
--                - make float if {float=true} or {float=1} in
--                  parameters
--                correct unlinkable labels in BibTeX ("/" -> "+")
--
--      Options:  ---
-- Requirements:  ---
--         Bugs:  ---
--        Notes:  ---
--       Author:  Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
-- Organization:  
--      Version:  0.1
--      Created:  30.03.2018
--     Revision:  ---
--------------------------------------------------------------------------------
--

-- local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'

keep_pattern = ".ANYPIC"


-- http://lua-users.org/wiki/StringRecipes

function string.starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

-- end

-- https://stackoverflow.com/questions/4990990/lua-check-if-a-file-exists
function file_exists(name)
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
-- end


return {
  {
    -- Str = function (str)
    --   if FORMAT == "ms" then
    --     -- Assumption: Strings are tokenised by whitespace;
    --     --    hence, we can rely on abbreviations' being on their own.
    --     local s = str.text
    --     -- German
    --     s = string.gsub(s, "^(Nr)%.", "%1.\\&")
    --     s = string.gsub(s, "^([Zz]%.Zt)%.", "%1.\\&")
    --     s = string.gsub(s, "^([Gg]gf)%.", "%1.\\&")
    --     s = string.gsub(s, "^([UuOo]%.a)%.", "%1.\\&")
    --     s = string.gsub(s, "^([UuOo]%.ä)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^([UuOo]%.Ä)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^([Zz]%.B)%.", "%1.\\&")
    --     s = string.gsub(s, "^([sS])%.", "%1.\\&")    -- (redundant)
    --     s = string.gsub(s, "^([Vv]gl)%.", "%1.\\&")
    --     s = string.gsub(s, "^([Uu]%.?s%.?w)%.", "%1.\\&")

    --     -- English
    --     s = string.gsub(s, "^([Pp]p?)%.", "%1.\\&")
    --     s = string.gsub(s, "^([Nn]o)%.", "%1.\\&")
    --     s = string.gsub(s, "^([Vv]ol)%.", "%1.\\&")
    --     s = string.gsub(s, "^(e%.g)%.", "%1.\\&")
    --     s = string.gsub(s, "^(i%.e)%.", "%1.\\&")
    --     s = string.gsub(s, "^(viz)%.", "%1.\\&")

    --     -- single letters
    --     s = string.gsub(s, "^(%l)%.", "%1.\\&")
    --     s = string.gsub(s, "^(Ä)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^(Ö)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^(Ü)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^(ä)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^(ö)%.", "%1.\\&") -- lua - not Unicode-capable
    --     s = string.gsub(s, "^(ü)%.", "%1.\\&") -- lua - not Unicode-capable
    --     if s ~= str.text then
    --       io.stderr:write(s.."\n")
    --       return pandoc.RawInline("ms", s)
    --     end
    --   end
    -- end,

    Table = function (tab)
      if FORMAT == "ms" then
        cap = pandoc.Plain(table.clone(tab.caption))
        -- cap = pandoc.utils.stringify(tab.caption) or ""
        tab.caption = {} -- delete old caption
        ret = List:new{
          pandoc.RawBlock("ms", ".TABLESTART\n"),
          tab,
        }
        if cap ~= nil then
          ret:extend({pandoc.RawBlock("ms", string.format('.TABLELABLE')),
                      cap})
        end
        ret:extend({pandoc.RawBlock("ms", string.format('.TABLEEND'))})
          -- pandoc.RawBlock("ms", string.format('.TABLEEND "%s"\n', cap)),
        return ret
      end
    end,

    Cite = function (cit)
      -- sanitize cite id
      -- this is not used, anyway!?
      if FORMAT == "ms" then
        for k, v in pairs(cit.c[1]) do
          v.id = string.gsub(v.id, '/', "+")
        end
        return cit
      end
    end,

    Link = function (cit)
      -- sanitize Link ID
      if FORMAT == "ms" then
        if string.sub(cit.c[3][1], 1, 1) == "#" then
          cit.c[3][1] = string.gsub(cit.c[3][1], '/', "+")
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
    
    Image = function (im)
      -- Image inclusion is by default disabled for ms in pandoc
      -- this uses the macro .ANYPIC to include PDF graphics
      --
      -- If there is no graphics file that can be included (PDF),
      -- it is generated by ImageMagicks convert – this may not be the
      -- optimal way to deal with this.
      --
      -- Determines size using pdfinfo not strictly necessary, but a
      -- starting point for changing size in ms.

      if FORMAT == "ms" then
        pat = keep_pattern
        if text.lower(im.attributes.float) == "true" or im.attributes.float == "1" then
          pat = pat .. " F"
        else
          pat = pat .. " S"
        end
        pat = pat .. string.format(' "%s"', pandoc.utils.stringify(im.caption))
        local im_src_old = im.src
        if not string.ends(text.lower(im.src), ".pdf") then
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
            -- size = pandoc.pipe('identify', {im.src}, "")
            -- _, _, w, h = string.find(size, "(%d+)x(%d+)")
            size = pandoc.pipe('pdfinfo', {im.src}, "")
            -- io.stderr:write(size)
            _, _, w, h = string.find(size, "Page size:%s+([%d.]+)%s+x%s+([%d.]+)")
            -- io.stderr:write(string.format("%s %s\n", w, h))
            pat = pat .. string.format(" %sp %sp", w, h)
          end
        end
        return pandoc.RawInline("ms", pat)
      end
    end,

  }
}
