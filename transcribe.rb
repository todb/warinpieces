#!/usr/bin/env ruby
#
# transcribe.rb: Extract and transcribe pages from War and Peace DJVU text
# Usage: ruby transcribe.rb --page 7
#
# Handles:
#   - Extracting raw text from DJVU file by page number
#   - Cleaning OCR artifacts (hyphenation, spacing)
#   - Splitting text into sentences per the binding rules
#   - Numbering sentences correctly across pages
#   - Writing output to text/page-NNNN.txt

require 'optparse'

DJVU_FILE = 'warpeace01tols_0_djvu.txt'
TEXT_DIR = 'text'

# Page boundaries: page_number => { start_line:, end_line:, start_sentence: }
# start_line is 1-indexed in the DJVU file
PAGE_BOUNDARIES = {
  1 => { start_line: 27, end_line: 52, start_sentence: 1 },
  2 => { start_line: 53, end_line: 114, start_sentence: 29 },
  3 => { start_line: 115, end_line: 178, start_sentence: 72 },
  4 => { start_line: 179, end_line: 240, start_sentence: 117 },
  5 => { start_line: 241, end_line: 332, start_sentence: 1 },
  6 => { start_line: 333, end_line: 453, start_sentence: 24 },
  7 => { start_line: 453, end_line: 507, start_sentence: 56 },
}

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

def extract_page_text(page_num)
  boundaries = PAGE_BOUNDARIES[page_num]
  abort "Page #{page_num} not yet configured" unless boundaries

  lines = File.readlines(DJVU_FILE)
  start_idx = boundaries[:start_line] - 1
  end_idx = boundaries[:end_line] - 1

  raw_text = lines[start_idx..end_idx].join
  raw_text
end

def clean_text(raw_text)
  # Remove page headers (WAR AND PEACE, page numbers, etc.)
  text = raw_text.sub(/^WAR\s+AND\s+PEACE.*?\n\n/m, '')

  # Remove section markers (Roman numerals on their own line)
  text.gsub!(/^\s*[IVX]+\s*$/, '')

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

def split_into_sentences(text)
  sentences = []
  pos = 0

  while pos < text.length
    # Skip whitespace
    pos += 1 while pos < text.length && text[pos].match?(/\s/)
    break if pos >= text.length

    # Detect quote start (all quotes normalized to ASCII in clean_text)
    if text[pos] == "'" || text[pos] == '"'
      quote_char = text[pos]
      quote_start = pos
      pos += 1

      # Find closing quote
      while pos < text.length && text[pos] != quote_char
        pos += 1
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
      # Check for ellipsis
      if pos >= 2 && text[pos-2..pos] == '...'
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

def transcribe_page(page_num)
  boundaries = PAGE_BOUNDARIES[page_num]
  abort "Page #{page_num} not yet configured" unless boundaries

  puts "[*] PASS 1: Extracting and cleaning page #{page_num}"
  raw_text = extract_page_text(page_num)
  clean = clean_text(raw_text)
  sentences = split_into_sentences(clean)

  output_file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num))

  # Determine starting sentence number
  start_num = boundaries[:start_sentence]
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

  # Write final version with renumbered sentences
  final_start = boundaries[:start_sentence]
  final_end = final_start + fixed_sentences.count - 1

  puts "[*] Writing final version (#{fixed_sentences.count} sentences)"
  File.open(output_file, 'w') do |f|
    RULES.each { |rule| f.puts rule }
    f.puts

    fixed_sentences.each_with_index do |sentence, idx|
      num = final_start + idx
      f.puts "#{num}. #{sentence}"
    end
  end

  puts "[+] Done! Page #{page_num} transcribed successfully."
  puts "    Final: Sentences #{final_start}-#{final_end}"
end

# Parse command line
page_num = nil
OptionParser.new do |opts|
  opts.on('--page NUM', Integer, 'Page number to transcribe') do |num|
    page_num = num
  end
end.parse!

if page_num.nil?
  abort "Usage: ruby transcribe.rb --page NUM"
end

transcribe_page(page_num)
