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
      @index ||= Relaton::Index.find_or_create "CCSDS", file: "index-v1.yaml"
    end

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
    end

    def fetch_docs(url, retired: false)
      resp = agent.get(url)
      json = JSON.parse resp.body
      @array = json["d"]["results"].map do |doc|
        parse_and_save doc, json["d"]["results"], retired
      end
    end

    def parse_and_save(doc, results, retired)
      bibitem = DataParser.new(doc, results).parse
      if retired
        predecessor = DataParser.new(doc, results, bibitem).parse
        save_bib predecessor
      end
      save_bib bibitem
    end

    def save_bib(bib) # rubocop:disable Metrics/MethodLength
      search_translation bib
      id = bib.docidentifier.first.id
      file = File.join @output, "#{id.gsub(/[.\s-]+/, '-')}.#{@ext}"
      if @files.include? file
        puts "(#{file}) file already exists. Trying to merge links ..."
        merge_links bib, file
      else
        @files << file
      end
      File.write file, content(bib), encoding: "UTF-8"
      index.add_or_update id, file
    end

    def search_translation(bib) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      bibid = bib.docidentifier.first.id.dup
      if bibid.sub!(TRRGX, "")
        index.search do |row|
          id = row[:id].sub(TRRGX, "")
          next if id != bibid || row[:id] == bib.docidentifier.first.id

          create_translation_relation bib, row[:file]
        end
      else
        index.search do |row|
          next unless row[:id].match?(/^#{bibid}#{TRRGX}/)

          create_instance_relation bib, row[:file]
        end
      end
    end

    def create_translation_relation(bib, file)
      hash = YAML.load_file file
      inst = BibliographicItem.from_hash hash
      if inst.docidentifier.first.id.match?(TRRGX)
        type1 = type2 = "hasTranslation"
      else
        type1 = "instanceOf"
        type2 = "hasInstance"
      end
      create_relation(bib, inst, type1)
      create_relation(inst, bib, type2)
    end

    def create_instance_relation(bib, file)
      hash = YAML.load_file file
      inst = BibliographicItem.from_hash hash
      create_relation bib, inst, "hasInstance"
      create_relation inst, bib, "instanceOf"
    end

    def create_relation(bib1, bib2, type)
      fref = RelatonBib::FormattedRef.new content: bib2.docidentifier.first.id
      rel = BibliographicItem.new docid: bib2.docidentifier, formattedref: fref
      bib1.relation << RelatonBib::DocumentRelation.new(type: type, bibitem: rel)
    end

    def merge_links(bib, file) # rubocop:disable Metrics/AbcSize
      hash = YAML.load_file file
      bib2 = BibliographicItem.from_hash hash
      if bib.link[0].type == bib2.link[0].type
        warn "(#{file}) links are the same."
        return
      end
      warn "(#{file}) links are merged."
      bib.link << bib2.link[0]
    end

    def content(bib)
      case @format
      when "yaml" then bib.to_hash.to_yaml
      when "xml" then bib.to_xml(bibdata: true)
      else bib.send "to_#{@format}"
      end
    end
  end
end
