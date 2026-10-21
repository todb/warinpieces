# Post-recording fixes

A running log of corrections made to `text/` *after* sentences were already recorded and published, so that only the affected sentences need to be re-recorded and re-published later - not everything.

Sentence IDs are `PART.CHAPTER.SENTENCE`, same as the audio filenames (so `1.3.63` is Part 1, Chapter 3, Sentence 63).

## How to read this log

Every entry is one of these. Only the first two ever require anything of the audio.

| Status | Meaning | Audio action |
| --- | --- | --- |
| **SHIFTED** | The sentence has a new number. Its old audio is filed under the wrong ID. | Re-file/re-record under the new number |
| **MERGED** / **SPLIT** | Two sentences became one (or one became two). Everything after it shifts. | Re-record the merged/split sentences; re-file the shifted ones |
| **REWORDED** | Same number, different words. | Re-record only if the spoken words differ |
| **TEXT-ONLY** | Same number, same spoken words; only punctuation/quote marks fixed. | None |
| unchanged | Not listed. If a chapter has no SHIFTED/MERGED/SPLIT rows, its numbering is intact. | None |

Each chapter section starts with a one-line numbering verdict so it's obvious at a glance whether anything moved.

---

## Chapter 1 (`text/page-0001.txt` - `page-0004.txt`, sentences 1-161)

**Numbering verdict: NO SENTENCES SHIFTED.** 161 sentences before, 161 after. Every recorded `1.1.N` still points at the same sentence.

Audited 2026-10-21 against the DJVU source (word-for-word diff of the whole chapter, plus a boundary-by-boundary comparison of the page splits against the source). The only differences were punctuation and one dropped letter:

| ID | Status | Change | Audio action |
| --- | --- | --- | --- |
| 1.1.9 | TEXT-ONLY | Opening `'` added (the note Anna Pavlovna wrote is a quoted utterance in the source) | none |
| 1.1.10 | TEXT-ONLY | Closing `'` added: `Annette Scherer.'` | none |
| 1.1.18 | TEXT-ONLY | `anxiety.'` -> `anxiety,'` (source has a comma; the reporting clause "he said" follows) | none |
| 1.1.20 | TEXT-ONLY | Opening `'` added | none |
| 1.1.21 | TEXT-ONLY | Closing `'` added (quote ends before "said Anna Pavlovna") | none |
| 1.1.23 | TEXT-ONLY | Wrapped in `'...'` (open and close were both missing) | none |
| 1.1.24 | TEXT-ONLY | Opening `'` added | none |
| 1.1.26 | TEXT-ONLY | `there.` -> `there,'` (source comma + closing quote before "said the prince") | none |
| 1.1.28 | TEXT-ONLY | Wrapped in `'...'` | none |
| 1.1.155 | REWORDED | `he's of good family` -> `She's of good family` (dropped letter; the source reads "She's", and a sentence-initial capital) | Re-record **only if** the take said "he's"; a reader would naturally have said "She's" |
| 1.1.29-71 | TEXT-ONLY | Page 2 used `"..."` for quotes; the rest of the book (and the source) uses `'...'`. Straightened to `'` throughout | none |

Also in Chapter 1, pages 1-5 had curly quotes/apostrophes (`’ ‘ “ ”`), now straightened to `'` and `"` per the transcription rules. No wording changed.

### Audio observations (not text changes)

- **`1.1.64` has no audio file**; every other `1.1.1`-`1.1.161` exists (160 files for 161 sentences). Sentence 64 is *"That famous Prussian neutrality is a mere snare."*

---

## Chapter 2 (`text/page-0005.txt` - `page-0007.txt` up to the Chapter 3 marker, sentences 1-71)

**Numbering verdict: NO SENTENCES SHIFTED.** 71 sentences before, 71 after, and 71 audio files (`1.2.1`-`1.2.71`) with none missing.

Audited 2026-10-21 against the DJVU source the same way as Chapter 1. The text matches the source word for word (the only diffs were OCR noise in the *source*, e.g. "foom" for "room"), and the page splits agree with the source's sentence boundaries. **No changes made.**

---

## Chapter 3 (`text/page-0007.txt` onward) - IN PROGRESS

**Numbering verdict: SHIFTED from sentence 63 onward** (via two fixes below). Chapter 3 is still being recorded, so it has *not* been audited the way Chapters 1-2 were. Plan: when the chapter is finished, run the same source audit and add its results here.

### Done so far

| Old ID | New ID | Status | Change | Audio action |
| --- | --- | --- | --- | --- |
| 1.3.63 | 1.3.63 | **MERGED** | Old 63 ended at `...the actress, Mlle.` (misread as `Mile.`) and old 64 began `Georges, and that there he met...`. These were one sentence, split at the abbreviation's period. Now a single sentence 63 reading `...Mlle. Georges, and that there he met Bonaparte...` | **Re-record 1.3.63** with the full sentence |
| 1.3.64 | *(gone)* | **MERGED** into 63 | The `Georges, and that...` half no longer exists as its own sentence | Delete/retire any `1.3.64` audio of the `Georges, and that...` text |
| 1.3.65 | 1.3.64 | **SHIFTED** (-1) | `The story was very charming and interesting...` | Re-file as 1.3.64 |
| 1.3.66 | 1.3.65 | **SHIFTED** (-1) | `'Charmant!'` | Re-file as 1.3.65 |
| 1.3.67 | 1.3.66 | **SHIFTED** (-1) | `said Anna Pavlovna, looking inquiringly...` | Re-file as 1.3.66 |
| 1.3.68 | 1.3.67 | **SHIFTED** (-1) | `'Charming!'` | Re-file as 1.3.67 |
| 1.3.69 | 1.3.68 | **SHIFTED** (-1) | `whispered the little princess...` | Re-file as 1.3.68 |
| 1.3.70 | 1.3.69 | **SHIFTED** (-1) | `The vicomte appreciated this silent homage...` | Re-file as 1.3.69 |
| 1.3.71 | 1.3.70 | **SHIFTED** (-1) | `But meanwhile Anna Pavlovna, still keeping a watch...` | Re-file as 1.3.70 |
| 1.3.9 | 1.3.9 | **REWORDED** | `the due d'Enghien` -> `the duc d'Enghien` (OCR read "c" as "e") | Re-record if the take said "due" (pronounced "dew"); the correct reading is "dook" |
| 1.3.10 | 1.3.10 | **REWORDED** | same `due` -> `duc` correction | same |
| 1.3.63 | 1.3.63 | **REWORDED** | All five `due` -> `duc` (`the duc d'Enghien`, `meeting the duc`, `the duc's power`, `the duc had not`, `the duc's death`) | covered by the 1.3.63 re-record above |

### Open items for Chapter 3

- `1.3.64.m4a` already exists in `audio/`. Check which text it was recorded from: if it's the old "Georges, and that there he met..." half, it's now orphaned; if it's "The story was very charming...", it's already correct under the new numbering.
- The audio folder is missing `1.3.15`, `1.3.17`, `1.3.18` and `1.3.19`. (Not a text issue - just noting it while here.)

---

## Open items across chapters

- `1.1.64` has no audio file ("That famous Prussian neutrality is a mere snare.").
