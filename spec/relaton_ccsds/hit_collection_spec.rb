describe RelatonCcsds::HitCollection do
  subject { RelatonCcsds::HitCollection.new("CCSDS 123") }

  it "#index" do
    url = "https://raw.githubusercontent.com/relaton/relaton-data-ccsds/main/index-v1.zip"
    expect(Relaton::Index).to receive(:find_or_create).with(:ccsds, url: url, file: "index-v1.yaml").and_return :index
    expect(subject.index).to eq :index
  end

  context "#fetch" do
    it "success" do
      index = double "index"
      row = { id: "CCSDS 123", file: "file.yaml" }
      expect(index).to receive(:search).with("CCSDS 123").and_return [row]
      expect(subject).to receive(:index).and_return index
      url = "https://raw.githubusercontent.com/relaton/relaton-data-ccsds/main/file.yaml"
      expect(RelatonCcsds::Hit).to receive(:new).with(code: "CCSDS 123", url: url).and_return :hit
      expect(subject.fetch).to be_instance_of RelatonCcsds::HitCollection
      expect(subject.first).to eq :hit
    end

    it "raise RelatonBib::RequestError" do
      expect(subject).to receive(:index).and_raise OpenURI::HTTPError.new("error", nil)
      expect { subject.fetch }.to raise_error RelatonBib::RequestError
    end
  end
end
