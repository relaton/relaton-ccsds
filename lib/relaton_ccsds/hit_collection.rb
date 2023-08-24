module RelatonCcsds
  class HitCollection < RelatonBib::HitCollection
    def fetch
      resp = agent.get(url)
      json = JSON.parse resp.body
      @array = json["d"]["results"].map do |hit|

      end
      self
    end

    def agent
      return @agent if @agent

      @agent = Mechanize.new
      @agent.request_headers = { "Accept" => "application/json" }
      @agent
    end
  end
end
