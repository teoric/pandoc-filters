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
-- Last Changed: 2019-08-08, 15:15:40 (CEST)
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
    if string.startswith(el.target, "file:") then
      local file = string.gsub(el.target, "^file:/*", "")
      if file_exists(file) then
        io.stderr:write(string.format("will include %s\n", file))
        return pandoc.RawInline(
          "beamer",
          string.format("\\textattachfile{%s}{%s}",
            file,
            utils.stringify(el)))
      else
        io.stderr:write("cannot attach '" .. file .. "' (does not exist).")
      end
    elseif el.attributes["type"] == "ANNIS" then
      local base = el.attributes["base"]
      if base == nil then
            io.stderr:write("base missing ".. utils.stringify(el) .."\n")
      end
      -- add slash to base if necessary
      if not(string.endswith(base, "/")) then
        base = base .. "/"
      end
      local corpus = el.attributes["corpus"]
      if corpus == nil then
        io.stderr:write("corpus missing ".. utils.stringify(el) .."\n")
      end
      -- io.stderr:write(utils.stringify(el) .. "\n")
      el.target =  base ..
      "#_q=" .. base64(trim1(utils.stringify(el))) ..
      "&_c=" .. base64(trim1(corpus))
      -- io.stderr:write(el.target .. "\n")
      return el
    elseif el.attributes["type"] == "KorAP" then
      local base = el.attributes["base"]
      if base == nil then
        io.stderr:write("base missing ".. utils.stringify(el) .."\n")
      end
      local lang = el.attributes["lang"]
      if lang == nil then
        io.stderr:write("lang missing ".. utils.stringify(el) .."\n")
      end
      -- io.stderr:write(utils.stringify(el) .. "\n")
      el.target =  base ..
      "?q=" .. urlencode(trim1(utils.stringify(el))) ..
      "&ql=" .. urlencode(trim1(lang))
      -- io.stderr:write(el.target .. "\n")
      return el
    elseif el.attributes["type"] == "RegExr" then
      local base = "https://regexr.com/"
      local text = el.attributes["text"]
      if text == nil then
        text = "Please enter some text to test the RegEx!"
      end
      -- io.stderr:write(utils.stringify(el) .. "\n")
      el.target =  base ..
      "?expression=" .. urlencode("/"..trim1(utils.stringify(el)).."/g") ..
      "&engine=pcre&text=" .. urlencode(trim1(text))
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
