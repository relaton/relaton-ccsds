module RelatonCcsds
  module HashConverter
    include RelatonBib::HashConverter
    extend self
    # @param args [Hash]
    # @return [Hash]
    def hash_to_bib(args)
      ret = super
      return unless ret

      ret[:technology_area] = ret[:ext][:technology_area] if ret[:ext]
      ret
    end

    # @param item_hash [Hash]
    # @return [RelatonCie::BibliographicItem]
    def bib_item(item_hash)
      BibliographicItem.new(**item_hash)
    end

    def create_doctype(**args)
      DocumentType.new(**args)
    end
  end
end
