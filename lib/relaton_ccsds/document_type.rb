module RelatonCcsds
  class DocumentType < RelatonBib::DocumentType
    # DOCTYPES = %w[standard practice report specification record].freeze

    def initialize(type:, abbreviation: nil)
      # check_type type
      super
    end

    # def check_type(type)
    #   return if DOCTYPES.include? type

    #   Util.warn "WARNING: invalid doctype: `#{type}`"
    # end
  end
end
