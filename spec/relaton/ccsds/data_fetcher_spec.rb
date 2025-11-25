require "relaton/ccsds/data_fetcher"

describe Relaton::Ccsds::DataFetcher do
  subject { described_class.new "data", "xml" }
  let(:identifier) { "CCSDS 123.0-B-1" }

  context "instance methods" do
    it "#agent" do
      expect(subject.agent).to be_instance_of Mechanize
      expect(subject.agent.request_headers["Accept"]).to eq "application/json;odata=verbose"
    end

    it "#fetch" do
      expect(subject).to receive(:fetch_docs).with(/ccsdsallpubs/)
      expect(subject.index).to receive(:save)
      subject.fetch
    end

    it "#fetch_docs" do
      body = File.read("spec/fixtures/ccsdsallpubs.html", encoding: "UTF-8")
      expect(subject.agent).to receive(:get).with(:url).and_return double(body: body)
      expect(subject).to receive(:parse_and_save) do |doc, data|
        expect(doc).to include "Telemetry Summary of Concept and Rationale"
        expect(data).to include doc
      end
      subject.fetch_docs :url
    end

    context "#parse_and_save" do
      let(:doc) do
        [
          "",
          "<center><a href=\"https:\/\/ccsds.org\/wp-content\/uploads\/gravity_forms\/5-448e85c647331d9cbaf66c096458bdd5\/2025\/03\/\/100x0g1s.pdf\" target=\"_blank\" download><i class=\"fa-regular fa-file-pdf fa-lg\" style=\"color:#808080\"><\/i><\/a><\/center>",
          "<a href=\"https:\/\/ccsds.org\/publications\/ccsdsallpubs\/entry\/3537\/\">CCSDS 100.0-G-1-S<\/a>",
          "Telemetry Summary of Concept and Rationale",
          "Silver Book",
          "1",
          "December 1987",
          "<p>This Report presents the conceptual framework and rationale for the CCSDS Telemetry System. It provides background information supporting the two CCSDS technical Recommendations for Telemetry, Telemetry Channel Coding and Packet Telemetry.<\/p>\n",
          "None <a href=\"\" target=\"_blank\" rel=\"noopener noreferrer\">\r\n\t<i class=\"fa fa-link\" aria-hidden=\"true\"><\/i>\r\n<\/a>",
          "",
          "",
          "",
        ]
      end

      it "retired" do
        # resp = double "response"
        # expect(resp).to receive(:at).with("//h1/span[1]").and_return double(text: "ISO 11754:2003")
        # agent = double "agent"
        # expect(agent).to receive(:get).with("https://www.iso.org/standard/3538.html").and_return resp
        # expect(Mechanize).to receive(:new).and_return agent
        expect(subject).to receive(:save_bib) do |bib|
          expect(bib).to be_instance_of Relaton::Ccsds::ItemData
        end.twice
        subject.parse_and_save doc, [doc]
      end
    end

    describe "#get_output_file" do
      subject { described_class.new("data", "yaml").get_output_file(identifier) }

      it { expect(subject).to eq("data/CCSDS-123-0-B-1.yaml") }
    end

    context "#save_bib" do
      let(:docid) { Relaton::Bib::Docidentifier.new(content: identifier) }
      let(:bib) { Relaton::Ccsds::ItemData.new(docidentifier: [docid]) }
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

      xit "adds identifier as string to old index" do
        subject.save_bib(bib)
        id_from_index = subject.old_index.search(identifier).first[:id]
        expect(id_from_index).to eq(identifier)
      end

      context "when have related translations" do
        before do
          subject.index.add_or_update(
            Pubid::Ccsds::Identifier.parse(translated_identifier),
            "spec/fixtures/ccsds_123_0-b-1_russian_translated.yaml",
          )
        end

        let(:translated_identifier) { "#{identifier} - Russian Translated" }

        it "adds identifier with translation to identifier's relation" do
          subject.instance_variable_set(:@format, "yaml")
          subject.save_bib(bib)
          expect(bib.relation.first.bibitem.docidentifier.first.content).to eq(translated_identifier)
        end
      end

      context "when identifier is translation" do
        before do
          subject.index.add_or_update(
            Pubid::Ccsds::Identifier.parse(identifier_without_translation),
            "spec/fixtures/ccsds_123_0-b-1.yaml",
          )
        end

        let(:identifier) { "CCSDS 123.0-B-1 - Russian Translated" }
        let(:identifier_without_translation) { "CCSDS 123.0-B-1" }

        it "adds identifier without translation to identifier's relation" do
          subject.instance_variable_set(:@format, "yaml")
          subject.save_bib(bib)
          expect(bib.relation.first.bibitem.docidentifier.first.content).to eq(identifier_without_translation)
        end
      end
    end

    context "#content" do
      let(:bib) { Relaton::Ccsds::ItemData.new(docidentifier: [Relaton::Bib::Docidentifier.new(content: identifier)]) }

      xit "bibxml" do
        expect(subject.content(bib)).to eq :bibxml
      end

      it "yaml" do
        subject.instance_variable_set(:@format, "yaml")
        expect(subject.content(bib)).to include "content: CCSDS 123.0-B-1\n"
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
        expect(subject.content(bib)).to eq :xml
      end
    end

    describe "#merge_links" do
      # skip merging when new file
      let(:data_fetcher) { described_class.new("data", "yaml") }
      subject { data_fetcher.merge_links(bib, "spec/fixtures/ccsds_123_0-b-1.yaml") }

      let(:yaml) do
        {
          "docidentifier" => [{ "type" => "CCSDS", "content" => "CCSDS 123.0-B-1" }],
          "source" => [{ "type" => "pdf", "content" => "http://www.example.com/CCSDS-123-0-B-1.pdf" }],
        }.to_yaml
      end
      let(:bib) { Relaton::Ccsds::Item.from_yaml yaml }

      before { subject }

      context "when new file" do
        it "doesn't add new link" do
          expect(bib.source.size).to eq(1)
        end
      end

      context "when new item have the same link type" do
        it "does not add new link" do
          data_fetcher.merge_links(bib, "spec/fixtures/ccsds_123_0-b-1.yaml")
          expect(bib.source.size).to eq(1)
        end
      end

      context "when new item have different link type" do
        let(:yaml) do
          {
            "docidentifier" => [{ "type" => "CCSDS", "id" => "CCSDS 123.0-B-1" }],
            "source" => [{ "type" => "doc", "content" => "http://www.example.com/CCSDS-123-0-B-1.pdf" }],
        }.to_yaml
        end

        it "adds another link" do
          data_fetcher.merge_links(bib, "spec/fixtures/ccsds_123_0-b-1.yaml")
          expect(bib.source.size).to eq(2)
        end
      end
    end

    context "#search_instance_translation" do
      it "instance" do
        docid = Relaton::Bib::Docidentifier.new(type: "CCSDS", content: "CCSDS 123.0-B-1")
        bib = Relaton::Ccsds::ItemData.new(docidentifier: [docid])
        expect(subject).to receive(:search_translations).with("CCSDS 123.0-B-1", bib)
        subject.search_instance_translation bib
      end

      it "translation" do
        docid = Relaton::Bib::Docidentifier.new(type: "CCSDS", content: "CCSDS 123.0-B-1 - French Translated")
        bib = Relaton::Ccsds::ItemData.new(docidentifier: [docid])
        expect(subject).to receive(:search_relations).with "CCSDS 123.0-B-1", bib
        subject.search_instance_translation bib
      end
    end

    context "#search_relations" do
      let(:bibid) { "CCSDS 123.0-B-1" }
      let(:docid) { Relaton::Bib::Docidentifier.new(type: "CCSDS", content: "CCSDS 123.0-B-1 -- Russian Translated") }
      let(:bib) { Relaton::Ccsds::ItemData.new(docidentifier: [docid]) }

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
        expect(subject.index).to receive(:search).and_yield(
          id: Pubid::Ccsds::Identifier.parse("CCSDS 123.0-B-1 - Russian Translated"),
          file: "file.yaml",
        )
        expect(subject).to receive(:create_instance_relation).with(bib, "file.yaml")
        subject.search_translations bibid, bib
      end

      it "not found" do
        bib = double(:bibitem, docidentifier: [double(id: bibid)])
        expect(subject.index).to receive(:search).and_yield(id: Pubid::Ccsds::Identifier.parse(bibid), file: "file.yaml")
        expect(subject).not_to receive(:create_instance_relation)
        subject.search_translations bibid, bib
      end
    end

    context "#create_relations" do
      let(:docid) { Relaton::Bib::Docidentifier.new(type: "CCSDS", content: "CCSDS 650.0-M-2") }
      let(:bib) { Relaton::Ccsds::ItemData.new(docidentifier: [docid]) }

      before do
        expect(File).to receive(:read).with("file.xml", encoding: "UTF-8").and_return inst_xml
        allow(File).to receive(:read).and_call_original
      end

      context "translation" do
        let(:inst_xml) do
          <<~XML
            <bibitem>
              <docidentifier type="CCSDS">CCSDS 650.0-M-2 - French Translated</docidentifier>
            </bibitem>
          XML
        end

        it do
          expect(File).to receive(:write).with("file.xml", /hasTranslation/, encoding: "UTF-8")
          subject.create_relations bib, "file.xml"
          expect(bib.relation[0].type).to eq "hasTranslation"
        end
      end

      context "instance of" do
        let(:inst_xml) do
          <<~XML
            <bibitem>
              <docidentifier type="CCSDS">CCSDS 650.0-M-2</docidentifier>
            </bibitem>
          XML
        end

        it do
          expect(File).to receive(:write).with("file.xml", /hasInstance/, encoding: "UTF-8")
          subject.create_relations bib, "file.xml"
          expect(bib.relation[0].type).to eq "instanceOf"
        end
      end
    end

    it "#create_instance_relation" do
      subject.instance_variable_set(:@format, "yaml")
      bib = Relaton::Ccsds::ItemData.new(docidentifier: [Relaton::Bib::Docidentifier.new(content: "CCSDS 123.0-B-1")])
      expect(File).to receive(:write).with("spec/fixtures/ccsds_123_0-b-1.yaml", /instanceOf/, encoding: "UTF-8")
      subject.create_instance_relation bib, "spec/fixtures/ccsds_123_0-b-1.yaml"
      expect(bib.relation[0]).to be_instance_of Relaton::Bib::Relation
    end

    it "#create_relation" do
      docid = Relaton::Bib::Docidentifier.new(type: "CCSDS", content: "CCSDS 123.0-B-1")
      bib = Relaton::Ccsds::ItemData.new(docidentifier: [docid])
      subject.create_relation bib, "hasInstance" do |rel|
        expect(rel).to be_instance_of Relaton::Bib::Relation
        expect(rel.type).to eq "hasInstance"
        expect(rel.bibitem).to be_instance_of Relaton::Bib::ItemData
        expect(rel.bibitem.docidentifier.first.content).to eq "CCSDS 123.0-B-1"
        expect(rel.bibitem.docidentifier.first.type).to eq "CCSDS"
        expect(rel.bibitem.formattedref).to eq "CCSDS 123.0-B-1"
      end
    end
  end
end
