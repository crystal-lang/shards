module Shards
  VERSION = {{ `cat VERSION`.stringify.chomp }}
  BUILD_DATE = {{ `date -u +'%Y-%m-%d'`.stringify.chomp }}

  def self.version_string
    "Shards #{VERSION} (#{BUILD_DATE})"
  end
end
