describe RelatonCcsds::DataFetcher do
  # let(:data_fetcher) { RelatonCcsds::DataFetcher.new "data", "bibxml" }
  let(:data_fetcher) { RelatonCcsds::DataFetcher.new @output_dir, format }
  before(:all) { @output_dir = Dir.mktmpdir }

  after(:all) { FileUtils.remove_entry_secure(@output_dir) }

  subject { data_fetcher }
  let(:identifier) { "CCSDS 123.0-B-1" }
  let(:bib) { RelatonCcsds::BibliographicItem.new(docid: [RelatonBib::DocumentIdentifier.new(id: identifier)]) }
  let(:format) { "bibxml" }

  describe "#parse" do
    subject { data_fetcher.parse(doc) }
    let(:doc) { JSON.parse File.read "spec/fixtures/doc_with_iso.json" }
    let(:identifier) { "CCSDS 121.0-B-3" }

    it "returns bib object" do
      expect(subject.docidentifier.first.id).to eq(identifier)
    end

    context "document with relations" do
      let(:doc) { JSON.parse File.read "spec/fixtures/doc_has_edition.json" }
      let(:doc_edition_of) { JSON.parse File.read "spec/fixtures/doc_edition_of.json" }

      before do
        data_fetcher.docs = [doc, doc_edition_of]
      end

      it "has adoptedAs relation" do
        expect(subject.relation.map { |r| [r.type, r.bibitem.docidentifier.first.id] })
          .to include(["adoptedAs", "ISO 18381"])
      end

      it "updated by corrigenda" do
        expect(subject.relation.map { |r| [r.type, r.bibitem.docidentifier.first.id] })
          .to include(["updatedBy", "CCSDS 123.0-B-2 Cor. 2"])
      end
    end
  end

  context "#fetch" do
    it "fetches data" do
      expect(FileUtils).to receive(:mkdir_p).with("data")
      df = double(:datafetcher)
      expect(df).to receive(:fetch)
      expect(described_class).to receive(:new).with("data", "yaml").and_return df
      described_class.fetch
    end
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
      expect(subject).to receive(:parse_and_save).with("doc", false)
      subject.fetch_docs :url
    end

    context "#parse_and_save" do
      subject { data_fetcher.parse_and_save(doc, retired) }
      let(:retired) { false }
      let(:format) { "bibxml" }
      let(:doc) { JSON.parse File.read "spec/fixtures/doc_with_iso.json" }

      context "when format yaml" do
        before { subject }
        let(:format) { "yaml" }

        it "saves parsed data in correct format" do
          result = File.read("#{@output_dir}/CCSDS-121-0-B-3.yaml")
          expect(result).to eq(File.read("spec/fixtures/CCSDS-121-0-B-3.yaml"))
        end

        it "adds file to index" do
          expect(data_fetcher.index.index).to include(
            { id: "CCSDS 121.0-B-3", file: "#{@output_dir}/CCSDS-121-0-B-3.yaml" })

        end

        it "stores yaml files" do
          expect(File.read "#{@output_dir}/CCSDS-121-0-B-3.yaml").to eq(File.read("spec/fixtures/CCSDS-121-0-B-3.yaml"))
        end

        context "when translation" do
          let(:doc) { JSON.parse File.read("spec/fixtures/ccsds_551_1-O-2_russian_translated.json") }
          let(:retired) { false }

          it "stores identifier" do
            expect(data_fetcher.index.index).to include(
              { id: "CCSDS 551.1-O-2 - Russian Translated", file: "#{@output_dir}/CCSDS-551-1-O-2-Russian-Translated.yaml" })
          end

          it "stores yaml files" do
            expect(File.read "#{@output_dir}/CCSDS-551-1-O-2-Russian-Translated.yaml").to eq(File.read("spec/fixtures/CCSDS-551-1-O-2-Russian-Translated.yaml"))
          end

          context "when file already exists and indexed" do
            # run #parse_and_save to create file and add to index
            before { data_fetcher.parse_and_save(doc, retired) }

            it "stores yaml files" do
              expect(File.read "#{@output_dir}/CCSDS-551-1-O-2-Russian-Translated.yaml").to eq(File.read("spec/fixtures/CCSDS-551-1-O-2-Russian-Translated.yaml"))
            end
          end

          context "when there are related identifiers" do
            let(:original_related_doc_file) { "spec/fixtures/CCSDS-551-1-O-2.yaml" }
            let(:related_doc_file) { "#{@output_dir}/CCSDS-551-1-O-2.yaml" }

            before do
              FileUtils.cp(original_related_doc_file, related_doc_file)
              # add file to index
              data_fetcher.index.add_or_update(data_fetcher.class.get_identifier_class.parse("CCSDS 551.1-O-2"), related_doc_file)
              data_fetcher.parse_and_save(doc, retired)
            end

            it "stores yaml files" do
              expect(File.read "#{@output_dir}/CCSDS-551-1-O-2-Russian-Translated.yaml").to eq(File.read("spec/fixtures/CCSDS-551-1-O-2-Russian-Translated.yaml"))
            end
          end
        end

        context "when have related translation in index" do
          let(:doc) { JSON.parse File.read("spec/fixtures/ccsds_551_1-O-2.json") }
          let(:retired) { false }
          let(:original_translated_file) { "spec/fixtures/CCSDS-551-1-O-2-Russian-Translated-without-relation.yaml" }
          let(:original_translated_file_with_relation) { "spec/fixtures/CCSDS-551-1-O-2-Russian-Translated.yaml" }
          let(:translated_file) { "#{@output_dir}/CCSDS-551-1-O-2-Russian-Translated.yaml" }

          before do
            FileUtils.cp(original_translated_file, translated_file)
            # add file to index
            data_fetcher.index.add_or_update(data_fetcher.class.get_identifier_class.parse("CCSDS 551.1-O-2 - Russian Translated"), translated_file)
            data_fetcher.parse_and_save(doc, retired)
          end

          it "adds relation to translated document" do
            expect(File.read(translated_file)).to eq(File.read(original_translated_file_with_relation))
          end

          context "when relation already added" do
            let(:original_translated_file) { "spec/fixtures/CCSDS-551-1-O-2-Russian-Translated.yaml" }

            it "don't add relation again" do
              expect(File.read(translated_file)).to eq(File.read(original_translated_file))
            end
          end
        end

        context "when retired true" do
          let(:doc) { JSON.parse File.read "spec/fixtures/doc_retired.json" }
          let(:retired) { true }

          it "stores successor" do
            expect(data_fetcher.index.index).to include(
              { id: "CCSDS 211.0-B-5", file: "#{@output_dir}/CCSDS-211-0-B-5.yaml" })
          end

          it "stores predecessor" do
            expect(data_fetcher.index.index).to include(
              { id: "CCSDS 211.0-B-5-S", file: "#{@output_dir}/CCSDS-211-0-B-5-S.yaml" })
          end

          it "creates relation to predecessor" do
            expect(subject.relation.select { |r| r.type == "hasSuccessor" }.first.bibitem.docidentifier.first.id)
              .to eq("CCSDS 211.0-B-5-S")
          end

          it "stores yaml files" do
            expect(File.read "#{@output_dir}/CCSDS-211-0-B-5.yaml").to eq(File.read("spec/fixtures/CCSDS-211-0-B-5.yaml"))
            expect(File.read "#{@output_dir}/CCSDS-211-0-B-5-S.yaml").to eq(File.read("spec/fixtures/CCSDS-211-0-B-5-S.yaml"))
          end
        end

      end

      context "when document identifier is wrong" do
        let(:doc) { JSON.parse File.read "spec/fixtures/doc_with_wrong_id.json" }

        it "prints error instead of raising an exception" do
          expect { subject }.to output(/^Failed to save/).to_stdout
        end
      end

      context "when format bibxml" do
        let(:format) { "bibxml" }
        # use retired true to invoke merge_links
        let(:retired) { true }

        it "cannot merge links when format is not yaml" do
          expect { subject }.to raise_error(RelatonCcsds::Errors::TypeError)
        end
      end
    end

    describe "#get_output_file" do
      subject { data_fetcher.get_output_file(bib) }

      it { is_expected.to eq("#{@output_dir}/CCSDS-123-0-B-1.xml") }
    end

    context "#save_bib" do
      # let(:bib) { double(:bibitem, docidentifier: [double(id: identifier)]) }
      let(:bib) { RelatonCcsds::BibliographicItem.new(docid: [RelatonBib::DocumentIdentifier.new(id: identifier)]) }
      let(:id) { Pubid::Ccsds::Identifier.parse(identifier) }
      let(:format) { "yaml" }
      subject { data_fetcher.save_bib(bib) }

      context "when have related translations" do
        before do
          # copy original file to avoid modifications
          FileUtils.cp(original_translated_file, translated_file)
          data_fetcher.index.add_or_update(
            Pubid::Ccsds::Identifier.parse(translated_identifier), translated_file)
        end

        let(:translated_identifier) { "#{identifier} - Russian Translated" }
        let(:original_translated_file) { "spec/fixtures/ccsds_123_0-b-1_russian_translated.yaml" }
        let(:original_translated_file_with_relation) { "spec/fixtures/ccsds_123_0-b-1_russian_translated_with_relation.yaml" }
        let(:translated_file) { "#{@output_dir}/ccsds_123_0-b-1_russian_translated.yaml" }

        it "adds identifier with translation to identifier's relation" do
          subject
          expect(bib.relation.first.bibitem.docidentifier.first.id).to eq(translated_identifier)
        end

        it "updates original file with relation" do
          subject
          expect(File.read(translated_file)).to eq(File.read(original_translated_file_with_relation))
        end
      end

      context "when identifier is translation" do
        before do
          # copy original file to avoid modifications
          FileUtils.cp(original_file_without_translation, file_without_translation)
          data_fetcher.index.add_or_update(
            Pubid::Ccsds::Identifier.parse(identifier_without_translation), file_without_translation)
        end

        let(:identifier) { "CCSDS 123.0-B-1 - Russian Translated" }
        let(:original_file_without_translation) { "spec/fixtures/ccsds_123_0-b-1.yaml" }
        let(:file_without_translation) { "#{@output_dir}/ccsds_123_0-b-1.yaml" }
        let(:identifier_without_translation) { "CCSDS 123.0-B-1" }

        it "adds identifier without translation to identifier's relation" do
          subject
          expect(bib.relation.first.bibitem.docidentifier.first.id).to eq(identifier_without_translation)
        end
      end
    end

    context "#content" do
      let(:bib) { double(:bibitem) }

      it "bibxml" do
        expect(bib).to receive(:send).with("to_bibxml").and_return :bibxml
        expect(subject.serialize(bib)).to eq :bibxml
      end

      it "yaml" do
        subject.instance_variable_set(:@format, "yaml")
        expect(bib).to receive(:to_hash).and_return "id" => "CCSDS 123.0-B-1"
        expect(subject.serialize(bib)).to eq "---\nid: CCSDS 123.0-B-1\n"
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
        expect(subject.serialize(bib)).to eq :xml
      end
    end

    describe "#merge_links" do
      # skip merging when new file
      let(:format) { "yaml" }
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
      expect(subject).to receive(:serialize).with(inst).and_return :content
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
