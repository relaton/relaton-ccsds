require "relaton/ccsds/bibliography"

describe Relaton::Ccsds::Bibliography do
  # integration test
  context "#get" do
    it "returns correct xml", vcr: "ccsds_230_2-g-1" do
      doc = described_class.get "CCSDS 230.2-G-1"
      xml = doc.to_xml bibdata: true
      file = "spec/fixtures/ccsds_230_2-g-1.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
    end
  end
end

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

module Relaton::Ccsds::TestBibliography
  include Relaton::Ccsds::Bibliography
  extend self
  def search(ref)
    hit_collection = Relaton::Ccsds::TestHitCollection.new(ref)
    hit_collection.add_to_index(Pubid::Ccsds::Identifier.parse("CCSDS 230.2-G-1"), "data/CCSDS-230-2-G-1.yaml")
    hit_collection.add_to_index(Pubid::Ccsds::Identifier.parse("CCSDS 720.4-Y-1"), "data/CCSDS-720-4-Y-1.yaml")
    hit_collection.add_to_index(Pubid::Ccsds::Identifier.parse("CCSDS 650.0-M-2"), "data/CCSDS-650-0-M-2.yaml")
    hit_collection.add_to_index(Pubid::Ccsds::Identifier.parse("CCSDS 650.0-M-2 - French Translated"), "data/CCSDS-650-0-M-2-French-Translated.yaml")

    hit_collection.fetch
  end
end

describe Relaton::Ccsds::TestBibliography do
  before do
    # Force to download index file
    allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
    allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
  end

  context ".get", vcr: "ccsds_230_2-g-1" do
    it "success" do
      expect do
        item = described_class.get("CCSDS 230.2-G-1")
        expect(item.docidentifier[0].content).to eq "CCSDS 230.2-G-1"
      end.to output(/\[relaton-ccsds\] INFO: \(CCSDS 230\.2-G-1\) Found: `CCSDS 230\.2-G-1`/).to_stderr_from_any_process
    end

    it "not found" do
      expect(described_class).to receive(:search).with("CCSDS 121").and_return []
      expect do
        expect(described_class.get("CCSDS 121")).to be_nil
      end.to output(/\[relaton-ccsds\] INFO: \(CCSDS 121\) Not found\./).to_stderr_from_any_process
    end

    it "doc by code", vcr: "ccsds_230_2-g-1" do
      doc = described_class.get "CCSDS 230.2-G-1"
      xml = doc.to_xml bibdata: true
      file = "spec/fixtures/ccsds_230_2-g-1.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
    end

    it "translated doc by code", vcr: "ccsds_650_0-m-2_french_translated" do
      doc = described_class.get "CCSDS 650.0-M-2 - French Translated"
      xml = doc.to_xml bibdata: true
      file = "spec/fixtures/ccsds_650_0-m-2_french_translated.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
    end

    context "doc by code with format" do
      xit "success", vcr: "ccsds_720_4-y-1" do
        doc = described_class.get "CCSDS 720.4-Y-1 (DOC)"
        expect(doc.source.size).to be 1
        expect(doc.source.first.type).to eq "doc"
      end

      xit "not found", vcr: "ccsds_230_2-g-1" do
        doc = described_class.get "CCSDS 230.2-G-1 (DOC)"
        expect(doc).to be_nil
      end
    end
  end
end
