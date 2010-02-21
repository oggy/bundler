require File.expand_path('../../spec_helper', __FILE__)

describe "Bundler.require" do
  before :each do
    build_lib "one", "1.0.0" do |s|
      s.write "lib/baz.rb", "puts 'baz'"
      s.write "lib/qux.rb", "puts 'qux'"
    end

    build_lib "two", "1.0.0" do |s|
      s.write "lib/two.rb", "puts 'two'"
      s.add_dependency "three", "= 1.0.0"
    end

    build_lib "three", "1.0.0" do |s|
      s.write "lib/three.rb", "puts 'three'"
      s.add_dependency "seven", "= 1.0.0"
    end

    build_lib "four", "1.0.0" do |s|
      s.write "lib/four.rb", "puts 'four'"
    end

    build_lib "five", "1.0.0", :no_default => true do |s|
      s.write "lib/mofive.rb", "puts 'five'"
    end

    build_lib "six", "1.0.0" do |s|
      s.write "lib/six.rb", "puts 'six'"
    end

    build_lib "seven", "1.0.0" do |s|
      s.write "lib/seven.rb", "puts 'seven'"
    end

    gemfile <<-G
      path "#{lib_path}"
      gem "one", :group => :bar, :require => %w(baz qux)
      gem "two"
      gem "three", :group => :not
      gem "four", :require => false
      gem "five"
      gem "six", :group => "string"
      gem "seven", :group => :not
    G
  end

  it "requires the gems" do
    # default group
    run "Bundler.require"
    out.should == "two"

    # specific group
    run "Bundler.require(:bar)"
    out.should == "baz\nqux"

    # default and specific group
    run "Bundler.require(:default, :bar)"
    out.should == "two\nbaz\nqux"

    # specific group given as a string
    run "Bundler.require('bar')"
    out.should == "baz\nqux"

    # specific group declared as a string
    run "Bundler.require(:string)"
    out.should == "six"

    # required in resolver order instead of gemfile order
    run("Bundler.require(:not)")
    out.should == "seven\nthree"
  end

  it "requires the locked gems" do
    bundle :lock

    # default group
    out = ruby("require 'bundler'; Bundler.setup; Bundler.require")
    out.should == "two"

    # specific group
    out = ruby("require 'bundler'; Bundler.setup(:bar); Bundler.require(:bar)")
    out.should == "baz\nqux"

    # default and specific group
    out = ruby("require 'bundler'; Bundler.setup(:default, :bar); Bundler.require(:default, :bar)")
    out.should == "two\nbaz\nqux"

    # specific group given as a string
    out = ruby("require 'bundler'; Bundler.setup('bar'); Bundler.require('bar')")
    out.should == "baz\nqux"

    # specific group declared as a string
    out = ruby("require 'bundler'; Bundler.setup(:string); Bundler.require(:string)")
    out.should == "six"

    # required in resolver order instead of gemfile order
    out = ruby("require 'bundler'; Bundler.setup(:not); Bundler.require(:not)")
    out.should == "seven\nthree"
  end

  it "allows requiring gems with non standard names explicitly" do
    run "Bundler.require ; require 'mofive'"
    out.should == "two\nfive"
  end

  it "raises an exception if a require is specified but the file does not exist" do
    gemfile <<-G
      path "#{lib_path}"
      gem "two", :require => 'fail'
    G

    run <<-R
      begin
        Bundler.require
      rescue LoadError => e
        puts e.message
      end
    R
    out.should == 'no such file to load -- fail'
  end

  describe "with autoload" do
    it "does not load the gem" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module SlowLib; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => true
      G

      run "Bundler.require; p !!defined?(SlowLib)"
      out.should == "false"
    end

    it "loads the gem when the implied constant is referenced, if :autoload => true is given" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module SlowLib; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => true
      G

      run "Bundler.require; SlowLib; p !!defined?(SlowLib)"
      out.should == "true"
    end

    it "loads the gem when the given constant is referenced" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module OtherName; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => 'OtherName'
      G

      run "Bundler.require; OtherName; p !!defined?(OtherName)"
      out.should == "true"
    end

    it "accepts a symbol for a constant" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module OtherName; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => :OtherName
      G

      run "Bundler.require; OtherName; p !!defined?(OtherName)"
      out.should == "true"
    end

    it "loads the gem when the given class method is called" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module SlowLib; end; def Module.foo; 100; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => 'Module.foo'
      G

      run "Bundler.require; p Module.foo; p !!defined?(SlowLib)"
      out.should == "100\ntrue"
    end

    it "loads the gem when the given instance method is called" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module SlowLib; end; class Module; def foo; 100; end; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => 'Module#foo'
      G

      run "Bundler.require; Module.new.foo; p !!defined?(SlowLib)"
      out.should == "true"
    end

    it "loads the gem when any of the given constants are referenced, or methods are called" do
      build_lib "slow_lib", "1.0.0" do |s|
        s.write "lib/slow_lib.rb", "module SlowLib; end; class Module; def foo; 100; end; end"
      end

      gemfile <<-G
        path "#{lib_path}"
        gem "slow_lib", :autoload => ['SlowLib', 'Module#foo']
      G

      run "Bundler.require; p !!defined?(SlowLib)"
      out.should == "false"

      run "Bundler.require; SlowLib; p !!defined?(SlowLib)"
      out.should == "true"

      run "Bundler.require; Module.new.foo; p !!defined?(SlowLib)"
      out.should == "true"
    end
  end

  describe "requiring the environment directly" do
    it "requires the locked gems" do
      bundle :lock
      env = bundled_app(".bundle/environment.rb")

      out = ruby("require '#{env}'; Bundler.setup; Bundler.require")
      out.should == "two"

      out = ruby("require '#{env}'; Bundler.setup(:bar); Bundler.require(:bar)")
      out.should == "baz\nqux"

      out = ruby("require '#{env}'; Bundler.setup(:default, :bar); Bundler.require(:default, :bar)")
      out.should == "two\nbaz\nqux"
    end
  end

  describe "using bundle exec" do
    it "requires the locked gems" do
      bundle :lock

      bundle "exec ruby -e 'Bundler.require'"
      out.should == "two"

      bundle "exec ruby -e 'Bundler.require(:bar)'"
      out.should == "baz\nqux"

      bundle "exec ruby -e 'Bundler.require(:default, :bar)'"
      out.should == "two\nbaz\nqux"
    end
  end
end
