require 'rugged'
require 'pathname'

module Bananajour
  class Repository
    def self.for_name(name)
      new(Bananajour.repositories_path.join(name + ".git"))
    end
    def self.html_id(name)
      name.gsub(/[^A-Za-z-]+/, '').downcase
    end
    def initialize(path)
      @path = Pathname(path)
    end
    def ==(other)
      other.respond_to?(:path) && self.path == other.path
    end
    attr_reader :path
    def exist?
      path.exist?
    end
    def init!
      path.mkpath
      Dir.chdir(path) { `git init --bare` }
    end
    def name
      dirname.sub(".git",'')
    end
    def html_id
      self.class.html_id(name)
    end
    def dirname
      path.split.last.to_s
    end
    def to_s
      name
    end
    def uri
      Bananajour.git_uri + dirname
    end
    def web_uri
      Bananajour.web_uri + "#" + html_id
    end
    def rugged_repo
      @rugged_repo ||= Rugged::Repository.new(path.to_s)
    end

    def rugged_walker
      @rugged_walker ||= Rugged::Walker.new(rugged_repo)
      @rugged_walker.tap{|w| w.push(rugged_repo.head.name) }
    end

    def recent_commits
      @commits ||= rugged_walker.each(limit: 10).to_a
    end

    def readme_file
      rugged_repo.head.target.tree.find{|file| file[:name] =~ /readme/i }
    end

    def raw_readme_file
      return unless readme_file
      rugged_repo.lookup(readme_file[:oid]).content
    end

    def rendered_readme
      case readme_file[:name]
      when /\.md/i, /\.markdown/i
        require 'rdiscount'
        RDiscount.new(raw_readme_file).to_html
      when /\.textile/i
        require 'redcloth'
        RedCloth.new(raw_readme_file).to_html(:textile)
      end
    rescue LoadError
      ""
    end
    def remove!
      path.rmtree
    end
    def to_hash
      heads = [rugged_repo.head]
      {
        "name" => name,
        "html_friendly_name" => html_id, # TODO: Deprecate in v3. Renamed to html_id since 2.1.4
        "html_id" => html_id,
        "uri" => uri,
        "heads" => heads.map {|h| h.name},
        "recent_commits" => recent_commits.collect do |c|
          c.to_hash.merge(
            "id" => c.oid,
            "head" => rugged_repo.head.name,
            "gravatar" => Bananajour.gravatar_uri(c.author[:email])
          )
        end,
        "bananajour" => Bananajour.to_hash
      }
    end
  end
end
