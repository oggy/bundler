require 'rubygems/dependency'

module Bundler
  class Dependency < Gem::Dependency
    attr_reader :autorequire
    attr_reader :autoload
    attr_reader :groups

    def initialize(name, version, options = {}, &blk)
      super(name, version)

      @autorequire = nil
      @autoload    = nil
      @groups      = Array(options["group"] || :default).map { |g| g.to_sym }
      @source      = options["source"]

      if options.key?('require')
        @autorequire = Array(options['require'] || [])
      end
      if options.key?('autoload')
        @autoload = normalize_autoload(options['autoload'])
      end
    end

    def normalize_autoload(autoload)
      if autoload == true
        infer_namespace(name)
      else
        Array(autoload)
      end
    end

    def infer_namespace(gem_name)
      gem_name.gsub(/[\W_]+/, '_').gsub(/(?:^|_)(.)/){$1.upcase}.sub(/^\d/, '_\\&')
    end
  end
end
