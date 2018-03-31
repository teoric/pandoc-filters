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
local List = require 'pandoc.List'

keep_pattern = ".ANYPIC"


-- http://lua-users.org/wiki/StringRecipes

function string.starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

-- end

function convert_measurements(size)
  if size ~= nil then
    size = string.gsub(size, "[;:,]$", "")
    size = string.gsub(size, "pt$", "p")
    size = string.gsub(size, "em$", "m")
    size = string.gsub(size, "ex$", "n")
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
      -- this is not used, anyway!?
      for k, v in pairs(cit.c[1]) do
        v.id = string.gsub(v.id, '/', "+")
      end
      return cit
    end,

    Link = function (cit)
      cit.c[3][1] = string.gsub(cit.c[3][1], '/', "+")
      return cit
    end,

    Div = function(div)
      -- this is not used, anyway!?
      if FORMAT == "ms" then
        if string.find(div.c[1][1], "^ref-.*/") then
          io.stderr:write("changed label «" .. div.c[1][1].."»\n")
          div.c[1][1] = string.gsub(div.c[1][1], '/', '+')
        end
      end
    end,
    
    Image = function (im)
      if FORMAT == "ms" then
        pat = keep_pattern
        if text.lower(im.attributes.float) == "true" or im.attributes.float == "1" then
          pat = pat .. " F"
        else
          pat = pat .. " S"
        end
        pat = pat .. string.format(' "%s"', pandoc.utils.stringify(im.caption))
        if not string.ends(text.lower(im.src), ".pdf") then
          im.src = im.src .. ".pdf"
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
            io.stderr:write(string.format("%s %s\n", w, h))
            pat = pat .. string.format(" %sp %sp", w, h)
          end
        end
        return pandoc.RawInline("ms", pat)
      end
    end,

  }
}
