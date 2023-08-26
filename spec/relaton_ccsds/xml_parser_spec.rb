describe RelatonCcsds::XMLParser do
  it "parse XML" do
    xml = File.read "spec/fixtures/ccsds_230_2-g-1.xml", encoding: "UTF-8"
    bib = RelatonCcsds::XMLParser.from_xml xml
    expect(bib).to be_instance_of RelatonCcsds::BibliographicItem
    expect(bib.to_xml(bibdata: true)).to be_equivalent_to xml
  end
end
