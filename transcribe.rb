#!/usr/bin/env ruby
#
# transcribe.rb: Extract and transcribe pages from War and Peace DJVU text
# Usage: ruby transcribe.rb --page 7 --lines=446-484
#
# Handles:
#   - Extracting raw text from DJVU file using manual line ranges
#   - Cleaning OCR artifacts and headers
#   - Splitting text into sentences per the binding rules
#   - Numbering sentences correctly across pages
#   - Writing output to text/page-NNNN.txt

require 'optparse'

DJVU_FILE = 'warpeace01tols_0_djvu.txt'
TEXT_DIR = 'text'

# Reporting verbs used to detect reporting clauses ("she said", "he answered")
REPORTING_VERBS = %w[said asked replied answered continued went added remarked observed
                     exclaimed whispered murmured noted cried shouted laughed responded told
                     called warned concluded recommended explained expressed denied admitted
                     acknowledged suggested]
REPORTING_VERBS_PATTERN = REPORTING_VERBS.join('|')

# Chapter markers survive space normalization in clean_text by being wrapped
# in triple brackets, e.g. "[[[CHAPTER_III]]]"
CHAPTER_MARKER = /\[\[\[CHAPTER_([IVX]+)\]\]\]/

# Sentence splitting rules (as comments for reference), written to the top
# of every transcribed page file.
RULES = [
  "# Quoted utterances are sentences",
  "# Reporting clauses are sentences",
  "# Utterances that end with elipses (...) end the sentence",
  "# Otherwise, compound sentences are sentences (em-dashes, colons, semicolons, and the like)",
  "# Sentence boundaries follow terminal punctuation otherwise",
  "# Line-end hyphenated words (which might be broken with a ¬ or - character) must be rejoined when transcribing per page.",
  "# Numbering restarts at each chapter start",
  "# Pages start with the first full complete sentence",
  "# See README.md in the source repo for more.",
]

def find_last_sentence_number(filepath)
  # Sentences are formatted as: "123. sentence text"
  # Scanning from the end finds the last sentence number regardless of any
  # chapter-reset markers earlier in the file.
  lines = File.readlines(filepath)
  lines.reverse.each do |line|
    match = line.match(/^(\d+)\./)
    return match[1].to_i if match
  end
  nil
end

def extract_page_text(start_line, end_line)
  # Extract text between specified (1-indexed) line numbers, inclusive.
  lines = File.readlines(DJVU_FILE)
  lines[(start_line - 1)..(end_line - 1)].join
end

def clean_text(raw_text)
  text = raw_text.dup

  # Remove WAR AND PEACE headers (with optional page numbers)
  text.gsub!(/^WAR\s*AND\s*PEACE.*?$/i, '')

  # Remove standalone page numbers (just digits on a line)
  text.gsub!(/^\s*\d+\s*$/, '')

  # Preserve chapter markers with unique delimiters that survive space
  # normalization: convert standalone Roman numerals to bracket format.
  text.gsub!(/\n\s*([IVX]+)\s*\n/) { " [[[CHAPTER_#{$1}]]] " }

  # Skip leading sentence fragment: find first complete sentence
  # (i.e., skip everything up to and including the first period/!/?)
  text.sub!(/^[^.!?]*?[.!?]\s+/, '')

  # Normalize Unicode quotes to ASCII (curly single/double quotes -> ' and ")
  text.gsub!(/[\u{2018}\u{2019}\u{201A}\u{201B}]/, "'")
  text.gsub!(/[\u{201C}\u{201D}\u{201E}\u{201F}]/, '"')

  # Normalize multiple spaces to single space
  text.gsub!(/\s+/, ' ')

  # Rejoin hyphenated word breaks: "word¬" or "word-" at line breaks.
  # The ¬ character (logical not, U+00AC) is how the OCR renders hyphenation.
  text.gsub!(/(\w)¬\s*/, '\1')
  text.gsub!(/(\w)-\s+/, '\1')

  text.strip
end

def fix_quotes_and_reporting_clauses(sentences)
  # Second pass: split "'...,' said X" style sentences into a quote sentence
  # and a separate reporting-clause sentence.
  sentences.flat_map do |sentence|
    next [sentence] if sentence.match?(/^__CHAPTER_/)

    match = sentence.match(/^(['"])(.*?\1)([,;.]?\s*)(#{REPORTING_VERBS_PATTERN})(.*)$/i)
    next [sentence] unless match

    opening_quote, quoted_text, _quote_end, verb, rest = match.captures
    quote_sentence = opening_quote + quoted_text
    reporting_sentence = (verb + rest).strip

    [quote_sentence, reporting_sentence]
  end
end

def roman_to_arabic(roman)
  values = { 'I' => 1, 'V' => 5, 'X' => 10, 'L' => 50, 'C' => 100, 'D' => 500, 'M' => 1000 }
  result = 0
  prev_value = 0

  roman.upcase.each_char.reverse_each do |char|
    value = values[char]
    return nil unless value

    result += value < prev_value ? -value : value
    prev_value = value
  end

  result > 0 ? result : nil
end

def chapter_marker_at(text, pos)
  # Returns [chapter_number, marker_length] if a chapter marker starts at
  # pos, otherwise nil.
  match = text[pos..-1].match(/\A#{CHAPTER_MARKER}/)
  return nil unless match

  chapter_num = roman_to_arabic(match[1])
  return nil unless chapter_num

  [chapter_num, match[0].length]
end

def contraction_apostrophe?(text, pos)
  # True if the apostrophe/quote char at pos is inside a word (a contraction
  # like "it's" or "don't"), not a genuine opening/closing quote.
  return false unless pos > 0 && pos < text.length - 1

  text[pos - 1].match?(/\w/) && text[pos + 1].match?(/\w/)
end

def consume_chapter_marker(sentences, text, pos)
  # If a chapter marker starts at pos, append its sentinel to sentences and
  # return the new position (past the marker and any trailing space).
  # Returns nil if no marker is present.
  chapter_num, marker_length = chapter_marker_at(text, pos)
  return nil unless chapter_num

  sentences << "__CHAPTER_#{chapter_num}__"
  pos += marker_length
  pos += 1 while pos < text.length && text[pos] == ' '
  pos
end

def consume_quote(sentences, text, pos)
  # Handles a quoted utterance starting at pos, optionally followed by a
  # reporting clause ("she said", "he answered"). Returns the new position.
  quote_char = text[pos]
  quote_start = pos
  pos += 1

  while pos < text.length && text[pos] != quote_char
    pos += 1
    # A contraction apostrophe (e.g. "don't") inside the quoted text isn't
    # the closing quote - keep scanning past it.
    if quote_char == "'" && pos < text.length && text[pos] == quote_char && contraction_apostrophe?(text, pos)
      pos += 1
    end
  end
  pos += 1 if pos < text.length # include closing quote

  # Collect trailing punctuation on the quote
  pos += 1 while pos < text.length && text[pos].match?(/[.!?,;]/)

  quote_sentence = text[quote_start...pos].strip

  # Look ahead for a reporting clause
  temp_pos = pos
  temp_pos += 1 while temp_pos < text.length && text[temp_pos].match?(/\s/)

  if temp_pos < text.length && text[temp_pos..-1].match?(/^(#{REPORTING_VERBS_PATTERN})\b/i)
    sentences << quote_sentence
    pos = temp_pos

    clause_start = pos
    while pos < text.length
      if text[pos].match?(/[.!?]/)
        pos += 1
        break
      end
      pos += 1
    end

    clause_sentence = text[clause_start...pos].strip
    sentences << clause_sentence if clause_sentence.length > 0
    return pos
  end

  sentences << quote_sentence if quote_sentence.length > 0
  pos
end

def ellipsis_end?(text, pos)
  # Matches both "..." and the OCR's spaced ". . ." rendering, ending at pos.
  (pos >= 2 && text[pos - 2..pos] == '...') ||
    (pos >= 4 && text[pos - 4..pos].match?(/\. \. \.$/))
end

def consume_plain_sentence(sentences, text, pos)
  # Consumes a non-quoted sentence starting at pos, stopping at terminal
  # punctuation, an ellipsis, or an embedded chapter marker. Returns the new
  # position.
  sent_start = pos

  while pos < text.length
    chapter_num, marker_length = chapter_marker_at(text, pos)
    if chapter_num
      sentence = text[sent_start...pos].strip
      sentences << sentence if sentence.length > 0
      sentences << "__CHAPTER_#{chapter_num}__"

      pos += marker_length
      pos += 1 while pos < text.length && text[pos].match?(/\s/)
      return pos
    end

    if ellipsis_end?(text, pos)
      pos += 1
      break
    end

    # Terminal punctuation (not colons - they can be in compound sentences)
    if text[pos].match?(/[.!?]/)
      pos += 1
      break
    end

    pos += 1
  end

  sentence = text[sent_start...pos].strip
  sentences << sentence if sentence.length > 0
  pos
end

def split_into_sentences(text)
  sentences = []
  pos = 0

  while pos < text.length
    pos += 1 while pos < text.length && text[pos].match?(/\s/)
    break if pos >= text.length

    new_pos = consume_chapter_marker(sentences, text, pos)
    if new_pos
      pos = new_pos
      next
    end

    if text[pos] == "'" || text[pos] == '"'
      # Contractions ("it's", "don't") and stray apostrophes preceding a
      # chapter marker aren't real quotes - treat them as plain text.
      if text[pos] == "'" && contraction_apostrophe?(text, pos)
        pos += 1
        next
      end

      if text[pos] == "'"
        lookahead = pos + 1
        lookahead += 1 while lookahead < text.length && text[lookahead] == ' '
        if lookahead < text.length && text[lookahead..-1].start_with?('[[[CHAPTER')
          pos += 1
          next
        end
      end

      pos = consume_quote(sentences, text, pos)
      next
    end

    pos = consume_plain_sentence(sentences, text, pos)
  end

  sentences.reject(&:empty?)
end

def transcribe_page(page_num, start_line, end_line)
  puts "[*] PASS 1: Extracting and cleaning page #{page_num}"
  raw_text = extract_page_text(start_line, end_line)
  clean = clean_text(raw_text)
  sentences = split_into_sentences(clean)
  puts "[*] Split into #{sentences.count} sentences"

  puts "[*] PASS 2: Splitting quotes and reporting clauses"
  fixed_sentences = fix_quotes_and_reporting_clauses(sentences)
  if fixed_sentences.count != sentences.count
    puts "[*] Split #{fixed_sentences.count - sentences.count} additional sentences"
  end

  start_num = 1
  if page_num > 1
    prev_page_file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num - 1))
    if File.exist?(prev_page_file)
      prev_last_sentence = find_last_sentence_number(prev_page_file)
      if prev_last_sentence
        start_num = prev_last_sentence + 1
        puts "[*] Continuing from page #{page_num - 1} (last sentence: #{prev_last_sentence})"
      end
    end
  end

  output_file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num))
  chapter_num = nil

  puts "[*] Writing #{output_file}"
  File.open(output_file, 'w') do |f|
    RULES.each { |rule| f.puts rule }
    f.puts

    sentence_num = start_num
    fixed_sentences.each do |sentence|
      if sentence.match?(/^__CHAPTER_\d+__$/)
        chapter_num = sentence.match(/\d+/)[0].to_i
        f.puts "# Chapter #{chapter_num}"
        sentence_num = 1
      else
        f.puts "#{sentence_num}. #{sentence}"
        sentence_num += 1
      end
    end
  end

  actual_sentences = fixed_sentences.reject { |s| s.match?(/^__CHAPTER_/) }

  puts "[+] Done! Page #{page_num} transcribed, more or less. Eyeball it for errors!"
  if chapter_num
    puts "    Contains Chapter #{chapter_num} (restarted numbering)"
    puts "    Final chapter sentence count: #{actual_sentences.count}"
  else
    puts "    Final: Sentences #{start_num}-#{start_num + actual_sentences.count - 1}"
  end
end

if __FILE__ == $PROGRAM_NAME
  page_num = nil
  start_line = nil
  end_line = nil

  OptionParser.new do |opts|
    opts.on('--page NUM', Integer, 'Page number to transcribe') do |num|
      page_num = num
    end
    opts.on('--lines RANGE', 'Line range (e.g., 446-484)') do |range|
      start_str, end_str = range.split('-')
      abort "Invalid --lines range: #{range}" unless start_str && end_str
      start_line = start_str.to_i
      end_line = end_str.to_i
    end
  end.parse!

  if page_num.nil? || start_line.nil? || end_line.nil?
    abort "Usage: ruby transcribe.rb --page NUM --lines=START-END\n" \
          "       Example: ruby transcribe.rb --page 7 --lines=446-484"
  end

  transcribe_page(page_num, start_line, end_line)
end
