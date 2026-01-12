#!/usr/bin/env ruby
#
# describe.rb: Generate episode descriptions for War in Pieces
# Uses config.yml for global settings and readers.csv for per-episode readers
#
# Directory layout:
#   audio/        -> episode audio files (e.g., 1.1.1.m4a)
#   descriptions/ -> generated episode descriptions (e.g., 1.1.1.txt)

require 'csv'
require 'yaml'
require 'fileutils'
require 'optparse'

# CLI options
force = false
target_episode = nil

OptionParser.new do |opts|
  opts.on('--force', 'Overwrite existing descriptions') { force = true }
end.parse!

if ARGV.size == 1
  target_episode = ARGV[0]
elsif ARGV.size > 1
  abort "Usage: describe.rb [--force] [part.chapter.sentence]"
end

# Load global config
CONFIG_FILE = 'config.yml'
abort "Missing config file: #{CONFIG_FILE}" unless File.exist?(CONFIG_FILE)
config = YAML.load_file(CONFIG_FILE)

DEFAULT_READER = config['default_reader'] || 'Tod Beardsley'
READER_FILE    = config['reader_file']    || 'readers.csv'
START_YEAR     = config['start_year']     || 2026
WEBSITE        = config['website']        || 'https://warinpiec.es'

# Parse per-episode readers
episode_reader_map = {}
if File.exist?(READER_FILE)
  CSV.foreach(READER_FILE, headers: true) do |row|
    episode_id = row['episode']&.strip
    reader     = row['reader']&.strip
    episode_reader_map[episode_id] = reader if episode_id && reader
  end
end

# Description template
TEMPLATE = <<~DESC
  Part %{part}, Chapter %{chapter}, Sentence %{sentence}. War and Peace by Leo Tolstoy (Russian: Война и мир, Лев Николаевич Толстой), translated by Constance Garnett in 1930, read usually by Tod Beardsley, who started in #{START_YEAR}.

  This is Episode %{episode_id} of War in Pieces, a daily podcast reading Leo Tolstoy’s War and Peace one sentence at a time, using the public-domain Constance Garnett translation. %{reader_credit}

  War and Peace was first published as a complete work in 1869, and is widely regarded as one of the greatest works of world literature. This recording is one small part of a grand audio project releasing one sentence per day.

  For more information, visit #{WEBSITE}
DESC

DESC_DIR = 'descriptions'
FileUtils.mkdir_p(DESC_DIR)

episode_files = Dir.glob('audio/*').select { |f| f =~ /\.(m4a|mp3)$/i }.sort

if target_episode
  part, chapter, sentence = target_episode.split('.')
  abort "Invalid episode format: #{target_episode}" unless part && chapter && sentence

  pattern = /^#{part}\.#{chapter}\.#{sentence}\.(m4a|mp3)$/i
  episode_files.select! { |f| File.basename(f) =~ pattern }
  abort "No audio file found for episode #{target_episode}" if episode_files.empty?
end

puts "[*] Processing #{episode_files.size} audio file(s)"

# Generate descriptions
episode_files.each do |path|
  filename = File.basename(path)
  match = filename.match(/^(\d+)\.(\d+)\.(\d+)\.(m4a|mp3)$/)
  next unless match

  part     = match[1].to_i
  chapter  = match[2].to_i
  sentence = match[3].to_i

  episode_id = "#{part}.#{chapter}.#{sentence}"
  txt_filename = File.join(DESC_DIR, "#{episode_id}.txt")

  reader = episode_reader_map.fetch(episode_id, DEFAULT_READER)

  reader_credit =
    if reader == DEFAULT_READER
      "This episode was read by #{reader}."
    else
      "This episode was read by #{reader}. Special thanks to #{reader} for contributing their voice to this project."
    end

  if File.exist?(txt_filename) && !force
    puts "Skipping #{filename}"
    next
  end

  puts "Describing #{filename} as read by #{reader}"

  description = TEMPLATE % {
    reader_credit: reader_credit,
    episode_id: episode_id,
    part: part,
    chapter: chapter,
    sentence: sentence
  }

  File.open(txt_filename, 'w') do |file|
    file.write(description)
  end
end
