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
-- Last Changed: 2021-07-19, 12:58:02 (CEST)
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
- Unicode: link to character description; give hex code as link text
The filter also tries to include links starting with "file:" into PDFs
generated from LaTeX documents as embedded files.  (Will not work in all
PDF viewers, e.g. for me not in Evince.)

--]]

-- local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'
utils = require 'pandoc.utils'
-- io.stderr:write(FORMAT .. "\n")
local utilPath = string.match(PANDOC_SCRIPT_FILE, '.*[/\\]')
if PANDOC_VERSION >= {2,12} then
  local path = require 'pandoc.path'
  utilPath = path.directory(PANDOC_SCRIPT_FILE) .. path.separator
end
local loc_utils = dofile ((utilPath or '') .. 'utils.lua')
-- does not work anymore!
-- local loc_utils = require(debug.getinfo(1, "S").source:sub(2):match( "(.*[\\/])") .. "utils")


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

local server_types = loc_utils.get_keys(query_values)

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

-- get file concatenates
function read_file(file_name, limit)
  local file = assert(io.open(file_name, "r"))
  if limit == nil then
    limit = "*all"
  end
  local content = file:read(limit)
  file:close()
  return content
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
      if loc_utils.startswith(el.target, "file:") then
        local file = string.gsub(el.target, "^file:/*", "")
        if loc_utils.file_exists(file) then
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
        if not(loc_utils.endswith(base, "/")) then
          base = base .. "/"
        end
        local corpus = get_value("ANNIS", el, server, "corpus")
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "#_q=" .. loc_utils.base64(loc_utils.trim(utils.stringify(el))) ..
        "&_c=" .. loc_utils.base64(loc_utils.trim(corpus))
        -- io.stderr:write(el.target .. "\n")
        return el
      elseif typ == "KorAP" then
        local server = get_server(el, typ)
        local base = get_value(typ, el, server, "base")
        local lang = get_value(typ, el, server, "lang")
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "?q=" .. loc_utils.urlencode(loc_utils.trim(utils.stringify(el))) ..
        "&ql=" .. loc_utils.urlencode(loc_utils.trim(lang))
        -- io.stderr:write(el.target .. "\n")
        return el
      elseif el.attributes["type"] == "DWDS" then
        local base = "https://www.dwds.de/r"
        local query = loc_utils.urlencode(loc_utils.trim(utils.stringify(el)))
        el.target = base .. "?q=" .. query
        return el
      elseif el.attributes["type"] == "Unicode" then
        local base = "http://unicode.org/cldr/utility/character.jsp?a="
        local char = loc_utils.trim(utils.stringify(el))
        el.target = base .. string.gsub(char, "U%+", "")
        return el
      elseif el.attributes["type"] == "RegExr" then
        local base = "https://regexr.com/"
        local text = el.attributes["text"]
        local file = el.attributes["file"]
        if text == nil then
          if file == nil then
            text = "Please enter some text to test the RegEx!"
          else
            text = read_file(file, 1978)
          end
        end
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "?expression=" .. loc_utils.urlencode("/" .. loc_utils.trim(utils.stringify(el)) .. "/g") ..
        "&engine=pcre&text=" .. loc_utils.urlencode(loc_utils.trim(text))
        -- io.stderr:write(el.target .. "\n")
        return el
      end
    end
  }
}
