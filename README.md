# Some Filters for Pandoc

- `abbrevs_ms.py` – abbreviation filtering for
  [MS](http://man7.org/linux/man-pages/man7/groff_ms.7.html) and
  [LaTeX](https://www.latex-project.org/) output
- `beamer-queries.lua` – a filter for presentations, not only with
  [Beamer](https://github.com/josephwright/beamer) for
  [LaTeX](https://www.latex-project.org/), which generates links for
  queries to corpus search engines like
  [ANNIS](https://corpus-tools.org/annis/) and
  [KorAP](http://korap.ids-mannheim.de), but also to
  [RegExr](http://www.regexr.com) and [Unicode](http://www.unicode.org)
  characters.
- `beamer-spans.lua` – a filter for
  [Beamer](https://github.com/josephwright/beamer) presentations with
  LaTeX which wraps certain `<spans>` (`:::`s) in some beamer
  environments I use.
- `bibexport.lua` – export citations to a list (adapted from
  [this](https://github.com/pandoc/lua-filters/blob/master/bibexport/bibexport.lua)
  to use [bibtool](http://www.gerd-neugebauer.de/software/TeX/BibTool/))
- `image-list.lua` – convert graphics (PDF/EPS to SVG for HTML/ePub,
  PDF/EPS/SVG as well as non-PNG/JPEG to EMF for Word/RTF) and print a list of images in order,
  e.g. for packaging
- `image-ms.lua` – prepare images for MS output; also handles some minor
  problems with Pandoc
- `protect_quote_ms.py` – protect
  [U+2019](http://unicode.org/cldr/utility/character.jsp?a=2019) from
  smartness (obsolete?)
- `reveal-lists.lua` – a filter that wraps all plain text bullet lists
  bullets in paragraphs, so that the IDS template for
  [Reveal.js](https://revealjs.com/) works.
- `scaps-simple.py` and `scaps.py` – for playing with smallcaps in MS
  output
- `un-smallcaps.lua` – make small caps all capitals
- `utils.lua` – contains local utility functions, mostly collected from
  the Web.

Feel free to use these as you see fit.
