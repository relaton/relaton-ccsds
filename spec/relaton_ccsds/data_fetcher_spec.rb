describe RelatonCcsds::DataFetcher do
  subject { RelatonCcsds::DataFetcher.new "data", "bibxml" }

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

    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
      expect(subject.index.instance_variable_get(:@file)).to eq "index-v1.yaml"
      io = subject.index.instance_variable_get(:@file_io)
      expect(io.instance_variable_get(:@dir)).to eq "ccsds"
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

    context "#save_bib" do
      let(:bib) { double(:bibitem, docidentifier: [double(id: "CCSDS 123.0-B-1")]) }

      before do
        expect(subject).to receive(:content).with(bib).and_return :content
        expect(File).to receive(:write).with("data/CCSDS-123-0-B-1.xml", :content, encoding: "UTF-8")
        expect(subject.index).to receive(:add_or_update).with("CCSDS 123.0-B-1", "data/CCSDS-123-0-B-1.xml")
      end

      it do
        subject.save_bib bib
        expect(subject.instance_variable_get(:@files)).to eq ["data/CCSDS-123-0-B-1.xml"]
      end

      it "file exists" do
        expect(subject).to receive(:merge_links).with(bib, "data/CCSDS-123-0-B-1.xml")
        subject.instance_variable_set(:@files, ["data/CCSDS-123-0-B-1.xml"])
        expect { subject.save_bib bib }.to output(/file already exists/).to_stdout
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

    context "#merge_links" do
      let(:hash) do
        {
          "docid" => [{ type: "CCSDS", id: "CCSDS 123.0-B-1" }],
          "link" => [{ type: "pdf", content: "http://www.example.com/CCSDS-123-0-B-1.pdf" }],
        }
      end
      let(:bib) { RelatonCcsds::BibliographicItem.from_hash hash }

      it "no new link" do
        expect(YAML).to receive(:load_file).with("data/CCSDS-123-0-B-1.xml").and_return hash
        subject.merge_links bib, "data/CCSDS-123-0-B-1.xml"
        expect(bib.link.size).to eq 1
      end

      it "new link" do
        hash2 = {
          "docid" => [{ type: "CCSDS", id: "CCSDS 123.0-B-1" }],
          "link" => [{ type: "doc", content: "http://www.example.com/CCSDS-123-0-B-1.doc" }],
        }
        expect(YAML).to receive(:load_file).with("data/CCSDS-123-0-B-1.xml").and_return hash2
        subject.merge_links bib, "data/CCSDS-123-0-B-1.xml"
        expect(bib.link.size).to eq 2
      end
    end

    context "#search_translation" do
      context "for translation" do
        let(:bib) do
          docid = double(id: "CCSDS 650.0-M-2 - French Translated")
          double(:bibitem, docidentifier: [docid])
        end

        it "found instance" do
          expect(subject.index).to receive(:search).and_yield(id: "CCSDS 650.0-M-2", file: "file.yaml")
          expect(subject).to receive(:create_translation_relation).with(bib, "file.yaml")
          subject.search_translation bib
        end

        it "found another translation" do
          expect(subject.index).to receive(:search)
            .and_yield(id: "CCSDS 650.0-M-2 - Russian Translated", file: "file.yaml")
          expect(subject).to receive(:create_translation_relation).with(bib, "file.yaml")
          subject.search_translation bib
        end

        it "not found" do
          expect(subject.index).to receive(:search).and_yield(id: "CCSDS 651.0-M-1", file: "file.yaml")
          expect(subject).not_to receive(:create_translation_relation)
          subject.search_translation bib
        end

        it "skip self" do
          expect(subject.index).to receive(:search)
            .and_yield(id: "CCSDS 650.0-M-2 - French Translated", file: "file.yaml")
          expect(subject).not_to receive(:create_translation_relation)
          subject.search_translation bib
        end

        it "skip successor" do
          expect(subject.index).to receive(:search)
            .and_yield(id: "CCSDS 650.0-M-2-S - French Translated", file: "file.yaml")
          expect(subject).not_to receive(:create_translation_relation)
          subject.search_translation bib
        end
      end

      context "for instance" do
        let(:bib) { double(:bibitem, docidentifier: [double(id: "CCSDS 650.0-M-2")]) }

        it "found translation" do
          expect(subject.index).to receive(:search)
            .and_yield({ id: "CCSDS 650.0-M-2 - French Translated", file: "file.yaml" })
          expect(subject).to receive(:create_instance_relation).with(bib, "file.yaml")
          subject.search_translation bib
        end

        it "not found" do
          expect(subject.index).to receive(:search).and_yield({ id: "CCSDS 650.0-M-2", file: "file.yaml" })
          expect(subject).not_to receive(:create_instance_relation)
          subject.search_translation bib
        end
      end
    end

    context "#create_translation_relation" do
      let(:inst) { double "Instance bib", docidentifier: [docid] }

      before do
        expect(YAML).to receive(:load_file).with("file.yaml").and_return :hash
        expect(RelatonCcsds::BibliographicItem).to receive(:from_hash).with(:hash).and_return inst
      end

      context "translation" do
        let(:docid) { double(id: "CCSDS 650.0-M-2 - Russian Translated") }

        it do
          expect(subject).to receive(:create_relation).with(:bib, inst, "hasTranslation")
          expect(subject).to receive(:create_relation).with(inst, :bib, "hasTranslation")
          subject.create_translation_relation :bib, "file.yaml"
        end
      end

      context "instance of" do
        let(:docid) { double(id: "CCSDS 650.0-M-2") }

        it do
          expect(subject).to receive(:create_relation).with(:bib, inst, "instanceOf")
          expect(subject).to receive(:create_relation).with(inst, :bib, "hasInstance")
          subject.create_translation_relation :bib, "file.yaml"
        end
      end
    end

    it "#create_instance_relation" do
      expect(YAML).to receive(:load_file).with("file.yaml").and_return :hash
      expect(RelatonCcsds::BibliographicItem).to receive(:from_hash).with(:hash).and_return :inst
      expect(subject).to receive(:create_relation).with(:bib, :inst, "hasInstance")
      expect(subject).to receive(:create_relation).with(:inst, :bib, "instanceOf")
      subject.create_instance_relation :bib, "file.yaml"
    end

    it "#create_relation" do
      bib2 = double("Bibitem 2", docidentifier: [double(type: "CCSDS", id: "CCSDS 123.0-B-1")])
      bib1 = double("Bibitem 1", relation: [])
      subject.create_relation bib1, bib2, "hasInstance"
      expect(bib1.relation.size).to eq 1
      expect(bib1.relation.first).to be_instance_of RelatonBib::DocumentRelation
      expect(bib1.relation.first.type).to eq "hasInstance"
      expect(bib1.relation.first.bibitem).to be_instance_of RelatonCcsds::BibliographicItem
      expect(bib1.relation.first.bibitem.docidentifier.first.id).to eq "CCSDS 123.0-B-1"
      expect(bib1.relation.first.bibitem.formattedref.content).to eq "CCSDS 123.0-B-1"
    end
  end
end
