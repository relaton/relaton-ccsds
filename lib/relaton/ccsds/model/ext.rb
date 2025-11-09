require_relative "doctype"

module Relaton
  module Ccsds
    class Ext < Lutaml::Model::Serializable
      attribute :schema_version, :string
      attribute :doctype, Doctype
      attribute :structuredidentifier, Bib::StructuredIdentifier, collection: true
      attribute :technology_area, :string, values: %w[SEA MOIMS CSS SOIS SLS SIS]

      xml do
        map_attribute "schema-version", to: :schema_version
        map_element "doctype", to: :doctype
        map_element "structuredidentifier", to: :structuredidentifier
        map_element "technology-area", to: :technology_area
      end
    end
  end
end
