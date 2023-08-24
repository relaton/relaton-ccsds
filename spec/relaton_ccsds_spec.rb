# frozen_string_literal: true

RSpec.describe Relaton::Ccsds do
  it "has a version number" do
    expect(Relaton::Ccsds::VERSION).not_to be nil
  end

  it "returns grammar hash" do
    hash = RelatonCcsds.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end
end
