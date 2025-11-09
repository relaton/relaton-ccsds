require "relaton/processor"

module RelatonCcsds
  class Processor < Relaton::Processor
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
    # @return [RelatonCcsds::BibliographicItem]
    def get(code, date, opts)
      ::RelatonCcsds::Bibliography.get(code, date, opts)
    end

    #
    # Fetch all the documents from a source
    #
    # @param [String] _source source name
    # @param [Hash] opts
    # @option opts [String] :output directory to output documents
    # @option opts [String] :format
    #
    def fetch_data(_source, opts)
      DataFetcher.fetch(**opts)
    end

    # @param xml [String]
    # @return [RelatonCcsds::CcBibliographicItem]
    def from_xml(xml)
      ::RelatonCcsds::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::CcBibliographicItem]
    def hash_to_bib(hash)
      ::RelatonCcsds::BibliographicItem.from_hash hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonCcsds.grammar_hash
    end

    #
    # Remove index file
    #
    def remove_index_file
      Relaton::Index.find_or_create(:ccsds, url: true, file: HitCollection::INDEX_FILE).remove_file
    end
  end
end
