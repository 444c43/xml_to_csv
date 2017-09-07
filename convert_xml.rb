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
    @party_attorney_headers = []
    @party_headers = []
    @case_headers = case_headers
    @conn = PG.connect( dbname: 'probate' )
  end

  def insert_into_db
    update_cases
  end

  def update_cases
    @doc["DailyRecordExport"]["Case"].each do |record|

      columns = record.map { |key, value| key if value.is_a?(String) }.compact.join(",")

      data = record.map do |key, value|
        update_party_table(value) if key == "Party" && is_a_collection?(value)
        %Q(#{value}) if is_integer?(value) unless value.is_a?(Hash) or value.is_a?(Array)
        %Q('#{value.gsub("'", "''")}') if value.is_a?(String)
      end.compact.join(',')

      sql = "INSERT INTO cases (#{columns}) VALUES (#{data})"
      @conn.exec(sql)
    end
  end

  def update_party_table(items)
    items.each { |item| update_party(item) } if items.is_a?(Array)
    update_party(items) if items.is_a?(Hash)
  end

  def update_party(enum_value)
    columns = enum_value.map { |key, value| key if value.is_a?(String) }.compact.join(",")

    data = enum_value.map do |key, value|
      update_party_attorney_table(value) if key == "PartyAttorney" && is_a_collection?(value)
      %Q('#{value.gsub("'", "''")}') if value.is_a?(String)
    end.compact.join(',')

    sql = "INSERT INTO party (#{columns}) VALUES (#{data})"
    @conn.exec(sql)
  end

  def update_party_attorney_table(items)
    items.each { |item| update_party_attorney(item) } if items.is_a?(Array)
    update_party_attorney(items) if items.is_a?(Hash)
  end

  def update_party_attorney(enum_value)
    columns = enum_value.map { |key, value| key if value.is_a?(String) }.compact.join(",")

    data = enum_value.map do |key, value|
      %Q('#{value.gsub("'", "''")}') if value.is_a?(String)
    end.compact.join(',')
    return if columns == '' or data == ''

    sql = "INSERT INTO attorney (#{columns}) VALUES (#{data})"
    @conn.exec(sql)
  end

  def is_integer?(int)
    int.to_i.to_s == int
  end

  def case_headers
    names = []

    @doc["DailyRecordExport"]["Case"].each do |record|
      case_names = record.map do |key,value|
        party_headers(value) if is_a_collection?(value)
        key if value.is_a?(String) or value.nil?
      end.compact

      case_names.each { |name| names << name unless names.include? name }
    end

    names.uniq
  end

  def party_headers(collection)
    collection.each { |element| party_headers(element) } if collection.is_a?(Array)

    party_names = []

    collection.each { |key, value| is_string_or_nil?(value) ? party_names << key : party_attorney_headers(value) } if collection.is_a?(Hash)

    party_names.compact.each { |name| @party_headers << name unless @party_headers.include? name }
  end

  def party_attorney_headers(collection)
    collection.each { |element| party_attorney_headers(element) } if collection.is_a?(Array)

    headers = []

    collection.each { |key, value| headers << key if is_string_or_nil?(value) } if collection.is_a?(Hash)

    headers.compact.each { |name| @party_attorney_headers << name unless @party_attorney_headers.include? name }
  end

  private

  def is_string_or_nil?(obj)
    obj.is_a?(String) or obj.nil?
  end

  def is_a_collection?(obj)
    obj.is_a?(Hash) or obj.is_a?(Array)
  end
end

parser = XMLParser.new("probate2")
parser.insert_into_db
