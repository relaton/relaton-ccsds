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

    # @param text [String]
    # @param year [String]
    # @param opts [Hash]
    # @return [RelatonCcsds::HitCollection]
    def get(ref, _year = nil, _opts = {})
      Util.warn "(#{ref}) fetching..."
      hits = search ref
    end
  end
end
