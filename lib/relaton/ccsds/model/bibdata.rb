module Relaton
  module Ccsds
    class Bibdata < Item
      model ItemData
      include Bib::BibdataShared
    end
  end
end
