module Relaton
  module Ccsds
    class ItemData < Bib::ItemData
      def relation=(value)
        @relation = value || []
      end

      def create_id(_without_date: false)
        docid = docidentifier.find(&:primary) || docidentifier.first
        return unless docid

        self.id = docid.content.gsub(/\W+/, "")
      end
    end
  end
end
