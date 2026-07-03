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

# Sentence splitting rules (as comments for reference)
RULES = [
  "# Quoted utterances are sentences",
  "# Reporting clauses are sentences",
  "# Utterances that end with elipses (...) end the sentence",
  "# Otherwise, compound sentences are sentences (em-dashes, colons, semicolons, and the like)",
  "# Sentence boundaries follow terminal punctuation otherwise",
]

def find_last_sentence_number(filepath)
  # Read file and find the last sentence number
  # Sentences are formatted as: "123. sentence text"
  lines = File.readlines(filepath)
  lines.reverse.each do |line|
    match = line.match(/^(\d+)\./)
    return match[1].to_i if match
  end
  nil
end

def extract_page_text(start_line, end_line)
  # Extract text between specified line numbers
  # Lines are 1-indexed in the file
  lines = File.readlines(DJVU_FILE)

  start_idx = start_line - 1
  end_idx = end_line - 1

  raw_text = lines[start_idx..end_idx].join
  raw_text
end

def clean_text(raw_text)
  text = raw_text

  # Remove WAR AND PEACE headers (with optional page numbers)
  text.gsub!(/^WAR\s*AND\s*PEACE.*?$/i, '')

  # Remove standalone page numbers (just digits on a line)
  text.gsub!(/^\s*\d+\s*$/, '')

  # Preserve chapter markers with unique delimiters that survive space normalization
  # Convert standalone Roman numerals to marker format using brackets
  text.gsub!(/\n\s*([IVX]+)\s*\n/) { |match| " [[[CHAPTER_#{$1}]]] " }

  # Skip leading sentence fragment: find first complete sentence
  # (i.e., skip everything up to and including the first period/! /?)
  text.sub!(/^[^.!?]*?[.!?]\s+/, '')

  # Normalize Unicode quotes to ASCII
  # U+2018 (LEFT SINGLE QUOTATION MARK) -> '
  # U+2019 (RIGHT SINGLE QUOTATION MARK) -> '
  # U+201A (SINGLE LOW-9 QUOTATION MARK) -> '
  # U+201B (SINGLE HIGH-REVERSED-9 QUOTATION MARK) -> '
  # U+201C (LEFT DOUBLE QUOTATION MARK) -> "
  # U+201D (RIGHT DOUBLE QUOTATION MARK) -> "
  # U+201E (DOUBLE LOW-9 QUOTATION MARK) -> "
  # U+201F (DOUBLE HIGH-REVERSED-9 QUOTATION MARK) -> "
  text.gsub!(/[\u{2018}\u{2019}\u{201A}\u{201B}]/, "'")
  text.gsub!(/[\u{201C}\u{201D}\u{201E}\u{201F}]/, '"')

  # Normalize multiple spaces to single space
  text.gsub!(/\s+/, ' ')

  # Handle hyphenated word breaks: "word¬" or "word-" at line breaks
  # The ¬ character (logical not, U+00AC) is OCR'd hyphenation
  text.gsub!(/(\w)¬\s*/, '\1')
  text.gsub!(/(\w)-\s+/, '\1')

  # Clean up leading/trailing whitespace
  text.strip
end

def fix_quotes_and_reporting_clauses(sentences)
  # Second pass: look for patterns like "'...,' said X" and split them
  # Returns a new array with quotes and reporting clauses separated

  result = []
  reporting_verbs = %w[said asked replied answered continued went on added remarked observed
                       exclaimed whispered murmured noted cried shouted laughed responded told
                       called warned concluded recommended explained expressed denied admitted
                       acknowledged suggested]

  sentences.each do |sentence|
    # Skip chapter markers - pass through as-is
    if sentence.match?(/^__CHAPTER_/)
      result << sentence
      next
    end

    # Pattern: 'text,' said ... or "text," said ...
    # Match: opening_quote, quoted_text, closing_quote+punctuation, verb, rest_of_clause

    match = sentence.match(/^(['"])(.*?\1)([,;.]?\s*)(#{reporting_verbs.join('|')})(.*)$/i)

    if match
      # Extract parts
      opening_quote = match[1]
      quoted_text = match[2]  # This already includes the closing quote!
      quote_end = match[3]
      verb = match[4]
      rest = match[5]

      # Build the quote - quoted_text already has opening quote attached and closing quote
      # We just need to prepend the opening quote
      quote_sentence = opening_quote + quoted_text

      # Build the reporting clause (verb + rest of sentence)
      reporting_sentence = (verb + rest).strip

      # Add both as separate sentences
      result << quote_sentence
      result << reporting_sentence
    else
      # Keep as-is if no quote/reporting clause pattern found
      result << sentence
    end
  end

  result
end

def roman_to_arabic(roman)
  # Convert Roman numerals to Arabic numbers
  values = { 'I' => 1, 'V' => 5, 'X' => 10, 'L' => 50, 'C' => 100, 'D' => 500, 'M' => 1000 }
  roman = roman.upcase
  result = 0
  prev_value = 0

  roman.each_char.reverse_each do |char|
    value = values[char]
    return nil unless value
    if value < prev_value
      result -= value
    else
      result += value
    end
    prev_value = value
  end

  result > 0 ? result : nil
end

def split_into_sentences(text)
  sentences = []
  pos = 0
  current_chapter = nil

  while pos < text.length
    # Skip whitespace
    pos += 1 while pos < text.length && text[pos].match?(/\s/)
    break if pos >= text.length

    # Check for chapter marker (preserved from clean_text)
    # Format: [[[CHAPTER_III]]] (bracket-delimited to survive space normalization)
    remaining = text[pos..-1]
    marker_match = remaining.match(/^\[\[\[CHAPTER_([IVX]+)\]\]\]/)
    if marker_match
      roman_numeral = marker_match[1]
      chapter_num = roman_to_arabic(roman_numeral)
      if chapter_num
        current_chapter = chapter_num
        sentences << "__CHAPTER_#{chapter_num}__"
        pos += marker_match[0].length
        # Skip trailing space after marker
        pos += 1 while pos < text.length && text[pos] == ' '
        next
      end
    end

    # Detect quote start (all quotes normalized to ASCII in clean_text)
    if text[pos] == "'" || text[pos] == '"'
      quote_char = text[pos]

      # Check if this is a contraction (apostrophe surrounded by word chars)
      # If so, treat as part of regular text, not a quote
      if quote_char == "'" && pos > 0 && pos < text.length - 1
        prev_char = text[pos - 1]
        next_char = text[pos + 1]
        if prev_char.match?(/\w/) && next_char.match?(/\w/)
          # This is a contraction like "it's" or "don't", skip it
          pos += 1
          next
        end
      end

      # Check if this is an orphaned quote (stray quote followed by chapter marker)
      # Skip it if found, but be careful not to skip legitimate opening quotes of dialogue
      if quote_char == "'"
        # Look ahead to see what follows
        temp_pos = pos + 1
        temp_pos += 1 while temp_pos < text.length && text[temp_pos] == ' '
        if temp_pos < text.length && text[temp_pos..-1].start_with?('[[[CHAPTER')
          # Only skip if followed by chapter marker
          pos += 1
          next
        end
      end

      quote_start = pos
      pos += 1

      # Find closing quote (skipping contractions)
      while pos < text.length && text[pos] != quote_char
        pos += 1
        # Handle potential contractions in quoted text
        if pos < text.length && text[pos] == quote_char && quote_char == "'"
          if pos > 0 && pos < text.length - 1
            prev = text[pos - 1]
            next_ch = text[pos + 1]
            if prev.match?(/\w/) && next_ch.match?(/\w/)
              pos += 1
              next
            end
          end
        end
      end
      pos += 1 if pos < text.length # Include closing quote

      # Collect trailing punctuation on the quote
      quote_end = pos
      while pos < text.length && text[pos].match?(/[.!?,;]/)
        pos += 1
      end

      quote_sentence = text[quote_start...pos].strip

      # Check for reporting clause
      temp_pos = pos
      temp_pos += 1 while temp_pos < text.length && text[temp_pos].match?(/\s/)

      if temp_pos < text.length
        # Look for reporting verb
        rest = text[temp_pos..-1]
        if rest.match?(/^(said|asked|replied|answered|continued|went on|added|remarked|observed|exclaimed|whispered|murmured|noted|cried|shouted|laughed|responded|told|called|warned|concluded|recommended|explained|expressed|denied|admitted|acknowledged|suggested)\b/i)
          # There's a reporting clause following the quote
          sentences << quote_sentence
          pos = temp_pos

          # Collect the reporting clause until terminal punctuation
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
          next
        end
      end

      # No reporting clause, just the quote
      sentences << quote_sentence if quote_sentence.length > 0
      next
    end

    # Regular sentence (not starting with quote)
    sent_start = pos

    while pos < text.length
      # Check for chapter marker in the middle of text
      if text[pos..-1].start_with?('[[[CHAPTER_')
        marker_match = text[pos..-1].match(/^\[\[\[CHAPTER_([IVX]+)\]\]\]/)
        if marker_match
          # Emit current sentence if we have one
          sentence = text[sent_start...pos].strip
          sentences << sentence if sentence.length > 0

          # Emit chapter marker
          roman_numeral = marker_match[1]
          chapter_num = roman_to_arabic(roman_numeral)
          if chapter_num
            current_chapter = chapter_num
            sentences << "__CHAPTER_#{chapter_num}__"
          end

          pos += marker_match[0].length
          # Skip whitespace after marker
          pos += 1 while pos < text.length && text[pos].match?(/\s/)
          sent_start = pos
          break
        end
      end

      # Check for ellipsis (both "..." and ". . ." patterns)
      if pos >= 2 && text[pos-2..pos] == '...'
        pos += 1
        break
      end
      # Also check for spaced ellipsis pattern: ". . ." (dots with spaces)
      if pos >= 4 && text[pos-4..pos].match?(/\. \. \.$/)
        pos += 1
        break
      end

      # Check for terminal punctuation (not colons - they can be in compound sentences)
      if text[pos].match?(/[.!?]/)
        pos += 1
        break
      end

      pos += 1
    end

    sentence = text[sent_start...pos].strip
    sentences << sentence if sentence.length > 0
  end

  sentences.reject { |s| s.empty? }
end

def transcribe_page(page_num, start_line, end_line)
  puts "[*] PASS 1: Extracting and cleaning page #{page_num}"
  raw_text = extract_page_text(start_line, end_line)
  clean = clean_text(raw_text)
  sentences = split_into_sentences(clean)

  output_file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num))

  # Determine starting sentence number
  start_num = 1  # Default; will be overridden by continuation logic
  if page_num > 1
    # Try to read the last sentence number from the previous page
    prev_page_file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num - 1))
    if File.exist?(prev_page_file)
      prev_last_sentence = find_last_sentence_number(prev_page_file)
      if prev_last_sentence
        start_num = prev_last_sentence + 1
        puts "[*] Continuing from page #{page_num - 1} (last sentence: #{prev_last_sentence})"
      end
    end
  end

  # Write first pass
  puts "[*] Writing first pass (#{sentences.count} sentences)"
  File.open(output_file, 'w') do |f|
    RULES.each { |rule| f.puts rule }
    f.puts
    sentences.each_with_index do |sentence, idx|
      num = start_num + idx
      f.puts "#{num}. #{sentence}"
    end
  end

  # Second pass: split quotes from reporting clauses
  puts "[*] PASS 2: Splitting quotes and reporting clauses"
  fixed_sentences = fix_quotes_and_reporting_clauses(sentences)

  if fixed_sentences.count != sentences.count
    puts "[*] Split #{fixed_sentences.count - sentences.count} additional sentences"
  end

  # Write final version with renumbered sentences and chapter markers
  puts "[*] Writing final version"
  chapter_num = nil

  File.open(output_file, 'w') do |f|
    RULES.each { |rule| f.puts rule }
    f.puts

    sentence_num = start_num

    fixed_sentences.each do |sentence|
      # Check for chapter marker
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

  # Calculate final range accounting for chapters
  actual_sentences = fixed_sentences.reject { |s| s.match?(/^__CHAPTER_/) }
  last_num = actual_sentences.count

  puts "[+] Done! Page #{page_num} transcribed successfully."
  if chapter_num
    puts "    Contains Chapter #{chapter_num} (restarted numbering)"
    puts "    Final chapter sentence count: #{last_num}"
  else
    puts "    Final: Sentences #{start_num}-#{start_num + actual_sentences.count - 1}"
  end
end

# Parse command line
page_num = nil
start_line = nil
end_line = nil

OptionParser.new do |opts|
  opts.on('--page NUM', Integer, 'Page number to transcribe') do |num|
    page_num = num
  end
  opts.on('--lines RANGE', 'Line range (e.g., 446-484)') do |range|
    parts = range.split('-')
    start_line = parts[0].to_i
    end_line = parts[1].to_i
  end
end.parse!

if page_num.nil? || start_line.nil? || end_line.nil?
  abort "Usage: ruby transcribe.rb --page NUM --lines=START-END\n" +
        "       Example: ruby transcribe.rb --page 7 --lines=446-484"
end

transcribe_page(page_num, start_line, end_line)
