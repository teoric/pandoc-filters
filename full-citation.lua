-- from https://stackoverflow.com/questions/66600105/pandoc-citing-a-full-source
-- extended by adding the citation prefix and suffix.
-- not perfect in case of punctuation etc.

local refs = {}

local function store_refs (div)
  local ref_id = div.identifier:match 'ref%-(.*)$'
  if ref_id then
    refs[ref_id] = div.content
  end
end

local function replace_cite (cite)
  -- only works for single citations
  local citation = cite.citations[1]
  if citation and refs[citation.id] and #cite.citations == 1 then
    local ret = pandoc.utils.blocks_to_inlines(refs[citation.id])
    if pandoc.utils.stringify(citation.prefix) ~= "" then
      ret:insert(1, " ")
      for key, value in pairs(citation.prefix) do
        ret:insert(key, value)
      end
    end
    if pandoc.utils.stringify(citation.suffix) ~= nil then
      if string.sub(pandoc.utils.stringify(refs[citation.id]), -1) ~= " " then
        ret:insert(" ")
      end
      ret:extend(citation.suffix)
    end
    return ret
  end
end

return {
  {
    Div = store_refs
  },
  {
    Cite = replace_cite
  },
}
