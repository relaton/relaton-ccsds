require_relative "data_fetcher"

module Relaton
  module Ccsds
    class DataParser
      include Core::ArrayWrapper

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
        title docidentifier abstract date status source edition relation contributor ext
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
        ItemData.new(**args)
      end

      def parse_title
        t = @doc["Dcoument_x0020_Title"]
        [Bib::Title.new(content: t, language: "en", script: "Latn")]
      end

      def parse_docidentifier
        [Bib::Docidentifier.new(content: docidentifier, type: "CCSDS", primary: true)]
      end

      def docidentifier(id = nil)
        id ||= @doc["Document_x0020_Number"].strip
        docid = ID_MAPPING[id] || id
        return docid unless @successor

        docid.sub(/(-S|s)(?=\s|$)/, "")
      end

      def parse_abstract
        a = @doc["Description0"]
        [Bib::LocalizedMarkedUpString.new(content: a, language: "en", script: "Latn")]
      end

      def parse_doctype
        /^CCSDS\s[\d.]+-(?<type>\w+)/ =~ @doc["Document_x0020_Number"]
        Doctype.new content: DOCTYPES[type&.to_sym]
      end

      def parse_date
        at = "#{@doc['calPublishedMonth']} #{@doc['calPublishedYear']}"
        [Bib::Date.new(type: "published", at: at)]
      end

      def parse_status
        stage = Bib::Status::Stage.new content: @successor ? "withdrawn" : "published"
        Bib::Status.new stage: stage
      end

      def parse_source
        l = "#{DOMAIN}#{@doc['FileRef']}"
        t = File.extname(@doc["FileRef"])&.sub(/^\./, "")
        [Bib::Uri.new(type: t, content: l)]
      end

      def parse_edition
        ed = @doc["Issue_x0020_Number"].match(/^\d+/)
        return unless ed

        Bib::Edition.new content: ed.to_s
      end

      def parse_relation
        @docs.each_with_object(successors + adopted) do |d, a|
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

      def successors
        return [] unless @successor

        @successors ||= begin
          if @successor.relation.none? { |r| r.type == "successorOf" }
            @successor.relation << create_relation("successorOf", docidentifier)
          end
          [create_relation("hasSuccessor", @successor.docidentifier[0].id)]
        end
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
        id = Bib::Docidentifier.new content: rel_id, type: "CCSDS", primary: true
        bibitem = Bib::ItemData.new docidentifier: [id], formattedref: rel_id
        Bib::Relation.new type: type, bibitem: bibitem
      end

      def parse_contributor
        array(@doc.dig("Working_x0020_Group", "Description")).map do |name|
          sdname = Bib::TypedLocalizedString.new content: name
          subdiv = Bib::Subdivision.new type: "technical-committee", name: [sdname]
          orgname = Bib::TypedLocalizedString.new content: "CCSDS"
          org = Bib::Organization.new name: [orgname], subdivision: [subdiv]
          description = Bib::LocalizedMarkedUpString.new(content: "committee")
          role = Bib::Contributor::Role.new type: "author", description: [description]
          Bib::Contributor.new(role: [role], organization: org)
        end
      end

      def parse_ext
        Ext.new flavor: "ccsds", doctype: parse_doctype, technology_area: parse_technology_area
      end

      def parse_technology_area
        desc = @doc.dig("Working_x0020_Group", "Description")
        return unless desc

        AREAS[desc.match(/^[A-Z]+(?=-)/)&.to_s]
      end
    end
  end
end
