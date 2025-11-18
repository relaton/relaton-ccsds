describe Relaton::Ccsds::Hit do
  subject { Relaton::Ccsds::Hit.new(code: :id, url: :url) }

  it "initialize" do
    expect(subject.code).to eq :id
    expect(subject.instance_variable_get(:@url)).to eq :url
  end

  context "#doc" do
    let(:agent) { double "agent" }
    before { expect(Mechanize).to receive(:new).and_return agent }

    it "success" do
      resp = double "response", body: "--- {}\n"
      expect(agent).to receive(:get).with(:url).and_return resp
      hash = { "fetched" => Date.today.to_s }
      expect(Relaton::Ccsds::BibliographicItem).to receive(:from_hash).with(hash).and_return :item
      expect(subject.doc).to eq :item
    end

    it "raise RelatonBib::RequestError" do
      expect(agent).to receive(:get).with(:url).and_raise Mechanize::Error.new(:response)
      expect { subject.doc }.to raise_error Relaton::RequestError
    end
  end
end
