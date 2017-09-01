require 'pg'
require 'csv'
require 'json'
require 'active_support/core_ext/hash'
require 'nokogiri'
require 'byebug'


class XMLParser
  def initialize(filename)
    @filename = filename
    @file = File.read("files/#{filename}.xml")
    @doc = Hash.from_xml(@file)
    @headers = column_names
  end

  def insert_into_db
    update_cases
  end

  def update_cases
    conn = PG.connect( dbname: 'probate' )
    @doc["DailyRecordExport"]["Case"].each do |record|

      columns = record.map { |key,value| key if value.is_a?(String) }.compact.join(",")
      data = record.map do |k,v|
        %Q(#{v}) if is_integer?(v) unless v.is_a?(Hash) or v.is_a?(Array)
        %Q('#{v}') if v.is_a?(String)
      end.compact.join(',')

      sql = "INSERT INTO cases (#{columns}) VALUES (#{data})"
      conn.exec(sql)
    end
  end

  def is_integer?(int)
    int.to_i.to_s == int
  end

  def column_names
    names = []

    @doc["DailyRecordExport"]["Case"].each do |record|
      case_names = record.map { |key,value| key if value.is_a?(String) }.compact
      case_names.each { |name| names << name unless names.include? name }
    end

    names.uniq
  end
end

parser = XMLParser.new("probate2")
parser.insert_into_db
