describe RelatonCcsds::DataParser do
  it ".initialize" do
    df = RelatonCcsds::DataParser.new :doc, :docs
    expect(df.instance_variable_get(:@doc)).to eq :doc
    expect(df.instance_variable_get(:@docs)).to eq :docs
  end

  context "instance methods" do
    let(:doc) { JSON.parse File.read "spec/fixtures/doc_with_iso.json" }
    let(:docs) { [doc] }
    subject { RelatonCcsds::DataParser.new doc, docs }

    it "#parse" do
      expect(subject).to receive(:parse_title).and_return :title
      expect(subject).to receive(:parse_docid).and_return :docid
      expect(subject).to receive(:parse_abstract).and_return :abstract
      expect(subject).to receive(:parse_doctype).and_return :doctype
      expect(subject).to receive(:parse_date).and_return :date
      expect(subject).to receive(:parse_docstatus).and_return :docstatus
      expect(subject).to receive(:parse_link).and_return :link
      expect(subject).to receive(:parse_edition).and_return :edition
      expect(subject).to receive(:parse_relation).and_return :relation
      expect(subject).to receive(:parse_editorialgroup).and_return :editorialgroup
      expect(subject).to receive(:parse_technology_area).and_return :technology_area
      expect(RelatonCcsds::BibliographicItem).to receive(:new).with(
        title: :title, docid: :docid, abstract: :abstract, doctype: :doctype, date: :date,
        docstatus: :docstatus, link: :link, edition: :edition, relation: :relation,
        editorialgroup: :editorialgroup, technology_area: :technology_area
      ).and_return :bibitem
      expect(subject.parse).to eq :bibitem
    end

    it "#parse_title" do
      title = subject.parse_title
      expect(title).to be_instance_of Array
      expect(title.size).to eq 1
      expect(title.first).to be_instance_of RelatonBib::TypedTitleString
      expect(title.first.title.content).to eq "Lossless Data Compression"
      expect(title.first.title.language).to eq ["en"]
      expect(title.first.title.script).to eq ["Latn"]
    end

    it "#parse_docid" do
      docid = subject.parse_docid
      expect(docid).to be_instance_of Array
      expect(docid.size).to eq 1
      expect(docid.first).to be_instance_of RelatonBib::DocumentIdentifier
      expect(docid.first.id).to eq "CCSDS 121.0-B-3"
      expect(docid.first.type).to eq "CCSDS"
      expect(docid.first.primary).to be true
    end

    context "#docidentifier" do
      it "successor" do
        expect(subject.docidentifier).to eq "CCSDS 121.0-B-3"
      end

      it "predecessor" do
        subject.instance_variable_set :@successor, :doc
        doc = subject.instance_variable_get :@doc
        doc["Document_x0020_Number"] = "CCSDS 713.5-B-1-S Cor. 1"
        expect(subject.docidentifier).to eq "CCSDS 713.5-B-1 Cor. 1"
      end
    end

    it "#parse_abstract" do
      abstract = subject.parse_abstract
      expect(abstract).to be_instance_of Array
      expect(abstract.size).to eq 1
      expect(abstract.first).to be_instance_of RelatonBib::FormattedString
      expect(abstract.first.content).to include "The Recommended Standard"
      expect(abstract.first.language).to eq ["en"]
      expect(abstract.first.script).to eq ["Latn"]
    end

    it "#parse_doctype" do
      expect(subject.parse_doctype).to eq "standard"
    end

    it "#parse_date" do
      date = subject.parse_date
      expect(date).to be_instance_of Array
      expect(date.size).to eq 1
      expect(date.first).to be_instance_of RelatonBib::BibliographicDate
      expect(date.first.type).to eq "published"
      expect(date.first.on).to eq "2020-08"
    end

    context "#parse_docstatus" do
      it "published" do
        status = subject.parse_docstatus
        expect(status).to be_instance_of RelatonBib::DocumentStatus
        expect(status.stage.value).to eq "published"
      end

      it "withdrawn" do
        subject.instance_variable_set :@successor, :doc
        expect(subject.parse_docstatus.stage.value).to eq "withdrawn"
      end
    end

    it "#parse_link" do
      link = subject.parse_link
      expect(link).to be_instance_of Array
      expect(link.size).to eq 1
      expect(link.first).to be_instance_of RelatonBib::TypedUri
      expect(link.first.type).to eq "pdf"
      expect(link.first.content.to_s).to eq "https://public.ccsds.org/Pubs/121x0b3.pdf"
    end

    it "#parse_edition" do
      expect(subject.parse_edition).to eq "3"
    end

    context "#parse_relation" do
      let(:doc) { JSON.parse File.read "spec/fixtures/doc_has_edition.json" }
      let(:docs) do
        doc_edition_of = JSON.parse File.read "spec/fixtures/doc_edition_of.json"
        [doc, doc_edition_of]
      end

      it do
        relation = subject.parse_relation
        expect(relation).to be_instance_of Array
        expect(relation.size).to eq 2
        expect(relation[0]).to be_instance_of RelatonBib::DocumentRelation
        expect(relation[0].type).to eq "adoptedAs"
        expect(relation[1]).to be_instance_of RelatonBib::DocumentRelation
        expect(relation[1].type).to eq "hasEdition"
        expect(relation[1].bibitem.id).to eq "CCSDS123.0-B-2Cor.2"
      end
    end

    context "successor" do
      it "doesn't have successor" do
        expect(subject.successor).to eq []
      end

      it "has successor" do
        docid = double "docid", id: :successor_id
        successor_rel = double "relation"
        successor = double "successor", docidentifier: [docid], relation: successor_rel
        expect(successor_rel).to receive(:<<).with(:predecessor)
        subject.instance_variable_set :@successor, successor
        expect(subject).to receive(:docidentifier).and_return :docid
        expect(subject).to receive(:create_relation).with("successorOf", :docid).and_return :predecessor
        expect(subject).to receive(:create_relation).with("hasSuccessor", :successor_id).and_return :successor
        expect(subject.successor).to eq [:successor]
      end
    end

    context "#relation_type" do
      context "hasEdition" do
        let(:doc) { JSON.parse File.read "spec/fixtures/doc_has_edition.json" }
        let(:docs) do
          doc_edition_of = JSON.parse File.read "spec/fixtures/doc_edition_of.json"
          [doc, doc_edition_of]
        end

        it { expect(subject.relation_type(doc["Document_x0020_Number"])).to be_nil }
        it { expect(subject.relation_type(docs[1]["Document_x0020_Number"])).to eq "hasEdition" }
      end

      context "editionOf" do
        let(:doc) { JSON.parse File.read "spec/fixtures/doc_edition_of.json" }
        let(:docs) do
          doc_has_edition = JSON.parse File.read "spec/fixtures/doc_has_edition.json"
          [doc, doc_has_edition]
        end

        it { expect(subject.relation_type(docs[1]["Document_x0020_Number"])).to eq "editionOf" }
      end

      it "one ID is translation" do
        expect(subject).to receive(:docidentifier).and_return("CCSDS 650.0-B-1-S").twice
        expect(subject.relation_type("CCSDS 650.0-B-1-S - French Translated")).to be_nil
      end

      it "both IDs are translations" do
        expect(subject).to receive(:docidentifier).and_return("CCSDS 650.0-B-1 - French Translated").exactly(3).times
        expect(subject.relation_type("CCSDS 650.0-B-1-S - French Translated")).to eq "hasEdition"
      end
    end

    context "#parse_editorialgroup" do
      it do
        eg = subject.parse_editorialgroup
        expect(eg).to be_instance_of RelatonBib::EditorialGroup
        expect(eg.technical_committee).to be_instance_of Array
        expect(eg.technical_committee.size).to eq 1
        expect(eg.technical_committee[0]).to be_instance_of RelatonBib::TechnicalCommittee
        expect(eg.technical_committee[0].workgroup).to be_instance_of RelatonBib::WorkGroup
        expect(eg.technical_committee[0].workgroup.name).to eq "SLS-MHDC"
      end

      it "has no editorialgroup" do
        doc = subject.instance_variable_get :@doc
        doc["Working_x0020_Group"] = nil
        expect(subject.parse_editorialgroup).to be_nil
      end
    end

    context "#parse_technology_area" do
      it do
        expect(subject.parse_technology_area).to eq "Space Link Services Area"
      end

      it "has no technology area" do
        doc = subject.instance_variable_get :@doc
        doc["Working_x0020_Group"] = nil
        expect(subject.parse_technology_area).to be_nil
      end
    end
  end
end
