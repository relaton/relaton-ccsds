module Relaton
  module Ccsds
    class HitCollection < Relaton::Core::HitCollection
      GHURL = "https://raw.githubusercontent.com/relaton/relaton-data-ccsds/main/".freeze
      INDEX_FILE = "index-v1.yaml".freeze

      #
      # Search his in index.
      #
      # @return [<Type>] <description>
      #
      def fetch
        @array = rows.map { |row| Hit.new code: row[:id], url: "#{GHURL}#{row[:file]}" }
        self
      rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError, Errno::ECONNRESET => e
        raise RelatonBib::RequestError, e.message
      end

      def index
        @index ||= Relaton::Index.find_or_create :ccsds, url: "#{GHURL}index-v2.zip", file: INDEX_FILE, pubid_class: Pubid::Ccsds::Identifier
      end

      def pubid
        @pubid ||= Pubid::Ccsds::Identifier.parse(ref)
      end

      def rows
        if pubid.edition
          index.search(pubid)
          # index.search { |r| Pubid::Ccsds::Identifier.create(**r[:id]) == pubid }
        else
          index.search { |r| r[:id].exclude(:edition) == pubid }
        end
      end
    end
  end
end
