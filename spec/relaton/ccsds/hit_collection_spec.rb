require "relaton/ccsds/hit_collection"

class Relaton::Ccsds::TestHitCollection < Relaton::Ccsds::HitCollection
  # override default index method to avoid index downloading
  def index
    @index ||= Relaton::Index.find_or_create :ccsds, file: "index-v2.yaml"
  end

  # method to be able to add index rows from test's context
  def add_to_index(id, file)
    index.add_or_update(id, file)
  end
end

describe Relaton::Ccsds::HitCollection do
  before { index_rows.each { |k, v| subject.add_to_index(Pubid::Ccsds::Identifier.parse(k.to_s) ,v) } }

  let(:index_rows) do
    { "CCSDS 103.0-B-1": "data/CCSDS-103.0-B-1.xml",
      "CCSDS 103.0-B-2": "data/CCSDS-103.0-B-2.xml" }
  end

  subject { Relaton::Ccsds::TestHitCollection.new(id) }

  context "#fetch" do
    before { subject.fetch }

    let(:id) { "CCSDS 103.0-B-2" }

    it "returns matching hit" do
      expect(subject[0].hit[:code]).to eq(Pubid::Ccsds::Identifier.parse(id))
    end

    context "when reference without edition" do
      let(:match_identifiers) { ["CCSDS 103.0-B-1", "CCSDS 103.0-B-2"] }
      let(:id) { "CCSDS 103.0-B" }

      it "returns identifiers related to reference" do
        expect(subject.map { _1.hit[:code] }.map(&:to_s)).to eq(match_identifiers)
      end
    end

    # implementation testing, do we need this?
    context "when HTTP error occurs" do
      it "raise RelatonBib::RequestError" do
        expect(subject).to receive(:index).and_raise OpenURI::HTTPError.new("error", nil)
        expect { subject.fetch }.to raise_error Relaton::RequestError
      end
    end
  end
end
