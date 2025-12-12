# Outline (I think we have 25 minutes - 20 minutes to present and 5 Q/A)

## Intro (3 minutes)

* Summary of what we are going to talk about
* High-level overview
* Present xpts as a villian holding industry back with outdated software

## datasetjson (4 minutes)
* History lesson on where it came from
* Dive into specifics of datasetjson
* CDISC/Phuse/FDA collaboration

## R Consortium Working Group (4 minutes)
* Focus of this group
* Successes
* Problems identified / Blogs / updated file specs
  
## Pilot 5 (9 minutes)
* Focus of this Pilot
* Trials and Tribulations
* AI infrastructure
* Way of working
* Succes of the Pilot

---

## Spell Checker

This repository includes an automated spell checker for `.qmd` (Quarto Markdown) files via GitHub Actions.

### How it works

- The spell checker runs automatically on:
  - Pull requests to `main` or `devel` branches
  - Pushes to `main` or `devel` branches
  - Manual workflow dispatch

- It uses the R `spelling` package to check all `.qmd` files in the repository
- Custom words can be added to `inst/WORDLIST` to avoid false positives

### Adding custom words

To add technical terms, acronyms, or proper nouns that should be ignored by the spell checker:

1. Edit `inst/WORDLIST`
2. Add one word per line
3. Commit and push the changes

### Skipping spell check

To skip spell checking on a specific commit, include `[skip spellcheck]` in your commit message.
