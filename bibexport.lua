-- from https://github.com/pandoc/lua-filters
--
-- This filter produces two files:
-- - a YAML file `bibexport.yaml` with cite keys and bibliographies
--   used in the document
-- - a bib file containing the BibTeX entries
-- Presupposed is that the bibliographies are BibTeX files.
--
-- Since forking:
-- - use bibtool instead of bibexport
-- - added unlinking of `bibexport.bib` to prevent backups
-- - added YAML file
-- - used get_keys() to simplify code
-- - document a bit
--
-- Last Changed: 2021-07-19, 12:33:42 (CEST)
--
-- local inspect = require('inspect')

-- local utils = require 'pandoc.utils'
local List = require 'pandoc.List'
local utils = require "pandoc.utils"

local utilPath = string.match(PANDOC_SCRIPT_FILE, '.*[/\\]')
if PANDOC_VERSION >= {2,12} then
  local path = require 'pandoc.path'
  utilPath = path.directory(PANDOC_SCRIPT_FILE) .. path.separator
end
local loc_utils = dofile ((utilPath or '') .. 'utils.lua')

local citation_id_set = {}

local link_set = {}

function Link (link)
  if link.target ~= nil then
    link_set[link.target] = true
  end
end

--- Collect all citation IDs from one citation
function Cite (c)
  local cs = c.citations
  for i = 1, #cs do
    citation_id_set[cs[i].id or cs[i].citationId] = true
  end
end

--- adjust file names of bibliographies
-- @param bibliography meta data
function bibdata (bibliography)
  --- adjust the file name of one bibliography
  local function bibname (bibitem)
    if type(bibitem) == 'string' then
      return bibitem:gsub('%.bib$', '')
    else
      -- bibitem is assumed to be a list of inlines
      return utils.stringify(bibitem):gsub('%.bib$', '')
    end
  end
  local bibs = type(bibliography) == "table" -- bibliography.t == 'MetaList'
    and List.map(bibliography, bibname)
    or List:new({bibliography})
  return bibs
end

--- write YAML lists of bibliographies and citations
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
  biby:write("links:\n")
  for k, v in pairs(link_set) do
    biby:write(string.format("- %s\n", k))
  end
  biby:close()
end

-- aggregate aux content and bibliography
-- @return aux content, bibs
function aux_content(bibliography)
  local cites = loc_utils.get_keys(citation_id_set)
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

--- write am aux file for processing with bibtool
-- @return the aux file name, the name of the bibliography files
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

--- when processing the document, process citations and write lists of citations
function Pandoc (doc)
  local meta = doc.meta
  if not meta.bibliography then
    return nil
  else
    -- create a dummy .aux file
    local auxfile_name, bibs = write_dummy_aux(meta.bibliography, meta.auxfile)
    os.remove('bibexport.bib') -- clean up old files
    -- os.execute('bibexport -t ' .. auxfile_name)
    local comm = 'bibtool -q -x ' .. auxfile_name .. ' ' .. table.concat(bibs, ' ') .. "> bibexport.bib"
    io.stderr:write("Execute: " .. comm)
    os.execute(comm)
    io.stderr:write('Output written to bibexport.bib\n')
    return nil
  end
end
