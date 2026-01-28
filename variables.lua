-- https://pandoc.org/lua-filters.html#replacing-placeholders-with-their-metadata-value
-- https://stackoverflow.com/a/76584424
local vars = {}

function get_vars(meta)
  for k, v in pairs(meta) do
    if pandoc.utils.type(v) == "Inlines" then
      vars[k] = { table.unpack(v) }
    end
  end
end

-- does not work for multi-valued meta variables
function replace(el)
  local text = el.text
  for k, v in pairs(vars) do
    local inText = "%%" .. string.gsub(k, "%-", "%%-") .. "%%"
    text = string.gsub(text, inText, v[1].text)
  end
  return pandoc.Str(text)
end

return { { Meta = get_vars }, { Str = replace } }
