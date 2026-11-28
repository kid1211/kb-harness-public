## R8. Any table-like data

**Requirement:** the check of R5 reads table-like data in other shapes too, with the same signals of R7. That covers a `csv` or `tsv` code block in the doc, and a link from the doc to a `.csv`, `.tsv` or `.xlsx` file. If a linked file is missing, too large, or in iCloud only, the check skips it and does not download it.

**Why it is not chosen:** the user also wants a note when a doc only names a CSV or a sheet. R9 adds that. Dropped 2026-10-25.
