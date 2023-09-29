module RelatonCcsds
  module Bibliography
    extend self

    #
    # Search for CCSDS standards by document reference.
    #
    # @param [String] ref document reference
    #
    # @return [RelatonCcsds::HitCollection] collection of hits
    #
    def search(ref)
      RelatonCcsds::HitCollection.new(ref).fetch
    end

    #
    # Get CCSDS standard by document reference.
    # If format is not specified, then all format will be returned.
    #
    # @param reference [String]
    # @param year [String, nil]
    # @param opts [Hash]
    # @option opts [String] :format format of fetched document (DOC, PDF)
    #
    # @return [RelatonCcsds::BibliographicItem]
    #
    def get(reference, _year = nil, opts = {}) # rubocop:disable Metrics/MethodLength
      ref = reference.sub(/\s\((DOC|PDF)\)$/, "")
      opts[:format] ||= Regexp.last_match(1)
      Util.warn "(#{reference}) fetching..."
      hits = search ref
      doc = hits.first&.doc&.to_format(opts[:format])
      unless doc
        Util.warn "(#{reference}) not found."
        return nil
      end
      Util.warn "(#{reference}) found `#{hits.first.code}`."
      doc
    end
  end
end
