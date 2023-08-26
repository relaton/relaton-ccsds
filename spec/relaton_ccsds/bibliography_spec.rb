describe RelatonCcsds::Bibliography do
  before do
    RelatonCcsds.instance_variable_set(:@configuration, nil)
  end

  it ".searche" do
    hc = double "hit collection"
    expect(hc).to receive(:fetch).and_return :hits
    expect(RelatonCcsds::HitCollection).to receive(:new).with("CCSDS 121").and_return hc
    expect(described_class.search("CCSDS 121")).to eq :hits
  end

  context ".get" do
    it "success" do
      hit = double "hit", code: "CCSDS 121", doc: :doc
      expect(described_class).to receive(:search).with("CCSDS 121").and_return [hit]
      expect do
        expect(described_class.get("CCSDS 121")).to eq :doc
      end.to output(/\(CCSDS 121\) found `CCSDS 121`/).to_stderr
    end

    it "not found" do
      expect(described_class).to receive(:search).with("CCSDS 121").and_return []
      expect do
        expect(described_class.get("CCSDS 121")).to be_nil
      end.to output(/\(CCSDS 121\) not found/).to_stderr
    end

    it "doc by code", vcr: "ccsds_230_2-g-1" do
      doc = described_class.get "CCSDS 230.2-G-1"
      xml = doc.to_xml bibdata: true
      file = "spec/fixtures/ccsds_230_2-g-1.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
    end
  end
end
