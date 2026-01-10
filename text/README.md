# What is this text directory all about?

This is a place to stash sentence-by-sentence text of War And Peace, for the hit podcast [War in Pieces](https://warinpeic.es). Having sentences planned out, per page, will make it much easiler to anticipate sentence counts, especially when guests record sentences out of order.

The source of the text is [archive.org](https://archive.org/details/warpeace01tols_0/page/n7/mode/2up) and is in the public domain. This particular translation and edition is the canonical source for War and Peace in English, as far as War in Pieces is concerned.

Of course, the transcription to a machine-readable, machine-writable sentence-by-sentence (annotated) version of this particular edition is an ongoing effort. Patches and suggestions accepted, but I'm not yet sure how I will verify new mechanisms for parsed text without a human verification step, so please do not attempt to PR the entire source text.

Notably, here in 2026, I know for a fact (through direct experimentation) that the current version OpenAI's ChatGPT implementation produces at least one error per page, due to fundamental LLM architecture reasons. Therefore, resolving this unacceptably error-prone machine transcription is unlikely to be trivial on a page by page basis.

We will probably need to combine OCR with some regexes or some similiar hack to get error-free text. Experiment next with [spaCy](https://en.wikipedia.org/wiki/SpaCy). In all cases, transcribed passages should be no more than one page per file.

Note that the the filenames are a lie; page 1 starts on page 13 of the original PDF from Duke University Library's scan output.

# What is a sentence?

We had to make some decisions early on on what constitutes a sentence for War in Pieces. The rules so far are:

- Quoted utterances are sentences
- Reporting clauses are sentences
- Colons terminate sentences
- Otherwise, sentence boundaries follow terminal punctuation
  - This means that compound sentences (those containing em-dashes, semicolons, and the like) are sentences. 

## Examples

### Parentheticals

Page 1 contains a good example of a sentence, interrupted by a parenthetical aside. This is a straightforward example of a single sentence.

> No, I warn you, that if you do not tell me we are at war, if you again allow yourself to palliate all the infamies and atrocities of this Antichrist (upon my word, I believe he is), I don’t know you in future, you are no longer my friend, no longer my faithful slave, as you say.

This is a single sentence.

### Colons as terminal punctuation.

Page 4 contains the following passage, which is illustrative of a sentence-ending colon.

> ‘I often think,‘ pursued Anna Pavlovna, moving up to the prince and smiling cordially to him, as though to mark that political and worldly conversation was over and now intimate talk was to begin: ‘I often think how unfairly the blessings of life are sometimes apportioned.

1. 'I often think,'
2. pursued Anna Pavlovna, moving up to the prince and smiling cordially to him, as though to mark that political and worldly conversation was over and now intimate talk was to begin:
3. ‘I often think how unfairly the blessings of life are sometimes apportioned.

The utterance is one sentence, followed by the reporting clause, and finally the next utterance. Together, these constitute three sentences. The fact that the colon is doing work as a period is enough to complete the sentence in this case. This appears to be consistent in the first 35 pages, so it's presumed it will be consistent forever.

### Interrupted utterances

From page 362: 

> ‘I don’t understand,' he said, ‘in what way human reason cannot attain that knowledge of which you speak.’

This sentence starts with an utterance, but is interrupted by the reporting clause. This should be interpreted as:

1. ‘I don’t understand,'
2. he said,
3. ‘in what way human reason cannot attain that knowledge of which you speak.’

If it were written with the reporting clause at the end of the utterance, it would be two sentences. As written, it is three sentences.

### Semicolons and dashes are not terminal

Semicolons create a compound sentence, as do em-dashes and en-dashes. For example, from page 1:

> Pavlovna had been coughing for the last few days; she had an
attack of la grippe, as she said—grippe was then a new word only used by
a few people.

This passage is, in fact, one sentence:

1. Pavlovna had been coughing for the last few days; she had an
attack of la grippe, as she said—grippe was then a new word only used by
a few people.

## Other corner cases

More corner cases will be documented here to bring some semblence of order and predictability of sentences. It's expected that the first time a corner case is encountered, a decision will be made that is binding for the remainder of the text. Hopefully, there will be a manageable number of these cases so these bit of rather arbitrary judgement calls can be easily remembered by future readers and easily encoded by machine transcribers.
