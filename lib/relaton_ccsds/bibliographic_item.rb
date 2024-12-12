module RelatonCcsds
  class BibliographicItem < RelatonBib::BibliographicItem
    attr_reader :technology_area

    # @param technology_area [String, nil]
    def initialize(**args)
      @technology_area = args.delete(:technology_area)
      super
    end

    #
    # Fetch flavor schema version
    #
    # @return [String] schema version
    #
    def ext_schema
      @ext_schema ||= schema_versions["relaton-model-ccsds"]
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(**opts) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      super do |builder|
        if opts[:bibdata] && (doctype || editorialgroup || technology_area)
          ext = builder.ext do |b|
            doctype&.to_xml b
            editorialgroup&.to_xml b
            b.send(:"technology-area", technology_area) if technology_area
          end
          ext["schema-version"] = ext_schema if !opts[:embedded] && respond_to?(:ext_schema) && ext_schema
        end
      end
    end

    # @return [Hash]
    def to_hash(embedded: false)
      hash = super
      if technology_area
        hash["ext"] ||= {}
        hash["ext"]["technology_area"] = technology_area
      end
      hash
    end

    def has_ext?
      super || technology_area
    end

    def to_format(format)
      return self unless format

      me = deep_clone
      me.link.select! { |l| l.type.casecmp(format).zero? }
      me if me.link.any?
    end
  end
end
