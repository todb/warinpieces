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

def split_into_sentences(text)
  sentences = []
  pos = 0

  while pos < text.length
    # Skip whitespace
    pos += 1 while pos < text.length && text[pos].match?(/\s/)
    break if pos >= text.length

    # Detect quote start
    if text[pos] == '"' || text[pos] == "'"
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

  puts "[*] Extracting page #{page_num} (lines #{boundaries[:start_line]}-#{boundaries[:end_line]})"
  raw_text = extract_page_text(page_num)

  puts "[*] Cleaning text"
  clean = clean_text(raw_text)

  puts "[*] Splitting into sentences"
  sentences = split_into_sentences(clean)

  output_file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num))
  start_num = boundaries[:start_sentence]
  end_num = start_num + sentences.count - 1

  puts "[*] Writing #{sentences.count} sentences to #{output_file}"
  File.open(output_file, 'w') do |f|
    RULES.each { |rule| f.puts rule }
    f.puts

    sentences.each_with_index do |sentence, idx|
      num = start_num + idx
      f.puts "#{num}. #{sentence}"
    end
  end

  puts "[+] Done! Page #{page_num} transcribed successfully."
  puts "    Sentences #{start_num}-#{end_num}"
  puts "[*] Open #{output_file} to fix quote/reporting clause splits on second pass."
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
