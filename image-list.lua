--
--------------------------------------------------------------------------------
--         File: image-list.lua
--
--        Usage: pandoc --lua-filter=image-list.lua
--
--  Description: 
--     convert SVG or PDF/EPS to EMF for inclusion into Word or RTF
--     convert PDF/EPS to SVG for inclusion into HTML and similar
--     needs: pdf2svg and inkscape for EMF export
--     prints: list of graphics,
--             e.g. for packing them separately for a publisher
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2019-03-17
-- Last Changed: 2019-03-17, 10:41:54 (CET)
--------------------------------------------------------------------------------
--
-- local inspect = require('inspect')
text = require 'text'
List = require 'pandoc.List'




-- http://lua-users.org/wiki/StringRecipes

--[[ -- as yet unused
function string.startswith(String, Start)
return string.sub(String, 1, string.len(Start)) == Start
end
--]]
function string.endswith(String, End)
return End=='' or string.sub(String, - string.len(End)) == End
end

-- end

-- https://stackoverflow.com/questions/4990990/lua-check-if-a-file-exists
function file_exists(name)
  -- file exists if it is readable
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end
--

-- convert SVG to PDF
function convert_to_svg(im)
  if string.endswith(text.lower(im.src), ".pdf")
      or string.endswith(text.lower(im.src), ".eps") then
    img_svg = string.gsub(im.src, "%.[^.]+$", ".svg")
    -- if not file_exists(img_svg) then
    pandoc.pipe("pdf2svg", {im.src, img_svg}, "")
    -- end
  end
  return im
end

-- convert SVG or PDF to EMF for inclusion into Word
function convert_to_emf(im)
  img_svg = im.src
  im = convert_to_svg(im)
  im.src = string.gsub(im.src, "%.[^.]+$", ".emf")
  if string.endswith(text.lower(im.src), ".pdf") then
    pandoc.pipe("inkscape", {img_svg, "--export-emf", im.src}, "")
  end
  return im
end

image_no = 0

return {
  {
    Image = function (im)
      --
      image_no = image_no + 1
      if FORMAT:find("html") or FORMAT:find("epub") then
        if string.endswith(text.lower(im.src), ".pdf") or
          string.endswith(text.lower(im.src), ".eps") then
            im = convert_to_svg(im)
          end
      elseif FORMAT == "docx" or FORMAT == "rtf" then
        image_orig = im.src
        if string.endswith(text.lower(im.src), ".pdf") or
          string.endswith(text.lower(im.src), ".eps") or
          string.endswith(text.lower(im.src), ".svg") then
          im = convert_to_emf(im)
        end
      end
      io.stderr:write(string.format("%-3d\t%s\t%s\n", image_no, im.src, image_orig))
      return im
    end
  }}
