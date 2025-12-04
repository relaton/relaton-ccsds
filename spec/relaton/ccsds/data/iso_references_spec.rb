require "relaton/ccsds/data/iso_references"

describe Relaton::Ccsds::IsoReferences do
  subject { Relaton::Ccsds::IsoReferences.instance }

  describe "#[]" do
    it "returns reference for given key" do
      stub_request(:get, Relaton::Ccsds::IsoReferences::ISO_CSV_URL)
        .to_return(body: <<~CSV)
          id,deliverableType,supplementType,reference,title.en,title.fr,publicationDate,edition,icsCode,ownerCommittee,currentStage,replaces,replacedBy,languages,pages.en,scope.en
          62319,IS,,ISO 18381:2013,Space data and information transfer systems — Lossless multispectral and hyperspectral image compression,Systèmes de transfert des informations et données spatiales — Compression d'images multispectrales et hyperspectrales sans perte,2013-05-29,1,['49.140'],ISO/TC 20/SC 13,9060,,,['en'],54,"<p>ISO 18381:2013 establishes a data compression algorithm applied to digital three-dimensional image data from payload instruments, such as multispectral and hyperspectral imagers, and specifies the compressed data format.</p><p>Data compression is used to reduce the volume of digital data to achieve benefits in areas including, but not limited to:</p><ul><li>reduction of transmission channel bandwidth;</li><li>reduction of the buffering and storage requirement;</li><li>reduction of data-transmission time at a given rate.</li></ul><p>The characteristics of instrument data are specified only to the extent necessary to ensure multi-mission support capabilities. ISO 18381:2013 does not attempt to quantify the relative bandwidth reduction, the merits of the approaches discussed, or the design requirements for encoders and associated decoders. </p><p>ISO 18381:2013 addresses only lossless compression of three-dimensional data, where the requirement is for a data-rate reduction constrained to allow no distortion to be added in the data compression/decompression process.</p>"
          12345,IS,,ISO 6123-2:1983,Rubber or plastics covered rollers — Specifications — Part 2: Classification of surface characteristics,Cylindres revêtus de caoutchouc ou de plastique — Spécifications — Partie 2: Classification des caractéristiques de surface,1983-09-01,1,['83.140.99'],ISO/TC 45,9599,,[12346],"['en','fr']",2,
        CSV
      expect(subject["62319"]).to eq "ISO 18381:2013"
      expect(subject["12345"]).to eq "ISO 6123-2:1983"
    end
  end
end
