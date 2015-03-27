# -*- encoding : utf-8 -*-
class CatalogController < ApplicationController  

  include Blacklight::Catalog

  class SingleDocumentResponse
    def initialize doc
      @doc = doc
    end

    def documents
      [@doc]
    end
  end

  class FacetResponse
    attr_reader :name
    def initialize name, counts
      @name = name
      @counts = counts
    end

    def items
      @counts.each_solution.map do |s|
        if s[:value]
          OpenStruct.new(name: name, value: s.value.to_s, hits: s.hits.to_i)
        end
      end.compact
    end

    def sort; end
    def offset; end
    def limit; end
  end

  class Aggregations
    attr_reader :response

    def initialize response
      @response = response
    end

    def [] field
      predicate = response.blacklight_config.facet_fields[field].field

      v = response.scoped_client(:value, count: {'*' => :hits}).where([:subject, predicate, :value]).group(:value).order("DESC(?hits)")

      FacetResponse.new(field, v)
    end
  end

  class SearchResponse
    attr_reader :client, :params
    attr_accessor :document_model, :blacklight_config

    include Kaminari::PageScopeMethods
    include Kaminari::ConfigurationMethods::ClassMethods

    def initialize client, params
      @client = client
      @params = params
      
      self.document_model = params[:document_model] || RdfDocument
      self.blacklight_config = params[:blacklight_config]
    end

    def grouped?; false; end
    
    def documents
      @documents = select_response.each_solution.map do |solution|
        document_model.new(solution.to_h[:subject])
      end
    end

    def select_response
      scope = scoped_client.limit(params[:limit]) if params[:limit]
      scope = scope.offset(params[:offset]) if params[:offset]

      scope
    end

    def scoped_client *args
      scope = client.select *args
      Array(params[:where]).each do |w|
        scope = scope.where(w)
      end
      scope
    end

    def empty?
      documents.to_a.empty?
    end

    def total
      scoped_client(distinct: true, count: {'*' => :count}).solutions.first[:count].to_i
    end
    alias_method :total_count, :total

    def aggregations
      @aggregations ||= Aggregations.new(self)
    end

    def start
      params[:offset]
    end
    alias_method :offset_value, :start
    
    def limit_value
      params[:limit]
    end
    alias_method :rows, :limit_value

    def sort
      params[:sort]
    end

    def spelling
      OpenStruct.new(words: [])
    end
  end

  class SparqlRepository < Blacklight::AbstractRepository
    def find id, params = {}
      SingleDocumentResponse.new(document_model.new(Base64.decode64(id)))
    end

    def search params = {}
      # Array(params[:scope]).each do |s|
      #   scope = scope.instance_exec &s
      # end

      SearchResponse.new(client, params.merge(blacklight_config: blacklight_config))
    end

    def client
      @client ||= SPARQL::Client.new("http://vfrbr.info/dataset/query")
    end

    def document_model
      blacklight_config.document_model
    end
  end

  class SparqlBuilder < Blacklight::SearchBuilder
    self.default_processor_chain = [:add_query, :add_facets, :add_sort, :add_limit]

    def add_query sparql_params
  #    sparql_params[:query] = blacklight_params[:q]
      sparql_params[:where] ||= []
      sparql_params[:where] << [:subject, RDF::URI.new("http://iflastandards.info/ns/fr/frbr/frbrer/P2013"), RDF::URI.new("http://vfrbr.info/person/3434")]
    end

    def add_facets sparql_params
      Array(blacklight_params[:f]).each do |field, values|
        Array(values).each do |v|
          sparql_params[:where] << [:subject, blacklight_config.facet_fields[field].field, v]
        end
      end
    end

    def add_sort sparql_params
      sparql_params[:sort] = sort
    end

    def add_limit sparql_params
      sparql_params[:limit] = per
      sparql_params[:offset] = start
    end
    
  end


  self.search_params_logic = true

  configure_blacklight do |config|
    
    config.repository_class = CatalogController::SparqlRepository
    config.search_builder_class = CatalogController::SparqlBuilder
    config.document_model = RdfDocument
    
    config.index.title_field = :title
    
    config.add_show_field :url
    config.add_show_field :work_title
    config.add_show_field :formOfExpression

    config.add_facet_field :instrument, field: RDF::URI.new("http://iflastandards.info/ns/fr/frbr/frbrer/P3068")
  end

end 
