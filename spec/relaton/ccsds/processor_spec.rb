require "relaton/ccsds/processor"

describe Relaton::Ccsds::Processor do
  it { expect(subject.short).to eq :relaton_ccsds }
  it { expect(subject.prefix).to eq "CCSDS" }
  it { expect(subject.defaultprefix).to eq %r{^CCSDS(?!\w)} }
  it { expect(subject.idtype).to eq "CCSDS" }
  it { expect(subject.datasets).to eq %w[ccsds] }

  context "#get" do
    it "calls Bibliography.get" do
      require "relaton/ccsds/bibliography"
      expect(Relaton::Ccsds::Bibliography).to receive(:get).with("code", "date", { foo: :bar })
      subject.get("code", "date", foo: :bar)
    end
  end

  context "#fetch_data" do
    it "calls DataFetcher.fetch" do
      require "relaton/ccsds/data/fetcher"
      expect(Relaton::Ccsds::DataFetcher).to receive(:fetch).with("ccsds", output: "dir", format: "xml")
      subject.fetch_data("ccsds", output: "dir", format: "xml")
    end
  end

  context "#from_xml" do
    it "calls Item.from_xml" do
      item = subject.from_xml("<bibitem></bibitemI>")
      expect(item).to be_instance_of Relaton::Ccsds::ItemData
    end
  end

  context "#from_yaml" do
    it "calls Item.from_yaml" do
      item = subject.from_yaml("---\nbibitem: {}\n")
      expect(item).to be_instance_of Relaton::Ccsds::ItemData
    end
  end

  it "#grammar_hash" do
    require "relaton/ccsds"
    expect(subject.grammar_hash.size).to eq 32
  end

  it "#remove_index_file" do
    require "relaton/index"
    index = instance_double(Relaton::Index::Type)
    expect(Relaton::Index).to receive(:find_or_create)
      .with(:ccsds, url: true, file: Relaton::Ccsds::INDEX_FILE).and_return(index)
    expect(index).to receive(:remove_file)
    subject.remove_index_file
  end
end
