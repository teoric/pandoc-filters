# Some Filters for Pandoc

- `abbrevs_ms.py` – abbreviation filtering for
  [MS](http://man7.org/linux/man-pages/man7/groff_ms.7.html) and
  [LaTeX](https://www.latex-project.org/) output
- `bibexport.lua` – export citations to a list (adapted from
  [this](https://github.com/pandoc/lua-filters/blob/master/bibexport/bibexport.lua)
  to use [bibtool](http://www.gerd-neugebauer.de/software/TeX/BibTool/))
- `image-list.lua` – convert graphics (PDF/EPS to SVG for HTML/ePub,
  PDF/EPS/SVG as well as non-PNG/JPEG to EMF for Word/RTF) and print a list of images in order,
  e.g. for packaging
- `image-ms.lua` – prepare images for MS output; also handles some minor
  problems with Pandoc
- `protect_quote_ms.py` – protect U+2019 from smartness (obsolete?)
- `scaps-simple.py` and `scaps.py` – for playing with smallcaps in MS
  output
- `un-smallcaps.lua` – make small caps all capitals


Feel free to use these as you see fit.
