describe RelatonCcsds::DataFetcher do
  subject { RelatonCcsds::DataFetcher.new "data", "bibxml" }
  let(:identifier) { "CCSDS 123.0-B-1" }

  it "fetch" do
    expect(FileUtils).to receive(:mkdir_p).with("data")
    df = double(:datafetcher)
    expect(df).to receive(:fetch)
    expect(described_class).to receive(:new).with("data", "yaml").and_return df
    described_class.fetch
  end

  it "initialize" do
    expect(subject.instance_variable_get(:@output)).to eq "data"
    expect(subject.instance_variable_get(:@format)).to eq "bibxml"
    expect(subject.instance_variable_get(:@ext)).to eq "xml"
    expect(subject.instance_variable_get(:@files)).to eq []
  end

  context "instance methods" do
    it "#agent" do
      expect(subject.agent).to be_instance_of Mechanize
      expect(subject.agent.request_headers["Accept"]).to eq "application/json;odata=verbose"
    end

    it "#fetch" do
      expect(subject).to receive(:fetch_docs).with(/calActive/)
      expect(subject).to receive(:fetch_docs).with(/Silver/, retired: true)
      expect(subject.index).to receive(:save)
      subject.fetch
    end

    it "#fetch_docs" do
      body = { "d" => { "results" => ["doc"] } }.to_json
      expect(subject.agent).to receive(:get).with(:url).and_return double(body: body)
      expect(subject).to receive(:parse_and_save).with("doc", ["doc"], false)
      subject.fetch_docs :url
    end

    context "#parse_and_save" do
      before do
        dp = double(:dataparser, parse: :bibitem)
        expect(RelatonCcsds::DataParser).to receive(:new).with(:doc, []).and_return dp
        expect(subject).to receive(:save_bib).with(:bibitem)
      end

      it "not retired" do
        subject.parse_and_save :doc, [], false
      end

      it "retired" do
        dp = double(:dataparser, parse: :retired_bibitem)
        expect(RelatonCcsds::DataParser).to receive(:new).with(:doc, [], :bibitem).and_return dp
        expect(subject).to receive(:save_bib).with(:retired_bibitem)
        subject.parse_and_save :doc, [], true
      end
    end

    describe "#get_output_file" do
      subject { RelatonCcsds::DataFetcher.new("data", "bibxml").get_output_file(identifier) }

      it { expect(subject).to eq("data/CCSDS-123-0-B-1.xml") }
    end

    context "#save_bib" do
      # let(:bib) { double(:bibitem, docidentifier: [double(id: identifier)]) }
      let(:bib) { RelatonCcsds::BibliographicItem.new(docid: [RelatonBib::DocumentIdentifier.new(id: identifier)]) }
      let(:id) { Pubid::Ccsds::Identifier.parse(identifier) }

      before do
        # write once when no relations, at least twice when there are relations found
        expect(File).to receive(:write).at_least(:once)#.with("data/CCSDS-123-0-B-1.xml",
                                             # "<reference anchor=\"CCSDS.123.0-B-1\"/>",
                                             # encoding: "UTF-8")
      end

      it "adds identifier's parameters as hash to index" do
        subject.save_bib(bib)
        id_from_index = subject.index.search(id).first[:id]
        expect(id_from_index).to eq(id)
      end

      it "adds identifier as string to old index" do
        subject.save_bib(bib)
        id_from_index = subject.old_index.search(identifier).first[:id]
        expect(id_from_index).to eq(identifier)
      end

      context "when have related translations" do
        before do
          subject.index.add_or_update(
            Pubid::Ccsds::Identifier.parse(translated_identifier),
            "spec/fixtures/ccsds_123_0-b-1_russian_translated.yaml"
          )
        end

        let(:translated_identifier) { "#{identifier} - Russian Translated" }

        it "adds identifier with translation to identifier's relation" do
          subject.save_bib(bib)
          expect(bib.relation.first.bibitem.docidentifier.first.id).to eq(translated_identifier)
        end
      end

      context "when identifier is translation" do
        before do
          subject.index.add_or_update(
            Pubid::Ccsds::Identifier.parse(identifier_without_translation),
            "spec/fixtures/ccsds_123_0-b-1.yaml"
          )
        end

        let(:identifier) { "CCSDS 123.0-B-1 - Russian Translated" }
        let(:identifier_without_translation) { "CCSDS 123.0-B-1" }

        it "adds identifier without translation to identifier's relation" do
          subject.save_bib(bib)
          expect(bib.relation.first.bibitem.docidentifier.first.id).to eq(identifier_without_translation)
        end
      end
    end

    context "#content" do
      let(:bib) { double(:bibitem) }

      it "bibxml" do
        expect(bib).to receive(:send).with("to_bibxml").and_return :bibxml
        expect(subject.content(bib)).to eq :bibxml
      end

      it "yaml" do
        subject.instance_variable_set(:@format, "yaml")
        expect(bib).to receive(:to_hash).and_return "id" => "CCSDS 123.0-B-1"
        expect(subject.content(bib)).to eq "---\nid: CCSDS 123.0-B-1\n"
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
        expect(subject.content(bib)).to eq :xml
      end
    end

    describe "#merge_links" do
      # skip merging when new file
      let(:data_fetcher) { RelatonCcsds::DataFetcher.new("data", "bibxml") }
      subject { data_fetcher.merge_links(bib, "spec/fixtures/ccsds_123_0-b-1.yaml") }

      let(:hash) do
        {
          "docid" => [{ type: "CCSDS", id: "CCSDS 123.0-B-1" }],
          "link" => [{ type: "pdf", content: "http://www.example.com/CCSDS-123-0-B-1.pdf" }],
        }
      end
      let(:bib) { RelatonCcsds::BibliographicItem.from_hash hash }

      before { subject }

      context "when new file" do
        it "doesn't add new link" do
          expect(bib.link.size).to eq(1)
        end
      end

      context "when new item have the same link type" do
        it "does not add new link" do
          data_fetcher.merge_links(bib, "spec/fixtures/ccsds_123_0-b-1.yaml")
          expect(bib.link.size).to eq(1)
        end
      end

      context "when new item have different link type" do
        let(:hash) do
          {
            "docid" => [{ type: "CCSDS", id: "CCSDS 123.0-B-1" }],
            "link" => [{ type: "doc", content: "http://www.example.com/CCSDS-123-0-B-1.pdf" }],
          }
        end

        it "adds another link" do
          data_fetcher.merge_links(bib, "spec/fixtures/ccsds_123_0-b-1.yaml")
          expect(bib.link.size).to eq(2)
        end
      end
    end

    context "#search_instance_translation" do
      it "instance" do
        bib = double(:bibitem, docidentifier: [double(id: "CCSDS 123.0-B-1")])
        expect(subject).to receive(:search_translations).with("CCSDS 123.0-B-1", bib)
        subject.search_instance_translation bib
      end

      it "translation" do
        bib = double(:bibitem, docidentifier: [double(id: "CCSDS 123.0-B-1 - French Translated")])
        expect(subject).to receive(:search_relations).with "CCSDS 123.0-B-1", bib
        subject.search_instance_translation bib
      end
    end

    context "#search_relations" do
      let(:bibid) { "CCSDS 123.0-B-1" }
      let(:bib) do
        double(:bibitem, docidentifier: [double(id: "CCSDS 123.0-B-1 -- Russian Translated")])
      end

      it "found instance" do
        expect(subject.index).to receive(:search).and_yield(id: Pubid::Ccsds::Identifier.parse(bibid), file: "file.yaml")
        expect(subject).to receive(:create_relations).with(bib, "file.yaml")
        subject.search_relations bibid, bib
      end

      it "found another translation" do
        expect(subject.index).to receive(:search).and_yield(
          id: Pubid::Ccsds::Identifier.parse("CCSDS 123.0-B-1 - French Translated"), file: "file.yaml",
        )
        expect(subject).to receive(:create_relations).with(bib, "file.yaml")
        subject.search_relations bibid, bib
      end

      it "not found" do
        expect(subject.index).to receive(:search).and_yield(
          id: Pubid::Ccsds::Identifier.parse("CCSDS 551.1-O-2 - Russian Translated"), file: "file.yaml",
        )
        expect(subject).not_to receive(:create_relations)
        subject.search_relations bibid, bib
      end
    end

    context "#search_translations" do
      let(:bibid) { "CCSDS 123.0-B-1" }

      it "found" do
        bib = double(:bibitem, docidentifier: [double(id: bibid)])
        expect(subject.index).to receive(:search).and_yield(id: "CCSDS 123.0-B-1 - Russian Translated", file: "file.yaml")
        expect(subject).to receive(:create_instance_relation).with(bib, "file.yaml")
        subject.search_translations bibid, bib
      end

      it "not found" do
        bib = double(:bibitem, docidentifier: [double(id: bibid)])
        expect(subject.index).to receive(:search).and_yield(id: bibid, file: "file.yaml")
        expect(subject).not_to receive(:create_instance_relation)
        subject.search_translations bibid, bib
      end
    end

    context "#create_relations" do
      let(:inst) { double "Instance bib", docidentifier: [docid], relation: [] }
      let(:bib) { double "Bibitem", relation: [] }

      before do
        expect(YAML).to receive(:load_file).with("file.yaml").and_return :hash
        expect(RelatonCcsds::BibliographicItem).to receive(:from_hash).with(:hash).and_return inst
        expect(inst).to receive(:to_bibxml).and_return :xml
        expect(File).to receive(:write).with("file.yaml", :xml, encoding: "UTF-8")
      end

      context "translation" do
        let(:docid) { double(id: "CCSDS 650.0-M-2 - Russian Translated") }

        it do
          expect(subject).to receive(:create_relation).with(inst, "hasTranslation").and_return :has_translation
          expect(subject).to receive(:create_relation).with(bib, "hasTranslation").and_return :has_translation
          subject.create_relations bib, "file.yaml"
          expect(bib.relation).to eq [:has_translation]
          expect(inst.relation).to eq [:has_translation]
        end
      end

      context "instance of" do
        let(:docid) { double(id: "CCSDS 650.0-M-2") }

        it do
          expect(subject).to receive(:create_relation).with(inst, "instanceOf").and_return :instance_of
          expect(subject).to receive(:create_relation).with(bib, "hasInstance").and_return :has_instance
          subject.create_relations bib, "file.yaml"
          expect(bib.relation).to eq [:instance_of]
          expect(inst.relation).to eq [:has_instance]
        end
      end
    end

    it "#create_instance_relation" do
      bib = double "Bibitem", relation: []
      inst = double "Instance bib", relation: []
      expect(YAML).to receive(:load_file).with("file.yaml").and_return :hash
      expect(RelatonCcsds::BibliographicItem).to receive(:from_hash).with(:hash).and_return inst
      expect(subject).to receive(:create_relation).with(inst, "hasInstance").and_return :has_instance
      expect(subject).to receive(:create_relation).with(bib, "instanceOf").and_return :instance_of
      expect(subject).to receive(:content).with(inst).and_return :content
      expect(File).to receive(:write).with("file.yaml", :content, encoding: "UTF-8")
      subject.create_instance_relation bib, "file.yaml"
      expect(bib.relation).to eq [:has_instance]
      expect(inst.relation).to eq [:instance_of]
    end

    it "#create_relation" do
      bib = double("Bibitem 2", docidentifier: [double(type: "CCSDS", id: "CCSDS 123.0-B-1")])
      rel = subject.create_relation bib, "hasInstance"
      expect(rel).to be_instance_of RelatonBib::DocumentRelation
      expect(rel.type).to eq "hasInstance"
      expect(rel.bibitem).to be_instance_of RelatonCcsds::BibliographicItem
      expect(rel.bibitem.docidentifier.first.id).to eq "CCSDS 123.0-B-1"
      expect(rel.bibitem.docidentifier.first.type).to eq "CCSDS"
      expect(rel.bibitem.formattedref.content).to eq "CCSDS 123.0-B-1"
    end
  end
end
