module Shards
  VERSION    = {{ read_file("#{__DIR__}/../VERSION").chomp }}
  BUILD_SHA1 = {{ `git log --format=%h -n 1 2>/dev/null || echo ""`.stringify.chomp }}
  BUILD_DATE = Time.unix({{ (env("SOURCE_DATE_EPOCH") || `date +%s`).to_i }}).to_s("%Y-%m-%d")

  def self.version_string
    if BUILD_SHA1.empty?
      "Shards #{VERSION} (#{BUILD_DATE})"
    else
      "Shards #{VERSION} [#{BUILD_SHA1}] (#{BUILD_DATE})"
    end
  end
end
