# Episode pipeline

This documents the entire process of making an episode of War in Pieces.

## Picking the next sentence

Sentence selection is strictly sequential: whatever the next sentence is in part/chapter/sentence order that's transcribed in `text/` but doesn't yet have a corresponding file in `audio/` is the one that gets recorded next. There's no calendar-driven picker yet (see "A Dream of Automation," below).

## Transcription

Before anything can be recorded, the sentence has to exist as transcribed text. Source pages are pulled from `warpeace01tols_0_djvu.txt` (OCR output of the source PDF) using `transcribe.rb --page N --lines=X-Y`, which cleans up OCR artifacts, splits the page into individually numbered sentences per the binding rules documented in `text/README.md`, and writes the result to `text/page-NNNN.txt`. Sentence numbering restarts at the beginning of each chapter and continues automatically from the previous page within a chapter.

If a sentence gets missed or a page needs renumbering after the fact, `number.sh` and `renumber.sh` handle shifting the numbers in a page without having to hand-edit every following line.

### Verification

After transcribing a page, `verify.rb --page N` (optionally with `--lines=X-Y` to also diff against the DJVU source) runs two advisory checks: a structural check for likely rule violations (a quote fused with its reporting clause, two sentences merged, etc.), and a word-for-word diff against the source text. It never rewrites the page itself — it just flags things for a human to look at before recording starts.

## Voices

Each episode is lovingly recorded, one sentence at a time, by 100% human voices. This element of the podcast will never be automated by synthetic voices, unless human culture predominately uses voice synthesizers in day-to-day life because it's all futuristic and shit.

## Recording

Recording usually happens on my iPhone, using Voice Memo. Voice Memo has a nice "studio voice" cleanup button, as well as fairly easy trim controls. It's not bad! Voice Memo saves recordings as `.m4a` files.

Sometimes, I record with my ROdecaster Pro. Most commonly, it's connected by USB-C cable to my Macbook, and I record using the client application Audacity. Rarely, I use the POdecaster Pro standalone, which means transferring to my MacBook and loading the multitrack WAVs in Audacity and converting to MP3.

Files are saved as `.mp3` files (44100 Hz Sample Rate, Stereo, Bit Rate Mode Constant, Quality 128kbps, I don't know what the details are on the Voice Memo m4a's).

### Editing

Oftentimes, recordings are minimally edited. As mentioned, episodes are often edited directly in Voice Memo; room noise killing with Studio Voice (apparently only selectable after recording, can't set as default), and trimming lead in or bad takes, both front and back. That is saved as the same recording. Sometimes, several sentences are banked ahead of time in one or more recordings. Those are often transferred to the Macbook for editing in Audacity for trimming and noise reduction, rather than fiddle with that on the phone for several sentences.

If the source recording is Voice Memo, the M4A file is loaded in Audacity, edited with the Audacity GUI with lots of clicking around for trimming, noise reduction, and loudness normalization. Clipping and fixing a given sentence takes about a minute or less. The results are exported as MP3. In the case of several sentences in one track, typically, each track is selected, copied, and pasted as a new track. Then that track is edited, and exported as MP3. Note, at no point are Audacity native project files (`.aup3`) saved.

If the source recording is from Audacity, then there's no import step.

If the source recording is from ROdecaster Pro, then the file has been exported as a multitrack WAV file. All but the first track are deleted (already processed and mixed by the ROdecaster Pro), edited normally (a little faster because no room noise is needed to delete, thanks to preprocessing), and exported as an MP3.

### Filenames and locations

Each sentence recording is named `$PART.$CHAPTER.$SENTENCE.mp3` (or `.m4a` when direct from Voice Memo). They're saved to `~/git/warinpieces/audio/` on the Macbook. Along with their matching files in `descriptions/` and any updated `text/page-NNNN.txt`, they're then git committed, and pushed to GitHub, at https://github.com/todb/warinpieces (note, I need to move this to `hugesuccessllc` as the GH organization) for mostly backup purposes, seeing as I'm quite likely to die before the project is complete.

## Metadata

Each episode must be titled and described, and these must be made available via RSS like a normal podcast.

### Titles

Each episode is titled `$PART.$CHAPTER.$SENTENCE`, such as "1.3.11", which is Part 1, Chapter 3, Sentence number 11, just like the filename style. Note, if I could automate this better, I'd start naming them a little more exicitingly.

### Description

Descriptions are written programmatically with a local ruby script, `credit.rb`, driven by two inputs: `config.yml` (default reader, start year, website URL) and `readers.csv` (a per-sentence map of `part.chapter.sentence` to guest reader name). Crediting a guest is a matter of adding a row to `readers.csv` before running `credit.rb` for that sentence; everything else is default. The description changes slightly if the sentence is read by a guest, crediting that guest, but otherwise, they're exactly the same from episode to episode, like the below:

#### Regular episode

Part 1, Chapter 3, Sentence 13. War and Peace by Leo Tolstoy (Russian: Война и мир, Лев Николаевич Толстой), translated by Constance Garnett in 1930, read usually by Tod Beardsley, who started in 2026.  
  
This is a daily podcast reading Leo Tolstoy’s War and Peace one sentence at a time, using the public-domain Constance Garnett translation. This episode was read by Tod Beardsley.  
  
War and Peace was first published as a complete work in 1869, and is widely regarded as one of the greatest works of world literature. This recording is one small part of a grand audio project releasing one sentence per day.  
  
For more information, visit https://warinpiec.es

#### Guest episode

Part 1, Chapter 1, Sentence 138. War and Peace by Leo Tolstoy (Russian: Война и мир, Лев Николаевич Толстой), translated by Constance Garnett in 1930, read usually by Tod Beardsley, who started in 2026.  
  
This is a daily podcast reading Leo Tolstoy’s War and Peace one sentence at a time, using the public-domain Constance Garnett translation. This episode was read by Claire Reynolds. Special thanks to Claire Reynolds for contributing their voice to this project.  
  
War and Peace was first published as a complete work in 1869, and is widely regarded as one of the greatest works of world literature. This recording is one small part of a grand audio project releasing one sentence per day.  
  
For more information, visit https://warinpiec.es

The titles are encoded as filename.txt in the `~/git/warinpieces/descriptions`, and the generated text is saved in those files. It's a little dumb to waste the space with several thousand nearly identical copies.

### Guest readers

Onboarding a guest reader is its own, separate, manual process: collect or create an avatar image for them in `avatars/`, add their name against the sentence(s) they read in `readers.csv`, and add them to wherever the running list of guests lives. This isn't part of the recording/upload loop above, and it's staying manual — it's not on the list to automate as part of "A Dream of Automation," below, at least not until that dream is otherwise realized.

## Hosting

Hosting is provided by Buzzsprout, with a paid account. They handle everything about file hosting, RSS, website, getting added to podcast directorioes, all that.

### Uploading

Uploading MP3s is done through the web UI, after login. It has always happened on a desktop browser. It's possible to upload through the Buzzsprout mobile app, but it's even clunkier.

Part of uploading is setting when the episode will publish, either immediately, or scheduled. Episodes are often batch uploaded and then scheduled daily from there. Occasionally I upload a single episode on the day it's supposed to publish.

The effort of copying and pasting descriptions into a web form, followed by choosing the scheduled publish dates through calendar widgets and time of day drop downs, are easily the most time-consuming portion of the process (outside of actually recording). Each episode takes something like 3 minutes to process, end to end (selecting upload file, uploading, type the title, paste the description that's already in the buffer from the terminal window `cat descriptions/1.3.2.txt | pbcopy`, select the day, select the time, and hit publish, I think are all the steps).

# A Dream of Automation

Ultimately, I want one app to:
* Present the sentence to be read, in large font, determined by what day it is today. Optionally, there is a selectable a few ahead and behind where we're at in the current sequence.
* Record a voiced sentence, and present and option to save and publish. Once OK'ed (allow for more than one take)
	* Automatically trim 
	* Automatically noise-remove
	* Automatically save
		* With the correct title
        * And the correct description
	* Automatically upload to Buzzsprout 
	* Automatically title and describe the episode
	* Automatically schedule the publish

That way, the only remaining human effort is the supervised automatic transcription of the pages, and the voice recordings themselves. Every other step is automated down to a text selection, a recording, and a final authorization.

# Future changes

Ideally, I'd get back to self-hosted, like Castopod, maybe they're good now. I had to drop them because the security and feature updates were nearly impossible to perform without serious Linux sysadmin effort. But, a cheap VPS would cost almost exactly the same as a Buzzsprout Pro account.

That said, it may well be possible to cobble together some basic RSS feed and website, very basic and barebones, possibly on an AWS free tier or somesuch. If so, it should be Fediverse-aware.