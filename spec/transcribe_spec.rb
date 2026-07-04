require 'tmpdir'
require 'stringio'

RSpec.describe 'transcribe.rb' do
  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
    $stdout = original_stdout
  end

  describe '#roman_to_arabic' do
    it 'converts simple numerals' do
      expect(roman_to_arabic('I')).to eq(1)
      expect(roman_to_arabic('V')).to eq(5)
      expect(roman_to_arabic('X')).to eq(10)
    end

    it 'converts additive numerals' do
      expect(roman_to_arabic('II')).to eq(2)
      expect(roman_to_arabic('III')).to eq(3)
      expect(roman_to_arabic('XV')).to eq(15)
    end

    it 'converts subtractive numerals' do
      expect(roman_to_arabic('IV')).to eq(4)
      expect(roman_to_arabic('IX')).to eq(9)
      expect(roman_to_arabic('XIV')).to eq(14)
      expect(roman_to_arabic('XL')).to eq(40)
    end

    it 'is case-insensitive' do
      expect(roman_to_arabic('xiv')).to eq(14)
    end

    it 'returns nil for non-numeral input' do
      expect(roman_to_arabic('ABC')).to be_nil
    end

    it 'returns nil for an empty string' do
      expect(roman_to_arabic('')).to be_nil
    end
  end

  describe '#clean_text' do
    it 'normalizes curly single and double quotes to ASCII' do
      raw = "start. ‘Hello,’ she said. “Hi,” he replied."
      expect(clean_text(raw)).to eq("'Hello,' she said. \"Hi,\" he replied.")
    end

    it 'strips WAR AND PEACE header lines, with or without a page number' do
      raw = "junk.\nWAR AND PEACE\nActual content follows."
      expect(clean_text(raw)).to eq('Actual content follows.')

      raw_numbered = "junk.\nWARANDPEACE  5\nActual content follows."
      expect(clean_text(raw_numbered)).to eq('Actual content follows.')
    end

    it 'strips standalone page-number lines' do
      raw = "junk. Some text here.\n42\nMore text."
      expect(clean_text(raw)).to eq('Some text here. More text.')
    end

    it 'converts a standalone Roman numeral line into a bracketed chapter marker' do
      raw = "junk. Before.\n\nIII\n\nAfter the marker."
      expect(clean_text(raw)).to eq('Before. [[[CHAPTER_III]]] After the marker.')
    end

    it 'drops the leading sentence fragment before the first terminal punctuation' do
      raw = 'a leftover fragment from the prior page. The real first sentence.'
      expect(clean_text(raw)).to eq('The real first sentence.')
    end

    it 'collapses runs of whitespace into single spaces' do
      raw = "junk. Word1   Word2\n\nWord3"
      expect(clean_text(raw)).to eq('Word1 Word2 Word3')
    end

    it 'rejoins words hyphenated across a line break with the OCR ¬ marker' do
      raw = "junk. under¬\nstand this."
      expect(clean_text(raw)).to eq('understand this.')
    end

    it 'rejoins words hyphenated across a line break with a plain dash' do
      raw = "junk. under-\nstand this."
      expect(clean_text(raw)).to eq('understand this.')
    end

    it 'does not mutate the string passed in' do
      raw = 'junk. Hello world.'
      frozen_copy = raw.dup
      clean_text(raw)
      expect(raw).to eq(frozen_copy)
    end
  end

  describe '#split_into_sentences' do
    it 'splits plain sentences on terminal punctuation' do
      text = 'He went home. She stayed behind! Did they notice?'
      expect(split_into_sentences(text)).to eq([
        'He went home.',
        'She stayed behind!',
        'Did they notice?'
      ])
    end

    it 'keeps compound sentences with semicolons and em-dashes intact' do
      text = 'He had not entered the service; he had only just returned, her defect — the shortness of the lip — seemed characteristic.'
      expect(split_into_sentences(text).length).to eq(1)
    end

    it 'does not treat a colon as a sentence boundary' do
      text = 'Anna Pavlovna stopped him in dismay with the words: she did not expect this outcome.'
      sentences = split_into_sentences(text)
      expect(sentences.length).to eq(1)
      expect(sentences.first).to include('words:')
    end

    it 'treats a contraction apostrophe as plain text, not a quote' do
      text = "It's a lovely day. Don't go."
      expect(split_into_sentences(text)).to eq(["It's a lovely day.", "Don't go."])
    end

    # A quote that opens mid-sentence (after a colon) isn't specially tracked:
    # the parser only recognizes a quote when it's the first character of a
    # new sentence. So terminal punctuation *inside* the quoted dialogue ends
    # the sentence early, and the closing quote mark attaches to whatever
    # sentence starts next. This matches real source text, e.g. "...with the
    # words: 'You don't know Abbe Morio?" / "He's a very interesting man,'
    # she said." (see text/page-0007.txt).
    it 'ends a sentence at terminal punctuation inside a quote opened mid-sentence' do
      text = "Anna Pavlovna stopped him with the words: 'You don't know Abbe Morio? " \
             "He's a very interesting man,' she said."
      sentences = split_into_sentences(text)
      expect(sentences).to eq([
        "Anna Pavlovna stopped him with the words: 'You don't know Abbe Morio?",
        "He's a very interesting man,' she said."
      ])
    end

    # Ellipsis detection only takes effect inside a quote's closing-quote
    # scan, which just runs to the matching quote character regardless of
    # internal periods (see "ends a sentence on the OCR-spaced ellipsis
    # inside a quote", below). Outside of a quote, a run of periods hits the
    # plain terminal-punctuation check on the very first dot, so it never
    # reaches the multi-dot lookback - a preexisting quirk, not something
    # this refactor changed. Locking in the current behavior here so a
    # future change to this logic is a deliberate, visible decision.
    it 'fragments a plain (non-quoted) ellipsis into single-dot sentences' do
      text = 'He paused... She waited.'
      expect(split_into_sentences(text)).to eq(['He paused.', '.', '.', 'She waited.'])
    end

    it 'keeps an OCR-spaced ellipsis together when it appears inside a quote' do
      text = "'Yes, I have heard of his scheme for perpetual peace, and it's very interesting, but hardly possible . . .'"
      sentences = split_into_sentences(text)
      expect(sentences).to eq([text])
    end

    it 'splits a quoted utterance out as its own sentence' do
      text = "'Mind, Annette, don't play me a nasty trick,' she turned to the lady."
      sentences = split_into_sentences(text)
      expect(sentences.first).to eq("'Mind, Annette, don't play me a nasty trick,'")
    end

    it 'splits a reporting clause that follows a quote into its own sentence' do
      text = "'I have brought my work,' she said, displaying her reticule."
      sentences = split_into_sentences(text)
      expect(sentences).to eq([
        "'I have brought my work,'",
        'she said, displaying her reticule.'
      ])
    end

    it 'emits a chapter sentinel for an embedded chapter marker and resumes splitting after it' do
      text = 'End of chapter one. [[[CHAPTER_II]]] Start of chapter two.'
      sentences = split_into_sentences(text)
      expect(sentences).to eq([
        'End of chapter one.',
        '__CHAPTER_2__',
        'Start of chapter two.'
      ])
    end

    it 'discards a stray OCR quote mark immediately preceding a chapter marker' do
      text = "family.' [[[CHAPTER_II]]] Anna Pavlovna's drawing-room began to fill."
      sentences = split_into_sentences(text)
      expect(sentences).to eq([
        'family.',
        '__CHAPTER_2__',
        "Anna Pavlovna's drawing-room began to fill."
      ])
    end

    it 'ignores empty input' do
      expect(split_into_sentences('')).to eq([])
      expect(split_into_sentences('   ')).to eq([])
    end
  end

  describe '#fix_quotes_and_reporting_clauses' do
    it 'splits a quote+reporting-clause sentence into two sentences' do
      input = ["'We will talk of it later,' said Anna Pavlovna, smiling."]
      expect(fix_quotes_and_reporting_clauses(input)).to eq([
        "'We will talk of it later,'",
        'said Anna Pavlovna, smiling.'
      ])
    end

    it 'leaves a sentence with no quote/reporting-clause pattern unchanged' do
      input = ['Anna Pavlovna crossed the room.']
      expect(fix_quotes_and_reporting_clauses(input)).to eq(input)
    end

    it 'passes chapter sentinels through untouched' do
      input = ['__CHAPTER_3__']
      expect(fix_quotes_and_reporting_clauses(input)).to eq(input)
    end

    it 'recognizes verbs other than "said"' do
      input = ["'He is going to get himself killed,' answered the general quietly."]
      expect(fix_quotes_and_reporting_clauses(input)).to eq([
        "'He is going to get himself killed,'",
        'answered the general quietly.'
      ])
    end
  end

  describe '#find_last_sentence_number' do
    it 'returns the number of the last numbered sentence line' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'page-0006.txt')
        File.write(path, "# some rule\n\n24. First.\n25. Second.\n")
        expect(find_last_sentence_number(path)).to eq(25)
      end
    end

    it 'returns the last local number after a chapter reset, not a cumulative count' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'page-0006.txt')
        File.write(path, "23. Before the break.\n# Chapter 2\n1. Reset.\n2. Continues.\n")
        expect(find_last_sentence_number(path)).to eq(2)
      end
    end

    it 'returns nil when no numbered sentence line is present' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'page-0006.txt')
        File.write(path, "# just a comment\n\n")
        expect(find_last_sentence_number(path)).to be_nil
      end
    end
  end

  describe '#extract_page_text' do
    it 'extracts the inclusive 1-indexed line range from the DJVU file' do
      Dir.mktmpdir do |dir|
        djvu_path = File.join(dir, 'fake_djvu.txt')
        File.write(djvu_path, "line1\nline2\nline3\nline4\nline5\n")
        stub_const('DJVU_FILE', djvu_path)

        expect(extract_page_text(2, 4)).to eq("line2\nline3\nline4\n")
      end
    end
  end

  describe '#transcribe_page (integration)' do
    it 'writes a numbered, cleaned transcription to text/page-NNNN.txt' do
      Dir.mktmpdir do |dir|
        djvu_path = File.join(dir, 'fake_djvu.txt')
        text_dir = File.join(dir, 'text')
        Dir.mkdir(text_dir)

        File.write(djvu_path, <<~DJVU)
          WAR AND PEACE 1

          junk fragment. He said hello. She smiled back.
        DJVU

        stub_const('DJVU_FILE', djvu_path)
        stub_const('TEXT_DIR', text_dir)

        transcribe_page(1, 1, 3)

        output = File.read(File.join(text_dir, 'page-0001.txt'))
        expect(output).to include('1. He said hello.')
        expect(output).to include('2. She smiled back.')
      end
    end

    it 'continues numbering from the previous page file' do
      Dir.mktmpdir do |dir|
        djvu_path = File.join(dir, 'fake_djvu.txt')
        text_dir = File.join(dir, 'text')
        Dir.mkdir(text_dir)

        File.write(File.join(text_dir, 'page-0001.txt'), "1. Prior sentence.\n2. Another one.\n")
        File.write(djvu_path, <<~DJVU)
          WAR AND PEACE 2

          junk fragment. Third sentence here.
        DJVU

        stub_const('DJVU_FILE', djvu_path)
        stub_const('TEXT_DIR', text_dir)

        transcribe_page(2, 1, 3)

        output = File.read(File.join(text_dir, 'page-0002.txt'))
        expect(output).to include('3. Third sentence here.')
      end
    end

    it 'resets numbering and writes a chapter comment at a chapter break' do
      Dir.mktmpdir do |dir|
        djvu_path = File.join(dir, 'fake_djvu.txt')
        text_dir = File.join(dir, 'text')
        Dir.mkdir(text_dir)

        File.write(djvu_path, <<~DJVU)
          WAR AND PEACE 1

          junk fragment. Last sentence of chapter one.

          II

          First sentence of chapter two.
        DJVU

        stub_const('DJVU_FILE', djvu_path)
        stub_const('TEXT_DIR', text_dir)

        transcribe_page(1, 1, 7)

        output = File.read(File.join(text_dir, 'page-0001.txt'))
        expect(output).to include('# Chapter 2')
        expect(output).to include('1. First sentence of chapter two.')
      end
    end
  end
end
