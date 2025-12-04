require "relaton/core/processor"

module Relaton
  module Ccsds
    class Processor < Relaton::Core::Processor
      attr_reader :idtype

      def initialize # rubocop:disable Lint/MissingSuper
        @short = :relaton_ccsds
        @prefix = "CCSDS"
        @defaultprefix = %r{^CCSDS(?!\w)}
        @idtype = "CCSDS"
        @datasets = %w[ccsds]
      end

      # @param code [String]
      # @param date [String, NilClass] year
      # @param opts [Hash]
      # @return [Relaton::Ccsds::ItemData, nil]
      def get(code, date, opts)
        require_relative "bibliography"
        Bibliography.get(code, date, opts)
      end

      #
      # Fetch all the documents from a source
      #
      # @param [String] source source name
      # @param [Hash] opts
      # @option opts [String] :output directory to output documents
      # @option opts [String] :format
      #
      def fetch_data(source = "ccsds", **opts)
        require_relative "data/fetcher"
        DataFetcher.fetch(source, **opts)
      end

      # @param xml [String]
      # @return [Relaton::Ccsds::ItemData]
      def from_xml(xml)
        require_relative "model/item"
        Item.from_xml xml
      end

      # @param yaml [String]
      # @return [Relaton::Ccsds::ItemData]
      def from_yaml(yaml)
        require_relative "model/item"
        Item.from_yaml yaml
      end

      # Returns hash of XML grammar
      # @return [String]
      def grammar_hash
        require_relative "../ccsds"
        @grammar_hash ||= ::Relaton::Ccsds.grammar_hash
      end

      #
      # Remove index file
      #
      def remove_index_file
        Relaton::Index.find_or_create(:ccsds, url: true, file: INDEX_FILE).remove_file
      end
    end
  end
end
