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
    #
    # @param text [String]
    # @param year [String, nil]
    # @param opts [Hash]
    #
    # @return [RelatonCcsds::BibliographicItem]
    #
    def get(ref, _year = nil, _opts = {})
      Util.warn "(#{ref}) fetching..."
      hits = search ref
      if hits.empty?
        Util.warn "(#{ref}) not found."
        return nil
      end
      doc = hits.first.doc
      Util.warn "(#{ref}) found `#{hits.first.code}`."
      doc
    end
  end
end
