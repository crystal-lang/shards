require "../integration_helper"

class OutdatedCommandTest < Minitest::Test
  def test_up_to_date
    with_shard({dependencies: {web: "*"}}) do
      run "shards install"

      stdout = run "shards outdated --no-color", capture: true
      assert_match "I: Dependencies are up to date!", stdout
    end
  end

  def test_not_latest_version
    with_shard({dependencies: {orm: "*"}}, {orm: "0.3.1"}) do
      run "shards install"

      stdout = run "shards outdated --no-color", capture: true
      assert_match "W: Outdated dependencies:", stdout
      assert_match "  * orm (installed: 0.3.1, available: 0.5.0)", stdout
    end
  end

  def test_available_version_matching_pessimistic_operator
    with_shard({dependencies: {orm: "~> 0.3.0"}}, {orm: "0.3.1"}) do
      run "shards install"

      stdout = run "shards outdated --no-color", capture: true
      assert_match "W: Outdated dependencies:", stdout
      assert_match "  * orm (installed: 0.3.1, available: 0.3.2, latest: 0.5.0)", stdout
    end
  end

  def test_reports_new_prerelease
    with_shard({dependencies: {unstable: "0.3.0.alpha"}}) do
      run "shards install"
    end
    with_shard({dependencies: {unstable: "~> 0.3.0.alpha"}}) do
      stdout = run "shards outdated --no-color", capture: true
      assert_match "W: Outdated dependencies:", stdout
      assert_match "  * unstable (installed: 0.3.0.alpha, available: 0.3.0.beta)", stdout
    end
  end

  def test_wont_report_prereleases_by_default
    with_shard({dependencies: {preview: "*"}}, {preview: "0.2.0"}) do
      run "shards install"

      stdout = run "shards outdated --no-color", capture: true
      assert_match "W: Outdated dependencies:", stdout
      assert_match "  * preview (installed: 0.2.0, available: 0.3.0)", stdout
    end
  end

  def test_reports_prereleases_when_asked
    with_shard({dependencies: {preview: "*"}}, {preview: "0.2.0"}) do
      run "shards install"

      stdout = run "shards outdated --pre --no-color", capture: true
      assert_match "W: Outdated dependencies:", stdout
      assert_match "  * preview (installed: 0.2.0, available: 0.4.0.a)", stdout
    end
  end
end
