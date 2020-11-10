module Shards
  VERSION    = {{ read_file("#{__DIR__}/../VERSION").chomp }}
  BUILD_SHA1 = {{ env("SHARDS_CONFIG_BUILD_COMMIT") || "" }}
  {% if (t = env("SOURCE_DATE_EPOCH")) && !t.empty? %}
    BUILD_DATE = Time.unix({{t.to_i}}).to_s("%Y-%m-%d")
  {% else %}
    BUILD_DATE = ""
  {% end %}

  def self.version_string
    if BUILD_SHA1.empty?
      "Shards #{VERSION} (#{BUILD_DATE})"
    else
      "Shards #{VERSION} [#{BUILD_SHA1}] (#{BUILD_DATE})"
    end
  end
end
