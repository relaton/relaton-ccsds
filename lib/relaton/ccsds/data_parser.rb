require_relative "model/item"
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
        t = @doc[3]
        [Bib::Title.new(content: t, language: "en", script: "Latn")]
      end

      def parse_docidentifier
        [Bib::Docidentifier.new(content: docidentifier, type: "CCSDS", primary: true)]
      end

      def docidentifier(id = nil)
        id ||= @doc[2].strip.match(/(?<=>).+(?=<\/a>)/).to_s
        docid = ID_MAPPING[id] || id
        return docid unless @successor

        docid.sub(/(-S|s)(?=\s|$)/, "")
      end

      def parse_abstract
        a = @doc[7]
        [Bib::LocalizedMarkedUpString.new(content: a, language: "en", script: "Latn")]
      end

      def parse_doctype
        />CCSDS\s[\d.]+-(?<type>\w+)/ =~ @doc[2]
        Doctype.new content: DOCTYPES[type&.to_sym]
      end

      def parse_date
        at = @doc[6]
        [Bib::Date.new(type: "published", at: at)]
      end

      def parse_status
        stage = Bib::Status::Stage.new content: @successor ? "withdrawn" : "published"
        Bib::Status.new stage: stage
      end

      def parse_source
        sources = []
        src = create_source(@doc[2], "src")
        sources << src if src

        pdf = create_source(@doc[1], "pdf")
        sources << pdf if pdf

        sources
      end

      def create_source(link, type)
        /(?<href>https?:[^"]+)/ =~ link
        return unless href

        Bib::Uri.new(type: type, content: href)
      end

      def parse_edition
        return unless @doc[5]

        Bib::Edition.new content: @doc[5]
      end

      def parse_relation
        successors + adopted
        # @docs.each_with_object(successors + adopted) do |d, a|
        #   id = docidentifier d["Document_x0020_Number"].strip
        #   type = relation_type id
        #   next unless type

        #   a << create_relation(type, id)
        # end
      end

      def adopted
        /(?<href>https?:[^"]+)/ =~ @doc[9]
        array(href).each_with_object([]) do |uri, acc|
          iso_doc = get_iso_page_with_raite_limit(uri)
          next unless iso_doc

          iso_id = iso_doc.at("//h1/span[1]").text.strip
          acc << create_relation("adoptedAs", iso_id, uri)
        end
      end

      def get_iso_page_with_raite_limit(uri)
        trys = 3
        begin
          sleeptime = @prev_request_time ? rand(5..10) - (Time.now - @prev_request_time) : 0
          sleep(sleeptime) if sleeptime.positive?
          @prev_request_time = Time.now
          agent.get(uri)
        rescue Mechanize::ResponseCodeError => e
          trys -= 1
          retry if trys.positive? && [403, 429].include?(e.response_code.to_i)
          Util.error "Failed to fetch ISO page #{uri}: #{e.message}"
        rescue Net::HTTPNotFound => e
          Util.warn "Failed to fetch ISO page #{uri}: #{e.message}"
        end
      end

      def agent
        @agent ||= begin
          mechanize = Mechanize.new
          mechanize.user_agent_alias = Mechanize::AGENT_ALIASES.keys.sample
          mechanize
        end
      end

      def successors
        return [] unless @successor

        @successors ||= begin
          if @successor.relation.none? { |r| r.type == "successorOf" }
            @successor.relation << create_relation("successorOf", docidentifier)
          end
          [create_relation("hasSuccessor", @successor.docidentifier[0].content)]
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

      def create_relation(type, rel_id, uri = nil)
        id = Bib::Docidentifier.new content: rel_id, type: "CCSDS", primary: true
        source = array(uri).map { |u| Bib::Uri.new(type: "src", content: u) }
        bibitem = Bib::ItemData.new docidentifier: [id], source: source, formattedref: rel_id
        Bib::Relation.new type: type, bibitem: bibitem
      end

      def parse_contributor # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        array(@doc[8]).each_with_object([]) do |wg, acc|
          /^(?<name>[^<]+)/ =~ wg
          next if name.nil? || name.strip.empty?

          sdname = Bib::TypedLocalizedString.new content: name.strip
          subdiv = Bib::Subdivision.new type: "technical-committee", name: [sdname]
          orgname = Bib::TypedLocalizedString.new content: "CCSDS"
          org = Bib::Organization.new name: [orgname], subdivision: [subdiv]
          description = Bib::LocalizedMarkedUpString.new(content: "committee")
          role = Bib::Contributor::Role.new type: "author", description: [description]
          acc << Bib::Contributor.new(role: [role], organization: org)
        end
      end

      def parse_ext
        Ext.new flavor: "ccsds", doctype: parse_doctype, technology_area: parse_technology_area
      end

      def parse_technology_area
        desc = @doc[8].split.first
        AREAS[desc]
      end
    end
  end
end
