module Sequel
  module Plugins
    # Sequel's built in Serialization plugin allows you to keep serialized
    # ruby objects in the database, while giving you deserialized objects
    # when you call an accessor.
    # 
    # This plugin works by keeping the serialized value in the values, and
    # adding a @deserialized_values hash.  The reader method for serialized columns
    # will check the @deserialized_values for the value, return it if present,
    # or deserialized the entry in @values and return it.  The writer method will
    # set the @deserialized_values entry.  This plugin adds a before_save hook
    # that serializes all @deserialized_values to @values.
    #
    # You can use either marshal or yaml as the serialization format.
    # If you use yaml, you should require yaml yourself.
    #
    # Because of how this plugin works, it must be used inside each model class
    # that needs serialization, after any set_dataset method calls in that class.
    # Otherwise, it is possible that the default column accessors will take
    # precedence.
    module Serialization
      # Set up the column readers to do deserialization and the column writers
      # to save the value in deserialized_values.
      def self.apply(model, *args)
        model.instance_eval{@serialization_map = {}}
      end
      
      def self.configure(model, format=nil, *columns)
        model.serialize_attributes(format, *columns) unless columns.empty?
      end

      module ClassMethods
        # A map of the serialized columns for this model.  Keys are column
        # symbols, values are serialization formats (:marshal or :yaml).
        attr_reader :serialization_map

        # Copy the serialization format and columns to serialize into the subclass.
        def inherited(subclass)
          super
          sm = serialization_map.dup
          subclass.instance_eval{@serialization_map = sm}
        end
        
        # The first value in the serialization map.  This is only for
        # backwards compatibility, use serialization_map in new code.
        def serialization_format
          serialization_map.values.first
        end
        
        # Create instance level reader that deserializes column values on request,
        # and instance level writer that stores new deserialized value in deserialized
        # columns
        def serialize_attributes(format, *columns)
          raise(Error, "Unsupported serialization format (#{format}), should be :marshal or :yaml") unless [:marshal, :yaml].include?(format)
          raise(Error, "No columns given.  The serialization plugin requires you specify which columns to serialize") if columns.empty?
          columns.each do |column|
            serialization_map[column] = format
            define_method(column) do 
              if deserialized_values.has_key?(column)
                deserialized_values[column]
              else
                deserialized_values[column] = deserialize_value(column, @values[column])
              end
            end
            define_method("#{column}=") do |v| 
              changed_columns << column unless changed_columns.include?(column)
              deserialized_values[column] = v
            end
          end
        end
        
        # The columns that will be serialized.  This is only for
        # backwards compatibility, use serialization_map in new code.
        def serialized_columns
          serialization_map.keys
        end
      end

      module InstanceMethods
        # Hash of deserialized values, used as a cache.
        attr_reader :deserialized_values

        # Set @deserialized_values to the empty hash
        def initialize(*args, &block)
          @deserialized_values = {}
          super
        end

        # Serialize all deserialized values
        def before_save
          super
          deserialized_values.each do |k,v|
            @values[k] = serialize_value(k, v)
          end
        end
        
        # Empty the deserialized values when refreshing.
        def refresh
          @deserialized_values = {}
          super
        end

        private

        # Deserialize the column from either marshal or yaml format
        def deserialize_value(column, v)
          return v if v.nil?
          case model.serialization_map[column] 
          when :marshal
            Marshal.load(v.unpack('m')[0]) rescue Marshal.load(v)
          when :yaml
            YAML.load v if v
          else
            raise Error, "Bad serialization format (#{model.serialization_map[column].inspect}) for column #{column.inspect}"
          end
        end

        # Serialize the column to either marshal or yaml format
        def serialize_value(column, v)
          return v if v.nil?
          case model.serialization_map[column] 
          when :marshal
            [Marshal.dump(v)].pack('m')
          when :yaml
            v.to_yaml
          else
            raise Error, "Bad serialization format (#{model.serialization_map[column].inspect}) for column #{column.inspect}"
          end
        end
      end
    end
  end
end
