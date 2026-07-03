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
  6 => { start_line: 333, end_line: 388, start_sentence: 24 },
  7 => { start_line: 450, end_line: 506, start_sentence: 56 },
}

# Sentence splitting rules (as comments for reference)
RULES = [
  "# Quoted utterances are sentences",
  "# Reporting clauses are sentences",
  "# Utterances that end with elipses (...) end the sentence",
  "# Otherwise, compound sentences are sentences (em-dashes, colons, semicolons, and the like)",
  "# Sentence boundaries follow terminal punctuation otherwise",
]

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

  # Note: Quote normalization is complex due to OCR curly quotes.
  # Manual fixing of quote/reporting clause splits is done in second pass.

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

    # Detect quote start (ASCII or Unicode quotes)
    quote_char = nil
    if text[pos] == "'" || text[pos] == "\u{2018}" || text[pos] == "\u{2019}"
      quote_char = "'"  # Normalize to ASCII single quote for matching
    elsif text[pos] == '"' || text[pos] == "\u{201C}" || text[pos] == "\u{201D}"
      quote_char = '"'  # Normalize to ASCII double quote for matching
    end

    if quote_char
      quote_start = pos
      pos += 1

      # Find closing quote (match corresponding Unicode or ASCII quote)
      while pos < text.length
        c = text[pos]
        break if ((quote_char == "'" && (c == "'" || c == "\u{2019}")) ||
                  (quote_char == '"' && (c == '"' || c == "\u{201D}")))
        pos += 1
      end
      pos += 1 if pos < text.length # Include closing quote

      # Collect trailing punctuation on the quote
      quote_end = pos
      while pos < text.length && text[pos].match?(/[.!?,:;]/)
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
            if text[pos].match?(/[.!?:]/)
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

      # Check for terminal punctuation
      if text[pos].match?(/[.!?:]/)
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
  start_num = boundaries[:start_sentence]

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
