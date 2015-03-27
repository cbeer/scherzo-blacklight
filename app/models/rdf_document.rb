require 'uri'

class RdfDocument
  include Blacklight::Document
  include Blacklight::Document::ActiveModelShim

  def initialize id
    @id = id.to_s
  end

  def graph
    @graph ||= RDF::Graph.load(id + ".rdf")
  end

  def id; @id; end

  def to_param; Base64.encode64(id); end

  def _source
    @_source ||= program.evaluate(RDF::URI.new(id), graph).with_indifferent_access
  end

  def program
    @program ||= Ldpath::Program.parse(program_string.strip)
  end

  def program_string
    <<-EOF
@prefix frbrer : <http://iflastandards.info/ns/fr/frbr/frbrer> ;
title = frbrer:P3008 :: xsd:string ;
    EOF
  end

end
