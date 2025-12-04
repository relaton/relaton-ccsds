require_relative "hit_collection"

module Relaton
  module Ccsds
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
        HitCollection.new(ref).fetch
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
        Util.info "Fetching from Relaton repository ...", key: reference
        hits = search ref
        item = hits.first&.item # &.to_format(opts[:format])
        unless item
          Util.info "Not found.", key: reference
          return nil
        end
        Util.info "Found: `#{hits.first.hit[:code]}`.", key: reference
        item
      end
    end
  end
end
