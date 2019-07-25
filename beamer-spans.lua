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

-- http://lua-users.org/wiki/BaseSixtyFour
local bs = { [0] =
   'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
   'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
   'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
   'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/',
}

local function base64(s)
   local byte, rep = string.byte, string.rep
   local pad = 2 - ((#s - 1) % 3)
   s = (s..rep('\0', pad)):gsub("...", function(cs)
      local a, b, c = byte(cs, 1, 3)
      return bs[a>>2] .. bs[(a&3)<<4|b>>4] .. bs[(b&15)<<2|c>>6] .. bs[c&63]
   end)
   return s:sub(1, #s-pad) -- .. rep('=', pad) -- need no padding
end

-- http://lua-users.org/wiki/StringTrim
function trim1(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end
-- http://lua-users.org/wiki/StringRecipes

--[[ -- as yet unused
function string.startswith(String, Start)
return string.sub(String, 1, string.len(Start)) == Start
end
--]]
function string.endswith(String, End)
return End=='' or string.sub(String, - string.len(End)) == End
end


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

  -- TODO: move to own file, does not depend on beamer.
  Link = function(el)
    if el.attributes["type"] == "ANNIS" then
        local base = el.attributes["base"]
        if not(string.endswith(base, "/")) then
          base = base .. "/"
        end
        el.target =  base ..
          "#_q=" .. base64(trim1(utils.stringify(el))) ..
          "&_c=" .. base64(trim1(el.attributes["corpus"]))
        io.stderr:write(el.target .. "\n")
        return el
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
