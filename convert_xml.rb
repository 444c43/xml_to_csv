require 'pg'
require 'csv'
require 'json'
require 'active_support/core_ext/hash'
require 'nokogiri'
require 'byebug'

class String
  def is_integer?
    self.to_i.to_s == self
  end
end

class XMLParser
  def initialize(filename)
    @filename = filename
    @file = File.read("files/#{filename}.xml")
    @doc = Hash.from_xml(@file)
    @headers = get_headers(@doc).uniq
  end

  def insert_into_db 
    conn = PG.connect( dbname: 'probate' )

    @doc["DailyRecordExport"]["Case"].each do |record|
      columns = record.map { |k,v| k if v.is_a?(String) }.compact.join(",")
      data = record.map do |k,v|
        %Q(#{v}) if v.is_integer? unless v.is_a?(Hash)
        %Q('#{v}') if v.is_a?(String)
      end.compact.join(',')

      sql = "INSERT INTO cases (#{columns}) VALUES (#{data})"

      conn.exec(sql)
    end
  end

  private
end

parser = XMLParser.new("pg_test")
parser.insert_into_db
