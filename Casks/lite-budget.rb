cask "lite-budget" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/ilja82/lite-budget/releases/download/v#{version}/LiteBudget.dmg"
  name "LiteBudget"
  desc "macOS Menu Bar app that tracks LiteLLM budget usage"
  homepage "https://github.com/ilja82/lite-budget"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "LiteBudget.app"

  zap trash: [
    "~/Library/Application Support/com.ilja82.lite-budget",
    "~/Library/Caches/com.ilja82.lite-budget",
    "~/Library/Preferences/com.ilja82.lite-budget.plist",
  ]
end