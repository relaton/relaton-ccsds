module RelatonCcsds
  class HitCollection < RelatonBib::HitCollection
    GHURL = "https://raw.githubusercontent.com/relaton/relaton-data-ccsds/main/".freeze
    INDEX_FILE = "index-v2.yaml".freeze

    #
    # Search his in index.
    #
    # @return [<Type>] <description>
    #
    def fetch
      pubid = Pubid::Ccsds::Identifier.parse(text)
      rows = if pubid.edition
               index.search(pubid)
               # index.search { |r| Pubid::Ccsds::Identifier.create(**r[:id]) == pubid }
             else
               index.search { |r| r[:id].exclude(:edition) == pubid }
             end
      @array = rows.map { |row| Hit.new code: row[:id], url: "#{GHURL}#{row[:file]}" }
      self
    rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError, Errno::ECONNRESET => e
      raise RelatonBib::RequestError, e.message
    end

    def index
      @index ||= Relaton::Index.find_or_create :ccsds, url: "#{GHURL}index-v2.zip", file: INDEX_FILE, pubid_class: Pubid::Ccsds::Identifier
    end
  end
end
