module RelatonCcsds
  module XMLParser
    include RelatonBib::Parser::XML
    extend self
    #
    # Parse bibitem data
    #
    # @param bibitem [Nokogiri::XML::Element] bibitem element
    #
    # @return [Hash] bibitem data
    #
    def item_data(doc)
      resp = super
      resp[:technology_area] = doc.at("./ext/technology-area")&.text
      resp
    end

    #
    # override RelatonBib::XMLParser#bib_item method
    #
    # @param item_hash [Hash]
    #
    # @return [RelatonCcsds::BibliographicItem]
    #
    def bib_item(item_hash)
      BibliographicItem.new(**item_hash)
    end
  end
end
