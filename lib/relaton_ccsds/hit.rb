module RelatonCcsds
  class Hit
    attr_reader :code

    def initialize(code:, url:)
      @code = code
      @url = url
    end

    def doc
      return @doc if @doc

      resp = Mechanize.new.get(@url)
      hash = YAML.safe_load(resp.body)
      hash["fetched"] = Date.today.to_s
      @doc = BibliographicItem.from_hash(hash)
    rescue Mechanize::Error => e
      raise RelatonBib::RequestError, e.message
    end
  end
end
