--
--------------------------------------------------------------------------------
--         File: image-ms.lua
--
--        Usage: pandoc --lua-filter=beamer-spans.lua
--
--  Description: handle queries to corpus search engines
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2018-03-30
-- Last Changed: 2019-07-26, 10:01:41 (CEST)
--------------------------------------------------------------------------------
--

local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
utils = require 'pandoc.utils'
-- io.stderr:write(FORMAT .. "\n")

require(debug.getinfo(1, "S").source:sub(2):match("(.*[\\/])") .. "utils")

-- https://stackoverflow.com/questions/6380820/get-containing-path-of-lua-file

return {{
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
      -- io.stderr:write(el.target .. "\n")
      return el
    elseif el.attributes["type"] == "DWDS" then
      local base = "https://www.dwds.de/r"
      local query = urlencode(trim1(utils.stringify(el)))
      el.target = base .. "?q=" .. query
      return el
    end
  end
}}
