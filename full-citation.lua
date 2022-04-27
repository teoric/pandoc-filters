-- from https://stackoverflow.com/questions/66600105/pandoc-citing-a-full-source
-- extended by adding the citation prefix and suffix.

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
      ret:insert(1, pandoc.Span(citation.prefix))
    end
    if pandoc.utils.stringify(citation.suffix) ~= nil then
      ret:extend({" ", pandoc.Span(citation.suffix)})
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
