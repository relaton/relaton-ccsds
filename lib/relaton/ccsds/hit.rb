require "mechanize"
module Relaton
  module Ccsds
    class Hit < Relaton::Core::Hit
      # attr_reader :code

      # def initialize(code:, url:)
      #   @code = code
      #   @url = url
      # end

      def item
        return @item if @item

        resp = Mechanize.new.get(hit[:url])
        @item = Item.from_yaml(resp.body)
        @item.fetched = Date.today.to_s
        @item
      rescue Mechanize::Error => e
        raise Relaton::RequestError, e.message
      end
    end
  end
end
