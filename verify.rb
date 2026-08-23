#!/usr/bin/env ruby
#
# verify.rb: Sanity-check an already-written text/page-NNNN.txt
# Usage: ruby verify.rb --page 8
#        ruby verify.rb --page 8 --lines=509-565
#
# This encapsulates the manual "diff source vs. transcription, check for
# rule violations" pass that otherwise gets redone by hand every time -
# useful after a hand edit (like patching a script's raw output) or when
# double-checking an older page. Everything here is advisory: it flags
# things for a human to look at, it never rewrites the page itself.
#
# Two independent checks:
#   - Structural: does any sentence look like a quote got fused with a
#     reporting clause, or two sentences got merged? (--page alone)
#   - Source diff: does the transcribed wording match the DJVU source,
#     word for word, ignoring quote-style/hyphenation normalization?
#     (--page plus --lines)

require 'optparse'
require_relative 'transcribe'

def read_page_sentences(page_num)
  file = File.join(TEXT_DIR, sprintf("page-%04d.txt", page_num))
  abort "No such file: #{file}" unless File.exist?(file)
  lines = File.readlines(file)
  lines.each_with_object([]) do |line, sentences|
    match = line.match(/^(\d+)\.\s*(.*)$/)
    sentences << [match[1].to_i, match[2].strip] if match
  end
end

def normalize_for_diff(text)
  text = text.dup
  text.gsub!(/(\w)¬\s*/, '\1')      # rejoin OCR hyphenation
  text.gsub!(/(\w)-\s+/, '\1')
  text.gsub!(/[\u{2018}\u{2019}\u{201A}\u{201B}]/, "'")
  text.gsub!(/[\u{201C}\u{201D}\u{201E}\u{201F}]/, '"')
  text.gsub!(/[—–]/, '--')
  text.gsub!(/\s+/, ' ')
  text.strip
end

def source_word_diff(page_num, start_line, end_line, transcribed_sentences)
  source = normalize_for_diff(extract_page_text(start_line, end_line))
  transcribed = normalize_for_diff(transcribed_sentences.map { |_, s| s }.join(' '))

  # Line up on the transcription's first few words, since --lines usually
  # spans a bit more context (a trailing sentence fragment, a preceding
  # page header) than the page actually starts/ends on.
  first_words = transcribed.split(' ').first(4).join(' ')
  start_idx = source.index(first_words)
  source = source[start_idx..-1] if start_idx

  require 'set'
  sm_diff(source.split(' '), transcribed.split(' '))
end

# Minimal LCS-based diff (no external gems) - returns [:same/:src_only/:txt_only, word] pairs.
def sm_diff(a, b)
  m, n = a.length, b.length
  dp = Array.new(m + 1) { Array.new(n + 1, 0) }
  (m - 1).downto(0) do |i|
    (n - 1).downto(0) do |j|
      dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : [dp[i + 1][j], dp[i][j + 1]].max
    end
  end

  ops = []
  i = j = 0
  while i < m && j < n
    if a[i] == b[j]
      ops << [:same, a[i]]
      i += 1
      j += 1
    elsif dp[i + 1][j] >= dp[i][j + 1]
      ops << [:src_only, a[i]]
      i += 1
    else
      ops << [:txt_only, b[j]]
      j += 1
    end
  end
  while i < m
    ops << [:src_only, a[i]]
    i += 1
  end
  while j < n
    ops << [:txt_only, b[j]]
    j += 1
  end
  ops
end

def report_word_diff(ops)
  mismatches = ops.reject { |tag, _| tag == :same }
  return puts "[*] Wording matches source exactly" if mismatches.empty?

  puts "[!] Wording differs from source:"
  ops.each_cons(1) # no-op, keeps structure simple
  i = 0
  while i < ops.length
    tag, word = ops[i]
    if tag == :same
      i += 1
      next
    end
    src_words = []
    txt_words = []
    while i < ops.length && ops[i][0] != :same
      src_words << ops[i][1] if ops[i][0] == :src_only
      txt_words << ops[i][1] if ops[i][0] == :txt_only
      i += 1
    end
    puts "    source: #{src_words.join(' ').inspect}"
    puts "    page:   #{txt_words.join(' ').inspect}"
  end
end

if __FILE__ == $PROGRAM_NAME
  page_num = nil
  start_line = nil
  end_line = nil

  OptionParser.new do |opts|
    opts.on('--page NUM', Integer, 'Page number to verify') { |n| page_num = n }
    opts.on('--lines RANGE', 'Source DJVU line range (e.g., 509-565), to diff wording against source') do |range|
      start_str, end_str = range.split('-')
      abort "Invalid --lines range: #{range}" unless start_str && end_str
      start_line = start_str.to_i
      end_line = end_str.to_i
    end
  end.parse!

  abort "Usage: ruby verify.rb --page NUM [--lines=START-END]" unless page_num

  sentences = read_page_sentences(page_num)
  puts "[*] Checking #{sentences.count} sentences on page #{page_num}"

  puts "[*] Structural check (idempotent re-split, curly quotes)"
  puts "    Note: pages transcribed before transcribe.rb existed (or under older" \
       " rules) may show an expected re-split mismatch here - that's not" \
       " necessarily a bug, just a page the rules have since moved past."
  # A page's numbering can reset at a chapter start; group runs on that,
  # same as transcribe.rb's own numbering does, so a chapter boundary
  # doesn't get treated as a merged sentence.
  runs = sentences.slice_when { |(a, _), (b, _)| b < a }.to_a
  any_problems = false
  runs.each do |run|
    start_num = run.first[0]
    problems = check_sentence_run(run.map { |_, text| text })
    any_problems ||= !problems.empty?
    print_check_problems(problems, start_num)
  end
  puts "[*] No issues found" unless any_problems

  if start_line && end_line
    puts "[*] Source diff (text/page-#{format('%04d', page_num)}.txt vs. DJVU lines #{start_line}-#{end_line})"
    ops = source_word_diff(page_num, start_line, end_line, sentences)
    report_word_diff(ops)
  else
    puts "[*] Skipping source diff (pass --lines=START-END to compare wording against the DJVU source)"
  end
end
