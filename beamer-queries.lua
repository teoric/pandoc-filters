--
--------------------------------------------------------------------------------
--         File: beamer-queries.lua
--
--        Usage: pandoc --lua-filter=beamer-queries.lua
--
--  Description: generate query links to corpus search engines
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2019-07-20
-- Last Changed: 2019-08-08, 17:14:43 (+02:00)
--------------------------------------------------------------------------------
--[[

This filter generates links to corpus search engines like ANNIS and KorAP.
It supports the following query types, where the content of the query is
taken from the content of a link, and several parameters can be specified:

- ANNIS (defaults supported):
  - base: the base URL, e.g. http://corpling.uis.georgetown.edu/annis/
  - corpus: the name of the corpus, e.g. GUM
- KorAP (defaults supported):
  - base: the base URL, e.g. https://korap.ids-mannheim.de
  - lang: the query language, e.g. poliqarp
- DWDS
- RegExr:
  - text: the text on which to try the regular expression

The filter also tries to include links starting with "file:" into PDFs
generated from LaTeX documents as embedded files.  (Will not work in all
PDF viewers, e.g. for me not in Evince.)

--]]

local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
utils = require 'pandoc.utils'
-- io.stderr:write(FORMAT .. "\n")

require(debug.getinfo(1, "S").source:sub(2):match("(.*[\\/])") .. "utils")

-- https://stackoverflow.com/questions/6380820/get-containing-path-of-lua-file



-- features for which defaults can be defined, by query type
local query_values = {
  ["ANNIS"] = {
    "base",
    "corpus"
  },
  ["KorAP"] = {
    "base",
    "lang"
  }
}

local server_types = get_keys(query_values)

local server_defaults = {} -- will be filled from document metadata

--- get the server for a query, including defaults
-- @param el The Pandoc element
-- @param typ The type of query
function get_server(el, typ)
  local server = el.attributes["server"]
  if server == nil then
    local _
    server, _ = next(server_defaults[typ])
    -- io.stderr:write(string.format("determined %s server: %s\n", typ, server or "NONE"))
  end
  return server
end

--- get a value, relying on defaults
-- @param typ The type of query
-- @param el The Pandoc element
-- @param server The server for looking up defaults
-- @param feat The feature for which to get a value
function get_value(typ, el, server, feat)
  local val = el.attributes[feat]
  if not val and server then
    val = server_defaults[typ][server][feat]
  end
  if val == nil then
    error(string.format("%s missing [%s]\n", val, utils.stringify(el)))
  end
  return val
end

return {
  {
    -- get defaults
    Meta = function(meta)
      for s, typ in ipairs(server_types) do
        local meta_key = typ .. "-servers"
        server_defaults[typ] = {}
        if meta[meta_key] ~= nil then
          -- io.stderr:write(string.format("%s\n", meta_key))
          for server, config in pairs(meta[meta_key]) do
            -- io.stderr:write(string.format("%s\n", inspect(config)))
            server_defaults[typ][server] = {}
            for i, val in pairs(query_values[typ]) do
              -- io.stderr:write(string.format("- %s [%s]\n", val, utils.stringify(config[val])))
              server_defaults[typ][server][val] = utils.stringify(config[val])
            end
          end
        end
      end
    end
  },
  {
    -- process query links
    Link = function(el)
      local typ = el.attributes["type"]
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
      elseif typ == "ANNIS" then
        local server = get_server(el, typ)
        local base = get_value(typ, el, server, "base")
        -- add slash to base if necessary
        if not(string.endswith(base, "/")) then
          base = base .. "/"
        end
        local corpus = get_value("ANNIS", el, server, "base")
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "#_q=" .. base64(trim1(utils.stringify(el))) ..
        "&_c=" .. base64(trim1(corpus))
        -- io.stderr:write(el.target .. "\n")
        return el
      elseif typ == "KorAP" then
        local server = get_server(el, typ)
        local base = get_value(typ, el, server, "base")
        local lang = get_value(typ, el, server, "lang")
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "?q=" .. urlencode(trim1(utils.stringify(el))) ..
        "&ql=" .. urlencode(trim1(lang))
        -- io.stderr:write(el.target .. "\n")
        return el
      elseif el.attributes["type"] == "DWDS" then
        local base = "https://www.dwds.de/r"
        local query = urlencode(trim1(utils.stringify(el)))
        el.target = base .. "?q=" .. query
        return el
      elseif el.attributes["type"] == "RegExr" then
        local base = "https://regexr.com/"
        local text = el.attributes["text"]
        if text == nil then
          text = "Please enter some text to test the RegEx!"
        end
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "?expression=" .. urlencode("/" .. trim1(utils.stringify(el)) .. "/g") ..
        "&engine=pcre&text=" .. urlencode(trim1(text))
        -- io.stderr:write(el.target .. "\n")
        return el
      end
    end
  }
}
