module Relaton
  module Ccsds
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end
