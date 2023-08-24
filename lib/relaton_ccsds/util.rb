module RelatonCcsds
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonCcsds.configuration.logger
    end
  end
end
