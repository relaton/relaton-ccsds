module RelatonCcsds
  class DataParser
    DOCTYPES = { B: "standard", M: "practice", G: "report", O: "specification", Y: "record" }.freeze
    DOMAIN = "https://public.ccsds.org".freeze

    AREAS = {
      "SEA" => "Systems Engineering Area",
      "MOIMS" => "Mission Operations and Information Management Services Area",
      "CSS" => "Cross Support Services Area",
      "SOIS" => "Spacecraft Onboard Interface Services Area",
      "SLS" => "Space Link Services Area",
      "SIS" => "Space Internetworking Services Area",
    }.freeze

    ATTRS = %i[
      title docid abstract doctype date docstatus link edition relation editorialgroup technology_area
    ].freeze

    ID_MAPPING = {
      "CCSDS 320.0-B-1-S Corrigendum 1" => "CCSDS 320.0-B-1-S Cor. 1", # TODO relaton/relaton-data-ccsds#5
      "CCSDS 701.00-R-3" => "CCSDS 701.00-R-3-S", # TODO relaton/relaton-data-ccsds#8
    }.freeze

    def initialize(doc, docs, successor = nil)
      @doc = doc
      @docs = docs
      @successor = successor
    end

    def parse
      args = ATTRS.each_with_object({}) { |a, o| o[a] = send "parse_#{a}" }
      BibliographicItem.new(**args)
    end

    def parse_title
      t = @doc["Dcoument_x0020_Title"]
      [RelatonBib::TypedTitleString.new(content: t, language: "en", script: "Latn")]
    end

    def parse_docid
      [RelatonBib::DocumentIdentifier.new(
        id: docidentifier,
        type: "CCSDS", primary: true
      )]
    end

    def docidentifier(id = nil)
      id ||= @doc["Document_x0020_Number"].strip
      docid = ID_MAPPING[id] || id
      return docid unless @successor

      docid.sub(/(-S|s)(?=\s|$)/, "")
    end

    def parse_abstract
      a = @doc["Description0"]
      [RelatonBib::FormattedString.new(content: a, language: "en", script: "Latn")]
    end

    def parse_doctype
      /^CCSDS\s[\d.]+-(?<type>\w+)/ =~ @doc["Document_x0020_Number"]
      DocumentType.new type: DOCTYPES[type&.to_sym]
    end

    def parse_date
      on = "#{@doc['calPublishedMonth']} #{@doc['calPublishedYear']}"
      [RelatonBib::BibliographicDate.new(type: "published", on: on)]
    end

    def parse_docstatus
      stage = @successor ? "withdrawn" : "published"
      RelatonBib::DocumentStatus.new stage: stage
    end

    def parse_link
      l = "#{DOMAIN}#{@doc['FileRef']}"
      t = File.extname(@doc["FileRef"])&.sub(/^\./, "")
      [RelatonBib::TypedUri.new(type: t, content: l)]
    end

    def parse_edition
      @doc["Issue_x0020_Number"].match(/^\d+/)&.to_s
    end

    def parse_relation
      @docs.each_with_object(successor + adopted) do |d, a|
        id = docidentifier d["Document_x0020_Number"].strip
        type = relation_type id
        next unless type

        a << create_relation(type, id)
      end
    end

    def adopted
      return [] unless @doc["ISO_x0020_Number"]

      code = @doc["ISO_x0020_Number"]["Description"].match(/(?<=\s)\d+$/)
      id = "ISO #{code}"
      [create_relation("adoptedAs", id)]
    end

    def successor
      return [] unless @successor

      @successor.relation << create_relation("successorOf", docidentifier)
      [create_relation("hasSuccessor", @successor.docidentifier[0].id)]
    end

    # TODO: cover this
    def relation_type(rel_id)
      return if rel_id == docidentifier ||
        rel_id.match(DataFetcher::TRRGX).to_s != docidentifier.match(DataFetcher::TRRGX).to_s

      if rel_id.include?(docidentifier.sub(DataFetcher::TRRGX, ""))
        "updatedBy"
      elsif docidentifier.include?(rel_id.sub(DataFetcher::TRRGX, ""))
        "updates"
      end
    end

    def create_relation(type, rel_id)
      id = RelatonBib::DocumentIdentifier.new id: rel_id, type: "CCSDS", primary: true
      fref = RelatonBib::FormattedRef.new content: rel_id
      bibitem = RelatonBib::BibliographicItem.new docid: [id], formattedref: fref
      RelatonBib::DocumentRelation.new type: type, bibitem: bibitem
    end

    def parse_editorialgroup
      name = @doc.dig("Working_x0020_Group", "Description")
      return unless name

      wg = RelatonBib::WorkGroup.new name: name
      tc = RelatonBib::TechnicalCommittee.new wg
      RelatonBib::EditorialGroup.new([tc])
    end

    def parse_technology_area
      desc = @doc.dig("Working_x0020_Group", "Description")
      return unless desc

      AREAS[desc.match(/^[A-Z]+(?=-)/)&.to_s]
    end
  end
end
