# frozen_string_literal: true
require "test_helper"

describe Licensed::Configuration do
  let(:config) { Licensed::Configuration.new }
  let(:fixtures) { File.expand_path("../fixtures/config", __FILE__) }

  before do
    @package = {"type" => "bundler", "name" => "bundler", "license" => "mit"}
  end

  it "accepts a license directory path option" do
    config["cache_path"] = "path"
    assert_equal config.root.join("path"), config.cache_path
  end

  it "sets default values" do
    assert_equal Pathname.pwd, config.source_path
    assert_equal config.root.join(".licenses"),
                 config.cache_path
    assert_equal File.basename(Dir.pwd), config["name"]
  end

  describe "load_from" do
    it "loads a config from a relative directory path" do
      relative_path = Pathname.new(fixtures).relative_path_from(Pathname.pwd)
      config = Licensed::Configuration.load_from(relative_path)
      assert_equal "licensed-yml", config["name"]
    end

    it "loads a config from an absolute directory path" do
      config = Licensed::Configuration.load_from(fixtures)
      assert_equal "licensed-yml", config["name"]
    end

    it "loads a config from a relative file path" do
      file = File.join(fixtures, "config.yml")
      relative_path = Pathname.new(file).relative_path_from(Pathname.pwd)
      config = Licensed::Configuration.load_from(relative_path)
      assert_equal "config-yml", config["name"]
    end

    it "loads a config from an absolute file path" do
      file = File.join(fixtures, "config.yml")
      config = Licensed::Configuration.load_from(file)
      assert_equal "config-yml", config["name"]
    end

    it "loads json configurations" do
      file = File.join(fixtures, ".licensed.json")
      config = Licensed::Configuration.load_from(file)
      assert_equal "licensed-json", config["name"]
    end

    it "sets a default cache_path" do
      config = Licensed::Configuration.load_from(fixtures)
      assert_equal Pathname.pwd.join(".licenses"), config.cache_path
    end

    it "returns empty sourses hash without default config file" do
      Dir.mktmpdir do |dir|
        assert_equal Licensed::Configuration.load_from(dir)["sources"], {}
      end
    end

    it "raises an error if the config file type is not understood" do
      file = File.join(fixtures, ".licensed.unknown")
      assert_raises ::Licensed::Configuration::LoadError do
        Licensed::Configuration.load_from(file)
      end
    end
  end

  describe "ignore" do
    it "marks the dependency as ignored" do
      refute config.ignored?(@package)
      config.ignore @package
      assert config.ignored?(@package)
    end
  end

  describe "review" do
    it "marks the dependency as reviewed" do
      refute config.reviewed?(@package)
      config.review @package
      assert config.reviewed?(@package)
    end
  end

  describe "allow" do
    it "marks the license as allowed" do
      refute config.allowed?("mit")
      config.allow "mit"
      assert config.allowed?("mit")
    end
  end

  describe "enabled?" do
    it "returns true if source type is enabled" do
      config["sources"]["npm"] = true
      assert config.enabled?("npm")
    end

    it "returns false if source type is disabled" do
      config["sources"]["npm"] = false
      refute config.enabled?("npm")
    end

    it "returns true if no source types are configured" do
      Licensed::Sources::Source.sources.each do |source|
        assert config.enabled?(source.type)
      end
    end

    it "returns true for source types that are not disabled, if no sources are configured enabled" do
      config["sources"]["npm"] = false
      Licensed::Sources::Source.sources - [Licensed::Sources::NPM].each do |source_type|
        assert config.enabled?(source_type)
      end
    end

    it "returns false for source types that are not enabled, if any sources are configured enabled" do
      config["sources"]["npm"] = true
      Licensed::Sources::Source.sources - [Licensed::Sources::NPM].each do |source_type|
        refute config.enabled?(source_type)
      end
    end
  end

  describe "apps" do
    it "defaults to returning itself" do
      assert_equal [config], config.apps
    end

    describe "from configuration options" do
      let(:apps) do
        [
          {
            "name" => "app1",
            "override" => "override",
            "cache_path" => "app1/vendor/licenses",
            "source_path" => File.expand_path("../../", __FILE__)
          },
          {
            "name" => "app2",
            "cache_path" => "app2/vendor/licenses",
            "source_path" => File.expand_path("../../", __FILE__)
          }
        ]
      end
      let(:config) do
        Licensed::Configuration.new("apps" => apps,
                                    "override" => "default",
                                    "default" => "default")
      end

      it "returns apps from configuration" do
        assert_equal 2, config.apps.size
        assert_equal "app1", config.apps[0]["name"]
        assert_equal "app2", config.apps[1]["name"]
      end

      it "includes default options" do
        assert_equal "default", config.apps[0]["default"]
        assert_equal "default", config.apps[1]["default"]
      end

      it "overrides default options" do
        assert_equal "default", config["override"]
        assert_equal "override", config.apps[0]["override"]
      end

      it "uses a default name" do
        apps[0].delete("name")
        assert_equal "licensed", config.apps[0]["name"]
      end

      it "uses a default cache path" do
        apps[0].delete("cache_path")
        assert_equal config.root.join(".licenses/app1"),
                     config.apps[0].cache_path
      end

      it "appends the app name to an inherited cache path" do
        apps[0].delete("cache_path")
        config = Licensed::Configuration.new("apps" => apps,
                                             "cache_path" => "vendor/cache")
        assert_equal config.root.join("vendor/cache/app1"),
                     config.apps[0].cache_path
      end

      it "does not append the app name to an explicit cache path" do
        refute config.apps[0].cache_path.to_s.end_with? config.apps[0]["name"]
      end

      it "raises an error if source_path is not set on an app" do
        apps[0].delete("source_path")
        assert_raises ::Licensed::Configuration::LoadError do
          Licensed::Configuration.new("apps" => apps)
        end
      end
    end
  end

  describe "root" do
    it "can be set to a path from a configuration file" do
      file = File.join(fixtures, "root.yml")
      config = Licensed::Configuration.load_from(file)
      assert_equal File.expand_path("../..", fixtures), config.root.to_s
    end

    it "can be set to true in a configuration file" do
      file = File.join(fixtures, "root_at_configuration.yml")
      config = Licensed::Configuration.load_from(file)
      assert_equal fixtures, config.root.to_s
    end

    it "defaults to the git repository root" do
      assert_equal Licensed::Git.repository_root, config.root.to_s
    end
  end
end
