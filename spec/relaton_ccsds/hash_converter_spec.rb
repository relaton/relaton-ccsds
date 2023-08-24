describe RelatonCcsds::HashConverter do
  it "returns CIE bibliographic item" do
    item = described_class.bib_item title: ["title"]
    expect(item).to be_instance_of RelatonCcsds::BibliographicItem
  end
end
