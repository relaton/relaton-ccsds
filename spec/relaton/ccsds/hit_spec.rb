describe Relaton::Ccsds::Hit do
  subject { Relaton::Ccsds::Hit.new({ code: :id, url: :url }) }

  it "initialize" do
    expect(subject.hit[:code]).to eq :id
    expect(subject.hit[:url]).to eq :url
  end

  context "#item" do
    let(:agent) { double "agent" }
    before { expect(Mechanize).to receive(:new).and_return agent }

    it "success" do
      resp = double "response", body: "--- {}\n"
      expect(agent).to receive(:get).with(:url).and_return resp
      expect(subject.item).to be_instance_of Relaton::Ccsds::ItemData
      expect(subject.item.fetched).to eq Date.today.to_s
    end

    it "raise RelatonBib::RequestError" do
      expect(agent).to receive(:get).with(:url).and_raise Mechanize::Error.new(:response)
      expect { subject.item }.to raise_error Relaton::RequestError
    end
  end
end
