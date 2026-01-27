--
--------------------------------------------------------------------------------
--         File: image-list.lua
--
--        Usage: pandoc --lua-filter=image-list.lua
--
--  Description:
--     convert SVG or PDF/EPS to EMF for inclusion into Word or RTF
--     convert PDF/EPS to SVG for inclusion into HTML and similar
--     needs: pdf2svg, inkscape and ImageMagick convert for EMF export
--     prints: list of graphics,
--             e.g. for packing them separately for a publisher
--
--       Author: Bernhard Fisseni (teoric), <bernhard.fisseni@mail.de>
--      Version: 0.5
--      Created: 2019-03-17
-- Last Changed: 2026-01-22, 08:41:36 (CET)
--------------------------------------------------------------------------------
--
-- local inspect = require('inspect')
local text = require 'text'
local list = require 'pandoc.List'

local utilPath = string.match(PANDOC_SCRIPT_FILE, '.*[/\\]')
if PANDOC_VERSION >= {2,12} then
  local path = require 'pandoc.path'
  utilPath = path.directory(PANDOC_SCRIPT_FILE) .. path.separator
end
local Loc_utils = dofile ((utilPath or '') .. 'utils.lua')


-- convert SVG to PDF
local function convert_to_svg(im)
  local img_orig = im.src
  if Loc_utils.endswith(text.lower(im.src), ".pdf")
      or Loc_utils.endswith(text.lower(im.src), ".eps") then
    im.src = string.gsub(im.src, "%.[^.]+$", ".svg")
    -- if not loc_utils.file_exists(img_svg) then
    pandoc.pipe("pdf2svg", {img_orig, img.src}, "")
    -- end
  end
  return im
end

-- convert to EMF for inclusion into Word
local function convert_to_emf(im)
  local img_orig = im.src
  im = convert_to_svg(im)
  if Loc_utils.endswith(text.lower(im.src), ".svg") then
    im.src = string.gsub(im.src, "%.[^.]+$", ".emf")
    pandoc.pipe("inkscape", {img_orig, "--export-emf", im.src}, "")
  elseif (
    not Loc_utils.endswith(text.lower(im.src), ".emf") and
    not (
      Loc_utils.endswith(text.lower(im.src), ".png")
      or
      Loc_utils.endswith(text.lower(im.src), ".jpg")
      or
      Loc_utils.endswith(text.lower(im.src), ".jpeg")
    )) then
    -- let's try our best
    im.src = string.gsub(im.src, "%.[^.]+$", ".emf")
    pandoc.pipe("convert", {img_orig, im.src}, "")
  end
  return im
end

local image_no = 0

return {
  {
    Image = function (im)
      image_no = image_no + 1
      local image_orig = im.src
      if FORMAT:find("html") or FORMAT:find("epub") then
        if Loc_utils.endswith(text.lower(im.src), ".pdf") or
          Loc_utils.endswith(text.lower(im.src), ".eps") then
            im = convert_to_svg(im)
          end
      elseif FORMAT == "docx" or FORMAT == "rtf" then
        im = convert_to_emf(im)
      end
      if image_orig == im.src then
        io.stderr:write(string.format("%-3d\t%s\n", image_no, im.src))
      else
        io.stderr:write(string.format("%-3d\t%s\t%s\n", image_no, im.src, image_orig))
      end
      return im
    end
  }
}
