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

local server_defaults = {}
local server_types = {"ANNIS", "KorAP"}

function get_server(el, typ)
  local server = el.attributes["server"]
  if server == nil then
    local _
    server, _ = next(server_defaults[typ])
    -- io.stderr:write(string.format("determined %s server: %s\n", typ, server or "NONE"))
  end
  return server
end

function get_default(typ, el, server, feat)
  local val = el.attributes[feat]
  if not val and server then
    val = server_defaults[typ][server][feat]
  end
  if val == nil then
    error(val .. " missing ".. utils.stringify(el) .."\n")
  end
  return val
end

return {
  {
    Meta = function(meta)
      for s, typ in ipairs(server_types) do
        local meta_key = typ .. "-servers"
        server_defaults[typ] = {}
        if meta[meta_key] ~= nil then
          io.stderr:write(string.format("%s\n", meta_key))
          for server, config in pairs(meta[meta_key]) do
            -- io.stderr:write(string.format("%s\n", inspect(config)))
            server_defaults[typ][server] = {}
            for i, val in pairs(query_values[typ]) do
              io.stderr:write(string.format("- %s [%s]\n", val, utils.stringify(config[val])))
              server_defaults[typ][server][val] = utils.stringify(config[val])
            end
          end
        end
      end
      io.stderr:write(inspect(server_defaults).."\n")
      for k, v in pairs(server_defaults) do
        print(k)
      end
    end
  },
  {
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
        local base = get_default(typ, el, server, "base")
        -- add slash to base if necessary
        if not(string.endswith(base, "/")) then
          base = base .. "/"
        end
        local corpus = get_default("ANNIS", el, server, "base")
        -- io.stderr:write(utils.stringify(el) .. "\n")
        el.target =  base ..
        "#_q=" .. base64(trim1(utils.stringify(el))) ..
        "&_c=" .. base64(trim1(corpus))
        -- io.stderr:write(el.target .. "\n")
        return el
      elseif typ == "KorAP" then
        local server = get_server(el, typ)
        local base = get_default(typ, el, server, "base")
        local lang = get_default(typ, el, server, "lang")
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
  }
}
