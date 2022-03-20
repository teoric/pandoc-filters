--
--------------------------------------------------------------------------------
--         File: reveal-lists.lua
--
--        Usage: pandoc --lua-filter=reveal-lists.lua
--
--  Description: make list items in reveal appear in paragraphs, always
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2018-03-30
-- Last Changed: 2019-08-08, 16:58:44 (CEST)
--------------------------------------------------------------------------------
--

-- local inspect = require('inspect')
local text = require 'text'
local list = require 'pandoc.List'
-- io.stderr:write(FORMAT .. "\n")
return {{
  BulletList = function(list_arg)
    if FORMAT == "revealjs" then
      return pandoc.walk_block(list_arg, {
        Plain = function(p)
          return pandoc.Para(p.c)
        end
      })
    end
  end
}}
