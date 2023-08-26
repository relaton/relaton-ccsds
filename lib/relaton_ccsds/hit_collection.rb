module RelatonCcsds
  class HitCollection < RelatonBib::HitCollection
    GHURL = "https://raw.githubusercontent.com/relaton/relaton-data-ccsds/main/".freeze
    INDEX_FILE = "index-v1.yaml".freeze

    #
    # Search his in index.
    #
    # @return [<Type>] <description>
    #
    def fetch
      rows = index.search text
      @array = rows.map { |row| Hit.new code: row[:id], url: "#{GHURL}#{row[:file]}" }
      self
    rescue SocketError, OpenURI::HTTPError, OpenSSL::SSL::SSLError, Errno::ECONNRESET => e
      raise RelatonBib::RequestError, e.message
    end

    def index
      @index ||= Relaton::Index.find_or_create :ccsds, url: "#{GHURL}index-v1.zip", file: INDEX_FILE
    end
  end
end
