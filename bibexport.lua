-- from https://github.com/pandoc/lua-filters
--
-- - added unlinking of `bibexport.bib` to prevent backups
--
local utils = require 'pandoc.utils'
local List = require 'pandoc.List'

local citation_id_set = {}

-- Collect all citation IDs.
function Cite (c)
  local cs = c.citations
  for i = 1, #cs do
    citation_id_set[cs[i].id or cs[i].citationId] = true
  end
end

--- Return a list of citation IDs
function citation_ids ()
  local citations = {};
  for cid, _ in pairs(citation_id_set) do
    citations[#citations + 1] = cid
  end
  return citations
end

function bibdata (bibliography)
  function bibname (bibitem)
    if type(bibitem) == 'string' then
      return bibitem:gsub('%.bib$', '')
    else
      -- bibitem is assumed to be a list of inlines
      return utils.stringify(pandoc.Span(bibitem)):gsub('%.bib$', '')
    end
  end

  local bibs = bibliography.t == 'MetaList'
    and List.map(bibliography, bibname)
    or {bibname(bibliography)}
  return bibs
end

function yamlify(bibs, citations)
  local biby = io.open("bibexport.yaml", "w")
  biby:write("bibliographies:\n")
  for i, b in ipairs(bibs) do
    biby:write(string.format("- %s\n", b))
  end
  biby:write("cite-keys:\n")
  for i, b in ipairs(citations) do
    biby:write(string.format("- %s\n", b))
  end
  biby:close()
end

function aux_content(bibliography)
  local cites = citation_ids()
  table.sort(cites)
  local citations = table.concat(cites, ',')
  local bibs = bibdata(bibliography)
  yamlify(bibs, cites)
  return table.concat(
    {
      '\\bibstyle{alpha}',
      '\\bibdata{' .. table.concat(bibs, ',') .. '}',
      '\\citation{' .. citations .. '}',
      '',
    },
    '\n'
  ), bibs
end

function write_dummy_aux (bibliography, auxfile)
  local filename
  if type(auxfile) == 'string' then
    filename = auxfile
  elseif type(auxfile) == 'table' then
    -- assume list of inlines
    filename = utils.stringify(pandoc.Span(auxfile))
  else
    filename = 'bibexport.aux'
  end
  local fh = io.open(filename, 'w')
  local aux_cont, bibs = aux_content(bibliography)
  fh:write(aux_cont)
  fh:close()
  io.stderr:write('Aux written to ' .. filename .. '\n')
  return filename, bibs
end

function Pandoc (doc)
  local meta = doc.meta
  if not meta.bibliography then
    return nil
  else
    -- create a dummy .aux file
    local auxfile_name, bibs = write_dummy_aux(meta.bibliography, meta.auxfile)
    os.remove('bibexport.bib')
    -- os.execute('bibexport -t ' .. auxfile_name)
    comm = 'bibtool -q -x ' .. auxfile_name .. ' ' .. table.concat(bibs, ' ') .. "> bibexport.bib"
    io.stderr:write("Execute: " .. comm)
    os.execute(comm)
    io.stderr:write('Output written to bibexport.bib\n')
    return nil
  end
end
