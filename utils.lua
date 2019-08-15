local export = {}

-- -- https://stackoverflow.com/questions/6380820/get-containing-path-of-lua-file
-- function export.script_path()
--   return debug.getinfo(2, "S").source:sub(2):match("(.*[\\/])")
-- end
-- -- end https://stackoverflow.com/questions/6380820/get-containing-path-of-lua-file

-- http://lua-users.org/wiki/BaseSixtyFour
local bs = { [0] =
'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/',
}

--- encode according to base64
-- @param s String to encode
-- @param padding Whether to pad the resulting string (by default nil)
function export.base64(s, padding)
  local byte, rep = string.byte, string.rep
  local pad = 2 - ((#s - 1) % 3)
  s = (s .. rep('\0', pad)):gsub("...", function(cs)
    local a, b, c = byte(cs, 1, 3)
    return bs[a >> 2] .. bs[(a & 3) << 4 | b >> 4] ..
      bs[(b & 15) << 2 | c >> 6] .. bs[c & 63]
  end)
  local ret = s:sub(1, #s - pad)
  if padding then
    ret = ret .. rep('=', pad)
  end
  return ret
end
-- end http://lua-users.org/wiki/BaseSixtyFour

-- http://lua-users.org/wiki/StringTrim
function export.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end
-- http://lua-users.org/wiki/StringRecipes

function export.startswith(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end

function export.endswith(String, End)
  return End == '' or string.sub(String, - string.len(End)) == End
end

-- https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99

local function char_to_hex(c)
  return string.format("%%%02X", string.byte(c))
end

function export.urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end


function export.urldecode(url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end

-- ref: https://gist.github.com/ignisdesign/4323051
-- ref: http://stackoverflow.com/questions/20282054/how-to-urldecode-a-request-uri-string-in-lua
-- to encode table as parameters, see https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua

-- end https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99


--- check if a file exists
-- @param name The name of the hypothetical file
-- https://stackoverflow.com/questions/4990990/lua-check-if-a-file-exists
function export.file_exists(name)
  -- file exists if it is readable
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

--- get the keys of a table as a table (list)
-- @param tab The table
function export.get_keys(tab)
  local keys = {}
  for k, v in pairs(tab) do
    table.insert(keys, k)
  end
  return keys
end

return export
