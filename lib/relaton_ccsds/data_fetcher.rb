module RelatonCcsds
  class DataFetcher
    ACTIVE_PUBS_URL = <<~URL.freeze
      https://public.ccsds.org/_api/web/lists/getbytitle('CCSDS%20Publications')/items?$top=1000&$select=Dcoument_x0020_Title,
      Document_x0020_Number,Book_x0020_Type,Issue_x0020_Number,calPublishedMonth,calPublishedYear,Description0,Working_x0020_Group,
      FileRef,ISO_x0020_Number,Patents,Extra_x0020_Link,Area,calActive,calHtmlColorCode&$filter=Book_x0020_Type%20eq%20%27Blue%20
      Book%27%20or%20Book_x0020_Type%20eq%20%27Magenta%20Book%27%20or%20Book_x0020_Type%20eq%20%27Green%20Book%27%20or%20
      Book_x0020_Type%20eq%20%27Orange%20Book%27%20or%20Book_x0020_Type%20eq%20%27Yellow%20Book%20-%20Reports%20and%20Records%27%20
      or%20Book_x0020_Type%20eq%20%27Yellow%20Book%20-%20CCSDS%20Normative%20Procedures%27
    URL

    OBSOLETE_PUBS_URL = <<~URL.freeze
      https://public.ccsds.org/_api/web/lists/getbytitle('CCSDS%20Publications')/items?$top=1000&$select=Dcoument_x0020_Title,
      Document_x0020_Number,Book_x0020_Type,Issue_x0020_Number,calPublishedMonth,calPublishedYear,Description0,Working_x0020_Group,
      FileRef,ISO_x0020_Number,Patents,Extra_x0020_Link,Area,calHtmlColorCode&$filter=Book_x0020_Type%20eq%20%27Silver%20Book%27
    URL

    TRRGX = /\s-\s\w+\sTranslated$/.freeze

    #
    # Initialize fetcher
    #
    # @param [String] output path to output directory
    # @param [String] format output format (yaml, xml, bibxml)
    #
    def initialize(output, format)
      @output = output
      @format = format
      @ext = format.sub "bibxml", "xml"
      @files = []
    end

    def agent
      return @agent if @agent

      @agent = Mechanize.new
      @agent.request_headers = { "Accept" => "application/json;odata=verbose" }
      @agent
    end

    def index
      @index ||= Relaton::Index.find_or_create "CCSDS", file: "index-v2.yaml", pubid_class: Pubid::Ccsds::Identifier
    end

    def old_index
      @old_index ||= Relaton::Index.find_or_create "CCSDS", file: "index-v1.yaml"
    end

    #
    # Create fetcher instance and fetch data
    #
    # @param [String] output path to output directory (default: "data")
    # @param [String] format output format (yaml, xml, bibxml) (default: "yaml")
    #
    # @return [void]
    #
    def self.fetch(output: "data", format: "yaml")
      t1 = Time.now
      puts "Started at: #{t1}"
      FileUtils.mkdir_p output
      new(output, format).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    def fetch
      fetch_docs ACTIVE_PUBS_URL
      fetch_docs OBSOLETE_PUBS_URL, retired: true
      index.save
      old_index.save
    end

    #
    # Fetch documents from url
    #
    # @param [String] url
    # @param [Boolean] retired if true, then fetch retired documents
    #
    # @return [void]
    #
    def fetch_docs(url, retired: false)
      resp = agent.get(url)
      json = JSON.parse resp.body
      @array = json["d"]["results"].map do |doc|
        parse_and_save doc, json["d"]["results"], retired
      end
    end

    #
    # Parse document and save to file
    #
    # @param [Hash] doc document data
    # @param [Array<Hash>] results collection of documents
    # @param [Boolean] retired if true then document is retired
    #
    # @return [void]
    #
    def parse_and_save(doc, results, retired)
      bibitem = DataParser.new(doc, results).parse
      if retired
        predecessor = DataParser.new(doc, results, bibitem).parse
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
    # @param [RelatonCcsds::BibliographicItem] bib bibitem
    #
    # @return [void]
    #
    def save_bib(bib)
      search_instance_translation bib
      file = get_output_file(bib.docidentifier.first.id)
      merge_links bib, file
      File.write file, content(bib), encoding: "UTF-8"
      index.add_or_update Pubid::Ccsds::Identifier.parse(bib.docidentifier.first.id), file
      old_index.add_or_update bib.docidentifier.first.id, file
    rescue StandardError => e
      puts "Failed to save #{bib.docidentifier.first.id}: #{e.message}\n#{e.backtrace[0..5].join("\n")}"
    end

    #
    # Search translation and instance relation
    #
    # @param [RelatonCcsds::BibliographicItem] bib <description>
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
    # @param [RelatonCcsds::BibliographicItem] bib instance or translation bibitem
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
    # @param [RelatonCcsds::BibliographicItem] bib bibliographic item
    # @param [String] file translation or instance file
    #
    # @return [void]
    #
    def create_relations(bib, file)
      hash = YAML.load_file file
      inst = BibliographicItem.from_hash hash
      type1, type2 = translation_relation_types(inst)
      bib.relation << create_relation(inst, type1)
      inst.relation << create_relation(bib, type2)
      File.write file, content(inst), encoding: "UTF-8"
    end

    #
    # Translation or instance relation types
    #
    # @param [RelatonCcsds::BibliographicItem] bib bibliographic item
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
    # @param [RelatonCcsds::BibliographicItem] bib bibliographic item
    # @param [String] file file name
    #
    # @return [void]
    #
    def create_instance_relation(bib, file)
      hash = YAML.load_file file
      inst = BibliographicItem.from_hash hash
      bib.relation << create_relation(inst, "hasInstance")
      inst.relation << create_relation(bib, "instanceOf")
      File.write file, content(inst), encoding: "UTF-8"
    end

    #
    # Create relation
    #
    # @param [RelatonCcsds::BibliographicItem] bib the related bibliographic item
    # @param [String] type type of relation
    #
    # @return [RelatonBib::DocumentRelation] relation
    #
    def create_relation(bib, type)
      fref = RelatonBib::FormattedRef.new content: bib.docidentifier.first.id
      rel = BibliographicItem.new docid: bib.docidentifier, formattedref: fref
      RelatonBib::DocumentRelation.new(type: type, bibitem: rel)
    end

    #
    # Merge identical documents with different links (updaes given bibitem)
    #
    # @param [RelatonCcsds::BibliographicItem] bib bibliographic item
    # @param [String] file path to existing document
    #
    # @return [void]
    #
    def merge_links(bib, file) # rubocop:disable Metrics/AbcSize
      # skip merging when new file
      unless @files.include?(file)
        @files << file
        return
      end

      puts "(#{file}) file already exists. Trying to merge links ..."

      hash = YAML.load_file file
      bib2 = BibliographicItem.from_hash hash
      if bib.link[0].type == bib2.link[0].type
        Util.info "links are the same.", key: file
        return
      end
      Util.info "links are merged.", key: file
      bib.link << bib2.link[0]
    end

    #
    # Srerialize bibliographic item
    #
    # @param [RelatonCcsds::BibliographicItem] bib <description>
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
