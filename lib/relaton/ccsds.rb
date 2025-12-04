# frozen_string_literal: true

# require "mechanize"
# require "relaton/core"
# require "relaton/bib"
require "relaton/index"
require "pubid/ccsds"
require_relative "ccsds/version"
# require_relative "ccsds/processor"
require_relative "ccsds/util"
require_relative "ccsds/model/item"
require_relative "ccsds/model/bibitem"
require_relative "ccsds/model/bibdata"
require_relative "ccsds/bibliography"

module Relaton
  module Ccsds
    INDEX_FILE = "index-v1.yaml".freeze

    class Error < StandardError; end
    # Your code goes here...

    def self.grammar_hash
      # gem_path = File.expand_path "..", __dir__
      # grammars_path = File.join gem_path, "grammars", "*"
      # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
      Digest::MD5.hexdigest Relaton::Ccsds::VERSION + Relaton::Bib::VERSION # grammars
    end
  end
end
