#!/usr/bin/env ruby
#
# describe.rb: Generate (destructively!) episode descriptions for War in Pieces
# Uses config.yml for global settings and readers.csv for per-episode readers
# TODO: If the default reader changes, ALREADY described episodes will be overwritten!

require 'csv'
require 'yaml'
require 'fileutils'

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

TEMPLATE = <<~DESC
  War and Peace by Leo Tolstoy (Russian: Война и мир, Лев Николаевич Толстой),
  translated by Constance Garnett in 1930,
  read usually by Tod Beardsley, who started in #{START_YEAR}.

  Part %{part}, Chapter %{chapter}, Sentence %{sentence}.

  This is Episode %{episode_id} of War in Pieces, a daily podcast reading
  Leo Tolstoy’s War and Peace one sentence at a time, using the public-domain
  Constance Garnett translation. This episode was read by %{reader}.

  War and Peace is a novel by Leo Tolstoy, first published as a complete
  work in 1869, and widely regarded as one of the greatest works of world
  literature. This recording is read by %{reader} as part of a long-term
  audio project releasing one sentence per day.

  For more information, visit #{WEBSITE}
DESC

DESC_DIR = 'descriptions'
FileUtils.mkdir_p(DESC_DIR)

episode_files =  Dir.glob('audio/*').select { |f| f =~ /\.(m4a|mp3)$/i }.sort
puts "[*] Describing #{episode_files.size} files, writing to #{File.expand_path(DESC_DIR)}"

episode_files.each do |fname|
  filename = File.basename(fname)
  match = filename.match(/^(\d+)\.(\d+)\.(\d+)\.(m4a|mp3)$/)
  next unless match

  part     = match[1].to_i
  chapter  = match[2].to_i
  sentence = match[3].to_i

  episode_id = "#{part}.#{chapter}.#{sentence}"
  reader     = episode_reader_map.fetch(episode_id, DEFAULT_READER)

  description = TEMPLATE % {
    reader: reader,
    episode_id: episode_id,
    part: part,
    chapter: chapter,
    sentence: sentence
  }

  txt_filename = File.join(DESC_DIR, "#{episode_id}.txt")

  File.open(txt_filename, 'w') do |file|
    # puts "[*] Described #{reader}'s reading in #{txt_filename}"
    file.write(description)
  end
end
