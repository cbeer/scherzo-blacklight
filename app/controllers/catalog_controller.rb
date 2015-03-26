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

  class SearchResponse
    attr_reader :response, :params
    attr_accessor :document_model, :blacklight_config

    include Kaminari::PageScopeMethods
    include Kaminari::ConfigurationMethods::ClassMethods

    def initialize response, params
      @response = response
      @params = params
      
      self.document_model = params[:document_model] || RdfDocument
      self.blacklight_config = params[:blacklight_config]
    end

    def grouped?; false; end
    
    def documents
      # return enum_for(:documents) unless block_given?
      
      @documents = response.each_solution.map do |solution|
        document_model.new(solution.to_h[:subject])
      end
    end

    def empty?
      documents.to_a.empty?
    end

    def total
      documents.to_a.length
    end
    alias_method :total_count, :total

    def aggregations
      {}
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
      nil
    end
    

  end

  class SparqlRepository < Blacklight::AbstractRepository
    def find id, params = {}
      SingleDocumentResponse.new(document_model.new(Base64.decode64(id)))
    end

    def search params = {}
      scope = client

      scope = scope.query(params[:query])
      # 
      # scope = scope.limit(params[:limit]) if params[:limit]
      # scope = scope.offset(params[:offset]) if params[:offset]

      # Array(params[:scope]).each do |s|
      #   scope = scope.instance_exec &s
      # end

      SearchResponse.new(scope, params)
    end

    def client
      @client ||= SPARQL::Client.new("http://vfrbr.info/dataset/query")
    end

    def document_model
      blacklight_config.document_model
    end
  end

  class SparqlBuilder < Blacklight::SearchBuilder
    self.default_processor_chain = [:add_query, :add_sort, :add_limit]

    def add_query sparql_params
  #    sparql_params[:query] = blacklight_params[:q]
      sparql_params[:query] = <<-EOF
      SELECT ?subject 
         WHERE { 
           ?subject <http://iflastandards.info/ns/fr/frbr/frbrer/P3056> "DRAM"^^<http://www.w3.org/2001/XMLSchema#string> .
         }
EOF
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
    
    config.index.title_field = :title
  end

end 
