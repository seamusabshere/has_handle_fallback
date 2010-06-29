require 'active_support'
require 'active_support/version'
%w{
  active_support/core_ext/string/inflections
}.each do |active_support_3_requirement|
  require active_support_3_requirement
end if ActiveSupport::VERSION::MAJOR == 3
require 'active_record'
require 'validates_decency_of'

module HasHandleFallback
  SUB_REGEXP = '\_\-a-zA-Z0-9'
  REGEXP = /\A[#{SUB_REGEXP}]+\z/
  ANTI_REGEXP = /[^#{SUB_REGEXP}]+/
  LENGTH_RANGE = 2..32
  RECORD_ID_REGEXP = /\A\d+\z/
  
  def self.str2handle(str)
    str = str.to_s.dup
    str.gsub! ANTI_REGEXP, ''
    str = str.underscore
    str << ('_' * (LENGTH_RANGE.min - str.length)) if str.length < LENGTH_RANGE.min
    str[0, LENGTH_RANGE.max]
  end
  
  module ActiveRecordBaseMethods
    def has_handle_fallback(fallback_column, options = {})
      include InstanceMethods
      extend ClassMethods
      
      class_eval do
        cattr_accessor :has_handle_fallback_options
        self.has_handle_fallback_options = {}
        has_handle_fallback_options[:required] = options.delete(:required) || false
        has_handle_fallback_options[:fallback_column] = fallback_column.to_s
        has_handle_fallback_options[:handle_column] = options.delete(:handle_column) || 'handle'
        has_handle_fallback_options[:validates_format] = 
          options.include?(:validates_format) ? options.delete(:validates_format) : true
        
        validate :handle_is_valid
      end
    end
  end
  
  module ClassMethods
    def find_by_id_or_handle(param)
      return if param.blank?
      param = param.to_s
      if param =~ HasHandleFallback::RECORD_ID_REGEXP
        find_by_id param
      else
        first :conditions => [ "#{quoted_table_name}.`#{has_handle_fallback_options[:handle_column]}` LIKE ?", param ]
      end
    end
    alias :[] :find_by_id_or_handle
  end

  module InstanceMethods
    def handle_is_valid
      raw = read_attribute self.class.has_handle_fallback_options[:handle_column]
      cooked = handle_fallback

      # inline check to make sure the handle_fallback method works
      unless cooked =~ HasHandleFallback::REGEXP and HasHandleFallback::LENGTH_RANGE.include?(cooked.length)
        raise "Dear Developer: your handle_fallback method is not generating valid handles (generated '#{handle_fallback}' for '#{raw}')"
      end
      
      # allow nils but not blanks
      if raw.blank? and (!raw.nil? or has_handle_fallback_options[:required])
        errors.add self.class.has_handle_fallback_options[:handle_column], "can't be blank"
      end
      
      # trapdoor for nil handles
      return if raw.nil?
      
      # don't allow all integer handles, because it looks like a database record id
      if raw =~ HasHandleFallback::RECORD_ID_REGEXP
        errors.add self.class.has_handle_fallback_options[:handle_column], "can't be entirely composed of integers"
      end
      
      # validates_format_of :handle, :with => HasHandleFallback::REGEXP, :allow_nil => true
      if has_handle_fallback_options[:validates_format] and raw !~ HasHandleFallback::REGEXP
        errors.add self.class.has_handle_fallback_options[:handle_column], "contains invalid characters"
      end
      
      # validates_length_of :handle, :in => HasHandleFallback::LENGTH_RANGE, :allow_nil => true
      unless HasHandleFallback::LENGTH_RANGE.include? raw.length
        errors.add self.class.has_handle_fallback_options[:handle_column], "must be #{HasHandleFallback::LENGTH_RANGE} characters in length"
      end
      
      if ValidatesDecencyOf.indecent? raw
        errors.add self.class.has_handle_fallback_options[:handle_column], "is indecent"
      end
      
      # validates_uniqueness_of :handle, :case_sensitive => false, :allow_nil => true
      if new_record? and self.class.exists? [ "#{self.class.quoted_table_name}.`#{self.class.has_handle_fallback_options[:handle_column]}` LIKE ?", raw ]
        errors.add self.class.has_handle_fallback_options[:handle_column], "isn't unique"
      end
      
      if !new_record? and self.class.exists? [ "#{self.class.quoted_table_name}.`#{self.class.primary_key}` <> ? AND #{self.class.quoted_table_name}.`#{self.class.has_handle_fallback_options[:handle_column]}` LIKE ?", id, raw ]
        errors.add self.class.has_handle_fallback_options[:handle_column], "isn't unique"
      end
    end
    
    def handle
      raw = read_attribute self.class.has_handle_fallback_options[:handle_column]
      raw.present? ? raw : handle_fallback
    end

    def handle_fallback
      fallback = read_attribute self.class.has_handle_fallback_options[:fallback_column]
      fallback = fallback.split('@').first if fallback.to_s.include? '@'
      HasHandleFallback.str2handle fallback
    end
    
    def to_param
      raw = read_attribute self.class.has_handle_fallback_options[:handle_column]
      if new_record?
        ''
      elsif raw.blank? or changes.include?(self.class.has_handle_fallback_options[:handle_column])
        id.to_s
      else
        raw
      end
    end
  end
end

ActiveRecord::Base.extend HasHandleFallback::ActiveRecordBaseMethods
