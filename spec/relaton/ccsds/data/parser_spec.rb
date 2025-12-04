require "relaton/ccsds/data/parser"

describe Relaton::Ccsds::DataParser do
  it ".initialize" do
    df = described_class.new :doc, :docs
    expect(df.instance_variable_get(:@doc)).to eq :doc
    expect(df.instance_variable_get(:@docs)).to eq :docs
  end

  context "instance methods" do
    let(:doc) { JSON.parse File.read "spec/fixtures/doc_with_iso.json" }
    let(:docs) { [doc] }
    let(:identifier) { "CCSDS 121.0-B-3" }
    subject { described_class.new doc, docs }

    context "#parse" do
      subject { described_class.new(doc, docs).parse }

      before { allow(Relaton::Ccsds::IsoReferences.instance).to receive(:[]).with("62314").and_return("ISO 15887") }

      it { is_expected.to be_a(Relaton::Ccsds::ItemData) }
      it { expect(subject.id).to eq("CCSDS1210B3") }
      it { expect(subject.docidentifier.first.content).to eq(identifier) }
      it { expect(subject.title.first.content).to eq("Lossless Data Compression") }
      it { expect(subject.ext.doctype.content).to eq("standard") }
      it { expect(subject.date.first.at.to_s).to eq("2020-08") }
      it { expect(subject.status.stage.content).to eq("published") }
      it { expect(subject.source.first.content.to_s).to eq("https://ccsds.org/publications/ccsdsallpubs/entry/3215/") }
      it { expect(subject.edition.content).to eq("3") }
      it { expect(subject.relation.first.bibitem.docidentifier.first.content).to eq("ISO 15887") }
      it { expect(subject.contributor[0].organization.subdivision[0].name[0].content).to eq("SLS-MHDC") }
      it { expect(subject.ext.technology_area).to eq("Space Link Services Area") }
    end

    it "#parse_title" do
      title = subject.parse_title
      expect(title).to be_instance_of Array
      expect(title.size).to eq 1
      expect(title.first).to be_instance_of Relaton::Bib::Title
      expect(title.first.content).to eq "Lossless Data Compression"
      expect(title.first.language).to eq "en"
      expect(title.first.script).to eq "Latn"
    end

    it "#parse_docidentifier" do
      docid = subject.parse_docidentifier
      expect(docid).to be_instance_of Array
      expect(docid.size).to eq 1
      expect(docid.first).to be_instance_of Relaton::Bib::Docidentifier
      expect(docid.first.content).to eq(identifier)
      expect(docid.first.type).to eq "CCSDS"
      expect(docid.first.primary).to be true
    end

    context "#docidentifier" do
      it "successor" do
        expect(subject.docidentifier).to eq identifier
      end

      context "predecessor" do
        let(:doc) { JSON.parse File.read "spec/fixtures/doc_predecessor.json" }
        it "remove -S from identifier" do
          subject.instance_variable_set :@successor, :doc
          expect(subject.docidentifier).to eq "CCSDS 713.5-B-1 Cor. 1"
        end
      end
    end

    it "#parse_abstract" do
      abstract = subject.parse_abstract
      expect(abstract).to be_instance_of Array
      expect(abstract.size).to eq 1
      expect(abstract.first).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
      expect(abstract.first.content).to include "The Recommended Standard"
      expect(abstract.first.language).to eq "en"
      expect(abstract.first.script).to eq "Latn"
    end

    it "#parse_doctype" do
      doctype = subject.parse_doctype
      expect(doctype).to be_instance_of Relaton::Ccsds::Doctype
      expect(doctype.content).to eq "standard"
    end

    it "#parse_date" do
      date = subject.parse_date
      expect(date).to be_instance_of Array
      expect(date.size).to eq 1
      expect(date.first).to be_instance_of Relaton::Bib::Date
      expect(date.first.type).to eq "published"
      expect(date.first.at.to_s).to eq "2020-08"
    end

    context "#parse_docstatus" do
      it "published" do
        status = subject.parse_status
        expect(status).to be_instance_of Relaton::Bib::Status
        expect(status.stage.content).to eq "published"
      end

      it "withdrawn" do
        subject.instance_variable_set :@successor, :doc
        expect(subject.parse_status.stage.content).to eq "withdrawn"
      end
    end

    it "#parse_source" do
      source = subject.parse_source
      expect(source).to be_instance_of Array
      expect(source.size).to eq 2
      expect(source[0]).to be_instance_of Relaton::Bib::Uri
      expect(source[0].type).to eq "src"
      expect(source[0].content.to_s).to eq "https://ccsds.org/publications/ccsdsallpubs/entry/3215/"
      expect(source[1].type).to eq "pdf"
      expect(source[1].content.to_s).to eq "https://ccsds.org/wp-content/uploads/gravity_forms/5-448e85c647331d9cbaf66c096458bdd5/2025/01//121x0b3.pdf"
    end

    context "#parse_edition" do
      let(:doc) { JSON.parse File.read "spec/fixtures/doc_edition_of.json" }
      it do
        expect(subject.parse_edition.content).to eq "2"
      end
    end

    context "#parse_relation" do
      let(:doc) { JSON.parse File.read "spec/fixtures/doc_has_edition.json" }
      let(:docs) do
        doc_edition_of = JSON.parse File.read "spec/fixtures/doc_edition_of.json"
        [doc, doc_edition_of]
      end

      it do
        expect(Relaton::Ccsds::IsoReferences.instance).to receive(:[]).with("62319").and_return("ISO 18381")
        relation = subject.parse_relation
        expect(relation).to be_instance_of Array
        expect(relation.size).to eq 2
        expect(relation[0]).to be_instance_of Relaton::Bib::Relation
        expect(relation[0].type).to eq "adoptedAs"
        expect(relation[0].bibitem.docidentifier[0].content).to eq "ISO 18381"
        expect(relation[1]).to be_instance_of Relaton::Bib::Relation
        expect(relation[1].type).to eq "updatedBy"
        expect(relation[1].bibitem.docidentifier[0].content).to eq "CCSDS 123.0-B-2 Cor. 2"
      end
    end

    context "#adopted" do
      it do
        expect(Relaton::Ccsds::IsoReferences.instance).to receive(:[]).with("62314").and_return("ISO 15887")
        relation = subject.adopted
        expect(relation).to be_instance_of Array
        expect(relation.size).to eq 1
        expect(relation[0]).to be_instance_of Relaton::Bib::Relation
        expect(relation[0].type).to eq "adoptedAs"
        expect(relation[0].bibitem.docidentifier[0].content).to eq "ISO 15887"
      end
    end

    context "#successors" do
      it "doesn't have successor" do
        expect(subject.successors).to eq []
      end

      it "has successor" do
        docid = Relaton::Bib::Docidentifier.new content: "CCSDS 121.0-B-3"
        successor = Relaton::Ccsds::ItemData.new docidentifier: [docid]
        subject.instance_variable_set :@successor, successor
        expect(subject.successors[0].bibitem.docidentifier[0].content).to eq "CCSDS 121.0-B-3"
        expect(subject.successors[0].type).to eq "hasSuccessor"
      end
    end

    context "#relation_type" do
      context "hasEdition" do
        let(:doc) { JSON.parse File.read "spec/fixtures/doc_has_edition.json" }
        let(:docs) do
          doc_edition_of = JSON.parse File.read "spec/fixtures/doc_edition_of.json"
          [doc, doc_edition_of]
        end

        it { expect(subject.relation_type(subject.parse_identifier(doc[2]))).to be_nil }
        it { expect(subject.relation_type(subject.parse_identifier(docs[1][2]))).to eq "updatedBy" }
      end

      context "editionOf" do
        let(:doc) { JSON.parse File.read "spec/fixtures/doc_edition_of.json" }
        let(:docs) do
          doc_has_edition = JSON.parse File.read "spec/fixtures/doc_has_edition.json"
          [doc, doc_has_edition]
        end

        it { expect(subject.relation_type(subject.parse_identifier(docs[1][2]))).to eq "updates" }
      end

      it "one ID is translation" do
        allow(subject).to receive(:docidentifier).and_return("CCSDS 650.0-B-1-S")
        expect(subject.relation_type("CCSDS 650.0-B-1-S - French Translated")).to be_nil
      end

      it "both IDs are translations" do
        expect(subject).to receive(:docidentifier).and_return("CCSDS 650.0-B-1 - French Translated").exactly(3).times
        expect(subject.relation_type("CCSDS 650.0-B-1-S - French Translated")).to eq "updatedBy"
      end
    end

    context "#parse_contributor" do
      it do
        contrib = subject.parse_contributor
        expect(contrib).to be_instance_of Array
        expect(contrib[0]).to be_instance_of Relaton::Bib::Contributor
        expect(contrib[0].role[0]).to be_instance_of Relaton::Bib::Contributor::Role
        expect(contrib[0].role[0].type).to eq "author"
        expect(contrib[0].role[0].description[0]).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
        expect(contrib[0].role[0].description[0].content).to eq "committee"
        expect(contrib[0].organization).to be_instance_of Relaton::Bib::Organization
        expect(contrib[0].organization.name[0].content).to eq "CCSDS"
        expect(contrib[0].organization.subdivision[0]).to be_instance_of Relaton::Bib::Subdivision
        expect(contrib[0].organization.subdivision[0].type).to eq "technical-committee"
        expect(contrib[0].organization.subdivision[0].name[0].content).to eq "SLS-MHDC"
      end
    end

    context "#parse_technology_area" do
      it do
        expect(subject.parse_technology_area).to eq "Space Link Services Area"
      end

      it "has no technology area" do
        doc = subject.instance_variable_get :@doc
        doc[8] = nil
        expect(subject.parse_technology_area).to be_nil
      end
    end
  end
end
