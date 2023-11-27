describe RelatonCcsds::BibliographicItem do
  context "initialize" do
    it "set technology area" do
      bib = described_class.new title: [title: "title"], technology_area: "SLS"
      expect(bib.technology_area).to eq "SLS"
    end
  end

  context "instance methods" do
    context "#to_xml" do
      context "creates ext element" do
        it "with doctype" do
          item = described_class.new title: [title: "title"], doctype: RelatonCcsds::DocumentType.new(type: "record")
          xml = item.to_xml bibdata: true
          expect(xml).to include "<ext>"
          expect(xml).to include "<doctype>record</doctype>"
        end

        it "with no technology area" do
          item = described_class.new title: [title: "title"], technology_area: "SLS"
          xml = item.to_xml bibdata: true
          expect(xml).to include "<ext>"
          expect(xml).to include "<technology-area>SLS</technology-area>"
        end
      end

      it "don't create ext element" do
        item = described_class.new title: [title: "title"]
        expect(item.to_xml(bibdata: true)).not_to include "<ext>"
      end
    end

    context "#to_hash" do
      it "creates ext element" do
        item = described_class.new title: [title: "title"], technology_area: "SLS"
        expect(item.to_hash["ext"]["technology_area"]).to eq "SLS"
      end

      it "don't create ext element" do
        item = described_class.new title: [title: "title"]
        expect(item.to_hash).not_to have_key "ext"
      end

      it "render doc" do
        hash = YAML.load_file "spec/fixtures/ccsds_230_2-g-1.yaml"
        bib  = RelatonCcsds::BibliographicItem.from_hash hash
        expect(bib.to_hash).to eq hash
      end
    end
  end
end
