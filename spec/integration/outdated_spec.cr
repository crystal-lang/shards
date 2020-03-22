require "./spec_helper"

describe "outdated" do
  it "up_to_date" do
    with_shard({dependencies: {web: "*"}}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("I: Dependencies are up to date!")
    end
  end

  it "not_latest_version" do
    with_shard({dependencies: {orm: "*"}}, {orm: "0.3.1"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * orm (installed: 0.3.1, available: 0.5.0)")
    end
  end

  it "available_version_matching_pessimistic_operator" do
    with_shard({dependencies: {orm: "~> 0.3.0"}}, {orm: "0.3.1"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * orm (installed: 0.3.1, available: 0.3.2, latest: 0.5.0)")
    end
  end

  it "reports_new_prerelease" do
    with_shard({dependencies: {unstable: "0.3.0.alpha"}}) do
      run "shards install"
    end
    with_shard({dependencies: {unstable: "~> 0.3.0.alpha"}}) do
      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * unstable (installed: 0.3.0.alpha, available: 0.3.0.beta)")
    end
  end

  it "wont_report_prereleases_by_default" do
    with_shard({dependencies: {preview: "*"}}, {preview: "0.2.0"}) do
      run "shards install"

      stdout = run "shards outdated --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * preview (installed: 0.2.0, available: 0.3.0)")
    end
  end

  it "reports_prereleases_when_asked" do
    with_shard({dependencies: {preview: "*"}}, {preview: "0.2.0"}) do
      run "shards install"

      stdout = run "shards outdated --pre --no-color"
      stdout.should contain("W: Outdated dependencies:")
      stdout.should contain("  * preview (installed: 0.2.0, available: 0.4.0.a)")
    end
  end
end
