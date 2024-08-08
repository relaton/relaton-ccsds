# frozen_string_literal: true

require "mechanize"
require "relaton_bib"
require "relaton/index"
require "pubid-ccsds"
require_relative "relaton_ccsds/version"
require_relative "relaton_ccsds/bibliographic_item"
require_relative "relaton_ccsds/util"
require_relative "relaton_ccsds/document_type"
require_relative "relaton_ccsds/bibliography"
require_relative "relaton_ccsds/hit"
require_relative "relaton_ccsds/hit_collection"
require_relative "relaton_ccsds/data_fetcher"
require_relative "relaton_ccsds/data_parser"
require_relative "relaton_ccsds/hash_converter"
require_relative "relaton_ccsds/xml_parser"

module RelatonCcsds
  class Error < StandardError; end
  # Your code goes here...

  def self.grammar_hash
    # gem_path = File.expand_path "..", __dir__
    # grammars_path = File.join gem_path, "grammars", "*"
    # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest RelatonCcsds::VERSION + RelatonBib::VERSION # grammars
  end
end
