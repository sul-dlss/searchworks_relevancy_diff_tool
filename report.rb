require 'http'
require 'json'
require 'rack'
require 'tty-table'

Endpoint = Struct.new(:url)

class SearchResult
  attr_reader :endpoint, :params

  def initialize(endpoint, params)
    @endpoint = endpoint
    @params = params
  end

  def response
    @response ||= HTTP.get(endpoint.url, params: params.merge('fl' => 'id,title_245a_display', 'wt' => 'json', 'rows' => 20))
  end

  def data
    @data ||= JSON.parse(response.body)
  end

  def docs
    @docs ||= data.fetch('response', {}).fetch('docs', []).fill({}, num_docs, 20 - num_docs)
  end

  def num_docs
    data.fetch('response', {}).fetch('docs', []).length
  end

  def doc_ids
    @doc_ids ||= docs.map { |x| x['id'] }
  end
end

class DifferenceReporter
  attr_reader :results

  def initialize(results)
    @results = results
  end

  def headers
    ['diff'] + results.map { |r| r.endpoint.url }
  end

  def doc_rows
    transposed_data.each_with_index.map do |row, index|
      next if row.all?(&:empty?)

      prefix = if row.map { |r| r['id'] }.uniq.length == 1
        ''
      else
        current_position = results.last.doc_ids.index(row.first['id'])

        if current_position.nil?
          '?'
        else
          relative_position = current_position - index

          if relative_position < 0
            "↑#{relative_position.abs}"
          else
            "↓#{relative_position}"
          end
        end
      end

      [prefix] + row.map { |x| "#{x['id']}: #{x['title_245a_display']}" }
    end.compact
  end

  def meta_info
    ['numFound'] + results.map do |r|
      r.data.fetch('response', {})['numFound']
    end
  end

  def transposed_data
    results.map { |r| r.docs }.transpose
  end

  def report
    table = TTY::Table.new(headers, [meta_info] + doc_rows)
    table.render(:unicode, resize: true, width: 270)
  end
end

endpoints = [
  Endpoint.new('http://searchworks-solr-lb.stanford.edu:8983/solr/current/select'),
  Endpoint.new('https://sul-solr-tester.stanford.edu/searchworks-dev/select')
]

ARGF.each_line do |query_string|
  query_params = Rack::Utils.parse_nested_query query_string.strip

  results = endpoints.map do |endpoint|
    SearchResult.new(endpoint, query_params)
  end
  puts query_params
  puts DifferenceReporter.new(results).report
end
