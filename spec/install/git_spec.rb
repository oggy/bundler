require File.expand_path('../../spec_helper', __FILE__)

describe "bundle install with git sources" do
  describe "when floating on master" do
    before :each do
      build_git "foo" do |s|
        s.executables = "foobar"
      end

      install_gemfile <<-G
        git "#{lib_path('foo-1.0')}"
        gem 'foo'
      G
    end

    it "fetches gems" do
      should_be_installed("foo 1.0")

      run <<-RUBY
        require 'foo'
        puts "WIN" unless defined?(FOO_PREV_REF)
      RUBY

      out.should == "WIN"
    end

    it "caches the git repo" do
      Dir["#{default_bundle_path}/cache/bundler/git/foo-1.0-*"].should have(1).item
    end

    it "floats on master if no ref is specified" do
      update_git "foo"

      in_app_root2 do
        install_gemfile bundled_app2("Gemfile"), <<-G
          git "#{lib_path('foo-1.0')}"
          gem 'foo'
        G
      end

      in_app_root do
        run <<-RUBY
          require 'foo'
          puts "WIN" if defined?(FOO_PREV_REF)
        RUBY

        out.should == "WIN"
      end
    end

    it "setups executables" do
      pending_jruby_shebang_fix
      bundle "exec foobar"
      out.should == "1.0"
    end

    it "complains if pinned specs don't exist in the git repo" do
      build_git "foo"

      install_gemfile <<-G
        gem "foo", "1.1", :git => "#{lib_path('foo-1.0')}"
      G

      out.should include("Source contains 'foo' at: 1.0")
    end
  end

  describe "when specifying a revision" do
    it "works" do
      in_app_root

      build_git "foo"
      @revision = revision_for(lib_path("foo-1.0"))
      update_git "foo"

      install_gemfile <<-G
        git "#{lib_path('foo-1.0')}", :ref => "#{@revision}"
        gem "foo"
      G

      run <<-RUBY
        require 'foo'
        puts "WIN" unless defined?(FOO_PREV_REF)
      RUBY

      out.should == "WIN"
    end
  end

  describe "specified inline" do
    it "supports private git URLs" do
      install_gemfile <<-G
        gem "thingy", :git => "git@example.fkdmn1234fake.com:somebody/thingy.git"
      G
      err.should include("example.fkdmn1234fake.com")
      err.should include("ssh")
    end

    it "installs from git even if a newer gem is available elsewhere" do
      build_git "rack", "0.8"

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path('rack-0.8')}"
      G

      should_be_installed "rack 0.8"
    end

    it "installs dependencies from git even if a newer gem is available elsewhere" do
      system_gems "rack-1.0.0"

      build_lib "rack", "1.0", :path => lib_path('nested/bar') do |s|
        s.write "lib/rack.rb", "puts 'WIN OVERRIDE'"
      end

      build_git "foo", :path => lib_path('nested') do |s|
        s.add_dependency "rack", "= 1.0"
      end

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "foo", :git => "#{lib_path('nested')}"
      G

      run "require 'rack'"
      out.should == 'WIN OVERRIDE'
    end
  end

  it "uses a ref if specified" do
    build_git "foo"
    @revision = revision_for(lib_path("foo-1.0"))
    update_git "foo"

    install_gemfile <<-G
      gem "foo", :git => "#{lib_path('foo-1.0')}", :ref => "#{@revision}"
    G

    run <<-RUBY
      require 'foo'
      puts "WIN" unless defined?(FOO_PREV_REF)
    RUBY

    out.should == "WIN"
  end

  it "correctly handles cases with invalid gemspecs" do
    build_git "foo" do |s|
      s.summary = nil
    end

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "foo", :git => "#{lib_path('foo-1.0')}"
      gem "rails", "2.3.2"
    G

    should_be_installed "foo 1.0"
    should_be_installed "rails 2.3.2"
  end

  it "runs the gemspec in the context of its parent directory" do
    build_lib "bar", :path => lib_path("foo/bar"), :gemspec => false do |s|
      s.write lib_path("foo/bar/lib/version.rb"), %{BAR_VERSION = '1.0'}
      s.write "bar.gemspec", <<-G
        require 'lib/version'
        Gem::Specification.new do |s|
          s.name        = 'bar'
          s.version     = BAR_VERSION
          s.summary     = 'Bar'
          s.files       = Dir["lib/**/*.rb"]
          STDERR.puts s.files
        end
      G
    end

    build_git "foo", :path => lib_path("foo") do |s|
      s.write "bin/foo", ""
    end

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "bar", :git => "#{lib_path("foo")}"
      gem "rails", "2.3.2"
    G

    should_be_installed "bar 1.0"
    should_be_installed "rails 2.3.2"
  end

  it "installs from git even if a rubygems gem is present" do
    build_gem "foo", "1.0", :path => lib_path('fake_foo'), :to_system => true do |s|
      s.write "lib/foo.rb", "raise 'FAIL'"
    end

    build_git "foo", "1.0"

    install_gemfile <<-G
      gem "foo", "1.0", :git => "#{lib_path('foo-1.0')}"
    G

    should_be_installed "foo 1.0"
  end

  it "fakes the gem out if there is no gemspec" do
    build_git "foo", :gemspec => false

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "foo", "1.0", :git => "#{lib_path('foo-1.0')}"
      gem "rails", "2.3.2"
    G

    should_be_installed("foo 1.0")
    should_be_installed("rails 2.3.2")
  end

  it "catches git errors and spits out useful output" do
    install_gemfile <<-G
      gem "foo", "1.0", :git => "omgomg"
    G

    out.should include("An error has occurred in git. Cannot complete bundling.")
    err.should include("fatal: 'omgomg'")
    err.should include("fatal: The remote end hung up unexpectedly")
  end
end
