require 'json'
require 'yaml'
require 'path'
require 'uri'

module Simple

  class Config

    class Error < StandardError; end

    attr_accessor :parent
    attr_accessor :fields
    attr_accessor :data

    def self.define(definitions)
      fields = {}
      data = definitions.map do |key, field|
        field = Field.make(field)
        fields[key] = field
        [key, field.convert(field.default)]
      end.to_h
      new(fields: fields, data: data)
    end

    def initialize(parent: nil, fields:, data:)
      @parent = parent
      @fields = fields
      @data = data.map do |key, value|
        key = key.to_sym
        field = @fields[key] or raise Error, "Unknown config key: #{key.inspect}"
        [key, field.convert(value)]
      end.to_h
    end

    def load(file)
      data = File.read(file)
      json = JSON.parse(data, symbolize_names: true)
      make(**json)
    end

    def load_yaml(file)
      yaml = YAML.load_file(file, permitted_classes: [Date, Symbol])
      make(**yaml)
    end

    def make(**data)
      self.class.new(parent: self, fields: @fields, data: data)
    end

    def as_json(*opts)
      @data.compact
    end

    def to_json(*opts)
      as_json.to_json(*opts)
    end

    def to_h
      (@parent&.to_h || {}).merge(@data)
    end

    def save(file)
      File.write(file, JSON.pretty_generate(self))
    end

    def method_missing(id, *args)
      key = id.to_s.sub(/=$/, '').to_sym
      field = @fields[key] or return super
      if $&
        @data[key] = args.first
      elsif @data.has_key?(key)
        @data[key]
      elsif @parent
        @parent.send(key)
      else
        super
      end
    end

    class Field

      attr_accessor :default
      attr_accessor :converter

      def self.make(obj)
        case obj
        when nil
          new
        when Proc
          new(converter: obj)
        when Hash
          new(**obj)
        when Field
          obj
        else
          new(default: obj)
        end
      end

      def initialize(default: nil, converter: nil)
        @default = default
        @converter = converter
      end

      def convert(value)
        if value.nil?
          nil
        else
          case @converter
          when :path
            Path.new(value)
          when :date
            value.kind_of?(Date) ? value : Date.parse(value)
          when :uri
            value.kind_of?(URI) ? value : URI.parse(value)
          when :symbol
            value.to_sym
          when Proc
            @converter.call(value)
          else
            value
          end
        end
      end

    end

  end

end