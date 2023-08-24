describe RelatonCcsds::Bibliography do
  it ".searche" do
    hc = double "hit collection"
    expect(hc).to receive(:fetch).and_return :hits
    expect(RelatonCcsds::HitCollection).to receive(:new).with("CCSDS 121").and_return hc
    expect(described_class.search("CCSDS 121")).to eq :hits
  end

  it ".get" do
    expect(described_class).to receive(:search).with("CCSDS 121").and_return :hits
    expect(described_class.get("CCSDS 121")).to eq :hits
  end
end
