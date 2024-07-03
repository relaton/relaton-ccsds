describe RelatonCcsds::Bibliography do
  before do
    # Force to download index file
    allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
    allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
  end

  it ".searche" do
    hc = double "hit collection"
    expect(hc).to receive(:fetch).and_return :hits
    expect(RelatonCcsds::HitCollection).to receive(:new).with("CCSDS 121").and_return hc
    expect(described_class.search("CCSDS 121")).to eq :hits
  end

  context ".get" do
    it "success" do
      doc = double "doc", to_format: :doc
      hit = double "hit", code: "CCSDS 121", doc: doc
      expect(described_class).to receive(:search).with("CCSDS 121").and_return [hit]
      expect do
        expect(described_class.get("CCSDS 121")).to eq :doc
      end.to output(/\[relaton-ccsds\] INFO: \(CCSDS 121\) Found: `CCSDS 121`/).to_stderr_from_any_process
    end

    it "not found" do
      expect(described_class).to receive(:search).with("CCSDS 121").and_return []
      expect do
        expect(described_class.get("CCSDS 121")).to be_nil
      end.to output(/\[relaton-ccsds\] INFO: \(CCSDS 121\) Not found\./).to_stderr_from_any_process
    end

    it "doc by code", vcr: "ccsds_230_2-g-1" do
      doc = described_class.get "CCSDS 230.2-G-1"
      xml = doc.to_xml bibdata: true
      file = "spec/fixtures/ccsds_230_2-g-1.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
    end

    it "translated doc by code", vcr: "ccsds_650_0-m-2_french_translated" do
      doc = described_class.get "CCSDS 650.0-M-2 - French Translated"
      xml = doc.to_xml bibdata: true
      file = "spec/fixtures/ccsds_650_0-m-2_french_translated.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
    end

    context "doc by code with format" do
      it "success", vcr: "ccsds_720_4-y-1" do
        doc = described_class.get "CCSDS 720.4-Y-1 (DOC)"
        expect(doc.link.size).to be 1
        expect(doc.link.first.type).to eq "doc"
      end

      it "not found", vcr: "ccsds_230_2-g-1" do
        doc = described_class.get "CCSDS 230.2-G-1 (DOC)"
        expect(doc).to be_nil
      end
    end
  end
end
