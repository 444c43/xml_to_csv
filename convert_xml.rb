require 'csv'
require 'json'
require 'active_support/core_ext/hash'
require 'nokogiri'
require 'byebug'
require 'pp'

class XMLParser
  def initialize(filename)
    @filename = filename
    @file = File.read("#{filename}.xml")
    @doc = Hash.from_xml(@file)
    @headers = get_headers(@doc).uniq
  end

  def convert_to_csv
    CSV.open("#{@filename}.csv", "wb") do |csv|
      csv << @headers

      @doc["DailyRecordExport"]["Case"].each do |element|
        foo = method_one element
        csv << foo.values
      end
    end
  end

  private

  def get_headers(h)
    h.each_with_object([]) do |(k,v),keys|      
      keys << k
      keys.concat(get_headers(v)) if v.is_a? Hash

      v.each_with_object(keys) { |ary| keys.concat(get_headers(ary)) } if v.is_a? Array
    end
  end

  def unnest(e)
    e.each_with_object({}) do |(key,value), keys|
      keys.merge!(key=>value) unless value.is_a?(Hash) || value.is_a?(Array)
      value.each_with_object(keys) { |item| keys.merge!(unnest(item)) } if value.is_a?(Array)
      keys.merge!(unnest(value)) if value.is_a? Hash
    end
  end

  def method_one(elem)
    element = unnest(elem)
    foo = {}
    @headers.each do |header|
      element[header].nil? ? foo[header] = " " : foo[header] = element[header]
    end
    foo
  end
end

parser = XMLParser.new("probate2")
parser.convert_to_csv
