module Relaton
  module Ccsds
    class ItemData < Bib::ItemData
      def relation=(value)
        @relation = value || []
      end
    end
  end
end
