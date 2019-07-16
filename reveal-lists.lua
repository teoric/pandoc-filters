--
--------------------------------------------------------------------------------
--         File: image-ms.lua
--
--        Usage: pandoc --lua-filter=reveal-lists.lua
--
--  Description: make list items in reveal appear in paragraphs, always
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2018-03-30
-- Last Changed: 2019-07-16, 10:16:03 (CEST)
--------------------------------------------------------------------------------
--

local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
-- io.stderr:write(FORMAT .. "\n")
return {{
  BulletList = function(list)
    if FORMAT == "revealjs" then
      return pandoc.walk_block(list, {
        Plain = function(p)
          return pandoc.Para(p.c)
        end
      })
    end
  end
}}
