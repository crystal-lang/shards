module Shards
  VERSION = {{ `cat VERSION`.stringify.chomp }}
  BUILD_SHA1 = {{ `git log --format=%h -n 1 2>/dev/null || echo ""`.stringify.chomp }}
  BUILD_DATE = {{ `date -u +'%Y-%m-%d'`.stringify.chomp }}

  def self.version_string
    if BUILD_SHA1.empty?
      "Shards #{VERSION} (#{BUILD_DATE})"
    else
      "Shards #{VERSION} [#{BUILD_SHA1}] (#{BUILD_DATE})"
    end
  end
end
