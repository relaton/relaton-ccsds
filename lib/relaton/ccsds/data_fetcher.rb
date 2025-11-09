module Relaton
  module Ccsds
    class DataFetcher < Relaton::Core::DataFetcher
      TRRGX = /\s-\s\w+\sTranslated$/

      def agent
        return @agent if @agent

        @agent = Mechanize.new
        @agent.request_headers = { "Accept" => "application/json;odata=verbose" }
        @agent
      end

      def index
        @index ||= Relaton::Index.find_or_create(
          "CCSDS", file: HitCollection::INDEX_FILE, pubid_class: Pubid::Ccsds::Identifier
        )
      end

      def fetch(_source = nil)
        fetch_docs "https://ccsds.org/publications/ccsdsallpubs/"
        index.save
      end

      #
      # Fetch documents from url
      #
      # @param [String] url
      #
      # @return [void]
      #
      def fetch_docs(url)
        resp = agent.get(url)
        json = JSON.parse resp.body.match(/const config = (.*);/)[1]
        @array = json["data"].map { |doc| parse_and_save doc, json["data"] }
      end

      #
      # Parse document and save to file
      #
      # @param [Hash] doc document data
      # @param [Array<Array<String>>] data collection of documents
      #   0 - empty
      #   1 - center/a HTML element with href to PDF
      #   2 - a HTML element with href to HTML and document ID content (e.g. "CCSDS 123.0-B-1")
      #   3 - document title
      #   4 - document series (e.g. "Blue Book", "Silver Book", etc)
      #   5 - issue number
      #   6 - publication date (e.g. "August 2020")
      #   7 - abstract
      #   8 - Working Group as `{WG name} <a href="{path}" ...`
      #   9 - ISO Equivalent as `{ISO id} <a href="{uri}" ...`
      #  10 - Patent Licensing. Some docs has this field. Content is same and looks not useful.
      #  11 - Extra Information. Looks not useful.
      #
      # @return [void]
      #
      def parse_and_save(doc, data)
        bibitem = DataParser.new(doc, data).parse
        if doc[4] == "Silver Book"
          predecessor = DataParser.new(doc, data, bibitem).parse
          save_bib predecessor
        end
        save_bib bibitem
      end

      def get_output_file(id)
        File.join @output, "#{id.gsub(/[.\s-]+/, '-')}.#{@ext}"
      end

      #
      # Save bibitem to file
      #
      # @param [Relaton::Ccsds::Item] bib bibitem
      #
      # @return [void]
      #
      def save_bib(bib) # rubocop:disable Metrics/AbcSize
        search_instance_translation bib
        file = get_output_file(bib.docidentifier.first.id)
        merge_links bib, file
        File.write file, content(bib), encoding: "UTF-8"
        index.add_or_update Pubid::Ccsds::Identifier.parse(bib.docidentifier.first.id), file
      rescue StandardError => e
        puts "Failed to save #{bib.docidentifier.first.id}: #{e.message}\n#{e.backtrace[0..5].join("\n")}"
      end

      #
      # Search translation and instance relation
      #
      # @param [Relaton::Ccsds::Item] bib translation bibitem
      #
      # @return [void]
      #
      def search_instance_translation(bib)
        bibid = bib.docidentifier.first.id.dup
        if bibid.sub!(TRRGX, "")
          search_relations bibid, bib
        else
          search_translations bibid, bib
        end
      end

      #
      # Search instance or translation relation
      #
      # @param [String] bibid instance bibitem id
      # @param [Relaton::Ccsds::ItemData] bib instance or translation bibitem
      #
      # @return [void]
      #
      def search_relations(bibid, bib)
        index.search do |row|
          id = row[:id].exclude(:language)
          # TODO: smiplify this line?
          next if id != bibid || row[:id] == bib.docidentifier.first.id

          create_relations bib, row[:file]
        end
      end

      def search_translations(bibid, bib)
        # will call create_instance_relation if
        # there are same identifiers in index but with word "Translated"
        index.search do |row|
          next unless row[:id].language && row[:id].exclude(:language) == bibid

          create_instance_relation bib, row[:file]
        end
      end

      #
      # Create translation or instance relation and save to file
      #
      # @param [Relaton::Ccsds::ItemData] bib bibliographic item
      # @param [String] file translation or instance file
      #
      # @return [void]
      #
      def create_relations(bib, file)
        inst = Item.from_yaml File.read(file, encoding: "UTF-8")
        type1, type2 = translation_relation_types(inst)
        bib.relation << create_relation(inst, type1)
        inst.relation << create_relation(bib, type2)
        File.write file, content(inst), encoding: "UTF-8"
      end

      #
      # Translation or instance relation types
      #
      # @param [Relaton::Ccsds::ItemData] bib bibliographic item
      #
      # @return [Array<String>] relation types
      #
      def translation_relation_types(bib)
        if bib.docidentifier.first.id.match?(TRRGX)
          ["hasTranslation"] * 2
        else
          ["instanceOf", "hasInstance"]
        end
      end

      #
      # Create instance relation and save to file
      #
      # @param [Relaton::Ccsds::Item] bib bibliographic item
      # @param [String] file file name
      #
      # @return [void]
      #
      def create_instance_relation(bib, file)
        inst = Item.from_yaml File.read(file, encoding: "UTf-8")
        bib.relation << create_relation(inst, "hasInstance")
        inst.relation << create_relation(bib, "instanceOf")
        File.write file, content(inst), encoding: "UTF-8"
      end

      #
      # Create relation
      #
      # @param [Relaton::Ccsds::Item] bib the related bibliographic item
      # @param [String] type type of relation
      #
      # @return [Relaton::Bib::Relation] relation
      #
      def create_relation(bib, type)
        rel = Item.new docidentifier: bib.docidentifier, formattedref: bib.docidentifier.first.content
        Relaton::Bib::Relation.new(type: type, bibitem: rel)
      end

      #
      # Merge identical documents with different links (updaes given bibitem)
      #
      # @param [Relaton::Ccsds::Item] bib bibliographic item
      # @param [String] file path to existing document
      #
      # @return [void]
      #
      def merge_links(bib, file) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        # skip merging when new file
        unless @files.include?(file)
          @files << file
          return
        end

        puts "(#{file}) file already exists. Trying to merge links ..."

        bib2 = Item.from_yaml File.read(file, encoding: "UTF-8")
        if bib.source[0].type == bib2.source[0].type
          Util.info "links are the same.", key: file
          return
        end
        Util.info "links are merged.", key: file
        bib.source << bib2.source[0]
      end

      #
      # Srerialize bibliographic item
      #
      # @param [Relaton::Ccsds::Item] bib bibliographic item
      #
      # @return [String] serialized bibliographic item
      #
      def content(bib)
        case @format
        when "yaml" then bib.to_hash.to_yaml
        when "xml" then bib.to_xml(bibdata: true)
        else bib.send "to_#{@format}"
        end
      end
    end
  end
end
