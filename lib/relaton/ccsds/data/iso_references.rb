require "csv"
require "singleton"
require "mechanize"

module Relaton
  module Ccsds
    class IsoReferences
      include Singleton

      ISO_CSV_URL = "https://isopublicstorageprod.blob.core.windows.net/opendata/_latest"\
                    "/iso_deliverables_metadata/csv/iso_deliverables_metadata.csv".freeze

      def [](key)
        data[key]
      end

      private

      def data
        @data ||= begin
          csv = Mechanize.new.get(ISO_CSV_URL).body
          rows = CSV.parse(csv, headers: true)
          rows.each_with_object({}) do |row, h|
            h[row["id"]] = row["reference"]
          end
        end
      end
    end
  end
end
