module Relaton
  module Ccsds
    class Doctype < Bib::Doctype
      TYPES = %w[standard practice report specification record].freeze

      attribute :content, :string, values: TYPES
    end
  end
end
