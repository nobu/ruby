# frozen_string_literal: true

module Bundler
  class SourceList
    attr_reader :path_sources,
      :git_sources,
      :plugin_sources,
      :global_path_source,
      :metadata_source

    def global_rubygems_source
      @global_rubygems_source ||= rubygems_aggregate_class.new("allow_local" => true)
    end

    def initialize
      @path_sources           = []
      @git_sources            = []
      @plugin_sources         = []
      @global_rubygems_source = nil
      @global_path_source     = nil
      @rubygems_sources       = []
      @metadata_source        = Source::Metadata.new

      @merged_gem_lockfile_sections = false
      @local_mode = true
    end

    def merged_gem_lockfile_sections?
      @merged_gem_lockfile_sections
    end

    def merged_gem_lockfile_sections!(replacement_source)
      @merged_gem_lockfile_sections = true
      @global_rubygems_source = replacement_source
    end

    def aggregate_global_source?
      global_rubygems_source.multiple_remotes?
    end

    def implicit_global_source?
      global_rubygems_source.no_remotes?
    end

    def add_path_source(options = {})
      if options["gemspec"]
        add_source_to_list Source::Gemspec.new(options), path_sources
      else
        path_source = add_source_to_list Source::Path.new(options), path_sources
        @global_path_source ||= path_source if options["global"]
        path_source
      end
    end

    def add_git_source(options = {})
      add_source_to_list(Source::Git.new(options), git_sources).tap do |source|
        warn_on_git_protocol(source)
      end
    end

    def add_rubygems_source(options = {})
      new_source = Source::Rubygems.new(options)
      return @global_rubygems_source if @global_rubygems_source == new_source

      add_source_to_list new_source, @rubygems_sources
    end

    def add_plugin_source(source, options = {})
      add_source_to_list Plugin.source(source).new(options), @plugin_sources
    end

    def add_global_rubygems_remote(uri)
      global_rubygems_source.add_remote(uri)
      global_rubygems_source
    end

    def local_mode?
      @local_mode
    end

    def default_source
      global_path_source || global_rubygems_source
    end

    def rubygems_sources
      non_global_rubygems_sources + [global_rubygems_source]
    end

    def non_global_rubygems_sources
      @rubygems_sources
    end

    def rubygems_remotes
      rubygems_sources.flat_map(&:remotes).uniq
    end

    def all_sources
      path_sources + git_sources + plugin_sources + rubygems_sources + [metadata_source]
    end

    def non_default_explicit_sources
      all_sources - [default_source, metadata_source]
    end

    def get(source)
      source_list_for(source).find {|s| s.include?(source) }
    end

    def lock_sources
      lock_other_sources + lock_rubygems_sources
    end

    def lock_other_sources
      (path_sources + git_sources + plugin_sources).sort_by(&:identifier)
    end

    def lock_rubygems_sources
      if merged_gem_lockfile_sections?
        [combine_rubygems_sources]
      else
        rubygems_sources.sort_by(&:identifier)
      end
    end

    # Returns true if there are changes
    def replace_sources!(replacement_sources)
      return false if replacement_sources.empty?

      @rubygems_sources, @path_sources, @git_sources, @plugin_sources = map_sources(replacement_sources)
      @global_rubygems_source = global_replacement_source(replacement_sources)

      different_sources?(lock_sources, replacement_sources)
    end

    # Returns true if there are changes
    def expired_sources?(replacement_sources)
      return false if replacement_sources.empty?

      lock_sources = dup_with_replaced_sources(replacement_sources).lock_sources

      different_sources?(lock_sources, replacement_sources)
    end

    def prefer_local!
      all_sources.each(&:prefer_local!)
    end

    def local_only!
      all_sources.each(&:local_only!)
    end

    def local!
      all_sources.each(&:local!)
    end

    def cached!
      all_sources.each(&:cached!)
    end

    def remote!
      @local_mode = false

      all_sources.each(&:remote!)
    end

    private

    def dup_with_replaced_sources(replacement_sources)
      new_source_list = dup
      new_source_list.replace_sources!(replacement_sources)
      new_source_list
    end

    def map_sources(replacement_sources)
      rubygems = @rubygems_sources.map do |source|
        replace_rubygems_source(replacement_sources, source)
      end

      git, plugin = [@git_sources, @plugin_sources].map do |sources|
        sources.map do |source|
          replace_source(replacement_sources, source)
        end
      end

      path = @path_sources.map do |source|
        replace_path_source(replacement_sources, source)
      end

      [rubygems, path, git, plugin]
    end

    def global_replacement_source(replacement_sources)
      replace_rubygems_source(replacement_sources, global_rubygems_source, &:local!)
    end

    def replace_rubygems_source(replacement_sources, gemfile_source)
      replace_source(replacement_sources, gemfile_source) do |replacement_source|
        # locked sources never include credentials so always prefer remotes from the gemfile
        replacement_source.remotes = gemfile_source.remotes

        yield replacement_source if block_given?

        replacement_source
      end
    end

    def replace_source(replacement_sources, gemfile_source)
      replacement_source = replacement_sources.find {|s| s == gemfile_source }
      return gemfile_source unless replacement_source

      replacement_source = yield(replacement_source) if block_given?

      replacement_source
    end

    def replace_path_source(replacement_sources, gemfile_source)
      replace_source(replacement_sources, gemfile_source) do |replacement_source|
        if gemfile_source.is_a?(Source::Gemspec)
          gemfile_source.checksum_store = replacement_source.checksum_store
          gemfile_source
        else
          replacement_source
        end
      end
    end

    def different_sources?(lock_sources, replacement_sources)
      !equivalent_sources?(lock_sources, replacement_sources)
    end

    def rubygems_aggregate_class
      Source::Rubygems
    end

    def add_source_to_list(source, list)
      list.unshift(source).uniq!
      source
    end

    def source_list_for(source)
      case source
      when Source::Git          then git_sources
      when Source::Path         then path_sources
      when Source::Rubygems     then rubygems_sources
      when Plugin::API::Source  then plugin_sources
      else raise ArgumentError, "Invalid source: #{source.inspect}"
      end
    end

    def combine_rubygems_sources
      Source::Rubygems.new("remotes" => rubygems_remotes)
    end

    def warn_on_git_protocol(source)
      return if Bundler.settings["git.allow_insecure"]

      if /^git\:/.match?(source.uri)
        Bundler.ui.warn "The git source `#{source.uri}` uses the `git` protocol, " \
          "which transmits data without encryption. Disable this warning with " \
          "`bundle config set --local git.allow_insecure true`, or switch to the `https` " \
          "protocol to keep your data secure."
      end
    end

    def equivalent_sources?(lock_sources, replacement_sources)
      lock_sources.sort_by(&:identifier) == replacement_sources.sort_by(&:identifier)
    end
  end
end
